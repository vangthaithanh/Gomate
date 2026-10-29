# Hotfix Post Publish 422/404 — đồng bộ máy hiện tại và máy mới

Ngày 29/10/2026. Bản vá kế tiếp baseline `d94ebf6d5bab89ab43d08c646e58f705ab0cb1a6`; không cần xuất hoặc restore lại dữ liệu.

## Lỗi và cách sửa

`PostPublishApiTest.spoofOwnershipInvalidForeignKeysAndSixTagsAreControlled` đã được tái hiện trước sửa: UUID người được gắn thẻ không tồn tại → khóa `user_settings` → `Db.one()` ném 404 trước validation 422. Dockerfile chạy full Maven verify nên image mới không build được, dù app/image cũ vẫn chạy và smoke 26 test trước đây không có test này.

PostService chỉ dịch lỗi 404 **ngay tại bước khóa** sang `422 INVALID_TAGGED_USER` khi tác giả còn hợp lệ và có người được gắn thẻ không hợp lệ. Không đổi helper Db/GlobalBlockPolicy dùng chung, không bỏ khóa hoặc thay thứ tự khóa UUID. Nếu tác giả không còn hợp lệ thì giữ 404. Global Block kiểm tra sau khóa vẫn trả 404, không tiết lộ chiều chặn; validation ACTIVE sau khóa vẫn giữ nguyên.

Không đưa mọi validation lên trước replay: một bài đã commit có thể retry đúng key/payload sau khi user được gắn thẻ bị LOCKED. Giữ ACK cũ, không tạo duplicate. Request mới vẫn bị chặn 422; cùng key khác payload vẫn 409. Khi request lỗi, media vẫn READY, không có Post hoặc tag ghi dở.

Không sửa UI, Auth, audience/media privacy, Follow/DM/Trip/AI, schema, migration V1–V26, config hoặc dependency. Không đổi expected 422 thành 404 và không bỏ qua test.

## Kiểm chứng

Trước sửa: 1 test FAIL (422 expected, 404 actual) trên Java 17 / Maven 3.9.9 / H2 in-memory, không dùng database từ backup. Log Mongo ensure-index trong test offline được catch/WARN; không phải nguyên nhân assertion này. Chưa khẳng định mọi Mongo lỗi trên máy khác đều vô hại.

Sau sửa, đã chạy thật:

- Windows Java 17 / Maven 3.9.9: **15 PostPublishApiTest PASS**. Nhóm scoped còn có **8 GlobalBlockApiTest + 9 PostFeedApiTest PASS**. Không gọi đây là full Windows suite.
- Docker build stage chạy **`mvn --batch-mode clean verify -Dtest=*` thành công**. Báo cáo XML của đúng stage: **275 tests, 0 failures, 0 errors, 3 skipped** (272 thực thi PASS). BuildKit cắt log sau 2 MiB nên số liệu lấy từ XML, không cộng từ phần log thiếu.
- Ba skip opt-in: `DirectMessageMongoTest`, `PostShareMongoTest` cần `GOMATE_P4_REAL_MONGO=true`; `GlobalBlockPostgresMigrationTest` cần `GOMATE_GLOBAL_BLOCK_PG_PROBE=true` và database probe riêng. Không nhận là đã chạy ba integration probe này hay test trên database người dùng.
- **Docker image build PASS (exit 0)**, giữ full test gate `TESTS=*`. Smoke trong đúng image vừa build: **Java / FFmpeg / FFprobe PASS**, network tắt. Lần build sạch có thể lâu vì tải Maven/99 gói thư viện FFmpeg; không nhầm thời gian download với lỗi assertion 422/404.
- Đã cập nhật API local bằng image vừa kiểm thử: **health UP**, container dùng đúng image mới; đọc Flyway thực tế vẫn **V1–V26 success**, không có migration mới. Không tạo user/Post/test data trong database thật.

Test ban đầu đã tái hiện FAIL; lần đầu thêm test mới có assertion đọc sai vị trí field `code` (API hiện tại trả flat), đã chỉnh test theo response đang chạy và chạy lại PASS. Không thay đổi error envelope của backend.

Test bổ sung bảo vệ: UUID không có → 422/code đúng; không ghi dở/không tiêu thụ request key/media; sửa lại target và retry thành công một lần; tác giả không có vẫn 404; user LOCKED → 422; chặn hai chiều và blocked+LOCKED vẫn 404; replay bài cũ sau target LOCKED và conflict key giữ nguyên. Các test concurrent publish, audience, protected media/Range, Global Block và Feed hiện có tiếp tục phải PASS.

## A. Máy đồng đội đã clone/restore

1. Vào đúng thư mục repository đang chạy Compose, không phải bản source khác hoặc chỉ thư mục KPDL. Kiểm tra:

```powershell
git rev-parse --show-toplevel
git branch --show-current
git log -1 --oneline
git status --short
git diff -- backend/src/main/java/vn/gomate/social/post/PostService.java
```

