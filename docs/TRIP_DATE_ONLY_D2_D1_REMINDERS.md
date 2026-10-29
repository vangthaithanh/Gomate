> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip Date-Only D-2/D-1 Reminders

Source: owner-approved CODEX_TASK_GOMATE_TRIP_DATE_ONLY_D2_D1_20H_REMINDERS.md,
2026-10-28. Supersedes V17 Trip optional hour / T-60/T-30, including the old
permission to send both overdue offsets. No other Trip/Post/DM business changes.

## Contract

- Trip create/update/list/detail use dates and IANA timezone; no plannedStartTime
  or clearStartTime field. Existing unknown-field validation rejects old inputs
  with 400. The legacy DB hour column is preserved, never used or overwritten.
- Original two-tap calendar, same-day Trip, past-date guard, historical metadata
  editing, LEADER permissions and all Stop time intervals remain unchanged.
- D-2: startDate minus two calendar days at local 20:00, preparation/date copy.
  D-1: previous day at local 20:00, tomorrow/preparation copy. No start-day reminder.
- Pin/view/unpin/switch/GPS never reschedule or suppress reminders. Only actual
  accepted/active members with active accounts/non-archived Trips receive them.
- Create/edit/accept/cutover: strictly future milestones only. No retrospective
  creation for missed slots. Already-PENDING downtime can deliver after 20:00
  only on that same scheduled local date; cancel after midnight. Never combine
  yesterday's D-2 with today's D-1. Timing is scheduler resolution, not an exact
  second delivery guarantee; existing provider/OS best-effort delivery remains.
- Instant calculations use server Clock + ZoneId, calendar arithmetic (not 48h
  subtraction). DST overlap chooses the earlier valid offset; nonexistent local
  20:00 is skipped, never silently shifted into another time/date.

## Storage and Cutover

Audit: live/source V24, 37 business tables, 18 Trips, 4 SENT old reminders,
0 old PENDING reminders. All current Trips have historical start dates; no
reminders are revived for them. Initial ignored backup/counts/hashes and V24 JAR:
backups/trip-date-reminders-20261028/. Docker image tagging was unavailable;
the old running JAR was copied instead. No claim of a preserved old image tag.

New V25__trip_date_reminders.java adds only four nullable metadata columns to
trip_reminders: days_before, trip_start_date, reminder_date, reminder_timezone.
New rows: days_before 2/1; reminder_type TRIP_START, old offset_minutes and
planned_start_at null. CHECK distinguishes these from legacy rows. New unique
(trip_id,recipient_user_id,reminder_type,reminder_date) caps a date to one row.
Cancelled unsent rows may be re-armed for that same date, SENT rows never change.
A send also checks SENT timestamps within the current Trip-local day, guarding
timezone edits against a second send that day. No new table or infrastructure.

V25 cancels all legacy PENDING TRIP_START rows and backfills future-only milestones
for eligible memberships using database current time. No recurring Trip scan.
Legacy SENT rows, Inbox content/IDs, hour columns and Stop times are retained.
Existing status/time/id queue index and bounded 100-row / 15s scheduler reused.
Writers lock Trip then reminder; Inbox and SENT share a transaction, SSE/FCM after
commit. Old T-60/T-30 rows are excluded from the active scheduler.

Notification type remains TRIP_START_REMINDER, with new nullable fields
reminderDaysBefore, tripStartDate, reminderDate, reminderTimezone. Historical
reminderOffsetMinutes/plannedStartAt remain readable on OLD notifications only.
Tap rechecks current membership/archive through existing Detail, never auto-pins.
No changes to invitation/follow/Post/DM delivery or Home media invalidation.

## Verification

Implemented and deployed locally to V25. Android D-2 foreground, D-1 background
and process-dead cold-start delivery/taps passed with owner confirmation below.
The scoped push read-ACK fix also passed on the real device. Remaining native
variants are explicitly listed below; do not reuse old minute-reminder acceptance.

- Full Flutter suite: 289 PASS. Analyze: 0 errors, 15 warnings identical to the
  saved prior full analyze after normalizing line numbers (no new warnings);
  359 total diagnostics, exit 1 for existing lint. Not a lint-clean PASS.
- Android debug APK build PASS (208.4s). APK not installed for this task;
  actual D-2/D-1 foreground/background/terminated delivery remains PENDING_MANUAL.
