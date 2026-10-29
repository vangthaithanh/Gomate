> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Global User Block — triển khai và kiểm chứng

Ngày 29/10/2026. Task: `CODEX_TASK_GOMATE_GLOBAL_BLOCK_TRIP_GPS_GROUP_CHAT_CONFIRMED.md`.

**IMPLEMENTED. Đã dừng joint test Android theo yêu cầu chủ dự án ngày 29/10/2026.**
Backend V26 đã chạy thật; 6 ca Android bên dưới đã PASS theo xác nhận trực tiếp và đối chiếu server. Không có lỗi mới được báo trong các ca này. Không tiếp tục yêu cầu thao tác hay tự thay đổi dữ liệu để hoàn tất các ca còn lại.

**GLOBAL_BLOCK_FULL_PASS chưa được xác nhận; BLOCKED ở phần nghiệm thu còn thiếu**, không phải thông báo lỗi chức năng đã tái hiện. Các ca chưa chạy được ghi rõ tại phần chốt cuối báo cáo; không suy diễn native PASS từ test tự động.

## Quyết định cuối cùng của chủ dự án

Một **Global Block có hướng duy nhất** cho Profile, DIRECT và Settings. Không giữ nghiệp vụ chặn tin nhắn riêng độc lập. A→B gây hạn chế xã hội/GPS hai chiều, nhưng A bỏ chặn không xóa B→A. Quyết định trong chat ngày 29/10 thay thế đề xuất tách hai loại chặn và các ghi chú DIRECT lịch sử.

- Block thu hồi hai follow edge, CANCEL các follow request PENDING, giữ lịch sử request. Không tự restore khi Unblock.
- Giữ nguyên DIRECT ACCEPTED/PENDING, conversationId, unread/body Mongo; không auto-accept/create empty chat.
- Không sửa thành viên/Leader/Trip invitations/Pin/publisher/reminders, không lọc/xóa Group Chat messages.
- GPS REST và SSE lọc theo người xem ở cả hai chiều, kể cả LAST_KNOWN. Không xóa snapshot toàn cục; C/D vẫn xem theo quyền của họ.
- Group popup chỉ nói về người **chính mình đã chặn**, một lần mỗi lần vào chat; Đóng không bỏ chặn, Bỏ chặn chờ ACK đúng người.

## Audit và migration

Trước cutover: V1–V25, 37 business tables; không có user_blocks/blocked_users. Profile gọi DIRECT block, Settings blocked còn demo. DB thật có **0 legacy DIRECT block flags**, không có trường thời gian block cũ tin cậy.

`backend/src/main/java/db/migration/V26__global_user_blocks.java` (checksum 26001):

- Thêm đúng 1 bảng `user_blocks`:
  - `blocker_user_id UUID` / `blocked_user_id UUID`, FK users ON DELETE CASCADE;
  - PK directed pair, CHECK không tự chặn;
  - `created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP`;
  - reverse index `(blocked_user_id, blocker_user_id)`.
- Backfill DISTINCT các cặp DIRECT hợp lệ từ `conversation_members.blocked=TRUE`, chống trùng. Với dữ liệu legacy, created_at là **thời điểm chuyển đổi**, không bịa thời điểm chặn lịch sử.
- Thu hồi follow hai chiều và cancel PENDING liên quan tới các cặp đã chuyển đổi.
- Giữ vật lý cờ cũ và lịch sử Mongo; runtime **không đọc/ghi cờ cũ để quyết định quyền**. Test cố ý để cả hai cờ cũ TRUE rồi Global Unblock: không còn veto ngầm.
- Không sửa V1–V25, không tạo bảng blocked_users thứ hai, không Flyway repair/reset volume.

Sau cutover: **V1–V26 đều success, 38 business tables** (39 nếu tính flyway_schema_history). Không thêm cấu hình/.env/dependency cho Global Block.

## API và file chính

| API | Quy tắc |
|---|---|
| `PUT /api/v1/users/{id}/block` | actor từ JWT, idempotent, no self/nonexistent/inactive; trả own flag + generic canInteract |
| `DELETE /api/v1/users/{id}/block` | chỉ xóa chiều của actor; không khôi phục follow/request |
| `GET /api/v1/users/me/blocked?page=0&size=20` | chỉ danh sách của actor; tối đa 50; name/avatar/nickname/blockedAt từ DB |
| `POST/DELETE /api/v1/conversations/{id}/block` | facade tương thích gọi cùng GlobalBlockService |
| `GET /api/v1/conversations/{id}/blocked-members` | active GROUP membership; chỉ những thành viên actor tự block |
| Profile/DM DTO | `isBlockedByMe` / `blockedByMe` thuộc người gọi; không serialize blockedByPeer; DM có canSend/canAccept |

