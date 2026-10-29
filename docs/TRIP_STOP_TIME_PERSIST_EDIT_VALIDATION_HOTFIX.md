> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Trip Stop — lưu giờ, mở lại và kiểm tra Add/Edit

Ngày thực hiện: 28/10/2026. Phạm vi: giờ của từng Trip Stop occurrence. Không đổi giao diện/layout cũ, lịch nhắc D-2/D-1, Pin/GPS, membership/chat hoặc Social. Không có migration/dependency/config mới.

## 1. Nguyên nhân có bằng chứng

Không thiếu cột DB. V3 đã có UUID occurrence, `planned_start_at TIMESTAMPTZ`, `planned_duration_min`. Trước sửa, 7 Stop đang có không chứa giờ; điều này không đủ để kết luận những lần thao tác của người dùng đã gửi được giờ.

Tái hiện bằng API thật/PostgreSQL trên lịch trình thử riêng của tài khoản GoMate Test Realtime:

- Trip `REDACTED_UUID`, Stop `REDACTED_UUID`, ngày 2 = 03/01/2030.
- POST start `2030-01-03T10:00:00+07:00`, end `2030-01-03T10:01:00+07:00`.
- DB thực lưu `2030-01-03 03:00:00+00`, duration `1`: ĐÚNG instant.
- Response cũ trả `2030-01-03T03:00:00` / `03:01:00` mà không có offset: SAI round-trip khi Flutter hiểu là giờ thiết bị.
- Test Flutter chứng minh summary refresh có thể thay UUID/times bằng `summary-stop-*`; Map chỉ hydrate một lần mỗi Trip ID nên các lần refresh sau có thể tiếp tục thiếu chi tiết.
- Serializer PATCH cũ tự gửi `clearTime=true` ngay cả khi caller không truyền giờ. Editor luôn dựng lại giờ từ ngày Trip hiện tại, có nguy cơ đổi instant cũ sau khi sửa ngày Trip.
- Picker cũ làm tròn phút đã lưu về bội số 5. Save lỗi vẫn đóng form; chưa chặn nhấn lưu trùng.

Artifacts riêng tư, không commit: `backups/trip-stop-time-hotfix-20261028/`. Chứa trace không token, backup DB và JAR trước cutover. Không ghi token/password/GPS trong báo cáo.

## 2. Luồng sau sửa

- Summary được đánh dấu `isDetail=false`. Session giữ các occurrence đang hiển thị trong lúc chờ detail mới, không dùng placeholder làm nguồn giờ. Map tải detail khi thiếu, có in-flight guard; không polling và không tải detail theo pan/zoom/GPS tick.
- Chạm sửa lấy lại detail backend, tìm đúng UUID đã chạm. Editor giữ UUID, không giữ index có thể đổi sau reorder. A → B → A là ba occurrence riêng.
- Chưa chọn giờ vẫn là null; không tự phát sinh 00:00. Có thể chạm rõ vào số trên wheel để chọn 00:00. Phút cũ không tròn 5 được giữ nguyên trong wheel; các bước 5 phút cũ vẫn giữ.
- Chỉ khi giá trị giờ thực sự đổi mới gửi time fields. Không đổi giờ → PATCH bỏ time fields, kể cả khi Trip đã đổi ngày. Chủ động bỏ start → `clearTime=true`.
- Save chỉ đóng sau ACK, chỉ áp dụng response vào flow còn hiện hành. Save lỗi giữ draft và báo lỗi cạnh input, chặn submit lặp; giờ start hết hiệu lực thì trở về input start để sửa.
- Dùng time-context sẵn có khi mở form; không dùng đồng hồ/múi giờ thiết bị để quyết định ngày hợp lệ. Spring dùng Clock hiện hành kiểm tra cuối cùng dưới Trip/LEADER lock.

## 3. API và schema

Giữ nguyên endpoint POST/PATCH/GET Trip Stop/Trip Detail.

```json
{
  "placeId": 156,
  "dayNo": 2,
  "plannedStartAt": "2030-01-03T10:00:00",
  "plannedEndAt": "2030-01-03T10:01:00"
}
```

Input không offset là wall time trong **Trip.timezone**, được Spring resolve qua ZoneId; client cũ gửi ISO có offset vẫn được hỗ trợ. DST gap bị reject; khi wall time trùng do DST overlap, chọn lần đầu một cách deterministic (cùng quy ước reminder), không hard-code +07.

