# PROJECT_CONTRACT.md — Compact GoMate System Contract

Current UI/invitation authority (2026-10-15): `CODEX_RECOVERY_SYNC_F11C6F7_INVITATION_FINAL.md`, the three UI handoff docs, and `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md`. Older Phase 1.2 direct create-time membership is superseded.

> Release authority 2026-10-29: [AI handoff](AI_HANDOFF/00_START_HERE.md) maps current V26 source and evidence. Historical endpoint/schema/lifecycle descriptions below are superseded at conflicts by the latest Post, DM, Global Block, pin-centric and D2/D1 reports; Post AI remains a proposal.

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
- PIN is the user's location-publishing intent; no Trip journey status or separate Start/Share action. Check-in remains separate future scope.
- Location publishing is pin-driven; preserve the existing Android native foreground-service implementation without promising exact background timing.
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
- Global Block is the single directed PostgreSQL authority across Profile/DIRECT/Settings (user decision 29/10/2026). It revokes both follow edges and cancels PENDING follow requests; it NEVER closes/accepts/deletes DM, Group Chat, Trip membership, Pin or reminders.
- Post/media/search/social delivery and Trip GPS REST/SSE/LAST_KNOWN are filtered both ways. Global snapshots remain for unrelated active members. Unblock removes only the caller direction and never restores follows. See `GLOBAL_USER_BLOCK.md`; historical scoped-DIRECT notes are superseded.

### Place/search/review
- Search covers Place + User + Post.
- Internal Place results respect status/privacy/moderation.
- External search failure must not erase internal results.
- Official Place is created by Admin, controlled external import, or approved user submission.
- External place is imported only when a business action needs an internal Place (save/review/add-to-trip) and no mapping exists.
- Saved Place is unique user/place.
- One active review per user/place; second submission is update flow.
- V27 Place review implementation is documented in `PLACE_RATING_REVIEW_FOUNDATION.md`: owner-only create/edit/soft-delete, real ACTIVE/VISIBLE average/count. Owner clarification 2026-10-29: zero reviews DISPLAY 5.0 + “Chưa có đánh giá”, while DB/API remain 0/0; never use display-five as an AI rating/vote. No review media upload, notification, or AI model change in this foundation.
- Review allowed without check-in.
- Valid check-in can set/update `verified_visit_at`.

### Post
- Like list extension: GET /posts/{id}/likes?size=&cursor= returns active liker
  public identity fields only, newest Like/UUID first, under current Post permission.
  Cursor binds Post/viewer; reading never Likes or notifies. Existing heart
  long-press opens a GoMate bottom sheet; no Feed/media refresh. See
  POST_LIKERS_AND_ANDROID_ACCEPTANCE.md (no schema change after V24).
P1B/V19 implements create/detail; P1C/V20 adds real Profile paging, pin/unpin,
audience edit and owner delete using the existing GoMate UI and PostgreSQL/JDBC.
Latest P1B/P1C audience rules supersede older Post handoff audience lists:
- PUBLIC defaults to EVERYONE; choices EVERYONE / FRIENDS / ONLY_ME.
- PRIVATE defaults to FOLLOWERS; choices FOLLOWERS / FRIENDS / ONLY_ME.
- FRIENDS means mutual accepted follow; pending requests and user tags grant no access.
- Store ACCOUNT for the account-dependent choice; read current account_visibility to
  resolve EVERYONE/FOLLOWERS. Privacy changes do not rewrite Posts or accepted follows.
- All Post binaries and covers are Cloudinary authenticated assets. Clients receive
  only Spring-relative paths; each JWT-protected GET rechecks Post access, no-store,
  with video Range support. Internal signed provider download expires after 30 seconds.
- P1C overrides NEW upload/publish video to <=30s; published 31-60s videos remain
  readable/seekable under existing rights. Storage V19 still permits old 60s values.
  Other limits unchanged: 1-12 mixed media, caption <=2200 graphemes, image <=10 MB,
  video <=100 MB (decimal).
