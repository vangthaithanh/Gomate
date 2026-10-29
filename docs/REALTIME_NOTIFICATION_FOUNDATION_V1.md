# Phase 4.2 - Foreground Realtime Notification Foundation

Date: 2026-10-15. Scope: delivery infrastructure for the existing Trip invitation inbox, not new business rules or UI.

Phase 4.3 extension: user confirmed the three native SSE sanity checks. `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md` adds Android FCM/device registration (V12), preserving this SSE implementation and 12s polling. Phase 4.3 is closed after native background/normal-termination delivery, foreground dedupe and stale-cancel opening were confirmed; remaining automated-only variants are stated in that document. Push-deferred entries below are the Phase 4.2 historical scope. iOS/APNs and realtime GPS remain deferred.

## Audit and decision

- Spring Boot 3.5.11, Spring MVC, JDBC, Resource Server JWT; no existing WebSocket/STOMP/SSE delivery infrastructure.
- Direct/group messages currently use REST; no socket infrastructure to reuse.
- Flutter already uses `package:http`, `AuthService`, API candidate URLs, secure refresh sessions, and one global `NotificationRepository` owned by MainShell.
- Existing foreground reconciliation polls every 12 seconds, refreshes on resume/open inbox, and routes popup taps by notificationId. Preserve this interval and approved f11c6f7 layout.
- Root Compose exposes HTTP 8081 -> API 8080 directly. No reverse proxy or broker is required locally.
- Chosen transport: **SSE**, a small authenticated one-way HTTP stream using dependencies already present. No WebSocket/STOMP package, new infrastructure, dependency, table, or Flyway migration.

