# PROJECT_CONTRACT.md — Compact GoMate System Contract

## 1. Project objective

**Thesis topic:** Nghiên cứu và xây dựng hệ thống du lịch thông minh dựa trên kiến trúc đa tầng và mô hình khuyến nghị cá nhân hóa (GoMate).

GoMate is a smart travel system built around:
- Place discovery,
- personal/group Trip planning,
- map/routing,
- opt-in group location and auto check-in,
- personal/group recommendation,
- notifications/admin,
- supporting social/follow/chat/moments.

Target architecture:

```text
Flutter + Spring Boot + PostgreSQL + MongoDB + Firebase + Cloudinary + AI FastAPI
```

The system is not intended to become a pure social network or a pure POI browser.

Priority:
- P0: Auth/User, Place/Discovery, Trip/Group, Map/Location/Check-in, Recommendation, Notification/Admin.
- P1: Social Post, Follow/Friend, Messaging, Moment.
- Removed: legacy Story as a separate non-Moment domain.

## 2. Locked design decisions

- Build new GoMate architecture; old project is reference for business/UI/assets/experience, not a 1:1 Supabase migration.
- Moment is in product scope as short-lived social media. Moment Backend V1 is implemented with MongoDB + Cloudinary and PostgreSQL-derived mutual-friend permissions.
- Conversation metadata in PostgreSQL; message body/history in MongoDB.
- PUBLIC/PRIVATE account model; mutual active follows imply friendship.
- AI focuses on Place recommendation for user and Trip/group.
- Home combines recommendation/discovery and community feed.
- Core Auth = email/password + email reset + Spring Security/JWT.
- User place proposal goes through `place_submissions`; Admin approves/rejects.
- Review does not require check-in.
- One Trip domain for PERSONAL/GROUP.
- Use "Start Trip"; only ACTIVE enables location/check-in.
- Location sharing is opt-in; MVP does not require background tracking.
- Raw location 7 days then archive/compress; purge only after successful archive.
- Post supports edit/delete/archive/bookmark/like/comment/reply/tags/share-link; no internal repost.

## 3. Responsibilities and source of truth

### Flutter
May:
- render UI,
- basic client validation,
- GPS,
- REST/WebSocket,
- secure token storage,
- analytics.

May not:
- query DB directly,
- hold server secrets,
- be the final authority for permissions/transactions.

### Spring Boot
Owns:
- Auth,
- authorization/permissions,
- server validation,
- transactions,
- business rules,
- routing/media/FCM adapters,
- AI gateway.

### PostgreSQL
Business source of truth:
- User/Profile/Settings/Interests
- Place/Review/Save
- Follow/Post/conversation metadata
- Trip/Member/Stop/Check-in
- Notification/Report

### MongoDB
Time-series/flexible-write domains:
- interaction_events
- messages
- moments and moment social events
- current_locations
- location_history
- location_archives
- audit_logs
- recommendation_logs

### Cloudinary
Binary media; DB stores URL/public_id/metadata.

### Firebase
FCM transport + product Analytics only. Notification business record remains in PostgreSQL.

### AI FastAPI
Spring -> AI. Flutter does not call AI directly. AI returns ranking/suggestion, not business mutations.

## 4. Actors

- Guest: register/login/reset.
- User: ACTIVE account.
- Trip Leader: owns/manages Trip.
- Trip Member: approved active participant.
- Admin: moderation/management.
- System/Batch: reminders, location archive, statistics/model/log jobs.

## 5. Core functional rules

### Auth
- Email normalized lowercase and unique.
- Nickname unique/trimmed.
- Password hashed, never plaintext.
- Refresh sessions revocable by device/session.
- Wrong password -> 401, no session.
- LOCKED -> 403.
- Duplicate email/nickname on register -> 409 and no partial records.