- Pre-cutover hashes confirm all 24 existing migration files byte-identical.
- Early test runs caught a helper shadowing MockMvc status(), a Flyway assertion
  counting H2's schema-creation metadata as a version, and a UTC expected-date
  typo in the DST test. These test issues were corrected without weakening the
  business rules. Failed initial logs are retained separately; final backend and
  actual PostgreSQL results will be reported only after their completed reruns.

### Final backend, database and cutover results

- Full Maven verify/package PASS: 247 cases, 245 PASS / 2 conditional real-Mongo
  cases skipped in the normal suite. Ran those two separately against dedicated
  scratch Mongo databases: 2 PASS / 0 skipped, with scoped test cleanup. Total
  distinct backend cases verified: 247 PASS across the two runs, not an inflated
  sum of repeated builds. Includes Auth/Google/Firebase/Profile/relationship,
  Post interaction/media permissions, DM/Share, Moments, Place/Route, Trip/Stop,
  invitations/leader/location and notification transport regression.
- Date reminder tests: 23 PASS. Flyway migration tests: 2 PASS. Cover exact
  26/27 October 20:00 for an October 28 start; no hour needed; no start-day send;
  create/accept after deadlines; same-date-only downtime; Pin/view/unpin/switch;
  date/zone edits and immutable SENT body; actual member vs pending/declined;
  leave/remove/archive; locked recipient; parallel workers and mutation races;
  after-commit/rollback; DST calendar arithmetic and ignoring old minute rows.
- Root docker compose build api PASS (verified exit code 0). Its normal test
  suite has the same conditional Mongo skips. BuildKit clipped the noisy test
  log after 2 MiB; the complete separate Maven log holds the explicit test totals.
- Real PostgreSQL 16 CLEAN: V1 -> V25 PASS, 37 business tables. UPGRADE: restored
  V24 -> V25 PASS. Added ONLY an isolated future Trip fixture with a legacy hour,
  timed Stop, Pin, old SENT/Inbox and old PENDING minute reminder to prove cutover.
  The old pending row became CANCELLED; two future day reminders were added.
  Every other table count and hashes of Trip/Stop/Member/Pin/chat/SENT/Inbox
  snapshots matched. Actual legacy hour and Stop interval remained identical.
- HTTP verifier PASS on both PostgreSQL databases: date-only create/same-day Trip,
  exact local20/date/zone metadata, accepted-member scheduling, pending exclusion,
  MEMBER edit denied, removed-hour keys 400, unchanged identities across
  Pin/view/unpin/title edit, real API restart with persisted queue, leave/archive
  cancellation and no early notification. Deadline dispatch uses the frozen-clock
  tests; real Android delivery is not inferred from HTTP or mocked FCM.
- Fresh consistent backup made with normal API stopped immediately before main
  cutover: ignored cutover.dump, counts and hashes in the artifact directory.
  Main V24 -> V25 PASS; health UP. Existing 24 migration files remain byte-identical.

| Main database entity | Before | After |
|---|---:|---:|
| Business tables | 37 | 37 |
| Trips | 18 | 18 |
| Trip members | 25 | 25 |
| Stops | 6 | 6 |
| Pins | 1 | 1 |
| Conversations | 9 | 9 |
| Old SENT reminders | 4 | 4 |
| Inbox notifications | 49 | 49 |
| Flyway versions | 24 | 25 |

All 37 business-table counts matched, not just the rows listed above. Historical
Trip/Stop/Pin/Member/chat/SENT/Inbox hashes matched as well. Main had no legacy
PENDING rows; cancellation was exercised by the isolated upgrade fixture. All
18 main Trips start in the past, so backfill correctly produced zero reminders.
No production demo/test writes, new Cloudinary assets, DB reset or schema repair.
Only standard api/postgres/mongo/ai containers remain running; temporary APIs and
Maven containers were removed. Scratch PostgreSQL databases are isolated audit
artifacts, not an additional business source of truth.

## Files and API impact

- New: backend/src/main/java/db/migration/V25__trip_date_reminders.java,
  backend/src/test/java/vn/gomate/TripDateReminderMigrationTest.java,
  backend/scripts/verify-trip-date-reminders.ps1 and this report.
- Backend: TripDtos, TripService, TripRepository, TripPlanningTime,
  TripStartReminderService, TripReminderRepository; NotificationDtos,
  NotificationRepository and NotificationService. Existing scheduler, transport,
  controller routes and notification permission model reused.
