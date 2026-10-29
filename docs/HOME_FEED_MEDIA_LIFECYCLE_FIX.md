> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Home Feed Media Lifecycle Hotfix

Date: 2026-10-23. Existing Home/P1A-P3 only; Android 13 / Samsung SM-N770F.
No Feed algorithm, UI redesign, backend behavior or migration changes.

## 1. Evidence And Files

Diagnostic-only APK: returning to the same video ID correlates with Dart player
disposal, ExoPlayer Release/Init and fresh Range requests. Post 6 alone had 16
ranges / 18,427,217 response bytes during the scrolling observation. A Range is
NOT necessarily a full-file download. User saw an immediate cover but delayed,
restarted playback. This is a native resource lifecycle issue, not just a spinner.

The old admission cost counted ALL source/decoded media in a Post, including
unseen album pages. Logs show repeated eviction at 72,794,422 estimated bytes,
only five cards, against a 64 MiB budget. Evicting a card destroyed its real image
and player. Small keep-alive fixtures did not prove native resources survived.
Separately, short tab returns/unchanged self-Profile notifications refreshed Feed.

Implementation files:
- `lib/features/posts/data/home_post_media_store.dart`: Home/session resource owner.
- `lib/features/posts/widgets/retained_home_post_media.dart`: disposable view lease.
- `protected_post_media.dart`: optional Home owner; existing other callers unchanged.
- `post_feed_controller.dart`: metadata TTL/dedupe, scoped reconcile, ACK counters.
- `home_screen.dart`: route/tab/app pause, memory pressure and lightweight card state.
- `post_repository.dart`, `post_engagement_controller.dart`, Profile Post viewer:
  scoped Post changes, not entire-Feed/binary reload on counters.
- `lib/core/services/content_access_changes.dart`, Search/follow-request repositories:
  successful LOCAL relationship mutations trigger server eligibility revalidation.
- `lib/core/diagnostics/post_media_diagnostics.dart`, AuthService diagnostic hooks;
  `scripts/diagnostics/post-media-proxy.cjs`: opt-in measurements, no auth bypass.
- Focused lifecycle/ownership/Feed fixtures; new `test/home_media_lifecycle_test.dart`.

## 2. Solution And Limits

- Home owns decoded `ui.Image` and prepared players above lazy tile State. No new
  disk/public HTTP cache or direct Cloudinary URL. Existing protected thumbnails
  are used in Home; original detail variants stay unchanged.
- Image budget: 32 MiB actual owned pixels, <=16 entries / <=8 distinct Posts,
  LRU preferring nonvisible entries. Decode <=600 px width / approximately <=1 MP;
  compressed bytes are discarded after decoding. This is NOT whole-app RAM.
- Native pool <=3 controllers, exclusive playback, visible-only spare-slot warmup;
  warmup never evicts a prepared player. Scroll/tab/route/app inactivity pauses
  immediately. Retained instance/buffer/position survives card disposal. Native
  buffers remain SDK-managed; no claim of caching entire videos or arbitrary Feed.
- Credential edge case: before resuming a retained paused player, reuse existing
  `AuthService.postMediaAccess`. Unchanged credentials/endpoint retain the player;
  renewed native HTTP headers require a decoder rebind, keeping cover and position.
  JWT is NOT part of image/media identity. JWT lifetime/refresh/business permissions
  are unchanged. This security-driven rebind is not a scroll/cache miss. Direct
  native denial still evicts scoped content; there is no authorization bypass.
- Identity: authenticated account + Post/media ID + protected variant/kind + API
  version/immutable metadata signature. Media IDs are immutable in current backend.
- Media idle TTL 15 minutes, lazily checked on access/resume. Pressure, Home disposal
  and account changes clear resources; late ACKs cannot restore released entries.
- ONE metadata absence TTL: 5 minutes. Short returns preserve list/scroll. Longer
  returns make one deduped refresh. Pull refresh remains explicit; refresh hides
  uncertain rows, then reuses unchanged resources after server permission ACK.
  Transient error hides content; retained RAM is reusable after a successful retry.
- Like/Save ACK updates fields only. Comment/viewer return reconciles one Post via
  existing detail API. Stable media keys; no new Feed polling/realtime.
- Logout/switch, confirmed 401/403/404, deletion, identity changes and revoked rows
  evict scoped resources. Local follow/privacy changes revalidate eligibility.
  Each NEW media/Range GET still uses Spring JWT/permission/no-store enforcement.
  Viewed bytes cannot be remotely recalled. Remote permission changes are learned
  at explicit refresh/TTL/real server denial, NOT realtime cache revocation.

