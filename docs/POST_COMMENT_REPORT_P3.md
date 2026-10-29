# Post Comment and Report P3

Updated 2026-10-23. P3 only; no P4, moderation workflow or new notifications.
User approved 2,000 grapheme characters/comment and 1,000/report description.
Post commentCount means ALL visible roots + replies, not just root threads.

## Existing Source and Scope

- Actual PostgreSQL was V21, 32 business tables, 7 Posts / 12 Post media.
  There were no Comment/Report tables to migrate or replace. The generic reports
  outline in DATABASE_CONTRACT was a future roadmap, not an existing module.
- Keep P2 newest-first Feed, P1C Profile pin/audience/delete, 30s NEW videos and
  readable legacy videos. No Auth, Follow, Moments, DM, Trip or Map logic change.
- Existing CommentSheetContent, composer, avatar, reply disclosure, owner long
  press delete, PostActionContent, ReportReasonContent, GoMateBottomSheet and
  GoMateSnackBar are reused. No card/layout/menu redesign.
- Missing Report submit/description and durable history are added in the same
  GoMate form. The reason list previously only returned a local enum; it did not
  actually submit. Settings -> Activity -> Reported now reads real history.

## Schema V22

V22__post_comments_reports.sql adds ONLY:
- comments: BIGINT identity, Post/user FK, request key/hash, root parent FK bound
  to SAME Post, reply target user, content, publication/moderation flags, timestamps.
- comment_likes: unique (comment_id,user_id), FK, timestamp.
- comment_media: separate UUID upload/owner/Post association, hash/state, protected
  original/cover IDs, metadata, order, created/cleaned timestamps. Composite FK
  binds an attached image to the SAME Comment owner and Post; order is 0..5.
- post_reports: UUID, reporter/Post FK, request key/hash, exact six reason codes,
  optional details, PENDING and timestamps. No generic multi-domain report API.

Unique request keys are per actor; media/order and FK constraints prevent reuse
or cross-owner attachment. Indexes cover Post/thread paging, staging cleanup and
reporter history. V1-V21 remain unchanged; no existing table/counter is rewritten.
There are 36 business tables, 37 including Flyway after V22.

## API

All under /api/v1, existing raw DTO/error convention, JWT identity and no-store:

| API | Behavior |
|---|---|
| GET /posts/{id}/comments?size=20&cursor= | Roots, newest ID first |
| GET /comments/{id}/replies?size=20&cursor= | Root's visible replies, oldest ID first |
| POST /posts/{id}/comments | clientRequestId, body, nullable parentId, mediaIds[] |
| POST /posts/{id}/comments/media | Multipart file + stable UUID uploadId |
| GET /comments/{id}/media/{mediaId}[/thumbnail] | Protected image, fresh access check |
| PUT /comments/{id}/like | Idempotent Like, current Comment ACK |
| DELETE /comments/{id}/like | Idempotent Unlike, current Comment ACK |
| DELETE /comments/{id} | Own-only 204; root logically deletes its thread |
| POST /posts/{id}/reports | clientRequestId, reasonCode, optional description |
| GET /me/reports?size=20&cursor= | Own reports only, newest timestamp/UUID first |
| GET /me/reports/{id} | Own durable report, even if Post visibility later changes |

Pages return items/nextCursor; size 1..50. Cursors bind actor + Post/root or
reporter scope. Comment DTO: commentId/id, postId, userId/userName/avatarUrl, body,
parentCommentId/replyToUserId/replyToUserName, media[], createdAt, replyCount,
likeCount/likedByMe/isMine. Provider public IDs/URLs never enter these DTOs.

## Rules and Failure Handling

- Reuse PostService authorization: ACCOUNT follows CURRENT server privacy,
  accepted FOLLOWERS only, mutual FRIENDS, owner ONLY_ME. Pending/tag/reply target
  grants nothing. Deleted Post/root denies comments, replies and original/cover.
- Reply to reply is flattened to its root and retains the intended reply user.
  No automatic follow/tag/DM grant or comment/reply/report notification.
- Own root deletion hides its entire thread; own reply deletion affects only it.
  Post owner cannot delete someone else's Comment. No Comment edit endpoint.
- Count is a SQL projection of visible Comment rows for Feed/Detail/Profile.
  No increment/decrement counter to race or become negative. Feed remains batched;
  Comment page images and final visible IDs are batch reads, not one call per row.
