# BIG_UPDATE_PHASE3_PINNED_TRIP_MEMBER_LOCATION.md

Updated: 2026-10-10.

## Scope completed

Phase 3 adds the foundation for:

- per-user pinned Trip state;
- publishing the current user's Trip location;
- reading Trip member location snapshots for Map member markers.

This phase does not implement realtime tracking, WebSocket streaming, background polling cadence, check-in, or Trip history/archive retention jobs.

## Business rules locked for this phase

- Pinning is per user. Each user can pin at most one Trip.
- Pinning does not change `trips.status`; it is not the same as an ACTIVE Trip.
- A user can pin only a Trip where they are an active member.
- Unpinning does not require OS location permission.
- Pinning in Flutter requires location service ON and OS permission `Always`.
- `When in use` permission is not enough for pinned Trip flow because the UX implies background/member location readiness.
- Member markers must come only from persisted location data. No fake offset markers are allowed.
- Current user location is runtime state and is not stored in PostgreSQL.
- Runtime member location is stored in MongoDB, with PostgreSQL still owning Trip membership and permissions.

## PostgreSQL

Migration:

```text
backend/src/main/resources/db/migration/V8__trip_pin_state.sql
```

Table:

```text
trip_pins
---------
user_id   UUID PK, FK users(id), ON DELETE CASCADE
trip_id   UUID NOT NULL, FK trips(id), ON DELETE CASCADE
pinned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
```

Indexes:

```text
ix_trip_pins_trip(trip_id)
```

This table is intentionally separate from `trips.status` and `trip_members`.

## MongoDB

Collection:

```text
trip_current_locations
```

Document shape:

```text
_id
tripId
userId
latitude
longitude
accuracyM
capturedAt
updatedAt
```

Indexes:

```text
unique (tripId, userId)
(tripId, updatedAt DESC)
(updatedAt DESC)
```

No TTL index is created in this phase. The response marks records as `LAST_KNOWN`; the app must not present this as realtime/live tracking.

## API contract

Base path: `/api/v1`.

```text
GET    /trips/pinned
POST   /trips/{id}/pin
DELETE /trips/{id}/pin
PUT    /trips/{id}/location
GET    /trips/{id}/locations
```

`GET /trips/pinned` returns `200` with:

```json
{
  "trip": null
}
```

when no Trip is pinned. This avoids an empty-body parsing edge in the current Flutter `AuthService`.

`PUT /trips/{id}/location` stores the JWT actor only. The client cannot publish another user's location.

`GET /trips/{id}/locations` returns active Trip members only when:

- the requester is an active member;
- the target member is active;
- the target member has `location_sharing_enabled=true`;
- MongoDB has a valid location document for that member.

Each item includes `locationState=LAST_KNOWN`.

## Flutter flow

Trip list/detail pin action:

```text
pin tapped
-> check location service
-> require OS permission Always
-> backend POST /trips/{id}/pin
-> best-effort publish current GPS to /trips/{id}/location
-> update GoMateMapUiSession pinned trip
```

Map member marker flow:

```text
pinned/group trip
-> GET /trips/{id}/locations
-> render only returned members
-> label as last-known/stale, not live
```

Displayed Trip route flow:

```text
editing/adding/pinned Trip shown on Map
-> current GPS runtime coordinate
-> ordered stops for the selected Trip day
-> POST /api/v1/routes/compute with originLatitude/originLongitude + placeIds[]
-> Spring resolves each placeId from PostgreSQL places
-> Mapbox Directions returns geometry/distance/duration
-> Flutter draws the route line on the active Map
```

Route order follows the Trip stop order. Reordering stops in Trip detail updates the active Map route from current location to the new first stop, then the remaining stops.

Flutter must not hard-code or guess Place coordinates for Trip routing. Current GPS stays runtime-only and is not persisted to PostgreSQL.

If there is no active displayed Trip, no stops for the selected day, no GPS permission/location, or the Route API fails, the Map clears the active Trip route instead of silently falling back to demo coordinates.

Backend `/api/v1/routes/compute` now supports two modes:

- `placeIds[]` only: route through the listed GoMate Places.
- `originLatitude` + `originLongitude` + `placeIds[]`: route from runtime current location through the listed GoMate Places.

Implementation note:

- Mapbox style/marker refresh can clear annotation layers while Flutter state still has the old route object.
- Therefore, whenever the Map re-renders explore markers/style while a Trip is displayed, Flutter must force-redraw the Trip route instead of relying only on the cached route signature.
- Trip list/pin state may contain only summary stops without real `placeId`. Before calculating the Map route, Flutter must load `GET /api/v1/trips/{id}` and use detail stops with real `placeId`.
- The first route calculation for a new Trip/day/order should fit the camera to the route so users can see the line even when current GPS is far from the Trip destination.
- Backend Trip detail serializes `stops[].placeId` as a numeric `Long`. Flutter must preserve this as string text for route requests; treating it as string-only drops the value and makes Map think the Trip day has no routable stops.
- The active route line is rendered with a Mapbox `GeoJsonSource` + `LineLayer`, with polyline annotations kept as a compatibility fallback.

## Deferred

- realtime/WebSocket location streaming;
- background publish cadence;
- disable location sharing endpoint/UI;
- TTL/retention/archive policy;
- check-in integration;
- notification/push hooks for member location changes;
- full device smoke test for Android/iOS permission dialogs.