- Owner pin <=3 atomically under author Settings row lock, INCLUDING ONLY_ME.
  Pinned-first by pinnedAt DESC, createdAt DESC, id DESC. Delete frees a pin slot.
- Profile pages filter rights before cursor/limit and expose no hidden total.
  Owner delete tombstones Post; original/thumbnail/Range are immediately denied,
  provider cleanup reconciles separately. No archive/restore product workflow.
- P2/V21 Home Feed now returns ALL currently visible Posts, newest first by
  (created_at,id) DESC; Profile pins never reorder Home. Persistent idempotent
  Like/Unlike and Save/Unsave return viewer-specific flags and real Like counts.
  List/count/actions/media enforce server eligibility; no Like notification or AI
  Feed ranking. No demo Post fallback. See POST_HOME_FEED_P2.md.
- The current Home extension uses `GET /api/v1/feed/recommended`: mutual-follow
  posts first, followed-author posts second, then the existing Spring
  recommendation score. V28 stores idempotent per-viewer Home views. A new
  snapshot filters viewed Posts only when the viewer currently follows the
  author; the scored remainder and Profile are not filtered. See
  POST_RECOMMENDED_HOME_VIEW_HISTORY.md. This does not train or change AI v15.
- Comment/Report, internal Share/Post Search and DM privacy requests are implemented; see the addenda below. Guest sharing remains deferred.
  PROFILE_POST_P1C.md governs ownership/30s; POST_PUBLISH_P1B.md remains historical.
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
- Existing Trip invitation acceptance must sync linked Group Chat membership from active `trip_members`; pending invitations are not chat membership.

### Trip/group
Pin-centric reset (2026-10-16): Trip has no journey status, Start/Complete/Cancel or separate Share switch. Read `TRIP_PIN_CENTRIC_BUSINESS_RESET.md` before changing Trip/Map/location.

