> SUPERSEDED for current Trip reminders by TRIP_DATE_ONLY_D2_D1_REMINDERS.md (V25). Preserve this document as historical evidence only.

> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip Optional Start Time and T-60/T-30 Reminders

> SUPERSEDED 2026-10-28 by TRIP_DATE_ONLY_D2_D1_REMINDERS.md.
> Trip-level hours and T-60/T-30 are historical only. Current reminders use
> start_date minus 2/1 days at 20:00 Trip local time; do not run both policies.
> Keep the historical implementation/test evidence below unchanged.

## Tóm Tắt Cho Người Kiểm Thử

- Giữ nguyên lịch chọn ngày 2 chạm; ngày quá khứ bị khóa. Vẫn cho phép lịch trình trong một ngày như trước.
- Giờ bắt đầu dự kiến không bắt buộc, nằm cạnh phần chọn ngày. Không chọn thì không tự đặt giờ và không tạo nhắc.
- Chủ lịch trình/nhóm trưởng được sửa, xóa giờ; thành viên chỉ xem. Giờ mới phải ở tương lai; lịch trình cũ vẫn xem và sửa tên được.
- Có giờ hợp lệ thì nhắc trước 60/30 phút cho thành viên thực sự đang tham gia, không cần ghim. Lời mời đang chờ không được nhận.
- Hai mốc là hai thông báo riêng. Sửa giờ không gửi lại mốc đã gửi; xóa giờ chỉ hủy mốc chưa gửi.
- Theo quyết định đã duyệt: reminder đang PENDING bị lỡ khi backend ngừng được gửi muộn nếu vẫn trước giờ dự kiến; có thể nhận cả hai. Tạo/sửa/nhận lời mời sau mốc thì không tạo nhắc bù mốc đó.
- Không thêm Bắt đầu/Kết thúc/Hủy, không thêm công tắc chia sẻ, không thay Map/GPS/Chat/Stop hay nghiệp vụ ghim.
- V17 chỉ bổ sung cột/index/constraint, tái sử dụng `trip_reminders`; không thêm bảng. V1–V16 không đổi; đã sao lưu trước khi cập nhật.
- Backend: 165 test pass. Flutter: 151 test pass. Analyze: 0 lỗi, giữ nguyên 16 warning cũ. APK đã cài lên máy thật.
- Database sạch, database phục hồi và database đang dùng đều lên V17; 24 bảng nghiệp vụ không mất bản ghi khi cập nhật.
- Máy thật đã xác nhận PERSONAL/GROUP, T-60 foreground không trùng, T-30 background/vuốt đóng app, mở đúng lịch trình, MEMBER chỉ xem giờ, xóa giờ và giữ lịch sử. A/B đang ghim lịch trình khác vẫn nhận nhắc; A đăng xuất lúc gửi vẫn thấy inbox khi đăng nhập lại.
- Một số ca biên (đổi ngày qua nửa đêm, leave/remove/archive sát giờ nhắc, lịch sử cũ) đã pass tự động nhưng chưa lặp lại đầy đủ trên điện thoại. Không đồng nhất kiểm thử tự động với nghiệm thu trọn bộ trên máy thật.

Implemented and deployed locally: 2026-10-21. Core Android cases passed;
full edge-case device matrix remains explicitly pending below.
Source: user-supplied CODEX_TASK_TRIP_OPTIONAL_START_TIME_T60_T30_REMINDERS.md.
Final verification/acceptance status is recorded at the end; historical in-progress
entries below are a chronological log, not the final verdict.

## Confirmed Decisions

- No Trip journey status, Start/Complete/Cancel, Share toggle or auto check-in.
- Optional Trip-level plannedStartTime, unrelated to Stop time or PIN/GPS.
- Current accepted members, including unpinned members/pinned elsewhere, receive
  reminders. Pending invitees/removed users do not receive new reminders.
