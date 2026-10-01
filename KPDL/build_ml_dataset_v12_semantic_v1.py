#!/usr/bin/env python3
"""Attach frozen semantic-v1 candidate features to the v11 ranking rows."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = ROOT / "ml_training_dataset_v11.csv"
DEFAULT_SEMANTIC_DIR = ROOT / "semantic_v1"
DEFAULT_OUTPUT = ROOT / "ml_training_dataset_v12_semantic_v1.csv"
DEFAULT_MANIFEST = ROOT / "ml_training_dataset_v12_semantic_v1_manifest.json"

BASE_REQUIRED = {
    "query_id", "ma_tour", "candidate_external_id", "candidate_canonical_name",
    "split_type", "label", "destination_key", "candidate_category",
}
STATUSES = {"READY", "PARTIAL", "NEED_REVIEW"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_csv(path: Path) -> pd.DataFrame:
    return pd.read_csv(path, encoding="utf-8-sig", keep_default_na=False)


def require_columns(frame: pd.DataFrame, required: set[str], source: str) -> None:
    missing = sorted(required - set(frame.columns))
    if missing:
        raise ValueError(f"{source} is missing columns: {missing}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v11", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--semantic-dir", type=Path, default=DEFAULT_SEMANTIC_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()

    source = args.v11.resolve()
    sem_dir = args.semantic_dir.resolve()
    matrix_path = sem_dir / "ai_place_semantic_matrix_v1.csv"
    tags_path = sem_dir / "ai_place_tags_v1.csv"
    taxonomy_path = sem_dir / "ai_place_tag_taxonomy_v1.csv"
    release_path = sem_dir / "semantic_v1_manifest.json"
    for path in [source, matrix_path, tags_path, taxonomy_path, release_path]:
        if not path.is_file():
            raise FileNotFoundError(path)

    base = read_csv(source)
    require_columns(base, BASE_REQUIRED, str(source))
    if base["candidate_external_id"].isna().any() or base["candidate_external_id"].eq("").any():
        raise ValueError("v11 contains an empty candidate_external_id")

    matrix = read_csv(matrix_path)
    tags = read_csv(tags_path)
    taxonomy = read_csv(taxonomy_path)
    release = json.loads(release_path.read_text(encoding="utf-8-sig"))
    if release.get("semanticDataVersion") != "semantic-v1" or release.get("releaseStatus") != "FINAL":
        raise ValueError("The semantic package is not the frozen semantic-v1 FINAL release")

    tag_codes = taxonomy["tag_code"].astype(str).tolist()
    if len(tag_codes) != len(set(tag_codes)):
        raise ValueError("Duplicate tag_code in the official taxonomy")
    matrix_tag_codes = set(matrix.columns) - {
        "external_id", "canonical_name", "destination_key", "category", "runtime_eligible", "semantic_status"
    }
    if matrix_tag_codes != set(tag_codes):
        raise ValueError("Matrix tag columns do not exactly match the official tag taxonomy")
    required_matrix = {"external_id", "canonical_name", "destination_key", "category", "runtime_eligible", "semantic_status", *tag_codes}
    require_columns(matrix, required_matrix, str(matrix_path))
    require_columns(tags, {"external_id", "tag_code", "semantic_status", "runtime_eligible", "semantic_data_version"}, str(tags_path))
    if matrix["external_id"].duplicated().any():
        raise ValueError("Semantic matrix must contain one row per external_id")
    if tags["semantic_data_version"].nunique() != 1 or tags["semantic_data_version"].iloc[0] != "semantic-v1":
        raise ValueError("Place-tag rows do not all belong to semantic-v1")
    if len(matrix) != int(release.get("canonicalPlaceCount", -1)):
        raise ValueError("Place count differs from the frozen manifest")
    if len(tag_codes) != int(release.get("tagCount", -1)) or len(tags) != int(release.get("placeTagLinkCount", -1)):
        raise ValueError("Tag taxonomy/link counts differ from the frozen manifest")
    unknown_link_tags = sorted(set(tags["tag_code"].astype(str)) - set(tag_codes))
    if unknown_link_tags:
        raise ValueError(f"Place-tag links contain non-canonical tag codes: {unknown_link_tags}")
    if not set(matrix["semantic_status"].unique()).issubset(STATUSES):
        raise ValueError("Unknown semantic_status in the matrix")

    for tag in tag_codes:
        matrix[tag] = pd.to_numeric(matrix[tag], errors="raise").astype(float)
        if not matrix[tag].between(0.0, 1.0).all():
            raise ValueError(f"Tag weight outside [0,1]: {tag}")

    tags = tags.copy()
    tags["runtime_eligible"] = tags["runtime_eligible"].astype(str).str.lower().eq("true")
    per_place = tags.groupby("external_id", as_index=False).agg(
        semantic_status_from_tags=("semantic_status", "first"),
        runtime_eligible_from_tags=("runtime_eligible", "first"),
        semantic_tag_count=("tag_code", "nunique"),
    )
    if per_place["external_id"].duplicated().any():
        raise ValueError("Unexpected duplicate place aggregation")
    if len(per_place) != len(matrix):
        raise ValueError("Every semantic Place must have status/source rows in the long-form handoff")

    link_weights = tags.groupby(["external_id", "tag_code"], as_index=False)["weight"].max()
    long_values = link_weights.pivot(index="external_id", columns="tag_code", values="weight").fillna(0.0)
    matrix_values = matrix.set_index("external_id")[tag_codes].astype(float)
    long_values = long_values.reindex(index=matrix_values.index, columns=tag_codes, fill_value=0.0).astype(float)
    if not np.allclose(long_values.to_numpy(), matrix_values.to_numpy(), atol=1e-9):
        raise ValueError("Long-form Place-tag weights do not match the wide semantic matrix")

    meta = matrix[["external_id", "canonical_name", "destination_key", "category", "runtime_eligible", "semantic_status"]].merge(
        per_place, on="external_id", how="left", validate="one_to_one"
    )
    status_conflict = meta["semantic_status_from_tags"].notna() & meta["semantic_status"].ne(meta["semantic_status_from_tags"])
    runtime_text = meta["runtime_eligible"].astype(str).str.lower().eq("true")
    runtime_tag_text = meta["runtime_eligible_from_tags"].astype(str).str.lower().eq("true")
    runtime_conflict = meta["runtime_eligible_from_tags"].notna() & runtime_text.ne(runtime_tag_text)
    if status_conflict.any() or runtime_conflict.any():
        raise ValueError("Matrix status/runtime eligibility conflicts with long-form place tags")
    meta["semantic_tag_count"] = meta["semantic_tag_count"].fillna(0).astype(int)
    meta["semantic_data_version"] = "semantic-v1"

    semantic_features = matrix[["external_id", *tag_codes]].copy()
    semantic_features = semantic_features.rename(columns={tag: f"sem_tag__{tag}" for tag in tag_codes})

    # READY has a usable profile. For PARTIAL, only explicit links are observed;
    # missing tag cells stay masked. NEED_REVIEW has no semantic feature signal.
    present = tags[["external_id", "tag_code"]].drop_duplicates()
    present_set = set(zip(present["external_id"], present["tag_code"]))
    status_by_id = meta.set_index("external_id")["semantic_status"].to_dict()
    mask_rows: list[dict[str, object]] = []
    for external_id in matrix["external_id"].astype(str):
        status = status_by_id[external_id]
        row: dict[str, object] = {"external_id": external_id}
        for tag in tag_codes:
            if status == "READY":
                observed = 1
            elif status == "PARTIAL":
                observed = int((external_id, tag) in present_set)
            else:
                observed = 0
            row[f"sem_mask__{tag}"] = observed
        mask_rows.append(row)
    masks = pd.DataFrame(mask_rows)
    semantic_features = semantic_features.merge(masks, on="external_id", validate="one_to_one")

    # Unknown PARTIAL cells and all NEED_REVIEW cells are zero-filled only as
    # numeric storage; the paired mask distinguishes them from observed values.
    for tag in tag_codes:
        value_col = f"sem_tag__{tag}"
        mask_col = f"sem_mask__{tag}"
        semantic_features.loc[semantic_features[mask_col].eq(0), value_col] = 0.0

    semantic_meta = meta[[
        "external_id", "canonical_name", "destination_key", "category",
        "semantic_status", "runtime_eligible", "semantic_tag_count", "semantic_data_version",
    ]].rename(columns={
        "canonical_name": "semantic_canonical_name",
        "destination_key": "semantic_destination_key",
        "category": "semantic_category",
        "runtime_eligible": "semantic_runtime_eligible",
    })
    semantic_meta["semantic_runtime_eligible"] = semantic_meta["semantic_runtime_eligible"].astype(str).str.lower().eq("true")

    candidate_ids = set(base["candidate_external_id"].astype(str))
    semantic_ids = set(matrix["external_id"].astype(str))
    missing_ids = sorted(candidate_ids - semantic_ids)
    if missing_ids:
        raise ValueError(f"v11 candidate IDs missing from semantic-v1: {missing_ids[:10]} (total {len(missing_ids)})")

    base["__original_row_order"] = np.arange(len(base))
    out = base.merge(semantic_meta, left_on="candidate_external_id", right_on="external_id", how="left", validate="many_to_one", sort=False)
    out = out.merge(semantic_features, left_on="candidate_external_id", right_on="external_id", how="left", validate="many_to_one", sort=False, suffixes=("", "__features"))
    out = out.sort_values("__original_row_order", kind="stable").drop(columns=["__original_row_order", "external_id", "external_id__features"])
    out = out.reset_index(drop=True)

    check = out["semantic_canonical_name"].astype(str).ne(out["candidate_canonical_name"].astype(str))
    if check.any():
        raise ValueError(f"Canonical-name mismatch for {int(check.sum())} candidate rows")
    if out["semantic_category"].astype(str).ne(out["candidate_category"].astype(str)).any():
        raise ValueError("Candidate category mismatch between v11 and semantic-v1")
    if out["semantic_destination_key"].astype(str).ne(out["destination_key"].astype(str)).any():
        raise ValueError("Destination mismatch between v11 and semantic-v1")
    if len(out) != len(base):
        raise AssertionError("Row count changed during semantic join")
    if not out["label"].equals(base["label"]):
        raise AssertionError("label changed during semantic join")
    if not out["split_type"].equals(base["split_type"]):
        raise AssertionError("split_type changed during semantic join")
    if out["semantic_status"].isna().any() or out.filter(regex=r"^sem_(tag|mask)__").isna().any().any():
        raise AssertionError("Missing semantic data after validated join")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.output, index=False, encoding="utf-8-sig")
    status_by_candidate = semantic_meta.set_index("external_id")["semantic_status"]
    candidate_status_counts = pd.Series([status_by_candidate[x] for x in sorted(candidate_ids)]).value_counts().to_dict()
    row_status_counts = out["semantic_status"].value_counts().to_dict()
    manifest = {
        "datasetVersion": "ml-training-v12-semantic-v1",
        "semanticDataVersion": "semantic-v1",
        "placeCatalogVersion": release.get("placeCatalogVersion"),
        "inputFile": source.name,
        "inputSha256": sha256(source),
        "outputFile": args.output.name,
        "outputSha256": sha256(args.output),
        "rows": int(len(out)),
        "queries": int(out["query_id"].nunique()),
        "candidateExternalIds": int(out["candidate_external_id"].nunique()),
        "semanticCatalogPlaces": int(len(matrix)),
        "semanticTags": int(len(tag_codes)),
        "semanticTagFeatureCount": int(len(tag_codes)),
        "semanticMaskFeatureCount": int(len(tag_codes)),
        "originalColumnCount": int(len(base.columns) - 1),
        "outputColumnCount": int(len(out.columns)),
        "labelCounts": {str(k): int(v) for k, v in out["label"].value_counts().to_dict().items()},
        "splitCounts": {str(k): int(v) for k, v in out["split_type"].value_counts().to_dict().items()},
        "candidateStatusCounts": {str(k): int(v) for k, v in candidate_status_counts.items()},
        "rowStatusCounts": {str(k): int(v) for k, v in row_status_counts.items()},
        "querySurveyPreferencesPresent": False,
        "distanceReviewPopularityContextAdded": False,
        "maskPolicy": {
            "READY": "all official tag dimensions are available to the semantic profile",
            "PARTIAL": "only explicit official tag links are observed; other dimensions are masked unknown",
            "NEED_REVIEW": "all semantic dimensions masked; use non-semantic model fallback",
        },
        "mlIdentifiersExcludedFromFeatures": ["query_id", "ma_tour", "candidate_external_id", "candidate_canonical_name", "split_type", "label"],
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
