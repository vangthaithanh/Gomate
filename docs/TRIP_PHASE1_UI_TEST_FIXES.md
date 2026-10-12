# Trip Phase 1 UI Test Fixes

Updated: 2026-10-10

## Context

These fixes close two user-facing issues found while testing Phase 1 Trip flows:

- The member picker showed no suggested friends/users when opened from Trip create or existing Trip member management.
- Stops added from Map appeared temporarily, but could disappear after switching between Map and Trip detail and starting another add-place flow.

## Business Rules Reconfirmed

- There is no Personal/Group selector in Trip creation.
- A new Trip is `PERSONAL` by default.
- Adding at least one other member makes the Trip `GROUP`.
- Roles remain only `LEADER` and `MEMBER`; no deputy/co-leader UI should be reintroduced.
- Existing Trip add-member is an immediate leader action in this phase:
  - validate selected active users;
  - ignore duplicates and already-active members;
  - convert `PERSONAL` to `GROUP` when needed;
  - create or reuse exactly one linked group conversation;
  - sync `conversation_members`;
  - leave real notification delivery for the Notification module.
- Trip stops are persisted `trip_stops` rows. Flutter must not treat Map-added stops as long-lived local-only state.

## Implemented Fixes

### Member picker suggestions

Flutter member pickers now preload contacts with an empty search query.

Backend `/api/v1/users/search?q=` now returns contact suggestions instead of an empty page. Results prioritize:

1. mutual follows,
2. users the viewer follows,
3. users following the viewer,
4. other active users.

This keeps the picker usable even before the user types.

### Existing Trip add-member

New API:

```text
POST /api/v1/trips/{id}/members
```

Request:

```json
{
  "selectedMemberIds": ["<user-uuid>"]
}
```

Response is the updated Trip detail.

Only the active Trip leader can add members.

### Map stop persistence

Map add/delete/reorder now calls real Trip stop APIs:

```text
POST   /api/v1/trips/{id}/stops
DELETE /api/v1/trips/{id}/stops/{stopId}
PATCH  /api/v1/trips/{id}/stops/reorder
```

Flutter distinguishes:

- `TripPlaceUi.id` = `trip_stops.id`
- `TripPlaceUi.placeId` = `places.id`

Adjacent duplicate validation uses `placeId`, not the stop occurrence id.

When selecting a Trip from the Map picker, Flutter attempts to fetch Trip detail first so it does not operate on summary placeholder stops.

## Remaining Note

Editing an existing stop time is still UI-local in the current Map screen because there is no dedicated backend PATCH endpoint for a single stop yet. The add/delete/reorder bug is fixed through persisted APIs; stop-time persistence should be handled in a later Trip Stop update task.
