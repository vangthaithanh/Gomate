#!/usr/bin/env python3
"""FastAPI wrapper for GoMate semantic-v1 cold-start recommendation."""

from __future__ import annotations

import os
import json
from functools import lru_cache
from pathlib import Path
from typing import Any

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from semantic_content_score_v1 import score_places
from history_hybrid import (
    apply_hybrid,
    build_pair_rule_index,
    score_association_rules,
    score_svd_history,
)


ROOT = Path(__file__).resolve().parent
MODEL_PATH = Path(
    os.getenv(
        "GOMATE_MODEL_PATH",
        str(ROOT / "training_output_research_v15_grid001" / "gomate_ranker_research_v15_strict.joblib"),
    )
)
DATASET_MANIFEST_PATH = ROOT / "ml_training_dataset_v12_semantic_v1_manifest.json"
TRAINING_DATA_PATH = ROOT / "ml_training_dataset_v12_semantic_v1.csv"
SEMANTIC_MANIFEST_PATH = ROOT / "semantic_v1" / "semantic_v1_manifest.json"

app = FastAPI(
    title="GoMate AI Recommendation Service",
    version="gomate-ranker-research-v15-screen12-strict",
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
    history_external_ids: list[str] = Field(default_factory=list, max_length=100)


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
    hybrid_score: float
    association_rule_score: float | None
    association_rule_available: bool
    svd_score: float | None
    svd_available: bool


class RecommendResponse(BaseModel):
    model_version: str
    selected_strategy: str | None
    destination_key: str | None
    selected_interest_codes: list[str]
    context_codes_received: list[str]
    context_note: str
    total_candidates: int
    component_availability: dict[str, bool]
    component_unavailable_reasons: dict[str, str]
    items: list[RecommendItem]


def load_model_metadata() -> dict[str, Any]:
    if not MODEL_PATH.exists():
        return {}
    bundle = joblib.load(MODEL_PATH)
    if not isinstance(bundle, dict):
        raise RuntimeError("AI artifact must be a Joblib dictionary bundle")
    required = {
        "model_version",
        "training_data_version",
        "selected_strategy",
        "selected_research_formula",
        "semantic_data_version",
        "hybrid_weights",
        "rule_normalization_stats",
        "svd_item_embeddings",
        "semantic_value_features",
        "semantic_mask_features",
    }
    missing = sorted(key for key in required if key not in bundle)
    if missing:
        raise RuntimeError(f"AI artifact is missing required metadata: {missing}")
    weights = bundle["hybrid_weights"]
    if not isinstance(weights, dict) or any(
        key not in weights for key in ("association_rule", "svd", "content_based")
    ):
        raise RuntimeError("AI artifact has incomplete hybrid_weights")
    if not DATASET_MANIFEST_PATH.exists() or not SEMANTIC_MANIFEST_PATH.exists():
        raise RuntimeError("AI artifact manifests are missing")
    dataset_manifest = json.loads(DATASET_MANIFEST_PATH.read_text(encoding="utf-8-sig"))
    semantic_manifest = json.loads(SEMANTIC_MANIFEST_PATH.read_text(encoding="utf-8-sig"))
    if bundle["training_data_version"] != dataset_manifest.get("datasetVersion"):
        raise RuntimeError("AI artifact and training dataset manifest versions do not match")
    if bundle["semantic_data_version"] != semantic_manifest.get("semanticDataVersion"):
        raise RuntimeError("AI artifact and semantic manifest versions do not match")
    return {
        "model_version": bundle["model_version"],
        "selected_strategy": bundle["selected_strategy"],
        "selected_research_formula": bundle["selected_research_formula"],
        "semantic_data_version": bundle["semantic_data_version"],
        "training_data_version": bundle["training_data_version"],
        "hybrid_weights": {key: float(value) for key, value in weights.items()},
        "semantic_value_feature_count": len(bundle["semantic_value_features"]),
        "semantic_mask_feature_count": len(bundle["semantic_mask_features"]),
        "artifact_valid": True,
        "artifact_bundle": bundle,
    }


MODEL_META = load_model_metadata()
MODEL_BUNDLE = MODEL_META.get("artifact_bundle", {})


@lru_cache(maxsize=1)
def load_runtime_rule_index() -> dict[str, Any] | None:
    """Build pairwise rules from frozen positive training-tour baskets."""
    if not TRAINING_DATA_PATH.exists():
        return None
    frame = pd.read_csv(
        TRAINING_DATA_PATH,
        encoding="utf-8-sig",
        usecols=["ma_tour", "candidate_external_id", "split_type", "label"],
    )
    train = frame[
        frame["split_type"].astype(str).eq("train")
        & pd.to_numeric(frame["label"], errors="coerce").eq(1)
    ]
    rows = [
        (str(row.ma_tour), str(row.candidate_external_id))
        for row in train.itertuples(index=False)
    ]
    return build_pair_rule_index(rows)


def apply_runtime_hybrid(
    scores: pd.DataFrame,
    history_external_ids: list[str],
) -> tuple[pd.DataFrame, dict[str, Any]]:
    """Apply the v15 formula to signals available from the survey request.

    The history adapter is deliberately separate from the offline trainer:
    Association Rules use pairwise baskets from frozen train tours, while SVD
    uses the artifact's Tour x Place item embeddings. This is not User x Place
    training and does not update the artifact online.
    """
    if scores.empty:
        return scores.copy(), {
            "association_rule": False,
            "svd": False,
            "content_based": False,
            "reasons": {
                "association_rule": "no_candidates",
                "svd": "no_candidates",
                "content_based": "no_candidates",
            },
        }

    candidate_ids = scores["external_id"].astype(str).tolist()
    weights = MODEL_META["hybrid_weights"]
    association_scores, association_available, association_reason = score_association_rules(
        candidate_ids,
        history_external_ids,
        load_runtime_rule_index(),
        MODEL_BUNDLE.get("rule_normalization_stats"),
    )
    svd_scores, svd_available, svd_reason = score_svd_history(
        candidate_ids,
        history_external_ids,
        MODEL_BUNDLE.get("svd_item_embeddings"),
    )
    output = apply_hybrid(
        scores,
        association_scores,
        association_available,
        svd_scores,
        svd_available,
        float(weights["content_based"]),
        float(weights["association_rule"]),
        float(weights["svd"]),
    )
    content_available = bool(output["semantic_signal_available"].any())
    return output, {
        "association_rule": association_available,
        "svd": any(svd_available.values()),
        "content_based": content_available,
        "reasons": {
            "association_rule": association_reason,
            "svd": svd_reason,
            "content_based": (
                "semantic_v1_survey_scoring"
                if content_available
                else "no_semantic_signal_for_candidates"
            ),
        },
    }


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": bool(MODEL_META.get("artifact_valid")),
        "model_path": str(MODEL_PATH.name),
        "model_version": MODEL_META.get("model_version"),
        "selected_strategy": MODEL_META.get("selected_strategy"),
        "selected_research_formula": MODEL_META.get("selected_research_formula"),
        "semantic_data_version": MODEL_META.get("semantic_data_version"),
        "runtime_components": {
            "association_rule": bool(MODEL_BUNDLE.get("rule_normalization_stats")),
            "svd": bool(MODEL_BUNDLE.get("svd_item_embeddings")),
            "content_based": bool(MODEL_BUNDLE.get("semantic_value_features")),
            "backend_screen3_rerank": True,
        },
    }


