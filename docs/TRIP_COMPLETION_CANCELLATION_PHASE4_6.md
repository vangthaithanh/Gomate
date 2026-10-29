> SUPERSEDED for journey lifecycle by TRIP_PIN_CENTRIC_BUSINESS_RESET.md. Do not reintroduce Start/Complete/Cancel.

> SUPERSEDED BY TRIP_PIN_CENTRIC_BUSINESS_RESET (2026-10-16).
> Journey status / Start / Complete / Cancel / separate Share rules below are historical.
> Preserve reusable native GPS, cadence, permissions and Map performance only.

# Phase 4.6 - Trip Completion / Cancellation

Ngày thực hiện: 2026-10-16.
Trạng thái: IMPLEMENTED / AUTOMATED + REAL STORE VERIFIED / ANDROID MANUAL PENDING.
Chưa tuyên bố PHASE_4_6_CLOSED khi chưa nghiệm thu các tình huống trên thiết bị thật.

## Nghiệp Vụ Chốt

- START != PIN != SHARE. COMPLETED != CANCELLED != ARCHIVED.
- Không có scheduler tự kết thúc/hủy. Qua ngày cuối, 23:59, hết giờ điểm dừng,
  thiếu GPS hoặc không mở app đều không tự thay đổi lifecycle.
- LEADER: DRAFT/PLANNED -> ACTIVE; ACTIVE -> COMPLETED;
  DRAFT/PLANNED/ACTIVE -> CANCELLED. Không mở lại; không đổi terminal sang nhau.
- Gọi lại cùng thao tác terminal trả detail hiện tại, không lặp side effect.
- MEMBER/ngoài nhóm không được kết thúc/hủy. Danh tính lấy từ JWT.
- Terminal vẫn có trong danh sách/chi tiết, giữ thành viên và các điểm để xem lại.
  Chặn sửa thông tin/điểm, reorder/optimize, thêm/rời/xóa/chuyển trưởng nhóm,
  mời/nhận lời mời cũ, ghim, Share ON, GPS và gửi GROUP chat.
- Xóa/lưu trữ vẫn riêng biệt: chỉ Leader, ẩn khỏi danh sách và quyền truy cập,
  không đổi lại terminal và không hard-delete lịch sử.

## Audit / Điều Chỉnh Kỹ Thuật

- Schema V3 đã có COMPLETED/CANCELLED, started_at/completed_at. V14 có archived_at,
  V15 có thời điểm thay đổi Share. Không thêm bảng/cột/migration; không sửa V1-V15.
- Dùng GROUP conversation.status=CLOSED theo V13 thay vì thêm ARCHIVED/INACTIVE.
  Giữ conversation/member/message history; API chat hoạt động vẫn từ chối như
  Phase 4.4A/B. Không tự thêm màn xem lịch sử chat đã đóng.
- API PATCH Trip cũ nhận status trực tiếp: nay đi chung luồng cleanup với POST
  terminal. Request gộp terminal + đổi thông tin trả 400, không cập nhật nửa chừng.
  Không cho ACTIVE quay về DRAFT/PLANNED.
- Không thay nghiệp vụ Auth/DM/Moment/AI/Place/Mapbox; không thêm dependency.

## API

Base `/api/v1`, JWT hiện có, response TripDetail hiện có.

| API | Điều kiện | Kết quả |
|---|---|---|
| POST /trips/{id}/start | Leader, DRAFT/PLANNED/ACTIVE | ACTIVE; không tự Pin/Share |
| POST /trips/{id}/complete | Leader, ACTIVE | COMPLETED + cleanup |
| POST /trips/{id}/cancel | Leader, DRAFT/PLANNED/ACTIVE | CANCELLED + cleanup |
| PATCH /trips/{id}, status terminal | Leader | Cùng cleanup; không bypass |
| GET /trips, GET /trips/{id} | Thành viên được giữ lại, chưa archive | Gồm lịch sử terminal |
| DELETE /trips/{id} | Leader được giữ lại | Archive riêng, idempotent |

