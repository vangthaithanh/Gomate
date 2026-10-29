# DM Privacy / Message Requests

Updated 2026-10-23. Stop after this phase; Android acceptance remains separate.

## Tóm Tắt Bàn Giao

- Đã làm nền quyền nhắn tin theo privacy người nhận, gửi tin đầu mới tạo chat,
  xử lý tin chờ bằng ACK thật; giữ nghiệp vụ Share P4 theo quyết định mới nhất.
- Không đổi schema, không có V25, không thêm dependency hay sửa cấu hình bí mật.
- Đã backup, kiểm chứng DB sạch/bản sao và cập nhật API chuẩn cổng 8081; không
  để lại API/container/DB test. Dữ liệu người dùng đang dùng không bị xóa hay seed.
- APK đã build, CHƯA cài/test máy thật trong lượt này. Cần cài bản mới cùng backend
  vì API mở chat mới có thể trả DRAFT/null ID; không dùng APK cũ để nghiệm thu.
- Chỉ dừng ở DM. Không tự làm Global Block, notification Like/Comment hay phase sau.

## Approved Rules

Newest owner clarification overrides the attached task's conflicting Share clause:
- Becoming mutual never creates an empty conversation.
- Post Share counts as first send. Mutual without DIRECT can create ACCEPTED
  and the reference together. Existing ACCEPTED permits Share even after unfollow
  or privacy changes; sender still needs current Post permission.
- Owner clarification after device testing, 2026-10-23: DM uses the SAME reference-
  only policy as GROUP. A recipient need not be able to read the Post at send time;
  opening Post/media always rechecks that recipient's current permission. ONLY_ME
  may be sent as a reference but never becomes readable by someone else.
- PENDING never accepts automatically or receives Share. Recipient eligibility
  (mutual/ACCEPTED, active membership, scoped block) is not relaxed.

New contact permission depends on the recipient, not the sender:

| Recipient | Accepted relationship | Profile button / new TEXT |
|---|---|---|
| PUBLIC | Mutual | Yes / ACCEPTED |
| PUBLIC | One-way or stranger | Yes / PENDING |
| PRIVATE | Mutual | Yes / ACCEPTED |
| PRIVATE | Sender follows recipient, accepted | Yes / PENDING |
| PRIVATE | Stranger, PENDING or REJECTED follow | No / 403 |

Existing ACCEPTED by conversation ID survives unfollow/privacy changes; the
Profile new-contact button can still be hidden. Scoped block denies sending.
DM accept never creates a follow edge/global block. PENDING remains pending after
follow-back/privacy changes. V1 sender may continue TEXT; only recipient resolves
the request. Delete marks REMOVED and retains history. A NEW permitted send reuses
that pair; retrying an already removed first-send receipt cannot resurrect it.

## API

Base `/api/v1`, JWT actor, existing raw DTO/error convention:
- User Profile adds server-computed `canInitiateMessage`.
- `POST /conversations/direct {targetUserId}` now performs permission-checked
  lookup ONLY. Existing active pair returns normal summary; otherwise summary
  has `status=DRAFT, conversationId=null`. Old clients that assume a non-null ID
  must update together with this backend. No persisted DRAFT status is added.
- NEW `POST /conversations/direct/messages`:
  `{targetUserId,clientRequestId:UUID,text,context?}` -> 201
  `{conversation:ConversationSummary,message:MessageItem}`.
  Server checks privacy/accepted follows for a new/reopened pair; existing chat
  follows its stored permission. Text maximum stays 4,000 characters.
- Existing `POST /conversations/{id}/messages` adds optional `clientRequestId`.
  Flutter always sends it. Legacy callers without it retain their old behavior.
- GET `/conversations` = ACCEPTED only; GET `/message-requests` = incoming pending
  only. Viewing never accepts. Recipient-only accept is idempotent; DELETE pending
  is idempotent for REMOVED. Resolved conflicting state -> 422; outsider -> 404;
  requester trying to resolve -> 403. Blocked request cannot accept until unblocked.

## Consistency / Data Safety

NO schema/dependency/config change; Flyway V24, V1-V24 immutable. Existing V6/V7
DIRECT pair uniqueness, requester/recipient/status and conversation_members are
reused. No new chat/request/receipt/outbox/notification table. Old data is retained.

First send owns a PG TransactionTemplate (REQUIRES_NEW): ordered pair settings
locks -> existing conversation lock -> validate privacy/status/membership/block
-> metadata/touch -> acknowledged Mongo upsert -> PG commit. Same pair locks
serialize accept/delete/block with sends and the existing privacy/follow locks.
GROUP retains its existing Trip membership guard.

TEXT uses deterministic Mongo `_id` for sender/request/scope and canonical payload
hash; retry returns the same message, changed payload gets 409. Internal hash is
not returned. Legacy bodies stay readable. New conversation ID is request-bound,
not pair-bound: an orphan cannot become readable through an unrelated later chat.
PG commit/Mongo failure rolls back PG and attempts scoped Mongo cleanup under the
pair lock only if candidate metadata is absent, never deleting committed retry
data. Orphan retry can rebind only with matching hash and absent old metadata.
Cleanup failure logs IDs, not body/token. This is compensation, NOT distributed
PG/Mongo atomicity. Manual operational recovery may be needed if both fail.

## Flutter / UI Lock

- Profile uses server permission, not demo/local privacy inference.
- Draft stays outside both inboxes, is discarded on back and never GETs a fake ID.
  First send resolves the temporary route alias to the real conversation.
