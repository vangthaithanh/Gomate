# Nghiệp vụ và quyền hiện hành

Nguồn V26; không mở phase mới. [PROJECT_CONTRACT](../PROJECT_CONTRACT.md), [DATABASE_CONTRACT](../DATABASE_CONTRACT.md) có phần roadmap lịch sử, không phải tất cả đã được triển khai.

| Miền | Rule khóa |
|---|---|
| Account/follow | PUBLIC follow trực tiếp; PRIVATE PENDING, chỉ ACCEPT tạo edge. Mutual = hai active follow, không friends table. Privacy toggle giữ follower hợp lệ, không tự accept pending. |
| Global Block | Một directed `user_blocks` cho Profile/DIRECT/Settings; hạn chế xã hội/GPS hai chiều. Revoke hai follow/cancel pending; Unblock chỉ chiều của caller, không restore follow. Không tiết lộ blockedByPeer. |
| Post | API EVERYONE/FOLLOWERS resolve ACCOUNT theo account visibility; FRIENDS cần mutual; ONLY_ME owner. PRIVATE không chọn EVERYONE. Spring recheck list/detail/media. |
| Publish | 1–12 media, caption≤2200 graphemes, ≤5 hashtag NFC, optional valid user tags/Place FK. Video mới≤30s/cắt thật; lịch sử31–60s còn đọc. Staging READY→ATTACHED, owner/request hash/idempotency giữ nguyên. |
| Feed/Profile | Home newest `(created_at DESC,id DESC)`, cursor viewer/scope. Profile pin≤3 không boost Home. Giữ owner audience/pin/delete. |
| Interactions | Like/Save persistent/idempotent/authorized. Comment≤2000, report description≤1000. Count visible root+reply; xóa root ẩn thread. Protected comment media, không auto-moderation vì Report. |
| DM | Open là draft, first-send mới tạo thread. Mutual ACCEPTED; contact khác theo recipient privacy có thể PENDING. PENDING không autoaccept khi mutual. ACCEPTED độc lập privacy/follow nhưng bị Global Block cấm gửi/accept/Share; giữ metadata/body/history. |
| Share | Post ID reference; sender authorized lúc gửi. Mutual chưa có DM được tạo ACCEPTED khi thực Share; không Share/autoaccept PENDING. DM/GROUP recipients recheck khi mở, không copy private preview. Group messages không bị lọc/xóa vì pair block. |
| Notifications | PG inbox trước transport. Like once/post/actor: inbox+SSE, không FCM. Comment→Post owner; Reply→actual target, eligible FCM. Không self/Save/Share/Report/comment-like notification. Old tap không cấp quyền đọc. |
| Trip | Một PERSONAL/GROUP; đúng một LEADER, chỉ LEADER/MEMBER. PERSONAL mặc định, GROUP khi người khác thật sự join. API hiện tại require LEADER để tạo/mời; invitee accept mới join. Rule đích member-origin accept rồi leader approve vẫn deferred, chưa có API approve để AI tự dùng. Không autojoin khi tick danh sách. |
| Pin/GPS | Không Start/Complete/Cancel hay Share ON/OFF. Own Pin + active membership + non-archived Trip cho publish. Unpin/switch dừng gửi Trip cũ, giữ LAST_KNOWN/timestamp; leave/remove/archive xử lý scoped snapshot/quyền. Block lọc LIVE/LAST_KNOWN hai chiều, C/D giữ quyền. |
| Reminder | Bắt buộc ngày start/end, không giờ khởi hành cấp Trip. D-2/D-1 local20:00 theo timezone, độc lập Pin; không backfill deadline đã qua khi create/edit/accept hoặc gửi nhắc ngày hôm qua hôm nay. Không revive T-60/T-30. |
| Stop | Ordered Place occurrence, A→B→A hợp lệ, adjacent A→A không. Time optional thuộc occurrence; thiếu start bỏ/clear end; start-only chưa là interval đầy đủ. Sửa đúng stopId, reopen lấy giờ lưu. Đặt mới future/đúng ngày Trip; nếu end thì start<end. Server IANA/UTC; không tự rebase lịch sử. |

[PostController](../../backend/src/main/java/vn/gomate/social/post/PostController.java)/[PostService](../../backend/src/main/java/vn/gomate/social/post/PostService.java) bảo vệ media/thumbnail/Range bằng JWT và quyền từng request, Cloudinary authenticated; không public originals/token cho AI. [Feed VISIBLE](../../backend/src/main/java/vn/gomate/social/post/PostFeedRepository.java) và [Block policy](../../backend/src/main/java/vn/gomate/relationship/block/GlobalBlockPolicy.java) là choke-points.

Nguồn: [Privacy](../ACCOUNT_PRIVACY_FOUNDATION_P1A.md), [P1C](../PROFILE_POST_P1C.md), [P2](../POST_HOME_FEED_P2.md), [P3](../POST_COMMENT_REPORT_P3.md), [P4](../POST_SHARE_SEARCH_P4.md), [DM](../DIRECT_MESSAGE_PRIVACY_REQUESTS.md), [Block](../GLOBAL_USER_BLOCK.md), [notifications](../POST_INTERACTION_NOTIFICATIONS.md), [Pin](../TRIP_PIN_CENTRIC_BUSINESS_RESET.md), [last-known](../MAP_PIN_SWITCH_LAST_KNOWN_FIX.md), [D2/D1](../TRIP_DATE_ONLY_D2_D1_REMINDERS.md), [Stop](../TRIP_STOP_TIME_PERSIST_EDIT_VALIDATION_HOTFIX.md).

**UI LOCK:** giữ screens/navigation/forms/cards/player. Home bounded RAM/video lifecycle đã PASS; ranking không đổi mount/key/reload media hoặc trộn cache giữa accounts. AI không tự đổi quyền, quan hệ, Post hay Trip.
