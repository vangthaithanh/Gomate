# GoMate P4 — Share và Search thật

Cập nhật 2026-10-23. P4 đã được chủ dự án nghiệm thu; phần DM được bổ sung trong DIRECT_MESSAGE_PRIVACY_REQUESTS.md.

## Quyết định đã được chủ dự án chốt

- Share DM: mutual friend chưa có DM có thể tạo ACCEPTED khi gửi Post thành công;
  DM ACCEPTED hiện có vẫn được Share sau unfollow/đổi privacy. Không gửi vào PENDING/CLOSED/blocked,
  không tự accept, reopen hoặc triển khai chính sách DM privacy mới.
- Group còn quyền gửi được nhận tham chiếu kể cả khi một số thành viên không có
  quyền xem Post. Mỗi người mở Post/media đều kiểm tra quyền hiện tại ở Spring.
  Chủ dự án chốt lại sau testcase ngày 2026-10-23: DM cũng nhận tham chiếu giống
  nhóm, kể cả bài Chỉ mình tôi. Chỉ người gửi phải được xem lúc gửi; người nhận
  kiểm tra quyền riêng khi mở bài/media, không nhận preview riêng tư. PENDING,
  block và điều kiện chọn liên hệ vẫn giữ nguyên.
- Gần tôi chỉ sắp gần nhất trước, không giới hạn bán kính. Không tạo GPS giả.

## Luồng và API

Base `/api/v1`, JWT hiện hành, raw DTO/error convention của repo, no-store.

| API | Contract |
|---|---|
| GET /posts/{id}/share-targets?q= | USER/GROUP, targetId UUID, name/avatar/subtitle; chỉ eligible |
| POST /posts/{id}/shares | clientRequestId UUID, targets[{type,targetId}], message tùy chọn; ACK từng đích |
| GET /search/posts?q=&hashtags=&size=&cursor= | Caption/hashtag thật; items + nextCursor; thumbnail Spring |
| GET /search/hashtags?q= | Tag/count chỉ tính Post đang được phép xem |
| GET /search/places?q=&filters=&latitude=&longitude=&size=&cursor= | ACTIVE Place, tag thật, keyset |
| GET /users/search?q=&page=&size= | Reuse API cũ, thêm tìm tiếng Việt không dấu |
| GET/POST/DELETE /search/recent | Đọc; submit body {query}; xóa bằng ?q=; current JWT user |

Keyword fold dấu tiếng Việt/đ, escape wildcard SQL; hashtag chip giữ identity
NFC/lowercase và AND. Caption khớp toàn bộ đứng trước, rồi mới nhất/id; Home không
đổi thứ tự. Post cursor bind viewer/query/tags và recheck permission từng trang.
Place filter AND: nature dùng nature/forest/lake/mountain/waterfall/beach/scenic;
checkin dùng photo_spot/iconic/trendy; history dùng historical/heritage/museum.
Nearby thiếu GPS chỉ báo lỗi tab Place, không chặn User/Post; không ghi GPS vào DB.
Page size 1–50 (Flutter 20); query <=200; tối đa 5 hashtag; Share <=50 đích,
message <=4.000; danh sách liên hệ giới hạn 100 candidate/query, dùng search để thu hẹp.

Share lưu POST_SHARE trong collection messages hiện có: Post ID, lời nhắn do người
gửi nhập và internal request hash. DTO chỉ lộ context.postId, không caption/cover/
Cloudinary URL. Bubble dùng link chung mở viewer thật; link không cấp quyền.
DM privacy completion: PG conversation mới chỉ commit sau ACK Mongo, có rollback/
cleanup nếu gửi đầu thất bại; không tạo DM rỗng khi chỉ mở composer. Deterministic Mongo _id theo sender/
request/target chống duplicate, kể cả concurrent/lost ACK/restart; đổi payload cùng
key bị 409. Sheet giữ key/nội dung cho retry và bỏ đích đã ACK khỏi selection.
Nháp khóa sau lần gửi đầu để không đổi payload retry; đóng/mở sheet là lượt gửi mới.
Không thêm push, repost, share-log table hay hệ thống chat song song.

