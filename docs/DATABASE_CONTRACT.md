# DATABASE_CONTRACT.md — GoMate Data + Flyway Contract

> Current source 2026-10-30: Flyway V1–V28, **40 business tables** plus flyway_schema_history. V27 adds `reviews`; V28 adds `post_home_views`. The broad catalog below is a historical design roadmap, not a claim that every conceptual table exists. Actual Post save is `post_saves` (not `saved_posts`); Global Block is `user_blocks`; actual invitations are `trip_invitations`. Do not create parallel tables from conceptual names.

Actual V28 inventory:
```text
users user_profiles user_settings refresh_sessions
interest_groups interest_options user_interests interest_tag_mappings
place_categories places place_media place_tags place_tag_links reviews
user_follows follow_requests user_blocks
posts post_media hashtags post_hashtags post_user_tags post_likes post_saves post_home_views
comments comment_likes comment_media post_reports
conversations conversation_members
trips trip_members trip_stops trip_reminders trip_pins trip_invitations
notifications device_tokens recent_searches
```

## 1. Data placement rule

PostgreSQL is the business source of truth.

MongoDB is for:
- `interaction_events`,
- `messages`,
- `moments` and Moment social events after the Moment backend task is approved,
- `current_locations`,
- `location_history`,
- `location_archives`,
- `audit_logs`,
- `recommendation_logs`.

Do not copy core User/Place/Trip state into MongoDB as a competing source.
Media binary belongs in Cloudinary/object storage; databases keep references/metadata.

## 2. Historical design table catalog — not the live inventory

### Auth/User/Interest
```text
users
refresh_sessions
password_reset_tokens
user_profiles
user_settings
interest_groups
interest_options
user_interests
```

### Social graph
```text
user_follows
follow_requests
user_blocks
```

### Place
```text
place_categories
places
place_media
place_tags
place_tag_links
interest_tag_mappings
place_submissions
saved_places
reviews
review_media
```

### Social post
```text
posts
post_media
hashtags
post_hashtags
post_place_tags
post_user_tags
post_likes
comments
saved_posts
```

### Messaging metadata
```text
conversations
conversation_members
```

### Trip
```text
trips
trip_members
trip_invites
trip_stops
trip_reminders
trip_checkins
```

### Notification/Admin
```text
notifications
device_tokens
reports
```

Do not create extra business tables only because coding is easier. If a genuinely new entity is required, use Change Control.

## 3. ID convention

Baseline:
- UUID: user, trip, conversation, report/invite and similar identity/workflow entities.
- BIGSERIAL/BIGINT: catalogs/content with many records such as Place/Post/Review.

Do not change meaning/relationships without review even if exact SQL type changes slightly.

## 4. Auth/User/Interest schema baseline

### users
```text
id                UUID PK
email             VARCHAR(255) NOT NULL UNIQUE, normalized
password_hash     VARCHAR(255) NOT NULL, BCrypt/Argon2 baseline
role              VARCHAR(20): USER/ADMIN
status            VARCHAR(20): ACTIVE/LOCKED/DELETED
email_verified    BOOLEAN default false
last_login_at     TIMESTAMPTZ nullable
created_at        TIMESTAMPTZ NOT NULL
updated_at        TIMESTAMPTZ NOT NULL
```

### refresh_sessions
```text
id           UUID PK
user_id      UUID FK users
token_hash   VARCHAR(255) UNIQUE
device_name  VARCHAR(120) nullable
expires_at   TIMESTAMPTZ NOT NULL
revoked_at   TIMESTAMPTZ nullable
created_at   TIMESTAMPTZ NOT NULL
```

Never store raw refresh token.

### password_reset_tokens
Official table is required by Master Spec for reset-email flow.
The Master Spec catalog fixes its existence/purpose but the compact parsed field dictionary does not provide a complete column list. Codex must not invent the full schema silently; consult canonical source/current contract when implementing this table.

### user_profiles
```text
user_id            UUID PK/FK users
nickname           VARCHAR(50) UNIQUE NOT NULL
full_name          VARCHAR(120) nullable
avatar_url         TEXT nullable
avatar_public_id   TEXT nullable
city               VARCHAR(100) nullable
bio                VARCHAR(500) nullable
updated_at         TIMESTAMPTZ NOT NULL
```

### user_settings
```text
user_id                       UUID PK/FK users
account_visibility            VARCHAR(20): PUBLIC/PRIVATE
notifications_enabled         BOOLEAN default true
recommendation_enabled        BOOLEAN default true
location_preference_enabled   BOOLEAN default true
created_at                    TIMESTAMPTZ NOT NULL
updated_at                    TIMESTAMPTZ NOT NULL
```