References: [Spring MVC streaming/SSE](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-async.html), [Spring transaction-bound events](https://docs.spring.io/spring-framework/reference/data-access/transaction/event.html), [Dart http streamed responses](https://pub.dev/documentation/http/latest/http/Client/send.html).

## Contract

```text
GET /api/v1/notifications/stream
Authorization: Bearer <existing GoMate access token>
Accept: text/event-stream
```

The endpoint derives the user from the authenticated JWT, never from a client user ID. It rejects subscription/query parameters (including query tokens). Initial request uses the existing issuer/audience/expiry/active-session/account validator. Every signal/heartbeat reuses the same JwtDecoder so revoked/expired sessions stop receiving. No token values are logged or put in URLs.

Frames:

```text
event:ready
data:{}

id:<event UUID>
event:notification
data:{"eventId":"<UUID>","eventKind":"CREATED","notificationId":"<inbox UUID>","occurredAt":"<ISO-8601 UTC>"}
```

Kinds: `CREATED`, `UPDATED`, `INBOX_INVALIDATED` (notificationId may be null for whole-inbox invalidation). No full Trip/user/business payload. Event ID is a delivery identity, not an invitation ID or durable replay position.

The stream has a 120-second lifetime, keepalive comments every 15 seconds, `Cache-Control: no-store`, and `X-Accel-Buffering: no`. The client has a 45-second idle watchdog and reconnects after EOF/error. These are transport settings, not a delivery SLA.

## After-commit integration

```text
TripService transaction
 -> persist invitation/member/chat changes as before
 -> NotificationService writes durable inbox or records invalidation
 -> ApplicationEventPublisher publishes an internal Change inside the transaction
 -> successful COMMIT
 -> @TransactionalEventListener(AFTER_COMMIT), fallbackExecution=false
 -> bounded asynchronous SSE delivery to the recipient's authenticated streams
 -> Flutter reads current state from REST
```

Rollback never dispatches the Change to transport. Signals published without an active transaction are ignored by the transactional listener. Transport exceptions after commit are caught and do not change the business result. Queue pressure/disconnected clients are best effort, recovered by REST/polling.

The server stores only ephemeral connection handles. Delivery uses 2-4 daemon workers with a bounded 128-task queue; max 8 connections per user / 1024 per process. Slow/disconnected/overloaded connections can be closed instead of blocking the business transaction. There is no durable event-log or replay table.

Initial integrations only:

| Committed action | Signal |
|---|---|
| Create Trip with selected invitees, or invite into an existing Trip | CREATED to each invitee for its new durable notification |
| Repeat existing PENDING send | No new record/signal |
| Accept | UPDATED to invitee's original invitation notification; CREATED accepted notification to inviter |
| Repeat accepted action | No duplicate success notification/signal |
| Cancel pending invitation | UPDATED for the same recipient notification, no new cancellation notification/popup |
| Repeat cancel | No new state signal |
| Decline existing backend endpoint | UPDATED for existing notification; still no new Decline UI |
| Read/read-all | UPDATED / INBOX_INVALIDATED so other sessions can reconcile read state |

Accept/cancel locking, permission, conflict, membership/chat creation, PERSONAL -> GROUP, and re-invite rules are unchanged. Re-invite uses new invitationId + notificationId; transport eventId is also new.

## Flutter lifecycle and reconciliation

- One receiver in `NotificationRepository`; no transport subscriptions in Home, Map, Trip, Profile, Messages, or individual inbox rows.
- MainShell starts/stops the repository and passes foreground/resume lifecycle as before.
- Login/account switch clears user-scoped inbox/seen/resolved IDs and cancels the previous stream. Generation guards reject late HTTP/events from the previous account.
- Initial load: durable REST baseline first, then SSE; `ready` triggers a second reconciliation to close the REST/connect gap.
- Token rotation reconnects once using the existing refresh/session behavior, without clearing the same account's inbox. The added AuthService adapter does not expose tokens to widgets or change login/Google/Firebase rules.
- Disconnect: reconnect backoff starts at 1 second and caps at 30 seconds. Background/logout/stop cancels reconnect timers and closes the dedicated HTTP client. Foreground resume refreshes REST and reconnects.
- Signals are coalesced for 80 ms. Reconciliation waits for an old poll, performs a fresh REST read, and refreshes signaled notification IDs even if they are outside loaded pages. Signals arriving during reconciliation cause another pass.
- Mutation revisions reject old poll/detail/pagination results that could restore stale PENDING/read state. Arrival order is never used as business authority.
- Store upsert is keyed by notificationId. `_seen` suppresses duplicate popups regardless of polling-first or realtime-first delivery; distinct re-invites are not collapsed. Known initial historical rows are loaded silently, preserving existing behavior.
- Newly discovered CANCELLED/closed invitation history does not show a new cancellation popup. If a visible pending popup becomes closed or the account changes, MainShell dismisses it. Popup layout/buttons are unchanged.
- Pending popup still has no Accept. Tap routes to Notifications/focus by notificationId; only the approved row action calls Accept by invitationId. Server still revalidates all actions.
- Unchanged 12-second foreground polling and manual inbox refresh remain fallback, including transport unavailable, missed events, process restart, and network changes.

## Files

Backend additions:

- `notification/realtime/NotificationSignal.java`
- `notification/realtime/NotificationEventPublisher.java`
- `notification/realtime/NotificationStreamHub.java`
- `notification/controller/NotificationStreamController.java`
- `src/test/java/vn/gomate/NotificationRealtimeTest.java`
- `backend/scripts/verify-notification-realtime.ps1` (disposable local API port 18083 only)

Backend modifications: NotificationRepository (return inserted ID / lookup existing notification references), NotificationService (transactional signals), TripService (call NotificationService at existing write points).

Flutter additions: `notification_realtime_client.dart`, `test/notification_realtime_test.dart`.

Flutter modifications: AuthService (authenticated stream adapter / credential revision), NotificationRepository (single transport lifecycle and reconciliation), MainShell (dismiss obsolete popup only). No Map/Trip/Notification screen layout change.

## Verification

| Check actually run | Result |
|---|---|
| Local Maven `-Dtest=NotificationRealtimeTest test` | PASS, 6 methods covering RT01-RT09 scenarios |
| `docker compose build api` (Dockerfile runs `mvn --batch-mode clean verify`) | PASS, 87 tests, 0 failures/errors/skips; Auth/Google/Firebase verifier, Place/Route, existing Trip/chat/cancellation regression included |
| `flutter test --no-pub` | PASS, 37 tests, including 14 new realtime tests and existing popup/inbox/invitation UI tests |
| `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos` | exit 0, 0 errors, 16 existing warnings + 265 info; no new realtime file diagnostics |
| `git diff --check` | PASS; existing LF/CRLF notices only |
| Docker HTTP/SSE smoke against disposable PostgreSQL/Mongo | PASS: isolated auth, create, cancel, accept recipient+inviter, distinct re-invite, disconnected persistence, reconnect+REST, revoked session rejection |
| Clean PostgreSQL startup | V1-V11 all applied successfully; no V12/table added |
| Existing PostgreSQL startup after API replacement | V1-V11 valid/up to date; health UP; unauthenticated stream returns 401 |
| Native foreground phone / real network toggle | **PENDING USER ACCEPTANCE**, not claimed as performed |

Backend tests assert no transport call before outer commit, none after rollback, no false success for failed/forbidden Accept/Cancel, post-commit DB state, and committed business success with a failing transport. Stream tests use two authenticated users and reject arbitrary recipient selection. Client tests cover FRT01-FRT10, fragmented SSE parsing, account/token changes, resume/reconnect, a signal during an old poll, a stale detail response, and shell stop/start. Existing popup widget tests still verify popup -> Notifications spotlight, no auto accept, and row-only Accept.

The first Docker test run exposed that MockMvc request parameters were not rejected by checking queryString alone. The endpoint now rejects both queryString and request parameters. Local and final Docker suites passed after that fix; the failed build was never deployed.

Measured local API request-to-SSE receive time, including REST verification: invitation create **177 ms**, cancel **30 ms**, accept (recipient + inviter) **71 ms**. This measures the automated Docker HTTP test, not native phone/UI rendering and not a product/network SLA.

Disposable verification API: `gomate-realtime-verify-20261015` on 18083, PostgreSQL/Mongo database `gomate_realtime_verify_20261015`; Firebase/Cloudinary disabled. Fixture result: 3 users, 2 Trips, 3 members, 3 invitations, 4 notifications. Container and both named test databases were removed after verification. No fixtures were inserted into the project DB.

Project DB counts before/after API replacement:

```text
users              37 -> 37
trips               9 -> 9
trip_members       14 -> 14
trip_invitations   16 -> 16
notifications      19 -> 19
conversations       5 -> 5
Flyway             V1-V11 -> V1-V11, all success
```

Runtime deployed using `docker compose up -d --no-deps api`; no volume reset, repair, schema edit, new dependency, or env secret change. Existing API image before replacement: `sha256:25570d93a33b18da6705383e82d7094d61c5138c0fc24ce970a304c41a76251d`. No commit/push performed; unrelated dirty work preserved.

Local generated logs (gitignored):

```text
backups/maven_realtime_notification_test.log
backups/docker_build_realtime_notification_final.log
backups/flutter_realtime_notification_full_test_final.log
backups/flutter_realtime_notification_analyze_final.log
backups/postgres_realtime_notification_smoke.log
backups/docker_realtime_notification_smoke_server.log
```

Development diagnostics: Flutter debug logs show connect/disconnect/reconnect, received event kind, and coalesced reconcile. Backend DEBUG logger `vn.gomate.notification.realtime` shows connection/event IDs and kinds only. Delivery failure warnings exclude tokens/payloads. Heartbeats do not log every tick.

## Operational limits and scope

- Foreground only. Background may suspend/close SSE; restart/resume restores state from REST.
- **BACKGROUND_PUSH = DEFERRED**: no FCM/APNs/device token/OS deep-link implementation in this phase.
- **GPS_REALTIME = DEFERRED**: Phase 3 remains LAST_KNOWN snapshots. No GPS, Map, pin, routing, Settings/Post, or member-lifecycle expansion.
- One Spring process is the current deployment. With multiple API replicas, a transaction on another process may be discovered by polling rather than this process's in-memory stream. Shared pub/sub/outbox/scaling is a future architectural decision, not silently introduced here.
- No replay guarantee, exactly-once transport claim, hard latency SLA, or durable transport history. Correctness comes from PostgreSQL, server action validation, REST reconstruction, idempotent business actions, and client dedupe.
- A future proxy must preserve streaming, disable response buffering for this endpoint, and allow idle time above the 15s heartbeat. Use HTTPS in releases. Keep existing API_BASE_URL/API_BASE_URLS and Android LAN/adb-reverse launch flow; no new hard-coded IP.
- Rollback deployment: restore the previous API image/client code, preserving DB/volumes; there is no schema rollback or Flyway repair for this phase. Polling-compatible REST contracts are unchanged.

## Phone acceptance / verdict

**Hot restart** the running Flutter app (uppercase `R` in the `flutter run` terminal), not only hot reload: the global receiver is created in application initialization. Backend 8081 is already rebuilt/up. Continue using the existing dev launch script/LAN or adb reverse configuration; there is no new port to expose.

1. Keep account B foreground; from another device/API session, A invites B. Expect the existing popup without waiting for a polling tick. Tap -> Notifications, exact pending row focused, no auto accept.
2. A cancels while B's inbox is visible. Expect the same row to become cancelled and Accept to disappear; no new cancellation popup.
3. Invite again, then B accepts. Expect normal GROUP/chat transaction and inviter's accepted notification, not a duplicate invitation.
4. Disable/restore B network or background/resume. Expect REST reconciliation and no duplicate rows/popups. No background/killed-app push expectation.
5. Logout B/login C on the same phone. Expect no B rows/popups in C's session.

```text
PHASE_4_2_CLOSED (implementation + automated integration)
FOREGROUND_REALTIME = READY
FOREGROUND_REALTIME_NOTIFICATION_READY
MANUAL_DEVICE_ACCEPTANCE = PENDING
BACKGROUND_PUSH = DEFERRED
GPS_REALTIME = DEFERRED
```

No later phase is started automatically.