Response chứa instant UTC `plannedStartAt`/`plannedEndAt` có `Z`; thêm `plannedLocalStartAt`/`plannedLocalEndAt` không offset, chỉ dành cho hiển thị theo Trip timezone. Flutter giữ raw instants nhưng hiển thị HH:mm từ hai trường local, không `.toLocal()` theo điện thoại.

PATCH semantics:

- Không gửi time fields hoặc chỉ null, không clear flag: giữ giờ cũ theo contract hiện tại.
- `clearTime=true`: xóa start và duration, end derive thành null; flag clear có ưu tiên.
- Chỉ start: duration/end null, `hasCompleteInterval=false`; không tái dùng duration cũ.
- End-only: không tạo start; theo quy tắc cũ coi là clear/unscheduled.
- Có cả hai: tính duration theo phút; end phải sau start trong cùng ngày Stop.

Ngày Stop là `trips.start_date + day_no - 1`, calendar arithmetic trong timezone Trip. Set/đổi giờ mới trên ngày đã qua, start <= server now, sai ngày, end <= start, end sang ngày khác → HTTP 400 `TRIP_STOP_TIME_INVALID`, không ghi đè DB. MEMBER vẫn chỉ đọc. Unchanged historical interval không bị kiểm tra lại như một thời gian mới.

Không tự dịch/xóa giờ cũ sau đổi ngày Trip. Timestamp có thể không còn khớp dayNo mới; vẫn đọc nguyên giá trị lịch sử, chỉ đặt lại theo ngày mới khi người dùng chủ động chỉnh giờ. Không migration/rebase hàng loạt.

## 4. File liên quan hotfix

Backend: `TripDtos.java`, `TripService.java`, mới `TripStopTime.java`; tests `TripApiTest.java`, mới `TripStopTimeTest.java`.

Flutter: `trip_repository.dart`, `trip_ui_models.dart`, `map_ui_session.dart`, `map_screen.dart`, `map_add_place_flow_panel.dart`; tests `trip_start_reminder_test.dart`, mới `trip_stop_time_hotfix_test.dart`.

Docs: báo cáo này, `CODEX_INDEX.md`, đoạn Stop của `PROJECT_CONTRACT.md` / `DATABASE_CONTRACT.md`.

## 5. Kiểm chứng

- Backend tập trung: **61 tests PASS** (Stop unit/API, Trip date reminders, Notification SSE/push và GoogleFlow).
- Flutter tập trung: **61 tests PASS** (7 ca hotfix, date reminders/read ACK, pin panel và pending-load regression).
- Flutter toàn bộ: **298 tests PASS** (baseline ngay trước hotfix 291 = 289 trước vá read-ACK + 2 test ACK; thêm 7 test).
- APK debug bản cuối build PASS (128,4 giây), chưa tự cài lên điện thoại. File: `build/app/outputs/flutter-apk/app-debug.apk`; SHA256 `0CCED2F1CBAD4E6BA024179D0655783C00A39F6E421525F40438404CB05B1BA4`. Cần dùng APK mới cùng API mới đã cập nhật, hoặc chạy lại Flutter hoàn toàn từ source hiện tại.
- Root `docker compose build --build-arg 'TESTS=Trip*,Notification*,ApiIntegrationTest,GoogleFlowTest,FirebaseGoogleApiTest,AccountProfileApiTest,PlaceApiTest,RouteApiTest,GroupTripChatApiTest' api`: **146 tests PASS**, 0 failure/error/skip; image build PASS. Đây là regression liên quan, không phải chạy toàn bộ backend/Post/Mongo integration suite trong phase này.
- `flutter analyze --no-pub`: **0 errors / 15 warnings cũ**, không warning mới (344 info cũ; lints mới trong code hotfix đã sửa).
- API/PostgreSQL thật: **20 request PASS** trên Trip thử riêng: GET giờ cũ đã lưu, PATCH interval, note-only, null không clear, start-only, end-only, A → B → A, reject interval/date sai không thay dữ liệu, reorder/optimize/delete giữ occurrence/giờ còn lại, explicit clear rồi set lại.
- Restart backend bằng Compose và login lại tài khoản thử: cùng Stop UUID `REDACTED_UUID` vẫn có instant `2030-01-03T07:00:00Z`, end `07:05:00Z`, local **14:00–14:05**, duration **5**. DB/GET sau restart cùng kết quả.
- 7 Stop cũ ngoài Trip thử giữ nguyên hash `b5c356b3c13509a774445eeac19c2169`. Cutover snapshot 8 Stop → 9 Stop do bài thử giữ thêm B; tổng dữ liệu thử của phase này là 1 Trip riêng + 2 Stop còn lại (A thứ hai được xóa qua API trong test). Không cập nhật/bịa giờ cho 7 Stop cũ đang null.
- Reminder count trước/sau Stop tests vẫn **14**; không tạo lại lịch nhắc khi sửa Stop. Giữ nguyên D-1 Karachi ngày 29/10 và toàn bộ lịch/Inbox đã nghiệm thu.
- Flyway thật: 25 history rows thành công, version **1–25**, không V26. Startup validate thành công, schema up to date/no migration necessary. 24 migration cũ so với snapshot trước V25 không đổi hash; V25 không chỉnh sửa.
- Compose sau kiểm tra vẫn chỉ 4 service đang chạy (api/postgres/mongo/ai), không giữ API test thừa. Không reset volume.
- Không cần clean DB/upgrade migration test mới vì không thay schema. Startup phải validate toàn bộ V1–V25 và không tạo V26.

