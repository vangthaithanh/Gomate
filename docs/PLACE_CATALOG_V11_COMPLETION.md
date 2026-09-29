# PLACE_CATALOG_V11_COMPLETION.md

Updated: 2026-09-20

## Scope

Completed the V11 canonical Place catalog alignment/completion step.

Rules preserved:
- No new database table.
- No new Flyway migration.
- No Auth, Trip, AI model, or Flutter Map architecture change.
- No mass image upload.
- `backend/src/main/resources/data/place_catalog_v11.csv` is the master catalog.
- `ai_place_catalog_v11.csv` and `ai_place_features_v11.csv` are derived from the master catalog.
- Backend business identity remains `places.id`.
- AI/training identity remains `external_id`.

## Identity Contract

Canonical source:

```text
external_source=tour_places_v11
external_id={destination_key}:{normalized_canonical_name}
```

Examples:
- `da_lat:ho_xuan_huong`
- `ha_noi:ho_hoan_kiem`
- `da_nang_hue_hoi_an:cau_rong`

Do not use `places.id` as AI/training key.

## Files

Created/updated:
- `scripts/place_catalog_completion.py`
- `backend/src/main/resources/data/place_catalog_v11.csv`
- `backend/src/main/resources/data/ai_place_catalog_v11.csv`
- `backend/src/main/resources/data/ai_place_features_v11.csv`
- `backend/src/main/resources/data/place_catalog_v11_completion_preview.csv`
- `backend/src/main/resources/data/place_catalog_v11_db_import_preview.csv`
- `backend/src/main/resources/data/place_seed_v11_canonical_import.csv`
- `backend/src/main/resources/data/place_category_taxonomy_v11.csv`
- `docs/PLACE_CATALOG_V11_COMPLETION.md`

Temporary geocode cache was removed after generation.

## Category Taxonomy

The catalog uses the existing `place_categories` contract instead of creating new categories:

| Code | Name | Meaning |
|---|---|---|
| `food` | An uong | Restaurants, cafes, food stops |
| `market` | Cho va mua sam | Markets, shopping, local specialties |
| `lake` | Ho va canh quan | Lakes, rivers, water landscapes |
| `heritage` | Di tich va van hoa | Heritage, architecture, museum, spiritual/cultural places |
| `nature` | Thien nhien | Beaches, mountains, waterfalls, islands, natural landscapes |
| `landmark` | Diem tham quan | Check-in points, tourist areas, parks, entertainment places |

Category coverage in master catalog:
- `food`: 6
- `heritage`: 51
- `lake`: 21
- `landmark`: 52
- `market`: 3
- `nature`: 55

## Catalog Result

Master catalog:
- Total rows: 188
- Unique `external_id`: 188
- Rows with verified coordinates: 146
- Rows held for manual coordinate review: 42

By destination:

| destination_key | total | with coordinates | unresolved |
|---|---:|---:|---:|
| `da_lat` | 63 | 41 | 22 |
| `da_nang_hue_hoi_an` | 31 | 29 | 2 |
| `ha_noi` | 33 | 31 | 2 |
| `phan_thiet` | 22 | 17 | 5 |
| `vung_tau` | 39 | 28 | 11 |

Coordinates were accepted only when the place could be matched by source/context. Ambiguous rows were left unresolved instead of guessed.

## DB Preview

Preview file:

```text
backend/src/main/resources/data/place_catalog_v11_db_import_preview.csv
```

Actions:
- `UPDATE_EXISTING`: 36
- `INSERT_NEW`: 110
- `HOLD_MANUAL_REVIEW`: 42

By destination:

| destination_key | update existing | insert new | hold review |
|---|---:|---:|---:|
| `da_lat` | 36 | 5 | 22 |
| `da_nang_hue_hoi_an` | 0 | 29 | 2 |
| `ha_noi` | 0 | 31 | 2 |
| `phan_thiet` | 0 | 17 | 5 |
| `vung_tau` | 0 | 28 | 11 |

## Import Result

Import source:

```text
backend/src/main/resources/data/place_seed_v11_canonical_import.csv
```

The importer used canonical key `(external_source, external_id)`.

DB after import:
- `places`: 146
- `places` with `external_source=tour_places_v11`: 146
- Distinct canonical `external_id`: 146
- `place_media`: 5
- Duplicate canonical `external_id`: 0

Flyway history is unchanged:
- V1 `Auth current schema baseline`
- V2 `place foundation`

No V3 migration was created.

