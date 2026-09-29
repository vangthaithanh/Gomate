# GoMate Real Place Routing Integration

Updated: 2026-09-19

## Scope

Backend routing now resolves GoMate `places.id` from PostgreSQL instead of demo coordinates.
It also accepts the existing Flutter current-location runtime coordinates as the default route origin.

No database migration, table change, Auth change, Cloudinary change, Place schema change, or Trip domain change was made in this step.

## Contract

Previous directions request:

- `origin` as raw longitude/latitude
- `destinationPlaceId`
- backend could fall back to demo place coordinates

Current default directions request:

- `originLatitude`
- `originLongitude`
- `destinationPlaceId`

`originLatitude` and `originLongitude` come from the device GPS runtime state in Flutter. They are not persisted to PostgreSQL or MongoDB in this step.

Alternative directions request when the user changes the start point to another GoMate place:

- `originPlaceId`
- `destinationPlaceId`

Place IDs are GoMate business Place IDs from PostgreSQL `places.id`. Mapbox feature IDs and hard-coded `place-xxx` demo IDs are not used for production routing.

## Backend Flow

```text
originLatitude + originLongitude + destinationPlaceId
-> runtime origin coordinate + PlaceCoordinateResolver for destination
-> PostgreSQL places latitude/longitude for destination
-> MapboxRoutingProvider
-> geometry + distance + duration
```

For the alternate Place-to-Place flow, `originPlaceId + destinationPlaceId` resolves both coordinates through `PlaceCoordinateResolver`.

If a place does not exist or is not active, the API returns `PLACE_NOT_FOUND`.

If a place ID has the wrong format, the API returns `INVALID_INPUT`.

If neither `originPlaceId` nor both runtime origin coordinates are provided, the API returns `INVALID_INPUT`.

If Mapbox Directions fails, the API returns `ROUTE_PROVIDER_UNAVAILABLE`.

## Flutter Flow

Map directions defaults to the already existing current-location service:

```text
selected destination place
-> GoMateLocationService.getCurrentLocation()
-> originLatitude + originLongitude
-> POST /api/v1/routes/directions
-> render returned polyline
```

The "Thay đổi điểm bắt đầu" action remains available for Place-to-Place routing: user taps another marker as origin, then Flutter sends `originPlaceId + destinationPlaceId`.

## Verification

Real API route tested:

- Runtime origin: `lat=11.9500`, `lng=108.4500`
- Destination: Thiền Viện Trúc Lâm, `places.id=7`
- Distance: `7859.811` meters
- Duration: `1167.628` seconds
- Geometry: `363` points
- Ordered place IDs: `current-location`, `7`

Place-to-Place API route tested:

- Origin: Hồ Xuân Hương, `places.id=3`
- Destination: Thiền Viện Trúc Lâm, `places.id=7`
- Distance: `6352.558` meters
- Duration: `886.311` seconds
- Geometry: `301` points

Controlled error checks:

- `originPlaceId=999999` -> `404 PLACE_NOT_FOUND`
- `destinationPlaceId=999999` -> `404 PLACE_NOT_FOUND`
- `destinationPlaceId=not-a-place-id` -> `400 INVALID_INPUT`
- missing origin -> `400 INVALID_INPUT`

Flyway history remained V1 + V2 only.

## Remaining Notes

`demo_places.dart`, `DemoPlaceDataSource`, and `DemoGoMateMapGateway` still exist for old/demo flows, but the active map screen uses the Spring gateway and PostgreSQL places.

Trip route is still out of scope and can be replaced later when the Trip/TripStop API exists.
