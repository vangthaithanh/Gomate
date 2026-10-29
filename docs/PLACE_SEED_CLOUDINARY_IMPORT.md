# GoMate Place Seed + Cloudinary Remote Import

Updated: 2026-09-19

## Scope

This step imports a small Da Lat Place seed into the existing V2 schema:

- `place_categories`
- `places`
- `place_media`

No migration is created for this step. `V1__auth_current_baseline.sql` and `V2__place_foundation.sql` remain unchanged.

Out of scope:

- Flutter Map integration
- replacing `DemoPlaceCatalog`
- reviews/saves/tags/trips/posts
- generic media/files/attachments tables

## Seed Source

Seed file:

```text
backend/src/main/resources/data/place_seed_dalat.csv
```

The selected Place names are taken from the provided `tour_places_v11.csv` dataset:

- Quảng Trường Lâm Viên
- Hồ Xuân Hương
- Dinh Bảo Đại
- Thiền Viện Trúc Lâm
- Hồ Tuyền Lâm

The dataset does not include coordinates or image URLs, so the seed file adds coordinates and reviewed remote image URLs. The first Lâm Viên row uses Wikimedia Commons. The current seed uses Flickr static image URLs for the other rows because Cloudinary remote fetch received `429 Too Many Requests` from Wikimedia during the import. The seed keeps `image_source_page`, `image_license`, and `image_attribution` columns for traceability, but PostgreSQL production media uses only Cloudinary `secure_url` and `public_id`.

## Import Flow

```text
seed CSV row
  -> resolve/create place category
  -> upsert place by external_source + external_id
  -> check place_media by deterministic Cloudinary public_id
  -> Cloudinary remote URL upload
  -> insert place_media secure_url + public_id
```

Cloudinary folder default:

```text
gomate/dev/places/{placeId}/seed-{externalId}
```

## Idempotency

Place idempotency:

- `places` uses `external_source + external_id`.
- Running import again updates the same Place row instead of inserting duplicates.

Media idempotency:

- importer checks deterministic `public_id` in `place_media` before uploading.
- Running import again skips existing media.

## Failure Rules

Cloudinary upload failure:

- no fake `place_media` row is inserted
- Place data remains upserted
- upload is retried using `PLACE_SEED_MEDIA_RETRY_ATTEMPTS` and `PLACE_SEED_MEDIA_RETRY_DELAY_MS`
- failure is logged and the importer exits non-zero in one-shot mode

Remote sources such as Wikimedia may return `429 Too Many Requests` when Cloudinary fetches several images quickly. Increase `PLACE_SEED_MEDIA_RETRY_DELAY_MS` for one-shot imports if that happens.

DB media insert failure after Cloudinary upload:

- importer attempts to delete the uploaded Cloudinary asset
- failed cleanup logs the `public_id`

## Run One-Shot Import

Use the built API image and the existing Docker database:

```powershell
docker compose run --rm `
  -e PLACE_SEED_ENABLED=true `
  -e PLACE_SEED_EXIT_AFTER_RUN=true `
  -e PLACE_SEED_LIMIT=10 `
  -e PLACE_SEED_MEDIA_RETRY_ATTEMPTS=3 `
  -e PLACE_SEED_MEDIA_RETRY_DELAY_MS=10000 `
  api
```

Normal API startup keeps `PLACE_SEED_ENABLED=false`.

## Verify

```powershell
docker compose exec -T postgres psql -U gomate -d gomate_auth -c "SELECT COUNT(*) FROM places;"
docker compose exec -T postgres psql -U gomate -d gomate_auth -c "SELECT COUNT(*) FROM place_media;"
Invoke-RestMethod http://localhost:8081/api/v1/places
Invoke-RestMethod "http://localhost:8081/api/v1/places/search?q=Hồ"
```

Flyway should still show only V1 and V2.
