> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip Pin-Centric Business Reset

> 2026-10-21 clarification: MAP_PIN_SWITCH_LAST_KNOWN_FIX.md supersedes this
> report's UNPIN/switch snapshot-deletion and pinned-only-read rules. UNPIN stops
> GPS but retains the actual last-known position for current Trip members.
> Leave/remove/delete still revoke/clean scoped positions. Explicit pin ACK now
> immediately selects the new Trip on Map. V16/history below are unchanged;
> the measurements below describe the original 2026-10-16 implementation.

User-approved contract, 2026-10-16. Supersedes Phase 4.5/4.6 journey/Share rules.
Automated verification and PostgreSQL cutover completed. Physical Android acceptance is recorded separately below.

## Business Truth

- Want to use/go on a Trip: PIN. Want to stop publishing: UNPIN.
- Want the Trip gone: DELETE, a separate existing Leader operation.
- No Trip journey status, Start, Complete, Cancel or Share ON/OFF switch.
- PERSONAL/GROUP, active membership, LEADER/MEMBER, invitations and soft archive
  remain distinct business concepts. Stop/reminder/account/chat statuses stay.
- One acknowledged pin per user, enforced by trip_pins PK(user_id).
- Creating/viewing/editing/inviting/accepting/leader transfer does not pin anyone.
- Only that user's explicit PIN switches their old pin. A Leader cannot pin
  another member or clear that member's unrelated Trip pin.
- Exactly three non-deleted terminal GROUP Trips and their same retained chat IDs
  were approved for restoration by the user. No members/messages/pins are created.
  The previously deleted Trip remains archived and its chat CLOSED.

## API Contract

| API | Result / permission |
|---|---|
| GET /api/v1/trips/pinned | Own acknowledged Trip or {trip:null} |
| POST /api/v1/trips/{id}/pin | 200 Trip detail; active member, non-archived Trip |
| DELETE /api/v1/trips/{id}/pin | 204; delete own matching pin only, safe retry |
| PUT /api/v1/trips/{id}/location | 200 snapshot; JWT actor + same-Trip pin + active membership/account |
| GET /api/v1/trips/{id}/locations | Member view, even if viewer is unpinned; only pinned current members' snapshots |
| GET /api/v1/trips/{id}/locations/stream | Same view authority; one scoped UI subscription |
| DELETE /api/v1/trips/{id} | Existing Leader soft archive, not an unpin |

Unpinned publish returns 403 LOCATION_REQUIRES_PIN in BOTH FOREGROUND/BACKGROUND.
Non-member/deleted Trip returns controlled 404. Invalid coordinate returns 400;
Mongo publish outage returns 503. Server owns updatedAt; capturedAt is not freshness.
Old lifecycle/share routes are removed, not no-op compatibility handlers.
Trip detail/list/update DTOs no longer carry journey status or lifecycle timestamps;
member DTOs no longer expose Share flags. Unknown status PATCH is rejected (400).

## Runtime / Privacy

- Reuses the working Geolocator driver/Android foreground location service.
  No new native subsystem, dependency, history, scheduler or battery bypass.
- Foreground timer target: 15s. Native background callback target: 60s, distance
  filter zero; stationary samples still receive new server updatedAt.
- New Android full-pin flow retains GPS + Always/background permission checks.
  WhileUsing alone is insufficient. Restored pin with insufficient capability is
  displayed but suspended. Restoring capability resumes; never auto-unpin.
- UNPIN hook stops local FG/BG before awaiting network/storage. Failed ACK keeps
  server pin UI truth, suspends that Trip locally and records account-scoped
  pending-unpin metadata in secure storage. Retry on resume/bounded retry clock.
- A new secure-storage key is used; old Share-OFF records are NOT interpreted as
  an instruction to unpin. No GPS is stored locally.
- Logout stops local workers/SSE, leaves server pin intact. Login/start/resume
  reconciles GET pinned and pending-unpin before publishing.
- Account/runtime generations reject late GPS samples and late pin responses.
  Single flight and native cancellation guards prevent overlapping publishers.
- PG publish/pin/unpin lock Trip then actor user row. Safe after-commit cleanup
  uses a separate actor-locked transaction, rechecks re-pin before deleting the
  pair (tripId,userId). A later re-pin wins; another member/Trip is untouched.
- Mongo cleanup failure cannot roll back PG unpin. REST/SSE reconciliation filters
  current pin authority, so failed physical cleanup never exposes an unpinned marker.
  Repeating unpin retries that pair's physical cleanup.