Các unit/API tests dùng deterministic Clock kiểm tra ngày hôm qua/hôm nay/ngày mai, start bằng hiện tại, interval bằng/nhỏ hơn/1 phút/qua ngày, optional/end-only, timezone/DST; historical metadata và ngày Trip đổi không rebase; A → B → A, clear, reorder/optimize giữ UUID/giờ, LEADER/MEMBER.

## 6. Checklist Android — chưa nghiệm thu máy thật trong lượt hotfix này

1. Chạy bản backend/APK mới cùng nhau. Chọn Trip có ngày từ hôm nay trở đi; thêm Stop không giờ → mở lại vẫn trống.
2. Chọn đúng ngày 1/2, cuộn start/end tương lai → lưu → mở lại thấy đúng cả hai; đổi giờ rồi rời tab/reload/relogin vẫn đúng.
3. Bỏ end → start-only, không hiện khoảng giờ đầy đủ. Bỏ start → clear; reload phải trống. Không thao tác wheel → không tự có 00:00.
4. Ngày hôm nay: thử giờ đã qua; phải có lỗi và giữ form. Để form qua thời điểm đã chọn rồi lưu: server phải chặn. Ngày đã qua phải hướng dẫn sửa ngày Trip trước.
5. End bằng/sớm hơn start → lỗi cạnh input; sửa lại trong form đang mở. Kiểm tra giờ tương lai hợp lệ lưu được.
6. Thêm A → B → A; sửa A thứ hai, A đầu không thay. Reorder/optimize vẫn giữ giờ đúng occurrence. MEMBER chỉ xem.
7. Trip đã đổi ngày: giờ lịch sử không tự bị dời; mở editor không đổi giờ rồi lưu vẫn giữ instant cũ. Chỉ đổi giờ khi muốn đặt lại cho ngày Trip mới.
8. Xác nhận Map vẫn mượt khi pan/zoom, layout cũ giữ nguyên; không có T-60/T-30 hay auto-pin phát sinh từ chỉnh Stop.

Không coi widget/API tests là bằng chứng đã test Android thật. Dừng sau hotfix, không mở phase khác.

## 7. Bổ sung đường thoát form — 29/10/2026

User phát hiện form sửa giờ của ngày đã qua không có đường thoát. Nguyên nhân: đây là panel nằm trong Stack của Map, không phải modal bottom sheet có dismiss mặc định. Khi panel mở, thanh tab bị ẩn và Map tap bị bỏ qua; validation giữ form nhưng thiếu Close/Back.

Sửa thuần Flutter:

