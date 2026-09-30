#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cold-start adapter for GoMate KPDL v11.

Input is the three-group onboarding result from Flutter:
    {"optionCodes": ["THIEN_NHIEN", "BIEN_NUI", "GAN_TOI"]}

The adapter converts onboarding interests into candidate POIs, then optionally
re-ranks them with model_artifacts_v11/ml_models/global_model.pkl. It keeps the
v11 identity contract: AI uses external_id; Spring Boot resolves those IDs to
PostgreSQL places.id before returning data to Flutter.
"""
from __future__ import annotations

import json
import math
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence

import pandas as pd

try:
    import joblib
except Exception:
    joblib = None

BASE_DIR = Path(__file__).resolve().parent
ARTIFACTS_DIR = BASE_DIR / "model_artifacts_v11"
CATALOG_PATH = BASE_DIR / "ai_place_catalog_v11.csv"
FEATURES_PATH = BASE_DIR / "ai_place_features_v11.csv"
FEATURE_SCHEMA_PATH = ARTIFACTS_DIR / "ml_models" / "feature_schema.json"
MODEL_PATH = ARTIFACTS_DIR / "ml_models" / "global_model.pkl"
PREPROCESSOR_PATH = ARTIFACTS_DIR / "ml_models" / "preprocessor.pkl"

CODE_TO_CATEGORIES: Dict[str, List[str]] = {
    "KET_BAN": ["market", "landmark"],
    "NGHI_DUONG": ["nature", "lake"],
    "CHECKIN_HOT": ["landmark", "nature"],
    "THIEN_NHIEN": ["nature", "lake"],
    "VAN_HOA": ["heritage", "landmark"],
    "AM_THUC": ["food", "market"],
    "MUC_DICH_KHAC": [],
    "BIEN_NUI": ["nature"],
    "TRUNG_TAM": ["market", "landmark"],
    "DIA_DANH_NOI_TIENG": ["landmark", "heritage"],
    "LANG_NGHE_DI_TICH": ["heritage", "market"],
    "NGOAI_O_DONG_QUE": ["nature", "lake"],
    "LOAI_KHAC": [],
    "GAN_TOI": [],
    "LOCAL": ["food", "market", "nature"],
    "DANG_HOT": [],
    "DI_TRONG_NGAY": [],
    "CO_REVIEW": [],
    "UU_TIEN_KHAC": [],
}

DESTINATION_CENTRES = {
    "da_lat": (11.9404, 108.4583),
    "phan_thiet": (10.9333, 108.1000),
    "vung_tau": (10.3460, 107.0843),
    "da_nang_hue_hoi_an": (16.0500, 108.1500),
    "ha_noi": (20.9500, 105.8500),
}

FEATURE_COLUMNS_FALLBACK = [
    "destination_key", "candidate_category", "so_ngay", "so_dem",
    "gia_tu_scaled", "day_index", "num_selected_places",
    "candidate_popularity", "candidate_is_core", "category_frequency",
    "same_category_count", "has_direct_rule", "max_support",
    "max_confidence", "max_lift", "max_rule_score", "is_ar_candidate",
]


def _load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def _catalog() -> pd.DataFrame:
    if not FEATURES_PATH.exists():
        raise FileNotFoundError(f"Thiếu file {FEATURES_PATH}")
    features = pd.read_csv(FEATURES_PATH, dtype=str).fillna("")
    for c in ["external_id", "canonical_name", "destination_key", "category"]:
        if c not in features.columns:
            raise ValueError(f"{FEATURES_PATH.name} thiếu cột {c}")
    for c in ["latitude", "longitude"]:
        features[c] = pd.to_numeric(features.get(c, ""), errors="coerce")
    tour_counts: Dict[tuple[str, str], float] = {}
    levels: Dict[tuple[str, str], str] = {}
    destinations = _load_json(ARTIFACTS_DIR / "destinations.json", [])
    for destination in destinations:
        key = destination.get("destination_key")
        rows = _load_json(ARTIFACTS_DIR / key / "places.json", [])
        for row in rows:
            k = (str(key), str(row.get("name", "")).strip().casefold())
            tour_counts[k] = float(row.get("tour_count") or 0)
            levels[k] = str(row.get("place_level") or "rare")
    features["tour_count"] = [
        tour_counts.get((str(r.destination_key), str(r.canonical_name).strip().casefold()), 0.0)
        for r in features.itertuples(index=False)
    ]
    features["place_level"] = [
        levels.get((str(r.destination_key), str(r.canonical_name).strip().casefold()), "rare")
        for r in features.itertuples(index=False)
    ]
    return features


@lru_cache(maxsize=1)
def _model_bundle() -> Dict[str, Any]:
    result: Dict[str, Any] = {"model": None, "preprocessor": None, "schema": {}}
    if joblib is None or not MODEL_PATH.exists() or not PREPROCESSOR_PATH.exists():
        return result
    try:
        result["model"] = joblib.load(MODEL_PATH)
        result["preprocessor"] = joblib.load(PREPROCESSOR_PATH)
        result["schema"] = _load_json(FEATURE_SCHEMA_PATH, {})
    except Exception as exc:
        result["load_error"] = f"Không tải được global_model.pkl: {exc}"
    return result


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _distance_score(row: pd.Series, latitude: Optional[float], longitude: Optional[float]) -> float:
    if latitude is None or longitude is None or pd.isna(row.get("latitude")) or pd.isna(row.get("longitude")):
        return 0.0
    distance = _haversine_km(latitude, longitude, float(row.latitude), float(row.longitude))
    return max(0.0, 1.0 - min(distance, 150.0) / 150.0)


def _destination_score(key: str, latitude: Optional[float], longitude: Optional[float]) -> float:
    if latitude is None or longitude is None or key not in DESTINATION_CENTRES:
        return 0.0
    lat, lon = DESTINATION_CENTRES[key]
    return max(0.0, 1.0 - min(_haversine_km(latitude, longitude, lat, lon), 500.0) / 500.0)


def _normalise_codes(option_codes: Iterable[str]) -> List[str]:
    return list(dict.fromkeys(str(x).strip().upper() for x in (option_codes or []) if str(x).strip()))


def _reason(cats: Sequence[str], codes: Sequence[str], row: pd.Series) -> str:
    labels = []
    if row.category in cats:
        labels.append("phù hợp loại địa điểm bạn chọn")
    if "GAN_TOI" in codes:
        labels.append("ưu tiên vị trí gần bạn")
    if "DANG_HOT" in codes:
        labels.append("địa điểm phổ biến trong dữ liệu v11")
    if "CO_REVIEW" in codes:
        labels.append("ưu tiên địa điểm có dữ liệu tour/review")
    return " và ".join(labels) if labels else "được chọn từ dữ liệu địa điểm v11"


def _ml_scores(candidates: pd.DataFrame) -> Optional[List[float]]:
    bundle = _model_bundle()
    model, preprocessor = bundle.get("model"), bundle.get("preprocessor")
    if model is None or preprocessor is None:
        return None
    schema = bundle.get("schema") or {}
    columns = schema.get("input_feature_columns") or FEATURE_COLUMNS_FALLBACK
    frame = pd.DataFrame(index=candidates.index)
    frame["destination_key"] = candidates["destination_key"].astype(str)
    frame["candidate_category"] = candidates["category"].astype(str)
    frame["so_ngay"] = 1.0
    frame["so_dem"] = 0.0
    frame["gia_tu_scaled"] = 0.0
    frame["day_index"] = 1.0
    frame["num_selected_places"] = 0.0
    max_count = max(float(candidates["tour_count"].max()), 1.0)
    frame["candidate_popularity"] = candidates["tour_count"].astype(float) / max_count
    frame["candidate_is_core"] = (candidates["place_level"] == "core").astype(int)
    frame["category_frequency"] = 0.0
    frame["same_category_count"] = 0.0
    frame["has_direct_rule"] = 0.0
    frame["max_support"] = 0.0
    frame["max_confidence"] = 0.0
    frame["max_lift"] = 0.0
    frame["max_rule_score"] = 0.0
    frame["is_ar_candidate"] = 0.0
    frame = frame.reindex(columns=columns, fill_value=0.0)
    try:
        transformed = preprocessor.transform(frame)
        if hasattr(model, "predict_proba"):
            values = model.predict_proba(transformed)[:, 1]
        else:
            values = model.predict(transformed)
        return [float(max(0.0, min(1.0, x))) for x in values]
    except Exception:
        return None


def recommend_cold_start(
    option_codes: Sequence[str], *, destination_key: Optional[str] = None,
    latitude: Optional[float] = None, longitude: Optional[float] = None,
    top_k: int = 10,
) -> Dict[str, Any]:
    codes = _normalise_codes(option_codes)
    unknown_codes = [c for c in codes if c not in CODE_TO_CATEGORIES]
    categories = list(dict.fromkeys(c for code in codes for c in CODE_TO_CATEGORIES.get(code, [])))
    data = _catalog().copy()
    if destination_key:
        data = data[data["destination_key"] == destination_key].copy()
    if data.empty:
        return {"modelVersion": "v11", "coldStart": True, "recommendations": [], "warnings": ["Không tìm thấy destination phù hợp."]}
    if categories:
        filtered = data[data["category"].isin(categories)].copy()
        if not filtered.empty:
            data = filtered

    max_count = max(float(data["tour_count"].max()), 1.0)
    data["popularity_score"] = data["tour_count"].astype(float) / max_count
    data["category_score"] = data["category"].isin(categories).astype(float) if categories else 0.0
    data["distance_score"] = data.apply(lambda row: _distance_score(row, latitude, longitude), axis=1)
    data["destination_score"] = data["destination_key"].map(lambda key: _destination_score(key, latitude, longitude))
    data["core_score"] = (data["place_level"] == "core").astype(float)
    score = 0.35 * data["category_score"] + 0.25 * data["core_score"] + 0.20 * data["popularity_score"]
    if "GAN_TOI" in codes and latitude is not None and longitude is not None:
        score += 0.20 * data["distance_score"]
    elif latitude is not None and longitude is not None:
        score += 0.08 * data["distance_score"]
    if "DANG_HOT" in codes:
        score += 0.15 * data["popularity_score"]
    if destination_key is None and latitude is not None and longitude is not None:
        score += 0.10 * data["destination_score"]
    data["rule_score"] = score.clip(0.0, 1.0)
    ml_scores = _ml_scores(data)
    scoring_mode = "cold_start_rules_and_global_model" if ml_scores is not None else "cold_start_rules"
    if ml_scores is not None:
        data["ml_score"] = ml_scores
        data["final_score"] = 0.65 * data["rule_score"] + 0.35 * data["ml_score"]
    else:
        data["ml_score"] = 0.0
        data["final_score"] = data["rule_score"]
    data = data.sort_values(["final_score", "tour_count", "canonical_name"], ascending=[False, False, True])
    rows, seen = [], set()
    for _, row in data.iterrows():
        external_id = str(row.external_id)
        if external_id in seen:
            continue
        seen.add(external_id)
        rows.append({
            "externalId": external_id, "name": str(row.canonical_name),
            "destinationKey": str(row.destination_key), "category": str(row.category),
            "latitude": None if pd.isna(row.latitude) else float(row.latitude),
            "longitude": None if pd.isna(row.longitude) else float(row.longitude),
            "score": round(float(row.final_score), 6),
            "reason": _reason(categories, codes, row), "modelSource": scoring_mode,
        })
        if len(rows) >= max(1, min(int(top_k), 50)):
            break
    warnings = []
    if unknown_codes:
        warnings.append(f"Bỏ qua optionCode không hợp lệ: {unknown_codes}")
    if "GAN_TOI" in codes and (latitude is None or longitude is None):
        warnings.append("Đã chọn 'Gần tôi' nhưng chưa có tọa độ; chưa tính khoảng cách.")
    if "CO_REVIEW" in codes:
        warnings.append("Dữ liệu v11 dùng độ phổ biến tour làm tín hiệu thay thế; chưa có lịch sử review thật.")
    if ml_scores is None:
        warnings.append("Không tải được global_model.pkl; đang dùng điểm cold-start từ metadata v11.")
    return {
        "modelVersion": "v11", "coldStart": True, "optionCodes": codes,
        "categories": categories, "destinationKey": destination_key,
        "scoringMode": scoring_mode, "recommendations": rows, "warnings": warnings,
    }