## 3. Measurements And Tests

Diagnostics default OFF: `--dart-define=POST_MEDIA_DIAGNOSTICS=true` opts in.
Logs contain safe IDs/counts/bytes/lifecycle, never tokens/content/headers. Ignored
evidence/APKs: `backups/home-media-lifecycle/`. Temporary streaming loopback proxy
counts transferred response bytes without changing Spring or adding containers.

| Baseline observation | Feed GET/bytes | Thumbnail GET/bytes | Original GET/bytes | Range GET/bytes |
|---|---:|---:|---:|---:|
| Initial navigation | 3 / 16,602 | 8 / 284,968 | 9 / 2,434,104 | 1 / 2,826,587 |
| Scrolling | 10 / 55,340 | 15 / 412,320 | 87 / 25,267,226 | 16 / 18,427,217 |
| Short-tab window | 1 / 5,534 | 0 / 0 | 0 / 0 | 0 / 0 |

Initial navigation was NOT a controlled cold benchmark. Scrolling included user-
reported pull refresh and the final Post, NOT a strict five-card/no-refresh test;
do not compute percentage improvement from unmatched windows. Cumulative log:
18 player init / 17 dispose, 90 tile evictions, 90 image-spinner stage emissions,
2 video-spinner emissions. Offscreen/prebuilt stages are NOT all visible spinners.
PSS KiB: initial unknown-screen 871,649; initial navigation 970,541; scrolling
937,110. Measurements include the rest of GoMate/Map/native allocations.

- Flutter focused P1A-P3 + lifecycle: 78 PASS on the final combined run, including
  actual pixel-budget eviction, offline retry, account switch and credential rebind.
- Server: 36 PASS across PostPublishApiTest, PostFeedApiTest, PostCommentReportApiTest,
  AccountPrivacyApiTest, PostImageBufferTest (protected media/privacy/Range).
- Read-only live Flyway: 22 successful versioned migrations, latest V22; no DB writes.
- Analyze: 0 errors, 15 existing warnings, 298 informational diagnostics.
- Diagnostic debug APK: PASS (final build 93.8 seconds), no dependency/native changes.
- Default-diagnostics-OFF final APK: PASS, 149.4 seconds. It additionally includes
  the credential guard tested automatically after the Android observation session.
  Artifact: `build/app/outputs/flutter-apk/app-debug.apk` (ignored).
- Android AFTER scrolling: owner confirmed five loops, fast playback and retained
  position. Same diagnostic process PID 4240; forwarding verified to host 18094.
- Measurement resumed after interruption: USB reverse/helper had stopped. The
  subsequently running APK (device update 10:00:58) had diagnostics OFF and direct
  8081 forwarding; zero proxy rows from that attempt are NOT a zero-request PASS.
  Reinstalled the verified diagnostic APK (SHA-256
  `31018eb529fc136541d4ad4b4620d5afdfea1f624cd7bcdb0b96debbd4f93f88`).
- Historical 73/81-test reports do not prove this hotfix or Android acceptance.

Verified AFTER warm-scroll window (after initial media preparation):

| Metric | Additional work in five loops |
|---|---:|
| Feed GET | 0 |
| Thumbnail GET / bytes | 0 / 0 |
| Original image GET / bytes | 0 / 0 |
| Video Range / response bytes | 1 / 75,908 |
| Player initialization / disposal | 0 / 0 |
| Image decode | 0 |
| Image/video full-spinner stage emissions | 0 / 0 |

Native player count stayed 1 initialized / 0 disposed across preparation and
scrolling; only ONE video media ID is proven in this capture. Do not claim the
two-distinct-video physical case yet. The Range was HTTP 206, `bytes=3150731-`,
75,908 bytes: the final part of the 3,226,639-byte video, not a complete re-download.
Its response took 2,545 ms; native buffering toggled for approximately 2.75 seconds.
Therefore zero reinitialization is proven, NOT zero network/buffering for unseen
segments. User nevertheless confirmed fast resumption/retained position.
PSS after preparation: 822,480 KiB; after five loops: 844,004 KiB. This is a
single whole-process observation, not proof of a RAM plateau or a matched
percentage improvement over the earlier baseline. No long-run leak claim.
Evidence: `hotfix-warmup*`, `hotfix-scroll*`, `network-after-resume.jsonl` in the
ignored diagnostic directory. Initial preparation bypassed the proxy, so its
binary traffic must NOT be reported as zero; the later scroll window was routed
through the proxy and is cross-checked against unchanged Dart counters.

