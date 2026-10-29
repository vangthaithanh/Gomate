# Account Privacy Foundation P1A

## Scope and ownership

- P1A only. No Post/P1B, Feed, Global Block or media implementation.
- PostgreSQL owns privacy and follow approval. Flutter never chooses whether a
  follow is valid. Existing Moments/DM/Trip rules still derive friendship from
  reciprocal rows in user_follows, never from pending requests.
- Existing Settings privacy switch and Notification rows are reused. Pending
  follow requests appear above Trip notifications; accept or the X (Tu choi)
  action resolves them. Open/pull-to-refresh reloads this queue. No additional
  timer, SSE event or Android push type was added for follow requests in P1A.

## Migration

V18__account_privacy_foundation.java is additive; V1-V17 must remain unchanged.

- user_settings.account_visibility: PUBLIC/PRIVATE, NOT NULL, default PUBLIC.
  This follows the existing database contract; API exposes boolean isPrivate.
- follow_requests: UUID id/requester_id/target_id, status
  PENDING/ACCEPTED/REJECTED/CANCELLED, created_at/responded_at TIMESTAMPTZ.
- Foreign keys to users; no self requests; responded_at must be NULL only
  while pending. PostgreSQL partial unique pending pair index and owner/status/
  creation inbox index. H2 tests emulate the partial index with a nullable
  generated guard; that guard is NOT added to PostgreSQL.
- Does not rewrite, delete or backfill user_follows. Previously accepted
  followers remain accepted across either privacy transition.

## API

All routes use /api/v1 and existing JWT/security/response conventions.

| Method and route | Contract |
| --- | --- |
| GET /users/me, /users/me/profile, /users/{userId} | Profile includes isPrivate and viewer-specific followRequestPending |
| PATCH /users/me/profile (existing /users/me alias) | Optional boolean isPrivate; omitted field preserves value |
| GET /users/search | Each result includes server privacy and outbound pending flag |
| PUT /users/{userId}/follow | Existing accepted edge is preserved; PUBLIC creates edge; PRIVATE creates one PENDING request |
| DELETE /users/{userId}/follow | Removes own follow and cancels own pending request, idempotently |
| GET /users/{userId}/relationship | Existing flags plus isPrivate and followRequestPending |
| GET /users/me/follow-requests?page=0&size=20 | Owner-scoped pending requests; existing page/items/size/total shape, max size 50 |
| POST /users/me/follow-requests/{id}/accept | Recipient only; creates requester -> recipient edge transactionally |
| POST /users/me/follow-requests/{id}/reject | Recipient only; no follow edge |
| GET /users/{userId}/followers or /mutual-friends | PRIVATE: only owner or accepted follower may read the list |

Request list items: id, requesterId, nickname, fullName, avatarUrl, status,
createdAt (ISO-8601). No caller-supplied actor or privacy state is trusted.
Missing/not-owned requests return controlled 404; resolving a different terminal
state returns 409 FOLLOW_REQUEST_RESOLVED. Retrying the same decision succeeds.
Rejected/cancelled requests can be sent again with a NEW request UUID.

Privacy changes alone NEVER accept pending requests. If a target becomes PUBLIC
and the requester later explicitly presses Follow again, that explicit action
creates a normal public edge and marks their old pending request CANCELLED,
not ACCEPTED. Without that action, it stays pending until owner resolution or
requester cancellation, including while the target is PUBLIC.

All mutations for a target lock its user_settings row in a transaction, including
privacy updates, follow/unfollow and accept/reject. The pending unique index is
an additional database-level duplicate guard. Only creation/removal of an actual
edge emits the existing interaction event after commit.

## Changed implementation

- Backend: auth/AuthRepository; user dto/UserDtos, repository/UserRepository,
  service/UserService; relationship dto/SocialRelationshipDtos,
  repository/SocialRelationshipRepository, service/SocialRelationshipService,
  controller/SocialRelationshipController.
- Flutter: core/services/auth_service.dart; profile SettingsOptionsScreen,
  PublicProfileScreen, ProfilePeopleScreen and the existing profile audience
  reader (removed production dependency on demo privacy);
  search model/repository/screen; notifications FollowRequestRepository and
  GoMateNotificationScreen.
- Tests: AccountPrivacyApiTest, MomentApiTest, DirectMessageApiTest,
  PlaceApiTest (approved table whitelist now includes follow_requests);
  test/account_privacy_test.dart; backend/scripts/verify-account-privacy.ps1.
- No new dependency, env variable, Compose definition or external service.

## Upgrade and recovery

Backup before cutover: ignored backups/p1a-pre-v18/database.dump and app-v17.jar.
The old API image is also retained as gomate-auth-api:p1a-v17-backup.
Migration hashes, pre/post counts and logs live in the same ignored directory.
Validate on a restored V17 database and a clean database BEFORE main cutover.
The API verification script is restricted to localhost ports 18088/18089 and
keeps temporary credentials only in ignored backups/.

