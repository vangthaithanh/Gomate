#!/usr/bin/env python3
"""FastAPI wrapper for GoMate semantic-v1 cold-start recommendation."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import joblib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from semantic_content_score_v1 import score_places


ROOT = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "training_output" / "gomate_ranker_v12_semantic_v1.joblib"

app = FastAPI(
    title="GoMate AI Recommendation Service",
    version="gomate-ranker-v12-semantic-v1",
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


def load_model_metadata() -> dict[str, Any]:
    if not MODEL_PATH.exists():
        return {}
    bundle = joblib.load(MODEL_PATH)
    if isinstance(bundle, dict):
        return {
            "model_version": bundle.get("model_version"),
            "selected_strategy": bundle.get("selected_strategy"),
            "semantic_data_version": bundle.get("semantic_data_version"),
        }
    return {}


MODEL_META = load_model_metadata()


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": MODEL_PATH.exists(),
        "model_path": str(MODEL_PATH.name),
        "model_version": MODEL_META.get("model_version", "gomate-ranker-v12-semantic-v1"),
        "selected_strategy": MODEL_META.get("selected_strategy"),
    }


@app.post("/recommend", response_model=RecommendResponse)
def recommend(request: RecommendRequest) -> RecommendResponse:
    try:
        scores = score_places(
            interest_codes=request.selected_interest_codes,
            destination_key=request.destination_key,
            runtime_only=not request.include_runtime_ineligible,
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
        )
        for index, row in enumerate(top.itertuples(index=False))
    ]

    return RecommendResponse(
        model_version=MODEL_META.get("model_version", "gomate-ranker-v12-semantic-v1"),
        selected_strategy=MODEL_META.get("selected_strategy"),
        destination_key=request.destination_key,
        selected_interest_codes=request.selected_interest_codes,
        context_codes_received=request.context_codes,
        context_note=(
            "Screen 3 context codes are returned for Backend reranking. "
            "This API score uses Screen 1-2 semantic interests only."
        ),
        total_candidates=int(len(scores)),
        items=items,
    )
