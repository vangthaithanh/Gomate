# BIG UPDATE PHASE 1.2 - Create Trip Membership Closure

Updated: 2026-10-10

## Business Lock

- Create Trip UI has no personal/group selector.
- New Trip defaults to `PERSONAL` when `selectedMemberIds` is omitted or empty.
- New Trip becomes `GROUP` only when backend persists at least one selected member besides the creator.
- Flutter sends `selectedMemberIds`; `tripType` from clients is ignored/recomputed by backend.
- The default title `Lịch trình` is invalid in UI and backend.
- Selecting members in the picker is local draft state only. It must not notify anyone before Trip creation succeeds.

## Implemented Flow

```text
POST /api/v1/trips
-> validate title/date
-> validate selectedMemberIds are active users
-> remove duplicates and creator self-reference
-> insert trips
-> insert creator as LEADER in trip_members
-> insert selected users as MEMBER in trip_members
-> derive PERSONAL/GROUP from effective membership
-> if GROUP, create linked GROUP conversation
-> insert conversation_members for creator + selected users
-> commit
-> after-commit notification hook
```

## API Contract

Create request:

```json
{
  "title": "Đà Lạt cuối năm",
  "selectedMemberIds": ["<user-uuid>"],
  "startDate": "2026-12-01",
  "endDate": "2026-12-03",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

Backward compatibility:
- `tripType` may be present in the request.
- Backend ignores/recomputes it.
- Response returns the actual derived `tripType`.

Response includes:
- `tripType`
- `memberCount`
- `linkedConversationId` for GROUP, null for PERSONAL
- `members[]` with `userId`, display name, avatar URL, role, status

## Database Invariants

PERSONAL:
- `trips.trip_type = PERSONAL`
- `trip_members = {creator}`
- no linked GROUP conversation

GROUP:
- `trips.trip_type = GROUP`
- `trip_members = {creator + selected members}`
- exactly one linked GROUP conversation
- `conversation_members` mirrors the Trip members
- roles are only `LEADER` and `MEMBER`

## Notification State

`NOTIFICATION_HOOK_READY`

There is no full Notification module in this phase. The backend registers an after-commit hook/log point so delivery can be connected later without changing the transaction timing rule.

## Existing Trip Add-Member Baseline

The basic existing-Trip add-member flow is now implemented for UI testing:

```text
POST /api/v1/trips/{id}/members
-> leader only
-> validate selected users
-> ignore duplicate/already-active members
-> convert PERSONAL to GROUP when needed
-> create/reuse linked group conversation exactly once
-> sync conversation_members
-> after-commit notification hook/log point
```

Full invite acceptance/approval policy is still deferred.

## Deferred

- Invite acceptance/rejection.
- Leader approval.
- Leader transfer.
- Leave/dissolve policy.
- Trip Stop time update endpoint and route optimization.
- Pinned Trip and location sharing.
