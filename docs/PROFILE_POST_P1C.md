# Profile Post P1C + Video 30s

Updated 2026-10-22. This is the current Post contract. POST_PUBLISH_P1B.md remains
an unchanged historical report of P1B (60 seconds). This report covers P1C only.
P2 Home Feed/Like/Save is now implemented in POST_HOME_FEED_P2.md; P3/P4, message
requests, global Block, archive/restore and redesign remain outside those phases.

Performance follow-up: `POST_MEDIA_PERFORMANCE.md` supersedes the immediate
discard-on-refresh implementation below. Retained mounted tiles are hidden until
a fresh authorized ACK; Spring buffers small image bytes only AFTER per-request
authorization. Audience, no-store, Range and all other P1C rules are unchanged.

## Decisions and Reused UI

- Existing My Profile and PublicProfileScreen retain their headers, avatar,
  spacing, font/colors, three-column square grid (2px gaps) and Place-heart tab.
  Production Post tiles now come only from the authenticated author list API.
  Global preview stores and other modules' demo flows are not deleted.
- GoMateProfilePostFeedScreen and its existing _PostFeedTile are the one viewer:
  selected first, remaining loaded grid order unchanged, no duplicate selected
  item; square full-width media, horizontal media paging, vertical Posts.
- Existing owner menu, _ownAction, GoMateBottomSheet, delete confirmation,
  GoMatePostAudienceContent and GoMateSnackBar are reused. Non-owner menu never
  offers ownership commands. Like/comment/save/share/report/search remain later
  scope; production callbacks do not mutate demo state or fake success.
- P1B's Codex-created PostDetailScreen is now only a compatibility wrapper around
  the existing viewer, NOT a second card/layout. Its protected renderer matches
  GoMate image fit/fallback/play icon; native playback still supports Range/seek.
- Loading/error/retry use existing ProfileEmpty, palette and controls. Pull-refresh
  and a paging scroll listener do not change idle layout. The one MainShell change
  passes Profile's active flag so returning to that tab refreshes server truth.
  No Map, Trip, GPS, AI, DM, Moment or Settings layout/logic was refactored.
- Automated pixel comparison at 400x900 verifies a real-image card against the
  existing preview card form with identical content. This is bounded evidence,
  not a claim that every device/codec/screen has had visual manual acceptance.

## Current Rules

PUBLIC: EVERYONE/FRIENDS/ONLY_ME. PRIVATE: FOLLOWERS/FRIENDS/ONLY_ME.
ACCOUNT stays the canonical database value for the account-dependent audience.
Accepted follow grants FOLLOWERS, mutual accepted follows grant FRIENDS; pending
requests and tags grant nothing. Owner always reads; denied/deleted detail and
media return 404. Privacy changes resolve ACCOUNT on read, not by rewriting Posts.

- Pin owner-only, maximum 3 across all non-deleted Posts, including ONLY_ME.
  Author's existing user_settings row is locked FOR UPDATE before counting and
  mutating: PostgreSQL serializes concurrent pin requests, privacy updates and
  ownership mutations. No silent eviction. Repeated pin/unpin is idempotent.
- Order: pinned group first, pinned_at DESC, created_at DESC, id DESC; ordinary
  group created_at DESC, id DESC. Unpin restores ordinary order; delete frees slot.
- Audience edit is one Post only, validates current server privacy under the same
  Settings lock. API NEVER accepts canonical ACCOUNT as a client selection.
- Delete uses deleted_at tombstone and clears pinned_at; no product trash/history
  or restore endpoint. Existing rows/FKs are preserved. All Post/list/media reads
  immediately exclude it, even if its asset cleanup is still pending.
- Cleanup reuses P1B's 15-minute reconciliation (up to 50 items per run). Deleted
  Post media retain metadata; cleaned_at marks successful original+cover removal.
  Failure retries idempotently. Other Posts/features' assets are never selected.
- All originals/covers remain Cloudinary authenticated, served only by Spring's
  JWT/access-checked proxy. No provider URL/public ID reaches client. No-store and
  video Range remain. Prior authorized/downloaded bytes cannot be recalled.

## Device Gallery Ordering Fix (2026-10-22)

Create Post already requested RequestType.common (images AND videos). On the
connected Android 13 device both media permissions were granted and MediaStore
contained ten videos. The actual bug was leaving filterOption/order unspecified:
the first unordered 72-row page contained 72 images, while the equivalent query
ordered by date_added DESC, _id DESC contained 65 images and seven videos.