- User explicitly approved pending reminders sending late after API restart,
  provided the planned start is still in the future; both offsets may send.
  This overrides any stricter no-late-delivery interpretation in the attachment.
- Creating/editing/accepting after an offset was already missed never creates
  a catch-up event for that offset. Only already-PENDING records may run late.
- User approved preserving historical Trips/metadata but rejecting a new hour
  on a date in the past. Clearing an old hour remains allowed.

## Pre-Edit Audit

- Branch codex/ui-f11c6f7-invitation-sync; HEAD 738d548. Many dirty/untracked
  files from earlier phases, including Auth/UI/social/Map, preserved.
- Actual main PostgreSQL history: V1 BASELINE, V2-V16 successful. No V17 applied
  at audit. 25 public tables (24 business + Flyway history).
- trips.start_date/end_date DATE NOT NULL; timezone VARCHAR(64) default
  Asia/Ho_Chi_Minh; archived_at TIMESTAMPTZ. No Trip-level hour column.
- Existing CHECK end_date >= start_date. Flutter calendar agrees: same-day
  start/end accepted. This ordering rule is preserved exactly.
- trip_reminders exists in V3: UUID id/trip/recipient, optional trip_stop_id,
  TRIP_START/UPCOMING_STOP, remind_at TIMESTAMPTZ, PENDING/SENT/CANCELLED,
  created_at. Main has 0 reminder rows. Only repository/detail reads existed;
  no reminder writes/scheduler in application code.
- Existing reminder index is recipient/status/time; no offset identity/due
  queue index. Existing UPCOMING_STOP/legacy null-offset rows must remain intact.
- notifications type is VARCHAR(50), no type CHECK; unique
  (user_id,type,entity_type,entity_id). Reminder ID, not Trip ID, distinguishes
  T-60/T-30 without weakening that uniqueness constraint.
- Calendar: TripDateRangeContent in trip_shared_sheets.dart, reused in create
  and detail edit. First tap starts a range, second finishes, an earlier second
  tap changes the start. Past days were not disabled before this task.
- Backend current LEADER edit authority rechecked after Trip row lock; MEMBER
  read-only. Creator of PERSONAL is its LEADER. Keep existing role flow.
- NotificationService/EventPublisher already persists inbox then sends SSE/FCM
  AFTER_COMMIT. FCM whitelist, Flutter parser, popup and tap resolver were
  invitation-only. Polling fallback is 12s. Extend, do not replace these paths.
- Flutter currently has no IANA timezone package. A small authenticated
  GET /trips/time-context?timezone= endpoint provides server Trip wall time for
  date/hour UX. No phone UTC-offset guess, new timezone dependency or polling.

## Implementation Plan / Boundaries

1. V17 adds nullable trips.planned_start_time TIME, and reminder offset_minutes,
   planned_start_at and sent_at; logical unique Trip/user/type/offset plus due
   index. No new table, deletion/backfill or old migration changes.
2. TripPlanningTime uses injectable Clock and ZoneId; strict HH:mm, minute
   precision, authoritative future validation and safe historical metadata edit.
3. Reuse JDBC. TripService synchronizes reminders only for actual date/hour/zone
   change, creation, or a newly accepted member; departure/archive cancel pending.
4. Bounded scheduler reads at most 100 due records per 15s pass, processes each
   transactionally with Trip-before-reminder lock ordering and membership recheck.
   Unique logical IDs and SENT history prevent restart/parallel-worker duplicates.
5. Durable TRIP_START_REMINDER inbox entries reference reminderId; use the
   existing AFTER_COMMIT SSE/FCM and client dedupe. No invitation ID/action.
6. Extend existing Trip UI/model/repository only. Same two-tap calendar/design,
   grey past dates, one optional-hour control next to dates; current role gates.
   Reminder tap resolves server notification + current Trip, never pins it.
