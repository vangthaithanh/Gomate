#!/usr/bin/env python3
"""
Complete reviewed cover-media metadata for imported GoMate Places.

The script treats backend/src/main/resources/data/place_catalog_v11.csv as the
    master catalog, queries Wikimedia Commons for free-license image candidates,
    and writes import/report CSV artifacts. It does not download images locally.
"""

from __future__ import annotations

import csv
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "backend" / "src" / "main" / "resources" / "data"
CATALOG_PATH = DATA_DIR / "place_catalog_v11.csv"
SEED_PATH = DATA_DIR / "place_seed_v11_media_completion.csv"
REPORT_PATH = DATA_DIR / "place_media_completion_report.csv"
SUMMARY_PATH = DATA_DIR / "place_media_completion_summary.json"
CACHE_PATH = DATA_DIR / ".place_media_completion_wikimedia_cache.json"

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "GoMateMediaImporter/1.0 (local development; contact: gomate-local@example.com)"

DESTINATION_ORDER = [
    "da_lat",
    "vung_tau",
    "ha_noi",
    "da_nang_hue_hoi_an",
    "phan_thiet",
]

CATEGORY_DESCRIPTIONS = {
    "food": ("An uong", "Restaurants, cafes, food stops"),
    "market": ("Cho va mua sam", "Markets, shopping, local specialties"),
    "lake": ("Ho va canh quan", "Lakes, rivers, water landscapes"),
    "heritage": ("Di tich va van hoa", "Heritage, architecture, museum, spiritual/cultural places"),
    "nature": ("Thien nhien", "Beaches, mountains, waterfalls, islands, natural landscapes"),
    "landmark": ("Diem tham quan", "Check-in points, tourist areas, parks, entertainment places"),
}

DESTINATION_CONTEXT = {
    "da_lat": ["Da Lat", "Lâm Đồng", "Vietnam"],
    "vung_tau": ["Vung Tau", "Bà Rịa Vũng Tàu", "Vietnam"],
    "ha_noi": ["Hanoi", "Hà Nội", "Vietnam"],
    "da_nang_hue_hoi_an": ["Da Nang", "Hue", "Hoi An", "Vietnam"],
    "phan_thiet": ["Phan Thiết", "Mũi Né", "Bình Thuận", "Vietnam"],
}

MANUAL_ALIASES = {
    "da_lat:ho_xuan_huong": ["Xuan Huong Lake"],
    "da_lat:ho_tuyen_lam": ["Tuyen Lam Lake"],
    "da_lat:thien_vien_truc_lam": ["Truc Lam Temple Da Lat", "Trúc Lâm Đà Lạt"],
    "da_lat:dinh_bao_dai": ["Bao Dai Summer Palace", "Bảo Đại Palace Đà Lạt"],
    "da_lat:quang_truong_lam_vien": ["Lam Vien Square"],
    "da_lat:cho_da_lat": ["Da Lat Market"],
    "da_lat:chua_linh_phuoc": ["Linh Phuoc Pagoda"],
    "da_lat:crazy_house": ["Hang Nga Guesthouse", "Crazy House Da Lat"],
    "da_lat:langbiang": ["Lang Biang"],
    "ha_noi:ho_hoan_kiem": ["Hoan Kiem Lake", "Lake of the Restored Sword"],
    "ha_noi:van_mieu_quoc_tu_giam": ["Temple of Literature Hanoi"],
    "ha_noi:lang_chu_tich_ho_chi_minh": ["Ho Chi Minh Mausoleum"],
    "ha_noi:nha_hat_lon_ha_noi": ["Hanoi Opera House"],
    "ha_noi:nha_tho_lon_ha_noi": ["St Joseph's Cathedral Hanoi"],
    "ha_noi:pho_co_ha_noi": ["Hanoi Old Quarter"],
    "ha_noi:ho_tay": ["West Lake Hanoi"],
    "da_nang_hue_hoi_an:cau_rong": ["Dragon Bridge Da Nang"],
    "da_nang_hue_hoi_an:bien_my_khe": ["My Khe Beach Da Nang"],
    "da_nang_hue_hoi_an:ban_dao_son_tra": ["Son Tra Peninsula"],
    "da_nang_hue_hoi_an:cau_vang": ["Golden Bridge Ba Na Hills"],
    "da_nang_hue_hoi_an:ba_na_hills": ["Ba Na Hills"],
    "da_nang_hue_hoi_an:pho_co_hoi_an": ["Hội An Ancient Town", "Hoi An Ancient Town"],
    "da_nang_hue_hoi_an:chua_cau_hoi_an": ["Japanese Covered Bridge Hoi An"],
    "da_nang_hue_hoi_an:dai_noi_hue": ["Imperial City Hue"],
    "da_nang_hue_hoi_an:chua_thien_mu": ["Thien Mu Pagoda"],
    "phan_thiet:bien_mui_ne": ["Mui Ne beach"],
    "phan_thiet:doi_cat_bay": ["Mui Ne sand dunes", "Red Sand Dunes Mui Ne"],
    "phan_thiet:suoi_tien": ["Fairy Stream Mui Ne"],
    "phan_thiet:hai_dang_ke_ga": ["Ke Ga Lighthouse"],
    "vung_tau:bai_sau": ["Back Beach Vung Tau"],
    "vung_tau:bai_truoc": ["Front Beach Vung Tau"],
    "vung_tau:tuong_chua_kito": ["Christ of Vung Tau"],
    "vung_tau:hai_dang_vung_tau": ["Vung Tau Lighthouse"],
    "vung_tau:hon_ba": ["Hòn Bà Vũng Tàu"],
}


