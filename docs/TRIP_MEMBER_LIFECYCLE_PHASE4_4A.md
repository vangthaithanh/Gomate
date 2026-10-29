> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Phase 4.4A - Trip Member Lifecycle

Date: 2026-10-15. Scope: MEMBER leave, LEADER remove, and the newly approved Group/Personal/chat lifecycle. No Map refactor, leader transfer, new notification event, or Trip deletion feature.

## Canonical rule

Last MEMBER leaves/is removed -> Trip PERSONAL, Leader remains, old chat C1 CLOSED and retained, zero active chat. Later acceptance -> Trip GROUP, new chat C2 different from C1, exactly one active chat. C1 is never reused; new members cannot inherit C1 access. The latest task explicitly supersedes the former no-downgrade rule in AGENTS/PROJECT_CONTRACT.

## Audit and UI

- Approved leave actions exist in Trip list/detail menus and Message detail. Approved removal exists in Group Members: existing select/copy icon, member checkboxes, trash, confirmation sheet. No new menu/button/screen/layout.
- Real MessageRepository leave/remove were no-op. Trip list and Chat detail could fake success; Trip detail showed a deferred placeholder. These now await backend ACK.
- V7 forced GROUP conversations to ACCEPTED and UNIQUE(linked_trip_id) for their entire lifetime. V13 is necessary and allowed by this task.
- Existing CLOSED status is reused for archived/inactive GROUP chats. DIRECT behavior and uniqueness stay unchanged.
- The existing Chat leave confirmation promised notifications to everyone, although leave/remove events are undecided. Only that unsupported promise was removed; confirmation layout/consequence text is retained. New notifications are DEFERRED.

## API / transaction

```text
DELETE /api/v1/trips/{tripId}/members/me
  Actor from JWT; active MEMBER only; 204 after commit.
DELETE /api/v1/trips/{tripId}/members/{memberUserId}
  Active LEADER removes active MEMBER; 200 updated Trip detail.
```

Outsider/missing/repeated already-removed membership: controlled 404. MEMBER removing another: 403. LEADER self-leave/removing LEADER: 422 with TRIP_LEADER_CANNOT_LEAVE / TRIP_LEADER_CANNOT_BE_REMOVED. No client actor ID or deputy role.

One PostgreSQL transaction: lock Trip first -> authorize -> remove trip_members -> remove active conversation_members -> delete departing user's Trip pin -> if only Leader remains, close C1 and set PERSONAL -> commit. Remaining other MEMBERS keep GROUP and C1 active. No chat is created during leave/remove.

Invitation accept/cancel retain their invitation-then-Trip lock order. Leave/remove never change accepted/cancelled/declined history; replaying an old ACCEPTED invitation cannot rejoin a departed member. A new invitation is required.

Group chat access checks current Trip membership, GROUP type and the active chat ID, not merely historical conversation_members. Reads/writes, pin creation and location publication serialize appropriately on the Trip row. Removed members cannot read Trip/chat/locations, send, publish or pin after commit.

trip_pins already joins active membership, but retaining the departing pin could unexpectedly re-pin on later rejoin. Delete only that user's pin; preserve Leader/other pins. Mongo trip_current_locations remains LAST_KNOWN and is retained. Membership/new opt-in flags filter old snapshots; no TTL/history deletion or GPS permission change.

## V13 / persistence

`backend/src/main/java/db/migration/V13__group_conversation_lifecycle.java` replaces lifetime Trip-link uniqueness with PostgreSQL partial unique index `uq_conversations_active_linked_trip`, where type=GROUP and status=ACCEPTED, and permits GROUP status ACCEPTED/CLOSED. H2 uses an equivalent generated nullable key because it lacks partial indexes; PostgreSQL adds no helper column. DIRECT shape is unchanged.

V1-V12 untouched; zero new tables/dependencies. PostgreSQL still has 25 public tables including Flyway history. Index enforces at-most-one active chat; business transactions enforce exact GROUP=1 / PERSONAL=0.

Backup: `backups/gomate_pre_v13_member_lifecycle_20261015.dump`, custom pg_dump, 121076 bytes. Restored V12 snapshot was migrated to V13 before live cutover; all counts below stayed identical:

| Table | Before / after restored-snapshot migration |
|---|---:|
| users | 38 / 38 |
| trips | 16 / 16 |
| trip_members | 23 / 23 |
| trip_invitations | 24 / 24 |
| notifications | 29 / 29 |
| conversations | 7 / 7 |
| conversation_members | 15 / 15 |
| device_tokens | 1 / 1 |

Main Mongo before cutover: messages 2, trip_current_locations 4. Live results are recorded below. No reset/repair/volume deletion. All helper APIs use isolated databases/port 18083 with Firebase/FCM/Cloudinary disabled; no tokens/passwords in reports.

Live V12 -> V13 cutover PASS: API was quiesced, an additional custom backup `backups/gomate_pre_v13_cutover_20261015.dump` (121078 bytes) was saved, then only the API was recreated. All business counts in the table above stayed identical, as did Mongo messages 2 and location snapshots 4. V1-V13 all successful; 25 public tables. Query for GROUP with active-chat count other than 1 or PERSONAL with any active chat returned zero rows. `/health` UP; api/ai/postgres/mongo running; existing NOTIFICATION_PUSH_ENABLED=true preserved.

## Flutter