7. Frozen-clock backend tests, Flutter regression, real PostgreSQL clean/restore
   migration and API/scheduler verification before main cutover. Device cases
   remain PENDING_MANUAL until actually executed/confirmed.

## Storage and API

Planned migration: V17__trip_start_reminders.sql, after verified V16.
Existing Trip create/detail/list/update APIs carry plannedStartTime HH:mm/null.
PATCH omitting it preserves the stored hour; clearStartTime=true explicitly
clears it, matching the current explicit clearTime Stop patch convention.
No default hour is persisted when the user has not chosen/confirmed one.

Notification payload adds reminderId, reminderOffsetMinutes, plannedStartAt.
The two durable IDs are independent; historical notification bodies/timestamps
remain frozen after SENT. No GPS/private token is included.

## Backups and Verification Status

Ignored local artifacts, never commit: backups/trip_reminder_before_20261021.tar,
trip_reminder_pre_20261021.dump, trip_reminder_before_counts.json (25 exact
table counts) and trip_reminder_old_migration_hashes.json (16 old migrations).
Main application/database remain unchanged until isolated validation and backup
before cutover. Initial compile/test failures are not deployed or called PASS.

Final commands, counts, migration and manual results will be recorded here after
execution. Auto Check-in/memberArrived and per-Stop T-60/T-30 remain deferred.

## Files Added / Changed

Backend new: V17__trip_start_reminders.sql; TripPlanningTime,
TripReminderConfiguration, TripReminderRepository, TripStartReminderService,
TripReminderScheduler; TripStartReminderTest; test-only TripTestClockConfiguration;
scripts/verify-trip-start-reminders.ps1.
Backend integration: TripDtos/TripController/TripRepository/TripService;
NotificationDtos/NotificationRepository/NotificationService/NotificationPushDelivery.
Tests: NotificationPushTest adds reminder delivery/preference; test profile disables
automatic scheduler; historical TripCompletionCancellationTest creates a valid
Trip then sets historical fixture dates only inside test DB. Existing isolated
verify-trip-pin-centric-reset.ps1 similarly adapts fixture creation and accepts
later additive migrations without weakening V1-V16 baseline checks.

Flutter new: TripPlanningContext, TripStartTimeContent; trip_start_reminder_test.
Integration: TripUi/TripCreateDraft/RealTripRepository; CreateTripScreen,
TripDetailScreen, TripDateRangeContent; notification parser/repository/screen,
main_shell popup text; notification_realtime_test adds distinct-offset dedupe.
Docs: this report, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT and live
AGENTS migration pointer after cutover. No new dependency or environment secret.

## Request / Response Contract

Create:
```json
{"title":"Optional reminder example","startDate":"2026-10-25","endDate":"2026-10-25","timezone":"Asia/Ho_Chi_Minh","plannedStartTime":"08:00"}
```
Omit plannedStartTime for truly no hour. Existing same-day rule is preserved.
PATCH {"plannedStartTime":"09:15"} changes hour; {"clearStartTime":true}
clears it; omit both to preserve it. Supplying clear and a value is rejected.
Backend serializes nullable LocalTime (HH:mm:ss); Flutter consistently displays
HH:mm without applying timezone conversion to a local hour. The derived shared
plannedStartAt and notification occurredAt are UTC Instants. No Stop time shifts.
GET /trips/time-context returns timezone/serverNow/localNow/today, authenticated,
only when the user opens a picker. Stopwatch advances that wall time locally;
there is no new timer/poll or implicit phone offset.
DST gaps are rejected rather than silently shifted; DST overlap uses Java's
earlier valid offset. Vietnam default is a named zone, not a fixed UTC+7 formula.

Notification item retains existing fields and adds reminderId,
reminderOffsetMinutes, plannedStartAt; invitationId is null. Historical reminder
tap has tripId=null after membership revocation/archive; Flutter still fetches
current Trip before opening, handling network failure/account switch safely.
Bodies say an offset reminder for a planned start, not a promise that exactly
60/30 minutes remain when approved late delivery occurs.

