> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Phase 4.4B - Trip Leader Lifecycle / Soft Delete

Ngày audit: 2026-10-16.

## Trạng thái

**IMPLEMENTED / AUTOMATED VERIFIED. Android manual verification còn chờ người dùng.**

Người dùng đã duyệt nút chìa khóa khi chọn đúng một MEMBER. Đã triển khai backend,
Flutter, V14 và kiểm thử DB sạch/bản restore. API chính đã cutover, không thao tác
chuyển quyền/archive trên Trip thật của người dùng. Các mục Audit dưới đây ghi
lại vấn đề phát hiện trước sửa; kết quả cuối và cách test nằm ở cuối tài liệu.

## Nguồn và phạm vi bảo toàn

- Yêu cầu: `CODEX_TASK_PHASE4_4B_TRIP_LEADER_LIFECYCLE_SOFT_DELETE.md` do người dùng cung cấp.
- `AGENTS.md`, `CODEX_INDEX.md`, contract hiện hành và Phase 4.4A.
- Giữ bản sửa cache chat rỗng, single-flight pending và `memberCount` trong
  `TRIP_PENDING_LOAD_AND_MEMBER_COUNT_FIX.md`.
- Giữ UI/permission Map, nút pin/unpin và khung kéo lịch trình của bước trước.

## UI Đã Được Người Dùng Duyệt

UI hiện có:

- Trip list/detail: menu xóa, member-leave, pin/unpin.
- Message detail: Leader thấy Xoá nhóm; Member thấy Rời nhóm.
- Màn Thành viên nhóm: thêm, bật chế độ chọn, chọn MEMBER và nút thùng rác.
- Biểu tượng chìa khóa cạnh tên hiện chỉ là nhãn LEADER, không có action chuyển.
- Row ngoài chế độ chọn không có handler chuyển quyền. Không tìm thấy
  transfer-leader action/picker/API wiring trong Flutter hiện tại.

UI đã được người dùng phê duyệt:

```text
Leader -> màn Thành viên -> chế độ chọn đang có
-> chọn đúng 1 active MEMBER
-> nút chìa khóa cạnh nút xóa
-> khung xác nhận GoMate đang có
-> server ACK -> cập nhật role từ server
```

Không có màn hình/navigation mới, không chọn pending/self/former member và không
tự rời nhóm sau khi chuyển. Không thay UI Map hay tạo màn hình lịch sử mới.

## Audit database thật

Đã chạy truy vấn chỉ đọc qua root Compose:

- `flyway_schema_history`: V1 đến V13 đều SUCCESS.
- `information_schema.columns` của `trips` và CHECK constraint thật.

```text
current Flyway before: V1-V13
current Flyway after audit: V1-V13, unchanged
archive representation hiện tại: CHƯA CÓ
hard delete thực hiện trong task này: NO
```

`trips` có status `DRAFT/PLANNED/ACTIVE/COMPLETED/CANCELLED`, không có
`archived_at/deleted_at/is_archived`. CANCELLED là trạng thái hành trình,
không được âm thầm coi là archive.

Hướng triển khai phù hợp: migration tiếp theo **V14**, thêm dấu archive tối
thiểu (dự kiến `archived_at TIMESTAMPTZ NULL`), không sửa V1-V13 hay tạo bảng mới.
V14 đã được kiểm thử trên DB sạch và bản restore trước khi cutover. Không sửa
V1-V13. Chi tiết backup, record count và lịch sử cuối ở dưới.

## Audit code hiện tại

- `TripService.delete` gọi `TripRepository.deleteTrip`, đang chạy
  `DELETE FROM trips`. Đây là hành vi cũ cần thay, không đáp ứng soft-delete.
- V3 có FK cascade từ Trip đến members/stops/reminders; V7 có cascade từ
  linked chat tới Trip. Không được tiếp tục gọi physical DELETE để làm Phase 4.4B.
- `TripService.leave` đã chặn LEADER bằng 422; giữ nguyên ý nghĩa đó.
- Phase 4.4A dùng chat `CLOSED` cho archive/inactive. Reuse trạng thái này;
  transfer phải giữ chat ID, archive Trip mới đóng active chat.
- Quyền trưởng nhóm hiện lấy từ `trip_members`; cần kiểm tra lại sau khi đã
  khóa Trip để actor cũ không giữ quyền trong race với transfer/archive.