If V18 fails transactionally on PostgreSQL: inspect error, keep backup and V17
API; do not run repair, rewrite V1-V17, reset volumes or delete user data.
After successful V18, rolling API back to the saved V17 artifact leaves additive
columns/table intact. Do not expose V17 follow writes while PRIVATE accounts
exist: old code does not enforce privacy. Use a maintenance window and a reviewed
forward fix, or restore the full pre-cutover backup ONLY with owner approval
because restoration discards any changes made after the backup.

## Verification

Executed 2026-10-21:

| Check | Result |
| --- | --- |
| Focused backend privacy/profile/relationship tests | 13 PASS |
| Final `docker compose build api` / Maven clean verify | 172 tests, 0 failures/errors/skips; image build PASS |
| Auth, Google/Firebase, Profile, Relationship regression | PASS in final suite |
| New private-account Moments and DM regression | PASS; no production Moment/DM logic changed |
| Flutter `flutter test --no-pub` | 157 PASS, including 6 new privacy tests |
| `flutter analyze --no-pub` | 0 errors, same 16 old warnings and 263 infos (279 total), no new diagnostics |
| Restored V17 -> V18 PostgreSQL | PASS; only V18 applied; original accepted edge IDs and created_at preserved |
| Clean PostgreSQL V1 -> V18 | PASS; 18 successful versions, exactly 26 approved tables |
| Two/three-account HTTP workflow on both PostgreSQL DBs | PASS PUBLIC immediate, PRIVATE pending, duplicate, accept/reject/cancel, owner-only, visibility toggles |
| Real restart of both test APIs | PASS privacy, pending, accepted mutual edge and login privacy reload persisted |
| PostgreSQL duplicate PENDING insert | Rejected by uq_follow_requests_pending as expected |
| Main database upgrade | V18 JDBC successful; history V1-V18, 26 tables; main API HTTP 200 |
| V1-V17 source checksums | Byte-identical to pre-task snapshot |

The initial full Docker verification caught two test issues, now fixed and
re-run: the approved table whitelist did not include follow_requests, and the
new DM test accessed detail.status instead of detail.conversation.status.
No production DM API was changed to satisfy these assertions.

### Main database preservation

All 24 original business table counts stayed unchanged. In particular:
users/profiles/settings **38 -> 38**, user_follows **2 -> 2**, places **146 -> 146**,
place_media **7 -> 7**, trips **18 -> 18**, trip_members **25 -> 25**,
notifications **37 -> 37**, refresh_sessions **208 -> 208**.
Flyway history **17 -> 18** is the only original-table count change;
new follow_requests has **0** rows on main. All 38 migrated accounts remain
PUBLIC by default; no real user's privacy/follow settings were changed for tests.
Both original follow rows retain identical IDs and timestamps.
The snapshot restored for testing received only isolated temporary accounts;
none of those fixtures was inserted into the main database.

The freshest pre-cutover dump is
`backups/p1a-pre-v18/pre-cutover.dump`; retain it alongside `database.dump`,
`app-v17.jar` and the tagged V17 image. Logs/counts are ignored local artifacts.
No secrets/config/dependencies were added to the repository.

### Docker cleanup

Removed only these 5 old, stopped test API containers, each inspected first:
gomate-pin-reset-rejected, gomate-pin-reset-clean, gomate-pin-reset-upgrade,
gomate-phase46-upgrade, gomate-phase46-clean.
Also removed this task's gomate-p1a-upgrade / gomate-p1a-clean APIs, their two
temporary PostgreSQL databases and isolated gomate_p1a_test Mongo database after
successful restart verification. No production volume was deleted/reset.
GoMate now has only its 4 standard running containers: api, postgres, mongo, ai.
Unrelated healthcare containers/images were not touched.

Physical-device UX was NOT tested or inferred from API/widget tests.
Follow-request queue does not yet produce a new SSE/FCM push or count toward
the existing Trip notification badge; it is real REST-backed state refreshed
on opening/pull-to-refresh. Existing Trip SSE/FCM/reminders remain unchanged.
P1A is complete; P1B/Post remains unimplemented.

## Device checklist

1. Account A: Settings -> Privacy -> enable private, reopen and sign in again;
   the switch must stay enabled.
2. B follows A: B sees Cho xac nhan, not following/friend; A opens Notifications
   (or pulls to refresh) and sees the real request above Trip notifications.
3. A rejects: B reloads profile and can request again. A accepts: counts and
   relationship reflect a real follow. Reciprocal accepted follow remains the
   only friendship signal for Moments/DM.
4. Toggle A PUBLIC/PRIVATE with an existing follower and another pending request:
   follower stays valid; pending is not automatically accepted.
5. B cancels their pending request; A refreshes the queue and it disappears.
6. Existing Trip invitations/reminders, Moments and DM remain usable.
