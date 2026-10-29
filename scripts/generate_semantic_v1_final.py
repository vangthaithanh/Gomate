import argparse
import csv
import json
import math
import re
import shutil
import statistics
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


SEMANTIC_VERSION = "semantic-v1"
CATALOG_VERSION = "tour_places_v11"
RELEASE_STATUS = "FINAL"
ALLOWED_WEIGHTS = {0.3, 0.6, 0.8, 1.0}
BEFORE_STATUS_COUNTS = {"READY": 71, "PARTIAL": 110, "NEED_REVIEW": 7}
QA_DESTINATIONS = ["da_lat", "vung_tau", "ha_noi", "da_nang_hue_hoi_an", "phan_thiet"]
QA_INTERESTS = ["NGHI_DUONG", "KET_BAN", "CHECKIN_HOT", "THIEN_NHIEN", "VAN_HOA", "AM_THUC"]
EXPERIENCE_TAGS = {
    "relaxing", "quiet", "scenic", "social", "group_friendly", "crowded", "event_place",
    "cafe_meeting", "walking_area", "night_market", "photo_spot", "iconic", "trendy",
    "local", "local_food", "local_market", "local_culture", "cafe", "night_activity",
    "resort_spa", "city_center", "urban", "countryside",
}


def row(**kwargs):
    return kwargs