### Privacy/follow/block
- PUBLIC -> follow immediately.
- PRIVATE -> PENDING follow request.
- Friend = reciprocal active follow.
- Cannot follow self.
- No duplicate pending follow request.
- Block overrides follow/DM and closes/cancels related active/pending relationships according to service transaction.

### Place/search/review
- Search covers Place + User + Post.
- Internal Place results respect status/privacy/moderation.
- External search failure must not erase internal results.
- Official Place is created by Admin, controlled external import, or approved user submission.
- External place is imported only when a business action needs an internal Place (save/review/add-to-trip) and no mapping exists.
- Saved Place is unique user/place.
- One active review per user/place; second submission is update flow.
- Review allowed without check-in.
- Valid check-in can set/update `verified_visit_at`.

### Post
- PRIVATE account cannot expose a truly PUBLIC post; backend gates visibility.
- Archive removes post from feed/profile/search but author can restore.
- Bookmark does not bypass visibility.
- Share creates link/deep-link only, no repost.

### Chat
- Non-mutual users: first DM becomes Message Request/PENDING.
- Accept -> ACTIVE.
- Trip Chat membership mirrors active `trip_members`.
- Kick/leave revokes ability to read new/send Trip messages.
- Chat outage must not break Trip.
- Group Chat must be linked to a successful Group Trip creation; do not create independent/orphan group conversations.
- Group Trip and linked Group Chat names must synchronize both ways once the linkage exists.
- Direct Message V1 is real one-to-one messaging and must not be rewritten while extending Group Messaging.

### Trip/group
Lifecycle:
```text
DRAFT -> PLANNED -> ACTIVE -> COMPLETED
                   \-> CANCELLED as allowed by rule
```

Core:
- create Trip + leader membership in one transaction,
- exactly one active LEADER,
- group roles are only LEADER and MEMBER; deputy/co-leader/vice-leader roles are deprecated and must not be introduced in new Trip/Group Chat contracts,
- only Leader edits title/date/description/stops, reorder, start/complete/cancel, kick, approve invite,
- Member may invite but invitee must accept, then Leader approves,
- Leader invite requires invitee acceptance only,
- first other active member switches PERSONAL -> GROUP,
- no automatic GROUP -> PERSONAL downgrade,
- active member only sees Trip-member protected context,
- create-trip UI must not expose a manual personal/group selector; a new trip is personal by default and becomes group when members are added,
- `selectedMemberIds` is optional during creation; backend derives `PERSONAL/GROUP` from persisted membership and ignores client `tripType` as business intent,
- selected members during creation must not receive notification until the trip + members + linked group chat transaction is successfully committed,
- stop order must stay unique/consistent,
- a Trip Stop is a Place occurrence, so `A -> B -> A` is valid but adjacent duplicate places such as `A -> A` are invalid,
- Trip Stop time belongs to the stop occurrence; no start time means no complete interval and any end-only value must be ignored/cleared,
- start-only stop time may be kept as a loose hint but must not be treated or rendered as a complete interval,
- Trip Stop mutation APIs must use `tripStopId` for occurrence-specific edit/delete/reorder/time operations,
- route optimization must keep unscheduled stops in the route and prioritize distance/km unless a later approved contract says otherwise.
- pinned Trip is per user and must not be modeled as `trips.status=ACTIVE`.
- the current Phase 3 member-location implementation is snapshot-only and returns last-known data, not realtime/live tracking.

Pre-Big-Update Trip/Maps/Messaging rules are tracked in:
- `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md`
- `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md`

Invite statuses:
```text
PENDING_INVITEE
WAITING_LEADER_APPROVAL
APPROVED
DECLINED_BY_INVITEE
REJECTED_BY_LEADER
CANCELLED
EXPIRED
```

### Location/check-in
- only ACTIVE Trip,
- sharing default OFF per member/Trip,
- Flutter sends GPS only while tracking is active in MVP,
- current location stale state must be visible in UI,
- poor accuracy sample must not create false check-in,
- distance <= stop radius and no previous check-in -> create exactly one,
- no manual check-in override in MVP,
- raw history 0-7 days, archive before purge.