Backend mới: `relationship/block/{GlobalBlockPolicy,GlobalBlockService,GlobalBlockController,GlobalBlockEvents}.java` và migration V26.
Backend tích hợp: UserRepository/UserDtos; SocialRelationshipService/Repository; ConversationController/Service/Repository/MessageDtos; PostService/PostFeedService/PostFeedRepository/PostActivityRepository; CommentService/Repository; NotificationService/StreamHub/PushDelivery; TripLocationService/StreamHub.

Flutter mới: `profile/data/user_block_repository.dart`, `profile/screens/blocked_users_content.dart`, `messages/widgets/blocked_group_members_content.dart`.
Flutter tích hợp: PublicProfile + Search model/parser; Settings blocked entry; DIRECT chat/detail/pending detail và repository/model; Notification realtime parser/repository; ProfilePostsController/Profile Post viewer; Comment/Likers panels; Moments repository/viewer; Trip location realtime service. Auth chỉ thêm getter sessionGeneration để bỏ ACK của phiên cũ, không đổi đăng nhập.
Docs cập nhật: AGENTS, CODEX_INDEX, DATABASE_CONTRACT, PROJECT_CONTRACT và báo cáo này.

## Kiểm soát quyền / hiệu năng

- Các mutation follow/accept, DIRECT first-send/accept/send, Post interaction và Share dùng khóa user_settings theo thứ tự UUID nhất quán. Share nhóm cũng khóa quyền đối với tác giả Post, không bỏ qua race chỉ vì gửi vào GROUP.
- Post detail/media/thumbnail/Range dùng cùng authorize; Feed/Search/hashtag/Activity lọc SQL trước paging, đọc lại quyền. Comment root/reply/liker/tagged-user không mở đường lộ người bị chặn; giữ bản ghi gốc.
- Sau commit gửi generic ACCESS_CHANGED qua kênh SSE hiện có, không tạo inbox/FCM báo bị chặn, không đưa tên blocker vào lỗi/event. Social notification mới/queued delivery kiểm tra lại pair; lịch sử inbox còn, tap kiểm tra Post/Comment thật.
- Location SSE chỉ là invalidation, không chứa tọa độ; kiểm tra block trước delivery. REST lọc một batch theo viewer. Khi quyền đổi, client fail-closed rồi lấy snapshot hợp lệ; response REST cũ bị bỏ bằng access revision. Không reconnect/publish/Pin lại, không tăng tần suất GPS/poll thường kỳ. C/D không bị server revoke; trong lúc recheck phía A/B, marker có thể tạm ẩn đến khi REST ACK.
- Home giữ bounded RAM media store đã PASS: recheck metadata, bỏ bytes/player mất quyền, giữ binary/player còn quyền. Không clear/download lại toàn bộ ảnh/video không liên quan. Viewer Profile recheck các tile đang mở, giữ tile/player còn quyền; Comment/Likers/Moment đang mở được kiểm tra lại.
- ACK của phiên đăng nhập cũ không được làm thay đổi UI tài khoản mới. UI thất bại giữ action/data phù hợp, không báo chặn/bỏ chặn thành công trước ACK.

## Test đã thực hiện

