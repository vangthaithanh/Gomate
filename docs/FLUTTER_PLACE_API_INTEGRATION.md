# Flutter Place API Integration

Updated: 2026-09-19

## Scope

This step replaces the active Flutter Map data source from `demo_places.dart` to the real Spring Place API.

No database migration, Auth change, backend routing change, or DemoPlaceCatalog change was made in this step.

## Active Flow

```text
GoMateMapScreen
  -> GoMateMapState
  -> SpringGoMateMapGateway
  -> SpringPostgresPlaceDataSource
  -> PlaceRepository
  -> PlaceApi
  -> GET /api/v1/places
  -> GET /api/v1/places/search?q=
  -> GET /api/v1/places/{id}
```

## API Usage

- Initial Map markers use `GET /api/v1/places`.
- Search uses `GET /api/v1/places/search?q=`.
- Marker tap and search-result selection use `GET /api/v1/places/{id}` for detail data.
- Flutter reuses `ApiConfig.candidateBaseUrls`; no new hard-coded backend URL was added.

## Media

- List and bottom-sheet thumbnails use `thumbnailUrl`.
- Detail screen uses `media[].url`, falling back to `thumbnailUrl` if needed.
- Images are loaded with `Image.network`.
- Loading, error, and no-media states fall back to existing local UI placeholders.
- Flutter does not call Cloudinary Admin APIs and does not download media locally.

## Demo Data Status

`demo_places.dart`, `DemoPlaceDataSource`, and `DemoGoMateMapGateway` are still present for old demo flows.

The active `GoMateMapScreen` now instantiates `SpringGoMateMapGateway`, so explore markers, search, and place detail no longer depend on `demoPlaces`.

## Verified Backend Data

With Docker running:

- `GET /api/v1/places` returned 5 places.
- `GET /api/v1/places/search?q=Hồ` returned 2 places:
  - Hồ Tuyền Lâm
  - Hồ Xuân Hương
- `GET /api/v1/places/{id}` returned detail data with Cloudinary media URL.

## Known Remaining Work

- Backend routing has since moved off `DemoPlaceCatalog` and now resolves `places.id` through PostgreSQL for real Place-to-Place directions.
- `MapPlaceUi` still exists in more than one map file. This was not refactored to keep this step focused.
- `flutter analyze` still reports pre-existing warnings/info in Auth, Trip, and Map code. No compile error was introduced by the Place API integration.