Short-tab window: no Feed/image/thumbnail GET, image decode or player init/dispose.
Owner confirmed retained position and no audio outside Home. There were 4 Range
responses / 7,219,578 transferred bytes, including repeated `bytes=400052-` and
one tail range. One response was partial/aborted. These are NOT zero video
traffic and cannot all be described as newly unbuffered tail bytes. Existing
logs do not distinguish end-of-video replay/seek from SDK buffer reloading;
do not claim exact causality without position/seek instrumentation. Player
identity stayed stable throughout. PSS: 752,836 KiB; Home pixels: 15,081,600 bytes,
6 entries, 1 player. Range traffic is still a documented limitation.

Read-only fixture check: Post 6 is a nondeleted 19,337 ms video. The other video
Post 7 is already soft-deleted; it is NOT restored or modified for testing.
Thus two-distinct-video physical acceptance remains unverified despite an earlier
generic preparation confirmation. Automated tests exercise three native players.
The first attempted long return was only 55,739 ms in lifecycle logs and had
zero Feed GET as expected; it is NOT counted as a >=5-minute TTL PASS.

Timed return PASS: Home exited at 10:18:22.802 and returned 10:24:43.477,
380,675 ms (6 min 20.675 sec) later. During absence: zero Feed/media calls.
Return: ONE Feed GET / 5,534 bytes, zero thumbnail/original/Range requests,
zero player init/dispose/decode/full-spinner increments. Metadata ACK in about
190 ms. Owner confirmed immediate images, preserved list/scroll. Pixel store
remained 15,081,600 bytes / 6 entries / 1 player. Whole-process PSS 883,022 KiB.

Final refresh/interaction window is MIXED, not a strict one-pull benchmark:
5 Feed GET / 27,669 bytes, 1 Post-detail GET / 669 bytes, 4 thumbnail GET /
115,315 bytes, zero original image or Range requests, no native player init/dispose.
The four thumbnails comprise two explicitly logged idle-TTL evictions (Posts 1/2)
and two previously unseen album media IDs in Post 2; no mass image reset is shown.
No image requests followed the comment-detail response in the final capture.
Do not attribute all five Feed requests solely to interactions or claim zero
metadata calls in this mixed session; refresh intent was not instrumented.
Owner confirmed refresh/Like/Unlike/Save/Unsave/comment counters, quick resumed
video and no unintended autoplay. Final pixels: 19,742,400 bytes / 8 entries /
1 player; PSS 916,598 KiB. These are point samples, not a long-running leak study.

## 4. Android Confirmation And Follow-Up

Owner-confirmed AFTER: five nearby-Post scroll loops, stable video position/quick
playback, short returns/no outside audio, timed >=5-minute return, refresh,
Like/Save toggles and a comment with correct counters/quick resumed playback.
The credential guard added afterward has automatic coverage; no second full
physical matrix or real 15-minute expiry wait is claimed for that small addition.

Remaining physical cases: two distinct nondeleted videos (only one available),
deliberate offline/unbuffered seek, memory-pressure/long-feed stress, Google A/B
privacy-revoke matrix and real credential-expiry/seek. RAM budgets, controller
eviction/exclusive playback, offline image retry, scope/session/late-ACK/revoke
and credential rotation are covered automatically, not misreported as phone PASS.
Native back-buffer behavior/repeated Range traffic remains a limitation. No
zero-network promise for replay, seeking or segments the SDK no longer retains.
Already issued requests may finish after navigation.

Measurement only: phone 8081 -> host 18094 -> Spring 8081. At the end restore
`adb -s ANDROID_DEVICE_SERIAL reverse tcp:8081 tcp:8081` BEFORE stopping the recorded proxy.
Cleanup DONE: restored 8081 -> 8081, verified and stopped our Node diagnostic
process; no listener remains on 18094. Docker retains the standard four services
and no extra API container was created. Final APK installed with `adb install -r`
(Success), preserving application data; launched MainActivity successfully,
process PID 11462. Diagnostics OFF by default. Final SHA-256:
`f686cfc8fa0d49ab9ffd8969c311394838638279fd4dcdfb6ec6f693875555f1`.
Unauthenticated host Feed probe returns expected 401; backend is reachable and
protected. Cold process restart legitimately reloads RAM media. Final normal
build was launched, not rerun through the full manual matrix after installation.
STOP after this hotfix. Do not resume P3 manual tests, implement P4/viewed-Post
hiding, or change Feed ordering without the owner's next instruction.