- Incoming pending uses existing Accept/Delete; outgoing pending uses existing
  composer. Accept keeps the same route/full history and waits for ACK. Canceling
  delete does nothing; API errors preserve state/input and show GoMate snackbar.
- Composer suppresses double tap and retains key/text for retry. Session changes
  discard late responses. Moment replies call the same first-send service/API;
  Moment mutual visibility is unchanged.
- Only shared-Post unavailable/error state gets matching GoMate lock/connection
  empty state and return-to-chat/retry. Other Profile/Home/Post UI is unchanged.
- Protected Post media and Home image/video retention are untouched.

## Files

Backend: UserDtos/UserRepository/UserService; MessageDtos, ConversationController,
ConversationRepository/Service, MessageDocument/MessageMongoService; narrow
MomentService reply adapter. Tests: DirectMessageApiTest/DirectMessageMongoTest,
PostSearchShareApiTest. Existing PostShareService protocol remains in place;
preparePostShare now validates only, actual first Share owns persistence.

Flutter: SearchUserProfile/parser, PublicProfileScreen; MessageConversation,
MessageRepository, chat/pending screens/composer; narrow MomentsRepository
adapter; shared-reference flag/error state in Profile Post viewer.
Added test/direct_message_privacy_test.dart and scratch-only diagnostic script
scripts/diagnostics/direct_message_privacy_smoke.ps1.
Updated AGENTS, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT, P4 notes.

## Verification

Automated results, all run in this task:
- Backend regression: 112 tests, zero failures/errors/skips, including real Mongo
  retry/restart/hash-conflict checks, Auth/Google/Firebase, Profile/Privacy/follow,
  Moment, Group Chat, P4 Share/Search and Post/Feed/Comment/Activity/Publish.
- Final `docker compose build api` with focused tests: 30 PASS, including 14
  DIRECT tests (two additional forced privacy-vs-first-send / block-vs-send lock
  cases), 10 P4 Share/Search and 6 Group Chat tests. These overlap the 112 above;
  they are NOT 142 distinct tests. Image was deployed to the standard API only.
- Flutter: 107 PASS across direct_message_privacy, account_privacy,
  post_share_search, post_activity, post_comment_report, post_feed,
  home_media_lifecycle, trip_member_lifecycle, trip_member_invite and
  trip_pending_load_regression suites. Includes recipient-only footer, ACK failure,
  cancel-delete, full history, logout late response and stale draft-alias tests.
- Analyze: 0 errors, 15 pre-existing warnings, 335 info; exit 1 because this repo
  is not lint-clean. No new warning. Existing warnings were not mass-cleaned.
- Android debug APK build PASS; not installed or device-tested in this task.
  `build/app/outputs/flutter-apk/app-debug.apk`, SHA256:
  `BAF59FB27086247DA118DC483D0F603FBEF08C6980AAC0ECB9F889746929B64E`.
- Scratch clean PostgreSQL applied V1-V24; V24 clone validated with no migration.
  Both passed HTTP privacy/request/Share flows with real Mongo and passed another
  JVM restart + fresh login + same first-send key: exactly one message remained.
- All 37 cloned business-table counts stayed unchanged at new-code startup before
  fixtures. Live cutover compared ALL 37 counts against its frozen backup: no diff.
  Selected live before/after: users 38/38, user_follows 1/1, follow_requests 4/4,
  conversations 9/9, conversation_members 17/17, posts 7/7, post_media 12/12,
  comments 6/6, trips 18/18. Flyway 24 successful entries, no failed entry.
- Standard API restarted successfully on 8081, Mongo connected, unauthenticated
  first-send returned 401. No real-user fixtures or real Cloudinary uploads.
- Deleted only scratch `gomate_dm_clean`/`gomate_dm_upgrade` PG/Mongo databases,
  stopped their Java APIs and removed the temporary build-image tag. No extra
  API container was left; standard api/postgres/mongo/ai remain. Unrelated stopped
  healthcare containers were not touched.
- Logs/history/row snapshots and ignored local backups are under
  `backups/dm-privacy/`; DB backup and old running JAR were captured before change,
  with a second frozen dump before deployment. No secrets were added to source.

Rollback for this code-only change needs the prior backend build/source + paired
Flutter version, NOT Flyway repair/volume reset. Retain current business data;
do not restore an old dump over newer user activity merely to roll code back.
Remaining limits: no distributed PG/Mongo transaction; compensation is best-effort.
Legacy clients omitting clientRequestId retain legacy non-idempotent TEXT sends.

## Android Acceptance Checklist

Not claimed as device PASS until owner tests:
1. PUBLIC A / PRIVATE B stranger: Profile B hides Message; API/search bypass
   denies new contact. B may message A into A's pending queue. Open/back creates
   no empty inbox row.
2. A accepts within chat: same screen/history, normal composer, main inbox; no
   follow edge. Profile B still hides Message while A does not follow B.
3. PRIVATE accepted one-way follow permits pending; mutual first send creates
   normal chat. Existing pending stays pending after follow-back. Delete confirm
   cancel does nothing; failure retryable; a genuinely new send follows V1 reopen.
4. Accepted TEXT/Share works after unfollow/private; pending never receives Share;
   scoped block disables sending. DM/GROUP recipient without Post permission sees
   only the unavailable page, never another member's private preview.
5. Logout/login restores real history and owner-scoped queues. No new DM push,
   call/media, Global Block or like/comment notification phase is included.

## Inbox / Share Follow-Up

See DM_INBOX_ORDER_AND_REFERENCE_SHARE_FIX.md for the subsequent device-reported
inbox ordering fix and newly approved DM reference-only delivery. Historical test
totals above refer to the privacy foundation, not that later hotfix.