create_post_screen.dart now passes an explicit CustomFilter with no WHERE filter,
newest-added first, plus Android _id DESC as a stable tie-breaker. PhotoManager
carries the same filter from the album into every paged query. Other platforms
use their supported creation-date column, without Android-only column names.
No duration filter is applied to the gallery: >30s videos must remain selectable
for the existing real trim/export flow. Existing 12-media cap, permission UI,
camera, video badges, layout, protected upload and server limits are unchanged.
No device files, permission grants, Cloudinary assets or database rows were changed.

New test/post_gallery_test.dart covers mixed media/48s video visibility, authorized
and limited library access, two-page query/filter consistency and denied access.
The focused Flutter Post/Profile/P1A/Auth/notification UI suite passes 40 tests.
Full analyze found 0 errors/16 existing warnings; a new test-only braces info was
corrected. Android debug APK build passes (116.0s); not installed automatically.
Physical-device evidence here is read-only permission/MediaStore metadata queries,
not a claim of testing selection/trim/publish through the updated APK on-device.

## Video Override

New Post video upload AND attach/publish: 0 < duration <=30,000ms. File inspector
uses real local file metadata via ffprobe; provider metadata is checked too.
Old READY staging of 31-60 seconds cannot be newly attached. Existing successfully
published 31-60 second media are NOT rewritten, truncated, deleted or blocked from
authorized GET/playback/Range, pin or audience management. Idempotent publish retry
of an already committed Post returns that Post, not a new attachment.

Create/gallery/camera/trim, Android Media3 and iOS AVAssetExportSession export guards
now use 30 seconds, still producing real MP4 files. Trim layout/slider/form remain
unchanged, only range bounds and duration messages change. Formatting mm:ss still
uses base 60; image thumbnail width 600 and 30-second process timeout are unrelated.
The V19 storage constraint <=60,000ms is intentionally preserved for old data.
Images 10,000,000 bytes, video 100,000,000 bytes, total 1-12 media, caption/hashtags
and other modules' limits are unchanged. No new package or configuration secret.

## V20 and API

V20__profile_post_management.sql adds only:
- posts.pinned_at TIMESTAMPTZ nullable.
- posts.deleted_at TIMESTAMPTZ nullable.
- post_media.cleaned_at TIMESTAMPTZ nullable.
- ix_posts_profile_order(author_id,deleted_at,pinned_at,created_at,id).

No new table; total remains 31 including Flyway. V1-V19 must never be edited.

All routes under /api/v1; JWT actor identity and existing raw DTO/error conventions:

| API | Result |
|---|---|
| GET /users/{authorId}/posts?size=20&cursor=... | items[] + nextCursor; max size 50; no total/hidden IDs/counts |
| GET /posts/{id} | Existing detail + pinned, pinnedAt, authorAvatar, placeName |
| PUT /posts/{id}/pin | Owner pin, 422 POST_PIN_LIMIT for a fourth |
| DELETE /posts/{id}/pin | Owner unpin, detail ACK |
| PATCH /posts/{id}/audience | {audience: EVERYONE/FOLLOWERS/FRIENDS/ONLY_ME}, validated by account |
| DELETE /posts/{id} | Owner-only 204, repeat deletion 204; unauthorized 404 |
| GET /posts/{id}/media/{mediaId}[/thumbnail] | Same protected P1B original/cover/Range |

Profile filtering happens in SQL BEFORE cursor/limit. Cursor is opaque, binds
author/viewer and ordered visible-row keys; tampered scope returns 400. Each detail
is reauthorized before serialization to handle concurrent permission changes.
Pin sorting only operates on visible rows. Private unapproved profile list is empty
with no next cursor. The existing locked Private Profile UI remains.

## State and Files

Backend: PostRepository/Service/Dtos/Controller, new ProfilePostController,
PostFileInspector/PostMediaService reconciliation. Existing protected provider unchanged.
Flutter: PostRepository real list/mutations, ProfilePostsController view-scoped
pages and mapping, Profile/PublicProfile callbacks; existing feed tile/menu; protected
media cleanup; PostDetail wrapper; Create/Trim limits; MainShell active flag only.
Native: PostVideoExporter.kt and AppDelegate export bounds/messages only.
AuthService only extends its existing Post API-candidate memory to the new author
list path, so protected thumbnails use the same successful fallback endpoint.
Tests: PostPublishApiTest adds 4 management/compatibility cases;
profile_posts_test.dart adds 6 focused controller/widget/pixel cases; P1B export
fixture expectations updated to 30s plus one API-candidate integration test. verify-profile-posts.ps1 is isolated-only.

