> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip - Nhóm trưởng hủy lời mời đang chờ

Ngày: 2026-10-15. Chỉ bổ sung chức năng hủy lời mời theo yêu cầu mới, không mở rộng leave/kick/expiry/approval/push.

Quyết định UI mới nhất: hủy ở từng dòng của danh sách Lời mời đang chờ trên màn Thành viên, không hủy trong popup dấu +. Popup của Trip đã lưu chỉ dùng thêm người; người đã mời phải biến mất sau khi Thêm thành công.

Tinh chỉnh UI tiếp theo: bỏ nhãn `Đang chờ` ở từng người cho cả PERSONAL/GROUP, chỉ còn một dòng `Huỷ lời mời` tại vị trí thao tác. Giữ tiêu đề section `Lời mời đang chờ`, không thay API/quyền/loading/error hoặc nghiệp vụ hủy.

## Nghiệp vụ

- LEADER đang hoạt động của Trip được hủy lời mời PENDING của chính Trip đó, kể cả PERSONAL chưa có chat.
- Người được mời, MEMBER khác hoặc người ngoài không được hủy.
- Chỉ PENDING -> CANCELLED. Không hủy ACCEPTED/DECLINED, không xóa thành viên đã gia nhập.
- Hủy lặp cùng invitationId trả thành công idempotent; retry ID cũ không tác động invitation mới.
- Có thể mời lại sau khi hủy: tạo invitationId và notificationId mới; không tái kích hoạt lời mời cũ.
- Không tạo/xóa/đổi Trip type, membership hay linked chat khi hủy.
- Chọn người khi CreateTripScreen chưa submit vẫn là draft, hủy draft chỉ bỏ lựa chọn cục bộ như trước.

## API và transaction

```text
DELETE /api/v1/trips/{tripId}/invitations/{invitationId}
200 -> TripDetail mới, pendingInvitations không còn lời mời đã hủy
404 -> không tồn tại/sai Trip/không có quyền xem Trip
403 -> là member nhưng không phải LEADER
409 TRIP_INVITATION_CLOSED -> đã ACCEPTED hoặc DECLINED
```

Lock invitation trước, sau đó lock Trip, cùng thứ tự với accept. Kiểm tra quyền và trạng thái trong transaction. Accept/cancel đồng thời chỉ một thao tác thắng:

- Cancel thắng: ACCEPT sau đó nhận 409; không có member/chat giả.
- Accept thắng: CANCEL nhận 409; giữ nguyên member/chat đã tạo.

Cancel chỉ cập nhật `status`, `updated_at`; không đặt `responded_at` vì đây không phải câu trả lời của invitee. Không xóa invitation hay notification lịch sử.

## Schema/Flyway

V1-V10 giữ nguyên. Thêm `backend/src/main/java/db/migration/V11__trip_invitation_cancellation.java` để mở rộng CHECK status thành PENDING/ACCEPTED/DECLINED/CANCELLED. Không thêm bảng/cột/index/dependency.

Java migration theo convention V7/V10 để hỗ trợ PostgreSQL và H2. Chỉ thay CHECK chứa status + PENDING; không đụng NOT NULL, FK hoặc self-invite constraint. PostgreSQL information_schema cũng liệt kê NOT NULL như CHECK, nên không chỉ lọc tên cột status.

## Flutter/UI