## Automated Evidence So Far

- docker compose build api: latest build ran 165 tests, 0 failures/errors/skips.
  Includes Auth/password/Google/Firebase, Place, Route, Trip/chat/invites,
  member/leader/archive/location and reminder tests.
- 22 frozen-clock reminder invocations cover null hour, historical edit, current
  minute/date/timezone/midnight, near offsets, accept/leave/remove/archive,
  pin/leadership independence, SENT history, clear/re-arm, expired queue,
  locked accounts, DST gap, rollback, concurrent workers and mutation races.
- Actual clean PG: V1-V17 all SQL/Java migration success; 25 tables.
- Actual restored PG: V1 BASELINE + V2-V17 success; 25 tables. All 24 business
  table record counts equal pre-task backup, history only 16 -> 17.
- Maintained isolated verifier passed on BOTH clean and restored databases:
  API null/hour round trip, past/current-minute validation, member read-only,
  pending invitee exclusion, four notifications (two active recipients x two
  offsets), actual SSE, distinct logical IDs, SENT unchanged after edits/clear,
  independent pin unchanged, fresh authorization after leave.
- Real API stop/start: both PENDING offsets survived downtime and delivered
  before planned start; next scheduler pass did not duplicate them. FCM disabled
  in isolated APIs deliberately, not represented as a physical push test.
- Pin-centric isolated PG/Mongo/Mapbox regression PASS: FG/BG authority,
  last-known after unpin/switch, membership/archive cleanup, SSE, chat, Stop
  interval/reorder/optimize, Auth, Place search/detail/no-media.
  Actual route: 6352.558 m, 873.969 s, 302 geometry points.
- V1-V16 SHA256 compared to pre-task artifact: all 16 byte-identical.
- Initial compile and newly added fixture test failures were fixed and rerun;
  their logs are kept separately, never counted as passing final verification.

Final Flutter/analyze/APK, live cutover/counts and manual statuses below remain
to be updated after those commands/tests finish.

## Performance / Delivery Limits

One bounded batch of at most 100 due rows per 15 seconds with due index.
Trip-before-reminder row locks serialize send vs edit/archive/member changes,
including parallel API instances. No full Trip scan, no per-Trip poll and no
Map/GPS calls. Notification inbox and SENT commit atomically; no FCM call
inside Trip create/edit transaction. Gateway/OS delivery remains best-effort
under existing device/session/preference rules; disabling push keeps inbox/SSE.
Existing FCM channel, 24-hour TTL and bounded delivery queue are reused.
Notifications may reach an offline phone later; tap always checks current access.
A continuously failing row is logged and retried next pass; there is no new
queue infrastructure. Offset scheduling does not create catch-up notifications.

## Recovery

Pre-task source snapshot includes existing dirty changes, not just Git HEAD.
Custom-format PG backups and 25-table counts are ignored artifacts in backups/.
Before live cutover take a fresh consistent backup. The old container image ID
was no longer available to Docker tagging; do not claim it was preserved. The
pre-task source snapshot is retained and is being built in an ignored isolated
recovery folder to verify V16 binary compatibility without touching main data.
Do not use flyway repair, modify old checksums, drop columns/history, or reset
Docker volume. V17 is additive: if runtime regression occurs, stop new API and
run a verified V16 binary rebuilt from the pre-task snapshot against V17 only
as a temporary runtime recovery (new reminder scheduler absent). Optional-hour
requests are then unavailable. Older Flutter builds cannot parse new reminder
types, so keep the updated notification parser/client and prefer a forward fix
after new reminders have been written. Do not claim complete UI rollback simply
because an old API boots. New columns/history can stay; existing queries ignore them.
Any full data restore must first restore backup into a separate database, verify,
then obtain user approval to switch; never overwrite newer business data silently.
For future schema correction use a new migration, not edits to shared V17.

## Device Acceptance

