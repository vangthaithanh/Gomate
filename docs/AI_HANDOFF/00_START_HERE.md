# GoMate — baseline local và bàn giao AI

**Bổ sung local V27 (30/10/2026):** [Place Rating/Review](08_PLACE_RATING_REVIEW_V27.md) có gói patch bàn giao riêng trên baseline 84ac037, chưa push master. Giữ khác biệt điểm thật 0/0 khi chưa có review và mặc định UI 5 sao; không dùng mặc định UI làm nhãn AI. Không cần restore lại DB V26 để nâng cấp V27.

Sau baseline d94ebf6, đọc [Post Publish hotfix / đồng bộ máy](../POST_PUBLISH_TAG_VALIDATION_HOTFIX.md) khi gặp Docker build FAIL 422/404. Không cần gửi lại hoặc restore lại backup.

> **PRIVATE FILE REQUIRED:** `lib/main.dart` được chủ dự án quyết định loại khỏi Git và bàn giao riêng qua kênh được duyệt. Bản clone **không compile/chạy Flutter được nếu chưa có file này tại đúng `lib/main.dart`**. Không có file thay thế giả và không đổi runtime sang `--dart-define`. Xem [release report](07_GIT_RELEASE_REPORT.md) để biết trạng thái chuẩn bị phát hành; SHA sau push được xác nhận riêng, không coi báo cáo trước push là bằng chứng đã phát hành.

Chủ dự án duyệt source local hiện tại làm chuẩn ngày 29/10/2026, không lấy lại code remote cũ. Nhánh bàn giao: **master**. Sau clone dùng `git rev-parse HEAD` để lấy SHA chính xác; không ghi SHA tự tham chiếu vào chính commit này.

```powershell
git clone --branch master https://github.com/vangthaithanh/Gomate.git
cd Gomate
git rev-parse HEAD
```

Snapshot phát hành không kế thừa history chứa credential. History/safety ref cũ giữ local; không merge lại history cũ khi chưa review. Xem [release report](07_GIT_RELEASE_REPORT.md).

Sau khi nhận file riêng, kiểm tra `git check-ignore lib/main.dart`, `git status --short` và `git ls-files lib/main.dart` (lệnh cuối phải không trả file). Không commit/forward file vào Git, issues, CI logs hay chat. File hiện chứa Mapbox token: bàn giao riêng chỉ giảm lộ qua Git, không tự bảo mật token. Khuyến nghị token AI/dev riêng với quyền tối thiểu; owner xem xét rotation/restrictions riêng, không đổi token trong release này.

Env/Firebase/signing keys và credential khác cũng gửi riêng theo nhu cầu; ưu tiên staging với quyền giới hạn, không clone dữ liệu người dùng thật. AI phải giữ audience/private follow/mutual/Global Block/DM pending-accepted, media được Spring bảo vệ, Trip/Pin/GPS/LAST_KNOWN, D-2/D-1 20:00, giờ Stop, Place AI, Notifications, UI và pagination/cache. Backend authorize candidate và media tại thời điểm truy cập; Home giữ fallback mới nhất trước. Dữ liệu mẫu cần duyệt nguồn/license/manifest, chỉ dev/staging được duyệt, idempotent và rollback giới hạn; không production seed, giả engagement hay mạo danh.

Thứ tự đọc:
1. [Kiến trúc và runbook](01_CURRENT_ARCHITECTURE_AND_RUNBOOK.md).
2. [Nghiệp vụ/quyền](02_CANONICAL_BUSINESS_AND_PERMISSIONS.md).
3. [Place AI hiện có / Post AI đề xuất](03_POST_AI_RECOMMENDATION_CONTRACT.md).
4. [Kế hoạch dữ liệu — chưa seed](04_SEED_DATA_POLICY_AND_PLAN.md).
5. [Ranh giới thay đổi/test gate](05_AI_CHANGE_BOUNDARIES_AND_TEST_GATE.md).
6. [Bằng chứng và docs cũ](06_EVIDENCE_LIMITATIONS_AND_DOC_INDEX.md).

Owner duyệt nghiệp vụ, data/consent và thay đổi lớn. Spring giữ authorization/transactions; AI chỉ đề xuất features/ranking và kiểm thử offline. Không tự sửa UI/schema/Auth/media hoặc tạo dữ liệu thật. **Bàn giao này không triển khai Post AI và không chạy seed.** Trước sửa code đọc [AGENTS](../../AGENTS.md), [CODEX_INDEX](../CODEX_INDEX.md).