- PERSONAL: `Huỷ lời mời` đặt cạnh từng người trong Lời mời đang chờ ở màn Thành viên. Sau ACK cập nhật list/count và Trip session; lỗi giữ nguyên dòng để retry.
- GROUP: màn Thành viên nhóm có cùng phần Lời mời đang chờ bên ngoài; chỉ LEADER có thao tác hủy. Reuse row/avatar/style quản lý nhóm hiện hành, không trộn pending vào danh sách member được chọn để xóa.
- Popup dấu + của Trip đã lưu ẩn pending cũ và người vừa Thêm thành công, kể cả khi tìm kiếm lại; không có thao tác hủy. Sau khi hủy ngoài danh sách, mở popup lại thì có thể chọn và mời lại người đó.
- `TripMemberUi.invitationId` chỉ dùng cho pending invitee, tách khỏi `id` là userId. DELETE luôn dùng invitationId thật, không dùng userId thay thế.
- Picker khóa gửi lặp khi đang chờ ACK; nút hủy bên ngoài có busy/error state. Chỉ chuyển trạng thái sau ACK. CreateTripScreen chưa submit vẫn giữ luồng draft hiện hành, không gửi sớm.
- Người nhận: notification vẫn tồn tại, status join từ invitation trở thành CANCELLED; không còn Chấp nhận, nội dung báo đã hủy. Popup/row cũ luôn resolve lại trạng thái trước action; backend vẫn bảo vệ race.
- Phase 4.2 bổ sung SSE foreground sau COMMIT để recipient reconcile notification hiện có sang CANCELLED ngay khi nhận signal, không tạo popup hủy mới. Polling 12 giây/refresh vẫn dự phòng; push/background chưa làm. Xem `REALTIME_NOTIFICATION_FOUNDATION_V1.md`. Nghiệp vụ/quyền/API hủy không đổi.

## File chính

- Backend: V11, TripController, TripService, TripInvitationRepository, TripInvitationInboxApiTest.
- Flutter: trip_ui_models.dart, trip_repository.dart, trip_detail_screen.dart, trip_shared_sheets.dart, message_repository.dart, message_group_invite_content.dart, gomate_member_invite_content.dart, notification model/screen.
- Tests: trip_member_invite_test.dart, notification_ui_sync_test.dart; script API verification hiện có được mở rộng cancellation cases.
- Contracts/index cập nhật; các báo cáo cũ được đánh dấu phần revoke-deferred đã được thay thế bởi bước này.

## Backup và kiểm chứng

Các kết quả ở phần này là lần triển khai API/V11. Xem phần cập nhật UI bên dưới cho lần điều chỉnh vị trí nút hủy sau đó.

Backup DB dự án trước V11: `backups/gomate_pre_invite_cancel_v11_20261015_151800.dump`, custom pg_dump, 112581 bytes, gitignored.

Trước cutover: users=37, trips=9, trip_members=14, trip_invitations=13, notifications=16, conversations=5. Flyway V1-V10 success.

Sau cutover: users=37, trips=9, trip_members=14, trip_invitations=13, notifications=16, conversations=5 (giữ nguyên). Flyway DB dự án V1-V11 đều success; GET `/health` trả UP.

| Kiểm tra đã chạy | Kết quả |
|---|---|
| `docker compose build api`, Dockerfile chạy Maven clean verify | PASS, 81 tests, 0 failure/error/skipped |
| `flutter test --no-pub` | PASS, 18 tests |
| `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos` | PASS exit 0, không error; 285 warning/info, không tăng so với trước |
| PostgreSQL sạch riêng V1 -> V11 | PASS; CHECK mới có 4 trạng thái, FK/self-invite/NOT NULL còn nguyên |
| DB hiện tại V10 -> V11 | PASS; không mất hay thêm business record |
| `pwsh -NoProfile -File backend/scripts/verify-trip-invitation-ui-sync.ps1` trên port 18082 | PASS, cả luồng invitation/chat cũ và cancellation mới |
| `docker compose up -d api`, health/compose ps | PASS |
| `git diff --check` | PASS |

Backend tests gồm quyền leader/member/outsider/invitee; sai Trip; hủy idempotent; canceled không accept/decline; mời lại ID mới; retry hủy ID cũ không tác động ID mới; không hủy ACCEPTED/DECLINED; không mất chat/member; race accept/cancel chỉ một thắng. Full suite còn kiểm tra Auth/Google/Firebase verifier, Place/Route, Follow/DM/Moments và Trip Phase 1/2/3.