User approved updating backend and installing APK for joint testing.
Physical cases stay PENDING_MANUAL until explicit execution/confirmation:
calendar/two taps/hour guard; optional null/clear; PERSONAL and accepted GROUP
recipients; pending exclusion; unpinned/pinned elsewhere; foreground one popup;
background/normal termination push tap; edit/SENT dedupe; revoke/archive/stale tap;
midnight; existing pin/GPS/chat/Stops/account-switch end-to-end.
No full READY verdict before these gates are closed. Auto Check-in and per-Stop
reminders remain deferred. No Start/Complete/Cancel/share toggle was introduced.

## Final Automated / Live Cutover Results

- Final Flutter suite: 151 passed. Includes real repository null/local-hour/clear
  serialization, MEMBER read-only vs LEADER edit/clear, disabled calendar,
  clock/minute guards and T-60/T-30 SSE+poll dedupe (one popup each).
- Final flutter analyze: 0 errors, 16 existing warnings, 263 infos (279 total).
  Exact normalized diagnostic comparison to pre-task baseline: zero additions.
  Analyze exits 1 for these existing diagnostics; it is NOT a clean-warning PASS.
- Final debug APK build success; installed with adb install -r on ANDROID_DEVICE_SERIAL,
  login data retained; USB reverse 8081 restored and app opened. No hot reload.
- Root compose build api success, final 165 tests passed (0 skipped).
- Main backup immediately before cutover:
  backups/trip_reminder_cutover_20261021.dump + *_before_counts.json.
  API was stopped for the dump/count consistency; PostgreSQL volume not reset.
- Main Flyway after cutover: V1 BASELINE, V2-V17 success; V17 SQL.
  No new business table, still 25 tables including Flyway.
- Main exact counts before -> after:
  users/profiles/settings 38 -> 38 each; refresh_sessions 204 -> 204;
  trips 16 -> 16; trip_members 22 -> 22; trip_invitations 25 -> 25;
  trip_stops 8 -> 8; trip_pins 2 -> 2; trip_reminders 0 -> 0;
  conversations 8 -> 8; conversation_members 15 -> 15; notifications 31 -> 31;
  device_tokens 1 -> 1; places 146 -> 146; place_media 7 -> 7;
  place_categories 6 -> 6; place_tags 36 -> 36; place_tag_links 639 -> 639;
  interest_groups 3 -> 3; interest_options 19 -> 19;
  interest_tag_mappings 53 -> 53; user_interests 46 -> 46; user_follows 2 -> 2.
  Flyway history only: 16 -> 17. No existing Trip was assigned an hour.
- Live GET /places: 200, 146 Places, 7 Cloudinary thumbnails.
  /actuator/health remains protected (401), not represented as a public health
  endpoint or treated as a new bug.
- Temporary clean/upgrade/pin test API containers stopped and removed explicitly;
  isolated verification databases/artifacts retained for evidence only.
- Main Flyway/DB count artifacts: *_cutover_before_counts.json,
  *_cutover_after_counts.json, *_cutover_diff.json. Full test/build logs are
  ignored local artifacts, not version-controlled user/credential data.

Physical confirmation so far:
- User confirmed original two-tap flow unchanged, past dates grey/disabled,
  PERSONAL Trip created with no optional hour and no fake hour in detail: PASS.
- User saved today 2026-10-21 19:30 Asia/Ho_Chi_Minh on that new Trip.
  PG confirms exactly two PENDING offsets at 18:30/19:00 and no own pin.
  Foreground T-60 and background T-30 delivery are being tested, not yet called
  PASS just because schedule persistence succeeded.

Recovery proof completed:
- Original image tag could not be recovered from Docker metadata. Instead the
  pre-task backend source was extracted ONLY under ignored
  backups/trip_reminder_v16_recovery/backend, with unchanged pom.xml, and packaged
  using Maven -DskipTests. This is a recovery build, not additional passing tests.
