# Post cold-start data — chỉ kế hoạch, KHÔNG seed

Nguồn: [V19](../../backend/src/main/resources/db/migration/V19__post_publish.sql), [V20](../../backend/src/main/resources/db/migration/V20__profile_post_management.sql), [V21](../../backend/src/main/resources/db/migration/V21__post_feed_interactions.sql), [V22](../../backend/src/main/resources/db/migration/V22__post_comments_reports.sql), [DTO](../../backend/src/main/java/vn/gomate/social/post/PostDtos.java).

| Bảng/field thật | Ý nghĩa |
|---|---|
| posts.id BIGINT, author_id UUID | business ID/owner, không mạo danh user thật |
| client_request_id UUID, request_hash | UNIQUE author/request; cùng key khác payload phải conflict |
| content, audience, place_id | caption; DB ACCOUNT/FRIENDS/ONLY_ME; API resolve EVERYONE/FOLLOWERS; optional Place FK |
| created_at/pinned_at/deleted_at | metadata server, không tự chỉnh để tạo popularity |
| post_media | owner/post, staging state, public_id/thumbnail_public_id, kind/mime/bytes/duration/dimensions/sort; không public originals |
| hashtags/post_hashtags | NFC/tag hash, ≤5 tags/Post |
| post_user_tags | optional valid user FK, chỉ fixture được phép |
| post_likes/post_saves | unique Post/user; không sinh engagement thật cho AI |
| comments/comment_likes/comment_media/post_reports | không seed để làm giả popularity |

**Đề xuất cần owner duyệt, chưa thực hiện:** pilot300 Posts, 30 synthetic authors, 5 destination hiện có ×60 Posts, ≥10 chủ đề (biển/núi/ẩm thực/văn hóa/camping/đô thị/gia đình/nghỉ dưỡng/lịch sử/sinh thái). 210 Post ảnh/90 video, 1–3 media/Post, video≤30s, ảnh≤10MB/video sau cắt≤100MB. 20 author PUBLIC/10 PRIVATE; dự kiến210 ACCOUNT (140 public/70 private),60 FRIENDS,30 ONLY_ME. Không spam một hashtag/duplicate caption/media.

Synthetic relations chỉ dùng fixture permission trong dev/demo, không coi là preference/training metrics thật. Không dùng tài khoản owner hoặc gửi FCM/SSE tới user thật. Chỉ media tự tạo/CC0/PD/license reuse phù hợp có attribution; không Google Images/social/ảnh riêng tư.

Manifest ngoài DB ghi batch_id/version/hash, SYNTHETIC, author alias→fixture user, post/upload request UUID, topic/destination/Place external_id, source URL/page/license/author/attribution, approval và split group. Không credential/PII/GPS. Resolve external_id→places.id tại môi trường đích, không copy numeric ID local, không trộn frozen semantic-v1 Place data.

Flow tương lai: validate manifest/license/duplicate/owner → dry-run coverage/count → owner duyệt → dev/demo/staging opt-in → upload qua Spring/Cloudinary authenticated → READY → publish API với UUID deterministic per batch/item → lưu manifest mapping IDs. Không INSERT bypass hooks/counters/notifications, không public media URL, không thêm cột/bảng business cho provenance khi chưa duyệt. Production default deny; không startup/CI tự seed.

**Hiện chưa có Post seed importer/dry-run/cleanup CLI**; không chạy hay giả script tồn tại. Phase riêng phải implement plan/dry-run không ghi và batch/environment scope bắt buộc. Read-only thống kê hiện có:
```powershell
docker compose exec -T postgres psql -U gomate -d gomate_auth -c "SELECT count(*) FROM posts"
```
Manifest JSON khi được cung cấp có thể kiểm tra syntax với `python -m json.tool MANIFEST_PATH`; không phải import.

Cleanup dự kiến: preview exact batch/owner/attached assets, DELETE owner API chỉ IDs do batch tạo rồi workflow cleanup media hiện có. Không TRUNCATE/cascade xóa user/Trip thật/reset DB/Flyway. Lần2 phải 0 duplicate asset/Post; cleanup lần2 không chạm nội dung khác. Đề xuất split80/20 theo author/source/media group, không để ảnh/near-duplicate/author xuyên split. Nếu cần interaction nghiên cứu thì fixture riêng gắn SYNTHETIC ngoài DB, không người thật/production metrics. Phải duyệt số lượng/tỷ lệ/license/split và importer trước mọi lệnh write.