Core:
- create Trip + leader membership in one transaction,
- exactly one active LEADER,
- group roles are only LEADER and MEMBER; deputy/co-leader/vice-leader roles are deprecated and must not be introduced in new Trip/Group Chat contracts,
- only Leader edits title/date/description/stops, reorders, kicks, approves invite,
- Member may invite but invitee must accept, then Leader approves,
- Leader invite requires invitee acceptance only,
- current Phase 4.1 covers Leader-originated invitations both during Trip creation and later with `PENDING/ACCEPTED/DECLINED/CANCELLED`; member-originated invite + Leader approval remains a later phase,
- only active LEADER can cancel a PENDING invitation; cancellation never removes accepted membership/chat. Lifecycle writers lock Trip before invitation, then recheck authority; re-inviting after cancellation uses a new invitation ID,
- Phase 4.4B: `PATCH /trips/{id}/leader` with `targetUserId` transfers only to an active current MEMBER. Old Leader becomes MEMBER, stays in Trip, and may leave separately after ACK. The same active Group Chat retains its ID and gets synchronized roles in the same PostgreSQL transaction,
- Phase 4.4B: `DELETE /trips/{id}` means soft archive, only by the current Leader. History stays, all PENDING invites become CANCELLED, active chat becomes CLOSED, pins are removed. Archived Trip is excluded from active reads and permissions, including location and chat sends. Repeated archive by its retained Leader is safe,
- Approved transfer UI: existing Members selection mode shows a key beside trash only for exactly one MEMBER; reuse GoMate confirmation, no new screen, no automatic transfer-and-leave. Role/cache changes wait for server ACK,
- cancellation UI belongs to each row of the outer pending-invitation list on the Members screen, not the Add popup. For a saved Trip, pending and successfully added invitees disappear from Add candidates; cancelling outside makes them eligible for selection again,
- pending Trip invitation is not membership and must not create `trip_members`, linked Group Chat, or `conversation_members`,
- accepting a Leader-originated invitation adds the invitee as MEMBER, converts PERSONAL -> GROUP if needed, and creates/reuses exactly one ACTIVE linked Group Chat; CLOSED historical chats are never reused,
- first other active member switches PERSONAL -> GROUP,
- Phase 4.4A supersedes the former no-downgrade rule: when the last MEMBER leaves/is removed, GROUP -> PERSONAL, old chat CLOSED/retained, no active linked chat; a later acceptance creates a NEW active chat and switches PERSONAL -> GROUP,
- active member only sees Trip-member protected context,
- create-trip UI must not expose a manual personal/group selector; a new trip is personal by default and becomes group when members are added,
- `selectedMemberIds` is optional during creation and means invitees, not immediate members; ignore client `tripType`, create PERSONAL with creator only,
- create Trip + creator + PENDING invitations + inbox notifications atomically; external delivery must wait until commit; no group chat before first acceptance,
- both create-time selection and existing-Trip additions send invitations; only server acceptance creates membership and linked group chat,
- once Trip creation has succeeded, the member picker's Add sends invitations immediately and waits for server ACK; no second Send action, even while PERSONAL/no linked chat. Only the unsubmitted Create Trip form stages invitees locally,
- stop order must stay unique/consistent,
- a Trip Stop is a Place occurrence, so `A -> B -> A` is valid but adjacent duplicate places such as `A -> A` are invalid,
- Trip Stop time belongs to the stop occurrence; no start time means no complete interval and any end-only value must be ignored/cleared,
- start-only stop time may be kept as a loose hint but must not be treated or rendered as a complete interval,
- Trip Stop mutation APIs must use `tripStopId` for occurrence-specific edit/delete/reorder/time operations,
- Stop time hotfix: optional `plannedStartAt`/`plannedEndAt` inputs accept ISO offset timestamps (existing clients) or ISO local wall timestamps resolved by Spring in the Trip IANA timezone. Responses return UTC instants plus explicitly Trip-local `plannedLocalStartAt`/`plannedLocalEndAt` for display; Flutter must not use the phone timezone to display these wall values. Omitted/null PATCH time fields preserve existing values; `clearTime=true` explicitly clears both stored fields. See `TRIP_STOP_TIME_PERSIST_EDIT_VALIDATION_HOTFIX.md`.
- Setting/changing Stop times requires the selected occurrence day within Trip dates, a non-past day, start strictly after server Clock, and end strictly after start within the same local day. Historical unchanged times/metadata remain editable; changing Trip dates never silently rebases existing Stop timestamps.
- route optimization must keep unscheduled stops in the route and prioritize distance/km unless a later approved contract says otherwise.
- pinned Trip is per user and must not be modeled as `trips.status=ACTIVE`.
- Own PIN is the only publishing intent, for PERSONAL and GROUP. One pin/user. Merely viewing/editing/creating/inviting/accepting/transferring leadership never pins anyone or replaces their other pin.
- Foreground and background publish require own same-Trip pin + active membership/account + non-archived Trip. Viewing snapshots needs membership, not own pin; current active members' actual last-known snapshots remain visible after unpin/switch (user clarification 2026-10-21).
- UNPIN suspends the local publisher before network I/O, then removes only own server pin, NOT the last-known snapshot. Failed unpin retains server UI truth and account-scoped pending-unpin retry; no continued publishing.
- Pin switch retains the old Trip's last-known snapshot without changing its timestamp/coordinates; new GPS is written only to the new pinned Trip. Explicit pin ACK immediately selects the new Trip on Map; passive startup/resume pin restore preserves a viewed preview. Logout stops local workers/SSE but retains server pin. See MAP_PIN_SWITCH_LAST_KNOWN_FIX.md.
- Preserve 15s foreground and approximately 60s native Android background cadence, including stationary ACK. New full Android pin requires GPS + Always permission; capability loss pauses without auto-unpin. No force-stop bypass or timing guarantee.
- Delete remains the separate Phase 4.4B soft archive/chat closure with retained history. Unpin never closes chat or clears membership/invitations/stops.
- Location SSE is not Notification SSE: no inbox rows/popups/badges/FCM for GPS ticks. Reconcile only member locations; diff affected annotations, never trigger Directions/full Trip/Place reload or full Map rebuild on a location tick.

