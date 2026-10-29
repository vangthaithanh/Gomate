> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Phase 4.3 - Android Background Push Foundation

Date: 2026-10-15. UI/business unchanged; scope is device registration and delivery of Trip invitation notifications only.

## Tóm tắt bàn giao

- Đã hoàn thành nền tảng push Android Phase 4.3. Máy thật đã xác nhận: nhận thông báo khi app ở nền, mở lại app đã đóng vào đúng lời mời một lần, không trùng popup khi đang mở app, và thông báo cũ không thể chấp nhận lời mời đã hủy.
- PostgreSQL vẫn là nguồn trạng thái chính; SSE giữ vai trò realtime khi mở app; polling vẫn 12 giây. FCM chỉ gửi gợi ý để app tải lại trạng thái từ API, không tự quyết định nghiệp vụ.
- V12 chỉ thêm `device_tokens`, không sửa V1-V11; đã backup và test DB cũ/DB sạch. Không thay giao diện, nghiệp vụ Trip/Map/Settings hoặc Auth core.
- Backend 95 test đạt; Flutter 51 test đạt; analyze riêng phần thay đổi sạch. Analyze toàn repo còn 16 cảnh báo và 265 info có sẵn, không được ghi là toàn repo đã sạch.
- iOS/APNs, GPS realtime và scheduler chưa làm. Từ chối quyền, đổi tài khoản/đăng xuất, trạng thái đã chấp nhận và re-invite đã có test tự động; chưa xác nhận hết các biến thể này trên máy thật.

## Preconditions and audit

- User confirmed all three Phase 4.2 physical-device checks: immediate foreground popup, cancellation removes Accept promptly, no duplicate after polling. This is the human confirmation from this task, not an inferred result from HTTP tests.
- Before task: Firebase Core 4.15 / Firebase Auth 6.7 and Google login work; Firebase initializes lazily through Google Auth. No firebase_messaging, device-token controller/repository, or physical device-token table existed.
- Android package `com.example.gomate`; native google-services configuration and backend service account both use `gomate-498319`. Existing server FirebaseApp/credentials are reused, never copied into Flutter.
- Actual connected Android: Samsung SM-N770F, SDK 33 (Android 13). POST_NOTIFICATIONS was absent before this task.
- iOS has no verified APNs key/capabilities/Firebase native setup. iOS push remains deferred; platform column permits future IOS support.
- Existing inbox is PostgreSQL V10, cancellation V11, SSE foreground + 12-second polling. These contracts remain authoritative.