403: có trong nhóm nhưng không phải Leader; 404: không có quyền xem/đã archive.
422 TRIP_CANNOT_COMPLETE: chưa ACTIVE. 422 TRIP_CANNOT_START: đã terminal.
409 TRIP_CLOSED: sửa/pin/thao tác active trên terminal hoặc đổi terminal khác.
409 invitation closed: lời mời cũ không thể tạo membership.
422 TRIP_LOCATION_NOT_ACTIVE: không được đọc/gửi GPS hoặc bật Share.
GROUP chat đã đóng trả 404 như convention lifecycle trước.

TripDetail trả status thật, pinned=false, linkedConversationId=null,
members[].locationSharingEnabled=false, pendingInvitations=[], giữ stops/reminders.
COMPLETED ghi completedAt; CANCELLED không giả làm completedAt/cancelled_at.

## Transaction / Runtime

1. Khóa trips bằng FOR UPDATE trước invitation/member/chat mutation.
2. Xác minh người dùng, vai trò và transition; retry cùng terminal thoát sớm.
3. Ghi status; PENDING invites -> CANCELLED; Share tất cả cùng Trip OFF và cập nhật
   location_sharing_updated_at; xóa pins đúng Trip; chat GROUP đang active -> CLOSED.
4. Cập nhật trạng thái notification lời mời đã có, không thêm inbox row/loại mới.
5. Sau COMMIT: invalidation SSE vị trí + deleteByTrip Mongo current snapshots.
   Hai nhánh best-effort độc lập; lỗi được log tripId/error type, không lộ tọa độ.

PostgreSQL đóng quyền ngay khi commit. Mutation khác đồng thời phải chờ cùng
Trip lock và đọc lại state, nên không nhận lời mời/gửi chat/bật Share sau closure.
Mongo lỗi không rollback lifecycle; snapshot còn sót không có quyền đọc/publish.
Chưa có hàng đợi retry cleanup bền vững; xem cảnh báo cuối tài liệu.

SSE hiện có thêm `tripStateChanged` chỉ gồm eventKind/tripId/tripStatus (không GPS,
notificationId, popup, badge hay FCM). Queued GPS/heartbeat đọc lại server truth:
nếu terminal, gửi một invalidation rồi đóng stream. Nếu mất quyền thì đóng, không
gửi cả terminal hay GPS. Heartbeat vẫn 15 giây, không scheduler nghiệp vụ.

Flutter dùng context chi tiết/Map hiện có, một stream cho Trip đang xem. ACK/SSE
hoặc own sharing-state reconcile đánh dấu terminal, dừng publisher/native service
đúng Trip, xóa overlay thành viên, giữ history. Gặp 422 sẽ reconcile status; nếu
terminal thì dừng, không retry mãi. Một request cũ không mở lại Trip đã biết terminal.
Đóng A không xóa pin, Share hay dừng native service của C. GPS tick không đổi
Map session hoặc gọi lại Trip detail/Directions; route fingerprint không chứa status.

## Giao Diện

- Giữ giao diện GoMate và các confirmation sheet đang có.
- DRAFT/PLANNED Leader: Bắt đầu nằm hàng đầu, trên Tin nhắn.
- ACTIVE Leader: Kết thúc ở cùng vị trí hàng đầu; Hủy nằm trong menu ba chấm.
- Cả hai có xác nhận; disable trong khi chờ ACK. Lỗi không đổi status/ghim giả.
- Terminal: hiện Đã kết thúc/Đã hủy, xem thành viên/địa điểm read-only; ẩn Pin,
  Share, Start/Complete/Cancel, sửa tên/ngày và quản lý thành viên. Leader vẫn Xóa.
- Không tạo màn History riêng, form lý do hủy hoặc lựa chọn PERSONAL/GROUP.

## File Quan Trọng

- Backend: TripController, TripService, TripRepository; ConversationService;
  TripLocationService, TripLocationStreamHub.
- Flutter: trip_repository, trip_ui_models, trip_detail_screen, trip_screen;
  map_ui_session, map_screen, map_trip_pin_button;
  trip_location_sharing_service, trip_location_realtime_service,
  location_sharing_models; message_repository, group_management_screen.
- Tests: TripCompletionCancellationTest.java;
  test/trip_completion_cancellation_test.dart; trip_location_sharing_test.dart;
  backend/scripts/verify-trip-completion-cancellation.ps1.