| Kiểm tra | Kết quả / bằng chứng |
|---|---|
| Scoped backend hồi quy | **131 tests PASS**, 0 failure/error/skip: Global Block, Privacy, DIRECT, Moments, Feed, Comment/Report, Share/Search, Activity, Post notifications, Push/SSE, Trip GPS, Place, reminders/migration. Không gọi đây là toàn baseline. |
| Docker Compose build API cuối | **26 tests PASS**: GlobalBlockApiTest (7 tại snapshot build), GlobalBlockMigrationTest (2), PostSearchShareApiTest (11), GroupTripChatApiTest (6); image đã build và chạy thật |
| Bổ sung PENDING + Share guard cuối | **19 tests PASS**: GlobalBlockApiTest 8 + PostSearchShareApiTest 11; PENDING không tự accept, Accept bị chặn đến khi Unblock. Các lượt trên có overlap, không cộng như số test độc lập. |
| PostgreSQL sạch + restored V25 | **1 opt-in probe PASS cho cả 2 DB**; Flyway migrate/validate/re-run; đúng số bảng, bảo toàn posts/trips/chat; fixture legacy hai chiều, unblock một chiều không backfill lại |
| Migration H2 | clean V1→26; upgrade V25→26; PK/self/FK, legacy flags và follow/request conversion: PASS |
| Real HTTP + PostgreSQL + Mongo + API restart | PASS trên DB/API cô lập: DIRECT block ↔ Profile/Settings cùng state sau restart; lịch sử Mongo nguyên vẹn, reverse block còn sau other-side Unblock, ACCEPTED gửi tiếp được; không restore follow |
| GPS tự động | REST/LAST_KNOWN 2 chiều; C còn cả 3 snapshot; SSE invalidate A/B ngay không cần GPS tick, không invalidate C; blocked update không phát tới A; pin/member/reminder/chat giữ nguyên: PASS |
| Flutter | **323 tests PASS** sau các chỉnh sửa cuối, gồm 6 Global Block tests + test GPS stale-response mới và các regression hiện có |
| Analyze | **0 errors / 14 warnings cũ**, không warning mới so với mốc 15; còn info lint (tổng 369 issues), không tự gọi analyze clean |
| APK debug | build thành công; SHA256 `0CD6864C2DDB8B8A69AC85AD5286D2EE6DD5DE11927DAD70D57E9BBA68D14D49` |

Logs/artifacts riêng: `backups/global-block-20261029/` (gitignored). `backend-final.log`, `compose-build.log`, `pending-and-share.log`, `verify3-reports/TEST-vn.gomate.GlobalBlockPostgresMigrationTest.xml`, `http-restart-result.json`, `flutter-release-check.log`, `analyze-release-check.log`, `apk-final.log`.
Các probe DB/API/Mongo test đã được dọn đúng phạm vi; Docker còn 4 service chuẩn api/postgres/mongo/ai. Không chạm DB/volume thật khi dọn fixture.

## Backup và dữ liệu thật sau cutover

Backup trước cutover: `backups/global-block-20261029/cutover-v25.dump`.
SHA256 `94A0AC9054D8F6172E1F67A494A6B4035E15AF8378DA3CC385552B1E4425F4EB`.
Backend cũ được giữ ở `rollback/old.jar` và image `gomate-auth-api:before-global-v26-20261029` (chỉ thay JAR trên runtime tương thích; không commit env/secrets của container).

| Bảng | Trước | Sau V26, trước native test |
|---|---:|---:|
| posts | 7 | 7 |
| post_media | 12 | 12 |
| comments | 19 | 19 |
| trips | 22 | 22 |
| trip_members | 32 | 32 |
| trip_pins | 1 | 1 |
| trip_reminders | 14 | 14 |
| conversations | 12 | 12 |
| conversation_members | 23 | 23 |
| legacy block flags TRUE | 0 | 0 |
| user_blocks | chưa có | 0 |

Hash toàn bộ row JSON của posts/trips/conversations trước và sau khớp; Mongo messages count trước/sau khớp. Đây là snapshot **ngay sau migration, trước các thao tác test của user**, không phải số liệu sau khi user chủ động Block/Unblock.

Rollback không tự chạy: ưu tiên forward fix. Không chỉ chạy app cũ trên DB mới rồi coi legacy flags là quyền thật. Khi thật sự rollback cần dừng ghi, backup dữ liệu phát sinh và phối hợp restore snapshot V25 với backend tương ứng; restore có thể mất dữ liệu sau backup nếu không đối soát. Không dùng repair/down -v/drop production tables làm rollback.

## Guided Android — kết quả thực tế và điểm dừng

Chủ dự án chọn **tự cài APK và cùng test ngay**. API 8081 healthy; USB ANDROID_DEVICE_SERIAL đã reverse `tcp:8081→tcp:8081`. Không tự cài/mở app, không tự Block user thật qua API.

Chủ dự án xác nhận đã cài APK mới, đang ở Thanh và chọn cặp TEST_ACCOUNT_A ↔ TEST_ACCOUNT_B (không phải tài khoản OTHER_TEST_ACCOUNT).