def normalize(value: str | None) -> str:
    if not value:
        return ""
    value = unicodedata.normalize("NFD", value)
    value = "".join(ch for ch in value if unicodedata.category(ch) != "Mn")
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def html_to_text(value: str | None) -> str:
    if not value:
        return ""
    value = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def accepted_license(short_name: str, usage_terms: str) -> bool:
    license_text = normalize(f"{short_name} {usage_terms}")
    if not license_text:
        return False
    if "noncommercial" in license_text or " nc " in f" {license_text} ":
        return False
    if "no derivatives" in license_text or " nd " in f" {license_text} ":
        return False
    return any(
        token in license_text
        for token in [
            "public domain",
            "cc0",
            "cc by",
            "creative commons attribution",
            "creative commons attribution share alike",
            "cc by sa",
        ]
    )


def canonical_license(short_name: str, usage_terms: str) -> str:
    value = short_name or usage_terms
    value = html_to_text(value)
    value = value.replace("CC BY-SA ", "CC-BY-SA-").replace("CC BY ", "CC-BY-")
    value = value.replace("CC0 ", "CC0-")
    return value[:80]


def license_url(license_name: str) -> str:
    urls = {
        "CC-BY-2.0": "https://creativecommons.org/licenses/by/2.0/",
        "CC-BY-3.0": "https://creativecommons.org/licenses/by/3.0/",
        "CC-BY-SA-3.0": "https://creativecommons.org/licenses/by-sa/3.0/",
        "CC-BY-SA-4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
        "CC0": "https://creativecommons.org/publicdomain/zero/1.0/",
    }
    return urls.get(license_name, "")


def is_image_url(url: str | None, mime: str | None = None) -> bool:
    if not url:
        return False
    lower_url = url.lower().split("?", 1)[0]
    lower_mime = (mime or "").lower()
    return lower_mime.startswith("image/") or lower_url.endswith((".jpg", ".jpeg", ".png", ".webp"))


def significant_tokens(name: str) -> set[str]:
    stop = {
        "va", "cua", "dia", "diem", "khu", "du", "lich", "bien", "chua",
        "nui", "ho", "lang", "cho", "da", "nang", "hue", "hoi", "an",
        "ha", "noi", "vung", "tau", "phan", "thiet", "viet", "nam",
    }
    return {token for token in normalize(name).split() if len(token) >= 3 and token not in stop}


def score_candidate(row: dict[str, str], page: dict[str, Any]) -> tuple[int, str]:
    info = page.get("imageinfo", [{}])[0]
    meta = info.get("extmetadata", {})
    title = page.get("title", "")
    haystack = normalize(
        " ".join(
            [
                title,
                html_to_text(meta.get("ObjectName", {}).get("value")),
                html_to_text(meta.get("ImageDescription", {}).get("value")),
                html_to_text(meta.get("Credit", {}).get("value")),
                html_to_text(meta.get("Artist", {}).get("value")),
            ]
        )
    )
    tokens = significant_tokens(row["canonical_name"])
    hits = sorted(token for token in tokens if token in haystack)
    score = len(hits) * 20
    context = " ".join(normalize(v) for v in DESTINATION_CONTEXT.get(row["destination_key"], []))
    if any(token in haystack for token in context.split() if len(token) >= 4):
        score += 20
    if normalize(row["canonical_name"]) in haystack:
        score += 50
    if "vietnam" in haystack or "viet nam" in haystack:
        score += 10
    if page.get("index") == 0:
        score += 5
    return score, " ".join(hits)


def commons_query(query: str, cache: dict[str, Any]) -> list[dict[str, Any]]:
    if query in cache:
        return cache[query]
    if os.environ.get("PLACE_MEDIA_OFFLINE", "").lower() in {"1", "true", "yes"}:
        return []
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": "8",
        "prop": "imageinfo",
        "iiprop": "url|mime|extmetadata",
        "format": "json",
    }
    url = COMMONS_API + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.loads(response.read().decode("utf-8"))
    pages = list(data.get("query", {}).get("pages", {}).values())
    pages.sort(key=lambda item: item.get("index", 9999))
    cache[query] = pages
    time.sleep(0.25)
    return pages