@app.post("/recommend", response_model=RecommendResponse)
def recommend(request: RecommendRequest) -> RecommendResponse:
    if not MODEL_META.get("artifact_valid"):
        raise HTTPException(
            status_code=503,
            detail="AI model artifact is unavailable or failed metadata validation.",
        )
    try:
        scores = score_places(
            interest_codes=request.selected_interest_codes,
            destination_key=request.destination_key,
            runtime_only=not request.include_runtime_ineligible,
        )
        scores, component_meta = apply_runtime_hybrid(
            scores,
            list(dict.fromkeys(
                value.strip()
                for value in request.history_external_ids
                if value and value.strip()
            )),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    top = scores.head(request.top_k).copy()
    items = [
        RecommendItem(
            rank=index + 1,
            external_id=str(row.external_id),
            name=str(row.canonical_name),
            destination_key=str(row.destination_key),
            category=str(row.category),
            semantic_status=str(row.semantic_status),
            semantic_score=None if row.semantic_score != row.semantic_score else float(row.semantic_score),
            semantic_score_upper=None
            if row.semantic_score_upper != row.semantic_score_upper
            else float(row.semantic_score_upper),
            semantic_coverage=float(row.semantic_coverage),
            semantic_signal_available=bool(row.semantic_signal_available),
            hybrid_score=float(row.hybrid_score),
            association_rule_score=None
            if not bool(row.association_rule_available)
            else float(row.association_rule_score),
            association_rule_available=bool(row.association_rule_available),
            svd_score=None
            if not bool(row.svd_available)
            else float(row.svd_score),
            svd_available=bool(row.svd_available),
        )
        for index, row in enumerate(top.itertuples(index=False))
    ]

    return RecommendResponse(
        model_version=MODEL_META["model_version"],
        selected_strategy=MODEL_META.get("selected_strategy"),
        destination_key=request.destination_key,
        selected_interest_codes=request.selected_interest_codes,
        context_codes_received=request.context_codes,
        context_note=(
            "AI combines only available components. Association Rules use "
            "pairwise frozen train-tour baskets and SVD uses frozen Tour x "
            "Place item embeddings; neither component updates the model "
            "online. Screen 3 context codes are returned for Backend reranking."
        ),
        total_candidates=int(len(scores)),
        component_availability={
            key: bool(value)
            for key, value in component_meta.items()
            if key != "reasons"
        },
        component_unavailable_reasons=component_meta["reasons"],
        items=items,
    )
