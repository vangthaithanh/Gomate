# GoMate Place Foundation V2

Updated: 2026-09-19

## Scope

V2 only creates the PostgreSQL foundation for Place data and read-only backend APIs.

Created tables:

- `place_categories`
- `places`
- `place_media`

Out of scope for this step:

- `saved_places`
- reviews
- tags
- posts/social data
- trip data
- generic media/files/attachments table
- Cloudinary import/upload implementation
- replacing Flutter `demo_places.dart`
- replacing backend `DemoPlaceCatalog`

## Contract Notes

`DATABASE_CONTRACT.md` is stricter than the task's minimum field list, so V2 keeps the contract fields for `places`:

- `district`
- `opening_hours`
- `price_level`
- rating/count fields
- source fields
- `updated_at`

The task also requires `place_media.created_at`, so V2 includes it.

## APIs

Read-only endpoints:

- `GET /api/v1/places`
- `GET /api/v1/places/search?q=...`
- `GET /api/v1/places/{id}`

List/search responses are intentionally marker-ready for the later Map integration:

- `placeId`
- `name`
- `category`
- `categoryName`
- `latitude`
- `longitude`
- `province`
- `district`
- `address`
- `thumbnailUrl`

Detail responses include place fields plus ordered `media` from `place_media`.

## Migration Behavior

Existing local DB:

- V1 remains the Auth baseline.
- Flyway applies `V2__place_foundation.sql` after V1.
- No Auth table or Auth logic is changed.

Clean DB:

- Flyway runs V1 first.
- Flyway runs V2 second.
- The clean schema should contain only `flyway_schema_history`, 4 Auth tables, and the 3 Place Foundation tables.

## Verification Checklist

- `docker compose build api`
- current DB Flyway history contains V1 + V2
- current DB has exactly the 3 new Place tables
- clean DB can run V1 -> V2
- `GET /api/v1/places` returns `[]` when no places exist
- `GET /api/v1/places/search?q=...` returns `[]` when no places match
- `GET /api/v1/places/{missingId}` returns 404
- Auth regression tests still pass
