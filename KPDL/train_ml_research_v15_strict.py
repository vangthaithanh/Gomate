#!/usr/bin/env python3
"""Strict GoMate trainer for the recommendation proposal.

Only the algorithms required by the proposal are included:

* Association Rules baseline;
* SVD collaborative-filtering baseline;
* Content-Based baseline;
* the proposed Hybrid score for screen 1-2.

Screen 3 is owned by Backend. Its Spatial, Temporal and Group scores are not
trained in this file because the frozen training release has no runtime GPS,
route-time or member-preference labels. The system-level score is documented
as:

    FinalScore = 0.75 * AIHybridScore + 0.25 * BackendContextScore

The script does not add Random Forest, popularity ranking or any other model.
It does not change the semantic-v1 taxonomy, mapping or external_id values.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.decomposition import TruncatedSVD


ROOT = Path(__file__).resolve().parent
DEFAULT_DATASET = ROOT / "ml_training_dataset_v12_semantic_v1.csv"
DEFAULT_OUTDIR = ROOT / "training_output_research_v15_strict"

LABEL_COL = "label"
SEMANTIC_VALUE_PREFIX = "sem_tag__"
SEMANTIC_MASK_PREFIX = "sem_mask__"

REQUIRED_COLUMNS = [
    "query_id",
    "ma_tour",
    "candidate_external_id",
    "split_type",
    LABEL_COL,
    "semantic_status",
    "max_support",
    "max_confidence",
    "max_lift",
    "max_rule_score",
    "has_direct_rule",
    "is_ar_candidate",
]


def rank_metrics(
    frame: pd.DataFrame,
    scores: Sequence[float],
    ks: Sequence[int] = (3, 5, 10),
) -> Dict[str, Any]:
    """Calculate Precision@K, Recall@K, NDCG@K and MRR by query."""
    if len(frame) != len(scores):
        raise ValueError("Number of scores must equal number of rows")

    scored = frame[["query_id", "candidate_external_id", LABEL_COL]].copy()
    scored["score"] = np.asarray(scores, dtype=float)
    result: Dict[str, Any] = {
        "queries": int(scored["query_id"].nunique())
    }
    per_k: Dict[int, List[Tuple[float, float, float]]] = {
        int(k): [] for k in ks
    }
    reciprocal_ranks: List[float] = []

    for _, group in scored.groupby("query_id", sort=False):
        group = group.sort_values(
            ["score", "candidate_external_id"],
            ascending=[False, True],
            kind="stable",
        )
        labels = group[LABEL_COL].astype(int).to_numpy()
        positive_count = int(labels.sum())
        if positive_count == 0:
            continue

        positive_ranks = np.flatnonzero(labels == 1)
        reciprocal_ranks.append(1.0 / (int(positive_ranks[0]) + 1))

        for k in ks:
            k = int(k)
            top_labels = labels[:k]
            hits = float(top_labels.sum())
            precision = hits / float(k)
            recall = hits / float(positive_count)
            discounts = 1.0 / np.log2(np.arange(2, len(top_labels) + 2))
            dcg = float((top_labels * discounts).sum())
            ideal_len = min(positive_count, k)
            idcg = float(
                (1.0 / np.log2(np.arange(2, ideal_len + 2))).sum()
            )
            ndcg = dcg / idcg if idcg else 0.0
            per_k[k].append((precision, recall, ndcg))

    for k, values in per_k.items():
        result["precision@%d" % k] = (
            float(np.mean([value[0] for value in values]))
            if values
            else 0.0
        )
        result["recall@%d" % k] = (
            float(np.mean([value[1] for value in values]))
            if values
            else 0.0
        )
        result["ndcg@%d" % k] = (
            float(np.mean([value[2] for value in values]))
            if values
            else 0.0
        )

    result["mrr"] = (
        float(np.mean(reciprocal_ranks)) if reciprocal_ranks else 0.0
    )
    return result


def fit_minmax_stats(
    frame: pd.DataFrame,
    columns: Iterable[str],
) -> Dict[str, Tuple[float, float]]:
    result: Dict[str, Tuple[float, float]] = {}
    for column in columns:
        values = pd.to_numeric(frame[column], errors="coerce").fillna(0.0)
        result[column] = (float(values.min()), float(values.max()))
    return result


def minmax_with_stats(
    values: pd.Series,
    low: float,
    high: float,
) -> pd.Series:
    numeric = pd.to_numeric(values, errors="coerce").fillna(0.0)
    if high <= low:
        return pd.Series(0.0, index=values.index, dtype=float)
    return ((numeric - low) / (high - low)).clip(0.0, 1.0)


def association_rule_scores(
    frame: pd.DataFrame,
    rule_stats: Mapping[str, Tuple[float, float]],
) -> Tuple[np.ndarray, np.ndarray]:
    """Calculate the Association Rules baseline score.

    A missing rule for one candidate is a valid zero score. The component is
    unavailable only when a query has no rule signal for any candidate.
    """
    support = minmax_with_stats(
        frame["max_support"], *rule_stats["max_support"]
    )
    confidence = minmax_with_stats(
        frame["max_confidence"], *rule_stats["max_confidence"]
    )
    lift = minmax_with_stats(frame["max_lift"], *rule_stats["max_lift"])
    direct = pd.to_numeric(
        frame["has_direct_rule"], errors="coerce"
    ).fillna(0.0).clip(0.0, 1.0)
    stored_rule = pd.to_numeric(
        frame["max_rule_score"], errors="coerce"
    ).fillna(0.0).clip(0.0, 1.0)

    score = (
        0.20 * support
        + 0.35 * confidence
        + 0.25 * lift
        + 0.20 * direct
    )
    score = np.maximum(score, stored_rule).clip(0.0, 1.0)

    has_signal = (
        (pd.to_numeric(frame["has_direct_rule"], errors="coerce") > 0)
        | (pd.to_numeric(frame["is_ar_candidate"], errors="coerce") > 0)
        | (pd.to_numeric(frame["max_support"], errors="coerce") > 0)
        | (pd.to_numeric(frame["max_confidence"], errors="coerce") > 0)
        | (pd.to_numeric(frame["max_lift"], errors="coerce") > 0)
        | (pd.to_numeric(frame["max_rule_score"], errors="coerce") > 0)
    )
    available = has_signal.groupby(frame["query_id"]).transform("any")
    return score.to_numpy(dtype=float), available.to_numpy(dtype=bool)


def semantic_matrix(
    frame: pd.DataFrame,
    semantic_values: Sequence[str],
    semantic_masks: Sequence[str],
) -> np.ndarray:
    values = frame[list(semantic_values)].to_numpy(dtype=float)
    masks = frame[list(semantic_masks)].to_numpy(dtype=float)
    return values * masks


def query_position(query_id: object) -> Tuple[int, int, str]:
    match = re.search(r"_day_(\d+)_pos_(\d+)", str(query_id))
    if not match:
        return (0, 0, str(query_id))
    return (int(match.group(1)), int(match.group(2)), str(query_id))


def content_based_scores(
    frame: pd.DataFrame,
    semantic_values: Sequence[str],
    semantic_masks: Sequence[str],
) -> Tuple[np.ndarray, np.ndarray]:
    """Calculate the Content-Based baseline from previous positive places."""
    scores = np.zeros(len(frame), dtype=float)
    available = np.zeros(len(frame), dtype=bool)
    if not semantic_values:
        return scores, available

    vectors = semantic_matrix(frame, semantic_values, semantic_masks)
    row_positions = pd.Series(np.arange(len(frame)), index=frame.index)

    for _, tour_frame in frame.groupby("ma_tour", sort=False):
        positives = (
            tour_frame[tour_frame[LABEL_COL].astype(int).eq(1)]
            .drop_duplicates("query_id")
            .copy()
        )
        if positives.empty:
            continue

        positives["_query_order"] = positives["query_id"].map(query_position)
        positives = positives.sort_values("_query_order", kind="stable")
        previous_vectors: List[np.ndarray] = []
        profiles: Dict[str, np.ndarray] = {}

        for row in positives.itertuples():
            if previous_vectors:
                profiles[str(row.query_id)] = np.mean(
                    previous_vectors,
                    axis=0,
                )
            vector = vectors[int(row_positions.loc[row.Index])]
            if float(np.linalg.norm(vector)) > 0:
                previous_vectors.append(vector)

        for query_id, profile in profiles.items():
            query_rows = tour_frame[
                tour_frame["query_id"].astype(str).eq(query_id)
            ]
            positions = row_positions.loc[query_rows.index].to_numpy()
            profile_norm = float(np.linalg.norm(profile))
            if profile_norm <= 0:
                continue

            candidate_vectors = vectors[positions]
            candidate_norm = np.linalg.norm(candidate_vectors, axis=1)
            denominator = candidate_norm * profile_norm
            cosine = np.divide(
                candidate_vectors @ profile,
                denominator,
                out=np.zeros(len(positions), dtype=float),
                where=denominator > 0,
            )
            scores[positions] = np.clip(cosine, 0.0, 1.0)
            available[positions] = True

    return scores, available


def fit_svd_item_embeddings(
    train: pd.DataFrame,
    components: int,
) -> Tuple[Dict[str, np.ndarray], Dict[str, Any]]:
    """Fit SVD on the training-only Tour x POI matrix."""
    positives = train[train[LABEL_COL].astype(int).eq(1)]
    tours = sorted(positives["ma_tour"].astype(str).unique())
    items = sorted(positives["candidate_external_id"].astype(str).unique())
    if len(tours) < 2 or len(items) < 2:
        return {}, {"status": "skipped", "reason": "not enough data"}

    tour_index = {tour: index for index, tour in enumerate(tours)}
    item_index = {item: index for index, item in enumerate(items)}
    matrix = np.zeros((len(tours), len(items)), dtype=float)
    for row in positives.itertuples(index=False):
        matrix[
            tour_index[str(row.ma_tour)],
            item_index[str(row.candidate_external_id)],
        ] = 1.0

    n_components = max(
        1,
        min(int(components), matrix.shape[0] - 1, matrix.shape[1] - 1),
    )
    svd = TruncatedSVD(n_components=n_components, random_state=42)
    svd.fit(matrix)
    item_vectors = svd.components_.T
    embeddings = {
        item: item_vectors[index]
        for item, index in item_index.items()
    }
    metadata = {
        "status": "fit",
        "matrix": "train Tour x POI",
        "tours": len(tours),
        "items": len(items),
        "components": int(n_components),
        "explained_variance_ratio_sum": float(
            svd.explained_variance_ratio_.sum()
        ),
    }
    return embeddings, metadata


def svd_scores(
    frame: pd.DataFrame,
    item_embeddings: Mapping[str, np.ndarray],
) -> Tuple[np.ndarray, np.ndarray]:
    """Calculate the SVD baseline score from previous places."""
    scores = np.zeros(len(frame), dtype=float)
    available = np.zeros(len(frame), dtype=bool)
    if not item_embeddings:
        return scores, available

    row_positions = pd.Series(np.arange(len(frame)), index=frame.index)
    for _, tour_frame in frame.groupby("ma_tour", sort=False):
        positives = (
            tour_frame[tour_frame[LABEL_COL].astype(int).eq(1)]
            .drop_duplicates("query_id")
            .copy()
        )
        if positives.empty:
            continue

        positives["_query_order"] = positives["query_id"].map(query_position)
        positives = positives.sort_values("_query_order", kind="stable")
        previous_vectors: List[np.ndarray] = []
        profiles: Dict[str, np.ndarray] = {}

        for row in positives.itertuples():
            if previous_vectors:
                profiles[str(row.query_id)] = np.mean(
                    previous_vectors,
                    axis=0,
                )
            item_vector = item_embeddings.get(str(row.candidate_external_id))
            if item_vector is not None:
                previous_vectors.append(item_vector)

        for query_id, profile in profiles.items():
            query_rows = tour_frame[
                tour_frame["query_id"].astype(str).eq(query_id)
            ]
            profile_norm = float(np.linalg.norm(profile))
            if profile_norm <= 0:
                continue

            for index, candidate_id in zip(
                query_rows.index,
                query_rows["candidate_external_id"].astype(str),
            ):
                item_vector = item_embeddings.get(candidate_id)
                if item_vector is None:
                    continue
                denominator = float(np.linalg.norm(item_vector) * profile_norm)
                if denominator <= 0:
                    continue
                cosine = float(item_vector @ profile / denominator)
                position = int(row_positions.loc[index])
                scores[position] = float(np.clip(
                    (cosine + 1.0) / 2.0,
                    0.0,
                    1.0,
                ))
                available[position] = True

    return scores, available


def semantic_coverage(
    frame: pd.DataFrame,
    semantic_masks: Sequence[str],
) -> np.ndarray:
    if not semantic_masks:
        return np.zeros(len(frame), dtype=float)
    return frame[list(semantic_masks)].mean(axis=1).astype(float).clip(
        0.0, 1.0
    ).to_numpy()


def hybrid_scores(
    frame: pd.DataFrame,
    association_scores: np.ndarray,
    association_available: np.ndarray,
    svd_values: np.ndarray,
    svd_available: np.ndarray,
    content_values: np.ndarray,
    content_available: np.ndarray,
    coverage: np.ndarray,
    weights: Mapping[str, float],
) -> pd.DataFrame:
    """Proposed screen-1-2 Hybrid with uncertainty-aware semantic masking."""
    result = pd.DataFrame(index=frame.index)
    result["association_rule_score"] = association_scores
    result["svd_score"] = svd_values
    result["content_based_score"] = content_values
    result["semantic_coverage"] = coverage
    result["association_rule_available"] = association_available.astype(int)
    result["svd_available"] = svd_available.astype(int)
    result["content_based_available"] = content_available.astype(int)

    w_association = float(weights["association_rule"])
    w_svd = float(weights["svd"])
    w_content = float(weights["content_based"])

    effective_content_weight = (
        w_content * coverage * content_available.astype(float)
    )
    denominator = (
        w_association * association_available.astype(float)
        + w_svd * svd_available.astype(float)
        + effective_content_weight
    )
    numerator = (
        w_association
        * association_scores
        * association_available.astype(float)
        + w_svd * svd_values * svd_available.astype(float)
        + w_content
        * content_values
        * coverage
        * content_available.astype(float)
    )
    result["hybrid_available_weight"] = denominator
    result["hybrid_score"] = np.divide(
        numerator,
        denominator,
        out=np.zeros(len(result), dtype=float),
        where=denominator > 0,
    ).clip(0.0, 1.0)
    return result


def positive_compositions(total: int, parts: int) -> Iterable[Tuple[int, ...]]:
    if parts == 1:
        yield (total,)
        return
    for first in range(1, total - parts + 2):
        for rest in positive_compositions(total - first, parts - 1):
            yield (first,) + rest


def tune_weights(
    frame: pd.DataFrame,
    association_scores: np.ndarray,
    association_available: np.ndarray,
    svd_values: np.ndarray,
    svd_available: np.ndarray,
    content_values: np.ndarray,
    content_available: np.ndarray,
    coverage: np.ndarray,
    step: float,
) -> Tuple[Dict[str, float], Dict[str, Any]]:
    """Tune only the three required Hybrid components on Validation."""
    if step <= 0 or step >= 1:
        raise ValueError("--grid-step must be greater than 0 and less than 1")
    units = int(round(1.0 / step))
    if not np.isclose(units * step, 1.0):
        raise ValueError("--grid-step must divide 1.0 exactly, e.g. 0.1")

    best_weights: Optional[Dict[str, float]] = None
    best_metrics: Optional[Dict[str, Any]] = None
    best_key: Optional[Tuple[float, float, float]] = None

    for values in positive_compositions(units, 3):
        weights = {
            "association_rule": round(values[0] * step, 10),
            "svd": round(values[1] * step, 10),
            "content_based": round(values[2] * step, 10),
        }
        scored = hybrid_scores(
            frame,
            association_scores,
            association_available,
            svd_values,
            svd_available,
            content_values,
            content_available,
            coverage,
            weights,
        )
        metrics = rank_metrics(frame, scored["hybrid_score"].to_numpy())
        key = (
            float(metrics["ndcg@5"]),
            float(metrics["recall@5"]),
            float(metrics["mrr"]),
        )
        if best_key is None or key > best_key:
            best_key = key
            best_weights = weights
            best_metrics = metrics

    if best_weights is None or best_metrics is None:
        raise RuntimeError("Could not tune Hybrid weights")
    return best_weights, best_metrics


def comparison_row(
    name: str,
    metrics: Mapping[str, Any],
) -> Dict[str, Any]:
    return {
        "model": name,
        "queries": metrics.get("queries", 0),
        "precision_at_5": metrics.get("precision@5", 0.0),
        "recall_at_5": metrics.get("recall@5", 0.0),
        "ndcg_at_5": metrics.get("ndcg@5", 0.0),
        "mrr": metrics.get("mrr", 0.0),
    }


def validate_dataset(data: pd.DataFrame) -> None:
    missing = sorted(set(REQUIRED_COLUMNS) - set(data.columns))
    if missing:
        raise ValueError("Dataset is missing required columns: %s" % missing)
    if not set(data["split_type"].unique()).issubset(
        {"train", "val", "test"}
    ):
        raise ValueError("split_type must contain only train/val/test")
    if data.groupby("ma_tour")["split_type"].nunique().max() != 1:
        raise ValueError("A tour appears in multiple splits")
    if data.groupby("query_id")["split_type"].nunique().max() != 1:
        raise ValueError("A query appears in multiple splits")
    if data.groupby("query_id")[LABEL_COL].sum().ne(1).any():
        raise ValueError("Expected exactly one positive candidate per query")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--outdir", type=Path, default=DEFAULT_OUTDIR)
    parser.add_argument("--svd-components", type=int, default=20)
    parser.add_argument("--grid-step", type=float, default=0.1)
    args = parser.parse_args()

    dataset_path = args.dataset.resolve()
    outdir = args.outdir.resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    data = pd.read_csv(dataset_path, encoding="utf-8-sig")
    validate_dataset(data)

    semantic_values = sorted(
        column
        for column in data.columns
        if column.startswith(SEMANTIC_VALUE_PREFIX)
    )
    semantic_masks = sorted(
        column
        for column in data.columns
        if column.startswith(SEMANTIC_MASK_PREFIX)
    )
    if not semantic_values or len(semantic_values) != len(semantic_masks):
        raise ValueError("Expected paired semantic tag and mask columns")
    if {
        column[len(SEMANTIC_VALUE_PREFIX):]
        for column in semantic_values
    } != {
        column[len(SEMANTIC_MASK_PREFIX):]
        for column in semantic_masks
    }:
        raise ValueError("Semantic tag and mask columns are not paired")
    for column in semantic_values + semantic_masks:
        data[column] = pd.to_numeric(data[column], errors="raise")
    if not data[semantic_masks].isin([0, 1]).all().all():
        raise ValueError("Semantic mask columns must be binary")

    train = data[data["split_type"].eq("train")].copy()
    val = data[data["split_type"].eq("val")].copy()
    test = data[data["split_type"].eq("test")].copy()
    if min(len(train), len(val), len(test)) == 0:
        raise ValueError("Train, validation and test must be non-empty")

    rule_stats = fit_minmax_stats(
        train,
        ["max_support", "max_confidence", "max_lift"],
    )
    val_association, val_association_available = association_rule_scores(
        val,
        rule_stats,
    )
    test_association, test_association_available = association_rule_scores(
        test,
        rule_stats,
    )

    item_embeddings, svd_metadata = fit_svd_item_embeddings(
        train,
        args.svd_components,
    )
    val_svd, val_svd_available = svd_scores(val, item_embeddings)
    test_svd, test_svd_available = svd_scores(test, item_embeddings)

    val_content, val_content_available = content_based_scores(
        val,
        semantic_values,
        semantic_masks,
    )
    test_content, test_content_available = content_based_scores(
        test,
        semantic_values,
        semantic_masks,
    )
    val_coverage = semantic_coverage(val, semantic_masks)
    test_coverage = semantic_coverage(test, semantic_masks)

    weights, tuned_validation_metrics = tune_weights(
        val,
        val_association,
        val_association_available,
        val_svd,
        val_svd_available,
        val_content,
        val_content_available,
        val_coverage,
        args.grid_step,
    )
    val_hybrid = hybrid_scores(
        val,
        val_association,
        val_association_available,
        val_svd,
        val_svd_available,
        val_content,
        val_content_available,
        val_coverage,
        weights,
    )
    test_hybrid = hybrid_scores(
        test,
        test_association,
        test_association_available,
        test_svd,
        test_svd_available,
        test_content,
        test_content_available,
        test_coverage,
        weights,
    )

    validation_metrics = {
        "associationRules": rank_metrics(val, val_association),
        "svdMatrixFactorization": rank_metrics(val, val_svd),
        "contentBased": rank_metrics(val, val_content),
        "hybridRecommendationScore": rank_metrics(
            val,
            val_hybrid["hybrid_score"].to_numpy(),
        ),
    }
    test_metrics = {
        "associationRules": rank_metrics(test, test_association),
        "svdMatrixFactorization": rank_metrics(test, test_svd),
        "contentBased": rank_metrics(test, test_content),
        "hybridRecommendationScore": rank_metrics(
            test,
            test_hybrid["hybrid_score"].to_numpy(),
        ),
    }

    audit_columns = [
        "query_id",
        "ma_tour",
        "candidate_external_id",
        "candidate_canonical_name",
        "label",
        "split_type",
        "semantic_status",
        "semantic_runtime_eligible",
    ]
    audit = test[audit_columns].copy()
    audit["association_rule_score"] = test_association
    audit["association_rule_available"] = test_association_available.astype(int)
    audit["svd_score"] = test_svd
    audit["svd_available"] = test_svd_available.astype(int)
    audit["content_based_score"] = test_content
    audit["content_based_available"] = test_content_available.astype(int)
    for column in test_hybrid.columns:
        audit[column] = test_hybrid[column].to_numpy()
    audit.to_csv(
        outdir / "test_candidate_scores_research_v15_strict.csv",
        index=False,
        encoding="utf-8-sig",
    )

    comparison_validation = pd.DataFrame([
        comparison_row("Association Rules", validation_metrics["associationRules"]),
        comparison_row("SVD", validation_metrics["svdMatrixFactorization"]),
        comparison_row("Content-Based", validation_metrics["contentBased"]),
        comparison_row(
            "Hybrid Recommendation Score",
            validation_metrics["hybridRecommendationScore"],
        ),
    ])
    comparison_test = pd.DataFrame([
        comparison_row("Association Rules", test_metrics["associationRules"]),
        comparison_row("SVD", test_metrics["svdMatrixFactorization"]),
        comparison_row("Content-Based", test_metrics["contentBased"]),
        comparison_row(
            "Hybrid Recommendation Score",
            test_metrics["hybridRecommendationScore"],
        ),
    ])
    comparison_validation["split"] = "validation"
    comparison_test["split"] = "test"
    pd.concat(
        [comparison_validation, comparison_test],
        ignore_index=True,
    ).to_csv(
        outdir / "research_model_comparison_v15_strict.csv",
        index=False,
        encoding="utf-8-sig",
    )

    bundle = {
        "model_version": "gomate-ranker-research-v15-screen12-strict",
        "training_data_version": "ml-training-v12-semantic-v1",
        "semantic_data_version": "semantic-v1",
        "selected_strategy": "hybrid_recommendation_score_screen12",
        "selected_research_formula": "uncertainty_aware_hybrid_screen12",
        "hybrid_weights": weights,
        "hybrid_formula": (
            "(wA*A + wS*S + wC*u*C) / "
            "(wA*availableA + wS*availableS + wC*u*availableC)"
        ),
        "rule_normalization_stats": rule_stats,
        "svd_item_embeddings": item_embeddings,
        "svd_baseline": svd_metadata,
        "semantic_value_features": semantic_values,
        "semantic_mask_features": semantic_masks,
        "api_contract": "Keep the existing request and response JSON fields.",
        "screen3_policy": (
            "Backend calculates Spatial, Temporal and Group separately."
        ),
        "final_system_formula": (
            "FinalScore = 0.75*AIHybridScore + 0.25*BackendContextScore"
        ),
    }
    joblib.dump(
        bundle,
        outdir / "gomate_ranker_research_v15_strict.joblib",
        compress=3,
    )

    report = {
        "modelVersion": bundle["model_version"],
        "trainingDataVersion": bundle["training_data_version"],
        "semanticDataVersion": bundle["semantic_data_version"],
        "selectedModel": "Hybrid Recommendation Score",
        "baselineModels": [
            "Association Rules",
            "SVD Matrix Factorization",
            "Content-Based",
        ],
        "formula": bundle["hybrid_formula"],
        "hybridWeights": weights,
        "selectionRule": (
            "Select the three Hybrid weights on Validation by NDCG@5; "
            "report Test only after selection."
        ),
        "rowCounts": {
            key: int(value)
            for key, value in data["split_type"].value_counts().to_dict().items()
        },
        "queryCounts": {
            key: int(
                data.loc[data["split_type"].eq(key), "query_id"].nunique()
            )
            for key in ["train", "val", "test"]
        },
        "validation": validation_metrics,
        "validationSelectedWeightsMetrics": tuned_validation_metrics,
        "test": test_metrics,
        "scoreOwnership": {
            "aiScreen1And2": [
                "association_rule_score",
                "svd_score",
                "content_based_score",
                "semantic_coverage",
                "hybrid_score",
            ],
            "backendScreen3": [
                "spatial_score",
                "temporal_score",
                "group_score",
            ],
            "screen3FeaturesUsedInTrainer": [],
            "randomForestUsed": False,
            "popularityModelUsed": False,
        },
        "finalSystemFormula": bundle["final_system_formula"],
        "apiContract": bundle["api_contract"],
        "limitations": [
            "The frozen training release has no query-level survey answers.",
            "Screen-3 runtime signals are owned by Backend.",
            "The offline metrics in this report evaluate the AI screen-1-2 "
            "component; end-to-end metrics require Backend replay scores."
        ],
    }
    report_path = outdir / "training_report_research_v15_strict.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(json.dumps({
        "modelVersion": report["modelVersion"],
        "selectedModel": report["selectedModel"],
        "hybridWeights": report["hybridWeights"],
        "validation": validation_metrics["hybridRecommendationScore"],
        "test": test_metrics["hybridRecommendationScore"],
        "outputDirectory": str(outdir),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
