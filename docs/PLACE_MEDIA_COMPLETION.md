# PLACE_MEDIA_COMPLETION.md

Updated: 2026-09-21

## Scope

Prepared the Place media completion phase before Trip Core.

Rules preserved:
- No schema change.
- No Flyway migration.
- No Auth change.
- No Trip change.
- No AI model change.
- No Flutter Map/Place architecture refactor.
- Only the 146 imported Places with verified coordinates were processed.
- The 42 unresolved-coordinate Places remain out of scope.

Flyway remains:
- V1 `Auth current schema baseline`
- V2 `place foundation`

## Source Policy

The media workflow only accepts sources with clear reuse metadata:
- Public Domain / CC0
- CC-BY
- CC-BY-SA

New data intentionally avoids CC-BY-NC. Existing CC-BY-NC media is only reported, not deleted or replaced automatically.

Do not use random Google Images, social media images, or arbitrary websites without clear reuse/license metadata.

## Files

Created/updated:
- `scripts/place_media_completion.py`
- `backend/src/main/java/vn/gomate/media/provider/MediaProvider.java`
- `backend/src/main/java/vn/gomate/media/provider/CloudinaryMediaProvider.java`
- `backend/src/main/java/vn/gomate/media/service/FetchedRemoteImage.java`
- `backend/src/main/java/vn/gomate/media/service/RemoteImageFetcher.java`
- `backend/src/main/java/vn/gomate/media/service/MediaService.java`
- `backend/src/main/java/vn/gomate/place/repository/PlaceRepository.java`
- `backend/src/main/java/vn/gomate/place/seed/PlaceSeedImporter.java`
- `backend/src/main/resources/application.yml`
- `backend/src/main/resources/data/place_catalog_v11.csv`
- `backend/src/main/resources/data/place_seed_v11_media_completion.csv`
- `backend/src/main/resources/data/place_media_completion_report.csv`
- `backend/src/main/resources/data/place_media_completion_summary.json`
- `docs/PLACE_MEDIA_COMPLETION.md`

Temporary Wikimedia cache was removed after report generation.

## Catalog Result

Processed imported Places:
- Total imported Places: 146
- `VERIFIED_READY`: 6
- `REPLACE_RECOMMENDED`: 1
- `MANUAL_MEDIA_REVIEW`: 139

By destination:

| destination_key | imported Places | verified ready | manual review | replace recommended |
|---|---:|---:|---:|---:|
| `da_lat` | 41 | 4 | 36 | 1 |
| `vung_tau` | 28 | 0 | 28 | 0 |
| `ha_noi` | 31 | 1 | 30 | 0 |
| `da_nang_hue_hoi_an` | 29 | 0 | 29 | 0 |
| `phan_thiet` | 17 | 1 | 16 | 0 |

License distribution in reviewed metadata:
- `CC-BY-2.0`: 5
- `CC-BY-SA-4.0`: 1
- `CC-BY-NC-2.0`: 1 existing media review only, excluded from new seed import

## Seed Import Artifact

Seed file:

```text
backend/src/main/resources/data/place_seed_v11_media_completion.csv
```

This seed contains image URLs only for reviewed non-NC sources.

It intentionally excludes the existing `CC-BY-NC-2.0` Dinh Bảo Đại source from future import so a fresh DB will not create new NC media from this task.

## Cloudinary Import Result

The importer no longer depends on Cloudinary remote fetch for source URLs. The final flow is:

```text
image_source_url
-> GoMate backend HttpClient fetches image bytes in memory
-> Cloudinary upload bytes
-> secure_url + public_id
-> place_media
```

No temporary image files are written to disk or committed to the repo.

Remote image fetch guardrails:
- explicit User-Agent via `PLACE_SEED_REMOTE_IMAGE_USER_AGENT`
- timeout via `PLACE_SEED_REMOTE_IMAGE_TIMEOUT_MS`
- max bytes via `PLACE_SEED_REMOTE_IMAGE_MAX_BYTES`
- content-type allowlist: JPEG, PNG, WEBP
- `429` handling with `Retry-After` + exponential backoff
- current importer runs sequentially, so concurrency is 1 and stays below the requested max of 3

Result:

```text
seedRows=146
placesUpserted=146
mediaCreated=2
mediaSkipped=144
mediaFailed=0
```