- Knowledge: tài liệu này, CODEX_INDEX, PROJECT_CONTRACT, DATABASE_CONTRACT,
  TRIP_LOCATION_SHARING_PHASE4_5.md.

## Kết Quả Kiểm Thử

| Kiểm tra đã chạy | Kết quả |
|---|---|
| `docker compose build api` (Dockerfile chạy `mvn clean verify`) | PASS, 139 tests, 0 failure/error/skipped |
| TripCompletionCancellationTest | 13 test instances PASS, gồm permission, history, rollback và concurrency |
| Auth/Firebase/Google regression | GoogleFlowTest, FirebaseGoogleApiTest, FirebaseGoogleVerifierTest, FirebaseSdkVerificationTest PASS; không thay cấu hình Auth |
| Place/Route/DM/notifications/Moment regression | Toàn bộ suite hiện có PASS; không sửa các domain này ngoài guard GROUP chat terminal |
| Flutter full `flutter test --reporter expanded` | 144 tests PASS, gồm 10 test cases trong file lifecycle mới + 5 runtime cases mới |
| Flutter analyze | 0 errors; 16 warnings + 263 infos sẵn có (279 issues), không mass-fix ngoài scope |
| `flutter build apk --debug` | PASS, `build/app/outputs/flutter-apk/app-debug.apk` |
| DB sạch `gomate_phase46_clean` | Startup tự chạy V1-V15; HTTP + PostgreSQL + Mongo thật PASS |
| Bản sao DB cũ `gomate_phase46_upgrade` | Restore backup trước cutover; startup không cần migration; cùng bộ HTTP/PG/Mongo PASS |
| PostgreSQL races thật | Complete/Cancel đúng một terminal winner; Start/Cancel không revive, PASS trên cả hai DB |
| API chính sau cutover | Startup PASS, GET /api/v1/places HTTP 200, 146 Place |

Hai DB kiểm thử tách biệt chạy script:

```powershell
pwsh -NoProfile -File backend/scripts/verify-trip-completion-cancellation.ps1 -BaseUrl http://127.0.0.1:18086/api/v1 -Database gomate_phase46_clean -MongoDatabase gomate_phase46_clean
pwsh -NoProfile -File backend/scripts/verify-trip-completion-cancellation.ps1 -BaseUrl http://127.0.0.1:18087/api/v1 -Database gomate_phase46_upgrade -MongoDatabase gomate_phase46_upgrade
```

Script có guard chỉ nhận localhost:18086/18087 + tên DB test `gomate_phase46_*`.
Đã kiểm tra Complete/Cancel GROUP, PERSONAL, DRAFT cancel chưa có chat, PATCH cũ,
history list/detail, stale notification refetch, tất cả active mutation bị chặn,
retry cùng terminal, archive riêng, message Mongo được giữ, snapshot xóa đúng Trip,
Share/pin/GPS của Trip C tiếp tục, login email/password, Place và route invalid-ID.
FK/transaction/migration vẫn theo convention JDBC/Flyway hiện tại.
Sau test, helper containers dừng; test DB được giữ riêng để truy vết. Không dùng
test account hay đóng bất kỳ lịch trình nào trong DB người dùng.

Flyway DB chính: V1 BASELINE, V2-V15 SUCCESS; không có V16. DB sạch V1 là SQL.
25 bảng public không thay đổi. Startup DB chính báo up-to-date, không chạy migration.

### Dữ Liệu Chính Trước / Sau Cutover

| Chỉ số | Trước | Sau |
|---|---:|---:|
| users | 38 | 38 |
| trips | 16 | 16 |
| trip_members | 23 | 23 |
| trip_stops | 7 | 7 |
| trip_invitations | 25 | 25 |
| trip_pins | 1 | 1 |
| Share ON | 1 | 1 |
| notifications | 31 | 31 |
| conversations | 8 | 8 |
| places | 146 | 146 |
| place_media | 7 | 7 |
| Flyway history SUCCESS | 15 | 15 |