Flutter tests kiểm tra hủy pending cũ và lời mời vừa gửi ngay trong popup; đợi ACK/bấm lặp; lỗi giữ pending để retry; list/count/cache cập nhật; canceled notification không có Accept/không mở Trip; form Create Trip vẫn draft. Đây là widget/API tests, chưa phải thao tác UI native trên máy thật.

API smoke dùng PostgreSQL/Mongo riêng `gomate_trip_cancel_clean_1015`, container `gomate-trip-cancel-clean-1015`; Firebase/Cloudinary tắt. Kết thúc fixture: 3 test users, 2 trips, 5 trip_members, 2 conversations, 5 invitations (3 ACCEPTED + 2 CANCELLED), 8 notifications. Đã dọn đúng container/DB test PostgreSQL/Mongo do task tạo. Không có fixture giả trong DB dự án, không dùng Flyway repair/reset volume.

Trong lần kiểm tra PG riêng ban đầu, filter metadata đọc nhầm cả status NOT NULL; đã sửa V11 chưa phát hành và chạy lại trên PostgreSQL sạch mới thành công trước khi cutover. Bản thất bại chỉ ở DB test, không tác động DB dự án.

Logs local (gitignored): `backups/docker_build_trip_cancel_final.log`, `backups/flutter_trip_cancel_test.log`, `backups/flutter_trip_cancel_analyze.log`, `backups/postgres_trip_cancel_smoke.log`. Không commit/push tự động.

## Nghiệm thu trên app

Sau backend được build/up và V11 success, hot restart app:

```powershell
.\scripts\run-android-dev.ps1 -DeviceId ANDROID_DEVICE_SERIAL -NoDockerStart
```

Nhóm trưởng mở Trip -> Thành viên -> Huỷ lời mời ngay ở người đang chờ. Kiểm tra pending/count giảm sau ACK. Mở dấu +: người đã hủy có thể chọn lại, người còn chờ không xuất hiện. Thêm một người mới: tên biến mất trong popup, đóng popup thấy lời mời ở bên ngoài. Đăng nhập người nhận, refresh Thông báo: lời mời đã hủy không còn Chấp nhận; invitation cũ không thể gia nhập. Mời lại tạo lời mời mới.

## Cập nhật vị trí nút hủy

- Chỉ sửa Flutter/tests/docs, không thay backend, API REST, quyền hoặc schema; không tạo V12 và không cần rebuild Docker.
- Thêm tùy chọn ẩn pending trong shared picker; adapter của Trip đã lưu bật ẩn, adapter form Create chưa submit vẫn giữ draft có thể bỏ lựa chọn như trước.
- TripDraftMembersScreen nối nút hủy ở dòng pending hiện có, giữ loading/ACK/error handling và cache Trip.
- RoleAwareGroupMembersScreen tải pending qua MessageRepository để hiển thị ngoài popup, gửi hủy qua repository hiện hành. Adapter dữ liệu dùng lại Trip detail API, không tạo source of truth mới.
- MessageGroupInviteContent chỉ thêm người, không giữ nút hủy bên trong; lỗi tải pending có retry, không để candidate list che lỗi API.
- Test mới bao phủ cả PERSONAL/GROUP, quyền non-leader, lỗi hủy và việc hiện lại candidate sau khi hủy.

Kết quả lần điều chỉnh UI: `flutter test --no-pub` PASS 23 tests; `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos` PASS exit 0, không error, còn 282 warning/info. Test tên dài trên width 320 và 430 px không có overflow. `git diff --check` PASS. Không chạy lại Maven/Docker vì không đổi backend; không thao tác dữ liệu DB. Chưa nghiệm thu native UI trên điện thoại.

Logs local: `backups/flutter_trip_cancel_placement_test.log`, `backups/flutter_trip_cancel_placement_analyze.log` (gitignored). Chỉ cần hot restart app, không cần rebuild Docker.