The previous Wikimedia sources were not retried blindly:
- Cloudinary remote fetch had produced `429`.
- Direct GoMate fetch from this local network returned `403` for several `upload.wikimedia.org` URLs.
- Those rows were moved to `MANUAL_MEDIA_REVIEW` unless a clear replacement source was found.

New Cloudinary assets in this run:

```text
2
```

New assets:
- `gomate/dev/places/198/cover-v11` — Hồ Tây, Flickr `CC-BY-2.0`
- `gomate/dev/places/224/cover-v11` — Mũi Kê Gà, Flickr `CC-BY-2.0`

Current DB media:

```text
place_media rows: 7
Places with media: 7
```

Existing media rows:
- `da_lat:quang_truong_lam_vien`
- `da_lat:ho_xuan_huong`
- `da_lat:dinh_bao_dai`
- `da_lat:thien_vien_truc_lam`
- `da_lat:ho_tuyen_lam`
- `ha_noi:ho_tay`
- `phan_thiet:mui_ke_ga`

`da_lat:dinh_bao_dai` is flagged for license review because the old source is `CC-BY-NC-2.0`. It was not deleted or replaced in this task.

## API Verification

Checked local API on port 8081:

- `GET /api/v1/places`: 146 Places
- List response includes `thumbnailUrl` for media-backed Places, including Hồ Tây and Mũi Kê Gà.
- `GET /api/v1/places/198`: Hồ Tây returns media count 1.
- `GET /api/v1/places/224`: Mũi Kê Gà returns media count 1.
- Cloudinary URL sample returned HTTP 200.

Place without media still returns `media=[]` and Flutter can use fallback image.

## Flutter Verification

No Flutter code was changed in this task.

`flutter analyze` was run. It completed dependency resolution but exited non-zero with 144 existing warnings/infos, mostly:
- deprecated `withOpacity`
- deprecated Mapbox APIs
- unused helper methods
- style/lint suggestions

No new Flutter analyzer issue was introduced by this media task because the task changed data/scripts/docs only.

## Manual Review

The full manual media review list is in:

```text
backend/src/main/resources/data/place_media_completion_report.csv
```

Rows with:

```text
status=MANUAL_MEDIA_REVIEW
```

need a manually verified image source/license before upload.

Rows with:

```text
status=VERIFIED_READY
```

have source metadata ready. They may still be skipped if that Place already has an image media row.

Rows with:

```text
status=REPLACE_RECOMMENDED
```

should be reviewed before reusing or re-importing on a fresh database.

## Retry Guidance

When Wikimedia/Cloudinary fetch is no longer rate-limited, retry only the media seed:

```powershell
$dataPath = (Resolve-Path 'backend/src/main/resources/data').Path
docker compose run --rm -v "${dataPath}:/app/data:ro" `
  -e PLACE_SEED_ENABLED=true `
  -e PLACE_SEED_EXIT_AFTER_RUN=true `
  -e PLACE_SEED_PATH=file:/app/data/place_seed_v11_media_completion.csv `
  -e PLACE_SEED_LIMIT=146 `
  -e PLACE_SEED_MEDIA_RETRY_ATTEMPTS=2 `
  -e PLACE_SEED_MEDIA_RETRY_DELAY_MS=3000 `
  api
```

The import is idempotent because `PlaceSeedImporter` checks whether the Place already has an image cover and also checks deterministic Cloudinary `public_id` before upload:

```text
gomate/dev/places/{placeId}/cover-v11
```

Idempotency verification:

```text
Second run: seedRows=146 placesUpserted=146 mediaCreated=0 mediaSkipped=146 mediaFailed=0
```

If Wikimedia `403/429` persists, use another license-clear source that allows server-to-server fetch, then update `place_catalog_v11.csv` and regenerate `place_seed_v11_media_completion.csv`.

## Important Warning

This task did not fully complete 146 cover images in PostgreSQL because most Places still do not have a sufficiently verified, fetchable, license-clear image source. The safe completed state is:

- metadata prepared,
- existing media preserved,
- Wikimedia 429/403 path avoided for imports,
- 2 additional licensed covers uploaded through GoMate byte upload,
- invalid/unclear images not imported,
- DB not corrupted,
- Trip Core can proceed with fallback media behavior,
- future media retry is documented and idempotent.