- Tests: TripStartReminderTest rewritten for the superseding policy;
  NotificationPushTest day fixtures; TripApiTest archive count preserves all
  reminders including the new automatic day slots.
- Flutter: create_trip_screen.dart, trip_detail_screen.dart, trip_repository.dart,
  trip_ui_models.dart, trip_planning_context.dart and gomate_notification.dart;
  trip_start_reminder_test.dart and notification_realtime_test.dart. Removed the
  now-unused trip_start_time_content.dart. No shared shell/DatePicker/Post/Map UI
  redesign, Stop-time or dependency/config change.
- Live docs: AGENTS, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT; V17 report
  marked SUPERSEDED without deleting history. Historical V17 verifier now refuses
  execution and points to the V25 verifier instead of exercising old hour logic.
- Existing POST/PATCH/GET /api/v1/trips contracts remove Trip-level hour fields;
  passing plannedStartTime/clearStartTime returns existing controlled 400. Existing
  /time-context remains for calendar server dates. Notifications add nullable
  reminderDaysBefore/tripStartDate/reminderDate/reminderTimezone; existing fields
  for historical notifications and every non-Trip notification stay unchanged.

## Android handoff — PENDING_MANUAL

New APK: build/app/outputs/flutter-apk/app-debug.apk, SHA256
228C4983C84A7300748BC0E5947BD949F09D04B4B1C274BFEA0806B65CF198D4.
Built only in this task; no phone install/restart, permission change or device
clock manipulation. Install the new APK or fully rerun Flutter before checking
the removed hour field; an already running old APK still has the old UI.

Manual checklist for a real future Trip: Create/Detail/Edit show dates only;
two-tap picker, past-date guard and Stop intervals unchanged. D-2 and D-1 local
20:00 reach the owner/accepted member with foreground single popup, background
and normal-termination push; tap opens authorized Detail without pinning. Pin
after D-2 must not suppress D-1. Day/date timezone boundaries, stale membership
tap and device/account changes remain PENDING_MANUAL for this new policy.
No implementation blocker remains. Stop after this task, no next phase started.

## Guided Android follow-up — 2026-10-28

Owner installed the new APK, opened GoMate signed in as Thanh and explicitly
requested joint notification tests. Verified USB ANDROID_DEVICE_SERIAL, 8081->8081 reverse,
GoMate TOP, API health UP, live V25 and one eligible Thanh Android push binding.
At preparation the real server showed 21:27 Vietnam; today's Vietnam20 was past.
Owner approved a separate Trip in Asia/Kolkata to test its real local20 at 21:30
Vietnam, without changing device/server clocks or reminder deadlines directly.

Authenticated only the dedicated existing GoMate Test Realtime actor through its
normal login. At server 14:29:22 UTC created real Trip
REDACTED_UUID, title
"[TEST D2] Trip 30-10 - 20h Kolkata", start/end 2026-10-30, timezone Asia/Kolkata.
Invitation to Thanh: REDACTED_UUID. Initial read-only check:
invitation PENDING, only owner has D-2/D-1 rows; pending Thanh has no reminder.
Due instants: 2026-10-28/29 14:30 UTC, local20 on each scheduled date.
Asked owner to accept before the first deadline, return Home and remain unpinned.
No fake accepted membership, impersonated Thanh session or direct scheduling SQL.
This preparation is not a native reminder-delivery PASS; confirmation pending.
- Owner reported acceptance and Thanh Home open. Server invitation responded_at
  is 2026-10-28 14:30:07.861329 UTC, ~8s AFTER local20 deadline. Correctly no
  D-2 row or Inbox notification for Thanh; D-1 scheduled for Oct29 14:30 UTC.
  Dedicated owner D-2 fired naturally at 14:30:11 UTC, one Inbox record
  REDACTED_UUID, reminder
  REDACTED_UUID. Thanh has no pin on this Trip.
  This verifies late-accept exclusion, NOT positive phone reminder delivery.
  No manual time/deadline changes or forced catch-up were made. Offered next
  real20 slot Asia/Karachi (22:00 Vietnam), pending owner's timing preference.
- Owner explicitly chose tonight's 22:00 Vietnam test and approved changing only
  this controlled Trip to Asia/Karachi. At 21:32 Vietnam updated timezone/title
  through the dedicated owner's real PATCH API; no direct scheduling SQL.
  Verified Thanh D-2 PENDING Oct28 15:00 UTC and D-1 PENDING Oct29 15:00 UTC.
  The dedicated owner's already-SENT Kolkata D-2 row and original Inbox body
  remained unchanged; no second same-day reminder for that owner. Both future
  D-1 rows recalculated to Karachi20, preserving row identity.
