# Trip Pin-Centric Reset - Removal / Reuse Matrix

Audit 2026-10-16, before deletion. New user request overrides Phase 4.5/4.6.
Working branch: codex/ui-f11c6f7-invitation-sync, HEAD 738d548.
Dirty work includes unrelated UI/Auth/social changes. No reset/stash/checkout/clean.
Pre-task working files are backed up in backups/pin_reset_pre_worktree_20261016.tgz.
Deletion counts will compare against this working-tree snapshot, not HEAD.

## Business / Data Decisions

- V1-V15 live and immutable; V16 is the next chronological migration.
- trips.status is journey-only. Delete is independently represented by V14
  archived_at. One-pin-per-user is the actual trip_pins primary key(user_id).
- Share fields are used only by the obsolete Phase 4.5 intent flow.
- Three non-archived GROUP Trips have obsolete terminal status and CLOSED chat.
  User explicitly APPROVED restoring these Trips and their same existing chat IDs,
  retaining membership/messages, never pinning anybody. Deleted Trip stays deleted.
- Delete evidence: approved/current Phase 4.4B report + PROJECT/DATABASE contract
  define archived_at + CLOSED chat + retained messages. This predates Phase 4.5/4.6.
  HEAD contains an older physical delete implementation; do not restore its cascade
  over the later approved Phase 4.4B behavior. Unpin never removes chat/membership.

## Source Matrix

| File / area | Classification | Removed block / replacement | Preserved hooks |
|---|---|---|---|
| TripService | REMOVE_OBSOLETE_STATUS / REMOVE_PARTIAL_PHASE46 / REWIRE | Start/Complete/Cancel/transitions/terminal guards removed; pin/unpin become sole location intent; user-row serialization + scoped snapshot cleanup | Invitations, create, permissions, stops/time/reorder/optimize, member leave/remove, leader transfer, separate Delete |
| TripRepository | REMOVE_OBSOLETE_STATUS / REMOVE_OBSOLETE_SHARE / REWIRE | Remove journey columns/queries and share getters/setters; add pin-authority queries and actor lock | JDBC, membership status, PERSONAL/GROUP, stop/reminder status, active-chat relation, archived_at |
| TripController / TripDtos | REMOVE_OBSOLETE_STATUS / REMOVE_OBSOLETE_SHARE | Remove lifecycle/share endpoints and Trip-only DTO fields | All pin/location/trip/invitation/member/stop APIs |
| TripLocationService | REWIRE | Remove share APIs; publish requires pin for FG and BG; reads filter to pinned current members; safe own-snapshot cleanup | Mongo UPSERT/server timestamp, location validation, after-commit signals, permission guards |
| TripLocationMongoRepository | KEEP / REWIRE | Add delete(tripId,userId), not broad user/Trip deletion | Unique current snapshot, no GPS history |
| TripLocationStreamHub | REWIRE | Remove terminal signals/gates; add location removal/context-unavailable signals | One authenticated scoped stream, bounded queue, heartbeat, JWT revalidation, no Notification/FCM |
| ConversationService | REMOVE_OBSOLETE_STATUS | Remove terminal Trip guard/status update argument | Existing GROUP membership lock and CLOSED/archived guards; DIRECT unchanged |
| New V16 migration | REWIRE | Restore only eligible old terminal chats, drop obsolete Trip status/timestamps/share columns, replace status-based index | IDs, row counts, FK, archive metadata, 25 tables, V1-V15 |
| trip_ui_models / trip_repository | REMOVE_OBSOLETE_STATUS / REWIRE | Remove Trip lifecycle fields/methods; pin ACK and unpin-intent hooks | Invitation status, member roles, stops, PERSONAL/GROUP, server truth |
| trip_detail_screen / trip_screen | REMOVE_OBSOLETE_STATUS / REMOVE_OBSOLETE_SHARE | Remove lifecycle rows/confirms/status labels/share control | Existing layout, name/date/member/chat/places, permission-gated pin/unpin, Delete/leave |
| map_ui_session | REMOVE_OBSOLETE_STATUS / REWIRE | Remove terminal cache; retain actor-scoped pin truth and prevent other Trip updates replacing a pin | Selection/day/launch/add flow; no network/GPS inside session |
| map_screen / map_trip_pin_button | REMOVE_OBSOLETE_STATUS | Remove ACTIVE/terminal gates only | Permission flow, marker diff, draggable panel, route fingerprint/cache, pin position, search/detail |
| trip_location_sharing_service -> trip_location_publishing_service | REWIRE | Remove share/status state and multi-Trip publishing; preserve 15s/60s orchestration and activate only acknowledged pin; persist pending unpin only | Native driver, single flight, retry, account generations, permissions, lifecycle stop/resume |
| location_sharing_models -> location_runtime_models | REMOVE_OBSOLETE_SHARE / KEEP | Remove TripLocationSharingState only | Sample + capability types |
| location_sharing_repository -> location_publishing_repository | REWIRE | Replace share endpoints with pinned/current authority | Existing Auth client, pinned DTO parser, location upload |
| trip_location_share_control.dart | REMOVE_OBSOLETE_SHARE | Entire file is only the obsolete switch/status; no replacement toggle | Pin buttons remain in existing UI |
| location_runtime_driver | KEEP / REWIRE | Keep native GPS implementation; replace disable-consent metadata with account-scoped pending-unpin metadata | Android foreground service, stationary cadence, no wake/battery bypass, no local GPS storage |
| trip_location_realtime_service | REWIRE | Remove status/share dependence, reconcile removal and unavailable events | One subscription, affected-marker REST refresh only, backoff, no Directions/Trip reload per GPS |
| message_repository / group_management_screen | REMOVE_PARTIAL_PHASE46 | Remove terminal-only chat cache/roster guards | Original active GROUP/delete/member behavior, pending single-flight, DM, invitation UI/leader controls |
| app.dart | REWIRE | Wire renamed publishing coordinator | Single global receiver; notifications unchanged |