- Writes lock author's Settings then Post, matching current privacy/ownership
  transaction order. Likes are unique/idempotent; retry keys compare payload hash.
- Text only, 1..6 images only, or both; no empty submission or video. Same approved
  10 MB image limit and PostFileInspector MIME/content/ffprobe validation.
- Separate CommentMediaService reuses MediaService, Cloudinary adapter, inspector,
  protected origin and bounded image buffer. It never attaches Post media rows.
- Original + cover are authenticated Cloudinary resources. Spring checks Comment
  and Post BEFORE each buffer hit. No public URL/client binary disk/global cache.
- Staging retries keep IDs; provider/DB failure attempts cleanup. Failed cleanup
  persists for reconciliation. Staging older than 24h and deleted Comment/Post
  media are retried every 15 minutes in bounded batches of 50. No other module's
  assets are selected. Uncertain create ACK retries the immutable prior draft;
  composer/media edits are held until that ACK resolves. API failure keeps draft.
- Report reasons: NEGATIVE_OR_VIOLENCE, NUDITY_OR_INAPPROPRIATE, SCAM_OR_SPAM,
  PROHIBITED_GOODS, FALSE_INFORMATION, INTELLECTUAL_PROPERTY. Non-owner + current
  Post access required. One submission retry is deduplicated, not all future reports.
- Reports remain PENDING. No automatic purge/retention deadline, assignment,
  moderation, Post hiding, penalties or push is invented in this phase.

## Video Follow-up Before P3

- Native video decoder allocations previously consumed the same retention budget
  as Post widgets. Revisiting evicted cards reinitialized video with a blank spinner.
- Home now retains protected covers/metadata separately, still max 6 Posts / 64 MiB
  estimated image budget. A view-owned PostVideoPool keeps max TWO native players.
- Prewarm only an on-screen video with a free slot, never evict a played decoder
  merely to preload an unseen Post. Scroll/tab/background/carousel pauses playback.
- Revisiting retained video reuses its player. Decoder eviction keeps its cover and
  playback position; a later explicit play reauthorizes/reinitializes and seeks back.
  Memory pressure clears decoders and retention. No autoplay behavior is added.
- Home/Profile viewer show the existing protected cover while preparing, rather
  than blocking the entire media frame on native initialization. First play still
  depends on network/device; there is no claim that buffering is eliminated.
- Post proxy, Range/seek, no-store, privacy revalidation and immutable binary paths
  are unchanged. No native dependency, provider transformation or media rewrite.

## Verification

- Focused Maven: 61 PASS, including 8 P3 tests + existing Post/P1A/Auth/Profile/
  Relationship/Google/Firebase/Moment/DM/Place/image-buffer tests. This is NOT the
  full backend suite. Mocked provider/origin tests do not claim real Cloudinary QA.
- Final focused Flutter run: 81 PASS, including six-image upload reuse after lost
  ACK and report-history/detail clearing on logout. Full analyze: 0 errors,
  15 existing warnings, 294 informational style diagnostics; no new warning.
- Actual PostgreSQL clean V1->V22 and restored V21->V22 start successfully. ALL
  32 old business-table counts match before/after upgrade BEFORE fixture insertion.
- Isolated HTTP + restart/re-login on BOTH databases verifies root/reply flattening,
  request retry, Like, Feed/Detail/Profile count, own delete permission, PRIVATE
  PENDING/accepted access, audience denial, report ownership/retry/history/persistence.
- Tests use scoped fixture DBs/containers and no real Cloudinary upload/delete.
  Logs/backups/token fixtures stay under ignored backups/p3-pre-v22/.
- Root docker compose build api: PASS with 13 tests (8 P3 + 5 image buffer).
- Main API 8081 upgraded to V22 successfully. All 32 old business-table counts
  match the frozen cutover snapshot. users=38, posts=7, post_media=12, post_likes=1,
  post_saves=0 before/after; all four new tables initially empty. No test fixture
  was inserted into the application DB. Unauthenticated API remains protected (401).
- Both temporary APIs and scoped PostgreSQL/Mongo test DBs were removed. Only
  the normal api/postgres/mongo/ai Compose containers remain; no volume reset.
- Backups: ignored backups/p3-pre-v22/gomate-cutover.dump, api-v21.jar and old
  image ID, row counts, logs. Historical migration hash snapshot (20 SQL/Java
  artifacts) matches; restored Flyway validation additionally checks old checksums.
