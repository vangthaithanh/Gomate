# Handoff `buitrong` — GoMate AI, Place Review V27 và Home Recommended Feed

Ngày chuẩn bị: 2026-10-30 (Asia/Bangkok)

Tài liệu này mô tả phần đã được đối chiếu trong source tree hiện tại và sẽ được commit/push lên `origin/buitrong`. PASS chỉ dùng cho bằng chứng từ code, tài liệu hoặc lệnh kiểm tra được ghi rõ; báo cáo kiểm thử cũ không được tính là lần chạy mới của phiên này.

## 1. Phạm vi bàn giao

- AI recommendation v15: FastAPI nhận sở thích/context và `history_external_ids`, dùng bundle hybrid Association Rules + SVD Tour × Place + semantic content score. Backend gọi AI, chuyển lịch sử Place lấy từ Trip membership, áp dụng contextual rerank/fallback và không để AI ghi business state.
- Place Rating/Review V27: Flyway migration, CRUD review của chính user, soft-delete, aggregate `avg_rating`/`review_count`, lọc tác giả theo Global Block, đồng bộ hiển thị Place có/không có review.
- Post Recommended Home Feed: snapshot + cursor, thứ tự mutual active follow → đang theo dõi → các bài còn lại; lọc quyền xem hiện tại, block và audience; điểm Place/hashtag/interaction chỉ xếp nhóm thứ ba.
- Home view history V28: ghi nhận xem idempotent; bài đã xem của nhóm quan hệ chỉ bị ẩn ở snapshot mới, không đổi cursor đang mở và không ẩn bài Profile. Flutter có marker theo tỷ lệ hiển thị/thời gian, nhưng native Flutter chưa chạy được trong phiên này.
- Flutter: Home/Place/Search/Map dùng aggregate rating ACK cục bộ; Home/Post feed có refresh, cursor pagination và view marker theo code.

Không kết luận nghiệm thu native end-to-end chỉ vì test hoặc APK cũ được ghi trong tài liệu trước đó.

## 2. File chính trong branch

AI/recommendation: `KPDL/api_service.py`, `KPDL/history_hybrid.py`, `KPDL/test_history_hybrid.py`, `KPDL/train_ml_research_v15_strict.py`, `KPDL/requirements.txt`, `KPDL/Dockerfile`, `KPDL/.dockerignore`, `KPDL/ml_training_dataset_v12_semantic_v1.csv`, `KPDL/ml_training_dataset_v12_semantic_v1_manifest.json`, `KPDL/semantic_v1/`, `backend/src/main/java/vn/gomate/recommendation/`, `lib/features/recommendation/`.

Place Review: `backend/src/main/java/db/migration/V27__place_reviews.java`, `backend/src/main/java/vn/gomate/place/review/`, `lib/features/place/data/place_review_repository.dart`, `lib/features/place/widgets/place_rating_builder.dart`, Map/Search files liên quan, `test/place_reviews_test.dart`.

Recommended Feed/View: `backend/src/main/resources/db/migration/V28__post_home_views.sql`, năm file `backend/src/main/java/vn/gomate/social/post/PostRecommendation*.java`, `lib/features/posts/data/post_repository.dart`, `lib/features/posts/data/post_feed_controller.dart`, `lib/features/posts/widgets/home_post_view_marker.dart`, các test Post Recommendation và view marker.

Model runtime không tự học online. `history_external_ids` chỉ tạo tín hiệu runtime từ artifact/basket/embedding freeze; code không cập nhật model. SVD là Tour × Place, không phải User × Place. Trip history hiện chỉ chứng minh membership/stop history, không chứng minh click/save cá nhân.

Quy tắc Place: `reviewCount == 0` là “Chưa có đánh giá”, không dùng `avgRating` legacy để hiển thị 5.0/0.0 hay tô năm sao. Khi count > 0, UI hiển thị aggregate thật; edit/delete dùng cùng review id và delete là soft-delete.

Endpoint Feed: `GET /api/v1/feed/recommended?size=20&cursor=...&destinationKey=...&latitude=...&longitude=...`; ghi view: `PUT /api/v1/feed/recommended/{postId}/view` trả `204`, idempotent theo `(viewer_user_id, post_id)`.

## 3. Luồng hoạt động

