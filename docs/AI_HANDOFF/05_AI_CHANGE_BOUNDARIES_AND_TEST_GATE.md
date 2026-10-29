# Ranh giới AI và test gate

**Handoff không cấp phép triển khai Post AI hoặc seed.** Whitelist để đề xuất review, không phải quyền tự deploy:
- Post ranker/feature pipeline mới trong vùng AI tách Place, chỉ features/manifest được duyệt;
- Spring adapter/orchestrator cạnh [social/post](../../backend/src/main/java/vn/gomate/social/post), reuse Post authorization;
- offline evaluation, fixture synthetic riêng, timeout/fallback/metrics và contract tests được duyệt.

Blacklist: Flutter UI/navigation/forms/cards/player và [Home retention](../../lib/features/posts/data/home_post_media_store.dart); Auth/Google/JWT/session/privacy; [PostService](../../backend/src/main/java/vn/gomate/social/post/PostService.java), protected Post/comment media/Cloudinary auth; Global Block; Follow/DM/Share/notifications; Trip/Pin/GPS/reminder/stop; Place AI; V1–V26 migrations. Không thêm state package/bảng/migration vì handoff. Nếu proposal buộc chạm vùng này, dừng, ghi diff/business impact và hỏi owner trước code. Không dùng AI/seed tự tạo tương tác thật hoặc đổi audience/Block.

Trước integration cần feature/data/consent/architecture approval, offline chống leakage, API/version/cursor/fallback agreed, whitelist diff review. Spring lọc quyền trước và sau ranking; AI không phát nội dung/URL trực tiếp tới client. Cache theo account/session/quyền; cursor/deeplink không là giấy phép đọc.

Test cần giữ/mở rộng, không claim đã chạy chỉ vì liệt kê:
- [Privacy](../../backend/src/test/java/vn/gomate/AccountPrivacyApiTest.java): PUBLIC/PRIVATE/PENDING/accept.
- [Global Block](../../backend/src/test/java/vn/gomate/GlobalBlockApiTest.java): hai chiều, independent Unblock, DM, media/Range/history.
- [Feed](../../backend/src/test/java/vn/gomate/PostFeedApiTest.java): eligibility, newest fallback, cursor/query count/revoked reads.
- [Share/Search](../../backend/src/test/java/vn/gomate/PostSearchShareApiTest.java), [Activity](../../backend/src/test/java/vn/gomate/PostActivityApiTest.java), [notifications](../../backend/src/test/java/vn/gomate/PostInteractionNotificationTest.java): không bypass/side effects.
- [Trip GPS](../../backend/src/test/java/vn/gomate/TripLocationSharingTest.java): per-viewer REST/SSE/LAST_KNOWN giữ C/D và snapshot/Pin.
- Flutter [media lifecycle](../../test/home_media_lifecycle_test.dart), [retention](../../test/post_view_retention_test.dart), [block](../../test/global_block_test.dart), [feed](../../test/post_feed_test.dart): scroll/tab/account/permission không reload vô cớ.

Post AI mới phải test model missing/timeout/malformed/empty, invalid score/duplicate/unknown IDs, quyền đổi giữa hai bước, pagination/dedup/fallback, latency thật. Seed phase riêng phải test dry-run/production deny/license/rerun idempotency/batch-only cleanup/no real-user notification/engagement. Không sửa test PASS để che regression. Ghi exact command/scope/PASS/FAIL/skips; native Android tách khỏi automation. DB test dùng H2/DB cô lập, không seed/reset DB owner. Không tự mở phase khác.
