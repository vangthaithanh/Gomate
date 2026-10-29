# Post Publish P1B

Updated: 2026-10-22. Scope: real Create Post and read-only verification. Stop here;
Profile grid/management is P1C, Feed/interactions/share/search are later phases.
The newest approved P1B task supersedes the older three-audience Post handoff.

## Approved Contract

- 1-12 combined images/videos, final selection order persisted as sortOrder 0..11.
- Caption preserves Unicode, emoji and newlines; max 2200 grapheme clusters.
- Image <=10,000,000 bytes; exported video <=100,000,000 bytes and <=60 seconds.
- Up to five distinct hashtags: NFC, remove leading #, lowercase, letters/marks/
  numbers/underscore. Flutter and Spring normalize identity; Spring validates.
- Tagged users must be real active users; optional single placeId must be an active
  places.id. Tagging grants no viewing/follow/friend/Trip/DM permission or push.
- PUBLIC account defaults EVERYONE; choices EVERYONE, FRIENDS, ONLY_ME.
- PRIVATE defaults FOLLOWERS; choices FOLLOWERS, FRIENDS, ONLY_ME.
- FOLLOWERS requires an accepted follow. FRIENDS requires mutual accepted follows.
  PENDING is not a follower. Owner can always read; other denied reads return 404.

## Audience and Binary Privacy

Store ACCOUNT for the account-dependent audience and resolve current
user_settings.account_visibility on every read. Thus PUBLIC -> PRIVATE makes
EVERYONE effectively FOLLOWERS and the reverse restores EVERYONE. FRIENDS and
ONLY_ME stay unchanged. Publish locks the author's Settings row to serialize with
privacy updates. No bulk rewrite, new settings flag, or change to V18 follow rules.

All Post originals AND generated JPEG covers use Cloudinary type=authenticated,
including EVERYONE Posts. Reuse the existing MediaService/provider; Place/Moment/
DM uploads keep their existing behavior. Client JSON contains only Spring-relative
paths, never Cloudinary URLs/public IDs. Each media/cover GET validates JWT, current
Post audience, and media membership. Spring streams binary (no redirect), supports
one byte Range (206/416), uses private/no-store/max-age=0, nosniff and no-cache.
Internal provider signed download TTL is 30 seconds. Flutter does not use the
shared NetworkImage cache for Post; local bytes/player are scoped to the mounted
view and cleared on session change/dispose. Existing API base/auth refresh reused.

User explicitly accepted increased Spring bandwidth. Already viewed/downloaded
bytes and a request authorized before a privacy change cannot be retroactively
revoked. Future GETs recheck current rights. Guest sharing is not implemented.

## Persistence and APIs

V19__post_publish.sql adds exactly posts, post_media, hashtags, post_hashtags,
post_user_tags. No V1-V18 edits. posts.id is BIGINT, user/media/upload/request IDs
are UUID, placeId is existing BIGINT. Ordered media, FK links and Post commit in
one transaction. Unique author/clientRequestId prevents duplicate Posts. A retry
with the same key and different normalized payload returns 409.

All routes use /api/v1 and existing authenticated API conventions:

| Method/Path | Contract |
|---|---|
| POST /posts/media | multipart file, uploadId UUID, kind IMAGE/VIDEO; returns mediaId, kind, durationMs, bytes |
| POST /posts | clientRequestId, caption, audience, ordered mediaIds, hashtags, taggedUserIds, optional placeId; 201 detail after commit |
| GET /posts/{id} | id, authorId/name, caption, effective audience, hashtags, taggedUserIds, placeId, ordered media[], createdAt |
| GET /posts/{id}/media/{mediaId} | authorized original stream |
| GET /posts/{id}/media/{mediaId}/thumbnail | authorized JPEG cover |

Media item: id, kind, mimeType, bytes, durationMs, width, height, sortOrder,
url and thumbnailUrl. Relative media paths start /posts, appended to ApiConfig's
existing /api/v1 base. Validation 400/422, unsupported MIME 415, oversize 413,
unauthenticated 401, hidden/foreign media 404, retry conflict 409, provider 503.

## Upload/Retry/Cleanup

Flutter retains the existing picker/camera/crop/trim layout, real User/Place picker,
and loading/error states. Android Media3 Transformer exports a real MP4 with the
selected interval; iOS AVAssetExportSession does the same. Original >60-second
videos cannot bypass export by sending trim metadata. Server inspects actual
magic/MIME/size and ffprobe metadata, then creates a real cover using ffmpeg.

Upload reserves owner/uploadId + content hash before provider calls. Stable asset
IDs and overwrite=false prevent duplicates; successful re-upload of the same
content/key reuses the row. Flutter retains uploaded IDs/exported files per compose
session. Upload failure retains the form; unknown publish ACK freezes the exact
payload/key for retry. Authoritative 4xx unlocks editing. UI success/navigation only
after commit ACK; resulting page is a minimal real read-only detail, not Profile.

Upload failure attempts deletion of both original and cover; deletion failure
retains CLEANUP for retry (log IDs only). Every 15 minutes, reconcile up to 50
cleanup/staging records, abandoning unattached uploads after 24 hours. Row locks
prevent deleting media attached concurrently. Publish rollback leaves READY media
available for retry; discarded exports are removed from local cache on dispose.

## Files and Runtime

