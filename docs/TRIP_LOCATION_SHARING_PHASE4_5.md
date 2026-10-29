> Historical Start/Share-ON gating below is SUPERSEDED by TRIP_PIN_CENTRIC_BUSINESS_RESET.md and MAP_PIN_SWITCH_LAST_KNOWN_FIX.md; Global Block filtering is in GLOBAL_USER_BLOCK.md.

> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

> SUPERSEDED BY TRIP_PIN_CENTRIC_BUSINESS_RESET (2026-10-16).
> Journey status / Start / Complete / Cancel / separate Share rules below are historical.
> Preserve reusable native GPS, cadence, permissions and Map performance only.

# Phase 4.5 - Trip Location Sharing

Status: IMPLEMENTED / AUTOMATED + REAL STORE VERIFIED / ANDROID MANUAL PARTIAL.
Date: 2026-10-16. NOT PHASE_4_5_CLOSED; no claim of Android physical readiness yet.

## Bàn Giao Nhanh

### Bổ Sung Phase 4.6

- Xem `TRIP_COMPLETION_CANCELLATION_PHASE4_6.md`: Kết thúc/Hủy là hành động
  nhóm trưởng chủ động, không chạy theo giờ/ngày và không thay thế Xóa/lưu trữ.
- Sau commit, Share mọi thành viên của đúng lịch trình OFF, ghim của đúng lịch
  trình được gỡ; Mongo current snapshots được dọn best-effort, giữ message history.
- SSE vị trí hiện có thêm invalidation tối giản `tripStateChanged` (tripId/status),
  không chứa GPS và không đi vào Notification Center/FCM. Màn chi tiết hoặc Map
  đang xem nhận trạng thái đóng; không tính lại Directions vì GPS/status tick.
- Flutter dừng runtime theo tripId; đóng A không dừng dịch vụ nền của C đang ghim.
  Gửi nền gặp 422 sẽ đọc lại trạng thái và dừng nếu terminal, không thử mãi.
- Không thêm dependency, migration hoặc location subsystem. Các số đo thiết bị
  Phase 4.5 bên dưới vẫn là kết quả cũ, không phải nghiệm thu vật lý Phase 4.6.

- Đã thêm “Bắt đầu lịch trình” riêng cho nhóm trưởng theo phê duyệt của bạn.
  Theo chỉnh sửa mới nhất khi test: dòng này đứng đầu chi tiết, trên “Tin nhắn”,
  không còn nằm trong menu ba chấm. Ghim, bắt đầu và chia sẻ là ba thao tác độc lập.
- Mỗi thành viên tự bật “Chia sẻ vị trí” trong chi tiết lịch trình. Chỉ lịch trình
  ACTIVE mới được gửi GPS; không tự bật Share khi ghim hoặc mở Map.
- Mục tiêu khi mở app khoảng 15 giây; khi xuống nền khoảng 60 giây qua dịch vụ
  vị trí native Android, cần ghim + GPS + quyền Luôn cho phép. Đây không phải
  cam kết thời gian chính xác hay chạy mãi sau khi Android diệt tiến trình.
- Bỏ ghim dừng gửi nền nhưng không tự tắt Share. Tắt Share không xóa snapshot cũ
  và không ngăn bạn xem vị trí thành viên khác nếu vẫn còn quyền trong lịch trình.
- Mongo chỉ giữ snapshot mới nhất, không tạo lịch sử đường di chuyển. GPS tick
  không tạo thông báo nghiệp vụ/FCM và không tính lại đường đi trên Map.
- V15 chỉ thêm thời điểm thay đổi Share, không thêm bảng. Đã backup trước khi
  cập nhật API cổng 8081. Bốn cờ ON được bật ngầm ở code cũ được reset OFF để
  người dùng tự lựa chọn lại; không xóa lịch trình, thành viên hay snapshot.
- Đã kiểm thử tự động và DB thật tách biệt. Đã đo được ACK foreground trên điện
  thoại, gồm foreground trung bình 15,15 giây và Home-background trung bình 61,20 giây.
  Bảng nghiệm thu bên dưới phân biệt các phần còn chờ kiểm tra. Cần chạy lại hoàn toàn
  để nhận cấu hình Android mới; không chỉ hot reload.