Place flow: Flutter `RecommendationRepository` → `GET /api/v1/recommendations/home` → Spring `RecommendationService` → PostgreSQL candidate + semantic interest/context + Trip Place history → AI FastAPI `POST /recommend` → Spring hybrid/context score → PostgreSQL fallback khi AI lỗi/timeout/thiếu profile → Flutter Place cards/rating aggregate.

AI bundle hiện ghi model `gomate-ranker-research-v15-screen12-strict`, strategy `hybrid_recommendation_score_screen12`, công thức cuối `0.75 * AIHybridScore + 0.25 * BackendContextScore`. Screen 3 (distance, route/time, review/context runtime) do Backend sở hữu.

Feed lấy bài visible tại snapshot. Bucket `0` là mutual active follow, `1` là viewer đang follow tác giả, `2` là phần còn lại. Bucket 0/1 sắp xếp mới nhất; bucket 2 dùng Place score (nếu có), hashtag popularity và interaction/recency. AI/Place không sẵn sàng thì feed vẫn trả bài với fallback. Cursor giữ snapshot; quyền xem/delete/block được kiểm tra lại từng trang; refresh tạo snapshot mới. `post_home_views` không được dùng để ẩn bài Profile.

## 4. API, cấu hình, migration

- Compose: Spring host `8081` → container `8080`; AI host/container `8000`.
- AI endpoints: `/health`, `/recommend`; Compose đặt `AI_SERVICE_BASE_URL=http://ai:8000`.
- Config không chứa secret: `AI_RECOMMENDATION_CANDIDATE_K`, `AI_RECOMMENDATION_HOME_LIMIT`, `AI_RECOMMENDATION_HISTORY_LIMIT`, `AI_RECOMMENDATION_TIMEOUT_MS`, `RECOMMENDATION_SEMANTIC_WEIGHT`, `RECOMMENDATION_CONTEXT_WEIGHT`, `RECOMMENDATION_DISTANCE_SCALE_KM`.
- `GOMATE_MODEL_PATH` có thể đổi artifact; mặc định là `KPDL/training_output_research_v15_grid001/gomate_ranker_research_v15_strict.joblib`.
- V27 tạo `reviews`; V28 tạo `post_home_views`; Flyway tự apply khi Spring khởi động. Không reset volume, `down -v`, sửa hoặc renumber migration cũ.

## 5. Artifact cần nhận riêng

Branch có source, dataset v12, manifest và toàn bộ `semantic_v1/`. Sau khi merge lịch sử remote, branch cũng có artifact research v13 cũ của commit `0eb6e1a`, nhưng source AI hiện tại mặc định cần v15. Vì v15 chưa có trong Git, gói gửi riêng chứa:

`KPDL/training_output_research_v15_grid001/gomate_ranker_research_v15_strict.joblib`

Gói ngoài Git: `C:\Users\Admin\Desktop\DoanLTDD\Gomate\handoff_buitrong.zip`. Dung lượng ZIP: **29,674 bytes (0.0283 MiB)**. SHA-256 ZIP: `a20656bfb9bf255a15f0cd4748da04f8c5932851eb018520783d7af13fad96ff`. Giải nén tại project root để giữ đường dẫn tương đối. Không đưa `.env`, token, password, private key, Firebase service account, database dump, APK, private `lib/main.dart` hoặc dữ liệu người dùng thật vào gói.

Các file trong ZIP: `README.md` (2,496 bytes, SHA-256 `cdf4ab471e58272072b063ed7eca6eea852e0283a2ba221310d85c30b9cac0f2`), `SHA256SUMS.txt` (danh sách kiểm tra; không tự hash chính nó), và `KPDL/training_output_research_v15_grid001/gomate_ranker_research_v15_strict.joblib` (27,625 bytes, SHA-256 `b17c335c6c85ce4f1cacd8af5d072917310f7667d7a2d71eb284315026b88f31`). README hướng dẫn giải nén, verify và chạy thử.

Các output `training_output_leaf_*`, `training_output_trees_*`, các `training_output_research_v15_*` khác và trainer backup là experiment/backup, không phải runtime dependency. Dùng source trainer + dataset trên branch để tái tạo khi cần.

