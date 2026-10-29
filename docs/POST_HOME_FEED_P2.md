# Post Home Feed P2

Updated 2026-10-22. P2 only; P3 Comment/Report, P4 Share/Post Search and DM requests
remain separate. User accepted P1C and explicitly approved BOTH first options:
all Posts the current viewer may read, newest first by created_at DESC, id DESC.
Own ONLY_ME Posts are eligible for the owner. Profile pins never reorder Home.
No AI, popularity score or followed-author priority is introduced.

V21 UI hotfix: `POST_OWNERSHIP_CREATION_PERFORMANCE_HOTFIX.md` documents the
shared P1C ownership menu, Home creation-mode bar and safe Feed scroll optimization.

## API and Permissions

All routes use /api/v1 and JWT-derived identity, existing raw DTO/error conventions:

| API | Result |
|---|---|
| GET /feed?size=20&cursor=... | items[] and nextCursor; size 1-50, no hidden total |
| PUT /posts/{id}/like | Idempotent Like |
| DELETE /posts/{id}/like | Idempotent Unlike |
| PUT /posts/{id}/save | Idempotent Save |
| DELETE /posts/{id}/save | Idempotent Unsave |

Action ACK: postId, likeCount, likedByMe, savedByMe. Existing detail/Profile DTOs
also return likeCount/likedByMe/savedByMe, scoped to the current viewer. No viewerId,
client-supplied count, author or privacy value controls an action. Count is derived
from actual rows, not a mutable counter. No Like/Save notification is created.

ACCOUNT is EVERYONE for a PUBLIC author, FOLLOWERS for PRIVATE. Accepted edges
alone grant FOLLOWERS; FRIENDS requires mutual accepted edges; ONLY_ME requires
ownership. PENDING grants nothing. Deleted/inactive-author Posts are excluded.
Denied detail, interactions and binary reads return controlled 404; unauthenticated
requests return 401. Prior Like/Save rows are retained when access is lost, but
cannot grant access or expose state; eligibility must pass again before reading.

Feed filters permissions in SQL BEFORE keyset/limit. Cursor binds viewer/HOME
scope and the scanned created_at/id; size+1 determines whether another page exists.
A newer insert waits for refresh, rather than shifting the cursor window.
Eligibility changes above the cursor appear on refresh, not retroactively inserted
into earlier pages. No offset paging or hidden Post counts.

Each page uses six bounded JDBC reads: candidates, media, tags, tagged users,
engagements, then fresh eligible rows joined to author/profile/Settings/Place.
The last read prevents serializing revoked rows after batch hydration. No per-Post
profile/media/detail request loop. Inactive Place/user tags are not exposed in Feed.
Cursor advances by the last scanned candidate even if permission changed mid-read;
Home can load the next cursor from an empty raced page without a demo fallback.

Interactions lock author Settings then Post, matching owner/privacy mutation order,
reauthorize, and set/delete the actor's unique row transactionally. Concurrent retries
cannot duplicate rows or inflate counts. Already-authorized in-flight operations
have the same boundary limitation as P1B/P1C; this is not a new realtime revocation system.

## V21

Actual baseline was V20; V21__post_feed_interactions.sql creates ONLY:
- post_likes(post_id, user_id, created_at).
- post_saves(post_id, user_id, created_at).

Both have PRIMARY KEY(post_id,user_id), FK to posts/users and UTC-capable timestamps.
Indexes: ix_post_saves_user(user_id,created_at,post_id),
ix_posts_feed_created(created_at,id). No cascade, Comment, Report, Share or general
interaction table. Old V1-V20 SQL/Java migration hashes are unchanged.
Total business tables 30 -> 32; including Flyway 31 -> 33.

## Flutter and UI Lock

- Home replaces its four Post fixtures with PostRepository/PostFeedController data.
  Existing _FeedPostCard metrics, icons, full-bleed square media, padding, caption,
  dots and heart animation remain. Existing Moment/recommendation/user rails,
  floating header, navigation and Map/Trip logic are not redesigned.
- Lazy ListView.builder, keyset scroll loading, pull-refresh and retry/empty states.
  Keep existing rails after the first/second Post; no fake Posts when API fails.
- ProtectedPostMedia is reused for images/video. Media are never public Cloudinary
  URLs. Tap media uses the existing GoMateProfilePostFeedScreen, not a new viewer.
- PostEngagementController is per mounted card. Optimistic updates wait for ACK,
  prevent overlapping same-kind taps and roll back on failure. Double tap never
  unlikes; reload takes real count and flags from Spring. Same raw Post object is
  not reapplied on unrelated header/Moment rebuilds to erase an acknowledged action.
- The same action controller drives real Profile/viewer Like/Save. Success Save
  snackbars follow ACK, not local/demo mutation. A denied action removes/revalidates
  the card. Like/Save do not broadcast full-list invalidations on every tap.