Pre-Big-Update Trip/Maps/Messaging rules are tracked in:
- `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md`
- `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md`

Conceptual full invite statuses for later member-originated approval:
```text
PENDING_INVITEE
WAITING_LEADER_APPROVAL
APPROVED
DECLINED_BY_INVITEE
REJECTED_BY_LEADER
CANCELLED
EXPIRED
```

Current Phase 4.1 implementation uses the smaller Leader-originated status set:
```text
PENDING
ACCEPTED
DECLINED
CANCELLED
```

### Location/check-in
- own same-Trip pin + active membership/account + non-archived Trip authorize current-location publishing,
- no separate Share flag; viewing/creating/accepting does not pin; UNPIN stops own publisher but retains the actual last-known snapshot for current members,
- Flutter sends GPS only for its reconciled acknowledged pin while existing OS capability permits,
- current location stale state must be visible in UI,
- check-in and raw history are future scope, not created by the pin-centric current-snapshot implementation,
- future check-in must reject poor-accuracy false visits, be idempotent per user/stop within stop radius, and not reintroduce retired ACTIVE/Share gates,
- no manual check-in override in the planned MVP,
- future raw-history retention target remains 0-7 days with successful archive before purge.

### Notification
- Post interaction extension (2026-10-23): see `POST_INTERACTION_NOTIFICATIONS.md`.
  POST_LIKE notifies only the Post owner, once per Post/actor even after Unlike;
  Inbox + SSE, never FCM. POST_COMMENT notifies the Post owner; POST_REPLY notifies
  only replyToUserId, not additionally the owner. Self events are suppressed.
  Comment/Reply reuse eligible after-commit FCM on gomate_social_v1 with generic
  text. Save/Share/Report/comment-like remain notification-free. No read/refresh
  event or backfill. This supersedes earlier P2/P3 notification-deferred notes.
  GET /notifications/{id}/post-target checks recipient and current Post permission;
  Post/media access is still checked by their own endpoints. Notification ID is
  not a grant. Missing Comment can open the permitted Post with an unavailable
  notice; deleted/denied Post uses the existing unavailable viewer.
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
PUT    /users/{id}/block
DELETE /users/{id}/block
GET    /users/me/blocked?page=&size=

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
- P1A/V18 adds persistent account privacy and recipient-owned follow requests.
- PRIVATE follow requests never grant accepted edges until owner acceptance.
- Privacy toggles preserve followers and do not auto-accept pending requests.
- PRIVATE follower/friend lists require owner or accepted-follower access.
- Moments/DM keep their existing mutual-follow rules; Trip invitations are unchanged.
- Global block, Post and Share remain outside P1A. See `ACCOUNT_PRIVACY_FOUNDATION_P1A.md`.

### Post
P1C implemented: GET /users/{authorId}/posts?size=&cursor=, PUT/DELETE /posts/{id}/pin,
PATCH /posts/{id}/audience, DELETE /posts/{id}.
P1B retained: POST /posts/media, POST /posts, GET /posts/{id},
GET /posts/{id}/media/{mediaId}, GET /posts/{id}/media/{mediaId}/thumbnail.
Media paths are relative to the existing /api/v1 base and require JWT.
The broader endpoint list below is a roadmap, NOT a claim of implemented P1C/P2-P4:
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
- linked Group Trip Chat is created/reused transactionally on accepted membership;
- Trip invitation lifecycle Phase 4.1 covers create-time selection and existing-Trip invites with a durable Notifications inbox;
- member-originated invite approval, message realtime, media messages, and remove member remain deferred. Foreground notification delivery now uses the Phase 4.2 SSE foundation.

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
POST   /trips/{id}/invitations
GET    /trip-invitations/incoming?status=PENDING
POST   /trip-invitations/{id}/accept
POST   /trip-invitations/{id}/decline
DELETE /trips/{id}/invitations/{invitationId}
DELETE /trips/{id}/members/{userId}
POST   /trips/{id}/start
POST   /trips/{id}/complete
POST   /trips/{id}/cancel