V18 implements `user_settings.account_visibility` as NOT NULL PUBLIC/PRIVATE,
default PUBLIC; API maps this to boolean `isPrivate`. Other historical/current
settings columns are preserved. Pending requests never grant a `user_follows`
edge. Only owner acceptance creates the edge for a PRIVATE target. A privacy
toggle preserves both existing followers and unresolved requests.
See `ACCOUNT_PRIVACY_FOUNDATION_P1A.md` for constraints, API and verification.

### interest_groups
```text
id           BIGSERIAL PK
code         VARCHAR(50) UNIQUE
name         VARCHAR(100) NOT NULL
description  TEXT nullable
sort_order   INT NOT NULL
active       BOOLEAN default true
```

### interest_options
```text
id           BIGSERIAL PK
group_id     BIGINT FK interest_groups
code         VARCHAR(60) UNIQUE
label        VARCHAR(120) NOT NULL
description  TEXT nullable
sort_order   INT NOT NULL
active       BOOLEAN default true
```

### user_interests
Composite identity user/option:
```text
user_id             UUID FK users
interest_option_id  BIGINT FK interest_options
preference_weight   NUMERIC(4,3) default 1
selected_at         TIMESTAMPTZ NOT NULL
```

Onboarding writes `user_interests`; skip is allowed.

## 5. Social graph schema

### user_follows
```text
follower_user_id UUID FK users
followed_user_id UUID FK users
created_at   TIMESTAMPTZ
PK (follower_user_id, followed_user_id)
CHECK follower_user_id <> followed_user_id
```

Current implemented foundation:
- V5 implements accepted directed edges in `user_follows`; V18 adds `follow_requests` without rewriting existing edges.
- Mutual friend is derived from two directed follow rows.
- V18 P1A implements account privacy and pending requests. V26 introduces the single `user_blocks` authority; see `GLOBAL_USER_BLOCK.md`.

### follow_requests
```text
id            UUID PK
requester_id  UUID FK users
target_id     UUID FK users
status        PENDING/ACCEPTED/REJECTED/CANCELLED
created_at    TIMESTAMPTZ
responded_at  TIMESTAMPTZ nullable
```

### user_blocks
```text
blocker_id UUID FK users
blocked_id UUID FK users
created_at TIMESTAMPTZ
PK (blocker_id, blocked_id)
```

## 6. Place schema

### place_categories
```text
id BIGSERIAL PK
code VARCHAR(50) UNIQUE
name VARCHAR(100) UNIQUE NOT NULL
description TEXT nullable
active BOOLEAN default true
```

### places
```text
id               BIGSERIAL PK
category_id      BIGINT FK
name             VARCHAR(200) NOT NULL
description      TEXT nullable
province         VARCHAR(100) NOT NULL
district         VARCHAR(100) nullable
address          TEXT nullable
latitude         DECIMAL(10,7) NOT NULL
longitude        DECIMAL(10,7) NOT NULL
opening_hours    JSONB nullable
price_level      SMALLINT 0..4 nullable
avg_rating       NUMERIC(3,2) cached from reviews
review_count     INT cached
save_count       INT cached
source_type      ADMIN/EXTERNAL_API/USER_APPROVED
external_source  VARCHAR(50) nullable
external_id      VARCHAR(150) nullable
status           ACTIVE/HIDDEN/DELETED
created_at       TIMESTAMPTZ
updated_at       TIMESTAMPTZ
```

### place_media
```text
id BIGSERIAL PK
place_id BIGINT FK places
media_type IMAGE/VIDEO
url TEXT NOT NULL
public_id TEXT NOT NULL
caption VARCHAR(255) nullable
sort_order INT default 0
```

### place_tags
```text
id BIGSERIAL PK
code VARCHAR(60) UNIQUE
label VARCHAR(100) NOT NULL
active BOOLEAN default true
```

### place_tag_links
```text
place_id BIGINT
tag_id BIGINT
weight NUMERIC(4,3) default 1
PK(place_id,tag_id)
```

### interest_tag_mappings
```text
interest_option_id BIGINT
tag_id BIGINT
weight NUMERIC(4,3) default 1
PK(interest_option_id,tag_id)
```

### place_submissions
```text
id UUID PK
submitted_by UUID FK users
name VARCHAR(200) NOT NULL
category_id BIGINT nullable
address TEXT nullable
latitude DECIMAL(10,7) NOT NULL
longitude DECIMAL(10,7) NOT NULL
description TEXT nullable
media_json JSONB nullable
status PENDING/APPROVED/REJECTED
reviewed_by UUID nullable
review_reason TEXT nullable
approved_place_id BIGINT nullable
created_at TIMESTAMPTZ
reviewed_at TIMESTAMPTZ nullable
```

### saved_places
PK `(user_id, place_id)` + `saved_at`.

### reviews