Danh sách nghiệm thu Android (kết quả thực tế ghi ở cuối mục):
1. Chặn từ DIRECT → Profile-shell và Settings đồng bộ; chờ ACK/error đúng.
2. Settings/Profile Unblock → DIRECT và các màn còn lại đồng bộ; không tự follow.
3. Reverse block độc lập; phía bị chặn chỉ thấy không khả dụng, không lộ blockedByPeer.
4. GROUP còn roster/messages/history, popup đúng mình-block-ai; Đóng giữ block, Unblock đúng người sau ACK; đóng/mở lại mới nhắc lại, rebuild/scroll không lặp.
5. Có snapshot LAST_KNOWN thật của A/B: Block ẩn marker qua REST/SSE ngay, Unblock khôi phục theo quyền, Pin/publishing không đổi; C/D vẫn thấy snapshot hợp lệ. Không ghi tọa độ vào report.
6. Post/Home/Profile/Comment/media và Search khi còn mở không lộ nội dung sau ACK; ảnh/video bài không liên quan không tải lại toàn bộ.

Sẽ bổ sung xác nhận trực tiếp và đối chiếu server ở đây. Không tự thay đổi nghiệp vụ ngoài Global Block trong lượt test.

### Android — ca 1: DIRECT → Profile/Settings — PASS

Ngày 29/10, user thao tác bằng Thanh và xác nhận đủ 3: chặn TEST_ACCOUNT_B trong DIRECT; chat còn lịch sử nhưng không gửi được; Settings có TEST_ACCOUNT_B và mở Profile từ đó có Bỏ chặn. Read-only server xác nhận directed Thanh→TEST_ACCOUNT_B đã có, conversation `REDACTED_UUID` vẫn ACCEPTED. Trước test pair không có block và không có follow, nên ca này chưa phải bằng chứng native về thu hồi follow có sẵn.

Đang giữ block để test Group Chat popup; chưa nghiệm thu Unblock/reverse/GPS trên Android. Không phải GLOBAL_BLOCK_FULL_PASS.

### Android — ca 2: Group popup / dismiss / re-entry — PASS

User giữ Thanh→TEST_ACCOUNT_B, xác nhận popup đúng thành viên với Bỏ chặn/Đóng; Đóng vẫn xem được chat/thành viên/lịch sử; cuộn không nhắc lại, thoát rồi vào lại mới hiện. User chọn Đóng lần nữa, giữ block. Server cũng xác nhận legacy conversation_members.blocked vẫn 0: thao tác DIRECT đang dùng Global duy nhất.

Tiếp theo: TEST_ACCOUNT_B kiểm tra phía bị chặn rồi tự chặn ngược Thanh; chưa tự thay đổi block qua API.

### Android — ca 3: phía bị chặn và tạo chiều ngược — PASS

User đăng nhập TEST_ACCOUNT_B xác nhận chat còn lịch sử, không gửi được và không có thông báo/nút tiết lộ “Thanh đã chặn bạn”; sau đó tự Chặn Thanh trong DIRECT. Read-only PostgreSQL xác nhận cả Thanh→TEST_ACCOUNT_B và TEST_ACCOUNT_B→Thanh đều tồn tại, chat vẫn ACCEPTED, legacy flags vẫn 0, pair vẫn 0 follow. Chưa kết luận Unblock một chiều PASS: bước kế tiếp là Thanh bỏ chặn TEST_ACCOUNT_B từ Settings, kiểm tra chiều TEST_ACCOUNT_B→Thanh vẫn còn.

### Android — ca 4: Settings Unblock chỉ gỡ chiều của người gọi — PASS

User dùng Thanh bỏ chặn TEST_ACCOUNT_B trong Settings và xác nhận: TEST_ACCOUNT_B biến mất khỏi danh sách; DIRECT hết dòng tự chặn nhưng vẫn không gửi được. Read-only PostgreSQL xác nhận chỉ còn TEST_ACCOUNT_B→Thanh, chiều Thanh→TEST_ACCOUNT_B đã được xóa; chat vẫn ACCEPTED, legacy flags 0, pair follow 0. Không có thao tác sửa block qua API của agent. Kế tiếp kiểm tra TEST_ACCOUNT_B gỡ chiều còn lại bằng popup Group Chat, chờ ACK và gửi lại DIRECT.

### Android — ca 5: Group popup Unblock và DIRECT gửi tiếp — PASS

User dùng TEST_ACCOUNT_B chọn Bỏ chặn Thanh trong popup Group Chat, xác nhận Settings cập nhật và gửi được tin thử trong DIRECT, lịch sử cũ còn. Server đối chiếu: pair còn 0 block, 0 follow, legacy flags 0, chat vẫn ACCEPTED; Mongo có 9 tin của chat này so với 8 ở lần đọc trước. Query kiểm chứng dùng đúng UUID legacy subtype 3, không đọc/log body hay token.