- Accept/cancel hiện khóa invitation trước Trip. Archive cần đóng toàn bộ
  pending: phải thống nhất thứ tự lock các luồng liên quan, không tạo chu trình
  Trip -> invitation / invitation -> Trip gây deadlock.
- Xóa nhóm ở Message repository thật còn no-op; Message detail có thể báo
  thành công trước ACK. Cần nối API soft-delete và xử lý ACK/error đúng.
- Confirmation xóa hiện còn mô tả xóa vĩnh viễn/xóa chat; cần căn chỉnh ý nghĩa
  với archive mới, giữ component/layout, không hứa notification chưa có.

## Checklist Triển Khai

1. Migration/archive queries; filter Trip archived khỏi list/detail/pin/member/chat.
2. API chuyển LEADER chỉ tới active MEMBER, một transaction, đúng một LEADER,
   đồng bộ chat role, giữ C1, không tự leave.
3. DELETE Trip thành soft-delete: giữ Trip/member/stop/history, đóng pending,
   đóng active chat, bỏ mọi pin của Trip trong cùng transaction.
4. Chặn tất cả active mutations/location/chat đối với Trip archived trên backend.
5. Notification/invitation cũ resolve REST truth, không Accept/mở active Trip.
6. Mongo current snapshots cleanup sau COMMIT, best-effort; không xóa messages.
7. Nối UI đã duyệt, cập nhật role/cache sau ACK, giữ các fix loading/count vừa rồi.
8. Test đầy đủ L01-L25, LF01-LF12 và 8 race trong file yêu cầu; regression,
   Flyway clean/existing restore, Docker build và Flutter/device status thực tế.

## Kết Quả Cuối

```text
current Flyway before: V1-V13 SUCCESS
current Flyway after:  V1-V14 SUCCESS
archive representation: trips.archived_at TIMESTAMPTZ NULL
hard delete used: NO
new tables: 0 (public vẫn 25 bảng, gồm flyway_schema_history)
new dependencies/config/secrets: NONE
```

`status` vẫn là vòng đời hành trình, không đổi CANCELLED/COMPLETED thành archive.
V14 chỉ thêm một cột nullable. Không xóa/renumber/repair migration cũ.

### API Chuyển Trưởng Nhóm

```http
PATCH /api/v1/trips/{tripId}/leader
Authorization: Bearer <current leader token>
Content-Type: application/json

{"targetUserId":"<active MEMBER UUID>"}
```

- 200: TripDetail chuẩn hiện tại; Trip ID và linkedConversationId giữ nguyên.
- A: LEADER -> MEMBER. B: MEMBER -> LEADER. Cùng C1, không tạo chat mới.
- A vẫn trong nhóm, không tự leave. Sau ACK A dùng thao tác Rời nhóm đang có.
- Không nhận self/pending/cancelled/declined/former/outsider làm target (422).
- MEMBER không có quyền chuyển (403); outsider/Trip archived bị 404.
- Body thiếu target hoặc UUID sai: 400 theo validation hiện tại.
- Trip row lock trước kiểm tra quyền, hai role Trip và hai role chat đổi trong
  cùng transaction. Lỗi ở chat rollback toàn bộ role changes.
- `owner_id` giữ người tạo ban đầu để không thay thông tin gốc. Quyền hiện tại
  luôn lấy từ `trip_members.role/status` + `trips.archived_at`, không từ owner_id.
- Mọi writer sửa Trip/stop/invite kiểm tra quyền sau khi lock Trip. Accept,
  decline, cancel thống nhất thứ tự Trip -> invitation, tránh deadlock với archive.

### DELETE Là Lưu Trữ

```http
DELETE /api/v1/trips/{tripId}
```

- LEADER: 204 sau commit. Lặp bởi Leader được giữ trong lịch sử: 204 an toàn.
- MEMBER: 403, outsider: 404; không biến leave thành archive.
- Trip row, members, stops, reminders, invitation/notification và chat history
  được giữ. Không gọi physical DELETE trips trong production repository/service.