2. Nếu đã sửa tay PostService, lưu một bản/diff riêng và đối chiếu trước khi cập nhật. Không reset hard, xóa thay đổi AI hoặc ép giải quyết conflict bằng cách chép đè. Dùng bản hotfix chính thức thay cho vòng pre-validation tự thêm; không chồng hai cách sửa.

3. Với checkout sạch trên `master` có cùng lịch sử baseline đã bàn giao:

```powershell
git pull --ff-only origin master
if ($LASTEXITCODE -ne 0) { throw 'Chưa cập nhật được source. Dừng, giữ thay đổi local và kiểm tra Git.' }
git log -1 --oneline
```

Nếu pull báo local changes/divergent/unrelated history thì **dừng**. Giữ bản AI/local hiện tại, đối chiếu với chủ dự án hoặc clone master mới ở thư mục khác rồi chuyển đúng phần việc riêng đã review. Không merge lại history cũ chứa secret, không force-push, không dùng allow-unrelated-histories.

Nếu đã có commit AI riêng trên một nhánh phát triển: không ép nhánh đó về master. Sau khi lưu/commit phần việc riêng và xác nhận checkout sạch, có thể nhận riêng hotfix bằng cherry-pick **chỉ khi** nhánh AI kế thừa baseline sạch d94ebf6:

```powershell
git merge-base --is-ancestor d94ebf6d5bab89ab43d08c646e58f705ab0cb1a6 HEAD
if ($LASTEXITCODE -ne 0) { throw 'Nhánh này không cùng baseline sạch. Dừng và đối chiếu với chủ dự án.' }
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Chưa fetch được commit hotfix.' }
git cherry-pick HOTFIX_SHA
if ($LASTEXITCODE -ne 0) { throw 'Dừng tại conflict; giữ thay đổi AI, review PostService/test theo note, không chép đè cả nhánh.' }
```

Thay HOTFIX_SHA bằng full SHA chủ dự án gửi cùng kết quả publish; không nhập nguyên placeholder. Nếu conflict thì chỉ resolve sau review, hoặc `git cherry-pick --abort` để về trạng thái trước lần tích hợp; không reset dữ liệu/source. Sau tích hợp vẫn phải chạy full build bên dưới. Với history cũ không kế thừa d94ebf6, dùng checkout sạch ở thư mục khác và review chuyển phần AI riêng.

4. Build API với toàn bộ test, không dùng TESTS rút gọn hoặc skip:

```powershell
docker compose build --build-arg 'TESTS=*' api
if ($LASTEXITCODE -ne 0) { throw 'Build/test chưa PASS. Không khởi động image cũ để coi là đã sửa.' }
```

Chỉ khi build exit 0 mới chạy bước tiếp. Nếu lỗi tiếp thì gửi tên test/status và SHA source, không restore lại backup để thử chữa test H2.

```powershell
docker compose up -d --no-deps api
if ($LASTEXITCODE -ne 0) { throw 'API chưa lên. Kiểm tra database và log, không reset volume.' }
docker compose ps
Invoke-RestMethod 'http://127.0.0.1:8081/api/v1/health'
```

Lệnh `--no-deps` dành cho máy đã có PostgreSQL/MongoDB chạy và đã restore thành công. Nếu database chỉ đang tắt thì `docker compose start postgres mongo` và đợi healthy trước khi mở API; không tạo/reset volume. API health phải UP. AI image không đổi, không cần build lại chỉ vì hotfix này.

**Giữ nguyên hai backup, database đã restore, `.env`, Firebase configs và `lib/main.dart` riêng.** Không `down -v`, restore chồng, Flyway repair, đổi migration hoặc credential. Không cần cài lại APK vì Flutter/API request contract không đổi. Thử đăng bài gắn user hợp lệ; user không còn khả dụng phải là lỗi có kiểm soát, không làm mất draft.

## B. Máy mới clone sau hotfix

Clone `master` mới nhất; nhận các file riêng như trước. `lib/main.dart` vẫn không nằm trong Git và bắt buộc có để chạy Flutter. Hai backup đã kiểm chứng vẫn dùng được; restore vào database dev rỗng theo README đi cùng backup **trước lần khởi động API đầu tiên**.

Sau restore, `docker compose up -d --build` phải build full test mặc định thành công; schema vẫn V26. Không tạo seed/migration mới để chữa lỗi build. Nếu dùng thư mục khác hoặc branch AI, kiểm tra root/SHA trước khi build.

## C. Cơ chế phòng tái phát và giới hạn

Test hồi quy được commit cùng bản vá; Dockerfile vẫn giữ default full test gate `clean verify -Dtest=*`. Smoke có scope không thay full build trước bàn giao máy mới. Ghi rõ test skip theo điều kiện môi trường; không gọi full integration PASS nếu test Mongo/PostgreSQL thật chưa được bật.

Đây là sửa một regression đã tái hiện, không phải bảo đảm mọi lỗi môi trường/Google SHA/cổng mạng hoặc mọi feature của các bản AI tùy biến đều đã kiểm thử. Dữ liệu nguồn không được dùng để chạy test hoặc sửa trong hotfix này.
