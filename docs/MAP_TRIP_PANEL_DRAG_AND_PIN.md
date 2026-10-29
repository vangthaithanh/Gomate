# Map: khung lịch trình kéo được và nút ghim

Ngày: 2026-10-16.

## Phạm vi

- Chỉ điều chỉnh UI Map theo yêu cầu: khung danh sách địa điểm và nút ghim.
- Không đổi Auth, Place, Route, chat, quyền thành viên hay nghiệp vụ lịch trình.
- Không sửa backend/schema/config/dependency; không có migration mới.
- Flyway giữ nguyên V1 đến V13 của bước trước, không chạy lại migration trong task này.

## Khung danh sách

- Khi mở rộng lịch trình đang xem/ghim, danh sách dùng `DraggableScrollableSheet`.
- Kéo thanh ngang trên đầu khung để thay đổi chiều cao. Vuốt danh sách cũng mở
  khung; tới giới hạn trên thì tiếp tục cuộn danh sách.
- Mức thu gọn dùng chiều cao cũ: `clamp(width * 0.64, 220, 270)` logical pixels.
  Màn hình thấp hơn thì giới hạn theo không gian thực còn lại.
- Mép trên tối đa nằm dưới tiêu đề lịch trình 8 logical pixels; không phủ tiêu đề.
- Mép dưới luôn neo đáy Map, không đóng/biến mất khi kéo xuống.
- Giữ khoảng đệm dưới theo chiều cao navigation bar thực tế để có thể cuộn tới
  điểm cuối cùng; bỏ giới hạn cũ 110 px vốn có thể che điểm cuối trên máy có
  navigation/safe-area cao.
- Danh sách rỗng và thành viên chỉ có quyền xem vẫn kéo/cuộn được.
- Giữ nguyên callback sửa giờ, tối ưu, xóa và long-press đảo thứ tự địa điểm.
- Chiều cao khung không nằm trong state của Map screen. Kéo khung không gọi
  API, không dựng lại Map widget, không yêu cầu render marker/route.
- Giữ chiều cao đã kéo qua lần cập nhật dữ liệu khi khung vẫn đang mở;
  đóng rồi mở lại khung sẽ về mức thu gọn.

## Nút ghim trên Map

- Có lịch trình đang hiển thị thì hiện icon ghim ngay dưới nút vị trí hiện tại.
- Nút chat nằm dưới nút ghim, chỉ hiện với lịch trình nhóm. Không giữ slot chat
  rỗng cho lịch trình cá nhân, nên không còn khoảng trống ở giữa các nút.
- Không có lịch trình thì không hiện nút ghim. Search/chọn lịch trình/vị trí
  hiện tại vẫn giữ vị trí cũ.
- Target là `GoMateMapUiSession.displayedTrip`: lịch trình đang chọn trước,
  nếu không có thì lịch trình đang ghim.
- Reuse `GoMateLocationService.ensureAlwaysForPinnedTrip()`:
  GPS bật và quyền vị trí **Luôn cho phép**, giống trang Lịch trình hiện tại.
- Reuse `RealTripRepository.pin(id)` -> `POST /api/v1/trips/{id}/pin`.
  Backend hiện có đã xác minh JWT/thành viên, lưu pin theo user và thay pin cũ.
- Chờ server ACK mới cập nhật `GoMateMapUiSession.updateTrip` và báo thành công.
- Có trạng thái chờ/chặn double-tap. Lỗi API giữ pin cũ và cho phép thử lại.
- Lịch trình đã ghim được tô màu; bấm lại **bỏ ghim** bằng
  `RealTripRepository.unpin(id)` -> `DELETE /api/v1/trips/{id}/pin`.
- Bỏ ghim không kiểm tra GPS/quyền vị trí. Chờ server ACK rồi mới bỏ màu,
  cập nhật pin ở UI dùng chung và báo `Đã bỏ ghim lịch trình`.
- API bỏ ghim lỗi thì giữ pin/màu cũ và cho thử lại. Chặn double-tap trong lúc chờ.
- `clearPinnedTrip(tripId: ...)` đồng bộ cả cờ `isActive` của lịch trình đang
  xem và danh sách, giữ nguyên địa điểm/ngày/selection. ACK của pin cũ không
  được xóa pin mới của một lịch trình khác.
- Snapshot GPS gửi qua repository có sẵn theo best-effort sau ACK, không giữ
  nút chờ GPS và không biến pin thành thất bại nếu GPS/snapshot lỗi.