Implemented by V27 (see `PLACE_RATING_REVIEW_FOUNDATION.md`): one new table only, content VARCHAR(1000), publication ACTIVE/DELETED and moderation VISIBLE/HIDDEN. `verified_visit_at` below remains a future check-in proposal and is NOT in V27. `review_media` remains unimplemented. Existing `places.avg_rating/review_count` are recomputed transactionally from ACTIVE/VISIBLE reviews, with empty 0/0 (UI default-five is not stored). Never modify V1–V26.
```text
id BIGSERIAL PK
user_id UUID FK users
place_id BIGINT FK places
rating SMALLINT 1..5
content TEXT nullable
verified_visit_at TIMESTAMPTZ nullable
publication_status ACTIVE/DELETED
moderation_status VISIBLE/HIDDEN
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

One ACTIVE review per user/place.

## 7. Post/chat metadata schema

### P1B/V19 implemented Post schema
Only five tables are added by V19__post_publish.sql:
- posts: BIGSERIAL id, UUID author_id/users FK, UUID client_request_id,
  request_hash, content TEXT, audience ACCOUNT/FRIENDS/ONLY_ME, optional BIGINT
  place_id/places FK, created_at TIMESTAMPTZ. Unique (author_id,client_request_id)
  and author/created/id index.
- post_media: UUID upload id, owner/users FK, nullable post/posts FK, content_hash,
  IMAGE/VIDEO kind, UPLOADING/READY/ATTACHED/CLEANUP state, unique authenticated
  public_id + thumbnail_public_id, format/MIME/bytes/duration/dimensions,
  nullable sort_order and created_at. Attachment shape/duration checks,
  unique (post_id,sort_order), staging cleanup index. No provider URLs exposed.
- hashtags: BIGSERIAL id, NFC/lowercase name TEXT, unique SHA256 name_hash.
- post_hashtags: (post_id,hashtag_id) PK and FKs.
- post_user_tags: (post_id,user_id) PK and FKs.
Single Place tag uses posts.place_id, not an extra bridge. No comments/likes/saves
or future management fields/tables added in P1B.
ACCOUNT resolves through current user_settings.account_visibility; FRIENDS and
ONLY_ME are fixed. Existing PUBLIC/PRIVATE follow request rules are unchanged.
Full contract, media staging lifecycle and tests: POST_PUBLISH_P1B.md.

### P1C/V20 implemented additions
V20__profile_post_management.sql adds posts.pinned_at/deleted_at and
post_media.cleaned_at (all nullable TIMESTAMPTZ), plus
ix_posts_profile_order(author_id,deleted_at,pinned_at,created_at,id).
No new table: 31 total including Flyway. Keep all V1-V19 migrations unchanged.
Pin mutations serialize on existing author's user_settings FOR UPDATE lock and
count all non-deleted pins, including ONLY_ME, before allowing <=3. No auto eviction.
Deletion tombstones the Post and clears pinned_at; all JSON/binary/list reads deny
it immediately. Reconciliation deletes only its authenticated originals/covers and
marks cleaned_at, keeping Post/media metadata/FKs; no restore/trash feature added.
New uploads and attachments require actual video <=30000ms; the V19 <=60000ms
storage check stays to preserve old published media. See PROFILE_POST_P1C.md.

### P2/V21 implemented additions
V21__post_feed_interactions.sql creates ONLY post_likes and post_saves, each with
(post_id,user_id) primary key, FK to posts/users, created_at TIMESTAMPTZ.
Indexes: ix_post_saves_user(user_id,created_at,post_id), ix_posts_feed_created(created_at,id).
No stored mutable Like counter, comments, reports or sharing tables. Rows survive
loss of viewing permission but cannot bypass it; denied requests expose no state.
Settings -> Post row locking serializes authorized idempotent Like/Save writes.
Old rows/migrations remain intact; 32 business tables / 33 including Flyway.
Current Feed/permission/API/evidence: POST_HOME_FEED_P2.md.

### Recommended Home/V28 viewed-post history
V28__post_home_views.sql adds only `post_home_views`: authenticated viewer UUID,
Post BIGINT, viewed_at TIMESTAMPTZ and primary key `(viewer_user_id,post_id)`.
The primary key is the idempotency authority. This history does not delete or
hide source Posts and is not consulted by Profile. New recommended-feed
snapshots consult it only for authors the viewer currently follows; scored
remainder Posts are not filtered. See POST_RECOMMENDED_HOME_VIEW_HISTORY.md.

### Future Post schema roadmap (not the V19-V21 physical schema)

### posts
```text
id BIGSERIAL PK
author_id UUID FK users
title VARCHAR(200) nullable
content TEXT NOT NULL
visibility PUBLIC/FOLLOWERS/ONLY_ME
publication_status ACTIVE/ARCHIVED/DELETED
moderation_status VISIBLE/HIDDEN
archived_at TIMESTAMPTZ nullable
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