### Notification
- write business notification to PostgreSQL first,
- then send FCM if enabled + active device target,
- FCM failure does not roll back business,
- global notification switch only controls push transport,
- Notification Center record stays.

### AI
- candidate business filtering occurs in Spring,
- AI returns `placeId + score + reason + modelVersion`,
- hidden/deleted/ineligible places removed,
- AI down -> controlled fallback,
- Group MVP should compare Average Satisfaction and Least Misery before more complex weighting,
- Leader role does not automatically mean stronger preference weight.

### Admin/audit
Admin actions such as lock/unlock, hide/restore, approve/reject and report resolution must append audit log.

## 6. Home/search UX intent

Home suggested order:
1. common header/search,
2. "For you"/"Near you",
3. upcoming/ACTIVE Trip,
4. permission-filtered community feed,
5. category/interest discovery.

Unified search:
- Place: ACTIVE internal + clearly marked external fallback.
- User: ACTIVE basic profile, respecting block.
- Post: ACTIVE + visible moderation + privacy gate; archived excluded.

## 7. API catalog baseline

Base `/api/v1`.

### Auth/User
```text
POST  /auth/register
POST  /auth/login
POST  /auth/refresh
POST  /auth/logout
POST  /auth/password/forgot
POST  /auth/password/reset

GET   /users/me
PATCH /users/me
GET   /users/{id}
GET/PATCH /users/me/settings
PUT   /users/me/interests
```

### Follow/Search/Place
```text
PUT    /users/{id}/follow
DELETE /users/{id}/follow
GET    /users/{id}/relationship
GET    /users/me/following
GET    /users/me/followers
GET    /users/me/mutual-friends
GET    /follow-requests
POST   /follow-requests/{id}/accept
POST   /follow-requests/{id}/reject
POST   /users/{id}/block

GET    /search?q=&type=
GET    /places
GET    /places/{id}
POST   /places/{id}/save
DELETE /places/{id}/save
POST   /places/{id}/reviews
PATCH  /reviews/{id}
DELETE /reviews/{id}
POST   /place-submissions
```

Current implemented Social Relationship V1:
- `user_follows` stores directed follow edges in PostgreSQL.
- Mutual friend is derived from reciprocal active follows.
- Follow/unfollow are idempotent and resolve the actor from JWT.
- `follow_requests`, global block, Message backend, Moment backend and Share backend remain separate follow-up scopes.

### Post
```text
POST   /posts
GET    /posts/feed
GET    /posts/{id}
PATCH  /posts/{id}
POST   /posts/{id}/archive
POST   /posts/{id}/restore
DELETE /posts/{id}
POST   /posts/{id}/like
DELETE /posts/{id}/like
POST   /posts/{id}/comments
POST   /posts/{id}/bookmark
DELETE /posts/{id}/bookmark
```

### Chat
```text
GET    /conversations
POST   /conversations/direct
GET    /conversations/{id}
GET    /conversations/{id}/messages
POST   /conversations/{id}/messages
PATCH  /conversations/{id}/name
POST   /conversations/{id}/read
POST   /conversations/{id}/mute
DELETE /conversations/{id}/mute
POST   /conversations/{id}/block
DELETE /conversations/{id}/block
GET    /message-requests
POST   /message-requests/{id}/accept
DELETE /message-requests/{id}
```

Current implemented Direct Message V1:
- one-to-one direct chat only;
- non-mutual users create a pending message request;
- mutual friends open accepted conversation;
- conversation metadata is PostgreSQL;
- message bodies/history are MongoDB;
- linked Group Trip Chat Phase 1.2 is implemented for create-time selected members;
- add/remove member after an existing Trip, invite acceptance/approval lifecycle, realtime delivery, and media messages remain deferred.