PUT /trips/{id}/location-sharing
GET /trips/{id}/location-sharing
DELETE /trips/{id}/location-sharing
DELETE /trips/location-sharing
POST /trips/{id}/start
PUT /trips/{id}/location
GET /trips/{id}/locations
GET /trips/{id}/locations/stream
GET /trips/pinned
POST /trips/{id}/pin
DELETE /trips/{id}/pin
```

### Recommendation/notification/admin
```text
GET   /recommendations/places
GET   /trips/{id}/recommendations

GET   /notifications
GET   /notifications/stream  (authenticated SSE, no recipient/query parameters)
GET   /notifications/{id}
PATCH /notifications/{id}/read
POST  /notifications/read-all
POST  /notification-devices  (JWT user/session, installationId/token/platform, 204)
DELETE /notification-devices/current  (same user/session + installationId, 204)
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

Current Notifications delivery: PostgreSQL inbox persistence, authenticated foreground SSE emitted only AFTER_COMMIT, and unchanged 12-second polling/REST reconciliation fallback. One global Flutter receiver; signals are hints, not business authority. Pending popup -> inbox spotlight by notificationId -> row Accept by invitationId -> accepted row opens tripId. Reading does not accept. Cancellation updates the existing notification without a new popup; re-invite identities stay distinct. No decline UI. See `REALTIME_NOTIFICATION_FOUNDATION_V1.md` for the Phase 4.2 foreground foundation and the Phase 4.3 extension below.

Phase 4.3 adds Android FCM for committed new invitation/accepted notifications and V12 device registration. Background push is never authority: taps must fetch current notification state after Auth/navigation readiness; cancelled history cannot Accept/open Trip. Foreground FCM builds no extra OS notification/popup and reconciles through the same SSE/polling store. Existing UI/business remain frozen. See `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md` for actual native readiness; iOS/APNs and GPS/schedulers remain deferred.

Phase 4.3 Android foundation is accepted on the physical Android 13 device: background delivery, normal-termination cold start once, no foreground duplicate and stale-cancel opening all passed with user confirmation. The handoff document explicitly retains permission/account-switch/accepted/re-invite native variants as not manually executed; their automated tests passed. This is not an iOS or production deployment readiness claim.

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

## Trip Date-Only Reminders (2026-10-28)

Current rule: TRIP_DATE_ONLY_D2_D1_REMINDERS.md. The V17 optional-hour and late
T-60/T-30 policy in TRIP_START_REMINDER_T60_T30.md is superseded history.
- Original two-tap calendar and endDate >= startDate remain unchanged. Newly
  selected dates cannot be past in Trip timezone. Historical metadata remains
  editable. There is no Trip-level hour picker, default hour, or active
  plannedStartTime/clearStartTime API field. Stop occurrence times are unchanged.
- D-2 and D-1 are 20:00 on startDate minus 2/1 calendar days in Trip's IANA zone.
  Server Clock is authoritative. No day-of-start reminder or journey lifecycle.
  Only current LEADER edits dates/timezone; MEMBER reads.
- Current accepted/active members receive reminders independently of Pin/GPS.
  Pending/declined/left/removed users and archived Trips are excluded.
- Create/edit/accept/cutover schedules only deadlines strictly in the future.
  An overdue PENDING reminder may send later on its scheduled local date only;
  after that date it is cancelled, never bundled with the next day's reminder.
- At most one notification per Trip/recipient/local date, including rescheduling.
  Sent reminder/inbox snapshots are immutable. Leave/remove/archive cancel unsent.
- Reuse PostgreSQL trip_reminders/inbox, AFTER_COMMIT SSE + eligible FCM, existing
  12s reconciliation and client notification-ID dedupe. Tap checks current
  notification and Trip authorization, never pins or starts GPS.
