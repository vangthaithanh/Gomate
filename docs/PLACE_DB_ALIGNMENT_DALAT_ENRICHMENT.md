# PLACE DB ALIGNMENT + DA LAT ENRICHMENT

Updated: 2026-09-20

## Scope

This step aligns the existing Da Lat places to the canonical V11 catalog and imports only the Da Lat records that are safe for the current `places` schema.

No new table, Flyway migration, Auth change, Trip change, AI model change, or Flutter map architecture change was made.

## Important Adjustment

The request target was 63 Da Lat places, but the current `places.latitude` and `places.longitude` columns are required. Because 27 catalog rows still do not have verified coordinates, they were not inserted into PostgreSQL. This avoids guessed coordinates and keeps the API/Map/Route data reliable.

Result:

- Canonical Da Lat rows in catalog: 63
- Existing DB places aligned: 5
- New DB places imported: 31
- Total DB canonical Da Lat places after import: 36
- Held for manual review: 27

## Files Changed/Created

- `backend/src/main/resources/data/place_catalog_v11.csv`
  - Added verified coordinate/address/category data for safe Da Lat rows.
- `backend/src/main/resources/data/place_catalog_dalat_geocode_preview_v11.csv`
  - Geocode validation preview for all 63 Da Lat canonical rows.
- `backend/src/main/resources/data/place_catalog_dalat_import_preview_v11.csv`
  - Preview/diff from current DB to import state.
- `backend/src/main/resources/data/place_seed_dalat_v11_canonical.csv`
  - Importable seed file with 36 verified Da Lat rows.
- `backend/src/main/java/vn/gomate/place/repository/PlaceRepository.java`
  - Made category upsert tolerant of `place_categories.name` uniqueness.
- `backend/src/main/java/vn/gomate/place/seed/PlaceSeedImporter.java`
  - Allows places with no reviewed image source to import while skipping media upload.
- `docs/PLACE_DB_ALIGNMENT_DALAT_ENRICHMENT.md`
  - This report.

## Canonical Identity

AI/training stable identity remains:

- `external_id`

Backend business identity remains:

- `places.id`

The canonical source is now:

- `external_source=tour_places_v11`

## 5 Existing Places Aligned

| places.id | name | external_id | media |
|---:|---|---|---:|
| 2 | Quảng Trường Lâm Viên | `da_lat:quang_truong_lam_vien` | 1 |
| 3 | Hồ Xuân Hương | `da_lat:ho_xuan_huong` | 1 |
| 6 | Dinh Bảo Đại | `da_lat:dinh_bao_dai` | 1 |
| 7 | Thiền Viện Trúc Lâm | `da_lat:thien_vien_truc_lam` | 1 |
| 8 | Hồ Tuyền Lâm | `da_lat:ho_tuyen_lam` | 1 |

All 5 kept the same `places.id`, and existing `place_media` rows were preserved.

## Preview Summary

| Metric | Count |
|---|---:|
| Da Lat canonical rows | 63 |
| Existing places to align | 5 |
| New importable places | 31 |
| Rows with verified coordinates | 36 |
| Rows missing verified coordinates | 27 |
| Rows with reviewed reusable image source | 0 |
| Rows without reviewed image source | 63 |
| Duplicate canonical identity | 0 |

Geocode source used:

- Existing seed coordinates for the original 5 places.
- Nominatim/OpenStreetMap for verified coordinates.
- OSM data is subject to OpenStreetMap contributor/ODbL attribution.
- Wikidata lookup was attempted, but it did not add extra safe matches for this batch.

## Import Result

Operational note:

- The first import attempt stopped after 16 places because the generated seed had `category_code=lake` with `category_name=Điểm tham quan`, while the existing DB already had `lake = Hồ và cảnh quan` and `landmark = Điểm tham quan`.
- The seed was corrected for the lake rows, and `PlaceRepository.upsertCategory` was made tolerant of the existing unique `place_categories.name` constraint.
- The importer was rerun safely by canonical `(external_source, external_id)` upsert, so the partial rows did not become duplicates.

Importer run:

- `seedRows=36`
- `placesUpserted=36`
- `mediaCreated=0`
- `mediaSkipped=36`
- `mediaFailed=0`

Database verification after import:

- `places_total=36`
- `canonical_total=36`
- `canonical_external_ids=36`
- `dalat_canonical=36`
- `place_media=5`
- Duplicate canonical `external_id`: 0 rows
- Flyway history: V1 Auth baseline + V2 Place foundation only

## Idempotency

The importer was run twice with the same seed file.

Second run result:

- `seedRows=36`
- `placesUpserted=36`
- `mediaCreated=0`
- `mediaSkipped=36`
- `mediaFailed=0`

No duplicate place rows or media rows were created.

## Cloudinary

No new Cloudinary upload was performed in this task because no new image source had a clearly reviewed reuse/license path.

Existing 5 Cloudinary-backed media rows remain intact and still belong to the original 5 places.

## API Verification

`GET /api/v1/places`

- Returned 36 places.

`GET /api/v1/places/search?q=Chợ`

- Returned `Chợ Đà Lạt`.

`GET /api/v1/places/{id}`

- `Chợ Đà Lạt` detail returned successfully with `media=[]`.
- No crash for no-media places.

## Route Verification

Place-to-place route:

- Origin: `Chợ Đà Lạt`, `places.id=30`
- Destination: `Hồ Xuân Hương`, `places.id=3`
- Distance: `1955.872` meters
- Duration: `424.617` seconds
- Geometry points: `97`

Current-location runtime route:

- Origin: runtime coordinates `11.9400,108.4380`
- Destination: `Hồ Xuân Hương`, `places.id=3`
- Distance: `1430.579` meters
- Duration: `297.793` seconds
- Geometry points: `61`

## Backend/Test Verification

`docker compose build api`

- Build success.
- Maven tests: `42` run, `0` failures, `0` errors.
- Auth/Firebase/Google regression covered by existing test suite during build.

## Manual Review List

These 27 places remain in the catalog but were not imported into PostgreSQL because verified coordinates are still missing:

- Bảo Tàng Madame De
- Cafe Miền Du Mục
- Cánh Đồng Hoa Cẩm Tú Cầu
- Cổng Trời Bali Green Hill
- Đại Bảo Tháp Kinh Luân
- Dapa Hill
- Đồi Robin
- Fresh Garden
- Gallery La Chocotea
- Hồ Vô Cực
- Hoa Sơn Điền Trang
- KDL Suối Bình Yên
- Kombi Land
- Lạc Hư Cổ Trấn
- Lặng Art Café
- Nấc Thang Thiên Đường
- Nhà Thờ Con Gà
- Nông Trại Cổ Tích
- Que Garden
- Rừng Hoa Khô
- Thác Pongour
- Thị Trấn Iyashi
- Tiệm Nướng Chuyến Tàu Hoàng Hôn
- Tu Viện Bát Nhã
- Vườn Châu Âu
- Vườn Địa Đàng
- Xưởng Tơ Lụa

## Next Safe Step

Review/fill coordinates for the 27 held rows, then create the next import seed batch. Media enrichment should stay separate and only upload images after source/license review.