- Không đổi lịch trình/ngày đang xem nếu user chọn lịch trình khác khi request
  ghim trước đó còn đang chờ.

## File liên quan

- `lib/features/map/screens/map_screen.dart`: giới hạn khung, gắn nút ghim.
- `lib/features/map/widgets/map_day_route_panel.dart`: kéo/cuộn có giới hạn.
- `lib/features/map/widgets/map_trip_header.dart`: dùng chung chiều cao header.
- `lib/features/map/widgets/map_controls.dart`: slot ghim, button loading/selected.
- `lib/features/map/widgets/map_trip_pin_button.dart`: UI action, permission, ACK.
- `lib/features/map/state/map_ui_session.dart`: đồng bộ cờ ghim của selection
  khi bỏ ghim, không xóa lịch trình đang xem.
- `test/map_trip_panel_test.dart`: 22 widget tests cho khung kéo và nút toggle ghim.
- `docs/CODEX_INDEX.md`: đường dẫn tri thức cho lần làm sau.

## Kiểm thử

- `flutter test --reporter expanded`: **83 tests PASS** (22 test khung kéo/ghim).
- Các test mới kiểm tra giới hạn kéo, cuộn tới điểm cuối, không rebuild Map
  sibling, empty-state, viewport 320x640/640x360, không mất quyền read-only,
  giữ callbacks sửa/xóa/tối ưu/reorder, pin ACK/double-tap/retry, bốn trạng thái
  chặn quyền GPS, snapshot lỗi/thành công, dispose khi chờ ACK, đổi selection
  và card cuối không bị navigation inset 140 px che khuất.
- Bổ sung test bỏ ghim chờ ACK, lỗi/retry, không cần GPS, không mất điểm/ngày,
  dispose khi chờ, đổi selection và không xóa pin mới của lịch trình khác;
  kiểm tra pin ngay sau vị trí hiện tại, chat nằm cuối và không có gap cho chat ẩn.
- Analyze các file Dart sửa trong lần bổ sung toggle: không có error/warning;
  còn 2 infos `withOpacity` có sẵn trong style nút.
- Analyze toàn repo ở bước khung kéo trước: 0 errors, 16 warnings + 262 infos cũ.
- `git diff --check` cho các file tracked đã sửa: PASS.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1`:
  **PASS**. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Log analyze/build: `backups/map_ui_drag_pin_analyze_20261016.log` và
  `backups/map_ui_drag_pin_apk_20261016.log` (local, không commit).
- Log: `backups/map_ui_drag_pin_flutter_test_20261016.log` (local, không commit).
- Log của lần sửa thứ tự và toggle:
  `backups/map_pin_toggle_flutter_test_20261016.log`,
  `backups/map_pin_toggle_analyze_20261016.log`,
  `backups/map_pin_toggle_apk_20261016.log` (local, không commit).
- Widget tests không thay thế kiểm tra gesture/native Mapbox trên điện thoại.
  Chưa tự thao tác test thay đổi này bằng tài khoản người dùng trên máy thật.
  Không tự cài APK/khởi động lại app đang chạy trên điện thoại của người dùng.

## Test bằng người dùng

1. Hot restart (không chỉ hot reload) app với backend đang chạy, mở Map,
   chọn/mở lịch trình. Nếu chạy từ APK cũ thì cài/chạy lại bản build mới trước.
2. Mở khung danh sách; kéo lên tới dưới header, xuống lại mức ban đầu.
3. Thử cuộn danh sách dài tới cuối, đổi ngày, sửa giờ/đảo điểm nếu là nhóm trưởng.
4. Thu khung, bấm icon ghim bên phải: kiểm tra màu nút và lịch trình ghim ở tab
   Lịch trình; chuyển tab rồi quay lại Map vẫn đúng lịch trình đã ghim.
5. Bấm lại icon: bỏ ghim, màu trở lại bình thường, tab Lịch trình cập nhật ngay;
   lịch trình/ngày/địa điểm đang xem trên Map vẫn giữ nguyên. Thử khi GPS tắt:
   bỏ ghim vẫn phải hoạt động, không mở Settings/xin quyền.
6. Thử ghim khi GPS tắt/thiếu quyền hoặc API mất kết nối: phải báo lỗi,
   không báo ghim giả. API bỏ ghim lỗi phải giữ trạng thái ghim cũ.

Không cần build/restart Docker hay cấu hình lại database cho thay đổi này.