### comments
```text
id BIGSERIAL PK
post_id BIGINT
user_id UUID
parent_comment_id BIGINT nullable
content TEXT
publication_status ACTIVE/DELETED
moderation_status VISIBLE/HIDDEN
created_at
updated_at
```

Bridge/media:
- `review_media`
- `post_media`
- `hashtags`
- `post_hashtags`
- `post_place_tags`
- `post_user_tags`
- `post_likes`
- `saved_posts` — historical name; implemented table is `post_saves`

Important:
- Archive != Bookmark.
- Hashtag social taxonomy != `place_tags` AI taxonomy.

### conversations
```text
id UUID PK
type DIRECT/GROUP
created_by UUID
requester_id UUID for DIRECT/message request
recipient_id UUID for DIRECT/message request
user_low_id UUID for DIRECT uniqueness
user_high_id UUID for DIRECT uniqueness
linked_trip_id UUID nullable; unique only for ACTIVE GROUP chat (status=ACCEPTED)
title VARCHAR(150) nullable
status PENDING/ACCEPTED/REMOVED/CLOSED
created_at
updated_at
accepted_at nullable
removed_at nullable
```

### conversation_members
```text
conversation_id UUID
user_id UUID
role LEADER/MEMBER
status PENDING/ACTIVE/LEFT/REMOVED
muted BOOLEAN
blocked BOOLEAN direct-conversation scoped
joined_at nullable
removed_at nullable
last_read_at nullable
PK(conversation_id,user_id)
```

Message body is MongoDB, not PostgreSQL.

Current implemented Direct Message V1:
- `V6__direct_message_foundation.sql` creates `conversations` and `conversation_members`.

Current implemented Group Trip Chat Phase 1:
- `V7__group_trip_chat_foundation.java` extends the V6 direct-message metadata schema for linked group-trip chat.
- `GROUP` conversations must be linked to exactly one `trips.id` through `linked_trip_id`.
- Group chat is not independent; it is created from successful group trip creation.
- Create Trip accepts optional `selectedMemberIds` as invitees. It persists only creator membership plus PENDING invitations/inbox records; the Trip remains PERSONAL until first acceptance. This supersedes Phase 1.2 direct membership.
- Client `tripType` is backward-compatible input only and cannot force the stored business state.
- On accepted invitation, `conversation_members` must mirror active `trip_members`; first acceptance creates one linked chat and later acceptance reuses it in the same transaction.
- Message body remains in MongoDB. PostgreSQL stores metadata, membership, and the trip link only.
- Group roles are only `LEADER` and `MEMBER`.

Phase 4.4A supersedes V7's lifetime-unique Trip link using `V13__group_conversation_lifecycle.java`:
- GROUP status ACCEPTED means active; CLOSED means archived/inactive history. DIRECT states and uniqueness are unchanged.
- PostgreSQL partial unique index `uq_conversations_active_linked_trip` permits at most one ACCEPTED GROUP conversation per linked_trip_id, while retaining CLOSED historical chats. H2 tests use an equivalent generated nullable key; PostgreSQL adds no helper column or new table.
- Trip transactions enforce GROUP = exactly one active chat and PERSONAL = zero. Last MEMBER leave/remove deletes only its trip_members/conversation_members rows and matching own trip_pins row, closes C1 and changes Trip to PERSONAL. Messages and invitation history remain. V16 additionally removes only that departing member's same-Trip current Mongo snapshot after commit; unrelated snapshots/history are untouched.
- Later acceptance creates C2, never reopens C1. Only the active linked chat mirrors current Trip membership; historical chat membership is not current authorization.
- Archived chat is excluded from active Trip/chat joins and protected endpoints, even for a later member of the same Trip. Archived-history browsing is not introduced.

## 8. Trip schema

### trips
```text
id UUID PK
owner_id UUID FK users
archived_at TIMESTAMPTZ nullable (V14; deletion only)
title VARCHAR(200) NOT NULL
description TEXT nullable
trip_type PERSONAL/GROUP
start_date DATE NOT NULL
end_date DATE NOT NULL
timezone default Asia/Ho_Chi_Minh
planned_start_time TIME nullable (V17 legacy-only; preserved, inactive after V25)
created_at
updated_at
```

V14 archive rules: retain Trip/membership/stop/reminder/chat/invitation/inbox
history; close PENDING invites and active linked chat, remove trip_pins.
All active authority requires `trips.archived_at IS NULL`, not just historical
membership. `owner_id` retains creator provenance; current leadership authority
comes from trip_members. Mongo current snapshots cleanup runs after PG commit,
best-effort; Mongo messages are retained. See `TRIP_LEADER_LIFECYCLE_PHASE4_4B.md`.

