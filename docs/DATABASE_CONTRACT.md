# DATABASE_CONTRACT.md — GoMate Data + Flyway Contract

## 1. Data placement rule

PostgreSQL is the business source of truth.

MongoDB is for:
- `interaction_events`,
- `messages`,
- `current_locations`,
- `location_history`,
- `location_archives`,
- `audit_logs`,
- `recommendation_logs`.

Do not copy core User/Place/Trip state into MongoDB as a competing source.
Media binary belongs in Cloudinary/object storage; databases keep references/metadata.

## 2. PostgreSQL official table catalog

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
follows
follow_requests
blocked_users
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

### follows
```text
follower_id  UUID FK users
following_id UUID FK users
created_at   TIMESTAMPTZ
PK (follower_id, following_id)
```

### follow_requests
```text
id            UUID PK
requester_id  UUID FK users
target_id     UUID FK users
status        PENDING/ACCEPTED/REJECTED/CANCELLED
created_at    TIMESTAMPTZ
responded_at  TIMESTAMPTZ nullable
```

### blocked_users
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
- `saved_posts`

Important:
- Archive != Bookmark.
- Hashtag social taxonomy != `place_tags` AI taxonomy.

### conversations
```text
id UUID PK
type DIRECT/GROUP/TRIP
created_by UUID
trip_id UUID nullable UNIQUE for TRIP
title VARCHAR(150) nullable
status PENDING/ACTIVE/CLOSED
created_at
```

### conversation_members
```text
conversation_id UUID
user_id UUID
role OWNER/ADMIN/MEMBER
status PENDING/ACTIVE/LEFT/REMOVED
joined_at nullable
left_at nullable
last_read_at nullable
PK(conversation_id,user_id)
```

Message body is MongoDB, not PostgreSQL.

## 8. Trip schema

### trips
```text
id UUID PK
owner_id UUID FK users
title VARCHAR(200) NOT NULL
description TEXT nullable
trip_type PERSONAL/GROUP
status DRAFT/PLANNED/ACTIVE/COMPLETED/CANCELLED
start_date DATE NOT NULL
end_date DATE NOT NULL
timezone default Asia/Ho_Chi_Minh
started_at TIMESTAMPTZ nullable
completed_at TIMESTAMPTZ nullable
created_at
updated_at
```

### trip_members
```text
trip_id UUID
user_id UUID
role LEADER/MEMBER
status ACTIVE/LEFT/KICKED
invited_by UUID nullable
joined_at NOT NULL
left_at nullable
location_sharing_enabled BOOLEAN default false
PK(trip_id,user_id)
```

### trip_invites
```text
id UUID PK
trip_id UUID
invited_user_id UUID
invited_by_user_id UUID
status:
  PENDING_INVITEE
  WAITING_LEADER_APPROVAL
  APPROVED
  DECLINED_BY_INVITEE
  REJECTED_BY_LEADER
  CANCELLED
  EXPIRED
message VARCHAR(300) nullable
created_at
invitee_responded_at nullable
leader_reviewed_at nullable
```

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

### trip_reminders
```text
id UUID
trip_id UUID
trip_stop_id UUID nullable
recipient_user_id UUID
reminder_type TRIP_START/UPCOMING_STOP
remind_at TIMESTAMPTZ
status PENDING/SENT/CANCELLED
```

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
```text
id UUID PK
user_id UUID
token TEXT UNIQUE NOT NULL
platform ANDROID/IOS/WEB
enabled BOOLEAN default true
last_seen_at TIMESTAMPTZ NOT NULL
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
eventId        idempotency
eventType
userId         when authenticated
placeId? postId? tripId?
recommendationRequestId?
timestamp UTC
context {}
```

### messages
```text
_id
conversationId
senderId
type TEXT/IMAGE/PLACE/LOCATION/POST
text?
media?
placeId?
postId?
location? GeoJSON Point
sentAt
editedAt?
deletedAt?
```

### current_locations
One document per `(tripId,userId)`, with GeoJSON point, accuracyM, updatedAt. Stale threshold must be respected.

### location_history
Raw GPS only when Trip ACTIVE + sharing ON. Retention 0-7 days.

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
- `follows(follower_id,following_id)` PK
- partial unique PENDING follow requests
- Place category/province/status indexes + text/trigram search as chosen
- `saved_places(user_id,place_id)` PK
- unique active review `(user_id,place_id)`
- Post author/time + publication/moderation/search indexes
- Comment post/time
- `trip_members(trip_id,user_id)` PK + one active Leader per Trip
- unique stop order `(trip_id,day_no,order_no)`
- unique check-in `(trip_stop_id,user_id)`
- notification inbox `(user_id,is_read,created_at)`

Mongo:
- messages `{conversationId:1,sentAt:-1}`
- interaction `{userId:1,timestamp:-1}` and `{placeId:1,eventType:1}`
- current location unique `{tripId:1,userId:1}`
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