- Backend: social/post/{PostDtos,PostRepository,PostService,PostController,
  PostFileInspector,PostMediaService,PostRequestPolicyFilter}.java; protected
  operations added to existing MediaProvider/CloudinaryMediaProvider/MediaService;
  new ProtectedMediaOrigin; Errors upload mapping; application.yml parser ceiling.
- Flutter: posts/data/post_repository.dart, models/post_compose_models.dart,
  screens/create_post_screen.dart, post_detail_screen.dart; protected_post_media,
  audience/hashtag widgets, trim import; AuthService authenticated binary access.
  Preview store only re-exports common types; publish never writes demo state.
- Android: PostVideoExporter.kt, MainActivity registration, Media3 Transformer
  1.9.2 matching existing video_player_android; iOS AppDelegate exporter channel.
  Flutter adds unorm_dart 0.3.3 for the same NFC hashtag identity as Spring.
- Dockerfile installs ffmpeg/ffprobe. Local non-Docker Java needs these on PATH.
  Shared multipart parser allows 100 MB file/101 MB request ceiling; Post enforces
  exact decimal limits, and a filter preserves the legacy 1 MiB per-file ceiling
  outside Post. Provider credentials remain in ignored existing .env, not client.
- Tests: PostPublishApiTest, PlaceApiTest table whitelist, post_publish_test.dart;
  backend/scripts/verify-post-publish.ps1 (isolated test DB/API only).
- Docs: this file, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT, AGENTS history.

## Verification Evidence

Baseline supplied by user: backend 172, Flutter 157, analyze 0 errors/16 warnings.
Focused checks only; no claim that all baseline tests were rerun.

- Docker build with TESTS=PostPublishApiTest,AccountPrivacyApiTest,AccountProfileApiTest,
  SocialRelationshipApiTest,GoogleFlowTest,FirebaseGoogleApiTest,DirectMessageApiTest,
  MomentApiTest,PlaceApiTest: 37 PASS (7 new Post tests), no failure/skip.
  Final image rebuild repeats these 37 tests after the Range edge-case fix;
  backend is running this image on port 8081. Post OpenAPI routes are registered,
  unauthenticated detail returns 401, startup keeps V19 with no extra migration.
- Flutter targeted post/account privacy/auth/notification UI tests: 28 PASS
  (10 new Post tests), final analyze 0 errors/16 old warnings (273 total issues,
  257 info; baseline report 279 total). No new warning.
- Clean PostgreSQL and restored V18 both reach V19/31 tables. Real smoke uses
  synthetic owned PNG/video, ffprobe, Cloudinary authenticated upload: rejects
  62s and invalid PNG; accepts actual 59s trimmed output; persists 12 mixed media
  and final order; upload/publish retry does not duplicate. All audience gates,
  accepted/pending/mutual/stranger checks, privacy switching, thumbnail, unsigned
  provider URL rejection and video Range verified. Restart/re-login repeats gates.
- Test accounts/data/assets are isolated from the user's main DB. Cleanup script
  deletes only assets owned by those fixture users, before fixture DB removal.
- Main database upgraded V18 -> V19 successfully; 31 tables including Flyway.
  All 25 previous business table counts unchanged (38 users/profiles/settings,
  146 Places, 7 Place media, 18 Trips, 1 current follow edge, 2 follow-request
  records). Privacy and follow identity checksums also unchanged. Five new Post
  tables are empty on main: all test publishes were isolated.
- Pre-cutover backups and V1-V18 file hashes are in ignored backups/p1b-pre-v19/:
  database.dump, fresh cutover-v18.dump, app-v18.jar, migration-hashes.csv,
  counts-cutover-before/after.txt, privacy-before/after.txt. No volume reset,
  Flyway repair, or modification of old migrations.
- 56 test-owned original/cover asset deletion operations completed (28 per DB).
  Both temporary APIs, both fixture PostgreSQL DBs and isolated Mongo test DB
  were removed. Root Compose retains api:8081 + postgres + mongo + ai only.
- Final Android debug APK build PASS (131.8s). No installation or physical export
  test was performed in P1B. Rebuild is needed only after changing native code.

## Android Acceptance Pending

Run Flutter again (native exporter added, hot reload is insufficient).

1. Publish one camera/gallery image with Vietnamese/emoji/newline caption,
   a real tagged user and a real Place; verify the saved references.
2. Select/reorder 12 mixed media; verify output detail order and playback/seek.
3. Pick >60s video, select a middle interval, publish, verify actual cut content.
4. Two accounts: PUBLIC/PRIVATE defaults, accepted vs PENDING vs mutual FRIENDS,
   ONLY_ME, repeated privacy changes, original and thumbnail protected.
5. Break network during upload and during commit ACK, retry; form stays and only
   one Post is committed. Restart/re-login and retrieve the saved Post by its ID.

Backend actual-file trimming validation PASS does not prove Android device export
works on every codec. Native Android build is checked; physical camera/export and
iOS build/device remain unverified. Profile grid remains preview until P1C; do not
mistake lack of a real Profile grid for a failed P1B database commit.

## Recovery

If startup fails, stop API writes first and keep PostgreSQL volume. V19 is additive;
prefer fixing forward. The saved V18 JAR is available for recovery; check its
Flyway startup against a separate restored V18 database before any rollback.
Do not repair/rewrite Flyway to conceal a failure. Restore a DB dump into a
separate recovery database and compare before any owner-approved replacement. Do not restore over current data or delete Post assets blindly.