`lib/main.dart` bị loại khỏi Git theo quyết định release; bản local hiện có 724 bytes và kiểm tra không in nội dung phát hiện literal dạng secret/token. Không phát hiện mẫu private key, JWT hoặc Google API key trong kiểm tra này, nhưng file vẫn là private release entrypoint có thông tin nhạy cảm theo chính sách dự án. Git-only clone chưa build/run Flutter được cho tới khi nhận file riêng an toàn. File này không thuộc ZIP model và không được gửi qua Git/Zalo công khai; dùng kênh bảo mật do chủ dự án kiểm soát.

## 6. Hướng dẫn đồng đội

Chạy `git fetch origin`, `git switch buitrong`, `git pull --ff-only origin buitrong`, rồi mở `docs/HANDOFF_BUITRONG.md`.

Giải nén `handoff_buitrong.zip` vào project root, không tạo thêm lớp `Gomate\handoff_buitrong\...`. Kiểm tra bằng PowerShell: `$model = '.\KPDL\training_output_research_v15_grid001\gomate_ranker_research_v15_strict.joblib'`; `Get-FileHash $model -Algorithm SHA256`; `Get-Item $model | Select-Object FullName,Length`. Đối chiếu với README/`SHA256SUMS.txt` trong ZIP.

Tạo `.env` local từ `.env.example` bằng secret của máy nhận. Chạy `docker compose up -d postgres mongo`, `docker compose build ai api`, `docker compose up -d`, rồi `Invoke-RestMethod http://localhost:8000/health`. Nếu thiếu artifact v15, AI service không load đúng hoặc recommendation trả `503`; Backend Place vẫn có fallback PostgreSQL nhưng thiếu tín hiệu v15.

Kiểm thử khi máy nhận có môi trường: `docker build --target build --build-arg TESTS="ContextualRecommendationRerankerTest,PostRecommendationScorerTest,PlaceReviewApiTest,PlaceReviewPostgresMigrationTest,PostRecommendationFeedApiTest" -t gomate-backend-test .\backend`; `flutter test test\place_reviews_test.dart test\home_post_view_marker_test.dart test\post_feed_test.dart test\post_publish_test.dart`. Nhận private `lib/main.dart` trước Flutter.

## 7. Kiểm tra phiên chuẩn bị

- PASS: `git fetch origin --prune`; kiểm tra lịch sử remote và quan hệ branch.
- PASS: kiểm tra source/diff/untracked, `.gitignore`, Dockerfile, Compose và đường dẫn artifact.
- PASS: `git diff --check` sau khi sửa whitespace trong trainer thay đổi; cảnh báo line-ending không phải lỗi diff.
- CHƯA CHẠY: Maven host test — `mvn` không có trong PATH và repo không có Maven wrapper.
- CHƯA CHẠY: Flutter targeted tests — `flutter test` không xuất output và bị dừng an toàn sau khi treo.
- CHƯA CHẠY: Python hybrid test — Python mặc định là 2.7, không có pytest; Python 3 launcher bị Windows từ chối tạo process.
- Docker build/test sẽ được ghi bổ sung trong báo cáo cuối nếu chạy được sau merge.

Test Java/Flutter mới vẫn được đưa lên branch. PASS cũ trong `docs/PLACE_RATING_REVIEW_FOUNDATION.md` và AI handoff là bằng chứng lịch sử/owner acceptance, không phải lệnh chạy lại phiên này.

## 8. Local không đưa vào commit/ZIP

- `.vscode/settings.json`: IDE cá nhân.
- `android/build/`: build/report generated.
- `KPDL/train_ml_model_v12_semantic_v1_backup.py`, `KPDL/train_ml_research_v13_backup.py` và output research thay thế: backup/experiment.
- Bản sao artifact/output v13/v15 khác artifact ở mục 5: không có bằng chứng code cần để khởi động API hiện tại.
- Generated registrant Linux/macOS/Windows đang hiện trong `git status`: không xác định được diff chức năng, không stage để tránh generated noise.

Không xóa hoặc restore các file trên. Nếu cần một output nghiên cứu cụ thể, gửi riêng sau khi xác nhận mục đích và quyền chia sẻ.

## 9. Giới hạn

- Review media, moderation/Admin và AI training từ review thật chưa thuộc V27 foundation.
- Native Flutter, offline/error variants và cross-screen acceptance chưa chạy lại trong phiên này.
- AI metrics là offline/proxy trên dataset v12; không mô tả thành bằng chứng User × Place hoặc online learning.
- Giữ `external_id` làm khóa nối AI catalog với Place; không tạo business state từ AI.