- Created one-time current-chat follow-up for 21:58 Vietnam to check user/device
  readiness before the natural22 deadline. Automation id
  ki-m-th-trip-d-2-gomate-l-c-22-00, ACTIVE, one occurrence. It must not force
  delivery, mutate business state or claim native PASS without confirmation.
  Positive Android D-2 delivery is still PENDING_MANUAL until the actual test.
- At the scheduled 21:58 follow-up, verified USB/reverse, API health UP, accepted
  Thanh membership, no test-Trip pin, D-2 PENDING exactly Oct28 15:00 UTC and D-1
  still PENDING Oct29 15:00 UTC. Android Launcher was TOP, not GoMate. Asked owner
  to open Thanh Home before22; no agent app launch or business write. Deleted
  the completed one-time chat-readiness automation to avoid stale follow-ups;
  the real Spring reminder and its due time were not changed/cancelled.
  Positive phone delivery remains pending owner readiness and actual deadline.
- Owner confirmed Thanh Home open. Native logs show SSE connect at 22:00:04
  Vietnam, reconcile22:00:05 and device registration22:00:06, before dispatch.
  D-2 fired naturally at 22:00:11.167588 Vietnam; reminder
  REDACTED_UUID became SENT. Exactly one Thanh Inbox row:
  REDACTED_UUID, created22:00:11.165387, preparation copy
  with start date30/10/2026. FCM SENT; native SSE CREATED at22:00:13.006.
  GoMate TOP verified, no matching OS tray record at22:00:45 sample, no agent
  app launch. Thanh test-Trip pin remains0; D-1 Oct29 15:00Z remains PENDING.
  This is real scheduler/transport evidence, not physical popup acceptance.
  Asked owner to confirm one in-app popup/no OS duplicate/no repeat/correct date.
- Owner confirmed all four foreground D-2 checks: one in-app popup, correct
  preparation/start-date copy, no duplicate Android notification, no repeat
  after approximately15s. Foreground D-2 real-device delivery is PASS.
  Notification tap/current authorization/no-auto-pin remain to be checked;
  background/terminated and next-day D-1 remain PENDING_MANUAL.
- Owner confirmed tapping the22:00 Inbox reminder opens the correct controlled
  Trip with date30/10, no invitation Accept action and no automatic pin.
  Read-only server verification: notification37b4649f-90c7-443a-a038-51d6581d819d
  is_read=true, Thanh test-Trip pin count0, D-2 SENT, tomorrow's D-1 still PENDING
  at Oct29 15:00 UTC. Reminder tap/no-auto-pin is physical PASS. No extra send,
  date/zone modification or pin operation occurred during this check.
- Owner chose next native background test tonight22:30 on a separate Trip.
  At server15:06:07 UTC the dedicated actor created
  REDACTED_UUID, title
  "[TEST D1 NEN] Trip 29-10 - 20h Kabul", start/end2026-10-29, Asia/Kabul,
  invitation64b05f72-7e35-4ea8-b1c2-d1b198f99dcc to Thanh. Owner accepted via UI;
  server responded_at15:06:30.064275 UTC, Thanh test-Trip pin0. Read-only check:
  exactly one D-1 per active recipient (dedicated LEADER and Thanh MEMBER),
  both PENDING Oct28 15:30 UTC =20:00 Kabul =22:30 Vietnam. No D-2 was created
  because its deadline had already passed. No forced catch-up or SQL write.
- Created one-time chat follow-up at22:28 Vietnam, automation
  ki-m-th-d-1-ch-y-n-n-gomate-l-c-22-30, to request Launcher/background readiness.
  D-1 background delivery/tap remains PENDING_MANUAL. Karachi Trip's tomorrow
  D-1 and all previously SENT notifications remain unchanged.
- Scheduled22:28 check: USB/reverse8081, API UP, Thanh invitation ACCEPTED,
  test pin0. Thanh D-1 REDACTED_UUID is PENDING at
  Oct28 15:30 UTC. GoMate was TOP, so asked owner to press phone Home and keep
  Thanh signed in/background before22:30, without closing/pinning. No agent
  app launch or business mutation. Completed one-time readiness automation
  deleted; actual Spring D-1 reminder retained. Awaiting background readiness.
