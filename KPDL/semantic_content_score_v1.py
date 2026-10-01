#!/usr/bin/env python3
"""Uncertainty-aware cold-start scoring from the frozen semantic-v1 contract."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
SEMANTIC_DIR = ROOT / "semantic_v1"


def load_semantic(semantic_dir: Path = SEMANTIC_DIR) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, list[str]]:
    taxonomy = pd.read_csv(semantic_dir / "ai_interest_taxonomy_v1.csv", encoding="utf-8-sig")
    mapping = pd.read_csv(semantic_dir / "ai_interest_tag_mapping_v1.csv", encoding="utf-8-sig")
    tags = pd.read_csv(semantic_dir / "ai_place_tags_v1.csv", encoding="utf-8-sig")
    matrix = pd.read_csv(semantic_dir / "ai_place_semantic_matrix_v1.csv", encoding="utf-8-sig")
    place_taxonomy = pd.read_csv(semantic_dir / "ai_place_tag_taxonomy_v1.csv", encoding="utf-8-sig")
    tag_codes = place_taxonomy["tag_code"].astype(str).tolist()
    return taxonomy, mapping, tags, matrix, tag_codes


def parse_interests(interest_codes: list[str], taxonomy: pd.DataFrame) -> tuple[list[str], list[str]]:
    selected = list(dict.fromkeys(code.strip() for code in interest_codes if code.strip()))
    type_by_code = taxonomy.set_index("interest_code")["interest_type"].astype(str).to_dict()
    unknown = sorted(set(selected) - set(type_by_code))
    if unknown:
        raise ValueError(f"Unknown interest codes; use official semantic-v1 codes only: {unknown}")
    context = sorted(code for code in selected if type_by_code[code] == "CONTEXT")
    if context:
        raise ValueError(f"Screen 3 context codes belong to Backend contextual re-ranking: {context}")
    return selected, [code for code in selected if type_by_code[code] == "SEMANTIC"]


def build_user_tag_weights(selected: list[str], mapping: pd.DataFrame) -> tuple[dict[str, float], list[str]]:
    mapped_codes = set(mapping["interest_code"].astype(str))
    unmapped = sorted(set(selected) - mapped_codes)
    chosen = mapping[mapping["interest_code"].isin(selected)]
    weights: dict[str, float] = {}
    for row in chosen.itertuples(index=False):
        tag = str(row.tag_code)
        weights[tag] = max(weights.get(tag, 0.0), float(row.weight))
    return weights, unmapped


def score_places(
    interest_codes: list[str],
    destination_key: str | None = None,
    semantic_dir: Path = SEMANTIC_DIR,
    runtime_only: bool = True,
) -> pd.DataFrame:
    taxonomy, mapping, place_tags, matrix, tag_codes = load_semantic(semantic_dir)
    selected, semantic_codes = parse_interests(interest_codes, taxonomy)
    user_weights, unmapped = build_user_tag_weights(semantic_codes, mapping)
    total_weight = sum(user_weights.values())
    if total_weight <= 0:
        detail = ", ".join(unmapped) if unmapped else ", ".join(semantic_codes)
        raise ValueError(f"Selected interests have no official semantic mapping in semantic-v1: {detail}")

    links = place_tags.groupby("external_id")["tag_code"].apply(lambda values: set(values.astype(str))).to_dict()
    records: list[dict[str, object]] = []
    for place in matrix.itertuples(index=False):
        if destination_key and str(place.destination_key) != destination_key:
            continue
        runtime_eligible = str(place.runtime_eligible).lower() == "true"
        if runtime_only and not runtime_eligible:
            continue

        status = str(place.semantic_status)
        place_id = str(place.external_id)
        if status == "READY":
            observed_tags = set(tag_codes)
        elif status == "PARTIAL":
            observed_tags = links.get(place_id, set())
        else:
            observed_tags = set()

        known_mass = sum(weight for tag, weight in user_weights.items() if tag in observed_tags)
        matched_mass = sum(
            user_weight * float(getattr(place, tag))
            for tag, user_weight in user_weights.items()
            if tag in observed_tags
        )

        if status == "NEED_REVIEW":
            score_lower = None
            score_upper = None
            coverage = 0.0
            signal_available = False
        elif known_mass <= 0:
            score_lower = 0.0
            score_upper = 1.0
            coverage = 0.0
            signal_available = False
        else:
            coverage = min(1.0, known_mass / total_weight)
            score_lower = min(1.0, matched_mass / total_weight)
            unknown_mass = max(0.0, total_weight - known_mass)
            score_upper = min(1.0, (matched_mass + unknown_mass) / total_weight)
            signal_available = True

        records.append({
            "external_id": place_id,
            "canonical_name": str(place.canonical_name),
            "destination_key": str(place.destination_key),
            "category": str(place.category),
            "semantic_status": status,
            "runtime_eligible": runtime_eligible,
            "selected_interest_codes": ";".join(selected),
            "unmapped_interest_codes": ";".join(unmapped),
            "semantic_score": score_lower,
            "semantic_score_upper": score_upper,
            "semantic_coverage": coverage,
            "semantic_signal_available": signal_available,
        })

    result = pd.DataFrame(records)
    if result.empty:
        return result
    result["__score_sort"] = pd.to_numeric(result["semantic_score"], errors="coerce").fillna(-1.0)
    result = result.sort_values(["__score_sort", "external_id"], ascending=[False, True], kind="stable")
    return result.drop(columns="__score_sort").reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interests", nargs="+", required=True, help="Official Screen 1-2 interest codes")
    parser.add_argument("--destination", default=None)
    parser.add_argument("--semantic-dir", type=Path, default=SEMANTIC_DIR)
    parser.add_argument("--include-runtime-ineligible", action="store_true")
    parser.add_argument("--output", type=Path, default=ROOT / "semantic_content_scores.csv")
    args = parser.parse_args()

    result = score_places(
        args.interests,
        destination_key=args.destination,
        semantic_dir=args.semantic_dir,
        runtime_only=not args.include_runtime_ineligible,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(args.output, index=False, encoding="utf-8-sig")
    print(f"Wrote {len(result)} rows to {args.output}")
    if not result.empty:
        print(result.head(10).to_string(index=False))


if __name__ == "__main__":
    main()