def queries_for(row: dict[str, str]) -> list[str]:
    name = row["canonical_name"]
    destination = row["destination_key"]
    queries: list[str] = []
    for alias in MANUAL_ALIASES.get(row["external_id"], []):
        queries.append(f'"{alias}"')
        queries.append(f'"{alias}" Vietnam')
    queries.append(f'"{name}"')
    for context in DESTINATION_CONTEXT.get(destination, []):
        queries.append(f'"{name}" "{context}"')
    # Commons search works better with unquoted broad English/Vietnam context too.
    queries.append(f"{name} Vietnam")
    seen = set()
    result = []
    for query in queries:
        if query not in seen:
            seen.add(query)
            result.append(query)
    return result


def choose_image(row: dict[str, str], cache: dict[str, Any]) -> dict[str, str]:
    if row.get("image_source_url"):
        if not is_image_url(row.get("image_source_url")):
            return {
                "status": "MANUAL_MEDIA_REVIEW",
                "image_source_url": "",
                "image_source_page": "",
                "image_license": "",
                "image_license_url": "",
                "image_author": "",
                "image_attribution": "",
                "matched_query": "",
                "matched_title": "",
                "match_score": "",
                "manual_reason": "EXISTING_SOURCE_NOT_IMAGE",
            }
        license_name = row.get("image_license", "")
        status = "VERIFIED_READY"
        if "NC" in license_name.upper():
            status = "REPLACE_RECOMMENDED"
        return {
            "status": status,
            "image_source_url": row.get("image_source_url", ""),
            "image_source_page": row.get("image_source_page", ""),
            "image_license": license_name,
            "image_license_url": row.get("image_license_url", license_url(license_name)),
            "image_author": row.get("image_author", ""),
            "image_attribution": row.get("image_attribution", ""),
            "matched_query": "",
            "matched_title": "",
            "match_score": "",
            "manual_reason": "" if status == "VERIFIED_READY" else "Existing media uses NC license; kept in DB but flagged for review.",
        }

    best: tuple[int, dict[str, Any], str, str] | None = None
    errors: list[str] = []
    for query in queries_for(row):
        try:
            pages = commons_query(query, cache)
        except Exception as exc:  # noqa: BLE001 - report and continue to next query
            errors.append(f"{query}: {exc}")
            continue
        for page in pages:
            info = page.get("imageinfo", [{}])[0]
            meta = info.get("extmetadata", {})
            short_name = html_to_text(meta.get("LicenseShortName", {}).get("value"))
            usage_terms = html_to_text(meta.get("UsageTerms", {}).get("value"))
            if not accepted_license(short_name, usage_terms):
                continue
            if not is_image_url(info.get("url", ""), str(info.get("mime", ""))):
                continue
            score, hits = score_candidate(row, page)
            if score < 35:
                continue
            candidate = (score, page, query, hits)
            if best is None or candidate[0] > best[0]:
                best = candidate

    if best is None:
        reason = "NO_LICENSED_IMAGE"
        if errors:
            reason += "; " + " | ".join(errors[:2])
        return {
            "status": "MANUAL_MEDIA_REVIEW",
            "image_source_url": "",
            "image_source_page": "",
            "image_license": "",
            "image_license_url": "",
            "image_author": "",
            "image_attribution": "",
            "matched_query": "",
            "matched_title": "",
            "match_score": "",
            "manual_reason": reason,
        }

    score, page, query, _hits = best
    info = page.get("imageinfo", [{}])[0]
    meta = info.get("extmetadata", {})
    author = html_to_text(meta.get("Artist", {}).get("value"))
    credit = html_to_text(meta.get("Credit", {}).get("value"))
    license_name = canonical_license(
        html_to_text(meta.get("LicenseShortName", {}).get("value")),
        html_to_text(meta.get("UsageTerms", {}).get("value")),
    )
    author_short = (author or credit or "Wikimedia Commons contributor")[:120]
    attribution = f"{author_short} / Wikimedia Commons / {license_name}".strip()
    return {
        "status": "VERIFIED_READY",
        "image_source_url": info.get("url", ""),
        "image_source_page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(page.get("title", "").replace(" ", "_"), safe=":/_()"),
        "image_license": license_name,
        "image_license_url": license_url(license_name),
        "image_author": author_short,
        "image_attribution": attribution[:220],
        "matched_query": query,
        "matched_title": page.get("title", ""),
        "match_score": str(score),
        "manual_reason": "",
    }