- Rebuilt V16 binary was mounted read-only into a temporary API pointed ONLY at
  the isolated V17 upgrade DB. Flyway accepted future V17 with its normal warning;
  API started, GET /places returned 200 and 146 records. No repair/schema rollback.
- Recovery JAR SHA256:
  26C65F565FC3D027F82401EA4F0AC1BBE53E6A6C2057F2F9CF5D06ECFA3AF120.
  Temporary API was stopped and auto-removed. Main stayed on V17 throughout.
- This proves bootstrap/database compatibility only, not complete old-client
  notification compatibility. Forward fix remains preferable after V17 writes.

Device evidence at 18:30:
- T-60 SENT and inbox committed at 18:30:10.738 Asia/Ho_Chi_Minh.
- Gateway logged FCM SENT at 18:30:11 for the same notification ID.
- T-30 remains PENDING at 19:00; no automatic pin. User foreground popup/no
  duplicate confirmation is still pending; gateway SENT alone is not delivery QA.

Physical confirmation at 18:31-18:32:
- User confirmed T-60 foreground: exactly one in-app popup, no duplicate Android
  notification, no repeated popup after 15s: PASS.
- User edited planned time from 19:30 to 19:05 and pressed Home: PASS.
  Read-only PG check: same SENT T-60 still keeps 19:30 snapshot and original
  sent_at; same unsent T-30 is now due 18:35 for new planned 19:05.
- ADB topResumedActivity was Samsung Launcher, not GoMate, before background test.
  No pin or clock override used. Background T-30/tap remains PENDING_MANUAL until
  actual device confirmation.

Device evidence at 18:35:
- T-30 SENT/inbox commit at 18:35:10.777 Asia/Ho_Chi_Minh, FCM SENT at 18:35:11.
- Repeated scheduler passes still show exactly two logical reminder rows, one
  notification per offset, no Trip pin. T-60 sent_at never changed after edit.
- Background OS display/tap is awaiting user confirmation; not inferred from
  FCM SENT. No production clock change or manual queue/notification mutation.

Physical confirmation at 18:35-18:38:
- User confirmed Android T-30 notification appeared, tap opened the correct Trip
  Detail, no automatic pin and no invitation Accept action: PASS.
- User confirmed today's 08:00 cannot be saved; modal rejects it safely.
  Selecting "Khong chon gio" clears optional hour; detail shows no invented
  default; both earlier notifications remain visible: PASS.
- Server read-only verification after clear: planned_start_time=NULL, two SENT
  reminder rows retained, exactly two notification records. No new pending event.
- Data created deliberately through user UI during this verification:
  +1 PERSONAL Trip and its owner membership; +2 reminder rows; +2 inbox entries.
  Relative to cutover, trips 16 -> 17, members 22 -> 23, reminders 0 -> 2,
  inbox 31 -> 33; pins stay 2. These are test interactions after cutover,
  not migration data changes; no test data is silently deleted.
- GROUP multi-account and normal-termination reminder-specific device cases
  remain PENDING_MANUAL until additional user-led testing; automated accepted/
  pending/revoked membership, push eligibility and lifecycle cases already pass.

GROUP physical test setup (user chose to continue):
- User created a separate "Test nhac GROUP 21-10" through Flutter, start today
  19:16. At creation time T-60=18:16 was already past: only future T-30=18:46.
- Read-only check BEFORE acceptance: invite PENDING and invitee reminder count=0;
  owner's one T-30 PENDING. No direct membership/chat for pending invite.
- User switched A -> B, accepted, confirmed MEMBER can view 19:16 but cannot
  edit, did not pin, then Home + swipe GoMate from recents (not Force Stop).
- PG AFTER acceptance: GROUP, active LEADER+MEMBER, one PENDING T-30 each at
  the same UTC instant, both not pinned to this Trip. ADB shows Launcher foreground.
  Delivery/tap after normal termination is still awaiting the actual due instant.

