# GoMate — hướng dẫn nhận gói Place Rating/Review V27

Gói bàn giao local ngày **30/10/2026**, base source **84ac0372c4618a04088be441473bac355145b546**. Chưa có commit V27 được push lên master: **chỉ pull sẽ chưa nhận được feature này**. Gói bổ sung đúng phần đánh giá và khung xác nhận xóa đã đồng bộ GoMate; không thay model AI hay nghiệp vụ khác.

## Gửi gì cho đồng đội?

Gửi ZIP `GoMate_Place_Review_V27_20261030.zip`, file SHA-256 đi cùng và README này. ZIP gồm:

- `place_review_v27.patch`: bản vá đầy đủ các file thay đổi so với base trên, gồm migration/test/docs.
- `source/`: bản sao các file trong delta để đối chiếu khi conflict, **không phải project độc lập và không chép đè cả thư mục lên code AI đang sửa**.
- `data/place_rating_snapshot.csv`: 146 Place ACTIVE đã import, mapping canonical + số sao/lượt thật tại lúc xuất. Không phải seed script.
- `data/place_catalog_v11.csv` và `data/ai_place_catalog_v11.csv`: cùng 188 canonical external_id; chỉ 146 Place đã import. Không tự import 42 Place unresolved.
- `data/flyway_history.json`: version/checksum V1–V27; `MANIFEST.json`: base, hash file, phạm vi và bằng chứng kiểm tra.
- `source/docs/AI_HANDOFF/08_PLACE_RATING_REVIEW_V27.md`: contract AI, tín hiệu thật, quyền và giới hạn.

**Không chứa** `.env`, `lib/main.dart`, Firebase/service account, signing key, DB dump, tài khoản/session, review content/author, tin nhắn/GPS hay binary media/APK. Cấu hình riêng đã nhận trước đó tiếp tục dùng. APK cập nhật cho chủ dự án được gửi riêng; người làm AI có thể build Flutter từ source sau khi đã có `lib/main.dart` riêng.

## 1. Nhận code an toàn

Giải nén gói ở ngoài repository. Mở PowerShell tại **đúng ROOT GoMate có docker-compose.yml** và xem trạng thái trước:

```powershell
git rev-parse --show-toplevel
git log -1 --oneline
git status --short
```

Base được tạo trên snapshot sạch 84ac037 (đã sửa lỗi Post Publish 422/404). Nếu chưa có base này, đồng bộ commit đó theo runbook hotfix trước. Nếu nhánh AI có thay đổi riêng, lưu/commit công việc của mình và review các file bị tác động; không reset hard, force-push hoặc merge history cũ chứa credential. Không cần ép về base nếu đã có commit mới hơn và patch vẫn áp dụng đúng.

Thay đường dẫn ví dụ dưới bằng nơi giải nén thật; không chạy trong thư mục ZIP:

```powershell
$gomateHandoff = 'C:\Path\GoMate_Place_Review_V27_20261030'
git apply --check "$gomateHandoff\place_review_v27.patch"
if ($LASTEXITCODE -ne 0) { throw 'Dừng: review conflict/local changes trước. Không chép đè source của đồng đội.' }
git apply "$gomateHandoff\place_review_v27.patch"
if ($LASTEXITCODE -ne 0) { throw 'Chưa áp dụng thành công. Dừng và kiểm tra git diff.' }
git diff --stat
git status --short
```

`git apply --check` không sửa code. Khi conflict, dùng `source/` và patch để tích hợp từng hunk với người phụ trách; không dùng script chép đè tự động hoặc bỏ test để vượt lỗi. Source patch không đổi branch, tạo commit hay tự push.

## 2. Nâng cấp backend/DB đang có dữ liệu

**Máy đã restore V26: KHÔNG restore lại hai backup.** V27 tạo `reviews`; cột aggregate Place đã có từ V2. Không sửa V1–V26, repair, clean, drop, truncate hoặc reset Docker volume.

Sau khi code đã nhận đầy đủ, mở Docker Desktop, bảo đảm PostgreSQL/Mongo hiện có đang healthy và build toàn bộ test:

