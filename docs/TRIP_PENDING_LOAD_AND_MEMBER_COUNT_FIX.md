> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip: sửa tải lời mời chờ và số thành viên

Ngày: 2026-10-16.

## Hiện tượng và bằng chứng

- Mở phần Thành viên của lịch trình nhóm: lời mời chờ tải lặp, app có thể đơ.
- Card lịch trình nhóm hiện 1 thành viên; mở detail rồi quay lại mới đúng.
- Đọc chẩn đoán trên điện thoại `ANDROID_DEVICE_SERIAL`: Android ghi nhận ANR của GoMate,
  chờ MotionEvent 10006 ms lúc 01:10:20 ngày 16/10/2026.
- Ảnh log `FrameEvents`, `OnBackInvokedCallback`, hoặc `NoClassDefFoundError`
  không có stack cụ thể chưa đủ kết luận nguyên nhân. Không sửa manifest/Mapbox
  hoặc tắt log để che hiện tượng.

## Nguyên nhân đã tái hiện bằng test

### 1. Chat rỗng bị coi là chưa tải

`RealDirectMessageRepository.conversation()` trước đây gọi `_loadDetail()`
mọi lần đọc nếu `messages.isEmpty`. Chat mới hợp lệ vốn không có tin nhắn:

```text
đọc conversation -> gọi detail -> kết quả messages=[] -> notifyListeners
-> widget/listener đọc conversation -> lại gọi detail
```

Màn Thành viên còn gọi tải pending khi repository phát thông báo. Vòng lặp
detail kéo theo tải pending, tăng số request/rebuild và làm loading khó kết thúc.

Test có giới hạn an toàn trước sửa: chỉ đọc lại từ listener mà phát sinh **6**
request detail thay vì **1**. Test này FAIL trước sửa, PASS sau sửa.

### 2. Bỏ qua memberCount của list API

Backend đã đếm ACTIVE members và trả `memberCount` trong `GET /api/v1/trips`.
Flutter `_fromSummary()` bỏ trường đó, để `members=[]`; getter cũ mặc định là 1.
Detail trả roster đầy đủ nên việc mở detail vô tình làm số hiển thị đúng lại.

Test trước sửa: API trả **4**, UI model nhận **1**. Sau sửa nhận **4** ngay
từ list, không phải gọi detail từng lịch trình để lấy count.

## Thay đổi

- Cache phân biệt đã thử tải detail với chat không có tin nhắn. Kết quả rỗng
  là kết quả hợp lệ; lỗi không tự retry theo mỗi lần build/đọc getter.
- Gom các lời gọi detail đồng thời của cùng conversation vào một Future.
- Refresh hoặc đọc chat chủ động vẫn tải mới. Không khóa vĩnh viễn chat rỗng:
  tin nhắn mới vẫn xuất hiện khi mở/đọc lại theo luồng hiện có.
- Invalidate request cũ khi refresh/logout/mất membership/dispose; response cũ
  không được khôi phục nhóm đã rời hoặc giữ cờ loading của request bị hủy logic.
- Màn Thành viên chỉ cho một lần tải pending đang chạy. Sau thêm/hủy lời mời,
  lần tải chủ động được thay thế request cũ bằng version mới; không kẹt spinner
  và không cho response cũ đưa lời mời đã hủy trở lại.
- `TripUi` giữ count từ summary, kể cả qua `copyWith` đổi pin/tên/ngày.
  Khi có roster mới đầy đủ, count lấy từ roster mới, không giữ summary cũ.
- Pending invitees không được cộng vào số thành viên đã gia nhập.
- Cho repository/screen nhận dependency tùy chọn để test bằng HTTP giả.
  Các call-site production vẫn dùng singleton Auth/Trip/Message cũ mặc định.

## Phạm vi bảo toàn

- Không đổi layout, nút, biểu tượng hay nghiệp vụ mời/chấp nhận/hủy/rời/xóa.
- Không sửa backend, API contract, Auth/Firebase, Cloudinary, Map renderer/route.
- Không thay schema, migration, dependency hoặc cấu hình Docker/network.
- Không chạy SQL ghi dữ liệu, không gửi lời mời thử đến tài khoản thật.

## File tạo/sửa

- `lib/features/messages/data/message_repository.dart`
- `lib/features/messages/screens/group_management_screen.dart`
- `lib/features/trip/data/trip_repository.dart`
- `lib/features/trip/models/trip_ui_models.dart`
- `lib/features/trip/screens/trip_screen.dart`
- `test/trip_pending_load_regression_test.dart` (mới)
- `docs/TRIP_PENDING_LOAD_AND_MEMBER_COUNT_FIX.md` (mới)
- `docs/CODEX_INDEX.md`

## Kiểm chứng

- Hai test tái hiện FAIL trước sửa, PASS sau sửa.
- `flutter test --reporter expanded`: **96 tests PASS**, gồm 13 test mới.
- Test bao phủ count trước khi mở detail, pending không tính là member,
  copy/update roster, chat rỗng, request trùng, lỗi detail/retry chủ động,
  tin nhắn mới sau chat rỗng, logout/quyền/dispose với response về muộn,
  pending nhận notify lồng nhau, hủy giữa lúc đang tải, lỗi pending/retry,
  và render thực tế màn Thành viên/card lịch trình bằng widget test.
- Các test Map pin/unpin, invitation, membership lifecycle, notifications và
  Auth Flutter hiện có cũng nằm trong full suite trên.
- `flutter analyze --no-fatal-warnings --no-fatal-infos`: **0 errors**, còn
  16 warnings + 262 infos cũ; test mới không có issue.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1`:
  **PASS**, Gradle 92.5 giây. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: **PASS**, chỉ có cảnh báo chuẩn hóa CRLF sẵn có.
- Logs local (gitignored): `backups/trip_pending_load_red_20261016.log`,
  `backups/trip_pending_load_full_test_20261016.log`,
  `backups/trip_pending_load_analyze_20261016.log`,
  `backups/trip_pending_load_apk_20261016.log`.

## Kiểm thử máy thật còn cần

Widget/HTTP tests chứng minh hai lỗi dữ liệu/request đã được sửa; không thay
thế kiểm tra thao tác/native ANR trên điện thoại sau bản mới. Chưa tự thao tác
tài khoản người dùng hoặc cài lại app trên điện thoại trong task này.

1. Dừng bản app cũ, hot restart/chạy lại app từ code mới, không chỉ hot reload.
2. Vào tab Lịch trình: các nhóm phải có số thành viên đúng ngay, không cần mở detail.
3. Mở nhóm chưa có tin nhắn -> Thành viên: pending tải xong, UI cuộn/bấm được.
4. Thêm/hủy lời mời: pending cập nhật sau ACK, không xoay vô hạn/hiện lại dòng cũ.
5. Mở chat rỗng, quay lại, mở lại: không phát sinh chuỗi tải detail liên tục.
6. Thử mất kết nối: pending hiện lỗi/retry, không báo giả thành công.

Không cần restart/build lại Docker hoặc chạy migration cho bản sửa này.