- SSE kinds: tripLocationUpdated, tripLocationRemoved, tripUnavailable. Payload is
  minimal invalidation, no coordinates or Notification/FCM side effects. Affected
  locations REST + annotation diff only; no Directions/full Trip/Place/Map reload.
- OS process destruction/force-stop/background scheduling remain OS-controlled;
  no claim of exact 60s delivery or tracking after force-stop.

## Migration / Data

New migration: backend/src/main/java/db/migration/V16__trip_pin_centric_reset.java.
Java Flyway follows the existing cross-PostgreSQL/H2 convention from V13; no new
dependency or table. Historical V1-V15 must remain byte-identical.

V16 restores only eligible latest retained CLOSED GROUP chats for non-archived
old terminal Trips without another active chat. A missing retained chat aborts
the migration instead of silently creating one. Then it removes:

- trips.status, started_at, completed_at;
- trip_members.location_sharing_enabled, location_sharing_updated_at;
- ix_trips_owner_status, replaced by ix_trips_owner_created(owner_id,created_at).

Preserved: every business ID/row, archived_at, date constraint, roles/member
status, PERSONAL/GROUP, FK/stop ordering, invitations/chat/messages/pins.
No automatic pin, group member creation, GPS/history or broad deletion.

## Delete Evidence

The approved Phase 4.4B report + current PROJECT/DATABASE contracts establish
archived_at + CLOSED active linked chat + retained messages/history. This
predates Phase 4.5/4.6. Older HEAD physical-delete code is not the latest approved
Delete behavior and must not replace the Phase 4.4B implementation.

DELETE cancels pending invitations and removes same-Trip pins/current snapshots;
the archived Trip/chat disappear from active access. UNPIN does NONE of the chat,
membership, invitation, stop or message operations above.

## Backups / Rollback

Ignored local artifacts (contain private working/data state; never commit):

- backups/pin_reset_pre_worktree_20261016.tgz and extracted pin_reset_before;
- backups/pin_reset_pre_20261016.dump and pin_reset_cutover_pre_20261016.dump (custom pg_dump);
- backups/pin_reset_mongo_pre_20261016.archive.gz (MongoDB, including messages/Moments);
- backups/pin_reset_pre_api_20261016.jar;
- backups/pin_reset_pre_counts.json and pin_reset_old_migration_hashes.json.

Test restored V15 -> V16 and clean V1 -> V16 on isolated DBs before main startup.
No volume reset, destructive checkout, Flyway repair, old-migration rewrite or
production test fixtures are permitted.

PostgreSQL executes this Flyway migration transactionally: a failed V16 rolls
back its DDL/chat changes. Diagnose and retry the unchanged failed attempt; do
not use repair as rollback. After successful V16, the old API cannot simply be
restarted against the new schema. Restore the pre-cutover dump into a NEW DB,
verify it with the previous API, then explicitly approve a connection switch.
Never overwrite the current database automatically.

## Source / Regression Evidence

See TRIP_PIN_CENTRIC_RESET_REMOVAL_MATRIX.md for per-file KEEP/REWIRE/removal
classification and preserved hooks. Large-deletion counts compare the pre-task
dirty working-tree snapshot, NOT HEAD; unrelated changes are not discarded.

Maintained API verification entry:

```powershell
pwsh -File backend/scripts/verify-trip-pin-centric-reset.ps1 -BaseUrl http://127.0.0.1:18086/api/v1 -Database gomate_pin_reset_upgrade -MongoDatabase gomate_pin_reset_upgrade
```

Old location-sharing/completion verification entry points now delegate to these
pin-centric equivalent checks. Existing member/leader/invitation/notification
regressions remain, with obsolete Start/Share setup removed only.

## Verification Results

