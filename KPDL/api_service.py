#!/usr/bin/env python3
"""FastAPI wrapper for GoMate cold-start recommendation.

The service keeps the public `/recommend` contract stable for Spring while the
runtime model moves from the deterministic semantic-v1 scorer to the research
v13 ranker bundle. Screen 3 context codes are still returned to Spring for
backend-side reranking.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from semantic_content_score_v1 import score_places


ROOT = Path(__file__).resolve().parent
V12_MODEL_PATH = ROOT / "training_output" / "gomate_ranker_v12_semantic_v1.joblib"
V13_MODEL_PATH = ROOT / "training_output_research_final" / "gomate_ranker_research_v13.joblib"
V13_TRAINING_FRAME = ROOT / "ml_training_dataset_v12_semantic_v1.csv"
V13_REPORT_PATH = ROOT / "training_output_research_final" / "training_report_research_v13.json"

CAT_FEATURES = {"destination_key", "candidate_category"}
UNCERTAINTY_WEIGHTS = {
    "association_rule": 0.20,
    "content_based": 0.30,
    "ml_ranker": 0.30,
    "popularity": 0.10,
}

app = FastAPI(
    title="GoMate AI Recommendation Service",
    version="gomate-ranker-research-v13",
)


class RecommendRequest(BaseModel):
    destination_key: str | None = Field(default=None, examples=["da_lat"])
    selected_interest_codes: list[str] = Field(
        min_length=1,
        examples=[["THIEN_NHIEN", "CHECKIN_HOT", "BIEN_NUI"]],
    )
    context_codes: list[str] = Field(default_factory=list, examples=[["GAN_TOI", "DANG_HOT"]])
    top_k: int = Field(default=10, ge=1, le=100)
    include_runtime_ineligible: bool = False


class RecommendItem(BaseModel):
    rank: int
    external_id: str
    name: str
    destination_key: str
    category: str
    semantic_status: str
    semantic_score: float | None
    semantic_score_upper: float | None
    semantic_coverage: float
    semantic_signal_available: bool


class RecommendResponse(BaseModel):
    model_version: str
    selected_strategy: str | None
    destination_key: str | None
    selected_interest_codes: list[str]
    context_codes_received: list[str]
    context_note: str
    total_candidates: int
    items: list[RecommendItem]


@lru_cache(maxsize=1)
def load_model_bundle() -> dict[str, Any] | None:
    if not V13_MODEL_PATH.exists():
        return None
    bundle = joblib.load(V13_MODEL_PATH)
    return bundle if isinstance(bundle, dict) else None


@lru_cache(maxsize=1)
def load_model_metadata() -> dict[str, Any]:
    bundle = load_model_bundle()
    if bundle:
        return {
            "model_version": bundle.get("model_version"),
            "selected_strategy": bundle.get("selected_strategy"),
            "selected_research_formula": bundle.get("selected_research_formula"),
            "semantic_data_version": bundle.get("semantic_data_version"),
            "model_path": V13_MODEL_PATH.name,
        }
    if V12_MODEL_PATH.exists():
        legacy = joblib.load(V12_MODEL_PATH)
        if isinstance(legacy, dict):
            return {
                "model_version": legacy.get("model_version", "gomate-ranker-v12-semantic-v1"),
                "selected_strategy": legacy.get("selected_strategy"),
                "semantic_data_version": legacy.get("semantic_data_version"),
                "model_path": V12_MODEL_PATH.name,
            }
    return {}


@lru_cache(maxsize=1)
def candidate_feature_defaults() -> pd.DataFrame:
    bundle = load_model_bundle()
    if not bundle or not V13_TRAINING_FRAME.exists():
        return pd.DataFrame()

    feature_columns = list(dict.fromkeys(
        [
            "candidate_external_id",
            "candidate_canonical_name",
            "semantic_status",
            *bundle.get("base_features", []),
            *bundle.get("semantic_features", []),
        ]
    ))
    data = pd.read_csv(
        V13_TRAINING_FRAME,
        encoding="utf-8-sig",
        usecols=lambda col: col in feature_columns,
    )
    if data.empty:
        return data

    rows: list[dict[str, Any]] = []
    for external_id, group in data.groupby("candidate_external_id", sort=False):
        row: dict[str, Any] = {"candidate_external_id": external_id}
        for column in feature_columns:
            if column == "candidate_external_id":
                continue
            values = group[column] if column in group.columns else pd.Series(dtype=object)
            if column in CAT_FEATURES or values.dtype == object:
                row[column] = first_non_empty(values)
            else:
                numeric = pd.to_numeric(values, errors="coerce").dropna()
                row[column] = float(numeric.median()) if not numeric.empty else 0.0
        rows.append(row)
    return pd.DataFrame(rows)


def first_non_empty(values: pd.Series) -> str:
    for value in values:
        if pd.notna(value) and str(value).strip():
            return str(value)
    return ""


def build_v13_frame(scores: pd.DataFrame, bundle: dict[str, Any]) -> pd.DataFrame:
    defaults = candidate_feature_defaults()
    if defaults.empty:
        frame = scores[["external_id", "canonical_name", "destination_key", "category"]].copy()
        frame["candidate_external_id"] = frame["external_id"].astype(str)
    else:
        frame = scores.merge(
            defaults,
            left_on="external_id",
            right_on="candidate_external_id",
            how="left",
            sort=False,
        )

    frame["candidate_external_id"] = frame["external_id"].astype(str)
    frame["candidate_canonical_name"] = frame.get("canonical_name", scores["canonical_name"]).astype(str)
    frame["destination_key"] = frame.get("destination_key", scores["destination_key"]).fillna(scores["destination_key"]).astype(str)
    frame["candidate_category"] = frame.get("candidate_category", scores["category"]).fillna(scores["category"]).astype(str)
    frame["semantic_status"] = scores["semantic_status"].astype(str)

    all_features = list(dict.fromkeys([
        *bundle.get("base_features", []),
        *bundle.get("semantic_features", []),
    ]))
    for column in all_features:
        if column not in frame.columns:
            frame[column] = "" if column in CAT_FEATURES else 0.0
        elif column not in CAT_FEATURES:
            frame[column] = pd.to_numeric(frame[column], errors="coerce").fillna(0.0)
        else:
            frame[column] = frame[column].fillna("").astype(str)
    return frame


def v13_ml_scores(frame: pd.DataFrame, bundle: dict[str, Any]) -> np.ndarray:
    base_features = bundle.get("base_features", [])
    semantic_features = bundle.get("semantic_features", [])
    base_model = bundle.get("base_model")
    semantic_model = bundle.get("semantic_model")
    if not base_features or base_model is None:
        return np.zeros(len(frame), dtype=float)

    base_scores = base_model.predict_proba(frame[base_features])[:, 1]
    selected_strategy = str(bundle.get("selected_strategy", "legacy_v11_ranker"))
    if (
        selected_strategy != "semantic_v1_with_legacy_fallback"
        or semantic_model is None
        or not semantic_features
    ):
        return base_scores

    mixed = base_scores.copy()
    usable = frame["semantic_status"].isin(["READY", "PARTIAL"]).to_numpy()
    if usable.any():
        mixed[usable] = semantic_model.predict_proba(frame.loc[usable, semantic_features])[:, 1]
    return mixed


def normalized_rule_score(frame: pd.DataFrame) -> pd.Series:
    support = minmax(frame.get("max_support", 0.0))
    confidence = minmax(frame.get("max_confidence", 0.0))
    lift = minmax(frame.get("max_lift", 0.0))
    direct = numeric_series(frame.get("has_direct_rule", 0.0)).clip(0, 1)
    fallback = numeric_series(frame.get("max_rule_score", 0.0)).clip(0, 1)
    score = 0.20 * support + 0.35 * confidence + 0.25 * lift + 0.20 * direct
    return np.maximum(score, fallback).clip(0, 1)


def minmax(values: Any) -> pd.Series:
    numeric = numeric_series(values)
    low = float(numeric.min()) if len(numeric) else 0.0
    high = float(numeric.max()) if len(numeric) else 0.0
    if high <= low:
        return pd.Series(np.zeros(len(numeric)), index=numeric.index, dtype=float)
    return (numeric - low) / (high - low)


def numeric_series(values: Any) -> pd.Series:
    if isinstance(values, pd.Series):
        return pd.to_numeric(values, errors="coerce").fillna(0.0)
    return pd.Series(values).pipe(pd.to_numeric, errors="coerce").fillna(0.0)


def uncertainty_hybrid_scores(
    frame: pd.DataFrame,
    semantic_scores: pd.DataFrame,
    ml_scores: np.ndarray,
) -> pd.Series:
    rule = normalized_rule_score(frame)
    content = pd.to_numeric(semantic_scores["semantic_score"], errors="coerce").fillna(0.0).clip(0, 1)
    coverage = pd.to_numeric(semantic_scores["semantic_coverage"], errors="coerce").fillna(0.0).clip(0, 1)
    ml = pd.Series(ml_scores, index=frame.index).clip(0, 1)
    popularity = numeric_series(frame.get("candidate_popularity", 0.0)).clip(0, 1)

    w_rule = UNCERTAINTY_WEIGHTS["association_rule"]
    w_content = UNCERTAINTY_WEIGHTS["content_based"]
    w_ml = UNCERTAINTY_WEIGHTS["ml_ranker"]
    w_popularity = UNCERTAINTY_WEIGHTS["popularity"]
    numerator = w_rule * rule + w_content * content * coverage + w_ml * ml + w_popularity * popularity
    denominator = w_rule + w_content * coverage + w_ml + w_popularity
    return (numerator / denominator.replace(0, np.nan)).fillna(0.0).clip(0, 1)


def rank_with_v13(scores: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, Any]]:
    bundle = load_model_bundle()
    if not bundle:
        scores = scores.copy()
        scores["final_score"] = pd.to_numeric(scores["semantic_score"], errors="coerce").fillna(0.0)
        return scores, {"model_source": "semantic-v1-fallback"}

    frame = build_v13_frame(scores, bundle)
    ml_scores = v13_ml_scores(frame, bundle)
    ranked = scores.copy()
    ranked["ml_ranker_score"] = ml_scores
    ranked["final_score"] = uncertainty_hybrid_scores(frame, scores, ml_scores)
    ranked = ranked.sort_values(
        ["final_score", "external_id"],
        ascending=[False, True],
        kind="stable",
    ).reset_index(drop=True)
    return ranked, {
        "model_source": "research-v13",
        "selected_strategy": bundle.get("selected_strategy"),
        "selected_research_formula": bundle.get("selected_research_formula"),
    }


MODEL_META = load_model_metadata()


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": load_model_bundle() is not None,
        "model_path": MODEL_META.get("model_path", V13_MODEL_PATH.name),
        "model_version": MODEL_META.get("model_version", "gomate-ranker-research-v13"),
        "selected_strategy": MODEL_META.get("selected_strategy"),
        "selected_research_formula": MODEL_META.get("selected_research_formula"),
        "semantic_data_version": MODEL_META.get("semantic_data_version"),
        "training_report_available": V13_REPORT_PATH.exists(),
    }


@app.post("/recommend", response_model=RecommendResponse)
def recommend(request: RecommendRequest) -> RecommendResponse:
    try:
        semantic_scores = score_places(
            interest_codes=request.selected_interest_codes,
            destination_key=request.destination_key,
            runtime_only=not request.include_runtime_ineligible,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    ranked, rank_meta = rank_with_v13(semantic_scores)
    top = ranked.head(request.top_k).copy()
    items = [
        RecommendItem(
            rank=index + 1,
            external_id=str(row.external_id),
            name=str(row.canonical_name),
            destination_key=str(row.destination_key),
            category=str(row.category),
            semantic_status=str(row.semantic_status),
            semantic_score=None if row.final_score != row.final_score else float(row.final_score),
            semantic_score_upper=None
            if row.semantic_score_upper != row.semantic_score_upper
            else float(row.semantic_score_upper),
            semantic_coverage=float(row.semantic_coverage),
            semantic_signal_available=bool(row.semantic_signal_available),
        )
        for index, row in enumerate(top.itertuples(index=False))
    ]

    selected_strategy = rank_meta.get("selected_strategy") or MODEL_META.get("selected_strategy")
    selected_formula = rank_meta.get("selected_research_formula") or MODEL_META.get("selected_research_formula")
    return RecommendResponse(
        model_version=MODEL_META.get("model_version", "gomate-ranker-research-v13"),
        selected_strategy=(
            f"{selected_strategy}/{selected_formula}"
            if selected_formula
            else selected_strategy
        ),
        destination_key=request.destination_key,
        selected_interest_codes=request.selected_interest_codes,
        context_codes_received=request.context_codes,
        context_note=(
            "AI runtime uses GoMate Ranker v13 plus uncertaintyHybrid. "
            "Screen 3 context codes remain Spring Backend reranking inputs."
        ),
        total_candidates=int(len(ranked)),
        items=items,
    )