## Test / Script Matrix

| Suite / script | Classification | Replacement / preservation |
|---|---|---|
| TripLocationSharingTest | REWRITE_TO_PIN | Keep Mongo/SSE/permissions/cadence/races/privacy; replace status/share prerequisites with pin |
| TripCompletionCancellationTest | DELETE_OBSOLETE_STATUS_ASSERTION / REWRITE_TO_PIN | Replace old terminal assertions with removed-endpoint, pin/unpin/switch/delete races and history preservation |
| TripApiTest / GroupTripChatApiTest | REWRITE_TO_PIN | Remove obsolete status/Share expectations only; retain stops/time/roles/Group/DM cases |
| trip_location_sharing_test.dart | REWRITE_TO_PIN | Preserve native fake driver, cadence, single-flight, permissions, logout/account, incremental markers; replace obsolete switch/Start cases |
| trip_completion_cancellation_test.dart | DELETE_OBSOLETE_STATUS_ASSERTION / REWRITE_TO_PIN | Test absence of removed controls, ordinary editable Trip/member/chat behavior and pin ACK/failure |
| Existing invitation/member/leader/notification tests/scripts | KEEP | Only remove obsolete location setup, never weaken permissions, transactions, inbox/FCM, stops or unrelated assertions |
| verify-trip-location-sharing / completion-cancellation scripts | REWRITE_TO_PIN | Test canonical pin authority, removal, migration and privacy on isolated DBs; no old APIs |

## No Broad Deletion

No file deletion before its references are audited. No changes to Auth business,
Moment, Place, AI, Cloudinary, Mapbox routing engine, historical migrations, device
tokens or notification inbox semantics. Historical Phase 4.5/4.6 reports stay with
SUPERSEDED notices. Final deletion counts and verification are in
TRIP_PIN_CENTRIC_BUSINESS_RESET.md.

## Recorded Verification

- Final Docker/Maven: 141 tests passed. Full Flutter: 137 passed.
- Analyze: 0 errors, existing 16 warnings + 263 infos; APK built/installed.
- Restored and clean PostgreSQL V16 validated; main cutover preserved all 24
  business table counts, restored exactly 3 retained chats, no automatic pins.
- All 15 historical migration hashes unchanged. No new tables/dependencies.
- Source removals/paired renames are counted against pin_reset_before, not HEAD;
  see the detailed large-deletion table and device evidence in the reset report.
- Physical Android core acceptance passed: GROUP foreground/background, scoped
  UNPIN with no restart after 97.763s, PERSONAL publishing, and direct PERSONAL
  -> GROUP switch (one own pin, old snapshot absent, new snapshot ACK advancing).
  This final acceptance pass changed documentation only, not source or schema.