- Mọi PENDING invite -> CANCELLED; trạng thái lịch sử khác không đổi.
- Active Group Chat -> CLOSED, không xóa chat/conversation_members/messages.
- Xóa mọi trip_pins trỏ tới Trip. List/detail/pinned/active chat đều loại archive.
- Cấm edit/stop/reorder/optimize/invite/accept/pin/location read+publish/chat send/
  transfer/member leave/remove trên Trip archived ở backend, không chỉ ẩn nút UI.
- Mongo `trip_current_locations` được dọn sau PG COMMIT; lỗi cleanup được log,
  không rollback archive. Retry DELETE thử cleanup lại, không tạo lại side effect
  inbox. Không có distributed transaction hay retry scheduler mới.
- Notification history vẫn tồn tại; pending đã CANCELLED. Với Trip archived,
  REST notification trả `tripId=null`, kể cả lịch sử ACCEPTED. UI resolve lại REST
  và không mở active Trip. Chỉ phát signal UPDATED đã có sau commit; không tạo
  loại thông báo/FCM mới cho transfer/archive.

### Flutter

- Thành viên -> icon chọn hiện có -> chọn đúng 1 MEMBER -> nút chìa khóa cạnh
  thùng rác -> confirmation GoMate. MEMBER/self/pending không có action này.
- Không giả đổi role trước ACK. Sau ACK cập nhật Trip/cache/role cùng chat từ
  response, rồi refresh server. Old Leader mất quản lý, vẫn là MEMBER.
- Menu Xoá lịch trình/Xoá nhóm giữ entry point và component hiện có. Nội dung
  xác nhận nói ngừng hoạt động/giữ lịch sử, không còn hứa xóa vĩnh viễn hay phát
  thông báo loại mới. Cancel không gửi API, không báo thành công giả.
- API thất bại giữ nguyên Trip/chat/pin. ACK mới purge cache và MapUiSession,
  kể cả lúc người dùng đã thoát màn hình đang chờ. Không gọi DELETE hai lần khi
  xóa ở Trip list.
- Giữ single-flight chat/pending, revision guard và memberCount của bước fix
  trước. Không refactor Map/camera/location renderer hoặc thay giao diện khác.

## Backup Và Cutover Thật

File local trong `backups/` được gitignore, không commit vì chứa dữ liệu thật:

- `phase44b_pre_20261016_022515.dump`: snapshot đầu trước migration.
- `phase44b_cutover_20261016.dump`: backup sát lúc cutover.
- `phase44b_pre_api_20261016.jar`: JAR API cũ để điều tra/khôi phục có kiểm soát.
- `phase44b_cutover_pre_counts.json`, `phase44b_cutover_after_counts.json`.
- `phase44b_upgrade_after_migration_counts.json`: so sánh bản restore.

Image cũ của container đã không còn trong image store nên không tag rollback
được; đã lấy JAR trực tiếp từ container cũ trước khi recreate. Không commit
container runtime/env vào image để tránh nhúng secrets.

Đã chạy `docker compose build api` rồi `docker compose up -d --no-deps api`.
PostgreSQL/Mongo/AI và volume không recreate/reset. API khởi động bình thường ở
8081, V14 SUCCESS, Place API trả 146 records. Không archive/chuyển role Trip thật.

Record count chính trước/sau cutover:

| Bảng | Trước | Sau |
|---|---:|---:|
| users / user_profiles / user_settings | 38 / 38 / 38 | 38 / 38 / 38 |
| refresh_sessions | 185 | 185 |
| places / place_categories / place_media | 146 / 6 / 7 | 146 / 6 / 7 |
| trips / trip_members / trip_stops | 16 / 23 / 7 | 16 / 23 / 7 |
| trip_invitations / trip_reminders / trip_pins | 25 / 0 / 1 | 25 / 0 / 1 |
| conversations / conversation_members | 8 / 16 | 8 / 16 |
| notifications / device_tokens | 31 / 1 | 31 / 1 |
| flyway_schema_history | 13 | 14 |

Đã so toàn bộ 24 bảng nghiệp vụ, không chỉ các dòng trên. Chỉ Flyway history tăng
1. Kiểm tra DB thật: 0 Trip archived do test, 0 Trip sai số Leader.

Rollback: ưu tiên fix-forward bằng migration tiếp theo nếu cần. Không dùng
flyway repair, không down -v, không xóa V14 history. Nếu cần phục hồi toàn bộ,
restore dump vào DB mới và kiểm chứng trước, chỉ chuyển DB khi người dùng duyệt;
restore đè làm mất writes phát sinh sau backup. Không chạy JAR cũ có hard-delete
against DB đã có archived Trip vì có thể hồi sinh UI/quyền cũ. Task này không
thực hiện rollback dữ liệu thật.

