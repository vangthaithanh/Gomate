#!/usr/bin/env python3
"""Train and compare the v11 Random Forest ranker with semantic-v1 place features."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.decomposition import TruncatedSVD
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


ROOT = Path(__file__).resolve().parent
DEFAULT_DATASET = ROOT / "ml_training_dataset_v12_semantic_v1.csv"
DEFAULT_OUTDIR = ROOT / "training_output"

CAT_FEATURES = ["destination_key", "candidate_category"]
NUMERIC_FEATURES = [
    "so_ngay", "so_dem", "gia_tu_scaled", "day_index", "num_selected_places",
    "candidate_popularity", "candidate_is_core", "category_frequency", "same_category_count",
    "has_direct_rule", "max_support", "max_confidence", "max_lift", "max_rule_score", "is_ar_candidate",
]
BASE_FEATURES = CAT_FEATURES + NUMERIC_FEATURES
SEMANTIC_VALUE_PREFIX = "sem_tag__"
SEMANTIC_MASK_PREFIX = "sem_mask__"
LABEL_COL = "label"
HYBRID_WEIGHTS = {
    "association_rule": 0.20,
    "content_based": 0.30,
    "ml_ranker": 0.30,
    "popularity": 0.10,
    "spatial": 0.05,
    "temporal": 0.03,
    "group": 0.02,
}
HYBRID_AVAILABLE_OFFLINE = {
    "association_rule": True,
    "content_based": True,
    "ml_ranker": True,
    "popularity": True,
    "spatial": False,
    "temporal": False,
    "group": True,
}


def make_pipeline(numeric_features: list[str], categorical_features: list[str], trees: int) -> Pipeline:
    numeric = Pipeline([("impute", SimpleImputer(strategy="median"))])
    categorical = Pipeline([("impute", SimpleImputer(strategy="most_frequent")),
                            ("onehot", OneHotEncoder(handle_unknown="ignore"))])
    prep = ColumnTransformer([
        ("numeric", numeric, numeric_features),
        ("categorical", categorical, categorical_features),
    ], remainder="drop")
    model = RandomForestClassifier(
        n_estimators=trees,
        min_samples_leaf=2,
        max_features="sqrt",
        class_weight="balanced_subsample",
        random_state=42,
        n_jobs=-1,
    )
    return Pipeline([("features", prep), ("ranker", model)])


def predict_positive(model: Pipeline, frame: pd.DataFrame, feature_cols: list[str]) -> np.ndarray:
    return model.predict_proba(frame[feature_cols])[:, 1]


def rank_metrics(frame: pd.DataFrame, scores: np.ndarray, ks: tuple[int, ...] = (3, 5, 10)) -> dict[str, float | int]:
    scored = frame[["query_id", "candidate_external_id", LABEL_COL]].copy()
    scored["score"] = scores
    result: dict[str, float | int] = {"queries": int(scored["query_id"].nunique())}
    per_k: dict[int, list[tuple[float, float, float]]] = {k: [] for k in ks}
    reciprocal_ranks: list[float] = []

    for _, group in scored.groupby("query_id", sort=False):
        group = group.sort_values(["score", "candidate_external_id"], ascending=[False, True], kind="stable")
        labels = group[LABEL_COL].astype(int).to_numpy()
        positive_count = int(labels.sum())
        if positive_count == 0:
            continue
        positive_ranks = np.flatnonzero(labels == 1)
        reciprocal_ranks.append(1.0 / (int(positive_ranks[0]) + 1))
        for k in ks:
            top_labels = labels[:k]
            hits = float(top_labels.sum())
            precision = hits / k
            recall = hits / positive_count
            discounts = 1.0 / np.log2(np.arange(2, len(top_labels) + 2))
            dcg = float((top_labels * discounts).sum())
            ideal_len = min(positive_count, k)
            idcg = float((1.0 / np.log2(np.arange(2, ideal_len + 2))).sum())
            ndcg = dcg / idcg if idcg else 0.0
            per_k[k].append((precision, recall, ndcg))

    for k, values in per_k.items():
        result[f"precision@{k}"] = float(np.mean([v[0] for v in values])) if values else 0.0
        result[f"recall@{k}"] = float(np.mean([v[1] for v in values])) if values else 0.0
        result[f"ndcg@{k}"] = float(np.mean([v[2] for v in values])) if values else 0.0
    result["mrr"] = float(np.mean(reciprocal_ranks)) if reciprocal_ranks else 0.0
    return result


def minmax(values: pd.Series) -> pd.Series:
    numeric = pd.to_numeric(values, errors="coerce").fillna(0.0)
    low = float(numeric.min())
    high = float(numeric.max())
    if high <= low:
        return pd.Series(np.zeros(len(numeric)), index=numeric.index, dtype=float)
    return (numeric - low) / (high - low)


def normalized_rule_score(frame: pd.DataFrame) -> pd.Series:
    support = minmax(frame["max_support"])
    confidence = minmax(frame["max_confidence"])
    lift = minmax(frame["max_lift"])
    direct = pd.to_numeric(frame["has_direct_rule"], errors="coerce").fillna(0.0).clip(0, 1)
    fallback = pd.to_numeric(frame["max_rule_score"], errors="coerce").fillna(0.0).clip(0, 1)
    score = 0.20 * support + 0.35 * confidence + 0.25 * lift + 0.20 * direct
    return np.maximum(score, fallback).clip(0, 1)


def semantic_matrix(frame: pd.DataFrame, sem_values: list[str], sem_masks: list[str]) -> np.ndarray:
    values = frame[sem_values].to_numpy(dtype=float)
    masks = frame[sem_masks].to_numpy(dtype=float)
    return values * masks


def query_position(query_id: object) -> tuple[int, int, str]:
    match = re.search(r"_day_(\d+)_pos_(\d+)", str(query_id))
    if not match:
        return (0, 0, str(query_id))
    return (int(match.group(1)), int(match.group(2)), str(query_id))


def content_scores_by_tour(frame: pd.DataFrame, sem_values: list[str], sem_masks: list[str]) -> np.ndarray:
    """Cosine score against the semantic profile of previous positive places in the same tour."""
    if not sem_values:
        return np.zeros(len(frame), dtype=float)
    vectors = semantic_matrix(frame, sem_values, sem_masks)
    scores = np.zeros(len(frame), dtype=float)
    row_positions = pd.Series(np.arange(len(frame)), index=frame.index)

    for _, tour_frame in frame.groupby("ma_tour", sort=False):
        positives = tour_frame[tour_frame[LABEL_COL].astype(int).eq(1)].drop_duplicates("query_id").copy()
        if positives.empty:
            continue
        positives["_query_order"] = positives["query_id"].map(query_position)
        positives = positives.sort_values("_query_order", kind="stable")
        previous_vectors: list[np.ndarray] = []
        profiles: dict[str, np.ndarray] = {}
        for row in positives.itertuples():
            if previous_vectors:
                profiles[str(row.query_id)] = np.mean(previous_vectors, axis=0)
            previous_vectors.append(vectors[int(row_positions.loc[row.Index])])

        for query_id, tour_profile in profiles.items():
            query_rows = tour_frame[tour_frame["query_id"].astype(str).eq(query_id)]
            group_positions = row_positions.loc[query_rows.index].to_numpy()
            profile_norm = float(np.linalg.norm(tour_profile))
            if profile_norm <= 0:
                continue
            candidate_vectors = vectors[group_positions]
            candidate_norm = np.linalg.norm(candidate_vectors, axis=1)
            denom = candidate_norm * profile_norm
            cosine = np.divide(
                candidate_vectors @ tour_profile,
                denom,
                out=np.zeros(len(group_positions), dtype=float),
                where=denom > 0,
            )
            scores[group_positions] = np.clip(cosine, 0, 1)
    return scores


def fit_svd_item_embeddings(train: pd.DataFrame, components: int = 20) -> tuple[dict[str, np.ndarray], dict[str, object]]:
    positives = train[train[LABEL_COL].astype(int).eq(1)]
    tours = sorted(positives["ma_tour"].astype(str).unique())
    items = sorted(positives["candidate_external_id"].astype(str).unique())
    if len(tours) < 2 or len(items) < 2:
        return {}, {"status": "skipped", "reason": "not enough tours or items"}

    tour_index = {tour: i for i, tour in enumerate(tours)}
    item_index = {item: i for i, item in enumerate(items)}
    matrix = np.zeros((len(tours), len(items)), dtype=float)
    for row in positives.itertuples(index=False):
        matrix[tour_index[str(row.ma_tour)], item_index[str(row.candidate_external_id)]] = 1.0

    n_components = max(1, min(components, matrix.shape[0] - 1, matrix.shape[1] - 1))
    svd = TruncatedSVD(n_components=n_components, random_state=42)
    svd.fit(matrix)
    item_vectors = svd.components_.T
    embeddings = {item: item_vectors[idx] for item, idx in item_index.items()}
    metadata = {
        "status": "fit",
        "matrix": "train Tour x POI",
        "tours": len(tours),
        "items": len(items),
        "components": int(n_components),
        "explained_variance_ratio_sum": float(svd.explained_variance_ratio_.sum()),
        "runtime_scoring": "cosine between candidate item vector and previous-place profile; unseen or no-history queries score 0",
    }
    return embeddings, metadata


def svd_scores_by_previous_places(frame: pd.DataFrame, item_embeddings: dict[str, np.ndarray]) -> np.ndarray:
    scores = np.zeros(len(frame), dtype=float)
    if not item_embeddings:
        return scores
    row_positions = pd.Series(np.arange(len(frame)), index=frame.index)

    for _, tour_frame in frame.groupby("ma_tour", sort=False):
        positives = tour_frame[tour_frame[LABEL_COL].astype(int).eq(1)].drop_duplicates("query_id").copy()
        if positives.empty:
            continue
        positives["_query_order"] = positives["query_id"].map(query_position)
        positives = positives.sort_values("_query_order", kind="stable")
        previous_vectors: list[np.ndarray] = []
        profiles: dict[str, np.ndarray] = {}
        for row in positives.itertuples():
            if previous_vectors:
                profiles[str(row.query_id)] = np.mean(previous_vectors, axis=0)
            vector = item_embeddings.get(str(row.candidate_external_id))
            if vector is not None:
                previous_vectors.append(vector)

        for query_id, profile in profiles.items():
            query_rows = tour_frame[tour_frame["query_id"].astype(str).eq(query_id)]
            profile_norm = float(np.linalg.norm(profile))
            if profile_norm <= 0:
                continue
            for idx, candidate_id in zip(query_rows.index, query_rows["candidate_external_id"].astype(str)):
                candidate_vector = item_embeddings.get(candidate_id)
                if candidate_vector is None:
                    continue
                denom = float(np.linalg.norm(candidate_vector) * profile_norm)
                if denom <= 0:
                    continue
                cosine = float(candidate_vector @ profile / denom)
                scores[int(row_positions.loc[idx])] = np.clip((cosine + 1.0) / 2.0, 0, 1)
    return scores


def context_scores(frame: pd.DataFrame) -> tuple[pd.Series, pd.Series, pd.Series]:
    """Offline proxies only. Runtime distance, traffic, opening time, and live group votes belong to Backend."""
    spatial = pd.Series(0.0, index=frame.index, dtype=float)
    temporal = pd.Series(0.0, index=frame.index, dtype=float)
    same_category = minmax(frame["same_category_count"])
    selected_places = minmax(frame["num_selected_places"])
    group = (0.60 * same_category + 0.40 * selected_places).clip(0, 1)
    return spatial, temporal, group


def hybrid_formula_scores(frame: pd.DataFrame, ml_scores: np.ndarray, sem_values: list[str], sem_masks: list[str]) -> pd.DataFrame:
    scores = pd.DataFrame(index=frame.index)
    scores["association_rule_score"] = normalized_rule_score(frame)
    scores["content_based_score"] = content_scores_by_tour(frame, sem_values, sem_masks)
    scores["ml_ranker_score"] = pd.Series(ml_scores, index=frame.index).clip(0, 1)
    scores["popularity_score"] = pd.to_numeric(frame["candidate_popularity"], errors="coerce").fillna(0.0).clip(0, 1)
    scores["spatial_score"], scores["temporal_score"], scores["group_score"] = context_scores(frame)
    available_weight = sum(weight for name, weight in HYBRID_WEIGHTS.items() if HYBRID_AVAILABLE_OFFLINE[name])
    weighted_sum = sum(
        HYBRID_WEIGHTS[name] * scores[f"{name}_score"]
        for name in HYBRID_WEIGHTS
        if HYBRID_AVAILABLE_OFFLINE[name]
    )
    scores["hybrid_available_weight"] = available_weight
    scores["hybrid_recommendation_score"] = (weighted_sum / available_weight).clip(0, 1)
    return scores


def semantic_fallback_scores(
    frame: pd.DataFrame,
    base_model: Pipeline,
    semantic_model: Pipeline,
    base_features: list[str],
    semantic_features: list[str],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    base_scores = predict_positive(base_model, frame, base_features)
    mixed_scores = base_scores.copy()
    usable = frame["semantic_status"].isin(["READY", "PARTIAL"]).to_numpy()
    if usable.any():
        mixed_scores[usable] = predict_positive(semantic_model, frame.loc[usable], semantic_features)
    return base_scores, mixed_scores, usable


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--outdir", type=Path, default=DEFAULT_OUTDIR)
    parser.add_argument("--trees", type=int, default=200)
    args = parser.parse_args()

    dataset_path = args.dataset.resolve()
    outdir = args.outdir.resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    data = pd.read_csv(dataset_path, encoding="utf-8-sig")
    required = set(BASE_FEATURES + [LABEL_COL, "query_id", "ma_tour", "split_type", "candidate_external_id", "semantic_status"])
    missing = sorted(required - set(data.columns))
    if missing:
        raise ValueError(f"Dataset is missing required columns: {missing}")
    if not set(data["split_type"].unique()).issubset({"train", "val", "test"}):
        raise ValueError("split_type must contain only train/val/test")
    if data.groupby("ma_tour")["split_type"].nunique().max() != 1:
        raise ValueError("A tour appears in multiple splits; this would leak tour information")
    if data.groupby("query_id")["split_type"].nunique().max() != 1:
        raise ValueError("A query appears in multiple splits")
    if data.groupby("query_id")[LABEL_COL].sum().ne(1).any():
        raise ValueError("Expected exactly one positive candidate per query, as in v11")

    semantic_features = [c for c in data.columns if c.startswith((SEMANTIC_VALUE_PREFIX, SEMANTIC_MASK_PREFIX))]
    sem_values = [c for c in semantic_features if c.startswith(SEMANTIC_VALUE_PREFIX)]
    sem_masks = [c for c in semantic_features if c.startswith(SEMANTIC_MASK_PREFIX)]
    if not sem_values or len(sem_values) != len(sem_masks):
        raise ValueError("Expected paired semantic tag and mask columns")
    for col in sem_values + sem_masks:
        data[col] = pd.to_numeric(data[col], errors="raise")
    if not data[sem_masks].isin([0, 1]).all().all():
        raise ValueError("Semantic mask columns must be binary")

    train = data[data["split_type"].eq("train")].copy()
    val = data[data["split_type"].eq("val")].copy()
    test = data[data["split_type"].eq("test")].copy()
    if min(len(train), len(val), len(test)) == 0:
        raise ValueError("Train, validation, and test splits must all be non-empty")

    base_model = make_pipeline(NUMERIC_FEATURES, CAT_FEATURES, args.trees)
    base_model.fit(train[BASE_FEATURES], train[LABEL_COL].astype(int))

    sem_train = train[train["semantic_status"].isin(["READY", "PARTIAL"])].copy()
    if sem_train.empty or sem_train[LABEL_COL].nunique() < 2:
        raise ValueError("Not enough READY/PARTIAL training rows for the semantic ranker")
    semantic_model = make_pipeline(NUMERIC_FEATURES + semantic_features, CAT_FEATURES, args.trees)
    semantic_model.fit(sem_train[NUMERIC_FEATURES + semantic_features + CAT_FEATURES], sem_train[LABEL_COL].astype(int))

    val_base, val_semantic, _ = semantic_fallback_scores(val, base_model, semantic_model, BASE_FEATURES, NUMERIC_FEATURES + semantic_features + CAT_FEATURES)
    test_base, test_semantic, test_sem_usable = semantic_fallback_scores(test, base_model, semantic_model, BASE_FEATURES, NUMERIC_FEATURES + semantic_features + CAT_FEATURES)
    val_base_metrics = rank_metrics(val, val_base)
    val_semantic_metrics = rank_metrics(val, val_semantic)
    selected_strategy = "semantic_v1_with_legacy_fallback" if val_semantic_metrics["ndcg@5"] > val_base_metrics["ndcg@5"] else "legacy_v11_ranker"
    test_selected = test_semantic if selected_strategy == "semantic_v1_with_legacy_fallback" else test_base

    svd_item_embeddings, svd_metadata = fit_svd_item_embeddings(train)
    val_svd = svd_scores_by_previous_places(val, svd_item_embeddings)
    test_svd = svd_scores_by_previous_places(test, svd_item_embeddings)
    val_hybrid_scores = hybrid_formula_scores(val, val_semantic, sem_values, sem_masks)
    test_hybrid_scores = hybrid_formula_scores(test, test_semantic, sem_values, sem_masks)
    val_formula_metrics = {
        "associationRules": rank_metrics(val, val_hybrid_scores["association_rule_score"].to_numpy()),
        "svdMatrixFactorization": rank_metrics(val, val_svd),
        "contentBased": rank_metrics(val, val_hybrid_scores["content_based_score"].to_numpy()),
        "hybridFormula": rank_metrics(val, val_hybrid_scores["hybrid_recommendation_score"].to_numpy()),
    }
    test_formula_metrics = {
        "associationRules": rank_metrics(test, test_hybrid_scores["association_rule_score"].to_numpy()),
        "svdMatrixFactorization": rank_metrics(test, test_svd),
        "contentBased": rank_metrics(test, test_hybrid_scores["content_based_score"].to_numpy()),
        "hybridFormula": rank_metrics(test, test_hybrid_scores["hybrid_recommendation_score"].to_numpy()),
    }

    test_base_metrics = rank_metrics(test, test_base)
    test_semantic_metrics = rank_metrics(test, test_semantic)
    test_selected_metrics = rank_metrics(test, test_selected)
    scores = test[[
        "query_id", "ma_tour", "candidate_external_id", "candidate_canonical_name",
        "label", "split_type", "semantic_status", "semantic_runtime_eligible",
    ]].copy()
    scores["legacy_ml_score"] = test_base
    scores["semantic_ranker_with_fallback_score"] = test_semantic
    scores["semantic_model_used"] = test_sem_usable
    scores["selected_ml_score"] = test_selected
    scores["svd_score"] = test_svd
    for col in test_hybrid_scores.columns:
        scores[col] = test_hybrid_scores[col].to_numpy()
    scores.to_csv(outdir / "test_candidate_scores_v12_semantic_v1.csv", index=False, encoding="utf-8-sig")

    bundle = {
        "model_version": "gomate-ranker-v12-semantic-v1",
        "training_data_version": "ml-training-v12-semantic-v1",
        "semantic_data_version": "semantic-v1",
        "selected_strategy": selected_strategy,
        "base_features": BASE_FEATURES,
        "semantic_value_features": sem_values,
        "semantic_mask_features": sem_masks,
        "semantic_features": NUMERIC_FEATURES + semantic_features + CAT_FEATURES,
        "base_model": base_model,
        "semantic_model": semantic_model,
        "need_review_policy": "fallback to base_model; no semantic model score",
        "screen3_policy": "not included; Backend contextual re-ranking owns distance, route time, review and live hot signals",
        "hybrid_weights": HYBRID_WEIGHTS,
        "hybrid_available_offline": HYBRID_AVAILABLE_OFFLINE,
        "svd_baseline": svd_metadata,
    }
    joblib.dump(bundle, outdir / "gomate_ranker_v12_semantic_v1.joblib", compress=3)

    report = {
        "modelVersion": bundle["model_version"],
        "trainingDataVersion": bundle["training_data_version"],
        "semanticDataVersion": bundle["semantic_data_version"],
        "selectedStrategy": selected_strategy,
        "selectionMetric": "validation NDCG@5",
        "estimator": {
            "type": "RandomForestClassifier",
            "trees": args.trees,
            "min_samples_leaf": 2,
            "max_features": "sqrt",
            "class_weight": "balanced_subsample",
            "random_state": 42,
        },
        "rowCounts": {k: int(v) for k, v in data["split_type"].value_counts().to_dict().items()},
        "queryCounts": {k: int(data.loc[data["split_type"].eq(k), "query_id"].nunique()) for k in ["train", "val", "test"]},
        "semanticFitRows": int(len(sem_train)),
        "semanticFitStatusCounts": {str(k): int(v) for k, v in sem_train["semantic_status"].value_counts().to_dict().items()},
        "features": {
            "legacy": BASE_FEATURES,
            "semanticValues": sem_values,
            "semanticMasks": sem_masks,
            "metadataExcluded": ["query_id", "ma_tour", "candidate_external_id", "candidate_canonical_name", "split_type", "label", "semantic_status", "semantic_runtime_eligible", "semantic_tag_count", "semantic_data_version"],
        },
        "validation": {"legacy": val_base_metrics, "semanticWithFallback": val_semantic_metrics},
        "formulaBaselines": {
            "validation": val_formula_metrics,
            "test": test_formula_metrics,
            "weights": HYBRID_WEIGHTS,
            "availableOffline": HYBRID_AVAILABLE_OFFLINE,
            "formula": "HybridScore(q,i) = sum(w_m * score_m(q,i) for available m) / sum(w_m for available m)",
            "svdBaseline": svd_metadata,
            "contentBasedOfflineProxy": "Cosine similarity between candidate semantic vector and the previous-positive-place semantic profile in the same historical tour. At runtime cold-start, Backend should replace this profile with the Screen 1-2 survey semantic vector.",
            "spatialTemporalOfflineProxy": "Not included in offline HybridScore because v11 has no distance, route time, current time, opening hour, or traffic columns. Backend owns these runtime signals.",
            "groupOfflineProxy": "Proxy from same_category_count and num_selected_places because v11 has no explicit group member preference columns.",
        },
        "test": {"legacy": test_base_metrics, "semanticWithFallback": test_semantic_metrics, "selected": test_selected_metrics},
        "surveyQueryPreferencesPresent": False,
        "semanticScope": "Candidate-place tags are included; survey-conditioned ContentScore remains a separate deterministic cold-start component because v11 has no query-level survey answers.",
        "scoreOwnership": {
            "includedHistoricalPopularityFeature": "candidate_popularity (also candidate_is_core and category_frequency)",
            "associationRuleFeatures": ["has_direct_rule", "max_support", "max_confidence", "max_lift", "max_rule_score", "is_ar_candidate"],
            "distanceKmIncluded": False,
            "reviewCountOrRatingIncluded": False,
            "screen3ContextIncluded": False,
        },
    }
    (outdir / "training_report_v12_semantic_v1.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
