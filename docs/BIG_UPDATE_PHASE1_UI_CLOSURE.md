# BIG UPDATE PHASE 1.1 - Group Trip UI Closure

> Historical create-time direct-membership behavior is SUPERSEDED by the 2026-10-15 invitation update. See `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md`: all additions invite first, and chat/membership begin after acceptance. Existing list/detail/stop/name/chat UI hooks remain active.

Updated: 2026-10-10

## Scope completed

This phase connects the existing xuanthu Trip and Message UI to the real V7 Group Trip Chat backend.

Implemented:
- Trip tab loads trips from `GET /api/v1/trips`.
- Create Trip screen calls `POST /api/v1/trips`.
- Create Trip screen has no `Personal/Group` type picker.
- The user must rename the default `Lịch trình` title before creating a trip.
- Create Trip sends real `selectedMemberIds`.
- Backend creates `PERSONAL` when no member is selected during creation.
- Backend creates `GROUP` when at least one valid member is selected during creation.
- Backend V7 creates the linked `GROUP` conversation in the same transaction.
- Trip detail fetches real trip detail from `GET /api/v1/trips/{id}`.
- Trip rename calls `PATCH /api/v1/trips/{id}`.
- Date edit calls `PATCH /api/v1/trips/{id}`.
- Trip delete calls `DELETE /api/v1/trips/{id}`.
- Trip -> Chat opens by the real `linkedConversationId`.
- MessageScreen uses the real conversation repository for both `DIRECT` and `GROUP`.
- Group text send/list uses the existing real conversation APIs and MongoDB message body.
- Chat -> Trip opens by real `linkedTripId` and fetches real Trip detail.
- Rename Trip refreshes MessageRepository so the group chat title follows the trip title.
- Rename Group Chat still uses `PATCH /api/v1/conversations/{id}/name`, which updates the linked trip title through backend Phase 1.

No migration was added.

## UI data sources

Trip production path:

```text
TripScreen
-> RealTripRepository
-> AuthService
-> /api/v1/trips
```

Message production path:

```text
MessageScreen / MessageChatScreen
-> RealDirectMessageRepository
-> AuthService
-> /api/v1/conversations
-> MongoDB messages through Spring
```

Demo repositories remain in the project for mock/dev screens, but the main Trip tab no longer seeds production trip rows from demo data.

## Group create flow

```text
CreateTripScreen
-> rename default trip title
-> optionally add members
-> POST /api/v1/trips { selectedMemberIds: [...] }
-> backend derives PERSONAL/GROUP from persisted membership
-> backend creates trip + linked group conversation
-> TripScreen refreshes MessageRepository
-> Trip detail can open linked chat
```

Flutter never calls a separate "create group chat" API.

Important business rules:
- There is no manual UI choice between personal and group trip.
- A new trip starts from the personal creation flow.
- Adding members during creation makes it a group trip after the trip is successfully created.
- Notifications for selected members must be sent only after successful trip creation, not while selecting members.

## Error behavior

If Trip API fails:
- Trip list shows error + retry.
- Create screen shows an error snackbar and stays on the create screen.
- Detail open/rename/delete shows an error snackbar.
- No local fake Trip is added on create failure.
- No silent fallback to demo trip/group chat data.

## Deferred intentionally

The following remain out of scope for Phase 1.1:
- invite lifecycle;
- adding/removing group members;
- member approval;
- leader transfer;
- leave/dissolve policy;
- trip stops/time/reorder/optimize expansion;
- pinned Trip persistence;
- member GPS/realtime location;
- WebSocket/realtime messaging;
- media messages.

The "Thêm thành viên" UI is now real for create-time membership selection. Add/remove member after an existing Trip, invite acceptance, and leader approval remain later scoped tasks.

## Validation

Flutter:

```text
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
```

Result:
- Flutter unit tests passed.
- Analyzer completed without compile errors. Existing project warnings/info remain.

Backend:
- No backend code or migration change was required in Phase 1.1.
- Backend V7 remains the required foundation.

## UI smoke status

Manual device smoke was not executed by Codex in this run. Expected user-test flow after running the app:

```text
Login
-> Trip tab
-> Create Trip
-> set name/date
-> optionally add members
-> create
-> Trip appears in real list
-> open Trip detail
-> tap Tin nhắn
-> send text
-> return MessageScreen
-> group row appears with latest text
-> open group detail
-> Xem lịch trình
-> opens the real linked Trip
-> rename Trip and verify MessageScreen title refreshes
-> rename group chat and verify Trip title refreshes after reopening/refresh
```

## Verdict

Phase 1.1 closes the main creator-only UI test path for:

```text
CREATE TRIP
-> OPEN TRIP
-> OPEN LINKED CHAT
-> SEND TEXT
-> RETURN MESSAGE LIST
-> OPEN TRIP FROM CHAT
-> RENAME/SYNC
```

Phase 1 should still be considered creator-only until invite/member lifecycle is implemented.