## Audit Before Code

- Actual Flyway: V1-V14 SUCCESS. V1-V14 will not be edited.
- Pin: V8 trip_pins, POST/DELETE /trips/{id}/pin, one pin per user; independent of journey status.
- GPS: GoMateLocationService + geolocator 14.0.3 / geolocator_android 5.0.3.
- PUT /trips/{id}/location currently implicitly enables sharing, including on pin.
  This violates Phase 4.5 explicit consent and will be removed.
- PG trip_members.location_sharing_enabled exists; no sharing-state updatedAt.
  Four existing ON flags came from legacy implicit publishing, not explicit consent.
- Mongo trip_current_locations has unique (tripId,userId), trip+updatedAt and updatedAt
  indexes; no TTL/history. These remain unchanged.
- Android currently has foreground/background location permissions, but no explicit
  foreground-service location configuration. Geolocator already supplies its native
  location foreground service; no new GPS/auth/background state-management package needed.
- Notification SSE already uses authenticated Spring SseEmitter, bounded delivery,
  JWT/session revalidation and client backoff. Location will reuse these patterns
  with a separate trip-scoped stream, never the durable notification channel.
- Map member preview currently deleteAll/recreates annotations. Location reconciliation
  will diff by userId and update affected annotations without route/place/Trip reload.
- No Share Location UI exists. Add one minimal switch/status in current Trip detail.
- All 15 non-archived Trips are DRAFT. User explicitly approved a separate Leader-only
  Start Trip action using the existing confirmation sheet. Initially in menu, then moved
  to the first Trip detail row above Chat per user's physical-test feedback. Pin != start != share.

## Approved Implementation Boundaries

- V15 adds sharing updatedAt only, resets legacy implicit ON to OFF. No tables,
  no GPS coordinates in PostgreSQL, no changes to old migrations or Trip IDs/history.
- Server checks ACTIVE journey + non-archived Trip + active JWT membership + explicit
  share intent before publish. BACKGROUND mode additionally requires that Trip pinned.
- Share OFF retains last-known Mongo snapshot. Snapshot reads do not infer LIVE.
- Android native foreground-service location stream targets 60s, foreground publisher
  targets 15s independently of camera/Map events. Start native service while foreground
  only, after explicit consent + pin + Always permission + service ON.
- No wake/Wi-Fi lock or battery-optimization bypass. Home/background is best-effort;
  process/Flutter-engine destruction, force-stop and OEM killing are not guaranteed.
  Recover/reconcile on next app start. Do not claim closure without physical proof.
- One global publishing coordinator. One location SSE subscription for the visible
  active Trip Map; unrelated screens/rebuilds must not create duplicates.
- Logout locally stops immediately; best-effort authenticated share disable, with
  user-scoped pending-disable reconciliation if offline. No previous-account workers.

## Platform References