| Check | Actual result |
|---|---|
| Focused Spring suite | 32 passed |
| Final docker compose build api / Maven clean verify | 141 passed, 0 failure/error/skip; BUILD SUCCESS |
| Full Flutter test --no-pub | 137 passed |
| Flutter analyze | 0 errors, 16 pre-existing warnings, 263 infos (same 279-issue baseline); non-fatal warnings/infos flags |
| Debug APK | Built; latest device build includes API_BASE_URLS loopback/emulator and USB 8081 reverse |
| APK installation | adb install -r succeeded on ANDROID_DEVICE_SERIAL, no app-data clear; launched after user approval |
| Restored PostgreSQL | V15 -> V16 PASS, 24 business table counts identical before fixtures |
| Clean PostgreSQL | V1 -> V16 PASS, 25 tables total, no extra business tables |
| Main PostgreSQL | V15 -> V16 PASS; same 24 business counts; history 15 -> 16 records |
| Historical migrations | SHA256 of all 15 V1-V15 files unchanged |
| Safety rejection | Isolated terminal GROUP without retained chat aborts V16; history stays V15, old status column exists and 3 original chats stay CLOSED; no repair |
| Pin-centric API scripts | PASS on both isolated DBs; actual Mongo UPSERT/removal, both runtime modes, scoped SSE, permissions, no location inbox rows |
| Existing Leader lifecycle script | 9 PASS cases, including transfers/archive/races and real retained Mongo message/history |
| Existing Member lifecycle script | leave/remove + concurrent race PASS; later acceptance creates new chat |
| Existing Invitation UI-sync script | PASS, including cancel/reinvite/accepted-membership/profile/follow |
| Place/Route/Stop regressions | Real Mapbox directions PASS on both DBs; fixture route 6,352.558m / 879.883s / 302 geometry points. Empty media, search/detail, occurrence time/clear/reorder/optimize preserved |
| Architecture search | No active Trip status/share gates or old lifecycle/share API calls in lib / backend modules |
| git diff --check | PASS; existing LF/CRLF Git notices only |
| Physical Android | User pinned GROUP on installed APK. Exactly one current snapshot; native Geolocator foreground service confirmed; real foreground ACK interval 14.929s. Launcher/Home confirmed; background ACK interval 61.302s, one snapshot. User UNPIN confirmed: own pin/snapshot 0 immediately and still 0 after 97.763s on Home; native foreground service stopped. PERSONAL pin also produced exactly one own current snapshot and the native service was running. Direct PERSONAL -> GROUP pin switch PASS: one own pin targeting the new GROUP, old PERSONAL snapshot 0, new GROUP snapshot 1 with advancing ACK; old snapshot remained absent after another 36.880s observation interval. |

Automated verification scripts never targeted main PostgreSQL/MongoDB.
Main API remains on port 8081. Isolated test fixture DBs use
gomate_pin_reset_upgrade / clean; the rejected fixture DB is separate.

### Main Data Preservation

Before / after cutover, before any new manual device action:

| Table | Before | After |
|---|---:|---:|
| users / user_profiles / user_settings | 38 each | 38 each |
| refresh_sessions | 192 | 192 |
| trips / trip_members / trip_stops | 16 / 23 / 7 | 16 / 23 / 7 |
| trip_invitations / trip_pins | 25 / 0 | 25 / 0 |
| conversations / conversation_members | 8 / 16 | 8 / 16 |
| notifications / device_tokens | 31 / 1 | 31 / 1 |
| places / place_media | 146 / 7 | 146 / 7 |
| flyway_schema_history | 15 | 16 |

All remaining business table counts also match; exact JSON artifacts are
backups/pin_reset_cutover_before_counts.json / pin_reset_cutover_after_counts.json.
Main retains V1 BASELINE + V2-V16 SUCCESS. Clean DB uses SQL V1 then V2-V16.

Restored chat IDs (same IDs and same membership, no inserted rows/pins):
REDACTED_UUID,
REDACTED_UUID,
REDACTED_UUID.
Archived Trip REDACTED_UUID and chat
REDACTED_UUID remain archived/CLOSED.

Mongo counts before/after migration: messages 4, moments 10, moment_views 6,
moment_mutes 1, moment_reactions 0, interaction_events 157, current locations 2.
These two pre-reset snapshots were not bulk-deleted: with zero pins they are
filtered out, never exposed as current shared markers. New unpin/switch/removal
physically cleans its own pair; no unrelated Mongo history/collections changed.

### Large Deletion Audit

Compared to the actual pre-task dirty working tree; renames are paired rather
than falsely counting the old filename as a total feature deletion.
Full artifact: backups/pin_reset_removal_audit.json.
New central pin verification script replaces, not removes, old script coverage.