Idempotency:
- First run: `seedRows=146 placesUpserted=146 mediaCreated=0 mediaSkipped=146 mediaFailed=0`
- Second run: `seedRows=146 placesUpserted=146 mediaCreated=0 mediaSkipped=146 mediaFailed=0`
- No duplicate place/media rows observed.

Images:
- No new mass upload was performed.
- Existing 5 media rows were preserved.
- Rows without license-clear image were imported without media.

## API Verification

Checked against local API on port 8081:

- `GET /api/v1/places`: 146 places
- `GET /api/v1/places/search?q=Hồ`: 39 results
- `GET /api/v1/places/search?q=Ba`: 12 results
- `GET /api/v1/places/154`: `Bà Nà Hills`, media count 0, no crash
- `GET /api/v1/places/3`: `Hồ Xuân Hương`, media count 1, Cloudinary media preserved

## Route Verification

Checked with `POST /api/v1/routes/directions`.

Place-to-place routes:

| Route | Distance | Duration | Geometry points |
|---|---:|---:|---:|
| Ho Xuan Huong -> Thien Vien Truc Lam | 6352.6 m | 879.3 s | 301 |
| Cau Rong -> Bien My Khe | 3948.6 m | 698.2 s | 129 |
| Ho Hoan Kiem -> Van Mieu Quoc Tu Giam | 2107.0 m | 476.5 s | 99 |
| Doi Cat Bay -> Bien Mui Ne | 14225.4 m | 1292.2 s | 260 |
| Bai Sau -> Tuong Chua Kito | 6639.6 m | 1522.9 s | 288 |

Current-location style route:
- Runtime origin lat/lng `11.9419,108.4483` -> destination `Thiền Viện Trúc Lâm`
- Result: 6352.6 m, 879.3 s, 301 geometry points

Note: `Bà Nà Hills -> Cầu Vàng` returned geometry but 0 m because Mapbox snapped both nearby points to the same routable location. Use a farther pair for route regression.

## Build/Test

`docker compose build api` completed successfully.

The backend Dockerfile runs:

```text
mvn --batch-mode clean verify
```

Result:

```text
BUILD SUCCESS
```

This covers backend tests, including current Auth/Google flow tests in the backend test suite.

Host note:
- Local `mvn` is not installed on this PC.
- Backend test/build was verified through Docker instead.

## Manual Review List

These 42 catalog rows remain out of PostgreSQL because coordinates were not verified confidently and `places.latitude/longitude` are NOT NULL.

### da_lat

- Bảo Tàng Madame De
- Cafe Miền Du Mục
- Cánh Đồng Hoa Cẩm Tú Cầu
- Cổng Trời Bali Green Hill
- Đại Bảo Tháp Kinh Luân
- Dapa Hill
- Đồi Robin
- Fresh Garden
- Gallery La Chocotea
- Hoa Sơn Điền Trang
- KDL Suối Bình Yên
- Kombi Land
- Lạc Hư Cổ Trấn
- Lặng Art Café
- Nông Trại Cổ Tích
- Que Garden
- Rừng Hoa Khô
- Thị Trấn Iyashi
- Tiệm Nướng Chuyến Tàu Hoàng Hôn
- Tu Viện Bát Nhã
- Vườn Châu Âu
- Vườn Địa Đàng

### da_nang_hue_hoi_an

- Biển An Bàng
- Thánh Địa La Vang

### ha_noi

- Làng Cổ Đường Lâm
- Nhà Thờ Đá Sapa

### phan_thiet

- Bảo Tàng Ngọc Trai
- Bàu Sen
- Circus Land
- Công Viên Bikini Beach
- Tháp Chàm Poshanu

### vung_tau

- Biển Tropicana
- Cầu Ngắm Biển Hamptons
- Cầu Tình Yêu Long Hải
- Hồ Suối Mơ Bình Châu
- KDL Biển Đông
- KDL Ngọc Xương
- Khu Giếng Trời Bình Châu
- Lăng Cá Ông
- Nông Trại Cừu
- Núi Minh Đạm
- Tháp Vọng Thiên

## Warnings

- Some geocoder administrative labels reflect the post-2025/2026 Vietnamese province/administrative naming context. If the project wants old province labels for UX, normalize display province in a separate explicit data-cleaning task.
- Some rows look like tour/vendor naming rather than stable public POIs. Keep them in manual review until source/canonical coordinates are confirmed.
- Because schema requires latitude/longitude, unresolved rows are intentionally not imported.
- `ai_place_catalog_v11.csv` and `ai_place_features_v11.csv` should be regenerated from the master catalog, not edited by hand.
