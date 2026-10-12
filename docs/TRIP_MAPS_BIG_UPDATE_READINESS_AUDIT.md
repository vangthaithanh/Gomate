# TRIP_MAPS_BIG_UPDATE_READINESS_AUDIT.md

Updated: 2026-10-10

## Scope

Readiness audit before the Trip/Maps/Group Messaging Big Update. This file does not implement the Big Update and must not be treated as a migration plan by itself.

Canonical input:

- `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md`
- `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md`
- current backend and Flutter code.

## Confirmed Business Rules

- Group roles are only `LEADER` and `MEMBER`.
- `DEPUTY`, `CO_LEADER`, `VICE_LEADER` and phó nhóm concepts are deprecated.
- Trip Stop is a Place occurrence, not the Place entity itself.
- `A -> B -> A` is valid; adjacent duplicate Place stops such as `A -> A` are invalid.
- Stop time belongs to the Trip Stop occurrence.
- If start is missing, end-only data must be ignored/cleared.
- Start without end is not a complete scheduled interval.
- Route optimization must include unscheduled stops and primarily optimize distance/km until a later approved algorithm says otherwise.
- Pinned Trip requires Always/background location capability.
- Member location display depends on real location data; last-known must not be labeled live/current.
- Group Chat is linked to Group Trip and should not be created as an orphan.
- Direct Message V1 must remain intact.

## Current Backend Trip State

Migration:

```text
backend/src/main/resources/db/migration/V3__trip_core.sql
```

Tables:

```text
trips
trip_members
trip_stops
trip_reminders
```

Implemented role schema:

```text
trip_members.role CHECK ('LEADER','MEMBER')
```

Implemented Trip API:

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

Current V3 creates PERSONAL trips only. Group invite/member expansion, Trip Chat linkage, pinned trip, member location and check-in are not implemented.

## Trip Stop Phase 2 Status

Current backend has:

```text
planned_start_at
planned_duration_min
```

It does not have `planned_end_at`.

Phase 2 now enforces the adjacent duplicate Place invariant at the service layer before writes:

```text
stops[i].placeId != stops[i + 1].placeId
```

This is checked after:

```text
add/insert
edit/replace Place
delete
reorder
optimize
```

The same Place can still repeat non-adjacent, for example `A -> B -> A`, because `trip_stops.id` is the occurrence identity and `trip_stops.place_id` is only the Place reference.

Time remains stored as `planned_start_at + planned_duration_min`; API responses derive `plannedEndAt` and expose `hasCompleteInterval`.

Optimize currently uses a minimal distance-first implementation over Place coordinates and preserves stop IDs/time. It is not the final traffic/time-window optimizer policy.

Do not auto-delete one of the repeated stops in `A -> B -> A` when deleting `B` unless the user approves a specific business rule.

## Deputy/Co-Leader Inventory

PostgreSQL Trip V3 already uses only `LEADER` and `MEMBER`.

Active/deferred deputy references remain in Flutter Messaging UI/mock code:

```text
lib/features/messages/models/message_models.dart
lib/features/messages/data/message_repository.dart
lib/features/messages/widgets/message_widgets.dart
lib/features/messages/screens/message_detail_screen.dart
lib/features/messages/screens/group_management_screen.dart
lib/features/messages/screens/message_support_screens.dart
docs/MESSAGE_BACKEND_BUSINESS_SPEC.md
```

Examples found:

```text
MessageGroupRole.deputy
promoteGroupMembers -> deputy
revokeGroupDeputy
group_deputy_demo
trip_da_lat_deputy
UI labels/descriptions mentioning phó nhóm
```

Do not delete these blindly in the pre-update step because Group Messaging backend is not yet opened. In the Big Update, remove or replace them after the backend/UI contract is migrated to LEADER/MEMBER.

## Messaging State

Real Direct Message V1:

- metadata in PostgreSQL: `conversations`, `conversation_members`;
- message body/history in MongoDB;
- direct conversation only;
- pending/accepted direct flow implemented.

Group chat state:

- Flutter has group UI/mock flows;
- backend migration currently limits `conversations.type` to `DIRECT`;
- no real Group Chat/Trip Chat backend yet.

Big Update must extend messaging without rewriting Direct Message V1.

## Maps/Location State

Current map flow uses real Place/Route foundation for normal routing.

Observed current code:

- `lib/features/map/services/location_service.dart` asks device location permission through Geolocator.
- `lib/features/map/screens/map_screen.dart` uses runtime GPS for current-location directions.
- Current map/trip demo entry still has references such as `trip-demo-01` and `demoTripStopIds`.
- No real pinned trip backend, Always/background permission gate, member location collection, last-known TTL or live-vs-last-known policy is implemented yet.

Big Update must not label last-known location as live/current.

## UI Merge Risk

Latest `origin/xuanthu` updates Trip/Maps/Messages heavily, but it overlaps local real integrations. See:

```text
PRE_BIG_UPDATE_XUANTHU_SYNC_AUDIT.md
```

Any UI sync should preserve current real repositories and avoid reverting to demo data.

## TBD / Do Not Invent

Still not enough information to implement without explicit approval:

- exact Leader/Member CRUD permissions;
- leader leave/transfer/dissolve policy;
- member limit;
- group invitation exact state machine;
- optimize algorithm;
- fixed route start/end policy;
- time-vs-distance conflict policy;
- member-location refresh interval;
- last-known location TTL;
- GPS privacy/consent beyond OS permission;
- exact GPA semantics;
- transaction/retry/compensation if Group Trip succeeds but Group Chat init fails;
- exact Trip status expansion;
- Personal -> Group conversion policy.

## Recommended Next Big Update Entry Criteria

- Resolve xuanthu UI merge in a controlled branch/stash workflow.
- Remove deputy/co-leader from Group UI and mock data only after the new backend contract is ready.
- Adjacent duplicate Place validation for Trip stop mutations is complete in Phase 2.
- Group Trip -> Group Chat linkage contract and migration is complete for create-time selected members in Phase 1.
- Add pinned Trip permission state and member location policy in backend before showing production UI.