| File/block | Removed lines | Classification / preserved coverage |
|---|---:|---|
| trip_location_sharing_test.dart | 534 | REWRITE_TO_PIN; +273 lines; keep cadence/native/errors/account/race/SSE/annotation cases, replace Share/terminal prerequisites |
| sharing_service -> publishing_service | 392 | REWIRE; +194; keep driver/15s/60s/native cancellation/single-flight/account safety, remove Share state and multi-Trip publishing |
| trip_completion_cancellation_test.dart | 216 | obsolete status assertions -> pin/role/UI/chat/parser assertions, +98 |
| verify-trip-completion-cancellation.ps1 | 192 | wrapper to maintained canonical pin script, not skipped |
| trip_detail_screen.dart | 146 | remove journey/share rows/confirms only; keep members/invites/pin/chat/stops/delete/leave |
| trip_location_share_control.dart | 138 | REMOVE_OBSOLETE_SHARE only; native driver and pin controls retained |
| TripCompletionCancellationTest.java | 134 | replace terminal mutation/race tests with pin/delete/permission/history races, +88 |
| verify-trip-location-sharing.ps1 | 111 | wrapper to maintained pin-centric integration script |
| TripService.java | 90 | remove start/complete/cancel/transitions; add own-pair cleanup/locking; unrelated transactions retained |
| TripLocationSharingTest.java | 64 | rewrite own pin/publish/Mongo/SSE/privacy/concurrent unpin coverage, +71 |
| map_ui_session.dart | 57 | remove terminal cache; only explicit pin ACK/GET pinned may replace pin |
| TripRepository.java | 54 | remove obsolete fields/share queries; keep JDBC/roles/stops/chat/archive, +23 |
| trip_location_realtime_service.dart | 51 | replace terminal signals with removed/unavailable; one scoped stream and location-only refresh retained |
| TripLocationService.java | 46 | remove consent handlers; pin/permission/pair cleanup instead, +22 |

The only whole removed widget is the obsolete Share switch/status control.
Runtime/model/repository files are moved and reused, not a new location subsystem.
Test count changes reflect obsolete status/Share scenarios replaced by the new
contract, not removal of member/invitation/Map/notification regression suites.

## Remaining Limits / Device Checklist

- Restart old Flutter runs; old binaries calling retired lifecycle/share APIs are
  deliberately incompatible. Do not roll an old API image onto V16 without a
  separately restored compatible DB.
- Existing 16 analyzer warnings/263 infos are outside this business reset.
- Android timing/process survival is OS-controlled, not guaranteed tracking.
- If Mongo is unavailable during unpin, authority/marker privacy still stops;
  cleanup is best effort, logged and safely retried by repeated scoped unpin.
- Recorded physical acceptance so far: PIN group (foreground >=30s), one snapshot,
  retained Always permission, native service; no Start/Share action required.
- Recorded Home/background: Launcher was top-resumed, native service remained
  foreground, backend ACK advanced from 15:59:44.853Z to 16:00:46.155Z (61.302s),
  still exactly one same-user/Trip snapshot. No coordinates recorded in reports.
- Recorded UNPIN: own pin and current snapshot removed, native foreground service
  absent, neither recreated after 97.763s on Home. Group foreground/background/unpin
  acceptance therefore passed on the physical device.
- Recorded PERSONAL pin: one own pin and one own current snapshot, server ACK
  updatedAt 2026-10-16T16:08:15.912Z; native foreground service running. No Start
  or Share step required. Artifact: backups/pin_reset_device_personal_ack.json.
- Recorded direct PERSONAL -> GROUP switch: user chose the new GROUP pin without
  first manually unpinning PERSONAL. Own pin count stayed 1 and targeted the new
  GROUP; old PERSONAL snapshot count was 0, new GROUP snapshot count was 1.
  Native Geolocator foreground service was running with GoMate top-resumed.
  ACK advanced from 2026-10-16T16:21:20.875Z to 16:22:05.845Z; old snapshot was
  still absent after a second observation 36.880s later. This is a sustained
  switch check, not a foreground cadence measurement. No coordinates recorded.
  Artifacts: backups/pin_reset_device_switch_t0.json and
  backups/pin_reset_device_switch_t1.json. No pin was changed by test tooling.
- Additional physical variants: permission revoke/recovery, logout/login
  retaining pin, another user's unrelated pin.
  Do not claim any unexecuted physical scenario passed.

## Final Verdict

```text
TRIP_PIN_CENTRIC_RESET_CLOSED
STATUS_LIFECYCLE_REMOVED
EXPLICIT_SHARE_REMOVED
PIN_DRIVEN_LOCATION_READY
```

PIN is the sole own-location publishing intent; UNPIN stops publishing/removes
the own current snapshot, while DELETE remains the separate approved archive
operation. Automated and physical evidence above establish this core flow for
the installed Android build. The additional physical variants listed above are
not claimed as manually executed; their automated coverage remains separate.