```powershell
docker compose start postgres mongo
if ($LASTEXITCODE -ne 0) { throw 'Chưa mở được hạ tầng hiện có. Kiểm tra Compose/config trước.' }
docker compose ps
docker compose build --build-arg 'TESTS=*' api
if ($LASTEXITCODE -ne 0) { throw 'Build/test chưa PASS. Không tiếp tục bằng image cũ hoặc skip test.' }
docker compose up -d --no-deps api
if ($LASTEXITCODE -ne 0) { throw 'API chưa lên. Kiểm tra log; không reset database.' }
```

Đợi API khởi động rồi kiểm tra:

```powershell
Invoke-RestMethod 'http://127.0.0.1:8081/api/v1/health'
docker compose exec -T postgres psql -U gomate -d gomate_auth -c 'SELECT version,success FROM flyway_schema_history ORDER BY installed_rank;'
docker compose exec -T postgres psql -U gomate -d gomate_auth -c 'SELECT COUNT(*) FROM places; SELECT COUNT(*) FROM reviews WHERE publication_status=''ACTIVE'';'
```

Kỳ vọng trên bản dữ liệu đã bàn giao: health UP, V1–V27 thành công, 146 Place vẫn còn, 39 bảng nghiệp vụ (40 kể cả Flyway). Review ACTIVE có thể là 0 — **bình thường**, không phải thiếu seed. Nếu đồng đội tự thêm dữ liệu hợp lệ thì count theo dữ liệu của họ, không ép về snapshot. Những WARN Mongo trong test build phải được xem cùng kết quả Maven cuối; không sửa backup để chữa test H2.

Máy hoàn toàn mới: theo hướng dẫn restore cũ vào DB dev rỗng trước khi mở API lần đầu, rồi dùng source đã áp dụng patch để Flyway tự nâng V27. Gói này không thay thế PostgreSQL/Mongo backup gốc, Cloudinary hay cấu hình riêng. AI service/model không đổi nên không cần build lại AI chỉ vì rating.

## 3. Chạy Flutter và kiểm tra

Sau khi có file private `lib/main.dart` và Firebase/SHA phù hợp như trước:

```powershell
flutter pub get
flutter test
flutter analyze
flutter run
```

Không hard-code endpoint mới, không đổi private main hay Google config để xử lý migration. Với Android USB, tiếp tục dùng reverse 8081→8081 như runbook mạng hiện hành. Không đưa private main/token lên Git.

## 4. Quy tắc dữ liệu AI bắt buộc nhớ

- `external_id` là training/catalog key; `places.id` là business key của DB cụ thể.
- `avg_rating` + `review_count` chỉ phản ánh GoMate review ACTIVE/VISIBLE. Không gộp rating ngoài, AI score hay số sao UI vào đây.
- **Chưa có review: DB/API/export=0/0; UI=5 sao + “Chưa có đánh giá”.** 5 mặc định không là nhãn huấn luyện.
- Snapshot lúc đóng gói có **0 review ACTIVE**. Hai review do Thanh/Xuân Thu test đã xóa mềm; không xuất actor/content và không đưa lịch sử test vào dataset.
- Đây là nền tảng để phase AI sau dùng đúng số liệu, chưa phải task train/retrain, tạo review giả hay triển khai Post AI. Không import CSV snapshot đè DB hoặc tạo điểm giả để đủ dữ liệu.

## 5. Kết quả và giới hạn bàn giao

- Backend Docker: 283 test, 279 thực chạy PASS, 4 opt-in skip; migration PostgreSQL sạch và nâng V26 đã chạy riêng PASS.
- Flutter full: 327 PASS. Sau chỉnh khung xóa: 4 test review PASS và APK rebuild PASS; backend/schema không thay đổi.
- Native Thanh/Xuân Thu: create/re-entry/account separation/edit/soft-delete/last-delete đều đã xác nhận đúng. Sửa giữ review id/count; xóa hết trả đúng 0/0 trong DB và 5 mặc định trên UI.
- Chủ dự án yêu cầu đóng gói sau chỉnh khung xóa. **Chưa xác nhận máy thật**: mất mạng, đồng bộ sao/ảnh giữa Map–Search–Home, review-list Block và hai điện thoại đồng thời; khung xóa mới chưa được xác nhận lại trên máy thật. Không đổi các mục này thành native PASS.
- Không có thay đổi backend mới trong lần chỉnh giao diện này, không migration V28, không push master. Xem MANIFEST và report trong source để biết hash APK/check hiện hành.