- Thêm **Đóng** cạnh Tiếp tục, dùng cùng màu/chữ và kích thước hiện tại, cho cả chọn ngày/start/end, ở Add và Edit. Panel không tăng chiều cao chỉ để thêm nút này.
- Đóng gọi đúng `_closeAddFlow`: bỏ draft/error/ID đang sửa, phục hồi thanh tab, giữ Trip/ngày đang xem. Không gọi Bỏ qua, không clear giờ trên DB, không POST/PATCH mới.
- Back trên Android đóng form trước, giữ trang Map. Sau khi form đã đóng, Back trở lại hành vi điều hướng bình thường. Modal đang nằm trên Map được đóng trước theo Navigator hiện tại.
- MainShell truyền `active` vào Map để chỉ Map đang hiện mới giữ Back. Map nằm ẩn trong IndexedStack không chặn Back của tab khác, kể cả vào Map bằng đường dẫn địa điểm từ Home.
- Đóng vẫn dùng được khi đang chờ lưu/lỗi mạng. Request đã gửi trước khi Đóng có thể đã/đang được server ghi; Đóng không phải thao tác rollback. Serial guard hiện có bỏ qua callback mở/cập nhật form đã đóng; lần mở sửa tiếp theo lấy lại backend truth. Không tạo retry/polling hoặc tự ghi giờ khi thoát.

File bổ sung lần này: `map_add_place_flow_panel.dart`, `map_screen.dart`, `main_shell.dart`; test mới `test/map_stop_flow_exit_test.dart`, cập nhật constructor trong `trip_stop_time_hotfix_test.dart`. Backend, schema, Flyway, permission, validation giờ và D-2/D-1 giữ nguyên; không cần cập nhật API/Docker cho lần sửa này.

Kiểm tra các đường liên quan: Trip picker có Hủy; Place search có Hủy; calendar dùng `GoMateBottomSheet.show` mặc định có tap ngoài/vuốt xuống/Back. Không sửa các màn đó. Đường thiếu exit là panel day/start/end dùng chung đã sửa ở trên.

Kiểm thử mới: 15 ca (3 bước × bình thường/ngày đã qua/interval sai/lỗi mạng/đang lưu), kiểm tra Đóng không phát callback save/skip/time; Back ưu tiên modal → form → trang; Map ẩn và form không mở không chiếm Back. **18 test mới + regression tập trung tổng 63 PASS; toàn bộ Flutter 316 tests PASS** (baseline 298 + 18). Analyze cuối **0 errors / 15 warnings cũ / 344 info**, không warning mới. Log tại `backups/trip-stop-flow-exit-20261029/` (ignored). Không chạy lại backend tests vì lần này chỉ sửa Flutter/đường thoát, không sửa backend hay DB.

Máy thật còn cần kiểm tra: mở Stop của Trip cũ → chọn giờ bị chặn → Đóng hoặc Back → thấy lại Map/thanh tab; thử tương tự khi thêm mới, sai end≤start và lỗi mạng. Mở lại phải đọc giờ từ backend, không bị tự xóa do thao tác Đóng. Chưa coi các ca này là native PASS khi chưa có xác nhận người dùng.

APK bản bổ sung đường thoát build PASS (194,7 giây): `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `0C397D66C51808B06A7C437E6381A5D60DD961591B45C934F8BAF57B1FE2747A`. Bản này thay APK bàn giao ở mục 5; chưa tự cài lên điện thoại.

## 8. Cân chỉnh riêng khung chọn giờ — 29/10/2026

Người dùng xác nhận fix đường thoát đã ổn, yêu cầu chỉnh nhẹ giao diện. Chỉ sửa style cho bước giờ bắt đầu/kết thúc trong `map_add_place_flow_panel.dart`: khung thoáng hơn một chút, tiêu đề/nút/số có phân cấp chữ đồng nhất; Đóng có nền xám `AppColors.grayBorder`, chữ tối rõ, bo góc và chiều cao đồng bộ với Tiếp tục. Giữ gradient xanh, nền trắng và bảng màu hiện hành.

Không sửa khung danh sách địa điểm kéo lên/xuống (`map_day_route_panel.dart`), style bước chọn ngày, callbacks Back/Đóng/Bỏ qua/Lưu, validation, dữ liệu hoặc backend. Chạy lại các test có sẵn về đường thoát, giờ và panel Map; không thêm test chỉ để kiểm tra màu/chữ.

Kiểm chứng style: **48 tests liên quan PASS**; analyze riêng file sửa có **0 errors / 0 warnings**, còn 1 info deprecation `withOpacity` đã có trước đó. Không chạy lại backend tests cho thay đổi thuần giao diện này.

APK style mới build PASS (126,5 giây), thay bản ở mục 7: `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `EE6D607DC4B6B90AEB15154C31985738F87326F34B2356C8A38E4512127BD73C`. Chưa tự cài lên điện thoại.