## Kiểm Thử Thực Tế

### Backend Và Docker

- `docker compose build api`: Maven clean verify **114 tests, 0 failures/errors,
  0 skipped**, BUILD SUCCESS và image build thành công.
- `TripLeaderLifecycleTest`: 13 invocations, bao phủ L01-L23 với 8 race, rollback
  transfer/archive, Mongo cleanup failure sau commit, idempotency, chỉ đúng 1
  Leader, cùng C1, hủy pending và chặn active authority sau archive.
- L24/L25: DirectMessageApiTest (3), TripMemberLifecycleTest (6), GroupTripChatApiTest
  (6) pass. Auth/Firebase/Google, Place/Route, social/Moment, realtime/push cũng
  pass trong full suite; không chỉ compile.
- TripApiTest bổ sung giữ stop/reminder và Trip row sau archive.
- TripInvitationInboxApiTest đổi kỳ vọng hard-delete UNAVAILABLE/404 cũ thành
  CANCELLED/409, vẫn giữ inbox history.
- Bổ sung kiểm tra cụ thể target CANCELLED/DECLINED và ACCEPTED notice của Trip
  archived trong lượt recheck `phase44b_backend_final_edges.log` (13 invocations).

### PostgreSQL Và MongoDB Thật

Hai API kiểm thử riêng, Firebase/FCM/seed disabled, không gửi test push vào user:

- DB restore `gomate_phase44b_upgrade_20261016`, cổng 18084: V13 -> V14.
- DB sạch `gomate_phase44b_clean_20261016`, cổng 18085: V1 -> V14.
- Mongo test tách riêng bằng cùng tên DB; không ghi Mongo `gomate` thật.
- Sau kiểm chứng đã dọn hai helper containers và hai cặp DB test do task tạo;
  không dọn/reset database hay volume chính. Backup và log kết quả được giữ lại.
- Restore giữ record count của tất cả 24 bảng nghiệp vụ ngay sau migrate.
- Chạy `backend/scripts/verify-trip-leader-lifecycle.ps1` trên từng môi trường:
  **9/9 scenario PASS mỗi DB**: real transfer/archive flow + 8 concurrency cases.
- Có Mongo message thật, publish snapshot thật: snapshot 1 -> 0 sau archive,
  số messages không đổi. Stops/reminders/members/inbox/invitations còn nguyên.
- Không chỉ test bằng H2 hay mock provider.
- Script lần đầu chạm Auth rate limit do tạo quá nhiều fixture user; đã điều
  chỉnh reuse 5 fixture users trên các race, không sửa/tắt rate limit Auth thật.

Race result thực tế trên PostgreSQL (thứ tự mã: request transfer/archive, request đối chọi):

| Race | DB restore | DB sạch |
|---|---|---|
| hai transfer | 200 / 403 | 200 / 403 |
| transfer vs target leave | 422 / 204 | 422 / 204 |
| transfer vs target remove | 200 / 403 | 422 / 200 |
| archive vs transfer | 204 / 404 | 204 / 404 |
| archive vs accept | 204 / 200 | 204 / 409 |
| archive vs new invite | 204 / 201 | 204 / 404 |
| archive vs member leave | 204 / 204 | 204 / 204 |
| archive vs mutation | 204 / 404 | 204 / 404 |

Các mã 200/201 trước archive là thứ tự giao dịch hợp lệ: thao tác đó commit
trước, sau đó archive đóng toàn bộ trạng thái. Final DB assertions kiểm tra
không có chat active/pending mới sót lại sau archive. Không có deadlock/500.

### Flutter

- Full `flutter test --reporter expanded`: **107 PASS**.
- LF01-LF10: 17 widget tests trong trip_member_lifecycle_test.dart (gồm 10 ca
  Phase 4.4A cũ và 7 ca mới), kiểm tra key chỉ đúng một MEMBER, ACK/role, failure,
  cancel, archive và cleanup pin.
- Real repository HTTP tests bổ sung transfer endpoint/body, role refresh cùng
  chat, DELETE ACK/failure trước khi purge. Các regression chat empty/pending
  reentrancy/memberCount vẫn pass.