- Rollback: stop affected API, inspect Flyway/transaction logs; prefer fix-forward.
  PostgreSQL transactional DDL rolls back failed migration DDL. Do not run repair,
  delete history, reset volume or overwrite live data automatically. Validate the
  saved dump with old JAR in isolation first; restoring the live DB loses writes
  since that backup and requires an explicit recovery decision.
- Final Android debug APK build PASS (127.6s) at
  build/app/outputs/flutter-apk/app-debug.apk. Not installed, per user choice.
  Physical Android tests and actual-device video latency/Cloudinary Comment upload
  remain owner verification, not an automated PASS claim.

## Comment Keyboard Focus Hotfix (2026-10-23)

- Reproduced for both new comments and replies: the first nonblank character
  hides the leading camera button/gap. The unkeyed Expanded holding TextField
  changes sibling position, so Flutter disposes EditableTextState and detaches
  its IME connection. A persistent FocusNode alone does not prevent this.
- Add a stable local ValueKey to that Expanded in comment_sheet_content.dart.
  Keep the existing layout, media-button visibility and submit/reply rules.
  Home and Profile already share this composer; no separate implementation.
- Two modal-sheet regression tests FAIL before the fix and PASS after it.
  They use IME editing updates without enterText/refocusing; assert identical
  EditableTextState, visible keyboard, focus and draft through first character,
  clearing/retyping, keyboard insets and two consecutive root/reply submissions.
- Focused Flutter regression: 41 PASS across post_comment_report_test,
  post_feed_test, profile_posts_test, home_media_lifecycle_test and
  post_view_retention_test. No backend/API/DB/migration/config/dependency change.
- Full flutter analyze completed with the existing 313 diagnostics (nonzero
  exit due to warnings/lints; not a lint-clean PASS). Debug APK build PASS
  (105.4 seconds): build/app/outputs/flutter-apk/app-debug.apk. Not installed.
- Actual Android keyboard acceptance remains manual: fresh comment/reply should
  accept continuous typing after one tap, including the next draft after send.
  Do not claim a physical-device PASS from widget tests.

## Android Acceptance (Owner Runs, Not Yet Claimed PASS)

Build APK only, per user choice; do not install/restart the phone automatically.
1. Play both existing videos, scroll away/back; compare spinner/replay behavior,
   seek, carousel, tab switch, background and rotation without overflow/audio leaks.
2. Two users: text-only/image-only/combo, camera/gallery, up to 6 images, remove X,
   text hides new-media buttons but existing previews stay. Check retry on network loss.
3. Root/reply/reply-to-reply, collapsed replies/load more, like/unlike, own long
   press delete; deleting root hides all thread media. Compare Home/Profile counts.
4. Change privacy/audience/unfollow/delete and reopen or interact: access must be
   denied. Pending requests must not grant access. Switch accounts without drafts.
5. Non-owner Report -> choose reason -> optional text -> Send; success only after
   ACK -> View reports. Check Settings history; own Post must never offer Report.

Stop after P3. Share/Search/Not Interested/Admin/Global Block remain deferred.

## Important Files

Backend additions: social/comment/{CommentDtos,CommentRepository,CommentService,
CommentMediaService,CommentController}.java; social/report/{PostReportRepository,
PostReportService,PostReportController}.java; V22 SQL; PostCommentReportApiTest;
scripts/verify-post-comments-reports.ps1.
Backend wiring: PostDtos/PostService/PostFeedRepository (derived commentCount),
PostRequestPolicyFilter, public reuse of PostImageBuffer.open/Loader, PlaceApiTest
exact schema allowlist. No pom/config/credential dependency change.
Flutter additions: comment_repository.dart, post_video_pool.dart, post_session_gate.dart,
post_reports_screen.dart, test/post_comment_report_test.dart. Wiring in existing Home,
Profile viewer/mapping, Comment/Report widgets/models, PostMenuActions/PostRepository,
ProtectedPostMedia/retention, Settings report entry and AuthService media path allowlist.
Existing retention and ownership menu tests updated for now-real Report functionality.
Docs: CODEX_INDEX/PROJECT_CONTRACT/DATABASE_CONTRACT/HOME_FEED_VIEW_RETENTION and AGENTS.