V16 pin-centric reset removes trips.status/started_at/completed_at and both
trip_members location_sharing_* columns. Replaces ix_trips_owner_status with
ix_trips_owner_created(owner_id,created_at). No new table, no GPS in PostgreSQL.
Historical V1-V15 stay byte-identical. Approved restoration reopens the same
retained latest CLOSED chat of each non-archived terminal GROUP Trip; no new
chat/pin/member/message rows, archived Trips remain archived. See
TRIP_PIN_CENTRIC_BUSINESS_RESET.md for migration/backup/rollback evidence.

### trip_members
```text
trip_id UUID
user_id UUID
role LEADER/MEMBER
status ACTIVE/LEFT/KICKED
invited_by UUID nullable
joined_at NOT NULL
left_at nullable
PK(trip_id,user_id)
```

### trip_invitations
```text
id UUID PK
trip_id UUID
inviter_user_id UUID
invitee_user_id UUID
status PENDING/ACCEPTED/DECLINED/CANCELLED
created_at
responded_at nullable
updated_at
```

Implementation note:
- V11 extends only the invitation status CHECK with CANCELLED. Leader cancellation updates status/updated_at, leaves responded_at for actual invitee responses, and preserves historical notification records. No table/column added.
- `V9__trip_invitation_lifecycle.sql` uses `trip_invitations` for Leader-originated invitations, reused for both create-time and existing-Trip invites after the 2026-10-15 business update.
- Pending duplicate prevention is transactional: the service locks the Trip row before checking/inserting a pending invitation.
- Pending invitation is not membership and must not create `trip_members`, `conversations`, or `conversation_members`.
- The older conceptual name `trip_invites` is superseded by `trip_invitations`; do not create a parallel table for a later member-originated approval phase.

### trip_stops
```text
id UUID PK
trip_id UUID
place_id BIGINT
day_no INT >=1
order_no INT >=1
planned_start_at nullable
planned_duration_min nullable
note TEXT nullable
checkin_radius_m INT default 150
status PLANNED/VISITED/SKIPPED
```

Current V3 implementation uses `planned_start_at + planned_duration_min`, not a separate `planned_end_at`.
Stop-time round-trip hotfix requires no migration: `planned_start_at` remains TIMESTAMPTZ and duration remains integer minutes. API derives the end instant and Trip-local display timestamps. Explicit clear sets BOTH storage fields null; omitted PATCH time leaves both untouched. No backfill/rebase of historical stops on Trip date changes. See `TRIP_STOP_TIME_PERSIST_EDIT_VALIDATION_HOTFIX.md`.
Pre-Big-Update business knowledge still requires time to belong to the Trip Stop occurrence:
- no start time means no complete interval and any end-only value must be ignored/cleared when a later end-time field exists;
- start-only may be persisted as an occurrence-level hint, but API/UI must expose `hasCompleteInterval=false`;
- the same Place may appear more than once as non-adjacent stops;
- adjacent duplicate Place stops are invalid after add/insert, edit/replace Place, delete, reorder, and optimization;
- `trip_stops.id`, not `place_id`, is the identity for occurrence-specific time/edit/delete/reorder operations.

### trip_reminders
```text
id UUID
trip_id UUID
trip_stop_id UUID nullable
recipient_user_id UUID
reminder_type TRIP_START/UPCOMING_STOP
remind_at TIMESTAMPTZ
status PENDING/SENT/CANCELLED
offset_minutes INTEGER nullable (V17 historical 60/30 only)
planned_start_at TIMESTAMPTZ nullable (V17 historical snapshot only)
sent_at TIMESTAMPTZ nullable (V17)
days_before INTEGER nullable (V25; new TRIP_START values 2/1)
trip_start_date DATE nullable (V25 start date snapshot)
reminder_date DATE nullable (V25 scheduled local date)
reminder_timezone VARCHAR(64) nullable (V25 IANA zone snapshot)
```

V25 supersedes the V17 T-60/T-30 policy without rewriting V17 or dropping columns.
All old PENDING TRIP_START rows are cancelled; SENT/inbox history remains intact.
New day-based rows require TRIP_START, days_before 2/1, complete date/zone snapshots,
trip_stop_id/offset_minutes/planned_start_at NULL. Unique
(trip_id,recipient_user_id,reminder_type,reminder_date) permits one row per local
date, regardless of edits. Old offset uniqueness remains for historical rows.
SENT rows/content never change. A current-local-day SENT guard also covers zone edits.
Due queue index: (status,remind_at,id). Only strictly future slots are created on
create/edit/accept/cutover; an overdue pending slot can fire only on its scheduled
local date after 20:00, otherwise CANCELLED. Never send yesterday and today together.
Notification type TRIP_START_REMINDER uses entity_type=TRIP_REMINDER and
entity_id=reminder UUID, not Trip UUID, under the existing notification unique
constraint. Current active membership/account and non-archive are rechecked
under Trip lock before inbox+SENT commit; SSE/eligible FCM run AFTER_COMMIT.
See TRIP_DATE_ONLY_D2_D1_REMINDERS.md. Pin/GPS/Stop time are independent.