- Resume, Home tab return, viewer/search/place route return and P1C mutation signals
  refresh current eligibility. Session change clears pages and card state; stale
  ACKs cannot restore another session's content. Retained mounted images are hidden
  while the same view is revalidated, as documented in POST_MEDIA_PERFORMANCE.md.
- AuthService remembers the successful Feed API candidate for protected media,
  just as for Profile; no new URL or network client is hard-coded.
- P3/P4 buttons keep their icons/layout but show unavailable, not fake comments,
  shares, reports or success. Comment count is zero while no Comment domain exists.
  Other modules' legacy previews remain isolated; no demo Post enters Home Feed.
- Save/Unsave persistence is implemented; the separate Settings collection browser
  is NOT connected by this phase. This is not a claim that its existing demo UI is real.

All Post binaries remain authenticated Cloudinary -> Spring access-checked GET,
private/no-store, including covers and video Range. Small server image buffers still
check current permissions before every hit. No trim/upload/30s/legacy-video change.

## Changed Files

Backend social/post: new PostFeedController/Service/Repository; existing PostService
projection, PostDtos viewer fields, PostRequestPolicyFilter Feed headers.
New V21 SQL and PostFeedApiTest; PlaceApiTest's exact schema allowlist adds precisely
the two new tables, not a weakened schema assertion. New scripts/verify-post-feed.ps1.

Flutter: Home screen; MainShell Home active flag; AuthService Feed candidate predicate;
PostRepository; new PostFeedController/PostEngagementController; Profile mapping and
existing viewer callbacks; post_feed_test.dart and Feed candidate test in
post_publish_test.dart. No package, .env, native configuration or media schema change.
Docs: this report, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT, AGENTS and P1C pointer.

## Verification and Cutover

- Current pre-P2 targeted baseline after the media/gallery fixes: 47 backend and
  40 Flutter tests. The older task-file baseline 41/35 was not assumed current.
- Final focused Docker Maven build: 53 PASS (+6 P2 tests), no failures/errors.
  Includes P1A/P1B/P1C/Auth/Profile/Relationship/Google/Firebase/Moment/DM/Place and
  image-buffer checks. Expected isolated Mongo connection warnings remain; this
  is not a new live Mongo end-to-end test of the unrelated DM/Moment modules.
- Flutter focused suite: 47 PASS (+6 Feed/action cases and one network-candidate case).
  Existing Profile real/demo card pixel equality still passes. Home tests exercise
  real data/card actions/viewer/error retry and empty-page cursor continuation.
  Home before/after pixel-perfect device screenshots were NOT taken or fabricated.
- Analyze: 0 errors, 15 existing warnings (one old unused placeId warning disappears
  when real Place data is mapped); no new warning. APK debug build PASS.
- Actual PostgreSQL clean V1->V21 and restored V20->V21 startup both PASS. Compared
  ALL old business-table row counts before fixture insertion: no change on upgrade.
- Both isolated APIs pass HTTP checks before AND after restart/re-login: global
  newest Feed, cursor/cross-viewer rejection, concurrent/idempotent Like/Save,
  user-scoped flags, no action notifications, PUBLIC/PRIVATE/PENDING/accepted/
  mutual/ONLY_ME, unfollow, audience edit, tombstone and protected media denial.
  These are isolated metadata fixtures; no Cloudinary asset was uploaded/deleted.
- Main API rebuilt/restarted on 8081; V21 applied successfully. Current retained
  Posts/media 7/12 before and after; users/Places/Trips 38/146/18. ALL old business
  table counts match the fresh cutover snapshot. New likes/saves initially 0/0.
  No fixture users/Posts/interactions were inserted into the main database.
- Backups/JAR/hash lists/logs/count snapshots/token fixtures stay in ignored
  backups/p2-pre-v21/. Prefer fixing forward; never repair/reset volumes or restore
  over current data blindly. Validate any backup recovery in isolation first.
- The two temporary P2 APIs, PostgreSQL fixture DBs and scoped Mongo test DB were
  removed. Only the existing root Compose services remain; no Docker volume reset.

## Device Acceptance

Run Flutter again using the existing run configuration; APK was not auto-installed.
Use two accounts to check PUBLIC/PRIVATE, pending/accepted/mutual and ONLY_ME; scroll,
pull-refresh, repeated Like/double tap/Unlike and Save/Unsave, login again; edit
audience/privacy/delete then reopen Home; network loss must show retry, not demos.
Verify mixed media, 30s new videos, seek/Range and an owned legacy >30s video if
available, and confirm Home layout on the actual phone. Automated tests are not a
claim of completing those physical-device cases. Stop here; do not start P3/P4.
