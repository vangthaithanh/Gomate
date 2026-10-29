# BIG_UPDATE_PHASE4_1_TRIP_INVITATION_LIFECYCLE

Status: historical partial implementation, superseded by `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md` on 2026-10-15. Its backend V9/accept transaction is reused; Trip-tab accept/decline UI is removed. Create-time selections now also invite first. Read the final document for current behavior.

## Scope

Phase 4.1 adds durable invitation lifecycle for adding members to an existing Trip.

It does not change create-time `selectedMemberIds` behavior from Phase 1.2:
- creating a Trip with selected members still persists `trip_members` immediately;
- backend still derives `PERSONAL/GROUP` from persisted membership;
- linked group chat is created in the same transaction for create-time group Trips.

## Implemented Business Rule

Existing Trip add-member flow now creates pending invitations instead of inserting `trip_members` immediately.

PENDING invitation is not membership:
- invitee cannot view the Trip;
- no `trip_members` row is inserted;
- no group conversation is created only because a pending invitation exists.

Leader-originated invitation lifecycle:
```text
LEADER sends invitation
-> trip_invitations.status = PENDING
-> invitee accepts
-> insert trip_members MEMBER
-> Trip becomes GROUP when there is another active member
-> create/reuse linked GROUP conversation
-> sync conversation_members with active trip_members
-> trip_invitations.status = ACCEPTED
```

Decline:
```text
PENDING -> DECLINED
```

Decline has no membership, group chat, or Trip type side effect.

## API

```text
POST /api/v1/trips/{tripId}/invitations
Body: { "inviteeUserId": "<uuid>" }
201 -> TripInvitationItem

POST /api/v1/trips/{tripId}/members
Body: { "selectedMemberIds": ["<uuid>"] }
200 -> TripDetail
Compatibility endpoint used by current UI; now creates invitations for existing Trip.

GET /api/v1/trip-invitations/incoming?status=PENDING
200 -> TripInvitationItem[]

POST /api/v1/trip-invitations/{invitationId}/accept
200 -> TripDetail

POST /api/v1/trip-invitations/{invitationId}/decline
200 -> TripInvitationItem
```

## Schema

Flyway:
```text
V9__trip_invitation_lifecycle.sql
```

New table:
```text
trip_invitations
- id UUID PK
- trip_id UUID FK trips(id) ON DELETE CASCADE
- inviter_user_id UUID FK users(id) ON DELETE CASCADE
- invitee_user_id UUID FK users(id) ON DELETE CASCADE
- status PENDING/ACCEPTED/DECLINED
- created_at
- responded_at
- updated_at
```

No new notification table, no new chat table, no Mongo change.

Pending duplicate protection is enforced transactionally by locking the Trip row before checking/inserting invitations, plus indexes on trip/invitee/status.

## Flutter

Trip list screen now reads incoming pending invitations and allows:
- accept invitation;
- decline invitation.

Existing add-member UI keeps the same layout but text now says it sends invitations, not direct membership.

## Important Limitation

This phase uses in-app invitation records only. FCM/push notification delivery is not implemented here.
