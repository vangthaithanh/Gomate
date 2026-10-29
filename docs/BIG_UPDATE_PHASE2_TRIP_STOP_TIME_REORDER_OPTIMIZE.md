# BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md

Updated: 2026-10-10

## Scope

Phase 2 closes the core Trip Stop flow before pinned trip/GPS/member location work.

Implemented scope:
- Trip Stop is a Place occurrence, not the Place itself.
- The same Place may appear multiple times in one Trip when not adjacent, for example `A -> B -> A`.
- Adjacent duplicate Places such as `A -> A` are rejected.
- Stop mutations are validated for add/insert, edit/replace Place, delete, reorder, and optimize apply.
- Time belongs to `tripStopId`, not `placeId`.
- Start/end input is normalized onto current V3 storage: `planned_start_at + planned_duration_min`.
- Optimize includes scheduled and unscheduled stops, preserves stop IDs and stop-specific time, and validates the result before persisting.

Out of scope:
- pinned Trip;
- Always/background location permission;
- member GPS/live/last-known location;
- turn-by-turn navigation;
- traffic/time-window optimization policy;
- new Trip schema migration.

## Schema Decision

No new Flyway migration was required.

Current V3 already has the needed data model:
- `trip_stops.id` is the stable occurrence identity (`UUID PK`);
- `trip_stops.place_id` is an FK to `places.id`;
- repeated Places are allowed because there is no unique `(trip_id, place_id)`;
- order is deterministic through `(trip_id, day_no, order_no)`;
- time is occurrence-scoped through `planned_start_at` and `planned_duration_min`.

There is no `planned_end_at` column. API accepts `plannedEndAt` where useful, derives duration, and returns derived `plannedEndAt` in responses.

## Backend Invariants

Shared validator:

```text
TripStopSequenceValidator.validateNoAdjacentDuplicate(...)
```

The validator checks each `dayNo` independently because the current project model orders itinerary stops by day. This is a project-fit implementation detail, not a new business rule about cross-day travel.

Validation applies before write for:
- `POST /api/v1/trips/{id}/stops`;
- `PATCH /api/v1/trips/{id}/stops/{stopId}`;
- `DELETE /api/v1/trips/{id}/stops/{stopId}`;
- `PATCH /api/v1/trips/{id}/stops/reorder`;
- `POST /api/v1/trips/{id}/stops/optimize`.

Invalid mutations are atomic: the old stop order/data remains persisted.

## Time Semantics

Backend API semantics:
- `plannedStartAt != null` and `plannedEndAt != null`: complete interval; store `planned_start_at` and computed `planned_duration_min`.
- `plannedStartAt == null` and `plannedEndAt != null`: end-only has no meaning; clear time.
- `plannedStartAt != null` and `plannedEndAt == null`: keep start-only if supplied, but `hasCompleteInterval=false`.
- both null: unscheduled stop.

`plannedEndAt` in response is derived from `plannedStartAt + plannedDurationMin`.

Flutter must not render start-only as a full time range.

## Optimization

Current implementation:
- no existing production optimizer was found;
- backend adds a minimal nearest-neighbor Haversine distance optimizer over existing Place coordinates;
- the first stop of the selected day is kept as the anchor;
- all stops participate, including unscheduled stops;
- stop IDs, Place IDs, time, note, radius, and status are preserved;
- result is rejected if it would create adjacent duplicate Places.

This is marked `CURRENT_IMPLEMENTATION`, not final canonical optimizer policy. Later traffic, fixed start/end, time-window, or Mapbox matrix policy requires a separate approved task.

## Flutter Integration

Flutter Trip/Map UI now calls real backend stop mutation APIs for:
- adding stops;
- editing stop time;
- deleting stops;
- reordering stops;
- optimizing stops.

The UI keeps `tripStopId` on every stop item and refreshes from backend after successful mutations. Backend remains the final authority.

## Regression Notes

Auth, Place, Map route rendering, Moment, profile/social, and Group Trip Chat Phase 1 are intentionally left structurally unchanged.

Phase 3 remains:
- pinned Trip state;
- Always/background permission;
- member GPS sharing;
- last-known vs live location behavior.
