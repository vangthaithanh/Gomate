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
- supporting social/follow/chat.

Target architecture:

```text
Flutter + Spring Boot + PostgreSQL + MongoDB + Firebase + Cloudinary + AI FastAPI
```

The system is not intended to become a pure social network or a pure POI browser.

Priority:
- P0: Auth/User, Place/Discovery, Trip/Group, Map/Location/Check-in, Recommendation, Notification/Admin.
- P1: Social Post, Follow/Friend, Messaging.
- Removed: Moments/Story.

## 2. Locked design decisions

- Build new GoMate architecture; old project is reference for business/UI/assets/experience, not a 1:1 Supabase migration.
- No Moments/Moment reactions/Moment reply.
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

### Trip/group
Lifecycle:
```text
DRAFT -> PLANNED -> ACTIVE -> COMPLETED
                   \-> CANCELLED as allowed by rule
```

Core:
- create Trip + leader membership in one transaction,
- exactly one active LEADER,
- only Leader edits title/date/description/stops, reorder, start/complete/cancel, kick, approve invite,
- Member may invite but invitee must accept, then Leader approves,
- Leader invite requires invitee acceptance only,
- first other active member switches PERSONAL -> GROUP,
- no automatic GROUP -> PERSONAL downgrade,
- active member only sees Trip-member protected context,
- stop order must stay unique/consistent.

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
POST   /users/{id}/follow
DELETE /users/{id}/follow
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
POST /conversations/direct/{userId}
POST /conversations
GET  /conversations
GET  /conversations/{id}/messages
POST /conversations/{id}/accept
POST /conversations/{id}/messages
```

### Trip/location
```text
POST   /trips
GET    /trips/{id}
PATCH  /trips/{id}
POST   /trips/{id}/stops
PATCH  /trips/{id}/stops/reorder
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