- Owner confirmed pressing Home/background with Thanh signed in. At22:29:18
  Vietnam, ADB verified Launcher TOP before the deadline. D-1 reminder
  REDACTED_UUID still PENDING, no Inbox row yet. Asked
  owner to remain backgrounded and not tap immediately. No agent app launch,
  clock/deadline manipulation or extra notification send.
- D-1 naturally SENT at22:30:11.256466 Vietnam for Thanh, reminder
  REDACTED_UUID. Exactly one Inbox notification
  REDACTED_UUID, created22:30:11.255614, tomorrow29/10
  preparation copy; FCM SENT. Launcher TOP remained verified after dispatch.
  Android dumpsys observed matching notification tag on the existing
  gomate_invitations_v1 channel. Test-Trip pin remains0; no agent app launch.
  Asked owner to confirm one visible Android push and tap correct Trip/date once,
  with no Accept action or auto-pin. Native acceptance remains pending reply.
- Owner confirmed all D-1 background checks: exactly one Android push, correct
  Trip/date29/10 opened once, no invitation Accept and no automatic pin.
  Read-only confirmation: Kabul test-Trip pin0. Inbox
  REDACTED_UUID still had is_read=false at this sample;
  do not claim a server read ACK. D-1 background delivery/correct navigation is
  physical PASS; inspecting the distinct push-tap read acknowledgement path.
  Karachi Trip's next-day D-1 remains PENDING Oct29 15:00Z; it was not cancelled
  by viewing notifications or testing another Trip. New-policy terminated-app
  delivery and pin-between-D2/D1 across real dates remain PENDING_MANUAL.
- Scoped follow-up: inspection found _resolveFocus (Android push entry) marked
  Post notifications read but not TRIP_START_REMINDER before opening Detail.
  Inbox-row taps already used the real read API. This explains is_read=false
  despite correct background push navigation; do not label read ACK physical PASS.
  Added the same awaited read ACK ONLY to the Trip-reminder push branch, with
  mounted/account checks before navigation. Accepted invitations, Post/Follow/DM,
  scheduler, schema, dates, Pin, UI layout and transport behavior are unchanged.
- Two regression cases reproduced missing ACK before the patch, then passed:
  read ACK before current Trip lookup, and failed ACK must not pretend read/open.
  Including notification push/realtime/UI/Post regressions, 64 targeted Flutter
  tests PASS. Scoped analyze: 0 errors, 3 existing warnings (normalized comparison
  to prior full analyze has no new warnings), 11 diagnostics total; exit1.
  New APK build in progress; no phone install or backend restart for this fix.
- Read-ACK hotfix APK build PASS (132.8s). Not installed by the agent; native
  read-ACK retest remains PENDING_MANUAL. Existing foreground/background delivery
  acceptance above applies to the owner's previously installed build. The new
  artifact at build/app/outputs/flutter-apk/app-debug.apk supersedes the earlier
  V25 APK for future installation; hash stored in ignored push-read-apk.sha256.
  Main API health UP and Karachi D-1 Oct29 15:00Z still PENDING after the fix.
- Owner chose a23:00 Vietnam terminated-app test and will install the new APK
  personally. At server15:41:24 UTC the dedicated actor created controlled Trip
  REDACTED_UUID, title
  "[TEST D1 DONG APP] Trip 29-10 - 20h Dubai", start/end2026-10-29,
  timezoneAsia/Dubai. Invitation REDACTED_UUID to Thanh.
  Initial owner-only D-1 PENDING Oct28 16:00 UTC; no overdue D-2 created.
  Asked owner to install, retain Thanh login, accept and remain unpinned.
- Created one-time22:56 readiness follow-up for cold-start preparation before23:00,
  ki-m-th-d-1-kh-i-ng-ngu-i-gomate-l-c-23-00. Process-dead state must be observed
  before send; do not equate a Recents swipe with process termination or use
  Force stop. User installation/acceptance/cold-start/read ACK remain pending.
- Owner confirmed installing the new read-ACK APK personally, retaining Thanh,
  accepting the Dubai invitation and not pinning. Read-only preparation check
  confirms accepted membership, one Thanh D-1 queued for23:00 Vietnam and no
  Dubai test-Trip pin; eligible Android push binding checked without reading its
  token. Wait for the scheduled22:56 cold-start preparation; no early send or
  agent app/process intervention. Delivery/read-ACK native results still pending.