- Reuses confirmation component; busy guards and one-shot confirm prevent repeated submissions.
- No local removal/success before ACK. Failure keeps roster/Trip and displays error.
- ACK discards affected Trip/chat cache and calls existing Map UI-session cleanup, even when user backed out during the request. No Map renderer/performance file modified.
- Leader removal updates roster/count and canonical full Trip detail; last removal hides old active chat and returns Trip to PERSONAL.
- Multi-select uses sequential single-member atomic APIs. Earlier ACKs remain committed if a later request fails; canonical refresh reconciles this partial result. No undocumented all-or-nothing bulk promise.
- Trip detail revalidates on opening/resume/return. A 403/404 clears stale protected Trip/pin and closes detail. Revision guards prevent old refresh/detail responses from restoring discarded membership.
- No new membership SSE/FCM event or polling interval. Another device reconciles through authorized REST/resume; backend membership authority is revoked immediately at commit.

## Real PostgreSQL proof

Both leave and remove ran through `backend/scripts/verify-trip-member-lifecycle.ps1` (PowerShell 7, isolated API only), with real Mongo messages/location snapshots.

```text
Trip REDACTED_UUID
Before: GROUP, {A,B}, C1=REDACTED_UUID ACCEPTED
B leaves: PERSONAL, {A}, zero active chat, C1 CLOSED retained with Leader
B Trip/chat/pin/location APIs: 404; historical invitation still ACCEPTED
C accepts: GROUP, {A,C}, one active chat
C2=REDACTED_UUID, different from C1
C GET C1/messages: 404; C GET C2: 200
```

Leader-remove produced the same lifecycle. Simultaneous real PostgreSQL leave/remove returned [204,404]: one effective removal, PERSONAL, no active chat. Pre-archive messages and old Mongo snapshots remained stored; removed snapshots were not returned or inherited as opted-in sharing in the new lifecycle.

## Tests

- Backend focused: 12 PASS (6 lifecycle including parameterized leave/remove, 6 existing group tests). M01-M16 covered with permission, rollback, concurrency, repeat, replay, archived access and pin/location tests.
- Full Docker build: 101 PASS, zero failure/error/skip. Includes Auth, Place, Route, Trip stops/time/order, DM, Moment, Follow, SSE/FCM regression.
- Existing NotificationPushTest assumed exactly 12 migrations. It now asserts successful V12 specifically, so additive V13 does not falsely fail; exact allowed-table regression is retained.
- Flutter: 61 PASS, including 10 lifecycle widgets covering ACK delay/failure, confirmation, role visibility, roster refresh, stale detail, back-navigation-before-ACK and partial bulk-failure retry with only remaining members selected. Existing invitation/SSE/FCM tests remain.
- Real PostgreSQL clean V1-V13, restored V12-V13, lifecycle/race and SSE invitation create/accept/cancel/reinvite/reconnect: PASS.
- Native member-lifecycle UI not manually tested yet. Android FCM infrastructure from Phase 4.3 is unchanged; no unrequested test notifications sent to real users.
- Final whole-repository analyze: exit 1, 0 errors, 16 existing warnings and 262 infos. Do not claim a clean global analyze pass. Scoped repository/test analysis: no errors/warnings, one existing null-aware-element info in location request mapping.
- Final debug APK build PASS: 266.5s, `build/app/outputs/flutter-apk/app-debug.apk`. ADB device list was empty, so this APK was not installed or manually tested on a phone in this phase.
- Temporary verification containers and the two explicitly created PostgreSQL databases/test Mongo database were removed after saving evidence. Main DB/volumes were not reset; archived-chat retention checks happened before disposal of test-only databases.
- Ignored evidence: `backups/phase44a_docker_build_final.log`, `phase44a_flutter_release_test.log`, `phase44a_existing_migration.log`, `phase44a_postgres_lifecycle.json`, `phase44a_postgres_lifecycle_final.json`, `phase44a_postgres_sse_regression.json`.

## Files / operations

Changed: V13 migration; TripController/Service/Repository; ConversationRepository/Service; TripLocationService; TripMemberLifecycleTest; NotificationPushTest migration assertion; verification script; Flutter Trip/Message repositories and existing Trip list/detail, Chat detail and Group Members screens; lifecycle widgets; AGENTS/PROJECT_CONTRACT/DATABASE_CONTRACT/CODEX_INDEX and this note.

Root Compose remains standard. V13 applies on API startup. Do not edit old migrations, use repair as rollback, delete volumes, or downgrade old application code once multiple historical chat links exist. Restore backup into a separate DB first if recovery is required; never silently overwrite later writes. Existing unrelated dirty work is preserved; no commit/push.

Leader transfer/leave, new deletion semantics, archived-chat browsing and leave/remove notification events remain DEFERRED. Existing unrelated deferred UI is not claimed implemented.

Deletion boundary for a future task: the pre-existing Trip DELETE handler and linked_trip_id ON DELETE CASCADE were not redesigned here. Retention verified above concerns leave/remove, not a promise about separate explicit Trip deletion. Decide archive retention/deletion policy before implementing new Leader exit/delete-group UX; do not silently change that business in a follow-up.

To test the new UI after reconnecting Android:

```powershell
.\scripts\run-android-dev.ps1 -NoDockerStart
```

Use MEMBER's existing Trip menu -> Roi lich trinh, or Chat detail -> Roi nhom. For LEADER: Trip -> Thanh vien -> select/copy icon -> choose MEMBER -> trash -> confirm. Check the last-member case then invite/accept a new member: PERSONAL/no active old chat -> GROUP/fresh chat. API is already running on 8081. Native notification retesting is not claimed; automated NotificationPush/NotificationRealtime suites and real PostgreSQL SSE smoke passed.

```text
PHASE_4_4A_CLOSED
TRIP_MEMBER_LEAVE_REMOVE_READY
LAST_MEMBER_TRANSITION = IMPLEMENTED
OLD_CHAT_REUSED = NO
PERSONAL_ACTIVE_CHAT_COUNT = 0
GROUP_ACTIVE_CHAT_COUNT = 1
```