Primary references: [Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [foreground/background and interaction handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Admin SDK delivery](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk), [token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens).

## Architecture

```text
Business transaction -> PostgreSQL -> COMMIT
 -> NotificationEventPublisher (delivery coordinator)
    -> existing authenticated SSE
    -> bounded NotificationPushDelivery queue -> Firebase Admin -> FCM

Flutter foreground -> existing SSE/store/popup, polling fallback
Android background/normal termination -> FCM notification+data -> OS tray
Tap -> wait for Firebase, Auth, inbox, MainShell navigator
    -> GET current notification -> approved Notification UI routing
```

SSE and FCM dispatch have separate error guards. A transport failure cannot roll back a successful Trip transaction. The FCM worker re-reads the notification after commit; only unread, still-PENDING TRIP_INVITATION or valid TRIP_INVITATION_ACCEPTED is eligible. CANCELLED/UPDATED/read signals do not create an intrusive cancellation OS notification.

One worker pool, 1-2 daemon threads, bounded 64-task queue. One send attempt per eligible device; permanent unregistered tokens disabled, transient/provider/queue failure logged without raw tokens and recovered through durable inbox/SSE/polling. No outbox, broker, scheduler, persistent retry jobs, or exactly-once delivery claim.

## V12 schema and ownership

`backend/src/main/resources/db/migration/V12__notification_device_tokens.sql` adds only `device_tokens`, using PostgreSQL/H2-compatible SQL. V1-V11 are not edited.

```text
id UUID PK
user_id UUID FK users ON DELETE CASCADE
installation_id UUID UNIQUE NOT NULL
session_id UUID FK refresh_sessions ON DELETE CASCADE
token TEXT UNIQUE NOT NULL
platform VARCHAR(10) CHECK ANDROID/IOS
enabled BOOLEAN default true
created_at / updated_at / last_seen_at TIMESTAMPTZ default current timestamp
indexes: (user_id,enabled), (session_id)
```

Multiple installations per user are supported. One opaque installation UUID is generated securely and kept separately from Auth session storage. Token rotation updates the same installation row. Authenticated registration rebinds that installation/token to the principal's user/session; no client owner userId is accepted. If the same token moved between installations, its old binding is removed so the token stays unique. Concurrent unique conflicts return the existing controlled conflict response and can be retried.

Delivery selects only enabled Android devices whose referenced refresh session still belongs to the recipient, is unrevoked/unexpired, whose account is ACTIVE, and whose existing `user_settings.notifications_enabled` is true. Session logout/revocation therefore disables effective delivery even if a client unregister request failed. This reads existing permission/session truth; it does not duplicate Auth state or store JWTs.

Unregister matches installation + current user + current session, so late cleanup from an old account/session cannot disable the new owner's valid binding. UNREGISTERED cleanup additionally matches the exact previously attempted token; a late invalid-token result cannot disable a rotated/reassigned token. INVALID_ARGUMENT is not blindly treated as proof that a token is dead, because invalid payloads can cause it too.

## API

```text
POST /api/v1/notification-devices
Authorization: existing GoMate JWT
{"installationId":"<UUID>","token":"<FCM token>","platform":"ANDROID"}
204, idempotent

DELETE /api/v1/notification-devices/current
Authorization: existing GoMate JWT
{"installationId":"<UUID>"}
204, idempotent and scoped to current user/session
```

Unknown owner fields are rejected by current strict JSON binding. No GET/list/enumeration endpoint; no token value is returned. Flutter never receives FCM server credentials.

## Payload and duplicate prevention

- Android notification title `GoMate`; body reuses existing notification titles (`Lời mời lịch trình` / `Lời mời đã được chấp nhận`). No Trip name, actor/private content, action button, or cancellation wording added.
- Data: notificationId, eventKind=CREATED, recipientUserId. The opaque recipient hint filters stale cross-account taps; REST authorization is still decisive. No business status or full object is trusted from payload.
- Android OS tag is notificationId; valid re-invite N2 is distinct from historical N1. TTL 24h; old delivery never restores old business state.
- Policy: notification+data lets Android display in background. Foreground FCM uses onMessage solely to invalidate the same NotificationRepository; **no local notification plugin, no OS notify call, no separate popup**. SSE stays primary; existing notificationId-based store dedupe arbitrates polling/SSE/FCM arrival order.
- Top-level background handler is retained with vm:entry-point; it does not navigate, access Auth, write business data, or build another OS notification.
- Channel `gomate_invitations_v1` and monochrome `ic_stat_gomate` are native OS integration, not a redesign of app screens.

## Flutter lifecycle

- firebase_messaging 16.7.0 added compatibly with current Firebase Core/Auth; no unrelated upgrades. Existing HTTP client/API candidate URLs and JWT refresh are reused.
- One global NotificationPushService starts during main initialization, Android only. Initialization errors leave app/Auth/Map/Inbox/SSE usable.
- Permission/token registration waits for authenticated MainShell/navigation readiness. Android 13 permission requested once if not previously asked; actual OS authorization checked on resume. Denied permission unregisters this install without breaking Inbox/SSE. No fake Settings-enabled state or Settings redesign.
- Token refresh re-registers installation; resume revalidates current binding. Network registration failure retries on foreground after 30s/resume, not by shortening inbox polling.
- Before normal logout: scoped unregister + best-effort FCM deleteToken. Existing server logout contract remains authoritative and revokes the session. Auth/account change clears pending opens/dedupe, deletes the previous FCM token and serializes cleanup before new registration. Generation guards reject late old-account REST/FCM work.
- getInitialMessage and onMessageOpenedApp share one queue. Cold-start hints wait for Auth/session and MainShell post-frame router. Each FCM message routes at most once; a new re-invite is not collapsed.
- Before routing, the service suppresses a duplicate in-app popup for the tapped ID and resolves the current notification through REST. Existing Notification Screen resolves again as needed: PENDING -> inbox spotlight #1, CANCELLED -> history/no Accept/no Trip, ACCEPTED -> fresh authorized Trip detail. Read does not accept, and popup still has no Accept.
- Missing/forbidden/unreachable notifications never navigate from payload alone; reconciliation can retry on resume. Old user's payload is discarded in a different signed-in account.

## Configuration and files

Root Compose remains the entry point. New `NOTIFICATION_PUSH_ENABLED` flag defaults false in application/.env.example; local ignored `.env` is enabled. `FIREBASE_ENABLED`, Firebase project ID, mounted service account path remain the existing configuration. No server key added to Flutter or committed.

Backend additions: V12; NotificationDeviceController/Service/Repository; FcmGateway/FirebaseFcmGateway/NotificationPushDelivery; NotificationPushTest. Existing NotificationEventPublisher coordinates both after-commit transports. PlaceApiTest's allowed schema list is updated for the sole new table, without weakening the no-extra-table assertion.

Flutter additions: firebase_push_messaging.dart, notification_push_service.dart, notification_push_test.dart. Changes: GoMateApp initialization; local main initialization; AuthService best-effort beforeLogout callbacks; existing store invalidation/suppression methods; MainShell router/lifecycle wiring. Android Manifest, MainActivity channel, OS icon, pubspec/lock updated. No Map/Trip/Notification/Settings layout or business changes.

Repository portability: `lib/main.dart` was already ignored before this phase. Shared `lib/app.dart` also starts the idempotent push service, so another developer's local main only needs its existing `runApp(GoMateApp())`; push startup does not depend on committing a local Mapbox token or changing ignore policy.

Native lifecycle diagnostics exposed an intentional SSE socket-close error on backgrounding. Client disconnect now cancels the subscription before closing its dedicated HTTP client, ignores only stale-generation close errors, and still propagates real active-connection errors for reconnect. Spring handles AsyncRequestNotUsableException without trying to serialize JSON onto a closed SSE response. No reconnect/poll interval change.

## Verification and physical acceptance

Execution results and any external prerequisites are recorded below. Do not infer Android READY merely from token registration, a mocked FCM send, or an Admin SDK message ID.

Backup before V12: `backups/gomate_pre_push_v12_20261015.dump` (114332 bytes, custom pg_dump, ignored). Pre-cutover DB: users 38, Trips 10, members 16, invitations 17, notifications 21, conversations 6; Flyway V1-V11 success. No reset/repair/volume deletion.

### Automated and database results

| Check | Result |
|---|---|
| Full backend test/build inside Docker | PASS: 95 tests, 0 failure/error/skip; final image includes closed-SSE handling |
| Focused push + SSE backend tests | PASS: 8 push methods + 6 realtime methods; covers PUSH-B01-B10 |
| Full Flutter test suite | PASS: 51 tests, including 12 push tests and both intentional-close/real-network SSE tests |
| Flutter analyze, whole repository | WARN / exit 1: 0 errors, 16 pre-existing warnings, 265 infos; not a clean analyze pass. No new diagnostics in push adapter/service or shared app bootstrap |
| Scoped Flutter analyze | PASS: 7 app/push/SSE/store/test files, no issues |
| Final Android debug APK | PASS: `flutter build apk --debug`; 80.6s; includes the intentional SSE-close fix |
| Existing PostgreSQL V11 -> V12 | PASS; V1-V12 success, 25 public tables, only device_tokens added |
| Existing business rows at migration cutover | PASS; users 38 -> 38, trips 10 -> 10, trip_members 16 -> 16, trip_invitations 17 -> 17, notifications 21 -> 21, conversations 6 -> 6 |
| Disposable clean PostgreSQL V1 -> V12 | PASS; 25 tables; no schema reset of the developer database |
| PostgreSQL SSE/invitation API smoke | PASS on isolated API with real PostgreSQL/Mongo and push disabled |
| PostgreSQL device API smoke | PASS: 401 unauthenticated, 400 unknown owner, 204 registration/repeat/rotation/rebind/scoped unregister, 401 revoked session |
| Device binding SQL after isolated smoke | PASS: one row, correct final owner, disabled after unregister; no token printed |

The clean verification container/database were removed after testing; the main Docker volume was not touched. Later physical-test invitations deliberately add test Trip/notification records through the real API and are not migration data loss/churn.

Evidence (ignored local logs): `backups/docker_build_android_push_release.log`, `backups/postgres_push_sse_regression.log`, `backups/postgres_push_devices_smoke.log`, `backups/docker_push_clean_server.log`, `backups/flutter_push_realtime_final_test.log`. The disposable registration script is `backend/scripts/verify-android-push-devices.ps1`; use PowerShell 7 and only an isolated push-disabled API on port 18083, never the main DB with synthetic tokens.

### Physical Android results

Device Samsung SM-N770F / Android 13. User granted POST_NOTIFICATIONS; native channel has HIGH importance. Real token registered for TEST_ACCOUNT_B, bound to its live session; token values are not included in this report.

| Scenario | Actual result |
|---|---|
| Phase 4.2 foreground SSE / cancel / no duplicate after 12s | PASS, user confirmed before Phase 4.3 implementation |
| First push at 18:14:33 | FCM accepted, user saw no OS notification. App background state was not reliably held during test preparation; not counted as a pass |
| Repeated background push at 18:22:42 | PASS: Launcher TOP, app LAST_ACTIVITY before send; FCM SENT; Android notification key present; user confirmed seeing and tapping the exact pending invitation |
| Normal termination at 18:25:00 | PASS: before send app UID NONEXISTENT and no process; FCM SENT and Android notification key present; user confirmed cold start opens the exact pending invitation once |
| Stale cancelled system notification tap | PASS on final APK: push delivered while background, Leader cancelled before tap; user confirmed cancelled state, no Accept, no Trip detail |
| Foreground FCM + SSE together | PASS on final APK: user confirmed one GoMate popup, no Android notification, no repeat after 15s for the 18:56:04 rerun |
| Permission denied / logout-account switch | Automated PASS; physical tests pending |
| Accepted push/current ACCEPTED state/re-invite identity | Automated PASS; physical variants not tested in this session |

Background test notificationId: `REDACTED_UUID`; normal-termination notificationId: `REDACTED_UUID`. Test sender is the dedicated GoMate Test Realtime account via legitimate login/API, never an impersonated real user. Test metadata stays under ignored `backups/`; credentials are not copied into docs.

APK handoff: `build/app/outputs/flutter-apk/app-debug.apk` was rebuilt with the SSE-close/bootstrap improvements. After the user confirmed the cold-start result, the final APK was installed successfully using `adb -s ANDROID_DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk` (keeps data). Installation/relaunch was intentionally postponed until that confirmation to avoid invalidating the terminated-app scenario. Final-build native regression checks follow below.

Foreground attempt at 18:45:38 is NOT counted: the user reported the phone connection had dropped and requested a rerun after reconnecting. USB API forwarding (`adb reverse tcp:8081 tcp:8081`) was restored and backend `/health` was UP; do not infer an SSE/popup failure from a test run during a disconnected development API tunnel. Wait for the user to be back inside the authenticated app before resending.

Foreground rerun at 18:56:04: user confirmed authenticated TEST_ACCOUNT_B app was open; device UID was TOP before sending. Notification `REDACTED_UUID`, invitation `REDACTED_UUID`, Trip `REDACTED_UUID`. Native logs show SSE CREATED/reconciliation and FCM broadcast received, backend FCM SENT, and no GoMate system notification key. User subsequently confirmed exactly one in-app popup, no OS notification and no repeat after 15s: physical foreground dedupe PASS.

Stale-cancel final native test: confirmed Launcher TOP and GoMate LAST_ACTIVITY before sending at 19:00:40. Trip `REDACTED_UUID`, invitation `REDACTED_UUID`, notification `REDACTED_UUID`. Verified FCM SENT and the matching Android tray key before cancelling through the legitimate Leader DELETE invitation API at 19:01:04. SQL confirmed CANCELLED; the original OS notification remained, with no second cancellation push. User then tapped it and confirmed all three: cancelled state, no Accept, no Trip detail. The stale payload did not resurrect PENDING.

Final-build native logs also show intentional SSE disconnect/resume without the previous unhandled client-close exception. No closed-SSE backend ERROR appeared in the checked final test interval. This is an observed test interval, not a claim that every future network/vendor failure is impossible.

Final live check: api/ai/postgres/mongo running, `/health` UP, Flyway V1-V12 all successful. After the six deliberate physical-test fixtures: users 38, trips 16, trip_members 22, trip_invitations 23, notifications 27, conversations 6, device_tokens 1. Relative to the preserved migration counts above this is exactly +6 Trips/owner memberships/invitations/notifications from API test setup, not a schema side effect. Test records are retained and were not silently deleted.

### Operations and rollback boundary

- Local configuration uses existing mounted Firebase credentials plus `FIREBASE_ENABLED=true` and `NOTIFICATION_PUSH_ENABLED=true`. A clone must supply its own ignored Firebase native/server files and environment as before; no private service account is committed.
- Local Android API still uses the existing development connection. After disconnecting/reconnecting USB, restore `adb -s ANDROID_DEVICE_SERIAL reverse tcp:8081 tcp:8081` or use the normal Android dev launcher script. FCM can reach the phone independently, but tapping must reach the backend to reconcile truth; an unavailable local API must not be bypassed with stale push state. Production requires its configured reachable HTTPS API, not a USB tunnel.
- Build/start API: `docker compose build api`, then `docker compose up -d api`; verify `/health`. FCM failure/disabled mode still leaves durable inbox/SSE/12s polling working.
- To disable only the new transport, set `NOTIFICATION_PUSH_ENABLED=false` and recreate api. Do not edit V1-V12, run repair, delete the Docker volume, or drop notification/business tables.
- Database restore is a deliberate recovery action from the pre-V12 custom dump into an isolated database first; it loses any writes after the snapshot if used to replace the main DB. No automatic down-migration or destructive rollback was performed.

Native dependency change needs rebuild/reinstall, not hot reload. `adb install -r` keeps app data; permission must be granted by the user through real OS UI. On Android, ordinary swipe from Recents is not the same as Android Settings/adb force-stop: force-stopped apps will not receive FCM until opened again. Reboot/device-vendor battery restrictions and network availability also matter; no delivery SLA is asserted.

Manual matrix: background invite/tap; normal-terminated invite/cold-start once; invite then cancel before tap; foreground no duplicate OS+SSE popup; denied permission still permits durable inbox; logout/account switch isolation. iOS/APNs, realtime GPS, background location cadence, memberArrived/upcomingPlace schedulers and all other event types stay deferred.

```text
PHASE_4_3_CLOSED
ANDROID_BACKGROUND_PUSH_READY
ANDROID_PUSH = VERIFIED_ON_SAMSUNG_ANDROID_13
FOREGROUND_DEDUPE = VERIFIED
STALE_CANCEL_OPEN = VERIFIED
IOS_PUSH = DEFERRED
SSE = PRESERVED
POLLING = PRESERVED_12_SECONDS
GPS_REALTIME = DEFERRED
SCHEDULER = DEFERRED
```

Verdict applies to this Android foundation and the verified native scenarios, not iOS readiness, delivery SLA/exactly-once guarantees, or a claim that every manual variant above was executed. Permission-denied/account-switch/accepted/re-invite variants retain their explicit automated-only status until separately checked on devices.