No global Post content/media cache: only an integer invalidation signal. Refresh
discards old items before loading; responses are session/request scoped. Mutation
updates occur after ACK. Resume, Profile tab return, route return, pull-refresh,
Auth/relationship/Settings updates and Post mutation signals refresh current truth.
No new polling, SSE channel or background refresh loop. Remote privacy changes while
already viewing are discovered on these refresh boundaries and every new binary
request, not through a new Post realtime subsystem.

## Evidence

- Baseline: P1B 37 backend/28 Flutter targeted, analyze 0 errors/16 old warnings.
- Current backend Docker build: 41 targeted PASS (11 Post tests + 30 direct
  Auth/Profile/P1A/Relationship/Google/Firebase/DM/Moment/Place regression tests).
  Additional real PostgreSQL HTTP race verification: with two pins already held,
  two concurrent PUT requests result in exactly one 200 and one 422, count stays 3
  (verify-profile-posts.ps1 -PinRaceOnly on an isolated restored DB).
- Current Flutter: 35 targeted PASS (6 new Profile cases, 1 fallback-endpoint case
  + 28 P1B/P1A/Auth/UI). Final analyze: 0 errors, 16 existing warnings (280 total
  issues, including info); no new warning. Debug APK build PASS (83.1s).
  These are focused checks, not a claim of rerunning the unrelated full suite.
- Isolated clean DB V1->V20 and restored V19->V20: real HTTP/Cloudinary smoke PASS.
  Exact real-file 30000ms accepted, 30001ms rejected; real middle 29s clip accepted.
  Paging, role visibility, pin cap, audience, deletion and direct media tested.
- Before upgrading restored DB, the real V19 JAR published a synthetic 45-second
  video and uploaded a separate 45-second READY asset. V20 still reads/Range-seeks
  the published video and rejects attaching its old READY upload. No fake metadata
  substituted for this compatibility test. Both test APIs were restarted/re-logged
  and profile/pin/delete/privacy/old video Range persisted.
- Fixture ownership is separate from the 4 user Posts/9 media existing on main.
  Cloudinary cleanup checks owner-prefixed IDs. No original user assets are deleted.
  Cleanup completed 16 upgrade + 12 clean test-asset/cover operations, plus 8 for
  the separate concurrent HTTP pin verification. Both test APIs, PostgreSQL
  fixtures and the isolated Mongo test DB were removed.
- Main V19->V20 startup PASS, still 31 tables. All 30 old business table row counts
  match cutover backup. Four Posts and nine media retain exact original-column
  content hashes, IDs, timestamps, relationships and Cloudinary identifiers;
  Settings/follow content hashes also match. User/Place/Trip counts stay 38/146/18.
  Current main also retains 2 accepted follow edges, 3 follow-request rows and 217
  refresh sessions as measured at cutover (not inferred from older task reports).
- Backups, V1-V19 hashes, source UI snapshots and logs: ignored
  backups/p1c-pre-v20/. Includes fresh cutover-v19.dump, counts-before/after,
  content-before/after and app-v19.jar recovery artifact. P1B report hash stays
  unchanged. No volume reset/repair. If startup fails, preserve current volume,
  inspect the error and prefer fixing forward; test restored backup separately
  before any owner-approved replacement. Never restore over current data blindly.

## Manual Android Pending

Stop and Run Flutter with the existing run configuration (native export changed;
hot reload is insufficient). No APK installation was performed automatically.

1. Two accounts: real Profile grid, locked Private Profile, correct viewer menu,
   selected-first viewer, horizontal mixed media and vertical Posts, back navigation.
2. Pin 3, reject fourth without evicting; unpin; delete a pinned Post frees a slot.
3. Audience popup and repeated PUBLIC/PRIVATE changes; accepted vs pending vs mutual,
   including original/cover and account switching with no stale private image.
4. Confirm delete, wait ACK, verify old Post/media/Range paths are denied.
5. Pick/record >30s video, select a middle <=30s segment, publish and verify content
   and playback/seek. Native exporter was built but codecs/hardware need real testing.
6. Old 31-60s published video must still play; only synthetic isolated fixture has
   been verified automatically. iOS build/device remain unverified on Windows.

Do not open P2-P4, message requests or redesign while awaiting P1C acceptance.
