# Home Feed: Bounded Mounted-View Retention

Historical approach. The Android-measured Home hotfix in
`HOME_FEED_MEDIA_LIFECYCLE_FIX.md` supersedes tile-owned media retention below.
Keep-alive now retains lightweight card state only; actual media belongs to Home.

Date: 2026-10-23. Performance follow-up only. No new API, database change,
migration, audience change, Post lifecycle or visual redesign.

## Cause

Stable IDs alone do not preserve lazy ListView children after they scroll outside
its viewport/cache. Home disposed those Post widgets; ProtectedPostMedia correctly
evicted their private bytes and disposed the player. Scrolling A -> B -> A then
created a new widget, binary GET/decode or video initialization for A. This was
unnecessary churn inside the same Home view, not a requirement of server privacy.

## Approach

- Keep original mounted Post widgets in the current Home view with Flutter's
  AutomaticKeepAlive mechanism. No global/private binary cache, disk cache,
  provider URL exposure or changed HTTP no-store policy.
- PostViewRetention contains ONLY widget admission/cost metadata, never Post
  contents, image bytes, tokens or permissions. Widget State remains the owner
  of private bytes and decoder, and its existing dispose/clear still runs.
- Retention admission is bounded to six Post slots, estimated 64 MiB of image
  source+decoded allocations and at most two video entries. Older admitted slots
  are released when a limit is exceeded. Large albums may not be retained.
  This is a retention budget, NOT an exact cap on total process/native/GPU RAM:
  visible/preload widgets and platform decoder buffers also consume memory.
- Image estimates use DTO bytes/dimensions and physical display width. Video
  native allocations use a fixed planning estimate, not the whole file size.
- Handle memory-pressure signals by releasing offscreen retention. Never retain
  every paginated Post indefinitely or increase the global Flutter image cache.
- Admission/eviction settles after layout before requesting keep-alive handles,
  avoiding Flutter parent-data races when several videos enter in one frame.
- The small prebuild window is 0.75 viewport height, clamped to 400-800 logical px,
  rather than building/loading the whole feed. This starts nearby media earlier.
- Retained videos pause when fully outside the scrolling viewport, when Home is
  inactive, when another route disables TickerMode or during revalidation/app
  inactivity. Scrolling back does not auto-play. Other media pages are inactive.
  Playing-video position checks are coalesced to one callback per frame; paused
  videos/images do not measure layout on every scroll tick.
- Keep the previous hard-edge square media clip, full-bleed fit, controls, Like,
  Save, pagination, Profile pin sorting and creation-mode selector unchanged.

## Privacy Boundaries

- Scrolling alone no longer destroys/reloads admitted media or refetches Feed.
- Existing refresh boundaries stay: pull-refresh, tab/route return, app resume,
  account/profile change and committed Post mutation signals.
- During revalidation ALL retained Posts, including offscreen ones, stay hidden.
  Reveal only after a fresh eligible list ACK. Missing/revoked/deleted items and
  failed refreshes dispose retained widgets, clearing their image/player state.
- Logout/user switch clears Feed rows immediately; stale ACKs cannot restore
  another user's content. Home disposal releases its retention scope.
- Every NEW binary request still uses Spring JWT + current authorization and
  private/no-store. No TTL or cached permission decision bypasses the backend.
- Media already authorized and displayed cannot be recalled remotely. Remote
  revocation is discovered at existing refresh boundaries, not through a new
  Post realtime subsystem. This limitation is unchanged from P1B/P1C.

## Files

- New lib/features/posts/data/post_view_retention.dart: bounded admission metadata.
- lib/features/home/screens/home_screen.dart: keep-alive slots, bounded prebuild,
  memory-pressure release and active flags. No lazy-list/sort API redesign.
- lib/features/posts/widgets/protected_post_media.dart: pause retained players
  offscreen/inactive; keep the same authenticated loading and disposal path.
- New test/post_view_retention_test.dart: real scrolling/download counts,
  retention bounds, refresh failure/revocation/logout and player lifecycle.
- pubspec.yaml/pubspec.lock: declare the ALREADY resolved version 6.9.0 of
  video_player_platform_interface as a dev dependency for the fake decoder test.
  Offline pub get changed only its dependency classification; no package version
  or runtime plugin was upgraded, no new runtime cache/state package was added.
- This note and pointers in CODEX_INDEX.md / POST_MEDIA_PERFORMANCE.md.

## Evidence And Device Check

The focused scrolling test visits five image Posts, scrolls down/up repeatedly
and records exactly five binary GETs and one Feed request. The same mounted State
instances survive; no extra requests occur merely on return scrolling.

Final focused Flutter regression: 73 PASS (65 preceding Post/creation/clipping/
Auth/privacy/notification UI cases + eight retention/player cases). Full analyze
reports 0 errors, 15 existing warnings and 265 existing infos. No new warning.
Offline pub get PASS with only the dev-dependency classification change above.
Final Android debug APK build PASS (87.4s), using the final vertical-viewport
video pause fix. No APK installation or device restart was performed.
Maven was not rerun because no backend/DTO/API/schema code changed. No test user,
Post, DB row or Cloudinary asset was created/deleted in the live environment.
Logs: ignored backups/p2-pre-v21/feed-retention-final-tests.log and
feed-retention-release-analyze.log. The initial retention test caught an async
cleanup timing issue in its fake player; the final tests wait for disposal.

Additional tests exercise weighted eviction, long-feed bounds, hidden offscreen
tiles while ACK is pending, removal on empty/failed validation and logout. A fake
native player verifies one decoder survives scrolling, pauses when outside the
vertical viewport/tab even inside a horizontal carousel, and is disposed when
Home closes. Native throughput/FPS on the real
phone is not measured by these tests.

Hot Restart (not only Hot Reload) the existing Flutter run so new retention and
scroll listeners initialize. Visit 4-5 Posts, scroll back repeatedly, try Like/Save,
play a video then scroll away/back, switch tabs, pull-refresh, delete a test Post,
change privacy from a second account, and logout/login. Check that denied Posts
disappear after refresh and videos do not keep playing out of view.

Cold media, streaming/seek, evicted entries, oversized albums, more than two
retained videos, memory pressure or a disposed Home can still need loading.
The goal is bounded reuse in one view, not infinite/offline caching or a promise
of zero network latency. Backend, Docker, DB and Cloudinary were not modified.


## P3 Video Follow-up (2026-10-23)

POST_COMMENT_REPORT_P3.md supersedes the video-cost part of this note. Retain cover
widgets separately from max TWO native decoders in a view-scoped PostVideoPool.
Prewarm only visible videos with spare capacity, retain position on decoder eviction,
and release on memory pressure/session/dispose. Widget budget remains 6 Posts /64 MiB
estimated images, plus the separately bounded native budget. Every fresh binary
request remains JWT/access checked through Spring; no disk/global private cache.
