# TRIP_CORE_V3.md

## Scope

This step adds the first PostgreSQL-backed Trip Core for GoMate.

Included:
- `trips`
- `trip_members`
- `trip_stops`
- `trip_reminders`
- PERSONAL Trip API
- ordered Place stops that reference `places.id`

Not included:
- `trip_invites`
- `trip_checkins`
- realtime location
- AI tables
- itinerary / itinerary_items
- Flutter Trip API integration
- route calculation inside Trip

## Migration

Migration file:

```text
backend/src/main/resources/db/migration/V3__trip_core.sql
```

V1 and V2 are unchanged.

## API

Base path:

```text
/api/v1/trips
```

Endpoints:

```text
POST   /api/v1/trips
GET    /api/v1/trips
GET    /api/v1/trips/{id}
PATCH  /api/v1/trips/{id}
DELETE /api/v1/trips/{id}

POST   /api/v1/trips/{id}/stops
DELETE /api/v1/trips/{id}/stops/{stopId}
PATCH  /api/v1/trips/{id}/stops/reorder
```

Trip detail returns stops joined with Place:

```text
placeId
name
category
categoryName
latitude
longitude
thumbnailUrl
```

## Permission

- Create Trip creates a PERSONAL Trip and an ACTIVE LEADER membership in one transaction.
- List/detail only return trips where the current user has ACTIVE membership.
- Update/delete Trip and stop mutations require ACTIVE LEADER membership.
- Unknown or inactive `placeId` returns controlled `PLACE_NOT_FOUND`.
- Trip does not calculate route and does not duplicate Mapbox logic.
- V3 keeps the active leader rule in service transactions and leader lookup indexes.
  A PostgreSQL partial unique index can be added in a later GROUP/leader-transfer migration if the team drops H2-compatible migration tests.

## Reorder Contract

`PATCH /api/v1/trips/{id}/stops/reorder` expects all current stops for the trip.
This keeps `(trip_id, day_no, order_no)` unique and avoids accidental partial-order corruption.

## Next Step

The next backend step can be Flutter Trip API integration or GROUP Trip invite flow.
Trip check-in/location should remain a separate migration because it touches runtime location rules.
