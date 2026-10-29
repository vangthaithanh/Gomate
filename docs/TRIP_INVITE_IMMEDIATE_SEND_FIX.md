> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip - Fix bước Gửi dư sau khi đã tạo lịch trình

Ngày: 2026-10-15.

Cập nhật sau theo yêu cầu mới: nhóm trưởng đã được bổ sung hủy PENDING trong `TRIP_INVITATION_CANCELLATION.md`. Ghi chú revoke-deferred trong báo cáo này là trạng thái tại thời điểm sửa bước Gửi dư, không còn là contract mới nhất.

## Testcase và nguyên nhân

Lịch trình vừa tạo: mở Thành viên -> dấu + -> tick người -> Thêm. Code cũ đưa người vào state pending cục bộ, hiện `Gửi (n)` ở header; chỉ khi bấm Gửi mới gọi backend. Người dùng đã thấy Đang chờ dù server chưa có lời mời.

Điểm rẽ thực tế không phải phiên đăng nhập:

- Trip đã có linked group chat mở `RoleAwareGroupMembersScreen`, adapter Messenger đã gửi ngay khi bấm Thêm.
- Trip chưa có chat mở `TripDraftMembersScreen`, adapter còn dùng cách chọn nháp trước khi tạo Trip.
- Trip mới tạo thường vẫn PERSONAL, chưa ai accept nên chưa có chat; vì vậy đi vào nhánh có lỗi. PERSONAL cũ chưa có chat cũng có thể gặp lỗi này.

Một Trip đã nhận create ACK và có ID server là đã được lưu, kể cả lifecycle trong DB đang là DRAFT. Không được nhầm với form CreateTripScreen chưa submit.

## Luồng sau sửa

```text
Trip đã lưu -> Thành viên -> + -> chọn người -> Thêm
-> POST /api/v1/trips/{tripId}/members
-> server tạo PENDING invitations + inbox notifications
-> ACK -> cập nhật Trip/pendingInvitees trên màn Thành viên và session dùng chung
-> quay lại chi tiết giữ đúng số lời mời
```

- Không có nút Gửi phụ ở header.
- Không thêm vào members, không tạo GROUP/chat trước khi invitee accept trong Thông báo.
- Chặn request lặp khi đang gửi; chỉ chuyển pending sau ACK. Lỗi giữ lựa chọn để retry, không báo đã gửi giả.
- Đóng màn Thành viên trả Trip mới nhất về TripDetail; giữ trạng thái ghim của UI.
- CreateTripScreen chưa submit vẫn chỉ chọn nháp, có thể bỏ người đã chọn; chưa gọi API gửi riêng. Lời mời chỉ tạo khi hoàn tất create như contract hiện hành.
- Không giả hủy lời mời đã gửi: revoke API vẫn deferred như phiên trước. Nhánh draft chưa tạo vẫn cho bỏ lựa chọn cục bộ.
- Giữ layout/popup/shared picker hiện có; chỉ bỏ thao tác Gửi dư được người dùng yêu cầu. Không sửa Map/Auth/acceptance flow.

## File sửa/tạo

- `lib/features/trip/screens/trip_detail_screen.dart`: nhánh PERSONAL đã lưu gửi ngay; giữ Trip từ ACK; bỏ staging + Gửi phụ. Tên class TripDraftMembersScreen là tên legacy, không biểu thị Trip chưa lưu.
- `lib/features/trip/widgets/trip_shared_sheets.dart`: callback async `onSendInvites` cho Trip đã lưu; mặc định vẫn là draft cho CreateTripScreen. Reuse error/double-tap handling của shared picker.
- `test/trip_member_invite_test.dart`: 5 regression tests.
- `docs/PROJECT_CONTRACT.md`, `docs/CODEX_INDEX.md` và báo cáo UI sync: ghi nhận phân biệt draft/create với Trip đã lưu.

Không sửa endpoint/schema/migration/config/dependency. Không cần Docker rebuild hoặc reset DB.

## Kiểm thử

`flutter test --no-pub`: PASS, 14 tests (9 hiện có + 5 mới).

`flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`: PASS exit 0, không có error; 285 warning/info, bằng tổng trước bản sửa này. `git diff --check`: PASS.

5 tests mới kiểm tra:

1. Trip mới tạo gửi ngay từ Thêm, không Gửi phụ; giữ lời mời cũ, đúng count khi back/reopen; không thành GROUP/member/chat trước accept.
2. Trip PERSONAL mở lại từ phiên trước có cùng hành vi.
3. Chờ ACK, bấm Thêm lặp chỉ 1 request; không hủy lời mời server giả.
4. Lỗi mạng không tạo pending giả, giữ lựa chọn và retry thành công.
5. Form CreateTripScreen vẫn draft, không gửi/create trước khi người dùng hoàn tất tạo.

Test widget dùng fake repository với controlled ACK/failure, không ghi user/Trip vào DB thật. Không chạy lại Maven vì không thay backend. Chưa thao tác thủ công trên điện thoại trong bước này.

Log local: `backups/flutter_trip_invite_send_test.log` và `backups/flutter_trip_invite_send_analyze.log` (gitignored).

## Chạy và nghiệm thu

Thực hiện **hot restart** hoặc chạy lại app, không chỉ hot reload vì state màn Thành viên đã thay đổi. API Docker hiện tại giữ nguyên.

```powershell
.\scripts\run-android-dev.ps1 -DeviceId ANDROID_DEVICE_SERIAL -NoDockerStart
```

Tạo Trip mới -> Thành viên -> + -> chọn người -> Thêm -> đóng popup: phải thấy Đang chờ và không có Gửi (n). Back/reopen giữ nguyên. Đổi tài khoản người nhận để kiểm tra inbox. Người chỉ được chọn bằng luồng lỗi cũ nhưng chưa từng bấm Gửi chưa có invitation server; cần chọn và Thêm lại sau restart, không tự gửi dữ liệu nháp cũ.