- API GET /api/v1/trips/time-context?timezone=IANA supplies server wall time for
  calendar UX without a new Flutter dependency or polling. Backend Clock is
  authoritative. Invalid date/zone or removed Trip-hour inputs return controlled 400.
- Auto Check-in/memberArrived and per-Stop T-60/T-30 remain deferred.


## Post Comment / Report P3 (2026-10-23)

Current additive contract: POST_COMMENT_REPORT_P3.md. PostgreSQL owns one-level
Comment threads, unique Comment Likes, separate authenticated Comment images and
own-only durable Post Reports. User approved 2,000 characters/comment, 1,000/report
description, max 6 images (10 MB each), no video comments. Post commentCount is all
visible roots + replies, derived on read. Deleting own root hides the thread;
Post author cannot delete others' comments. Reply target grants no privileges.

Settings activity addendum: GET /api/v1/me/liked-posts, /me/saved-posts and
/me/comments expose only current JWT-user interactions, cursor-paged newest
interaction first, filtered by current Post permission. Existing P2/P3 mutations
are reused; no activity table, new delete privilege or public media URL.
Like/Save ACKs synchronize Home/Profile without reloading Feed/media. See
SETTINGS_POST_ACTIVITY.md. P4 Share/Search is described below; unrelated Settings work remains deferred.
Every read/write/media request reuses current Post privacy eligibility. Reports
are non-owner-only, PENDING, per-submission retry-safe; no automatic moderation,
notification or expiry policy. No Trip/Map/AI change.

## Post Share / Search P4 (2026-10-23)

See POST_SHARE_SEARCH_P4.md. Internal Share reuses existing Conversation/Mongo
messages, stores an ID reference only and rechecks current Post/media access on
open. Approved target scope: mutual friends without an existing pending/closed DM,
or users with an ACCEPTED DM (even after unfollow/privacy change); active eligible group chats. No auto-accept,
new message requests or new push. A group may receive a reference even if some
members cannot read it; those members receive no private preview and GET remains
denied. Owner clarification 2026-10-23: DIRECT uses the same reference-only delivery
as GROUP, including ONLY_ME references; only sender authorization is required at
send, and each recipient rechecks Post/media permission when opening. Retries use one durable
key per sender/request/target; partial results do not re-send successful targets.

## DM Privacy / Requests (2026-10-23, V24 unchanged)

See DIRECT_MESSAGE_PRIVACY_REQUESTS.md. Profile canInitiateMessage is server-owned:
PUBLIC recipient permits new contact; PRIVATE requires an accepted outbound follow.
Sender privacy does not restrict contacting a PUBLIC recipient. Existing ACCEPTED
chat by conversation ID continues despite unfollow/privacy; Global Block still wins; legacy DIRECT block endpoints delegate to Global Block.
Profile does not expose its new-contact button merely because such a chat exists.
Opening DIRECT returns existing metadata or a non-persisted DRAFT with null ID.
Only successful first send (including mutual Post Share) persists a new pair and
message. Non-mutual first TEXT becomes PENDING; mutual first send becomes ACCEPTED.
Existing PENDING remains pending even after mutual follows; only its recipient can
accept/delete. Accepted conversation/history is reused, no new follow edges.
The newest owner clarification overrides the task file's obsolete prohibition
on creating a DM during Share: mutual first Share creates ACCEPTED safely;
existing ACCEPTED Share no longer requires a current follow. Group Share remains
reference-only and each member rechecks current Post/media permission on open.

Search keeps its three tabs/states and existing UI. Post caption/hashtag keyword
matching and User/Place search fold Vietnamese accents and the Vietnamese crossed
d into ASCII d. Selected hashtag chips retain canonical NFC tag identity
and use AND. Post previews use authenticated Spring thumbnails only. Results and
hashtag counts filter current privacy before paging/aggregation. Home order and
AI ranking are unchanged. Nearby uses real GPS and distance order, no radius;
missing GPS blocks only nearby Place results. Submitted recent queries are durable,
normalized/deduplicated per JWT user, max eight; live typing does not save history.
