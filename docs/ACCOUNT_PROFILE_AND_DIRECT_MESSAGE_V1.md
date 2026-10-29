> Historical create-on-open/DIRECT-only block rules below are SUPERSEDED by DIRECT_MESSAGE_PRIVACY_REQUESTS.md, DM_INBOX_ORDER_AND_REFERENCE_SHARE_FIX.md and GLOBAL_USER_BLOCK.md.

> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Account Profile + Direct Message V1

Date: 2026-10-08

## Scope Completed

- Account/Profile API now exposes real current-user/public profile data from PostgreSQL.
- Profile and Settings Flutter screens read the signed-in user from `AuthService.user` instead of hard-coded TEST_ACCOUNT_B data.
- Direct Message V1 is implemented for one-to-one conversations.
- Conversation metadata is stored in PostgreSQL.
- Message bodies are stored in MongoDB.
- Group chat, calls, voice, media messages, and Moment backend remain deferred.

## PostgreSQL Migration

`V6__direct_message_foundation.sql` creates only:

- `conversations`
- `conversation_members`

The migration does not create group chat tables, message body tables, media/file tables, or Moment tables.

Important constraints:

- Direct conversations use one unordered pair: `UNIQUE (type, user_low_id, user_high_id)`.
- `type` is currently limited to `DIRECT`.
- Status is `PENDING`, `ACCEPTED`, `REMOVED`, or `CLOSED`.
- `conversation_members` stores per-user state: active/removed, muted, blocked, last read.

## API Contract Implemented

Profile:

- `GET /api/v1/users/me`
- `GET /api/v1/users/me/profile`
- `PATCH /api/v1/users/me`
- `PATCH /api/v1/users/me/profile`
- `GET /api/v1/users/{userId}`
- `GET /api/v1/users/search?q=&page=&size=`

Direct messages:

- `GET /api/v1/conversations`
- `POST /api/v1/conversations/direct`
- `GET /api/v1/conversations/{conversationId}`
- `GET /api/v1/conversations/{conversationId}/messages`
- `POST /api/v1/conversations/{conversationId}/messages`
- `POST /api/v1/conversations/{conversationId}/read`
- `POST /api/v1/conversations/{conversationId}/mute`
- `DELETE /api/v1/conversations/{conversationId}/mute`
- `POST /api/v1/conversations/{conversationId}/block`
- `DELETE /api/v1/conversations/{conversationId}/block`
- `GET /api/v1/message-requests`
- `POST /api/v1/message-requests/{conversationId}/accept`
- `DELETE /api/v1/message-requests/{conversationId}`

## Business Rules

- Mutual friends open an accepted direct conversation.
- Non-mutual users create a pending message request.
- In pending state, only the requester can send until the recipient accepts.
- Other users cannot view or mutate a private direct conversation.
- Blocking is scoped to the direct conversation, not a global user block table.
- MongoDB outage makes message send/history return controlled `503 MESSAGE_STORE_UNAVAILABLE`.
- Conversation list can still show PostgreSQL metadata when MongoDB latest/unread data is unavailable.

## Flutter Integration

- `ProfileScreen` and `SettingsScreen` use `AuthService.loadProfile()` and live auth listener updates.
- `MessageScreen` defaults to `RealDirectMessageRepository`.
- `RealDirectMessageRepository` calls the direct-message APIs through existing `AuthService.request`.
- Existing group-message UI remains mock/deferred because backend Group Chat is not part of V1.
- `DemoMessageRepository` remains available for mock/group screens and tests.

## Notes For Next Steps

- Add proper edit-profile form if the UI needs users to update name, city, bio, or avatar.
- Add group/trip chat only after the Trip Chat backend scope is approved.
- Add message media/upload only after media-message rules are approved.
- Add WebSocket/realtime refresh later; V1 uses REST and local refresh.