INTEREST_TAXONOMY = [
    row(interest_code="KET_BAN", interest_name="Ket ban", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants social/group-friendly travel experiences."),
    row(interest_code="NGHI_DUONG", interest_name="Nghi duong", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants relaxing, quiet, resort-like experiences."),
    row(interest_code="CHECKIN_HOT", interest_name="Check-in hot", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants photogenic, iconic, trendy places."),
    row(interest_code="THIEN_NHIEN", interest_name="Thien nhien", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants nature, lake, mountain, waterfall or forest experiences."),
    row(interest_code="VAN_HOA", interest_name="Van hoa lich su", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants cultural, historical, heritage and museum places."),
    row(interest_code="AM_THUC", interest_name="Am thuc", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="User wants food, local food, market and cafe experiences."),
    row(interest_code="MUC_DICH_KHAC", interest_name="Muc dich khac", interest_group="TRAVEL_INTENT", interest_type="SEMANTIC", definition="Survey compatibility option without semantic tag mapping in semantic-v1."),
    row(interest_code="BIEN_NUI", interest_name="Bien nui", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="User prefers sea, mountain and scenic nature environments."),
    row(interest_code="TRUNG_TAM", interest_name="Trung tam", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="User prefers city center and urban environments."),
    row(interest_code="DIA_DANH_NOI_TIENG", interest_name="Dia danh noi tieng", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="User prefers famous landmarks and iconic places."),
    row(interest_code="LANG_NGHE_DI_TICH", interest_name="Lang nghe di tich", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="User prefers heritage, cultural and historical places."),
    row(interest_code="NGOAI_O_DONG_QUE", interest_name="Ngoai o dong que", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="User prefers countryside, local and nature-oriented environments."),
    row(interest_code="LOAI_KHAC", interest_name="Loai khac", interest_group="ENVIRONMENT_PREFERENCE", interest_type="SEMANTIC", definition="Survey compatibility option without semantic tag mapping in semantic-v1."),
    row(interest_code="GAN_TOI", interest_name="Gan toi", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Runtime distance/GPS re-ranking strategy."),
    row(interest_code="LOCAL", interest_name="Dia diem local", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Shared context strategy using local tags plus backend re-ranking."),
    row(interest_code="DANG_HOT", interest_name="Dang hot", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Popularity/trend re-ranking strategy."),
    row(interest_code="DI_TRONG_NGAY", interest_name="Di trong ngay", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Route duration, distance and available time re-ranking strategy."),
    row(interest_code="CO_REVIEW", interest_name="Co review", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Review count and rating re-ranking strategy."),
    row(interest_code="UU_TIEN_KHAC", interest_name="Uu tien khac", interest_group="CONTEXT_STRATEGY", interest_type="CONTEXT", definition="Survey compatibility context option."),
]


TAG_TAXONOMY = [
    ("relaxing", "Relaxing", "Place supports rest, low-pressure leisure or relaxation."),
    ("quiet", "Quiet", "Place is expected to be calm or low-noise when verified."),
    ("scenic", "Scenic", "Place has notable landscape or visual scenery."),
    ("nature", "Nature", "Place is primarily nature-oriented."),
    ("lake", "Lake", "Place is a lake or strongly lake-centered."),
    ("beach", "Beach", "Place is beach or sea-oriented."),
    ("mountain", "Mountain", "Place is mountain or highland-oriented."),
    ("waterfall", "Waterfall", "Place is waterfall-oriented."),
    ("forest", "Forest", "Place is forest-oriented."),
    ("social", "Social", "Place supports social activity when verified."),
    ("group_friendly", "Group friendly", "Place is suitable for groups when verified."),
    ("crowded", "Crowded", "Place is often crowded when verified."),
    ("event_place", "Event place", "Place hosts or supports events when verified."),
    ("cafe_meeting", "Cafe meeting", "Cafe or meeting-friendly place when verified."),
    ("walking_area", "Walking area", "Place supports walking or strolling when verified."),
    ("night_market", "Night market", "Place is a night market or strongly night-market-related."),
    ("photo_spot", "Photo spot", "Place is photogenic or commonly used for photos."),
    ("landmark", "Landmark", "Place is a landmark or symbolic site."),
    ("iconic", "Iconic", "Place is iconic or strongly representative when verified/category-derived."),
    ("trendy", "Trendy", "Place is currently fashionable when verified."),
    ("local", "Local", "Place has local character or serves local discovery."),
    ("local_food", "Local food", "Place is associated with local food."),
    ("local_market", "Local market", "Place is associated with local market experience."),
    ("local_culture", "Local culture", "Place is associated with local culture."),
    ("cultural", "Cultural", "Place is culture-oriented."),
    ("historical", "Historical", "Place has historical orientation."),
    ("heritage", "Heritage", "Place is heritage-oriented."),
    ("museum", "Museum", "Place is museum-related."),
    ("food", "Food", "Place is food-oriented."),
    ("cafe", "Cafe", "Place is cafe-oriented."),
    ("market", "Market", "Place is market-oriented."),
    ("night_activity", "Night activity", "Place supports night activity when verified."),
    ("resort_spa", "Resort and spa", "Place is resort/spa-oriented when verified."),
    ("city_center", "City center", "Place is city-center-oriented."),
    ("urban", "Urban", "Place is urban-oriented."),
    ("countryside", "Countryside", "Place is countryside-oriented."),
]


INTEREST_TAG_MAPPINGS = [
    ("NGHI_DUONG", "relaxing", 1.0), ("NGHI_DUONG", "quiet", 0.8), ("NGHI_DUONG", "resort_spa", 1.0),
    ("NGHI_DUONG", "scenic", 0.8), ("NGHI_DUONG", "nature", 0.6), ("NGHI_DUONG", "lake", 0.3), ("NGHI_DUONG", "walking_area", 0.3),
    ("KET_BAN", "social", 1.0), ("KET_BAN", "group_friendly", 0.8), ("KET_BAN", "cafe_meeting", 0.8), ("KET_BAN", "event_place", 0.8),
    ("KET_BAN", "crowded", 0.6), ("KET_BAN", "walking_area", 0.6), ("KET_BAN", "night_market", 0.3),
    ("CHECKIN_HOT", "photo_spot", 1.0), ("CHECKIN_HOT", "scenic", 0.8), ("CHECKIN_HOT", "landmark", 0.8), ("CHECKIN_HOT", "iconic", 0.8), ("CHECKIN_HOT", "trendy", 0.6),
    ("THIEN_NHIEN", "nature", 1.0), ("THIEN_NHIEN", "lake", 0.8), ("THIEN_NHIEN", "mountain", 0.8), ("THIEN_NHIEN", "waterfall", 0.8), ("THIEN_NHIEN", "forest", 0.8), ("THIEN_NHIEN", "scenic", 0.6),
    ("VAN_HOA", "cultural", 1.0), ("VAN_HOA", "historical", 1.0), ("VAN_HOA", "heritage", 0.8), ("VAN_HOA", "museum", 0.8), ("VAN_HOA", "local_culture", 0.6),
    ("AM_THUC", "food", 1.0), ("AM_THUC", "local_food", 0.8), ("AM_THUC", "market", 0.6), ("AM_THUC", "cafe", 0.6), ("AM_THUC", "local", 0.3),
    ("BIEN_NUI", "nature", 0.8), ("BIEN_NUI", "mountain", 0.8), ("BIEN_NUI", "beach", 0.8), ("BIEN_NUI", "scenic", 0.8),
    ("TRUNG_TAM", "city_center", 0.8), ("TRUNG_TAM", "urban", 0.8), ("TRUNG_TAM", "walking_area", 0.8),
    ("DIA_DANH_NOI_TIENG", "landmark", 0.8), ("DIA_DANH_NOI_TIENG", "iconic", 0.8), ("DIA_DANH_NOI_TIENG", "photo_spot", 0.8),
    ("LANG_NGHE_DI_TICH", "heritage", 0.8), ("LANG_NGHE_DI_TICH", "cultural", 0.8), ("LANG_NGHE_DI_TICH", "historical", 0.8), ("LANG_NGHE_DI_TICH", "local_culture", 0.8),
    ("NGOAI_O_DONG_QUE", "countryside", 0.8), ("NGOAI_O_DONG_QUE", "local", 0.8), ("NGOAI_O_DONG_QUE", "nature", 0.8), ("NGOAI_O_DONG_QUE", "scenic", 0.8),
]


CATEGORY_RULES = {
    "lake": [("lake", 1.0), ("nature", 0.8), ("scenic", 0.6)],
    "heritage": [("heritage", 1.0), ("cultural", 0.8), ("historical", 0.8)],
    "market": [("market", 1.0), ("local", 0.8)],
    "food": [("food", 1.0), ("local_food", 0.8)],
    "landmark": [("landmark", 1.0), ("photo_spot", 0.8), ("iconic", 0.6)],
    "nature": [("nature", 1.0), ("scenic", 0.6)],
}


CONTEXT_STRATEGY = [
    row(context_code="GAN_TOI", context_name="Gan toi", owner="BACKEND", primary_signal="DISTANCE", description="Use runtime GPS and place coordinates for distance scoring.", included_in_model_v1="false"),
    row(context_code="LOCAL", context_name="Dia diem local", owner="SHARED", primary_signal="LOCAL_TAG", description="May use local-related tags plus backend contextual boost.", included_in_model_v1="false"),
    row(context_code="DANG_HOT", context_name="Dang hot", owner="BACKEND", primary_signal="POPULARITY", description="Use trend, save, review, view or click signals when available.", included_in_model_v1="false"),
    row(context_code="DI_TRONG_NGAY", context_name="Di trong ngay", owner="BACKEND", primary_signal="ROUTE_TIME", description="Use distance, route duration, opening hours and available time.", included_in_model_v1="false"),
    row(context_code="CO_REVIEW", context_name="Co review", owner="BACKEND", primary_signal="REVIEW", description="Use review count and average rating signals.", included_in_model_v1="false"),
    row(context_code="UU_TIEN_KHAC", context_name="Uu tien khac", owner="BACKEND", primary_signal="MANUAL_CONTEXT", description="Reserved survey compatibility context.", included_in_model_v1="false"),
]


CATEGORY_CONFLICT_EXTERNAL_IDS = {
    "da_lat:nha_tho_con_ga": "Catalog category is lake but canonical name is a church.",
    "da_lat:happy_hill": "Catalog category is food but canonical name indicates a hill/check-in attraction.",
    "da_lat:puppy_farm": "Catalog category is food but canonical name indicates a farm attraction.",
    "da_nang_hue_hoi_an:pho_co_hoi_an": "Catalog category is lake but canonical name is an old town.",
    "ha_noi:lang_chu_tich_ho_chi_minh": "Catalog category is lake but canonical name is a mausoleum.",
    "ha_noi:nha_tho_da_sapa": "Catalog category is lake but canonical name is a church.",
    "ha_noi:pho_co_ha_noi": "Catalog category is lake but canonical name is an old quarter.",
    "vung_tau:bien_ho_coc": "Catalog category is lake but canonical name indicates a beach.",
    "vung_tau:bien_ho_tram": "Catalog category is lake but canonical name indicates a beach.",
}


EXACT_REVIEW_RULES = {
    "da_lat:ho_xuan_huong": [
        ("scenic", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "central lake landscape supports stronger scenic profile"),
        ("walking_area", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "well-known city lake route supports strolling use case"),
        ("relaxing", 0.6, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "lake scenery supports light relaxation"),
        ("social", 0.3, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "public central lake can support low-intensity social activity"),
    ],
    "da_lat:cho_da_lat": [
        ("local_market", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "market identity supports local market experience"),
        ("food", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "Da Lat market commonly supports food discovery"),
        ("crowded", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "central visitor market is often crowded"),
        ("social", 0.6, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "market visit supports social/group browsing"),
        ("night_activity", 0.6, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "Da Lat market is linked to night-market activity in destination context"),
        ("photo_spot", 0.3, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "central market can support light check-in behavior"),
    ],
    "da_lat:quang_truong_lam_vien": [
        ("walking_area", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "public square supports walking/strolling"),
        ("social", 0.8, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "public square supports social gathering"),
        ("group_friendly", 0.6, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "open public square is suitable for groups"),
        ("crowded", 0.6, "MANUAL_REVIEW", "docs/SEMANTIC_ENRICHMENT_V1_FINAL.md:place-example", "central public square is a common visitor gathering place"),
    ],
}


def normalize_text(value):
    value = value or ""
    value = unicodedata.normalize("NFD", value)
    value = "".join(ch for ch in value if unicodedata.category(ch) != "Mn")
    value = value.replace("Đ", "D").replace("đ", "d")
    return value.lower()


def add_tag(tags, tag_code, weight, source_type, source_ref, reason):
    if tag_code not in {code for code, _, _ in TAG_TAXONOMY}:
        raise ValueError(f"Unknown tag code {tag_code}")
    if weight not in ALLOWED_WEIGHTS:
        raise ValueError(f"Invalid weight {weight} for {tag_code}")
    current = tags.get(tag_code)
    evidence = row(source_type=source_type, source_ref=source_ref, reason=reason)
    if current is None or weight > current["weight"]:
        tags[tag_code] = {"weight": weight, "evidence": [evidence]}
    elif math.isclose(weight, current["weight"]):
        current["evidence"].append(evidence)


def add_keyword_rule(tags, text, patterns, tag_code, weight, reason):
    if any(re.search(pattern, text) for pattern in patterns):
        add_tag(tags, tag_code, weight, "CATALOG_NAME_RULE", "place_catalog_v11.csv:canonical_name", reason)


def semantic_tags_for_place(place):
    tags = {}
    category = place["category"]
    name = place["canonical_name"]
    norm = normalize_text(name)

    for tag_code, weight in CATEGORY_RULES.get(category, []):
        add_tag(tags, tag_code, weight, "CATEGORY_RULE", "place_catalog_v11.csv:category", f"category={category}")

    add_keyword_rule(tags, norm, [r"\bho\b", r"\bsong\b", r"\bpha\b", r"\bbau\b"], "lake", 1.0, "canonical name indicates lake/river/water landscape")
    add_keyword_rule(tags, norm, [r"\bbien\b", r"\bbai\b", r"\bmui\b", r"\bdao\b", r"\bhon\b", r"\bcu lao\b"], "beach", 1.0, "canonical name indicates beach/coast/island")
    add_keyword_rule(tags, norm, [r"\bnui\b", r"\bdoi\b", r"\bdeo\b", r"\bfansipan\b", r"\blangbiang\b", r"\bba na\b"], "mountain", 0.8, "canonical name indicates mountain/hill/pass")
    add_keyword_rule(tags, norm, [r"\bthac\b", r"\bsuoi\b"], "waterfall", 0.8, "canonical name indicates waterfall/stream")
    add_keyword_rule(tags, norm, [r"\brung\b", r"\bvuon quoc gia\b"], "forest", 0.8, "canonical name indicates forest/national park")
    add_keyword_rule(tags, norm, [r"\bhang\b", r"\bdong\b"], "nature", 0.8, "canonical name indicates cave/grotto nature attraction")
    add_keyword_rule(tags, norm, [r"\bcanh dong\b", r"\bvuon\b", r"\blang hoa\b", r"\bdoi che\b", r"\bnong trai\b", r"\bdao\b", r"\bhon\b", r"\bcu lao\b"], "nature", 0.8, "canonical name indicates garden/farm/flower/island/natural landscape")
    add_keyword_rule(tags, norm, [r"\bcanh dong\b", r"\bvuon\b", r"\blang hoa\b", r"\bdoi\b", r"\bdeo\b", r"\bbien\b", r"\bbai\b", r"\bmui\b", r"\bdao\b", r"\bhon\b", r"\bcu lao\b", r"\bho\b", r"\bsong\b", r"\bpha\b", r"\bbau\b", r"\bvịnh\b", r"\bvinh\b", r"\bhang\b", r"\bdong\b", r"\bthac\b", r"\bsuoi\b"], "scenic", 0.8, "canonical name indicates scenic landscape")

    add_keyword_rule(tags, norm, [r"\bbao tang\b", r"\bmuseum\b"], "museum", 1.0, "canonical name indicates museum")
    add_keyword_rule(tags, norm, [r"\bchua\b", r"\bden\b", r"\bdinh\b", r"\bthien vien\b", r"\btu vien\b", r"\bnha tho\b", r"\blang\b", r"\bthap\b", r"\bvan mieu\b", r"\bthanh dia\b", r"\bhoa lu\b", r"\bnha tu\b"], "heritage", 1.0, "canonical name indicates heritage/spiritual/historical site")
    add_keyword_rule(tags, norm, [r"\bchua\b", r"\bden\b", r"\bdinh\b", r"\bthien vien\b", r"\btu vien\b", r"\bnha tho\b", r"\blang\b", r"\bthap\b", r"\bvan mieu\b", r"\bthanh dia\b", r"\bpho co\b", r"\blang co\b", r"\blang gom\b", r"\blang huong\b", r"\bnha co\b", r"\bnha lon\b"], "cultural", 0.8, "canonical name indicates cultural place")
    add_keyword_rule(tags, norm, [r"\bdai noi\b", r"\bpho co\b", r"\blang co\b", r"\bnha co\b", r"\bnha tu\b", r"\bvan mieu\b", r"\bhoa lu\b", r"\bdinh\b", r"\blang\b"], "historical", 0.8, "canonical name indicates historical place")
    add_keyword_rule(tags, norm, [r"\blang\b", r"\bban\b", r"\bpho co\b", r"\bhoi quan\b", r"\blang gom\b", r"\blang huong\b", r"\blang chai\b"], "local_culture", 0.6, "canonical name indicates local/community cultural experience")

    add_keyword_rule(tags, norm, [r"\bcafe\b", r"\bca phe\b"], "cafe", 1.0, "canonical name indicates cafe")
    add_keyword_rule(tags, norm, [r"\bcafe\b", r"\bca phe\b"], "cafe_meeting", 0.8, "canonical name indicates cafe meeting context")
    add_keyword_rule(tags, norm, [r"\bcho\b", r"\bmarket\b"], "market", 1.0, "canonical name indicates market")
    add_keyword_rule(tags, norm, [r"\bcho\b", r"\bmarket\b"], "local_market", 0.8, "canonical name indicates local market")
    add_keyword_rule(tags, norm, [r"\btiem nuong\b", r"\bfood\b", r"\bcafe\b", r"\bcho\b"], "food", 0.8, "canonical name indicates food/food-adjacent experience")
    add_keyword_rule(tags, norm, [r"\btiem nuong\b", r"\bcafe\b", r"\bcho\b"], "social", 0.3, "canonical name indicates social browsing or meeting context")

    add_keyword_rule(tags, norm, [r"\bquang truong\b", r"\bcau\b", r"\btuong\b", r"\bcong troi\b", r"\bga\b", r"\bhai dang\b", r"\bmarina\b", r"\bhang\b", r"\bdong\b", r"\bthac\b", r"\bsuoi\b", r"\bnui\b", r"\bdoi\b", r"\bdeo\b", r"\bbien\b", r"\bbai\b", r"\bmui\b", r"\bdao\b", r"\bhon\b", r"\bcu lao\b"], "photo_spot", 0.6, "canonical name indicates scenic/check-in/photo context")
    add_keyword_rule(tags, norm, [r"\bquang truong\b", r"\bcau\b", r"\btuong\b", r"\bcong troi\b", r"\bga\b", r"\bhai dang\b", r"\bba na\b", r"\bcau vang\b"], "iconic", 0.8, "canonical name indicates iconic landmark")
    add_keyword_rule(tags, norm, [r"\bquang truong\b", r"\bcong vien\b", r"\bkdl\b", r"\bkhu du lich\b", r"\bsun world\b", r"\bnovaworld\b", r"\bcircus land\b", r"\bvinwonders\b"], "group_friendly", 0.6, "canonical name indicates public park/tourist area suitable for groups")
    add_keyword_rule(tags, norm, [r"\bquang truong\b", r"\bcong vien\b", r"\bkdl\b", r"\bkhu du lich\b", r"\bcircus land\b", r"\bnovaworld\b"], "social", 0.6, "canonical name indicates public/group activity area")
    add_keyword_rule(tags, norm, [r"\bquang truong\b", r"\bcong vien\b", r"\bpho co\b", r"\bho\b"], "walking_area", 0.6, "canonical name indicates open strolling/walking context")

    add_keyword_rule(tags, norm, [r"\bspa\b", r"\bresort\b", r"\bsea links\b", r"\bnuoc nong\b", r"\bhot springs\b"], "resort_spa", 0.8, "canonical name indicates resort/spa/hot-spring orientation")
    add_keyword_rule(tags, norm, [r"\bnuoc nong\b", r"\bhot springs\b", r"\bho\b", r"\bsong\b", r"\bpha\b", r"\bbau\b", r"\bbien\b", r"\bbai\b", r"\bmui\b", r"\bdao\b", r"\bhon\b", r"\bcu lao\b", r"\bvuon\b", r"\bthung lung\b"], "relaxing", 0.6, "canonical name indicates low-pressure leisure setting")
    add_keyword_rule(tags, norm, [r"\btrung tam\b", r"\bpho co\b", r"\bquang truong\b", r"\bcho\b"], "urban", 0.6, "canonical name indicates urban/central context")
    add_keyword_rule(tags, norm, [r"\btrung tam\b", r"\bpho co\b", r"\bquang truong\b"], "city_center", 0.6, "canonical name indicates city-center-like environment")
    add_keyword_rule(tags, norm, [r"\blang\b", r"\bban\b", r"\bnong trai\b", r"\bdoi cuu\b"], "countryside", 0.8, "canonical name indicates village/farm/countryside context")
    add_keyword_rule(tags, norm, [r"\blang\b", r"\bban\b", r"\bcho\b"], "local", 0.8, "canonical name indicates local discovery context")

    for rule in EXACT_REVIEW_RULES.get(place["external_id"], []):
        add_tag(tags, *rule)

    return tags


def semantic_status(place, tags):
    if place["external_id"] in CATEGORY_CONFLICT_EXTERNAL_IDS:
        return "NEED_REVIEW", CATEGORY_CONFLICT_EXTERNAL_IDS[place["external_id"]]
    has_enriched = any(any(ev["source_type"] != "CATEGORY_RULE" for ev in data["evidence"]) for data in tags.values())
    has_experience = any(tag in EXPERIENCE_TAGS for tag in tags)
    if has_enriched and has_experience and len(tags) >= 3:
        return "READY", "core identity plus experience semantics are supported by catalog-name/manual evidence"
    if tags:
        return "PARTIAL", "category-derived baseline exists but enrichment evidence remains limited"
    return "NEED_REVIEW", "no valid semantic tags generated from category or catalog name"


def read_csv(path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, fieldnames=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = list(rows)
    if fieldnames is None:
        fieldnames = list(rows[0].keys()) if rows else []
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def runtime_eligible(place):
    return bool(place.get("latitude")) and bool(place.get("longitude"))


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def generate_sync_sql(path, place_tags):
    runtime_rows = [r for r in place_tags if r["runtime_eligible"] == "true"]
    values = ",\n".join(
        f"({sql_quote(r['external_id'])},{sql_quote(r['tag_code'])},{r['weight']})"
        for r in runtime_rows
    )
    sql = f"""BEGIN;
CREATE TEMP TABLE semantic_place_tag_sync (
  external_id TEXT NOT NULL,
  tag_code TEXT NOT NULL,
  weight NUMERIC(4,3) NOT NULL
) ON COMMIT DROP;

INSERT INTO semantic_place_tag_sync(external_id, tag_code, weight)
VALUES
{values};

DELETE FROM place_tag_links l
USING places p
WHERE l.place_id = p.id
  AND p.external_source = 'tour_places_v11'
  AND p.status = 'ACTIVE'
  AND NOT EXISTS (
    SELECT 1
    FROM semantic_place_tag_sync s
    JOIN place_tags pt ON pt.code = s.tag_code
    WHERE s.external_id = p.external_id
      AND pt.id = l.tag_id
  );

INSERT INTO place_tag_links(place_id, tag_id, weight)
SELECT p.id, pt.id, s.weight
FROM semantic_place_tag_sync s
JOIN places p ON p.external_source = 'tour_places_v11'
             AND p.external_id = s.external_id
             AND p.status = 'ACTIVE'
JOIN place_tags pt ON pt.code = s.tag_code
ON CONFLICT (place_id, tag_id)
DO UPDATE SET weight = EXCLUDED.weight;

COMMIT;
"""
    path.write_text(sql, encoding="utf-8")


def validate(catalog, place_tags, tag_codes, interest_mappings, matrix_rows):
    errors = []
    external_ids = [p["external_id"] for p in catalog]
    if len(set(external_ids)) != len(external_ids):
        errors.append("duplicate_external_id")
    if len(matrix_rows) != len(catalog):
        errors.append("matrix_row_count_mismatch")
    tag_set = set(tag_codes)
    for r in place_tags:
        if r["tag_code"] not in tag_set:
            errors.append(f"unknown_tag:{r['tag_code']}")
        if float(r["weight"]) not in ALLOWED_WEIGHTS:
            errors.append(f"invalid_place_weight:{r['external_id']}:{r['tag_code']}:{r['weight']}")
    pairs = [(r["external_id"], r["tag_code"]) for r in place_tags]
    if len(set(pairs)) != len(pairs):
        errors.append("duplicate_place_tag_pair")
    for r in interest_mappings:
        if r["tag_code"] not in tag_set:
            errors.append(f"unknown_mapping_tag:{r['tag_code']}")
        if float(r["weight"]) not in ALLOWED_WEIGHTS:
            errors.append(f"invalid_mapping_weight:{r['interest_code']}:{r['tag_code']}:{r['weight']}")
    return errors


def build_sanity_scores(catalog, place_tags, interest_mappings):
    place_by_id = {p["external_id"]: p for p in catalog}
    tag_by_place = defaultdict(dict)
    for r in place_tags:
        tag_by_place[r["external_id"]][r["tag_code"]] = float(r["weight"])
    map_by_interest = defaultdict(dict)
    for r in interest_mappings:
        map_by_interest[r["interest_code"]][r["tag_code"]] = float(r["weight"])

    rows = []
    for interest in ["NGHI_DUONG", "THIEN_NHIEN", "VAN_HOA", "AM_THUC", "CHECKIN_HOT", "KET_BAN"]:
        scores = []
        mapping = map_by_interest[interest]
        for external_id, place_weights in tag_by_place.items():
            raw = sum(mapping.get(tag, 0.0) * weight for tag, weight in place_weights.items())
            if raw > 0:
                place = place_by_id[external_id]
                scores.append((raw, external_id, place["canonical_name"], place["destination_key"], place["category"]))
        scores.sort(reverse=True)
        for rank, item in enumerate(scores[:10], start=1):
            raw, external_id, name, destination, category = item
            rows.append(row(interest_code=interest, rank=rank, external_id=external_id, canonical_name=name, destination_key=destination, category=category, score=round(raw, 3)))
    return rows


def build_tag_maps(place_tags, interest_mappings):
    tag_by_place = defaultdict(dict)
    status_by_place = {}
    runtime_by_place = {}
    for r in place_tags:
        tag_by_place[r["external_id"]][r["tag_code"]] = float(r["weight"])
        status_by_place[r["external_id"]] = r["semantic_status"]
        runtime_by_place[r["external_id"]] = r["runtime_eligible"]
    map_by_interest = defaultdict(dict)
    for r in interest_mappings:
        map_by_interest[r["interest_code"]][r["tag_code"]] = float(r["weight"])
    return tag_by_place, map_by_interest, status_by_place, runtime_by_place


def score_place(place_weights, mapping):
    matched = []
    raw = 0.0
    for tag, place_weight in place_weights.items():
        interest_weight = mapping.get(tag, 0.0)
        if interest_weight:
            raw += interest_weight * place_weight
            matched.append(f"{tag}:{place_weight:.1f}x{interest_weight:.1f}")
    return raw, matched


def build_interest_coverage(catalog, place_tags, interest_mappings):
    tag_by_place, map_by_interest, _, runtime_by_place = build_tag_maps(place_tags, interest_mappings)
    rows = []
    for interest in QA_INTERESTS:
        scores = []
        runtime_scores = []
        mapping = map_by_interest[interest]
        for place in catalog:
            score, _ = score_place(tag_by_place.get(place["external_id"], {}), mapping)
            if score > 0:
                scores.append(score)
                if runtime_by_place.get(place["external_id"]) == "true" or runtime_eligible(place):
                    runtime_scores.append(score)
        rows.append(row(
            interest_code=interest,
            matching_place_count=len(scores),
            runtime_matching_place_count=len(runtime_scores),
            avg_semantic_match=round(statistics.mean(scores), 3) if scores else 0.0,
        ))
    return rows


def build_category_coverage(catalog, place_tags, status_by_place):
    by_place = defaultdict(list)
    for r in place_tags:
        by_place[r["external_id"]].append(r)
    by_category = defaultdict(list)
    for place in catalog:
        by_category[place["category"]].append(place)
    rows = []
    for category in sorted(by_category):
        places = by_category[category]
        statuses = Counter(status_by_place[p["external_id"]][0] for p in places)
        tag_counts = [len(by_place.get(p["external_id"], [])) for p in places]
        rows.append(row(
            category=category,
            place_count=len(places),
            ready_count=statuses["READY"],
            partial_count=statuses["PARTIAL"],
            need_review_count=statuses["NEED_REVIEW"],
            avg_tags_per_place=round(statistics.mean(tag_counts), 2) if tag_counts else 0.0,
        ))
    return rows


def build_sanity_scenarios(catalog, place_tags, interest_mappings):
    tag_by_place, map_by_interest, status_by_place, runtime_by_place = build_tag_maps(place_tags, interest_mappings)
    rows = []
    for destination in QA_DESTINATIONS:
        places = [p for p in catalog if p["destination_key"] == destination]
        for interest in QA_INTERESTS:
            scored = []
            mapping = map_by_interest[interest]
            for place in places:
                raw, matched = score_place(tag_by_place.get(place["external_id"], {}), mapping)
                if raw > 0:
                    scored.append((raw, place["external_id"], place["canonical_name"], matched))
            scored.sort(key=lambda item: (-item[0], item[1]))
            for rank, (raw, external_id, name, matched) in enumerate(scored[:10], start=1):
                rows.append(row(
                    destination=destination,
                    interest=interest,
                    rank=rank,
                    external_id=external_id,
                    canonical_name=name,
                    score=round(raw, 3),
                    matched_tags="|".join(matched),
                    semantic_status=status_by_place.get(external_id, ""),
                    runtime_eligible=runtime_by_place.get(external_id, "false"),
                ))
    return rows


def detect_sanity_issues(scenario_rows):
    required = {
        "NGHI_DUONG": {"relaxing", "quiet", "resort_spa", "scenic", "nature", "lake", "walking_area", "beach"},
        "AM_THUC": {"food", "local_food", "market", "cafe", "local_market"},
        "VAN_HOA": {"cultural", "historical", "heritage", "museum", "local_culture"},
    }
    issues = []
    grouped = defaultdict(list)
    for r in scenario_rows:
        grouped[(r["destination"], r["interest"])].append(r)
    for (destination, interest), rows_for_scenario in grouped.items():
        expected = required.get(interest)
        if not expected:
            continue
        top = rows_for_scenario[:5]
        observed = set()
        for r in top:
            for part in str(r["matched_tags"]).split("|"):
                if part:
                    observed.add(part.split(":", 1)[0])
        if top and not (observed & expected):
            issues.append(row(
                destination=destination,
                interest=interest,
                issue="top5_missing_expected_semantic_family",
                observed_tags="|".join(sorted(observed)),
            ))
    return issues


def markdown_report(summary, partial_rows, need_review_rows, sanity_rows, category_rows, interest_rows, scenario_rows, sanity_issues):
    partial_list = "\n".join(f"- `{r['external_id']}` - {r['canonical_name']}: {r['status_reason']}" for r in partial_rows[:80])
    if len(partial_rows) > 80:
        partial_list += f"\n- ... {len(partial_rows) - 80} more PARTIAL rows in `ai_place_tags_v1.csv`."
    need_review_list = "\n".join(f"- `{r['external_id']}` - {r['canonical_name']}: {r['status_reason']}" for r in need_review_rows)
    sanity_sections = []
    for interest in ["NGHI_DUONG", "THIEN_NHIEN", "VAN_HOA", "AM_THUC", "CHECKIN_HOT", "KET_BAN"]:
        top = [r for r in sanity_rows if r["interest_code"] == interest and r["rank"] <= 5]
        lines = "\n".join(f"- {r['rank']}. `{r['external_id']}` - {r['canonical_name']} ({r['score']})" for r in top)
        sanity_sections.append(f"### {interest}\n\n{lines}")
    category_table = "\n".join(
        f"| `{r['category']}` | {r['place_count']} | {r['ready_count']} | {r['partial_count']} | {r['need_review_count']} | {r['avg_tags_per_place']} |"
        for r in category_rows
    )
    interest_table = "\n".join(
        f"| `{r['interest_code']}` | {r['matching_place_count']} | {r['runtime_matching_place_count']} | {r['avg_semantic_match']} |"
        for r in interest_rows
    )
    sanity_issue_list = "\n".join(
        f"- `{r['destination']}` / `{r['interest']}`: {r['issue']} (observed: {r['observed_tags'] or 'none'})"
        for r in sanity_issues
    )
    runtime_breakdown = summary["runtimeSemanticStatusDistribution"]
    inactive_breakdown = summary["runtimeIneligibleSemanticStatusDistribution"]
    return f"""# Semantic Enrichment V1 FINAL

Updated: {summary['generatedAt']}

## Scope

This is the final `semantic-v1` data release for AI handoff. It enriches Place semantic profiles without changing schema, migrations, Auth, Flutter, Trip, Route, or Cloudinary.

No external web sources were used in this pass. Evidence comes from the version-controlled canonical catalog fields, conservative category rules, catalog-name rules, and a small set of documented manual review overrides for well-known examples.

## Result

| Metric | Count |
|---|---:|
| Canonical Place | {summary['canonicalPlaces']} |
| READY | {summary['ready']} |
| PARTIAL | {summary['partial']} |
| NEED_REVIEW | {summary['needReview']} |
| Runtime eligible | {summary['runtimeEligible']} |
| Runtime ineligible | {summary['runtimeIneligible']} |
| Place-tag links | {summary['placeTagLinks']} |
| Average tags / Place | {summary['averageTagsPerPlace']} |
| Median tags / Place | {summary['medianTagsPerPlace']} |

## Before / After

| Status | Before | After |
|---|---:|---:|
| READY | {BEFORE_STATUS_COUNTS['READY']} | {summary['ready']} |
| PARTIAL | {BEFORE_STATUS_COUNTS['PARTIAL']} | {summary['partial']} |
| NEED_REVIEW | {BEFORE_STATUS_COUNTS['NEED_REVIEW']} | {summary['needReview']} |

## Runtime Breakdown

146 runtime-eligible Place:

```json
{json.dumps(runtime_breakdown, ensure_ascii=False, indent=2)}
```

42 runtime-ineligible Place:

```json
{json.dumps(inactive_breakdown, ensure_ascii=False, indent=2)}
```

## Evidence Distribution

```json
{json.dumps(summary['sourceDistribution'], ensure_ascii=False, indent=2)}
```

## Weight Distribution

```json
{json.dumps(summary['weightDistribution'], ensure_ascii=False, indent=2)}
```

## Tag Coverage Top

```json
{json.dumps(dict(list(summary['tagCoverage'].items())[:20]), ensure_ascii=False, indent=2)}
```

## Interest Coverage

| interest_code | matching_place_count | runtime_matching_place_count | avg_semantic_match |
|---|---:|---:|---:|
{interest_table}

## Category Coverage

| category | place_count | ready_count | partial_count | need_review_count | avg_tags_per_place |
|---|---:|---:|---:|---:|---:|
{category_table}

## Sanity Scenario QA

- Generated scenarios: {summary['sanityScenarioCount']}
- Absurd/issue scenarios: {summary['sanityIssueCount']}
- Full file: `backend/src/main/resources/data/ai_handoff/semantic_v1/semantic_sanity_scenarios_v1.csv`

Issues:

{sanity_issue_list or "- None"}

## NEED_REVIEW Places

{need_review_list or "- None"}

## PARTIAL Places

{partial_list or "- None"}

## Sanity Ranking Samples

{chr(10).join(sanity_sections)}

## Notes

- `semantic_status` and `runtime_eligible` live in the AI artifact, not PostgreSQL schema.
- PostgreSQL `place_tag_links` is synced only for runtime places already present in `places`.
- The 42 coordinate-unresolved canonical places remain in the AI artifact with `runtime_eligible=false`.
- Existing taxonomy and interest mappings are frozen for this release.
"""


def package_readme(summary):
    return f"""# AI Handoff Semantic V1 FINAL

This folder is the frozen `semantic-v1` training handoff package for GoMate.

## Identity

- Stable AI Place key: `external_id`
- Runtime backend Place key: `places.id`
- Catalog version: `tour_places_v11`
- Semantic release: `semantic-v1 FINAL`

## Counts

- Canonical places: {summary['canonicalPlaces']}
- Runtime eligible: {summary['runtimeEligible']}
- Runtime ineligible: {summary['runtimeIneligible']}
- READY: {summary['ready']}
- PARTIAL: {summary['partial']}
- NEED_REVIEW: {summary['needReview']}
- Place-tag links: {summary['placeTagLinks']}

## Use

Use `semantic_v1/ai_place_semantic_matrix_v1.csv` for wide content features, or `semantic_v1/ai_place_tags_v1.csv` for explainable long-form features.

Do not train on `places.id` as a stable cross-machine key. Join model output back to backend runtime data through `external_id`.

QA helpers:

- `semantic_v1/semantic_interest_coverage_v1.csv`
- `semantic_v1/semantic_category_coverage_v1.csv`
- `semantic_v1/semantic_sanity_scenarios_v1.csv`

Missing `0.0` values on `PARTIAL` places mean unknown or insufficient evidence, not a confirmed negative signal.
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="backend/src/main/resources/data/place_catalog_v11.csv")
    parser.add_argument("--output-dir", default="backend/src/main/resources/data/ai_handoff/semantic_v1")
    parser.add_argument("--package-dir", default="AI_HANDOFF_SEMANTIC_V1_FINAL")
    args = parser.parse_args()

    repo = Path.cwd()
    catalog_path = repo / args.catalog
    output_dir = repo / args.output_dir
    package_dir = repo / args.package_dir
    docs_dir = repo / "docs"

    catalog = read_csv(catalog_path)
    tag_taxonomy = [row(tag_code=code, tag_name=name, definition=definition, active="true") for code, name, definition in TAG_TAXONOMY]
    tag_codes = [r["tag_code"] for r in tag_taxonomy]
    interest_mappings = [
        row(interest_code=interest, tag_code=tag, weight=weight, mapping_version=SEMANTIC_VERSION)
        for interest, tag, weight in INTEREST_TAG_MAPPINGS
    ]

    place_tag_rows = []
    status_by_place = {}
    for place in catalog:
        tags = semantic_tags_for_place(place)
        status, status_reason = semantic_status(place, tags)
        status_by_place[place["external_id"]] = (status, status_reason)
        runtime = "true" if runtime_eligible(place) else "false"
        for tag_code in sorted(tags):
            data = tags[tag_code]
            evidence = data["evidence"][0]
            place_tag_rows.append(row(
                external_id=place["external_id"],
                canonical_name=place["canonical_name"],
                destination_key=place["destination_key"],
                category=place["category"],
                tag_code=tag_code,
                weight=f"{data['weight']:.1f}",
                source_type=evidence["source_type"],
                source_ref=evidence["source_ref"],
                reason=evidence["reason"],
                semantic_status=status,
                runtime_eligible=runtime,
                semantic_data_version=SEMANTIC_VERSION,
                status_reason=status_reason,
            ))

    by_place = defaultdict(list)
    for r in place_tag_rows:
        by_place[r["external_id"]].append(r)

    matrix_rows = []
    for place in catalog:
        status, _ = status_by_place[place["external_id"]]
        matrix = row(
            external_id=place["external_id"],
            canonical_name=place["canonical_name"],
            destination_key=place["destination_key"],
            category=place["category"],
            runtime_eligible="true" if runtime_eligible(place) else "false",
            semantic_status=status,
        )
        weights = {r["tag_code"]: r["weight"] for r in by_place.get(place["external_id"], [])}
        for tag in tag_codes:
            matrix[tag] = weights.get(tag, "0.0")
        matrix_rows.append(matrix)

    errors = validate(catalog, place_tag_rows, tag_codes, interest_mappings, matrix_rows)
    status_counter = Counter(status for status, _ in status_by_place.values())
    runtime_counter = Counter("true" if runtime_eligible(p) else "false" for p in catalog)
    source_counter = Counter(r["source_type"] for r in place_tag_rows)
    weight_counter = Counter(r["weight"] for r in place_tag_rows)
    tag_counter = Counter(r["tag_code"] for r in place_tag_rows)
    links_per_place = [len(by_place.get(p["external_id"], [])) for p in catalog]
    interest_coverage = Counter(r["interest_code"] for r in interest_mappings)
    sanity_rows = build_sanity_scores(catalog, place_tag_rows, interest_mappings)
    category_coverage_rows = build_category_coverage(catalog, place_tag_rows, status_by_place)
    interest_coverage_rows = build_interest_coverage(catalog, place_tag_rows, interest_mappings)
    scenario_rows = build_sanity_scenarios(catalog, place_tag_rows, interest_mappings)
    sanity_issues = detect_sanity_issues(scenario_rows)
    runtime_status_counter = Counter()
    runtime_ineligible_status_counter = Counter()
    for place in catalog:
        status, _ = status_by_place[place["external_id"]]
        if runtime_eligible(place):
            runtime_status_counter[status] += 1
        else:
            runtime_ineligible_status_counter[status] += 1

    generated_at = datetime.now(timezone.utc).isoformat()
    summary = {
        "semanticDataVersion": SEMANTIC_VERSION,
        "releaseStatus": RELEASE_STATUS,
        "placeCatalogVersion": CATALOG_VERSION,
        "generatedAt": generated_at,
        "canonicalPlaces": len(catalog),
        "runtimeEligible": runtime_counter["true"],
        "runtimeIneligible": runtime_counter["false"],
        "ready": status_counter["READY"],
        "partial": status_counter["PARTIAL"],
        "needReview": status_counter["NEED_REVIEW"],
        "placeTagLinks": len(place_tag_rows),
        "tagCount": len(tag_codes),
        "interestCount": len(INTEREST_TAXONOMY),
        "semanticInterestCount": sum(1 for r in INTEREST_TAXONOMY if r["interest_type"] == "SEMANTIC"),
        "contextStrategyCount": len(CONTEXT_STRATEGY),
        "interestTagMappingCount": len(interest_mappings),
        "averageTagsPerPlace": round(statistics.mean(links_per_place), 2),
        "medianTagsPerPlace": statistics.median(links_per_place),
        "weightDistribution": dict(sorted(weight_counter.items())),
        "sourceDistribution": dict(sorted(source_counter.items())),
        "semanticStatusDistribution": dict(sorted(status_counter.items())),
        "runtimeEligibilityDistribution": dict(sorted(runtime_counter.items())),
        "runtimeSemanticStatusDistribution": dict(sorted(runtime_status_counter.items())),
        "runtimeIneligibleSemanticStatusDistribution": dict(sorted(runtime_ineligible_status_counter.items())),
        "tagCoverage": dict(tag_counter.most_common()),
        "interestMappingCoverage": dict(sorted(interest_coverage.items())),
        "semanticInterestCoverage": interest_coverage_rows,
        "sanityScenarioCount": len({(r["destination"], r["interest"]) for r in scenario_rows}),
        "sanityScenarioRows": len(scenario_rows),
        "sanityIssueCount": len(sanity_issues),
        "sanityIssues": sanity_issues,
        "validationErrors": errors,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(output_dir / "ai_interest_taxonomy_v1.csv", INTEREST_TAXONOMY)
    write_csv(output_dir / "ai_place_tag_taxonomy_v1.csv", tag_taxonomy)
    write_csv(output_dir / "ai_interest_tag_mapping_v1.csv", interest_mappings)
    write_csv(output_dir / "ai_place_tags_v1.csv", place_tag_rows, [
        "external_id", "canonical_name", "destination_key", "category", "tag_code", "weight",
        "source_type", "source_ref", "reason", "semantic_status", "runtime_eligible",
        "semantic_data_version", "status_reason",
    ])
    write_csv(output_dir / "ai_place_semantic_matrix_v1.csv", matrix_rows)
    write_csv(output_dir / "ai_context_strategy_v1.csv", CONTEXT_STRATEGY)
    write_csv(output_dir / "semantic_v1_sanity_scores.csv", sanity_rows)
    write_csv(output_dir / "semantic_interest_coverage_v1.csv", interest_coverage_rows)
    write_csv(output_dir / "semantic_category_coverage_v1.csv", category_coverage_rows)
    write_csv(output_dir / "semantic_sanity_scenarios_v1.csv", scenario_rows)
    write_json(output_dir / "semantic_v1_manifest.json", {
        "semanticDataVersion": SEMANTIC_VERSION,
        "releaseStatus": RELEASE_STATUS,
        "placeCatalogVersion": CATALOG_VERSION,
        "generatedAt": generated_at,
        "canonicalPlaceCount": len(catalog),
        "runtimeEligibleCount": runtime_counter["true"],
        "runtimeIneligibleCount": runtime_counter["false"],
        "readyCount": status_counter["READY"],
        "partialCount": status_counter["PARTIAL"],
        "needReviewCount": status_counter["NEED_REVIEW"],
        "interestCount": len(INTEREST_TAXONOMY),
        "semanticInterestCount": summary["semanticInterestCount"],
        "contextStrategyCount": len(CONTEXT_STRATEGY),
        "tagCount": len(tag_codes),
        "interestTagMappingCount": len(interest_mappings),
        "placeTagLinkCount": len(place_tag_rows),
        "sanityScenarioCount": summary["sanityScenarioCount"],
        "sanityIssueCount": summary["sanityIssueCount"],
        "notes": [
            "semantic-v1 FINAL uses category rules, catalog-name rules, and limited manual review overrides.",
            "No external web sources were used in this pass.",
            "Screen 3 options are exported as context strategy, not long-term semantic profile.",
            "Missing tags on PARTIAL places mean unknown or insufficient evidence, not confirmed negative preference.",
        ],
    })
    write_json(output_dir / "semantic_v1_qa_summary.json", summary)
    generate_sync_sql(output_dir / "sync_place_tag_links_v1.sql", place_tag_rows)

    partial_rows = []
    need_review_rows = []
    seen_status = set()
    for place in catalog:
        status, reason = status_by_place[place["external_id"]]
        item = row(external_id=place["external_id"], canonical_name=place["canonical_name"], status_reason=reason)
        if status == "PARTIAL":
            partial_rows.append(item)
        elif status == "NEED_REVIEW":
            need_review_rows.append(item)
        seen_status.add(status)

    (docs_dir / "SEMANTIC_ENRICHMENT_V1_FINAL.md").write_text(
        markdown_report(summary, partial_rows, need_review_rows, sanity_rows, category_coverage_rows, interest_coverage_rows, scenario_rows, sanity_issues),
        encoding="utf-8",
    )

    package_dir.mkdir(parents=True, exist_ok=True)
    (package_dir / "README.md").write_text(package_readme(summary), encoding="utf-8")
    shutil.copyfile(repo / "backend/src/main/resources/data/ai_place_catalog_v11.csv", package_dir / "ai_place_catalog_v11.csv")
    shutil.copyfile(repo / "backend/src/main/resources/data/ai_place_features_v11.csv", package_dir / "ai_place_features_v11.csv")
    pkg_semantic = package_dir / "semantic_v1"
    if pkg_semantic.exists():
        shutil.rmtree(pkg_semantic)
    shutil.copytree(output_dir, pkg_semantic)
    pkg_docs = package_dir / "docs"
    pkg_docs.mkdir(exist_ok=True)
    shutil.copyfile(docs_dir / "AI_SEMANTIC_DATA_HANDOFF_V1.md", pkg_docs / "AI_SEMANTIC_DATA_HANDOFF_V1.md")
    shutil.copyfile(docs_dir / "SEMANTIC_FOUNDATION_V4.md", pkg_docs / "GOMATE_SEMANTIC_FOUNDATION_AI_GUIDE.md")

    if errors:
        raise SystemExit("Validation failed: " + "; ".join(errors))

    print("Generated semantic-v1 FINAL package")
    print(f"  canonical places: {len(catalog)}")
    print(f"  ready: {status_counter['READY']}")
    print(f"  partial: {status_counter['PARTIAL']}")
    print(f"  needReview: {status_counter['NEED_REVIEW']}")
    print(f"  runtimeEligible: {runtime_counter['true']}")
    print(f"  placeTagLinks: {len(place_tag_rows)}")


if __name__ == "__main__":
    main()
