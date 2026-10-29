> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Chat Mới Lên Đầu Và Share Tham Chiếu Qua DM

Ngày: 2026-10-23. Hotfix hẹp sau DM Privacy; không mở phase khác.

## Nguyên Nhân

1. Backend đã sắp inbox theo `conversations.updated_at DESC`, nhưng Flutter gửi
   vào chat có sẵn chỉ cập nhật message tại vị trí cũ. Chấp nhận tin chờ cũng chỉ
   đổi trạng thái ở vị trí cũ. Vì vậy chat mới hoạt động có thể nằm dưới nhóm cũ.
2. Người dùng xác nhận đang Share bài Chỉ mình tôi. Luồng trước lọc DM theo quyền
   xem của người nhận ngay lúc gửi; nhóm nhận tham chiếu nên vẫn xuất hiện. Đây
   không phải dữ liệu demo hay lỗi thiếu quan hệ. Đã hỏi và được chủ dự án duyệt
   thống nhất DM với nhóm, không tự nới quyền đọc nội dung.

## Thay Đổi

- `lib/features/messages/data/message_repository.dart`: sau gửi hoặc accept được
  ACK, đưa chính chat đó lên đầu; không đổi ID/history, không tạo bản sao. Lỗi gửi
  không đẩy chat lên và không báo thành công. Bỏ phản hồi refresh inbox cũ nếu
  đã có gửi tin thành công trong lúc chờ, tránh đảo ngược thứ tự vừa cập nhật.
- Không tải lại toàn bộ inbox sau mỗi tin, không thêm timer/polling hoặc sửa UI.
- `backend/.../message/service/ConversationService.java`: bỏ điều kiện quyền đọc
  Post của người nhận tại bước chọn/gửi Share DM. Vẫn yêu cầu người gửi được xem,
  DM mutual/ACCEPTED hợp lệ, không PENDING/blocked; nhóm vẫn kiểm tra membership.
- Share chỉ mang ID/lời nhắn người gửi nhập, không copy caption/ảnh/Cloudinary URL.
  Thu nhận tham chiếu ONLY_ME, nhưng mở Post/media vẫn 404 và dùng trang không
  khả dụng đã làm. Không sửa PostService.authorize hoặc protected media.
- Cập nhật test Flutter/Backend và knowledge: AGENTS, index, Project/Database
  contract, P4 Share, DM Privacy. API shape, schema, migration, dependency/config
  giữ nguyên; Flyway vẫn V24.

## Kiểm Chứng

- Flutter: 57 PASS trong direct_message_privacy, post_share_search,
  trip_member_lifecycle, trip_pending_load_regression. Có widget test inbox đang
  mở đổi thứ tự ngay sau ACK, gửi lỗi không đổi vị trí, không reload inbox mỗi
  tin và refresh chậm không ghi đè thứ tự mới; accept vẫn giữ chat/history.
- Backend: 43 PASS khi Docker build (Direct Message 14, Post Publish 12,
  Share/Search 11, Group Chat 6). Test mới xác nhận PRIVATE/ONLY_ME gửi tham chiếu
  được nhưng GET Post/thumbnail/media của người nhận vẫn 404, sender mất quyền
  bị 404, block/PENDING vẫn không Share; không tự cấp quyền/follow/accept.
- Regression bổ sung: 34 PASS (Privacy 5, Firebase Google 3, Google flow 6,
  Post Activity 6, Comment/Report 8, Feed 6). Tổng 77 backend tests, không cộng trùng.
- Lượt build đầu dùng snapshot test chưa sửa kỳ vọng HTTP khi sender mất quyền:
  FAIL 1 assertion (mong 200 thay vì 404). Đã sửa test về 404 và build lại: 43 PASS.
  Không sửa API để nới quyền người gửi chỉ nhằm làm test xanh.
- Analyze: 0 errors / 15 warnings cũ / 335 info, exit 1 vì baseline chưa sạch lint;
  không có warning mới. `git diff --check` các file sửa không lỗi whitespace.
- Debug APK build PASS, chưa cài hay test máy thật trong lượt này:
  `build/app/outputs/flutter-apk/app-debug.apk`, SHA256
  `A4089ECF45654AA61AE5531C82DD0FC115FAF4A06D0D0909DC94AA50FB336D56`.
- API chuẩn 8081 đã cập nhật, startup thành công; endpoint Share không JWT trả 401.
  Flyway V24, 0 failed migration; toàn bộ 37 business-table counts khớp trước/sau
  cutover. Không migration/schema/seed hay upload media trong bước này.
- Backup DB/JAR trước sửa và frozen dump/counts trước cutover, cùng test logs ở
  `backups/dm-inbox-order/` (gitignored). Không restore, repair hay reset volume.
  Container Maven regression tự xóa sau test; chỉ 4 service GoMate chuẩn còn chạy.

## Giới Hạn

- Đây không phải DM realtime/push mới. Tin nhận từ thiết bị khác vẫn theo cơ chế
  tải inbox hiện tại; không thêm polling để đổi thứ tự khi chưa có dữ liệu mới.
- Share không phải cấp quyền đọc hay sao chép bài. Người nhận thấy tham chiếu
  không có nghĩa được xem nội dung; quyền đọc luôn do Spring quyết định lúc mở.
- Cần cài APK mới để nhận fix thứ tự local; đóng/mở lại khung Share để tải danh
  sách theo policy backend mới. Không đổi cổng hoặc ADB reverse.

## Máy Thật

Sau khi cài APK mới, dùng Thanh/Thu:
1. Chọn một DM có sẵn đang nằm dưới nhóm, gửi tin, quay về inbox: DM lên đầu ngay.
2. Nhận/accept tin chờ: cùng chat/history vào đầu Main, không sinh chat trùng.
3. Share bài Chỉ mình tôi: thấy Thu nếu DM ACCEPTED hoặc mutual đủ điều kiện;
   gửi thành công, Thu mở thì bài không khả dụng. Không xem được ảnh/video riêng tư.
4. Bài có quyền xem vẫn mở bình thường; PENDING/blocked không trở thành đích Share.
5. Nhóm và Share retry giữ như trước. Không tự cài/chạy testcase thay người dùng.

## Bổ Sung Tên Hiển Thị Chat (2026-10-23)

- Sửa parser `RealDirectMessageRepository`: dùng `peer.displayName` cho tên chat
  và người tham gia; chỉ dùng account `nickname` khi thiếu tên hiển thị.
  Không gán account nickname vào trường biệt danh riêng của hội thoại vì getter
  hiện có sẽ ưu tiên nó, gây hiển thị handle thay vì tên như TEST_ACCOUNT_B.
- Giữ nguyên UI, biệt danh riêng của demo, API, dữ liệu tài khoản và quyền DM/Share.
  Không sửa backend/DB/config/migration và không thêm request mạng.
- Thêm 4 regression tests: tên thật ở inbox/header, fallback khi tên null/rỗng,
  và bảo toàn biệt danh riêng của hội thoại. Tổng 61 Flutter tests liên quan PASS;
  analyze 0 errors / 15 warnings cũ / 335 info (exit 1 do lint baseline).
- Debug APK build PASS: `build/app/outputs/flutter-apk/app-debug.apk`.
- Cần kiểm tra máy thật sau khi chạy bản mới: mở Tin nhắn và chat với TEST_ACCOUNT_B,
  xác nhận cả danh sách và tiêu đề dùng tên hiển thị thay vì handle tài khoản.
  Chưa test máy thật trong lượt sửa này.
