# Settings Post Activity (2026-10-23)

Scope: the supplied P4 Settings addendum only. Do not infer Share/Search or a
new phase from this addendum; those production flows are still deferred.

## Flow and UI Lock

- Settings -> Hoat dong cua ban -> Likes, Post tab; own Comments; Saved now
  read PostgreSQL through Spring. No production Post activity uses SettingsUiDemo.
- Keep menu labels, Place/Post tabs, copy manage icon, grid proportions, round
  selectors, two-level comment rows and gradient action button unchanged.
- Likes and Saved open exactly one Post by numeric Post ID in the shared P1C
  remote viewer. Comments open that same Post and existing Comment sheet once,
  only after authorized detail ACK. Exact-comment scrolling is NOT supported by
  the existing viewer and is not invented here.
- Comment upper row is a reference only; only the lower OWN comment is selected.
  Existing P3 deletion remains: own root hides its thread; own reply hides only
  itself. Never delete the referenced parent or unrelated comments/Post.
- Individual existing mutation APIs are reused. Successful items are removed on
  ACK; failed items stay selected/are reported separately. No fake batch success.
- Like Place and Reviews stay their pre-existing UI preview flows, not real Post
  activity or Place bookmarks. The shared demo files remain for out-of-scope UI.
  Existing P3 Report history is not reimplemented.

## API and Data

All routes require JWT and have private/no-store response headers:

| GET /api/v1/me/... | Source / order |
|---|---|
| liked-posts?size=20&cursor= | post_likes created_at DESC, post_id DESC |
| saved-posts?size=20&cursor= | post_saves created_at DESC, post_id DESC |
| comments?size=20&cursor= | own visible comments created_at DESC, id DESC |

Pages: items + nextCursor, size 1..50, cursor bound to JWT user AND list kind.
Post items contain post (existing Detail DTO), likedAt/savedAt. Comment items
contain post, commentId/postId/parentCommentId, body/createdAt, own author/avatar
and parent reference body/author/avatar. These are views, not a new data table.
Only protected /posts/{id}/media/... paths are returned, never Cloudinary URLs.

Eligibility is filtered BEFORE LIMIT using the same P2 visibility predicate,
then PostService authorization is rechecked before projection. Deleted/inactive
Posts, hidden/deleted comment roots, ONLY_ME/FRIENDS/ACCOUNT access loss and
PENDING follow requests cannot leak captions/previews. Unavailable rows are
hidden; a stale click uses the existing controlled-unavailable viewer state.

Actual predecessor was V22, verified on PostgreSQL. V23 adds ONLY:
- ix_post_likes_user_created(user_id,created_at,post_id)
- ix_comments_user_created(user_id,created_at,id)

Saved reuses its V21 user index. No tables, business columns, stored counters or
legacy migration were changed. Still 36 business tables / 37 including Flyway.
New activity timestamps are projected explicitly in UTC: the shared Db converts
JDBC Timestamp through JVM local time, which otherwise duplicates keyset pages
on a Vietnam-timezone host. No global Db/Auth/Trip timestamp refactor was made.

## Synchronization and Media

- PostInteractionChanges is a non-replaying, transient ACK stream scoped by
  AuthService identity + actor. It stores no Posts, permissions or media bytes.
- Like/Save ACK patches existing Home metadata, Profile previews and mounted
  engagement controllers. It does not trigger full Feed/Profile requests,
  dispose Home media, add timers, SSE or push.
- Comment deletion reconciles only the changed Post through existing PostChanges;
  the comment sheet keeps P3 semantics and its first-character focus hotfix.
- Activity refreshes on entry, viewer return, mutation ACK, permission signals,
  app resume and pull-refresh. Cursor pages dedupe IDs. A pre-mutation page cannot
  resurrect removed items. Account switch/logout invalidates old requests,
  selections and view-owned protected bytes; no cross-account/public cache.

## Verification

- 63 focused backend tests PASS: activity (6), P1A/Profile/Auth/relationship,
  Google/Firebase and P1B/P2/P3; Maven verification also run in Vietnam timezone.
- 91 focused Flutter tests PASS, including 11 new activity cases: source/IDs,
  two-way ACK with zero Feed/Detail reloads for Like/Save, partial batch failure,
  comment deletion/count, cursor retry/dedupe, old-response race, logout/B account,
  failed revalidation, unchanged Place tab and two-level selection/navigation.
  A real Home widget regression additionally retains the same mounted media
  instance with ZERO new binary/Feed requests after a Settings Unlike ACK.
- Full analyze: 0 errors, 15 pre-existing warnings + 298 info, unchanged from
  prior 313 diagnostics. Nonzero analyzer exit is existing lint debt, not clean PASS.
- Real PostgreSQL clean V1->V23 and restored V22->V23 both start/validate. Before
  fixture insertion, all 36 upgraded business-table counts match the V22 snapshot.
  HTTP tests and restart/relogin pass on BOTH isolated databases; script:
  backend/scripts/verify-post-activity.ps1 (guarded localhost/test DBs only).
- Only isolated test databases receive artificial test users/media metadata;
  no actual Cloudinary request/upload/delete is used for those fixtures.
- Backups/logs/test credentials remain ignored under backups/post-activity/.
  Fix forward on failure; do not repair Flyway/reset volumes/restore live data
  without a specific recovery decision. The old JAR and DB dump are retained.
- Final root Docker Compose build PASS (37 repeated focused tests). Main API
  upgraded V22->V23 after a frozen backup. All 36 live business-table counts match:
  users=38, posts=7, post_media=12, post_likes=2, post_saves=1, comments=5.
  No production fixture inserted. All three new APIs reject no-JWT requests (401).
- Debug APK build PASS (149.7 seconds), build/app/outputs/flutter-apk/app-debug.apk;
  not installed. Both temporary APIs and PostgreSQL/Mongo databases were removed;
  only standard api/postgres/mongo/ai containers remain. No volume reset.

## Main Files

- Backend: social/post/PostActivity{Repository,Service,Controller}.java,
  PostRequestPolicyFilter.java; V23__post_activity_indexes.sql;
  PostActivityApiTest.java; scripts/verify-post-activity.ps1.
- Flutter: posts/data/post_activity_controller.dart + post_interaction_changes.dart;
  existing PostRepository/Engagement/Feed/Profile controllers and CommentRepository;
  settings_collection_screen.dart, shared profile_post_feed_screen.dart,
  comment_sheet_content.dart; test/post_activity_test.dart.
- Knowledge: this file, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT and AGENTS.

## Manual Android Acceptance (Not Claimed PASS)

1. A Like/Save/comment/reply B's Post. Each Settings list shows correct own data;
   B cannot see A's activity. Open each item: correct single Post, Comments open.
2. Unlike/Unsave in Home -> reopen/refresh Settings; manage removal in Settings
   -> Home/Profile counters/icons agree, original Post remains.
3. Select own root/reply lower row; verify upper reference has no selector and
   P3 thread/count deletion stays correct. Try multiple selections/network loss.
4. Privacy/unfollow/ONLY_ME/deletion while a list is open -> refresh/click safely
   hides/denies old content. Logout/login B has no A previews or pending selections.
5. Scroll media, open Settings and return: Home images/video retention stays
   smooth; Report and Place Like tab keep their existing behavior.
