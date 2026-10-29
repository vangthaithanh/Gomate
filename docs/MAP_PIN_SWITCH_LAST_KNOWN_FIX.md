> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Map Pin Switch and Last-Known Position Fix

Updated: 2026-10-21. Implements the user's two scoped corrections; no redesign.
This note supersedes the 2026-10-16 reset's snapshot deletion/pinned-only read
rules only. Trip journey status and explicit Share remain removed.

## Current Rules

- Explicit successful PIN selects that Trip on Map immediately. No tab switch.
- Passive startup/resume reconciliation must not replace a different viewed
  preview. A deliberate selection made during an in-flight pin is preserved.
- One pin per user remains the publishing authority for foreground/background.
- UNPIN stops native/local publishing immediately and removes the server pin,
  but retains the actual last-known snapshot for that Trip's current members.
- Switching pin A -> B likewise retains A's last-known position. Subsequent GPS
  goes only to B, never copied to A and never given a fabricated fresh timestamp.
- GET locations returns snapshots of active members with active accounts in a
  non-archived Trip, whether those members currently pin it or not. The viewer
  still needs current membership; outsiders and departed users cannot read it.
- No snapshot means no marker. There is no fake position or backfill.
- Leave/remove and Trip archive keep scoped snapshot cleanup/revocation.
- Auth, invitations, roles, chat, stops, routing and permission gates unchanged.

## Root Causes and Fix

1. Map displayed `selectedTrip ?? pinnedTrip`; the previous pin populated
   selectedTrip, so a new ACK updated only pinnedTrip and left the old selection.
   `GoMateMapUiSession.pinTrip` now selects on explicit ACK, resets day only when
   changing the viewed Trip, and emits the existing revision. Passive restore
   passes selectOnMap=false. Callers retain selection-race/ACK failure guards.
2. TripService unpin/switch deleted the old snapshot; location profiles also
   INNER JOINed trip_pins. Unpin/switch no longer performs Mongo cleanup. Reads
   use active member profiles, not pins. Cleanup is now named for member
   departure and rechecks current authority before deleting that own pair.

## Performance / Scope

- Existing Map listener, route fingerprint/cache and single-flight route sync
  reused. No Mapbox widget recreation, polling interval change or extra timer.
- A different group target reconnects the existing single scoped SSE receiver;
  repeated same-target ACKs do not reconnect or add location REST requests.
- GPS remains approximately 15s foreground / 60s native Android background.
- Unpin does less work: no Mongo delete and no marker-removal SSE broadcast.
- Location ticks still update affected annotations only, never Directions,
  Place catalog or full Trip reload. Existing Map performance work retained.
- One existing Mongo document per (tripId,userId), no trail/history or new
  collection/index/table/column/dependency. Flyway stays V1-V16, untouched.

## Changed Areas

- Flutter session + publishing restore; pin ACK callers in repository, Map
  button, Trip list/detail. No widget layout/style changes.
- Backend TripService, TripRepository location profile query, TripLocationService.
- Flutter Map panel/runtime tests; backend location/lifecycle regression tests.
- Existing isolated pin-centric API verification script follows retained
  last-known semantics, still guards against targeting the main databases.
- AGENTS, CODEX_INDEX, PROJECT/DATABASE contracts and old report clarification.

Pre-edit dirty working files preserved in ignored local archives:
backups/map_pin_last_known_before_20261021.tar and
backups/map_pin_selection_callers_before_20261021.tar.

## Verification

| Check | Actual result |
|---|---|
| docker compose build api / full Maven clean verify | 142 passed, 0 failure/error/skip; BUILD SUCCESS |
| flutter test --no-pub | 140 passed |
| flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos | 0 errors, 16 warnings + 263 infos; existing 279-issue baseline unchanged |
| Isolated PostgreSQL/Mongo API script | PASS; retained last-known coordinate/timestamp after unpin/switch, denied unpinned FG/BG, UPSERT, membership/chat/archive and notification isolation |
| Place/Stop/Mapbox regression in same script | PASS; search/no-media detail, time/clear/reorder/optimize, real route 6,352.558m / 851.832s / 302 geometry points |
| Main API deployment | User-approved update to port 8081; application started successfully, schema already V16, no migration necessary |
| Migration preservation | Main history still 16 successful entries, latest V16; all 15 pre-V16 SHA256 hashes match the recorded baseline; no migration file edited/added |
| Android APK | flutter build apk --debug --no-pub with API_BASE_URLS loopback/emulator succeeded |
| Device installation | User-approved adb install -r succeeded on ANDROID_DEVICE_SERIAL; app launched, no app-data clear; USB reverse 8081 restored |
| Physical Map pin switch | PASS: user confirmed on 2026-10-21 that Map updates to B immediately, without an extra tab switch to force refresh |
| Physical last-known member marker | PASS: user confirmed on 2026-10-21 that A still sees B's last-known position after B unpins |
| git diff --check | PASS; existing Git LF/CRLF notices only |

Automated tests also cover exact last-known JSON retention, active-account and
membership privacy, departure/delete cleanup, SSE target switch while Map stays
visible, late old-target REST rejection, same-target connection/request reuse,
pin ACK failure, in-flight selection races and incremental annotation updates.
No success is inferred from build alone. Both requested visual acceptance cases
are confirmed by the user on the installed build: immediate A -> B Map update,
and B's last-known marker retained for A after B unpins. These confirmations
supplement the API/automated results; no new GPS coordinates are recorded here.

The two requested fixes are accepted. This final confirmation updates the
report only; no further runtime, UI, business or schema changes were made.

No main-DB test fixtures were created. The real API script reused the existing
isolated gomate_pin_reset_clean databases. Its temporary container used --rm
and was stopped/automatically removed immediately after verification.

Local evidence (ignored; not committed): map_pin_last_known_build.log,
map_pin_last_known_flutter_all.log, map_pin_last_known_analyze.log,
map_pin_last_known_api.log under backups/. Previous running API JAR was also
backed up there before replacement. No environment/dependency/schema edits.

## Limits

- Snapshots already deleted by the prior implementation cannot be recreated
  from nothing; a fresh authorized GPS publish is needed for those pairs.
- Last-known is not live tracking. Display keeps the actual server updatedAt
  and existing relative-time presentation; unpin never advances it.
- Native background scheduling is OS-controlled; no force-stop guarantee.