### Trip/location
```text
POST   /trips
GET    /trips/{id}
PATCH  /trips/{id}
POST   /trips/{id}/stops
PATCH  /trips/{id}/stops/{stopId}
PATCH  /trips/{id}/stops/reorder
POST   /trips/{id}/stops/optimize
DELETE /trips/{id}/stops/{stopId}
POST   /trips/{id}/invites
POST   /trip-invites/{id}/accept
POST   /trip-invites/{id}/leader-approve
POST   /trip-invites/{id}/leader-reject
DELETE /trips/{id}/members/{userId}
POST   /trips/{id}/start
POST   /trips/{id}/complete

PUT /trips/{id}/location-sharing
PUT /trips/{id}/location
GET /trips/{id}/locations
GET /trips/pinned
POST /trips/{id}/pin
DELETE /trips/{id}/pin
```

### Recommendation/notification/admin
```text
GET   /recommendations/places
GET   /trips/{id}/recommendations

GET   /notifications
PATCH /notifications/{id}/read
POST  /devices/token

GET   /admin/users
PATCH /admin/users/{id}/status
CRUD  /admin/places
GET/PATCH /admin/place-submissions
GET/PATCH /admin/reports
PATCH /admin/posts/{id}/moderation
PATCH /admin/reviews/{id}/moderation
```

Do not infer omitted request/response fields. Inspect the current contract/OpenAPI or ask before inventing them.

## 8. API response/error conventions

Success:
```json
{"data": {}, "meta": {}, "requestId": "..."}
```

Error:
```json
{"error": {"code": "...", "message": "...", "fieldErrors": {}}, "requestId": "..."}
```

Pagination:
- page,size,totalItems,totalPages, or cursor where domain needs it.

Time:
- backend ISO-8601 UTC,
- client localizes.

## 9. Interaction events for AI

Core event examples and initial research weights:
- PLACE_VIEW 1.0
- PLACE_SEARCH_CLICK 1.5
- RECOMMENDATION_IMPRESSION 0.0
- RECOMMENDATION_CLICK 2.0
- SAVE_PLACE 3.0
- UNSAVE_PLACE -1.0
- REVIEW_CREATE 4.0
- REVIEW_UPDATE 0.5
- ADD_TO_TRIP 4.0
- REMOVE_FROM_TRIP -1.0
- CHECK_IN 5.0
- POST_PLACE_CLICK 1.0

Weights are experiment baselines, not claims of optimality.

AI output:
```text
requestId
modelVersion
items[].placeId
items[].score
items[].reasonCodes
items[].reasonText
latencyMs
```

## 10. Non-functional baseline

Security:
- password hash,
- short access JWT,
- revocable refresh,
- secrets server-side,
- upload validation,
- permission service,
- privacy/block gate.

Reliability:
- FCM/AI/Map failure must not corrupt business transaction.

Consistency:
- create Trip + Leader member transactional,
- saves/reviews uniqueness,
- invites idempotent,
- check-ins unique.

Privacy:
- location opt-in,
- Trip-member visibility only,
- raw location retention 7 days,
- analytics contains no email/phone/message body/exact GPS.

Observability:
- requestId/correlationId,
- application logs,
- admin audit,
- recommendation log/modelVersion.

Reproducibility:
- Flyway,
- Mongo index/config scripts,
- Docker Compose,
- AI artifact/version,
- seed data.

Performance targets for demo:
- Place search/Trip detail p95 target < 800 ms,
- recommendation p95 target < 2 s end-to-end when model/server is local/demo.

UX:
- loading/empty/error,
- permission-denied,
- offline/reconnect,
- notification deep link.

## 11. Intentionally not locked

These may be experimented with without changing business intent:
- exact map/routing provider,
- exact location compression method,
- AI weight values/group aggregation winner,
- media provider may later swap behind adapter,
- exact WebSocket/STOMP implementation,
- exact search ranking algorithm/fallback threshold.

Do not confuse an implementation choice with a business rule.