### trip_pins
Implemented by Big Update Phase 3 as `V8__trip_pin_state.sql`.

```text
user_id UUID PK FK users(id)
trip_id UUID FK trips(id)
pinned_at TIMESTAMPTZ
```

Rules:
- pinned Trip state is per user;
- one user has at most one pinned Trip;
- pinning requires no Trip journey status (the obsolete `trips.status` column was removed by V16);
- only active Trip members may pin/read the Trip-protected location context.

### trip_checkins
```text
id UUID
trip_id UUID
trip_stop_id UUID
user_id UUID
latitude DECIMAL(10,7)
longitude DECIMAL(10,7)
accuracy_m NUMERIC(8,2) nullable
distance_m NUMERIC(8,2)
source AUTO_GPS
checked_in_at TIMESTAMPTZ
```

Unique `(trip_stop_id,user_id)` for idempotency.

## 9. Notification/Admin schema

### notifications

Post interaction extension (2026-10-23, NO migration after V24): existing type,
actor_id, entity_type/entity_id and data JSONB are reused. POST_LIKE uses
entity_type=POST_LIKE, entity_id="<numeric postId>:<actor UUID>" (<=56 characters).
POST_COMMENT/POST_REPLY use entity_type=POST_COMMENT and numeric commentId as
entity_id. The existing recipient/type/entity unique constraint plus atomic
INSERT ON CONFLICT DO NOTHING chooses the one successful writer; only it emits
after commit. data contains postId and optional commentId only; no caption/media.
Unlike/deletion never removes or resets old inbox identities/read state. No new
table, schema/check/index, notification backfill, or changes to migrations V1-V24.
See POST_INTERACTION_NOTIFICATIONS.md for delivery/permission/UI rules.

Implemented by `V10__trip_invitation_notifications.java` for Trip invitation inbox events. `trip_invitations` remains the invitation/membership authority. UUID inbox IDs are distinct from invitation/trip IDs. Existing invitations are backfilled with new notification IDs. Recipient/actor foreign keys reference users; unique `(user_id,type,entity_type,entity_id)` prevents duplicate events. Status in API is joined from the invitation; read is independent. No Mongo schema change.

Phase 4.2 adds foreground SSE delivery **after successful transaction commit**, not storage. PostgreSQL remains the only durable inbox/invitation truth. Notification signals have ephemeral eventId/kind/notificationId/time; no new table/column/event-log/Flyway migration. Client reconciles through REST and unchanged 12s polling, including cancellation/read state. Flyway remains V1-V11. Push and GPS realtime remain deferred. See `REALTIME_NOTIFICATION_FOUNDATION_V1.md`.

```text
id UUID PK
user_id UUID
type VARCHAR(50)
actor_id UUID nullable
entity_type VARCHAR(30) nullable
entity_id VARCHAR(80) nullable
title VARCHAR(150)
body VARCHAR(500)
data JSONB nullable
is_read BOOLEAN default false
created_at TIMESTAMPTZ
```

### device_tokens

Implemented separately in Phase 4.3 by `V12__notification_device_tokens.sql`, the only new table. Device binding is tied to the authenticated user's revocable refresh session; no JWT/access token is stored. Installation and FCM token are unique, while one user may own multiple installations. Delivery checks existing ACTIVE account/session and push preference. Unregister/invalid-token cleanup is scoped so late responses cannot disable a new binding. No changes to V1-V11 or other schema. See `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md`.
```text
id UUID PK
user_id UUID
token TEXT UNIQUE NOT NULL
installation_id UUID UNIQUE NOT NULL
session_id UUID FK refresh_sessions NOT NULL
platform ANDROID/IOS
enabled BOOLEAN default true
last_seen_at TIMESTAMPTZ NOT NULL
created_at / updated_at TIMESTAMPTZ NOT NULL
```

### reports
```text
id UUID PK
reporter_id UUID
target_type POST/COMMENT/REVIEW/USER
target_id VARCHAR(80)
reason_code VARCHAR(50)
details TEXT nullable
status PENDING/IN_REVIEW/RESOLVED/REJECTED
assigned_admin_id UUID nullable
resolution TEXT nullable
created_at
resolved_at nullable
```

## 10. MongoDB contract

### interaction_events
```text
_id
eventId        unique server event id/idempotency key when available
eventType
userId         when authenticated
entityType?
entityId?
source
createdAt UTC
metadata {}
```

Current implemented event in MongoDB Foundation V1:
```text
eventType = HOME_RECOMMENDATION_SERVED
source    = spring.recommendations.home
metadata  = safe recommendation summary only
```