- At22:56 scheduled preparation: USB/reverse8081 and API UP; new install timestamp
  22:43:47, POST_NOTIFICATIONS granted, package stopped=false. Dubai invitation
  ACCEPTED, Thanh has0 pins and1 eligible Android binding. D-1 reminder
  REDACTED_UUID still PENDING at Oct28 16:00 UTC.
  GoMate PID12652 was alive, so no cold-start claim. Asked owner to Home/swipe
  from Recents, not Force stop, and wait for process verification before23:00.
  Deleted completed one-time chat readiness automation; Spring reminder unchanged.
- Owner confirmed normal Recents swipe/Launcher. At22:59:01 Vietnam verified
  Launcher TOP, GoMate PID absent and package stopped=false before the deadline.
  Dubai D-1 REDACTED_UUID remained PENDING for23:00.
  This establishes real process-dead/non-Force-stop preparation. No ADB process
  termination, user impersonation or agent launch was needed; wait for natural send.
- Dubai D-1 naturally SENT23:00:11.389296 Vietnam. Exactly one Thanh Inbox row
  REDACTED_UUID, created23:00:11.388292, tomorrow29/10
  preparation copy; FCM SENT23:00:11.873. Android observed that exact tray tag
  on existing gomate_invitations_v1; Launcher stayed TOP, test-Trip pin0.
  GoMate process appeared after delivery, consistent with background FCM handling;
  its absence was proven before send, not assumed from a swipe. No agent launch.
  Asked owner to tap and confirm real cold-start/retained Thanh/correct Detail
  once/no Accept/no auto-pin. Read flag was false before tap, as expected;
  native navigation/read-ACK confirmation still pending.
- Owner confirmed Dubai23:00 notification opened GoMate from closed state,
  retained Thanh login, opened correct Trip/date29/10 exactly once, without
  invitation Accept or automatic pin. Follow-up SQL verifies notification
  REDACTED_UUID is_read=true, exactly one Inbox row and
  Dubai test-Trip pin0. Cold-start delivery/navigation and the scoped read-ACK
  hotfix are physical PASS; no fabricated read update or resend was used.

### Current physical acceptance — 2026-10-28

| Case | Physical result |
|---|---|
| D-2 foreground at22:00 Vietnam / Karachi20 | PASS: single popup, correct preparation/date, no OS duplicate or repeat |
| D-1 background at22:30 Vietnam / Kabul20 | PASS: Android notification, correct Trip/date once, no Accept/auto-pin |
| D-1 process-dead at23:00 Vietnam / Dubai20 | PASS: Android notification, retained Thanh, correct cold-start navigation once |
| Read ACK from Android Trip-reminder tap | Initial bug found on background run; scoped fix tested and physical PASS on cold-start run |
| No automatic pin on reminder navigation | PASS, confirmed in UI and SQL for the controlled Trips |
| Late acceptance after first deadline | Server-confirmed no D-2 catch-up, only future D-1 for Thanh |
| Timezone edit after owner's D-2 SENT | Stored SENT/Inbox unchanged and no repeat for that owner; Thanh's future slot recalculated correctly |

Read-ACK hotfix artifact installed by owner: SHA256
687AF89B5720AE5F7E4BEF6B00645282A445B29177E17DDD7D294013E99992CA.
64 targeted Flutter tests PASS, no new analyze warnings; no backend/schema change.

Remaining new-policy physical cases: PERSONAL owner delivery; same Trip across
real D-2/D-1 dates with pin/unpin/switch between them; Vietnam20 specifically;
membership/archive races and timezone/DST date edges. Automated coverage already
passed, but these are not all separately tested on the phone. Karachi Trip's
Thanh D-1 remains naturally PENDING at22:00 Vietnam on2026-10-29. Do not cancel
or claim its next-day result without an actual run. All one-time chat readiness
automations from tonight were deleted after use; Spring reminders were retained.
Controlled test Trips/history remain in the app; no silent cleanup was performed.

## Recovery

No reset/volume deletion/Flyway repair/old migration edits. Validate failures on
an isolated restored DB first and fix forward. Preserve new writes; never restore
the backup onto the live DB silently. A V24 runtime would have old reminder
semantics, so it is not a supported rollback for this new business rule; stop
delivery and diagnose/fix forward instead of reactivating T-60/T-30.
