# Post/Profile Media Performance

Home lifecycle update: see `HOME_FEED_MEDIA_LIFECYCLE_FIX.md`. Its Home-owned
decoded-image/native-player store supersedes the older mounted-tile strategy;
Profile/comment/viewer ownership described here is unchanged by that hotfix.

Updated: 2026-10-22. Performance-only follow-up to P1C; no schema, migration,
new endpoint, dependency, audience rule or visual redesign.

Latest Home-specific follow-up: `HOME_FEED_VIEW_RETENTION.md`. It bounds the
retention of original mounted lazy-list widgets during scrolling; no global or
disk private media cache is introduced. The P1C notes below remain historical.

## Cause

Profile tab return calls loadProfile. Its Auth notification refreshes Post pages.
Previously every refresh emptied the grid immediately, disposed all mounted
ProtectedPostMedia states and forced another full protected binary GET per tile.
PublicProfile also replaced its whole body with a spinner during profile reads.
Spring then fetched the same authenticated Cloudinary image again on each GET.

## Changes

- ProfilePostsController retains only its current view's tiles while revalidating
  the same viewer/author. `revalidating` is a mandatory display gate, not permission.
- Both Profile grids use stable Post keys and SliverVisibility with state retained
  but painting, hit-testing and semantics disabled during revalidation. Only a fresh
  authorized list ACK can reveal retained tiles. Empty/failed refresh removes them.
  Paging retains its existing retry behavior; a fresh list replaces old pages.
- PublicProfile retains its mounted body, hidden while its profile request runs.
  Route return and pull-refresh start Post revalidation before awaiting Profile.
- Logout/viewer change/author change clear immediately; stale request ACKs cannot
  restore the previous viewer's content. Disposed ProtectedPostMedia still evicts
  its bytes. No global Flutter binary cache, disk cache or offline Post access.
- PostImageBuffer is Spring-only, binary-only RAM. Controller MUST authorize the
  current JWT viewer from PostgreSQL and validate the media attachment BEFORE
  every lookup. It never caches permission decisions, Post JSON or JWTs.
- Non-Range image/cover requests reuse immutable media-ID/variant/provider-ID bytes.
  Max 2 MiB per image, 32 MiB stored total, 128 entries, LRU, two-minute reuse TTL.
  Expired entries are removed on the next lookup. Restart empties it; no disk writes.
  Sixteen fixed locks coalesce same-key concurrent misses without unbounded maps.
  Large images, partial bodies, Range and original videos bypass the buffer.
  Truncated/failed reads are never stored. Cloudinary assets are not rewritten.

## Privacy Invariants

All originals/covers remain authenticated Cloudinary assets. Flutter receives only
Spring-relative paths; every new binary GET still rechecks current permissions,
even on a warm server buffer hit. Cache-Control remains private/no-store/max-age=0,
Pragma no-cache and video Range/seek remain unchanged. No signed provider URL is
exposed. Delete/privacy/audience changes do not wait for the binary buffer TTL:
denied requests stop before lookup. Already displayed/downloaded pixels cannot be
recalled; remote changes are discovered at the same P1C refresh boundaries.

Retaining already-mounted hidden image state is not an HTTP-cache shortcut: the
list is reauthorized before revealing it. Any future consumer of controller.items
MUST honor revalidating. Currently only the two guarded Profile grids consume it.
Do not relax this gate to show old content while waiting for a server response.

## Files

- lib/features/posts/data/profile_posts_controller.dart
- lib/features/profile/screens/profile_screen.dart
- lib/features/profile/screens/public_profile_screen.dart
- backend/src/main/java/vn/gomate/social/post/PostImageBuffer.java (new)
- backend/src/main/java/vn/gomate/social/post/PostController.java
- test/profile_posts_test.dart
- backend/src/test/java/vn/gomate/PostPublishApiTest.java
- backend/src/test/java/vn/gomate/social/post/PostImageBufferTest.java (new)
- This note, CODEX_INDEX.md and current PROFILE_POST_P1C.md pointer.

## Verification

- Flutter targeted suite: 37 PASS, including retained widget identity, no extra
  image GET after fresh list ACK, hidden pending state, failed validation removal,
  logout/stale-response isolation and existing real/demo card pixel comparison.
- Backend targeted suite: 47 PASS (Post + direct Auth/Profile/Relationship/Moment/
  DM/Place regressions and five buffer tests). Warm original+cover reads fetch the
  mocked origin twice total for four binary GETs. Privacy/pending-follow/ONLY_ME/
  deletion and unauthenticated requests still deny access while bytes are warm.
- Buffer tests cover expiry, variant isolation, concurrent misses, failed/truncated
  sources, large/partial bypass and byte/entry LRU limits.
- Analyze: 0 errors / 16 existing warnings (280 total issues, mostly old infos).
- Android debug APK build PASS (148.2s). APK was not installed automatically.
- Root Compose API rebuilt and restarted successfully on port 8081; unauthenticated
  protected media GET still returns 401. Flyway reports current version 20 and no
  migration necessary. Successful history remains V1-V20; measured Post/media rows
  before and after restart stay 5/10. Only the existing four Compose services run.
- These are focused tests, not a rerun of every unrelated module or a device
  latency/FPS benchmark. No fixture account, Post or Cloudinary asset was created
  in the user's running database by this task.

## Device Check

Restart Flutter using the existing run configuration. Open Profile once, switch
tabs several times and return: unchanged mounted covers should not redownload.
Open/close a Post, pull-refresh, pin/reorder/delete; verify the current grid truth.
Use a second account to change audience/privacy, return to Profile and verify
denied Posts disappear; logout/login must not reveal the previous user's image.
Check slow/unreachable API: no stale private content should remain visible.

Initial cold downloads, images larger than 2 MiB, actual video streaming, expired
server buffers and disposed/scrolled-out tiles can still load. Lightweight permission
revalidation still takes network time. Do not promise zero waiting or device speedup
percentages without measuring on the actual connection/device.