## File và migration

- Backend mới: common/SearchText; social/post/PostSearch{Repository,Service,Controller},
  PostShare{Dtos,Service,Controller}; user/{repository,service}/RecentSearch*;
  place/{controller,service}/PlaceSearch*. Existing PlaceRepository/UserRepository,
  ConversationRepository/Service, MessageMongoService và PostRequestPolicyFilter được mở rộng.
- Flutter mới: posts/data/post_share_repository.dart. Nối lại SearchRepository,
  models/screen/widgets/filter, Home/Profile callbacks, SharePostContent và Message
  model/repository/bubble. Giữ khung UI cũ, không đổi Home media store/player.
- Test: PostSearchShareApiTest, PostShareMongoTest, PlaceApiTest schema assertion,
  test/post_share_search_test.dart; scripts/diagnostics/post_share_search_smoke.ps1.
- V24__search_history.sql chỉ tạo recent_searches + hai index. PK(user_id,query_key),
  FK users, display_query, used_at; max8/user dưới row lock. V1–V23 không sửa.
  Không đổi Post/Place/Follow schema, config, dependency, .env, Map/Trip/AI.

## Kiểm chứng và triển khai

- Backend targeted: 93 PASS, gồm Auth/Profile/Google/Firebase/Relationship/Moments/
  DM/Group/Post P1–P3/Activity/Search và real Mongo concurrent idempotency.
  Docker build cuối recheck 31 PASS, gồm các assertion mới nhất của P4.
- Flutter targeted: 80 PASS; debounce/stale/account switch, Share selection/search/
  cancel, partial ACK/lost ACK, protected link và Home media lifecycle regressions.
- Analyze: 0 errors, 15 warnings cũ không tăng, 321 info (336 diagnostics tổng).
  Chưa sạch lint; không gọi đây là analyze hoàn toàn xanh.
- PostgreSQL sạch V1→V24 và restored V23→V24 đều PASS; cả 36 bảng cũ giữ count.
  HTTP thật trên PostgreSQL/Mongo PASS: register/login, AND/normalize, recent max8,
  DM/group reference, partial/retry, private counts và protected media deny.
  Restart/relogin giữ history và đúng một tin nhắn; quyền mới vẫn áp dụng.
- API chính đã cập nhật V24; lịch sử V21/V22/V23/V24 success. Tất cả 36 bảng cũ
  không đổi count: users38, posts7, post_media12, likes2, saves2, comments6;
  recent_searches mới=0. Không đưa fixture/dữ liệu ảnh giả vào DB chính.
- Backup DB/JAR cũ, count JSON và log ở backups/post-share-search/ (gitignored).
  Không reset volume/repair; nếu có lỗi nâng cấp cần giữ backup và điều tra/fix forward,
  không tự xóa migration/table hay restore đè dữ liệu đang dùng.
- Đã dọn 2 API process/scratch PostgreSQL/Mongo và build-only image; chỉ 4 service
  Compose chuẩn còn chạy. Cổng API vẫn 8081; không đổi ADB reverse.
- APK: build/app/outputs/flutter-apk/app-debug.apk, debug build PASS, chưa tự cài.

## Cần kiểm thử Android trước khi nghiệm thu

Thanh/Thu: Share DM và group, nhiều đích/partial/retry; mở link khi có/mất quyền;
Search ba tab, “Đà Nẵng”/“Da Nang”, hashtag→Back, ảnh Spring, nearby có/không GPS;
recent submit/xóa/đổi tài khoản; Home cuộn/đổi tab/Like/Comment vẫn giữ media.
Không tuyên bố các ca máy thật này PASS từ automation. Không làm tiếp P5, Feed AI,
Global Block, DM privacy/message requests, moderation hoặc notification mới.