Additional implemented Social Relationship events:
```text
eventType = USER_FOLLOWED
eventType = USER_UNFOLLOWED
source    = SOCIAL_RELATIONSHIP
entityType = USER
metadata  = { mutualAfter: true|false }
```

Rules:
- Mongo event logging is non-critical; core APIs must still return if MongoDB is down.
- Do not store raw JWT, refresh tokens, Firebase credentials, passwords, raw headers, or exact runtime GPS.
- Recommendation metadata may store destination/context codes, candidate counts, returned `placeId`/`externalId` order, score/model source, and model version.

### moments
Implemented by Moment Backend V1 in MongoDB, without PostgreSQL/Flyway schema changes.

```text
_id
momentId
ownerUserId
mediaUrl
mediaPublicId    Cloudinary URL/public_id references, not binary
mediaType
caption?
visibility
createdAt
expiresAt
deletedAt?
```

Moment views/reactions/mutes are Mongo-owned:

```text
moment_views      momentId, ownerUserId, viewerUserId, viewedAt
moment_reactions  reactionId, momentId, ownerUserId, reactorUserId, type, reactedAt
moment_mutes      muterUserId, mutedUserId, createdAt
```

PostgreSQL remains the source of truth for users, follows/friendship, blocks, and future moderation decisions. Moment V1 does not add a report table/collection.

### messages
```text
_id
conversationId
senderUserId
type TEXT/IMAGE/PLACE/LOCATION/POST
text?
media?
placeId?
postId?
location? GeoJSON Point
createdAt
editedAt?
deletedAt?
```

### trip_current_locations
Implemented by Big Update Phase 3 for snapshot-only member location on Map.

One document per `(tripId,userId)`:

```text
_id
tripId
userId
latitude
longitude
accuracyM
capturedAt
updatedAt
```

Rules:
- PostgreSQL membership + trip_pins is the only location-publishing authority after V16; no separate Share consent columns.
- MongoDB stores runtime location snapshots only.
- No fake member coordinates are allowed.
- Pin-centric reset preserves LAST_KNOWN snapshot semantics; scoped SSE only invalidates location markers.
- User clarification 2026-10-21: UNPIN/switch retains the old Trip's last-known snapshot without changing coordinate/capturedAt/updatedAt. New publishing still requires own pin. Reads filter active membership/account + non-archived Trip, not current pin. No fabricated position without a snapshot. Leave/remove/delete still revoke/clean scoped snapshots. See MAP_PIN_SWITCH_LAST_KNOWN_FIX.md.
- V15 is historical and immutable; V16 removes its now-obsolete share timestamp and earlier Share flag. No GPS columns/tables added.
- No TTL/history/trail added by the pin reset. Historical retention/archive design below is future scope, not a new scheduler.

### location_history
Future scope only, not implemented by this snapshot phase. Eligibility must follow the current pin-centric contract, never retired Trip ACTIVE/Share ON gates. Historical retention target: 0-7 days.

### location_archives
Stores compressed/versioned route summary. Purge raw only after archive success.

### audit_logs
Append-only:
```text
actorId, actorRole, action, targetType, targetId,
before, after, timestamp, requestId
```

### recommendation_logs
```text
requestId unique
userId
tripId?
modelVersion
topK[{placeId,score,reason}]
latencyMs
createdAt
```

## 11. Important index/constraint baseline

PostgreSQL:
- unique `users(email)`
- unique `user_profiles(nickname)`
- `user_follows(follower_user_id,followed_user_id)` PK
- partial unique PENDING follow requests
- Place category/province/status indexes + text/trigram search as chosen
- `saved_places(user_id,place_id)` PK
- unique active review `(user_id,place_id)`
- Post author/time + publication/moderation/search indexes
- Comment post/time
- `trip_members(trip_id,user_id)` PK + one active Leader per Trip
- unique stop order `(trip_id,day_no,order_no)`
- no unique `(trip_id,place_id)` constraint on `trip_stops`; repeated non-adjacent Places are valid
- unique check-in `(trip_stop_id,user_id)`
- notification inbox `(user_id,is_read,created_at)`

Mongo:
- messages `{conversationId:1,sentAt:-1}`
- interaction_events unique `{eventId:1}`
- interaction_events `{userId:1,createdAt:-1}`
- interaction_events `{eventType:1,createdAt:-1}`
- interaction_events `{entityType:1,entityId:1,createdAt:-1}`
- trip_current_locations unique `{tripId:1,userId:1}`
- trip_current_locations `{tripId:1,updatedAt:-1}`
- trip_current_locations `{updatedAt:-1}`
- location history `{tripId:1,userId:1,recordedAt:1}` + 2dsphere
- recommendation_logs unique `requestId`