Chuyển sang GPS: TEST_ACCOUNT_B đang có pin ở `Lịch trình 1 ne` (`REDACTED_UUID`); cả hai có snapshot ở Trip đó. Snapshot Thanh là LAST_KNOWN cũ, chưa phát mới trong lượt test; TEST_ACCOUNT_B đã có ACK mới ngày 29/10. Chưa kết luận GPS native PASS; cần xác nhận thấy marker trước khi thử Block/Unblock. Không ghi tọa độ vào report.

### Android — GPS baseline trước Block — xác nhận

User giữ TEST_ACCOUNT_B, mở Map ở `Lịch trình 1 ne`, xác nhận thấy vị trí gần nhất của Thanh. Đã lưu metadata snapshot trước block vào `native-gps-before-block.jsonl` (chỉ Trip/user label/updatedAt; không có tọa độ). Tiếp theo user tự Chặn Thanh từ DIRECT rồi quay lại Map cùng Trip, giữ Pin; chưa kết luận ca ẩn marker PASS khi chưa nhận kết quả.

### Android — ca 6: Block ẩn LAST_KNOWN, không xóa snapshot/Pin — PASS

User dùng TEST_ACCOUNT_B chặn Thanh, quay lại Map cùng `Lịch trình 1 ne`, xác nhận marker Thanh biến mất trong khi vẫn ghim và giữ danh sách thành viên. Read-only đối chiếu metadata trước/sau: snapshot Thanh vẫn tồn tại và updatedAt giữ nguyên; snapshot TEST_ACCOUNT_B vẫn tồn tại và có ACK mới sau baseline. PostgreSQL chỉ có chiều TEST_ACCOUNT_B→Thanh, Pin của TEST_ACCOUNT_B vẫn cùng Trip, 3 thành viên ACTIVE giữ nguyên. Bằng chứng ở `native-gps-after-block.jsonl` và `compare_native_gps.py`, không có tọa độ.

Đây là nghiệm thu trên một điện thoại, thao tác Block rồi quay lại Map; chưa phải chứng cứ native cho hai thiết bị cùng giữ Map mở và nhận invalidation SSE trực tiếp. SSE hai chiều/C không bị ảnh hưởng đã PASS ở test backend, không gộp thành native PASS. Kế tiếp kiểm tra phía Thanh đang bị chặn cũng không thấy marker TEST_ACCOUNT_B; chưa bỏ chặn.

### Chốt joint test theo yêu cầu chủ dự án

Chủ dự án yêu cầu dừng khi được đề nghị test phía Thanh đang bị chặn. Vì vậy không có xác nhận cho bước đó và agent không thực hiện thêm thao tác test/server mutation.

Đã PASS native: DIRECT → Profile/Settings; Group popup Đóng/re-entry; phía bị chặn và tạo chiều ngược; Settings Unblock độc lập; Group popup Unblock + gửi tiếp DIRECT; Map ẩn LAST_KNOWN phía TEST_ACCOUNT_B và server giữ snapshot/Pin/member/publishing.

Chưa kiểm tra nốt trên máy thật:
- GPS phía Thanh đang bị chặn; marker hiển thị lại sau Unblock và timestamp LAST_KNOWN giữ nguyên ở bước khôi phục.
- Hai thiết bị đồng thời giữ Map mở để quan sát SSE trực tiếp và quyền GPS của C/D. Backend đã có test PASS, không gọi đó là native PASS.
- Nút Unblock trực tiếp trên Profile, lỗi mạng/ACK thất bại và popup nhiều thành viên bị chặn trong phiên Android này.
- Ma trận Post/media/Range/Search đang mở, thu hồi follow có sẵn và follow request race trên máy thật; các kiểm tra backend/Flutter tương ứng đã được báo riêng ở trên.

Lần đối chiếu server cuối còn **TEST_ACCOUNT_B→Thanh**, không có chiều ngược, legacy flags 0, chat ACCEPTED, pair follow 0. Agent giữ nguyên trạng thái này; không tự Unblock, khôi phục follow, bỏ ghim hay xóa tin thử. Không ghi token, body riêng tư hoặc tọa độ vào báo cáo. Trạng thái chốt là các ca đã test PASS, nghiệm thu toàn bộ còn thiếu; không báo GLOBAL_BLOCK_FULL_PASS.
