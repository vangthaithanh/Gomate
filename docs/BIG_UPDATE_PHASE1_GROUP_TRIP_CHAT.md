# BIG UPDATE PHASE 1 - Group Trip Chat Foundation

> Create-time direct membership below is historical and SUPERSEDED by `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md` (2026-10-15). Selection now sends PENDING invitations; membership and linked GROUP chat occur only after acceptance. V7 schema, linked chat uniqueness, text messaging and rename invariants remain valid.

Updated: 2026-10-10

## Scope completed

Phase 1 adds the backend foundation for group trips and their linked group conversation.

Implemented:
- A trip is created from `selectedMemberIds`; backend derives `PERSONAL` or `GROUP` from persisted membership.
- Creating a derived group trip also creates exactly one linked group conversation in the same transaction.
- The trip creator becomes `LEADER` in both `trip_members` and `conversation_members`.
- Selected members become `MEMBER` in both `trip_members` and `conversation_members`.
- Group conversation membership mirrors active trip membership at creation time.
- Group messages reuse the existing MongoDB message body flow.
- PostgreSQL keeps conversation metadata and membership only.
- Trip title is the display-name source of truth for linked group chat.
- Renaming the group chat updates the trip title.

Not implemented in this phase:
- invite/request approval lifecycle;
- adding/removing group members from UI;
- WebSocket/realtime delivery;
- read receipt expansion;
- check-in or realtime location;
- independent/orphan group conversations.

## Database

Flyway migration:

```text
V7__group_trip_chat_foundation.java
```

This migration is Java-based because the test database is H2 while local/dev is PostgreSQL. H2 generated unstable check-constraint names for the old direct-message schema, so the migration resolves and drops only the known old direct-only checks before adding the group-compatible contract.

Schema alignment:
- `conversations.type` now supports `DIRECT` and `GROUP`.
- `conversations.linked_trip_id` links a group conversation to `trips.id`.
- Direct-only columns are nullable for group conversations:
  - `requester_id`
  - `recipient_id`
  - `user_low_id`
  - `user_high_id`
- `GROUP` conversations must have:
  - non-null `linked_trip_id`;
  - null direct-only columns;
  - `status='ACCEPTED'`.
- `DIRECT` conversations must keep the old direct shape and have null `linked_trip_id`.
- `conversation_members.role` now allows only:
  - `LEADER`
  - `MEMBER`

No new table was created in this phase.

## API contract

Trip:

```text
POST /api/v1/trips
GET  /api/v1/trips
GET  /api/v1/trips/{id}
PATCH /api/v1/trips/{id}
```

`POST /trips` accepts optional `selectedMemberIds`:

```json
{
  "title": "Da Lat weekend",
  "selectedMemberIds": ["<user-uuid>"]
}
```

`tripType` may still be accepted for backward compatibility, but backend ignores/recomputes it from real membership. `GET /trips` and `GET /trips/{id}` return `linkedConversationId` when the trip is a group trip.

Conversation:

```text
GET   /api/v1/conversations
GET   /api/v1/conversations/{id}
GET   /api/v1/conversations/{id}/messages
POST  /api/v1/conversations/{id}/messages
PATCH /api/v1/conversations/{id}/name
```

Group conversation summaries include:
- `linkedTripId`
- `displayName`
- `members`
- `memberCount`

Permission rules:
- Only an active trip member can view/send messages in the linked group conversation.
- Only the active trip `LEADER` can rename the linked group conversation/trip.
- Non-members receive controlled forbidden/not-found style errors through the existing API error path.

## Flutter integration

The real message repository now parses backend `GROUP` conversations and exposes them to the existing message UI model:
- backend `linkedTripId` maps to `linkedItineraryId`;
- backend group members map to message participants;
- backend `LEADER` maps to the existing leader UI role;
- `renameGroup` calls `PATCH /api/v1/conversations/{id}/name`.

Phase 1.1 UI closure is tracked in `BIG_UPDATE_PHASE1_UI_CLOSURE.md`.

Current UI status:
- Trip tab uses real Trip API for list/detail/create/update/delete.
- Create Trip UI has no manual personal/group picker.
- The default `Lịch trình` title must be renamed before creation.
- Flutter sends `selectedMemberIds`.
- No selected members creates `PERSONAL`.
- One or more valid selected members creates `GROUP`.
- Flutter does not create a group chat manually.
- Trip -> Chat uses real `linkedConversationId`.
- Chat -> Trip uses real `linkedTripId`.
- Add/remove member after an existing Trip remains outside this phase.

## Validation

Backend targeted test:

```text
mvn --batch-mode clean -Dtest=GroupTripChatApiTest test
```

Result:
- 2 tests run;
- 0 failures;
- 0 errors.

Covered:
- create group trip;
- linked conversation creation;
- leader membership;
- list/detail group conversation;
- send group message;
- outsider permission denial;
- trip rename updates group display name;
- group rename updates trip title.

Docker build:

```text
docker compose build api
```

Result:
- API image built successfully as `gomate-auth-api:latest`.

Flutter:

```text
flutter test
```

Result:
- existing Flutter unit tests passed.

```text
flutter analyze
```

Result:
- command completed with no compile errors, but exits non-zero because the project currently has analyzer warnings/info from existing UI files.

## Notes

The older `MESSAGE_BACKEND_BUSINESS_SPEC.md` still contains some group-role wording from before the business lock. The active rule is the current contract: group trip/chat roles are only `LEADER` and `MEMBER`.