## 12. Flyway policy

Migration root:
```text
backend/src/main/resources/db/migration/
```

Staged baseline:
```text
V1 Auth/User/Interest
V2 Place
V3 Social
V4 Conversation
V5 Trip/Location integration
V6 Notification/Admin
```

Current implementation also includes later incremental migrations for the already-built social/message/group-trip/pinned-trip/invitation work. For Phase 4.1, the latest Trip workflow migrations are:

```text
V8__trip_pin_state.sql
V9__trip_invitation_lifecycle.sql
V10__trip_invitation_notifications.java
V11__trip_invitation_cancellation.java
```

Rules:
- shared migration is immutable in normal team workflow,
- schema evolution -> new migration,
- Flyway history determines what each machine still needs,
- no copying Docker volume between team members,
- no manual DBeaver schema edit as source of truth,
- Docker Compose provides same DB runtime; Flyway provides same schema,
- seed/demo data maintained separately.

## 13. Current Auth package warning

The teammate Auth README currently says:
- only 4 tables,
- onboarding data is in `user_settings`,
- `schema.sql`,
- no Flyway.

That is **not the canonical database contract**.

When the user asks only for structure reorganization:
- preserve current working database behavior,
- do not silently break it while moving files.

When the user asks for DB alignment:
- introduce Flyway intentionally,
- reconcile current tables with canonical V1,
- add Interest tables and reset-token design,
- migrate existing data safely,
- do not destroy the current Docker volume/data without permission.

See `AUTH_CURRENT_STATE.md`.


## Implemented V22: Post Comment / Report P3

Actual predecessor V21 verified; V1-V21 unchanged. V22__post_comments_reports.sql
adds comments, comment_likes, comment_media, post_reports ONLY (36 business tables,
37 including Flyway). See POST_COMMENT_REPORT_P3.md for columns, API and tests.
Comments: BIGINT business ID, same-Post composite parent FK, actor/request UUID
uniqueness, logical delete. Comment media: UUID staging identity, owner/Post/Comment
composite FK, protected original + cover IDs, READY/ATTACHED/cleanup lifecycle;
never repurpose post_media or create a general media table. Report UUID has a real
Post FK, reporter/request uniqueness and exactly six approved reasons, PENDING.
The earlier generic reports/Admin outline is still a roadmap, NOT another live
report source. Future moderation requires its own approved contract/migration.
Post counts are projections, not stored mutable counters. Old data is preserved.

## Implemented V23: Settings Post Activity Indexes

Verified predecessor V22. V23__post_activity_indexes.sql adds only indexes on
post_likes(user_id,created_at,post_id) and comments(user_id,created_at,id).
post_saves reuses the V21 user index. No new table/column or activity event source;
the JWT-scoped lists project existing Likes/Saves/own Comments with current Post
permissions. V1-V22 unchanged; 36 business tables remain. See SETTINGS_POST_ACTIVITY.md.

## Implemented V24: P4 Search History

Verified predecessor V23. V24__search_history.sql adds ONLY recent_searches:
user_id UUID FK users, query_key VARCHAR(200), display_query VARCHAR(200),
used_at timestamptz. Composite PK (user_id,query_key); user/time index plus reverse
post_hashtags(hashtag_id,post_id) index. Max eight recent queries are maintained
under the existing user_settings row lock. No Post/Place/Follow schema changes,
no share log table and no duplicate chat storage. V1-V23 remain immutable.
There are now 37 business tables, 38 including Flyway.

POST_SHARE message bodies use existing Mongo messages with a deterministic _id
for sender/request/target. Persisted context is postId + internal request hash;
outgoing DTO exposes postId only. Never persist a Post caption/thumbnail/provider
URL as message preview. DM privacy completion supersedes P4's early commit:
a NEW direct pair is committed only after Mongo acknowledges first TEXT/Share.
On failure, PG rolls back and scoped compensation attempts to remove only the
uncommitted message; deterministic request-bound conversation/message IDs allow
safe retry. No new notification or push.
See POST_SHARE_SEARCH_P4.md for target eligibility. Owner clarification 2026-10-23:
DM and GROUP both carry a Post ID reference only. Sender must be authorized;
recipient access is checked on opening Post/media, not used to filter Share targets.
ONLY_ME delivery never grants viewing permission. No schema change.

DM privacy requires NO migration after V24: reuses V6/V7 DIRECT pair uniqueness,
requester/recipient/status, conversation_members and existing messages collection.
DRAFT is a transport-only state, never a conversations.status value. New TEXT
documents use deterministic _id and internal requestHash (not exposed in DTO),
while existing messages stay readable. No outbox/receipt/message-request table.
PostgreSQL and Mongo are not a distributed transaction: failure cleanup is scoped,
best-effort, logged by IDs only, never a deletion of existing chat/history.