- [Android location foreground-service requirements](https://developer.android.com/develop/background-work/services/fgs/service-types#location).
- [Geolocator package documentation](https://pub.dev/packages/geolocator).
- Installed plugin AndroidSettings.foregroundNotificationConfig documentation and native
  GeolocatorLocationService inspected. Its service is attached to the Flutter engine;
  do not promise continued publishing after engine/process termination.

## Business Flow And UI

1. Leader opens Trip detail -> first Start Trip row (above Chat) -> existing GoMate confirmation.
   Server ACK changes DRAFT/PLANNED -> ACTIVE. MEMBER cannot start. Completed/cancelled
   Trip cannot be restarted. No pin or sharing intent is changed by Start. The action
   disappears after start and is no longer in the three-dot menu. Other rows are unchanged.
2. Each member independently enables the new minimal Share Location switch in Trip detail.
   Switch reflects server ACK, with loading/error/retry and background-capability status.
3. Foreground coordinator targets 15s for explicit-enabled ACTIVE contexts: current Map,
   Trip detail, or pinned Trip. A stationary GPS fix can still refresh server updatedAt.
4. Native Android geolocator location foreground service is armed while app is visible,
   only after consent + ACTIVE membership + pin + Always permission + GPS ON. Its native
   location stream targets 60s; background publishing is driven by native fixes, not
   a Dart background Timer. Ongoing OS notification is disclosure, not a business alert.
5. Unpin cancels native background delivery but retains Share ON. Foreground sharing may
   continue for the Trip/Map in use. Share ON does not pin. Pin does not start/share.
6. OFF stops local runtime before requesting server OFF; UI intent waits for ACK.
   Failed OFF stays truthfully ON on server but locally suspended, with user-scoped
   pending-disable metadata. No GPS coordinates are stored in local pending metadata.
7. Logout stops local publisher/SSE first, then best-effort bulk-disable (3s client wait).
   Offline cleanup is reconciled before any new-session publisher may start. Existing
   Auth logout semantics remain unchanged: failed server logout may leave user signed in,
   but location runtime stays suspended. Retry logout rather than assume session revoked.
8. Leave/remove/archive immediately revoke server authority. Archive retains Phase 4.4B
   snapshot-cleanup behavior; ordinary Share OFF does NOT delete snapshot. Leader transfer,
   invitation/cancellation, member count and pending-list fixes remain unchanged.

## API Contract

All paths below use existing `/api/v1`, JWT principal and current JSON/error convention.
No query-string tokens or arbitrary userId for location ownership.

| Method | Path | Result |
|---|---|---|
| POST | /trips/{id}/start | Leader-only idempotent start; Trip detail after ACK |
| GET | /trips/{id}/location-sharing | Own intent + timestamp + Trip status + server pin |
| PUT | /trips/{id}/location-sharing | Enable own explicit intent; empty body only |
| DELETE | /trips/{id}/location-sharing | Disable own intent; retain snapshot |
| DELETE | /trips/location-sharing | Disable own active-member intents for logout; 204 |
| PUT | /trips/{id}/location | Existing UPSERT endpoint; actual GPS sample |
| GET | /trips/{id}/locations | Current snapshots of current authorized members |
| GET | /trips/{id}/locations/stream | Trip-scoped authenticated SSE invalidation |

Sharing response:

```json
{
  "tripId": "<trip UUID>",
  "userId": "<JWT actor UUID>",
  "sharingEnabled": true,
  "updatedAt": "<server UTC instant>",
  "tripStatus": "ACTIVE",
  "pinned": true
}
```

Publish accepts latitude/longitude, optional accuracyM/capturedAt, optional
runtimeMode FOREGROUND or BACKGROUND. Omitted mode preserves old foreground payload
compatibility, but no longer bypasses explicit consent/ACTIVE requirements. BACKGROUND
additionally checks server pin. Runtime mode is client context, never identity or proof
of consent. Server updatedAt, not capturedAt/device clock, determines snapshot freshness.
Malformed coordinates/userId body -> controlled 400; missing consent or background pin
-> 403; unavailable membership/archived Trip -> 404; non-ACTIVE journey -> 422;
Mongo unavailable -> 503. No fake successful ACK when Mongo fails.

SSE data contains eventKind=tripLocationUpdated, tripId, userId, updatedAt only.
Coordinates remain behind authorized snapshot REST. Revalidate JWT/session and current
Trip eligibility before delivery/heartbeat; bounded queues/connections; reconnect/backoff.
Delivery failure retains Mongo snapshot. No notification/push module is called on a tick.
SSE rejection clears location overlay, not automatically the readable Trip itself:
location stream eligibility is narrower than Trip visibility (ACTIVE only).

## Schema And Preservation

V15__trip_location_sharing_intent.sql:

```sql
ALTER TABLE trip_members
  ADD COLUMN location_sharing_updated_at TIMESTAMP WITH TIME ZONE
  NOT NULL DEFAULT CURRENT_TIMESTAMP;
UPDATE trip_members SET location_sharing_enabled=FALSE
WHERE location_sharing_enabled=TRUE;
```

- Reuses existing boolean; timestamp records server-side intent changes.
- Resets 4 old implicit ON flags once. After cutover: 23 membership rows, all OFF.
  This is intentional consent correction, not loss of Trip/member/snapshot data.
- No new tables/indexes, no GPS fields in PostgreSQL, no modified V1-V14.
- Mongo remains one snapshot per pair; unique/trip+updatedAt/updatedAt indexes unchanged.
  No TTL/history/archive/trail collections added. Five pre-existing current snapshots
  remained after cutover; OFF reset never called Mongo delete.

Clean DB: V1 -> V15 all applied. Restored current V14 DB: V15 applied once.
Main local DB: V1-V15 all SUCCESS. 25 public tables total: same 24 business tables
and Flyway history. Counts for every business table were compared exactly on a separate
restored copy before any API fixtures. All preserved; only Flyway count 14 -> 15.

Selected main-DB cutover counts:

| Table | Before | After |
|---|---:|---:|
| users / user_profiles / user_settings | 38 each | 38 each |
| places / place_media | 146 / 7 | 146 / 7 |
| trips / trip_members / trip_stops | 16 / 23 / 7 | 16 / 23 / 7 |
| trip_pins / trip_invitations | 1 / 25 | 1 / 25 |
| conversations / conversation_members | 8 / 16 | 8 / 16 |
| notifications / device_tokens | 31 / 1 | 31 / 1 |
| refresh_sessions | 187 | 187 |
| flyway_schema_history | 14 | 15 |

All 15 non-archived Trips stayed DRAFT. No real user Trip was automatically started,
no test users/Trips/location samples were inserted into main DB by verification scripts.

## Map Performance Boundaries

- One global publisher coordinator and one visible GROUP/ACTIVE Trip SSE subscriber.
- SSE ticks refresh only `/locations`, single-flight with one coalesced follow-up if an
  event arrives during an in-flight REST read. 30s REST fallback while foreground Map.
- No full Trip/Place request, route request, Map state rebuild or session revision on
  a location tick. Stream is disconnected when Map hidden/app background/logged out.
- Annotation diff by userId/fingerprint. Update only changed members; no deleteAll on
  each snapshot. Gesture-time changes defer until gesture ends; marker image cache bounded.
- No snapshot means no member marker. LAST_KNOWN age stays truthful without a made-up
  LIVE/stale cutoff. No GPS-driven camera animation, arrival/check-in or movement trail.

## Files In This Phase

Created:
- backend/src/main/resources/db/migration/V15__trip_location_sharing_intent.sql
- backend/src/main/java/vn/gomate/location/controller/TripLocationStreamController.java
- backend/src/main/java/vn/gomate/location/realtime/TripLocationStreamHub.java
- backend/src/test/java/vn/gomate/TripLocationSharingTest.java
- backend/scripts/verify-trip-location-sharing.ps1
- lib/features/trip/location/location_sharing_models.dart
- lib/features/trip/location/location_sharing_repository.dart
- lib/features/trip/location/location_runtime_driver.dart
- lib/features/trip/location/trip_location_sharing_service.dart
- lib/features/trip/location/trip_location_realtime_service.dart
- lib/features/trip/location/trip_location_share_control.dart
- lib/features/map/utils/last_known_location_label.dart
- test/trip_location_sharing_test.dart
- docs/TRIP_LOCATION_SHARING_PHASE4_5.md

Modified (some already had unrelated prior-phase changes; never discard them):
- Backend TripController, TripDtos, TripRepository, TripService, TripLocationService.
- TripApiTest; member/leader lifecycle verification scripts now explicitly start/share
  before fixture GPS writes. Leader verification compares snapshot deltas rather than
  assuming a completely unused isolated Mongo DB.
- lib/app.dart; AuthService.openEventStream optional approved Trip path (same existing
  client/API config/JWT/refresh flow, no Auth business change).
- TripUi/status mapping, RealTripRepository.start, Trip detail Start/share controls.
- TripScreen/TripDetail/MapTripPinButton: remove implicit GPS publish on pin.
- MainShell/MapUiSession visibility/account cleanup; MapScreen snapshot subscription;
  SpringMapGateway LAST_KNOWN; GoMateLocationService non-prompt runtime option;
  MapboxLayerController incremental member updates.
- AndroidManifest native location FGS declarations/permissions; no new dependency.
- PROJECT_CONTRACT.md, DATABASE_CONTRACT.md, CODEX_INDEX.md.

## Automated And Real-Store Verification

- `docker compose build api`: Maven clean verify, **126 passed**, no failures/errors.
  Existing Auth/Firebase/Google, Place/route, invitations/notifications/push, Trip/member/
  leader lifecycle regressions included. Firebase/Google tests are automated mocks,
  not a claim of newly performed Google sign-in on the phone.
- Additional focused `TripLocationSharingTest`: **12 passed**, including explicit mock
  assertion that location publish never calls NotificationPushDelivery, even SSE failure.
- `flutter test --reporter expanded`: **129 passed**, including 22 location/Start tests:
  explicit consent, clocks, pending OFF/logout, account guards, native-error backoff,
  single subscriber, incremental annotation updates, retained OFF overlay and Start row
  first above Chat / absent from menu / Leader only / confirmation + ACK required.
- `flutter analyze --no-fatal-warnings --no-fatal-infos`: 0 errors, 16 existing warnings,
  263 infos (279 total). Existing unrelated lint debt was not mass-refactored.
- Android debug APK built successfully; merged manifest includes native geolocator service
  type=location, FOREGROUND_SERVICE and FOREGROUND_SERVICE_LOCATION.
- Real PostgreSQL + Mongo + HTTP + two authenticated SSE clients: PASS on both clean
  and restored V14 -> V15 DBs. Tested consent, Leader start, outsider, wrong userId body,
  server timestamp, stationary UPSERT one document, OFF retains LAST_KNOWN, BG unpin403 /
  FG allowed, bulk disable, invalid GPS, leave/archive revocation, no inbox growth.
- Existing real-store member leave/remove/regroup/race and Leader transfer/archive/race
  scripts: PASS on isolated V15 DB. Test-only samples never used a real user's GPS.
- Main API 8081 is running V15; public Place API HTTP200. Main migration/count checks PASS.

Ignored evidence in backups/: phase45_docker_build_final.log,
phase45_backend_location_final.log, phase45_flutter_completed.log,
phase45_analyze_completed.log, phase45_apk_completed.log,
phase45_clean_location.json, phase45_upgrade_location.json,
phase45_member_regression.json, phase45_leader_regression.json,
phase45_restore_before_counts.json, phase45_restore_after_counts.json,
phase45_cutover_pre_counts.json, phase45_cutover_after_counts.json.
Logs contain no raw location/token/secret diagnostics by this implementation.

## Backup And Rollback

Before changes/cutover, saved ignored PostgreSQL custom dumps:
- backups/phase45_pre_20261016.dump
- backups/phase45_cutover_20261016.dump
- backups/phase45_pre_api_20261016.jar (working V14 API)

If rollback is necessary: stop only API; restore the pre-cutover dump into a NEW isolated
PostgreSQL database, verify counts, run the saved V14 JAR against that restored database
with existing private environment, then switch the API datasource deliberately. Do not
run the V15 code against a restored V14 schema and expect it to remain V14: Flyway will
apply V15. Do not delete Flyway history, use repair as rollback, reset volume, or drop the
user database. Returning to V14 reintroduces legacy implicit-sharing behavior; treat it
as incident recovery, not a privacy-compliant feature state.

Scratch helper API containers have been removed. Isolated Phase45 verification DBs may
be retained for inspection; none are the application DB. No Docker volume reset, no
secret/environment change, no dependency addition, no commit/push made in this phase.

## Android Manual Acceptance / Remaining Limits

Device: ANDROID_DEVICE_SERIAL, Samsung SM-N770F, Android 13 / API 33 (app target SDK 36).
No claim of physical Android 14+ verification. The user explicitly started one Trip, enabled Share and kept it
pinned; later explicitly put GoMate in background with Home. No GPS was enabled or
Trip started automatically by the agent. ACK evidence stores timing/service metadata
only, not coordinates or movement history.

Physical observations 2026-10-16 (phone local clock, UTC+07):
- Foreground: 13 successful ACKs, 17:47:58.589 -> 17:51:00.421.
  12 intervals: mean 15.153s, min 14.729s, max 16.840s (first interval includes immediate
  enable publish vs periodic clock). Independent of camera movement.
- Home background: observed for 207s, launcher confirmed resumed on every check;
  geolocator native service isForeground=true, ongoing native notification present.
- Background ACKs: 17:52:01.838, 17:53:02.982, 17:54:04.186, 17:55:05.429.
  Intervals 61.144s / 61.204s / 61.243s, mean 61.197s; zero foreground ACKs during watch.
- Mongo snapshot count remained 5 across repeated real ACKs; latest server updatedAt
  advances. Notification count remained 31. No new history collection.
- User confirmed Start -> Share becomes usable. Earlier grey switch was correct while
  Trip remained DRAFT. UI discoverability was improved at user's request: Start is now
  the first detail row above Chat, not hidden in the three-dot menu. Full Flutter tests
  and rebuilt APK include this placement; no business eligibility was loosened.
- After the user's explicit test there is one ACTIVE Trip / one Share ON membership;
  this is subsequent user action, not a discrepancy in the cutover DRAFT/OFF counts.
- User then explicitly unpinned while keeping Share ON and returned to Home.
  Four checks over more than 90s: no new background ACK, native foreground service
  stopped, Share ON membership count=1 and shared-and-pinned count=0 at every check.
  This physically proves unpin stops background without silently clearing consent.
  Foreground-after-unpin authority is additionally verified in real-store API tests;
  that specific foreground device variant is not claimed separately.

Evidence (ignored): backups/phase45_android_foreground_observed.json and
backups/phase45_android_background_observed.json and
backups/phase45_android_unpin_observed.json. Home evidence does not prove locked-
screen/doze, process termination, a second phone's marker rendering, or all stop cases.

| Case | Status |
|---|---|
| A Foreground ~15s publishing | Physical ACK PASS; peer marker/movement variants PENDING |
| B Home ~60s native background publishing | Physical Home ACK PASS; locked-screen/doze PENDING |
| C Unpin stops BG; Share intent retained | Physical PASS; FG-after-unpin API PASS / device variant pending |
| D Share OFF stops workers; last-known retained | Automated PASS / physical PENDING |
| E Logout/account switch prevents old-account sends | Automated PASS / physical PENDING |
| F Leave/remove/archive stops authority/worker | Automated PASS / physical PENDING |
| G GPS OFF / permission revoked / resume | Automated PASS / physical PENDING |
| H Map marker/route/pan performance and no notification spam | Automated PASS / physical PENDING |

Do not substitute fake-clock tests for observed device cadence. Do not claim Android
background publishing survives destroyed Flutter engine/process, force-stop, OEM battery
killing or exact timing. No headless background engine/new authentication subsystem was
introduced. Current native service supports ordinary background while its Flutter engine
is alive; other cases require a separate approved/tested extension if later demanded.

Physical test setup: stop the old Flutter run, then run from repository root:

```powershell
.\scripts\run-android-dev.ps1 -DeviceId ANDROID_DEVICE_SERIAL -NoDockerStart
```

Full reinstall/run is needed for the new Android manifest/service, not just hot reload.
Leader chooses the first Start Trip row above Chat explicitly (not the three-dot menu).
Each tester chooses Share explicitly; for BG also
pin the same Trip, enable GPS, and grant Android Always location in app settings. Observe
foreground first, then Home/lock for several minutes. The receiver must be a current
member viewing the same ACTIVE GROUP Trip on Map. No forced battery-policy changes.

Verdict: backend/storage/API and automated Flutter verified. Android foreground and
ordinary Home-background cadence have real-device evidence. Remaining stop/permission,
peer-marker and locked-screen variants prevent full PHASE_4_5_CLOSED acceptance yet.