## Final Device Results / Acceptance Boundary

GROUP at 18:46:
- Two inbox notifications committed independently for active LEADER and MEMBER
  at 18:46:10.835 and 18:46:10.816 respectively. Exactly one per recipient.
- B's FCM gateway SENT at 18:46:11.320. A was logged out, so no OS push for A
  was expected; its durable inbox was still written.
- User confirmed B received Android notification after swiping GoMate out of
  recents, tap opened the correct GROUP exactly once, time remained read-only,
  no automatic pin: PASS.
- User then logged B out / A back in and confirmed A's inbox reminder opens the
  correct GROUP as Leader, still two active members: PASS.
- Read-only pin check: BOTH members were actually pinned elsewhere during the
  reminder test. Neither pin was replaced. This is physical/account evidence of
  pin-independent reminders, not only a mocked no-pin assertion.
- Android process PID remained cached before delivery; report normal recents
  termination truthfully, not a separately proven full process-death/Force Stop
  case. Force Stop was not used and is not promised to receive FCM.

Acceptance matrix:
| Case | Result |
|---|---|
| Original two-tap date flow, disabled past dates, today hour guard | DEVICE PASS |
| Optional absent hour / selected hour round trip / clear / retained history | DEVICE PASS |
| PERSONAL T-60 foreground + T-30 background, no duplicates | DEVICE PASS |
| GROUP actual Leader+accepted Member inbox / MEMBER push and readonly time | DEVICE PASS |
| Pending invite has no schedule; accept adds only future T-30 | LIVE DB + DEVICE FLOW PASS |
| Both members pinned elsewhere; no auto pin / GPS switch | LIVE DB + DEVICE FLOW PASS |
| Normal recents termination, correct authorized Trip tap once | DEVICE PASS (cached process caveat above) |
| Logged-out Leader receives durable inbox on later login | DEVICE PASS |
| Clear pending rather than already SENT | AUTOMATED PASS; PENDING_MANUAL |
| Leave/remove/archive racing due event and stale tap on phone | AUTOMATED/ISOLATED PG PASS; PENDING_MANUAL |
| Historical Trip metadata edits on phone | AUTOMATED PASS; PENDING_MANUAL |
| Midnight/timezone device UX and actual night delivery | FROZEN CLOCK PASS; PENDING_MANUAL |
| Every Map gesture/chat/stop regression on physical device in this new build | AUTOMATED + REAL PG/MAPBOX PASS; PENDING_MANUAL |

Milestone labels, under the attachment's strict full-device acceptance rule:
- TRIP_DATE_VALIDATION_READY
- TRIP_OPTIONAL_START_TIME_READY
- TRIP_START_REMINDER_BLOCKED: acceptance-only, because the PENDING_MANUAL edge
  cases above have not all been physically repeated. No known failing
  implementation case after the executed tests. Code is deployed and the main
  PERSONAL/GROUP reminder flows are proven on the device; do not describe the
  entire Android matrix as fully accepted yet.

No business ambiguity remains from the two questions: approved late-PENDING
delivery before planned start and safe historical-date edit rules are implemented.
No further code/DB mutation is required merely to finish those manual checks.
No commit/push/reset or Docker-volume deletion was performed. V1-V16 immutable.
Two user-created test Trips and their notifications/history are intentionally
retained, not silently deleted. The user can delete them using normal Trip UI.

Final live counts AFTER user-led tests (not migration deltas):
trips 18, trip_members 25, conversations 9, conversation_members 17,
trip_invitations 26, trip_reminders 4 (all SENT, 0 PENDING), notifications 37,
refresh_sessions 208, users 38, trip_pins 2. New rows reflect two test Trips,
one invitation+acceptance/group chat, four reminders and normal account switches.
The separate cutover count comparison still proves all original business rows
were retained before these manual actions. No further reminder is pending for
the two test Trips; nothing was purged.