- LF11: archived ACCEPTED notice trả tripId null không gọi loadTrip, không
  hiện Accept; stale cancelled push/invitation tests cũ vẫn pass.
- LF12: notification realtime/push/polling tests trong suite vẫn pass.
- Analyze: **0 errors, 16 warnings + 262 infos tồn tại từ baseline**. Không tăng
  warning/info mới trong phần triển khai này.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1`:
  PASS, assembleDebug 105s. APK: `build/app/outputs/flutter-apk/app-debug.apk`.

### Manual Android Chưa Chạy

Không tự install APK, điều khiển máy thật hoặc dùng tài khoản thật gửi lời mời
trong phase này. Những xác nhận SSE/FCM thiết bị thật ở phase trước được giữ là
kết quả lịch sử, không trình bày thành một lượt native test Phase 4.4B mới.

Chạy lại app từ cấu hình IDE đang dùng, hoặc nếu vẫn dùng thiết bị USB cũ:

```powershell
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s ANDROID_DEVICE_SERIAL reverse tcp:8081 tcp:8081
flutter run -d ANDROID_DEVICE_SERIAL --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1
```

Test A Leader/B Member: mở Thành viên -> chọn B -> chìa khóa -> xác nhận. A còn
trong nhóm nhưng mất quản lý; A có thể rời riêng, B còn Leader. Test archive qua
menu cũ: Cancel giữ nguyên; confirm thành công mất Trip/chat/pin, old notification
không mở lại Trip. Dùng Trip test riêng, không dùng lịch trình cần giữ hoạt động.

## File Tạo/Sửa Trong Phase Này

Tạo:
- `backend/src/main/resources/db/migration/V14__trip_archive.sql`
- `backend/src/test/java/vn/gomate/TripLeaderLifecycleTest.java`
- `backend/scripts/verify-trip-leader-lifecycle.ps1`
- `docs/TRIP_LEADER_LIFECYCLE_PHASE4_4B.md`

Sửa backend:
- `trip/controller/TripController.java`, `trip/dto/TripDtos.java`
- `trip/service/TripService.java`, `trip/repository/TripRepository.java`
- `trip/repository/TripInvitationRepository.java`
- `message/repository/ConversationRepository.java`
- `location/repository/TripLocationMongoRepository.java`, `location/service/TripLocationService.java`
- `notification/repository/NotificationRepository.java`
- Tests `TripApiTest.java`, `TripInvitationInboxApiTest.java`

Sửa Flutter:
- `lib/features/trip/data/trip_repository.dart`
- `lib/features/trip/screens/trip_detail_screen.dart`, `trip_screen.dart`
- `lib/features/messages/data/message_repository.dart`
- `lib/features/messages/screens/group_management_screen.dart`, `message_detail_screen.dart`
- Tests `trip_member_lifecycle_test.dart`, `trip_pending_load_regression_test.dart`,
  `notification_ui_sync_test.dart`

Sửa docs: `PROJECT_CONTRACT.md`, `DATABASE_CONTRACT.md`, `CODEX_INDEX.md`.
Không gom mọi file dirty từ phase trước vào danh sách thay đổi phase này.

## Giới Hạn Và Verdict

- leader transfer: IMPLEMENTED, AUTOMATED + REAL STORE VERIFIED.
- leader normal leave: BLOCKED AS DESIGNED; former Leader leave là thao tác riêng.
- soft delete: IMPLEMENTED, AUTOMATED + REAL STORE VERIFIED.
- hard delete: NOT IMPLEMENTED / NOT USED.
- iOS push / realtime GPS / scheduler: OUT OF SCOPE.
- Mongo cleanup best-effort, không có durable retry queue mới; retry DELETE có
  thể thử lại, lỗi được log. Active authority vẫn bị khóa bằng PostgreSQL.
- Không có SSE/FCM notification type mới cho transfer/archive. User khác lấy
  quyền/trạng thái mới qua refresh/REST, không hứa cập nhật lifecycle UI tức thì
  bằng một event chưa được duyệt.
- Backend + Flutter automated readiness đã đạt. Manual Android Phase 4.4B còn
  chờ người dùng, nên chưa gắn nhãn PHASE_4_4B_CLOSED cho nghiệm thu thiết bị.