Mongo chính vẫn có 5 current snapshots, không đọc/ghi tọa độ vào báo cáo.
Không reset consent, ghim hoặc trạng thái Trip hiện tại khi deploy. Chỉ thao tác
Complete/Cancel được người có quyền xác nhận mới đóng quyền của Trip đó.

Log chạy thật (ignored, không commit): `backups/phase46_docker_build.log`,
`phase46_flutter_full_final.log`, `phase46_flutter_analyze_final.log`,
`phase46_apk_build_final.log`, `phase46_real_clean.log`, `phase46_real_upgrade.log`,
`phase46_pre_counts.json`, `phase46_post_counts.json`.

Đã deploy image mới bằng `docker compose up -d --no-deps api`; PostgreSQL/Mongo/AI
không bị reset/recreate. Không thay `.env`, credentials, dependency hoặc Compose
trong Phase 4.6. API vẫn ở cổng 8081 như cấu hình đang dùng.

## Kiểm Tra Thiết Bị

Trạng thái nghiệm thu vật lý: chưa thực hiện Phase 4.6; thiết bị ADB có kết nối
không đồng nghĩa đã pass các testcase người dùng bên dưới. Không tự cài APK, đổi
tài khoản hay đóng Trip của bạn để thử.

Chạy lại Flutter hoàn toàn sau khi nhận bản cập nhật. Không chỉ hot reload khi
kiểm tra lifecycle của service vị trí.

1. Tạo lịch trình thử, mời/nhận thành viên; Start; tự Share ON + ghim. Leader
   Kết thúc -> xác nhận -> Đã kết thúc; không Share/Pin/chat/edit nhưng còn lịch sử.
2. Tương tự với Hủy lịch trình đang ACTIVE và Hủy DRAFT có lời mời chưa nhận.
   Bấm push/lời mời cũ -> đã hủy, không Chấp nhận và không tạo membership.
3. B đang mở Map/chi tiết Trip A: Leader đóng A; B mất active controls/overlay và
   dừng gửi. B ở nền: lần native fix kế tiếp đọc lại status rồi dừng. Không cam kết
   Android gửi đúng thời điểm khi bị hệ điều hành hạn chế.
4. B ghim và Share Trip C, là thành viên Trip A. Leader đóng A: C giữ pin/Share,
   gửi nền tiếp; không đổi camera/route của C do closure A.
5. Qua ngày cuối/giờ dừng: Trip vẫn ACTIVE cho đến khi Leader chủ động kết thúc.
6. Xóa riêng một Trip terminal thử: bị ẩn, không xóa message/history vật lý.

Không dùng Trip/dữ liệu thật cần giữ làm fixture terminal vì không có mở lại.

## Backup / Rollback

- Backup trước cutover: `backups/phase46_pre_20261016.dump` (pg_dump custom,
  pg_restore -l đọc được), `backups/phase46_pre_api_20261016.jar` và counts JSON.
- Không migration mới, rollback triển khai không cần rollback Flyway.
- Không restore DB đè lên dữ liệu mới chỉ vì API lỗi; dừng thao tác, xem log rồi
  đổi về image/JAR trước khi cần. Lưu ý API cũ chưa có đầy đủ guard terminal nên
  không dùng nó để mở lại/sửa Trip đã đóng bởi bản mới.
- Khi thực sự cần phục hồi dữ liệu: restore dump vào DB TÁCH BIỆT trước, kiểm tra
  diff và xin phê duyệt trước khi thay DB hiện tại. Không down -v/reset volume,
  không Flyway repair, không sửa migration cũ.

## Giới Hạn

- Chưa tạo durable completion/cancellation notification/FCM theo yêu cầu.
- Mongo cleanup failure được log và snapshot bị khóa quyền; retry bền vững là
  phần vận hành sau này, không tạo import/job/queue/table trong phase này.
- Background runtime không nhận push điều khiển mới; backend chặn ngay, thiết bị
  dừng tại lần reconcile/native callback tiếp theo. Force-stop/process-kill không
  được bảo đảm như Phase 4.5.
- Chưa tự coi automated tests là nghiệm thu vật lý hai thiết bị. Chỉ đóng phase
  sau khi kiểm tra thực tế theo checklist và ghi kết quả.