def read_catalog() -> list[dict[str, str]]:
    with CATALOG_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    catalog = read_catalog()
    imported = [row for row in catalog if row.get("latitude") and row.get("longitude")]
    imported.sort(key=lambda row: (DESTINATION_ORDER.index(row["destination_key"]), row["canonical_name"]))

    cache: dict[str, Any] = {}
    if CACHE_PATH.exists():
        cache = json.loads(CACHE_PATH.read_text(encoding="utf-8"))

    # Add artifact columns to master catalog if absent.
    for row in catalog:
        row.setdefault("image_author", "")
        row.setdefault("image_attribution", "")
        row.setdefault("image_license_url", "")
        row.setdefault("media_review_status", "")

    media_by_external_id: dict[str, dict[str, str]] = {}
    report_rows: list[dict[str, str]] = []

    for index, row in enumerate(imported, start=1):
        media = choose_image(row, cache)
        media_by_external_id[row["external_id"]] = media
        print(f"[{index:03d}/{len(imported)}] {row['external_id']} -> {media['status']} {media.get('image_license', '')}")
        report_rows.append({
            "external_id": row["external_id"],
            "destination_key": row["destination_key"],
            "canonical_name": row["canonical_name"],
            **media,
        })
        if index % 10 == 0:
            CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")

    for row in catalog:
        media = media_by_external_id.get(row["external_id"])
        if not media:
            row["media_review_status"] = "OUT_OF_SCOPE_UNRESOLVED_COORDINATE"
            continue
        row["image_source_url"] = media["image_source_url"]
        row["image_source_page"] = media["image_source_page"]
        row["image_license"] = media["image_license"]
        row["image_license_url"] = media["image_license_url"]
        row["image_author"] = media["image_author"]
        row["image_attribution"] = media["image_attribution"]
        row["media_review_status"] = media["status"]

    catalog_fields = [
        "external_source",
        "external_id",
        "destination_key",
        "canonical_name",
        "category",
        "province",
        "district",
        "address",
        "latitude",
        "longitude",
        "image_source_url",
        "image_source_page",
        "image_license",
        "image_license_url",
        "image_author",
        "image_attribution",
        "media_review_status",
    ]
    write_csv(CATALOG_PATH, catalog, catalog_fields)

    seed_rows: list[dict[str, str]] = []
    for row in imported:
        media = media_by_external_id[row["external_id"]]
        category_name, category_description = CATEGORY_DESCRIPTIONS.get(row["category"], (row["category"], ""))
        image_caption = media["image_attribution"] or row["canonical_name"]
        seed_rows.append({
            "name": row["canonical_name"],
            "category_code": row["category"],
            "category_name": category_name,
            "category_description": category_description,
            "description": "",
            "province": row["province"],
            "district": row["district"],
            "address": row["address"],
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "source_type": "EXTERNAL_API",
            "external_source": row["external_source"],
            "external_id": row["external_id"],
            "image_source_url": media["image_source_url"] if media["status"] == "VERIFIED_READY" else "",
            "image_source_page": media["image_source_page"],
            "image_license": media["image_license"],
            "image_license_url": media["image_license_url"],
            "image_attribution": media["image_attribution"],
            "image_caption": image_caption[:255],
        })

    seed_fields = [
        "name",
        "category_code",
        "category_name",
        "category_description",
        "description",
        "province",
        "district",
        "address",
        "latitude",
        "longitude",
        "source_type",
        "external_source",
        "external_id",
        "image_source_url",
        "image_source_page",
        "image_license",
        "image_license_url",
        "image_attribution",
        "image_caption",
    ]
    report_fields = [
        "external_id",
        "destination_key",
        "canonical_name",
        "status",
        "image_source_url",
        "image_source_page",
        "image_license",
        "image_license_url",
        "image_author",
        "image_attribution",
        "matched_query",
        "matched_title",
        "match_score",
        "manual_reason",
    ]
    write_csv(SEED_PATH, seed_rows, seed_fields)
    write_csv(REPORT_PATH, report_rows, report_fields)
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")

    summary = {
        "imported_place_rows": len(imported),
        "statuses": {},
        "license_distribution": {},
        "by_destination": {},
    }
    for row in report_rows:
        summary["statuses"][row["status"]] = summary["statuses"].get(row["status"], 0) + 1
        if row["image_license"]:
            summary["license_distribution"][row["image_license"]] = summary["license_distribution"].get(row["image_license"], 0) + 1
        dest = summary["by_destination"].setdefault(row["destination_key"], {"total": 0, "verified_ready": 0, "manual": 0, "replace_recommended": 0})
        dest["total"] += 1
        if row["status"] == "VERIFIED_READY":
            dest["verified_ready"] += 1
        elif row["status"] == "REPLACE_RECOMMENDED":
            dest["replace_recommended"] += 1
        else:
            dest["manual"] += 1
    SUMMARY_PATH.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
