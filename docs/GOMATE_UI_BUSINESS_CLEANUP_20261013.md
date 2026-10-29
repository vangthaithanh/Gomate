# GoMate — Tổng hợp nghiệp vụ UI/UX, quy tắc tích hợp backend và checklist dọn dữ liệu giả

**Phiên bản tài liệu:** 2026-10-13 · Bàn giao UI → backend · Bao gồm bản sửa popup lời mời lịch trình chưa xác nhận.

> **Phạm vi:** Tổng hợp những hạng mục đã trao đổi, thiết kế và bàn giao trong chuỗi làm việc Profile → Search/Posts → Place Detail → Moments → Messages/Trip/Maps → Notifications, đồng thời nêu các quy tắc dùng chung đã chốt từ những giai đoạn UI trước. Đây là tài liệu **nghiệp vụ và handoff**, không khẳng định các API chưa có đã chạy thật. File Dart thực tế trên máy có thể mới hơn các gói đã bàn giao; luôn đối chiếu Git diff trước khi xoá hoặc thay.
>
> **Nguồn đối chiếu:** gói Profile V1, V2, V3, V4; bản sửa menu Khoảnh khắc Profile; ba file Search/Place Detail do người dùng gửi; Notifications V1; bản sửa lời mời đính kèm tài liệu. GitHub `vangthaithanh/Gomate`, nhánh `master` khi đối chiếu là `738d548c45fd07756e41a84d488e5609f5b14b45`. Các gói UI local chưa chắc đã được push lên nhánh đó.

---

## 0. Quy ước, mức độ hoàn thiện, thứ tự ưu tiên

### 0.1. Bốn trạng thái phải phân biệt

| Trạng thái | Nghĩa |
|---|---|
| **Đã chốt nghiệp vụ** | Yêu cầu sản phẩm phải tuân thủ về sau; không đồng nghĩa backend đã triển khai. |
| **UI/điều hướng đã chuẩn bị** | Có màn hình/component/route tại các gói Dart bàn giao; **chưa xác nhận biên dịch Flutter trên máy người dùng**. |
| **Demo/local-only** | Dữ liệu và cập nhật trạng thái trong RAM, không đồng bộ server, phải bỏ hoặc thay khi có API. |
| **Đã có contract/API hiện hành** | Có interface/service trong source được đối chiếu; vẫn cần test end-to-end trên phiên bản backend đang chạy. |

### 0.2. Nguyên tắc triển khai GoMate

1. **Chỉ sửa UI/UX trừ khi có yêu cầu backend rõ ràng.** Không chỉnh repository/API/service/db chỉ vì cần demo màn hình.
2. **Xem component có sẵn trước khi viết mới:** `GoMateMainTabHeader`, `GoMateBottomSheet` (`compact` và `expanded`), `GoMateSnackBar`, `GoMateSearchField`, `GoMateNameEditorContent`, `CommentSheetContent`, `SharePostContent`, `GoMateNotificationPopup`, các màn Post/Moment/Trip/Map hiện có.
3. **Responsive:** không dùng khung 375×715 px cố định, `position:absolute` từ Figma React, hay chiều cao fix cứng của toàn màn. Code xuất Figma là bản mô tả thị giác, ảnh thiết kế là tham chiếu tỷ lệ.
4. Bộ màu: gradient `#0A43A8 → #0C6ECF → #0D8AE8`, text xanh đậm `#08327C`, icon xanh `#0A43A8`, xám `#828282`, viền `#DADADA`, nền trắng, bóng đổ phía ngoài. Nút xác nhận dùng gradient GoMate, không dùng tím Material mặc định.
5. Dùng `LucideIcons` thống nhất; back nên dùng `chevron_left` cùng kích thước/component có sẵn. Không thay bừa logic back của picker, bottom sheet hoặc màn có route quay về Maps đặc biệt.
6. Chỉ còn vai trò nhóm **LEADER/MEMBER**, không có phó nhóm/deputy. Tuyệt đối không tái tạo UI/enum/screen liên quan phó nhóm.
7. ID `ui-preview-*` / `demo-*` **tuyệt đối không được gửi** lên API thật, không coi thông báo demo là một sự kiện server đã phát hành.
8. Popup feedback `GoMateSnackBar` non-modal, tự ẩn sau khoảng 10 giây, không dim; BottomSheet modal dùng shell chung; **popup thông báo realtime** dùng `GoMateNotificationPopup`, là overlay đầu màn không dim và không có action chữ xanh.

---

## 1. Hồ sơ cá nhân (Profile)

### 1.1. Trang cá nhân của mình

- Header thống nhất với các main tab nhờ `GoMateMainTabHeader`; hiển thị nickname, nút cộng **chưa kết nối tạo bài**, và menu. Không chuyển nút cộng sang chụp Moment hoặc route khác khi chưa thống nhất.
- Avatar có badge dấu cộng cùng phong cách avatar Khoảnh khắc ở Home. Chạm avatar khi có Khoảnh khắc khả dụng sẽ mở luồng Moment hiện có, không dựng viewer riêng.
- Khu thông tin: tên, username/biệt danh, số Người theo dõi/Bạn bè; tiểu sử và liên kết **chỉ render khi có dữ liệu**. Không có bio/link thì **ẩn hoàn toàn** cả hàng.
- Hai tab: **Bài viết** là bài thuộc tài khoản đang xem; **tim** là danh sách địa điểm người dùng đã yêu thích. Bấm địa điểm → `PlaceDetailScreen` hiện có.
- Không có bài/follower/bạn bè/địa điểm và không bật demo thì hiển thị empty state **“Chưa có …”**, không hiện câu chữ kiểu “backend chưa hỗ trợ”. Demo bật chỉ để QA UI.
- Dữ liệu đang có: `AuthService` tải/cập nhật một số trường hồ sơ; `FavoritePlaceStore` chỉ là UI store trong bộ hiện tại, **không được coi là danh sách yêu thích lưu bền trên server**.

### 1.2. Sửa trang cá nhân

- Sửa tên, biệt danh, tiểu sử, liên kết bằng bottom sheet/editor chung; không tạo popup màu riêng. Tên và biệt danh tối đa **50 ký tự theo đặc tả UI**, bio tối đa **1.000 ký tự**. **Lưu ý:** một phiên bản backend nickname từng có giới hạn 40 ký tự — phải thống nhất hợp đồng validation trước khi deploy, không tự cho là đã nâng lên 50.
- Chỉnh avatar: chọn ảnh từ máy hoặc chụp; UI preview cục bộ; upload/persist phải do backend contract được nối sau.
- Giới tính: chọn **một trong hai** Nam/Nữ qua selector tròn, nút Xác nhận gradient; không dùng checkbox vuông hay tím mặc định.
- Liên kết & giới tính: dấu `>` ở cuối dòng **cố định mép phải** kể cả khi đã nhập giá trị dài.
- `profile_edit_screen.dart` (bản V2) hiện có `_genderPreview`, `_linkPreview`, một số ảnh tạm; **không coi những giá trị đó đã được lưu backend**.
- Cập nhật tên/bio thật chỉ khi `AuthService`/contract hiện hành hỗ trợ. Khi request thất bại phải hiển thị lỗi, không “Đã lưu” giả.

### 1.3. Trang cá nhân người khác

- **Public:** xem hồ sơ/bài viết mà không cần theo dõi (trong giới hạn quyền sản phẩm). Nếu chưa theo dõi: nút **Theo dõi**. Nếu đã theo dõi nhưng người kia không theo dõi lại: vẫn **chưa phải bạn bè**.
- **Private chưa được duyệt:** chỉ xem thông tin công khai cho phép. Bài viết bị khóa; nhấn Người theo dõi/Bạn bè phải có popup thông báo **phải theo dõi và được chấp nhận mới xem được**. Chưa follow → `Theo dõi`; đã gửi yêu cầu → `Chờ xác nhận`; chạm lại ở `Chờ xác nhận` là hủy yêu cầu.
- **Private đã chấp nhận:** được xem những nội dung theo quyền đã duyệt. Khi chủ động bỏ theo dõi private **đã được duyệt**, trước khi bỏ phải hiện popup xác nhận, giải thích muốn theo dõi lại phải chờ duyệt. Các trường hợp follow/unfollow khác **không cần xác nhận**.
- **Bạn bè thực sự:** điều kiện **hai chiều** (`followingByMe && followsMe`, hoặc `mutualFriend` từ server). **Chỉ bạn bè hai chiều** mới có quyền xem Khoảnh khắc của nhau, và menu ba chấm mới có thao tác ẩn/bỏ ẩn Khoảnh khắc.
- Menu `⋮` với người chưa là bạn: **Báo cáo**, **Chặn**. Với bạn bè: **Báo cáo**, **Chặn**, thêm **Ẩn khoảnh khắc** hoặc **Bỏ ẩn khoảnh khắc** đúng trạng thái mute.
- Báo cáo tái sử dụng `ReportReasonContent`; chặn dùng luồng Messages hiện có nếu có direct conversation. **Chặn theo `userId` bất kỳ chưa có contract UI/repository tương ứng trong bộ đối chiếu**; không tạo chat ẩn rồi tự chặn, không fake thành công cho tài khoản thật.
- Ẩn Khoảnh khắc đang có `MomentsRepository.muteUser(userId)`; `unmuteUser()` **chưa xuất hiện trong interface Flutter đã đối chiếu** dù API DELETE `/moment-mutes/{userId}` có trên backend nguồn. Handoff phải bổ sung qua repository và đọc được trạng thái mute bền vững, không chỉ `_locallyMutedRealUser` trong RAM.
- Nút Nhắn tin mở direct chat của **đúng userId thật**, không mở đại một cuộc trò chuyện mẫu trên tài khoản production.
- Avatar người khác ở Home, Comments, Search, Messages, danh sách theo dõi, thông báo… phải dẫn tới đúng `PublicProfileScreen(userId: ...)` khi có ID hợp lệ; không suy ID từ display name.

### 1.4. Người theo dõi / Bạn bè

- Header và tỷ lệ avatar/font/spacing thống nhất các màn, tránh quá nhỏ.
- Tab **Người theo dõi:** liệt kê người follow mình; nếu bản thân chưa follow lại thì hiện **Theo dõi lại**, nếu đã follow thì không hiện lời mời follow lại.
- Tab **Bạn bè:** danh sách quan hệ hai chiều; hành động **Bỏ theo dõi** theo nghiệp vụ đã chốt (lưu ý kết quả mất trạng thái mutual).
- Tìm kiếm hoạt động theo mẫu tìm kiếm lịch trình: chưa nhập từ khóa không cần chữ Hủy; khi nhập/focus theo quy tắc thiết kế mới hiện Hủy và filter.
- Không có dữ liệu thật: empty state; trong QA có thể bật sample list. Khi bấm sample user phải mở đúng sample profile, **không gọi API bằng fake ID**.

### 1.5. Những thứ cần backend Profile

- Trạng thái `isPrivate`, follow request `pending/accepted/rejected/cancelled`, quan hệ hai chiều và quyền xem thông tin follower/friends.
- API danh sách follower/friends kèm phân trang, tìm kiếm, ID, avatar và quan hệ hiện hành.
- API danh sách bài theo `authorId`, danh sách địa điểm yêu thích, count đồng bộ, hồ sơ có bio/link/gender/avatar.
- Upload avatar, cập nhật bio/link/gender/nickname/fullName với validation nhất quán.
- API block user bằng userId (không phụ thuộc chat tồn tại), report nếu nghiệp vụ yêu cầu lưu server.
- Persist trạng thái mute Moments và luồng unmute; làm mới mọi màn liên quan sau mutation.

---

## 2. Bài viết dùng chung (Home / Profile / Search / Place Detail / Notification)

### 2.1. Quy tắc feed khi chạm vào lưới bài viết

- Dùng **một giao diện xem bài viết** `GoMateProfilePostFeedScreen` để tránh khác tỷ lệ giữa các nguồn. Tỷ lệ ảnh, avatar, caption, tương tác giữ gần chuẩn Home.
- Khi có danh sách `1,2,3,4`, chạm bài `2` → hiển thị `2 → 1 → 3 → 4`; chạm bài `4` → `4 → 1 → 2 → 3`. **Không lặp lại bài được chọn**. Đây là hoán vị đưa bài được chọn lên đầu, rồi giữ thứ tự gốc của phần còn lại; không phải carousel vòng vô hạn.
- Khi từ **thông báo bài viết**, mở đúng **một bài duy nhất** liên quan đến thông báo (`[post]`), không nối thêm 3 bài minh họa.
- Ảnh nhiều tấm trong cùng post: cuộn ngang; giữa các post: cuộn dọc. Back trở về nơi đã mở (Profile/Search/Place/Notification).
- Like/double-tap, Comment, Share, Save phải đúng UI quy ước từ Home. `CommentSheetContent`, `SharePostContent`, `GoMateBottomSheet` dùng lại thay vì tạo bản tương tự.

### 2.2. Nguồn dữ liệu và giới hạn hiện tại

- `ProfileUiPreview.posts(...)` sinh post mock của mình/khác; `GoMateProfilePostPreview` là model UI, không chứng minh backend đã có owned post API.
- `GoMateProfilePostFeedScreen` bản V4 tạo `DemoPostInteractionRepository`, like/save local, comment/share chỉ thử tương tác. **Phải đổi sang post repository thật** và trạng thái server.
- `SearchPostItem` ở bản đối chiếu chưa có đủ tác giả, media album, like/comment IDs. `_openPostFeed`/`_openSearchPost` có adapter từ Search sang preview model với ID `ui-preview-search-post-*`; đổi khi API hoàn thiện.
- `place_detail_screen.dart` `_buildRelatedPosts()` đang tạo các ảnh và `ui-preview-related-*`, caption/author mock. Khi có endpoint posts-by-place, lấy ID media/tác giả thật, vẫn giữ `InkWell` cùng feed.
- `search_widgets.dart` có `searchPostPreviewImage()` fallback asset cho các đường dẫn `assets/images/home/post_*.jpg` không có thật trong source snapshot. **Bỏ nhánh fallback demo** sau khi backend trả ảnh hợp lệ; giữ logic hiển thị ảnh lỗi nếu cần.
- `place_detail_screen.dart` còn `_buildDemoReviews()` / `DemoPostInteractionRepository` trong phần đánh giá/chia sẻ địa điểm. Đó là demo **riêng của Place Detail**, cũng cần audit khi backend hoàn tất. Không xóa cả trang chi tiết hoặc Map UI.

### 2.3. Backend và định tuyến

- ID post thật, ownerId, media URLs, placeId, caption, hashtags, privacy, counts, like/save state, tập bình luận và share targets.
- Đảm bảo quyền xem bài đối với tài khoản private, bài đã xóa/ẩn và thông báo mention; trả 403/404 thích hợp.
- Notification đến một post luôn dùng `postId` thật, fetch đúng post, feed một bài; không tự suy từ thumbnail.

---

## 3. Khoảnh khắc (Moments)

- Moments tại Home: chỉ hiển thị bạn bè **theo dõi hai chiều**, vòng xanh nếu có story khả dụng, khoảng cách trắng giữa avatar và vòng; story bạn bè có thời hạn **24 giờ** và đã xem thì không phát lại theo nghiệp vụ đã chốt.
- Khoảnh khắc của mình: vẫn lưu ở thư viện cá nhân theo chính sách sản phẩm; xóa vĩnh viễn, phản hồi và thả cảm xúc theo luồng đã định. Tin nhắn trả lời Moment xuất hiện trong chat.
- Avatar Profile: chạm để mở luồng Moment tương ứng nếu có; không ghi đè nút cộng ở header Profile.
- Ẩn/Hiện: chỉ có option trên menu profile **khi là bạn bè**. `Ẩn` làm story của người đó biến mất khỏi nguồn nhìn thấy; **bỏ ẩn** phải khôi phục khả năng thấy Moment còn hạn sau khi gọi server thành công, không phát lại cái đã xem/hết hạn.
- `moment_viewer_screen.dart` và `my_moment_detail_screen.dart` là màn xem/chỉnh chi tiết đang có. `DemoMomentsRepository` dùng cho QA thông báo reaction và dữ liệu demo viewer.
- Notification `momentReaction` phải dẫn đến **đúng Moment của chính mình** bằng `momentId`; bản Notification V1 hiện chọn `DemoMomentsRepository.instance.myMoments.first` → **phải thay**, không mở nhầm Moment.
- Backend cần xuất trạng thái mute kể cả khi người đó đã bị ẩn khỏi `stripItems`; bổ sung `unmuteUser` trong Flutter repository bằng API hiện hành, phản ánh các thiết bị khác.

---

## 4. Messages, bạn bè, nhóm và tác vụ liên quan

- Main tab Messages là nơi hiển thị direct/group chats, unread, requests; các màn cần thiết dùng `MessageChatScreen`, `MessageRepository`, `MessageDetailScreen` hiện có. Badge unread tối đa “5+” theo thiết kế cũ.
- Nhấn **Nhắn tin** ở profile, follow notification hoặc incoming message → **đúng** direct conversation của sender; trong QA có thể dùng DemoMessageRepository, production phải phân giải conversationId/senderId thật.
- Nhóm chỉ có Leader và Member; Leader không tự rời mà phải xử lý delete group/trip theo nghiệp vụ, Member có thể rời nếu cho phép. Group chỉ được tạo khi có lịch trình hợp lệ; không đưa trở lại phó nhóm.
- Khi xem thành viên nhóm, chọn một người sẽ có **hai lựa chọn**: **Xem trang cá nhân** / **Xem vị trí**. Xem vị trí cần có quyền chia sẻ và tọa độ đáng tin cậy, không đánh dấu marker giả.
- Share post chọn đa người/nhóm, có trường tin nhắn, trạng thái selection, thanh search; giữ component share cũ.
- Các `DemoMessageRepository`, `DemoPostInteractionRepository` nếu còn được màn production sử dụng thì phải thay dependency injection sang repository thật, **không xóa class global trước khi thay hết call-site** (một số màn QA khác còn dùng).

---

## 5. Địa điểm, Maps và Lịch trình

### 5.1. Place Detail / Favorites

- Nút thêm lịch trình ở chi tiết địa điểm mở picker danh sách trip và luồng chọn ngày/giờ từ Map; không đổi logic backend hiện có.
- Tab tim Profile hiển thị các địa điểm đã lưu; dùng `FavoritePlaceStore` hiện tại chỉ phục vụ UI tạm thời. Backend cần favorite folders, save/remove, persistence, đồng bộ giữa Detail và Profile.
- Bài viết liên quan có thể bấm, dùng một feed chung; đánh giá địa điểm là domain khác bài viết và cần API riêng nếu hệ thống triển khai.
- Giữ nguyên lớp map style, Mapbox custom color, marker, route, GPS và các controller ngoài phạm vi. **Không làm mất màu Maps đã chốt** khi merge.

### 5.2. Map → tab Lịch trình → tạo mới

- Khi Maps mở danh sách chọn lịch trình nhưng **chưa có lịch trình**, nhấn icon tạo: **đóng picker → chuyển sang tab Lịch trình (index 3) → tự mở luồng tạo lịch trình sẵn có**.
- Giữ `TripScreen._createTrip()` xử lý tạo/lưu/đồng bộ; không push `CreateTripScreen` trực tiếp từ Map vì sẽ bỏ qua cập nhật state/trip list.
- Nếu đã có lịch trình, luồng chọn bình thường, không tự tạo. Bản vá UI đã dùng `GoMateMapUiSession.requestedCreateTrip`, hàm request/clear, listener tại TripScreen. Giữ notifier UI-only nếu còn phù hợp khi refactor.

### 5.3. Ghim lịch trình & GPS

- **Bắt buộc cấp phép vị trí “Luôn luôn”/background** để ghim một lịch trình. Đã cấp thì không hỏi lại; chưa cấp thì hỏi; từ chối → **không ghim**, không ghi trạng thái active giả.
- Logic định vị/GPS trên máy và duyệt GPS thuộc trách nhiệm các tầng thực, không thao túng trạng thái bằng UI demo.
- Khi ghim lịch trình nhóm: bắt đầu chuyến đi, hệ thống theo dõi/check-in đến từng stop theo GPS được cho phép; thành viên được xác nhận đã tới → sinh thông báo `memberArrived` cho người có quyền.
- Notification `memberArrived` → tab Maps, chọn đúng trip/day, **focus vị trí thành viên vừa tới** (cần memberId và tọa độ hoặc bản ghi vị trí mới nhất, có kiểm tra quyền/độ tin cậy).
- Thông báo sắp đến địa điểm `upcomingPlace` được tạo **hai lần trước giờ đã đặt**: trước **60 phút** và **30 phút**. Chạm → Maps hiển thị trip và lộ trình theo ngày đã định. Backend phải xử lý timezone, cập nhật khi sửa stop/giờ, lịch nhắc và chống gửi trùng.
- `GoMateMapUiSession.requestOpenTripOnMap()` đã có UI route contract. Bản demo Notification dùng `_previewTrip`, **chưa có focus GPS member thật**; không dùng mock GPS để cho rằng đã hoàn tất.

### 5.4. Invitation nhóm/lịch trình

- Người nhận lời mời có notification `tripInvitation`, trạng thái `PENDING` trước khi chấp nhận. Chỉ sau server xác nhận ACCEPTED mới trở thành thành viên và mở được Trip Detail tương ứng.
- Khi có thông báo **người khác đã chấp nhận lời mời của mình** (`tripInvitationAccepted`), chạm có thể mở chi tiết lịch trình của mình (kiểm tra quyền/trip còn tồn tại).
- Lời mời pending không được mở Trip Detail dù chạm row, action chữ xanh hay popup; action xanh **Chấp nhận** ở trang Thông báo mới là hành động duyệt thực sự. Với server cần thêm Từ chối/Hủy lời mời nếu nghiệp vụ mở rộng (không tự đưa nút vào UI đã chốt).

---

## 6. THÔNG BÁO — CHỐT ĐẦY ĐỦ HÀNH VI

### 6.1. Cấu trúc màn hình

- Header quay lại đồng bộ GoMate, title như ảnh thiết kế. Danh sách theo **7 ngày qua**, **30 ngày qua**, **Cũ hơn** (khi có backend phải tính từ `occurredAt` thay vì cờ `period` hardcode).
- Trang Private có khu tổng hợp **Yêu cầu theo dõi** phía trên nhóm thời gian. Trang Public không có yêu cầu duyệt, chỉ có “đã bắt đầu theo dõi bạn”.
- Một hàng thông báo có avatar người gửi hoặc thumbnail địa điểm/bài, nội dung actor đậm, thời gian xám, nhãn hành động xanh **chỉ khi cần**. Chạm hàng đi tới đúng thực thể.
- Màn yêu cầu theo dõi riêng: danh sách người yêu cầu và `Xác nhận`, sau duyệt hiển thị `Theo dõi lại` nếu chưa mutual; nếu follow public → `Nhắn tin`, nếu họ private → `Chờ xác nhận` cho tới khi họ duyệt. Nhấn hàng mở đúng profile của sender.
- Empty/loading/error, unread state, phân trang phải có nguồn thật khi backend triển khai.

### 6.2. Bảng sự kiện → đích

| Loại sự kiện | Bấm cả hàng / popup | Action xanh **trên trang danh sách** | ID backend phải có |
|---|---|---|---|
| `followRequest` | Profile người đã yêu cầu | `Xác nhận` (nếu pending) | notificationId, requestId, actorId |
| `followAccepted` | Profile người đã chấp nhận | `Nhắn tin` khi mutual; có thể `Theo dõi lại` theo trạng thái thực | actorId, relation |
| `startedFollowing` | Profile người bắt đầu follow mình | `Theo dõi lại` / `Chờ xác nhận` / `Nhắn tin` | actorId, relation, privacy |
| `postLiked` | **Một** bài liên quan | Không cần | postId, actorId |
| `postCommented` | **Một** bài liên quan (có thể focus comment) | Không cần | postId, commentId |
| `postMentioned` | **Một** bài bị nhắc, gồm cả post của người khác | Không cần | postId, commentId, mentionId |
| `recommendedPlace` | Chi tiết **một địa điểm** | Không cần | placeId |
| `momentReaction` | Chi tiết **Moment của mình** | Không cần | momentId, actorId |
| `tripInvitation` PENDING | **Trang Thông báo, lời mời lên đầu**, tuyệt đối không Trip Detail | `Chấp nhận` tại inbox | notificationId, invitationId, tripId |
| `tripInvitation` ACCEPTED | Chi tiết đúng lịch trình | Không còn `Chấp nhận` | invitationId, tripId |
| `tripInvitationAccepted` | Chi tiết lịch trình người dùng đã mời | Không cần | tripId, actorId |
| `newMessage` | Chat với đúng sender / conversation | `Xem tin nhắn` trên inbox | conversationId, senderId, messageId |
| `memberArrived` | Maps, trip/day và focus member | `Xem vị trí` | tripId, tripStopId, memberId, lat/lon |
| `upcomingPlace` | Maps, trip/day route mở | `Xem lộ trình` | tripId, tripStopId, day, leadMinutes |

### 6.3. **QUY TẮC ĐẶC BIỆT — POPUP ĐƯỢC MỜI THAM GIA LỊCH TRÌNH CHƯA XÁC NHẬN**

> Đây là ngoại lệ điều hướng **bắt buộc**, áp dụng cho popup realtime trên **bất kỳ màn nào** trong ứng dụng. Đã sửa ở gói đi kèm tài liệu, cần giữ nguyên khi backend được nối.

1. Backend phát `tripInvitation` với `invitation.status = PENDING`, `notificationId` và `invitationId` thật. Trạng thái `PENDING` lấy từ server (không lấy từ text “Chấp nhận”).
2. Overlay `GoMateNotificationPopup` xuất hiện **ở đầu màn**, non-modal, không che tối, không có chữ/nút `Chấp nhận` xanh ở phía phải; toàn bộ popup là một vùng chạm.
3. **Chưa nhấn popup:** không tự chuyển màn, **không tự thay thứ tự inbox**, không chấp nhận lời mời. Đây là lỗi đã từng có ở Notification V1: chọn popup thử đã gây spotlight trước khi bấm popup; bản fix loại bỏ.
4. **KHI NHẤN POPUP mà lời mời vẫn PENDING:** **không mở trang chi tiết lịch trình**, **không auto-accept**, **đi tới trang Thông báo**. Nếu người dùng đang đứng ở Thông báo (trường hợp nút test popup) thì ở lại trang đó và focus danh sách; nếu đang đứng tại màn khác thì `Navigator.push` sang `GoMateNotificationScreen(focusPendingInvitationId: notificationId)` / helper `GoMateNotificationScreen.openPendingInvitation(context, notificationId: ...)`.
5. Ngay sau khi mở/focus trang Thông báo, **đưa CHÍNH THÔNG BÁO MỜI NÀY lên vị trí SỐ 1 TRONG DANH SÁCH**, **trước** khu Yêu cầu theo dõi Private và **trước** cả ba nhóm ngày. Cuộn danh sách tới đầu, làm nổi nhẹ lời mời, cho thấy nút chữ xanh **`Chấp nhận`** ở cuối hàng. Lời mời chỉ xuất hiện **một lần**, không có bản trùng ở nhóm 30 ngày.
6. **Bấm nội dung cả hàng** khi pending → tiếp tục đứng trên danh sách và focus lời mời, **không mở Trip Detail**. **Bấm `Chấp nhận` trong HÀNG trên trang Thông báo** mới gọi accept API (bản QA đang đổi local). Chỉ khi server trả về thành công/ACK xác thực mới chuyển status `ACCEPTED`, xóa khỏi vùng ưu tiên; thông báo quay về nhóm ngày bình thường.
7. Sau khi accept, bấm hàng lời mời đã chấp nhận → `TripDetailScreen` của **đúng tripId**. Nếu accept lỗi/reject/hết hạn/bị rút lại, không ghi accepted giả; giữ/refresh trạng thái và thông báo lỗi thích hợp, không mở trip.
8. Nếu popup cũ được nhấn khi lời mời đã được xử lý ở một thiết bị khác: fetch trạng thái server, nếu `ACCEPTED` có thể mở trip theo quyền; nếu `REVOKED/EXPIRED/REJECTED/NOT_FOUND` thì mở inbox/empty state thích hợp; **không dựng notification giả để có nút Chấp nhận**.
9. Không dùng `tripId` để làm khóa `spotlight`: khóa duy nhất là `notificationId` (có thể có nhiều loại sự kiện liên quan cùng trip). Mutation accept lấy `invitationId`; phân giải trip dùng `tripId`. Không trộn ba ID.
10. Nếu nhiều lời mời pending: chạm popup của lời mời A thì A được pin số 1; chạm lời mời B thì B được pin số 1, A trở về nhóm thời gian. Hai thông báo không nhân bản.
11. Sau khi hoàn thành backend: **GIỮ nguyên** `GoMateNotificationPopup` không action xanh; **GIỮ nguyên** cơ chế inbox pin/focus; **THAY** `_demo.spotlight`, `_demo.acceptedTripIds`, `_demo.acceptTrip` bằng store và trạng thái server. Không xoá cơ chế ưu tiên lời mời cùng với demo provider.

#### Sơ đồ trạng thái bắt buộc

```text
[TRIP_INVITATION: PENDING]
    |
    | Popup xuất hiện (KHÔNG đổi route/thứ tự khi chưa bấm)
    v
[Người dùng bấm popup]
    |
    v
[Trang THÔNG BÁO: lời mời pin #1, nút Chấp nhận]
    |                                     |
    | Bấm hàng -> vẫn ở inbox            | Bấm Chấp nhận
    |                                     v
    |                           [Server xác nhận invitationId]
    |                            | thành công       | thất bại
    |                            v                  v
    |                       [ACCEPTED]       [Giữ/Pull trạng thái]
    |                            |
    |                            v
    +--------------------> [Bấm hàng đã ACCEPTED]
                                 |
                                 v
                        [TripDetailScreen(tripId thật)]
```

### 6.4. Popup realtime chung

- Popup **không** chứa các chữ hành động như `Xác nhận`, `Nhắn tin`, `Xem vị trí`; click cả popup đi theo bảng 6.2, **ngoại lệ pending trip như 6.3**.
- Một popup tại một thời điểm; cái mới thay cái cũ; tự ẩn sau thời gian UI config; overlay không blocking. Không dùng `GoMateSnackBar` cho popup nhận sự kiện chính thức.
- Event realtime ngoài inbox phải dùng navigation service/router để dẫn đến đúng màn; nếu app đang ở inbox thì focus tại chỗ, tránh push trùng nhiều NotificationScreen.
- Tách dữ liệu realtime khỏi UI: một nơi nhận WebSocket/SSE/push, một state store cho inbox, một router theo event. Không subscribe event lặp trong từng màn hình.

### 6.5. Backend scheduler/GPS/read state

- Nhắc trước 60/30 phút theo `scheduledAt`, `timezone`, `scheduleRevision`, `tripStopId`. Có khóa chống trùng `(recipientId, tripId, tripStopId, scheduleRevision, leadMinutes)` và hủy lịch cũ khi sửa giờ/stop/trip.
- GPS arrival phải được backend xác minh theo cấu hình vùng điểm đến, chống spoof/duplicate, quyền location của member, pin trip còn hiệu lực. Notification arrival có memberId/lat/lon hoặc đường dẫn lookup vị trí mới nhất.
- Notifications có danh sách phân trang, read/unread, badge, thời gian thật, bảo mật đối tượng được xem, xử lý target đã bị xóa/không còn quyền; đồng bộ đa thiết bị.
- Lời mời pending và follow request có status độc lập với notification read status; **đọc thông báo không đồng nghĩa accept**.

---

## 7. CHECKLIST XOÁ/THAY DEMO SAU KHI BACKEND HOÀN THÀNH

> Không xóa hàng loạt bằng `rm -rf` hoặc tìm chữ `Demo` rồi xóa. **Thứ tự: bổ sung repository thật → nối state/route → kiểm thử → xoá dữ liệu mẫu → xoá import/call-site → chạy analyze**. Nếu một DemoRepository vẫn dùng ở màn QA khác, chỉ bỏ import/call-site của màn production, không xóa định nghĩa chung ngay.

### 7.1. Các file mock có thể xoá NGUYÊN FILE **sau khi thay hết call-site**

| Độ ưu tiên | File | Xoá khi nào | Thay bằng |
|---|---|---|---|
| **P0** | `lib/features/notifications/ui_preview/notification_ui_demo.dart` | Có Notifications API/realtime, follow request, invitation thật và inbox store. | NotificationRepository/State thật: `notifications`, `pendingInvitations`, `read`, `accept`, relation. |
| **P0** | `lib/features/profile/ui_preview/profile_ui_preview.dart` | Có profile privacy/follow relations, owned posts, follower/friends, favorites thật. | Mapper/profile+post+favorites repository thật. |
| **P2 nếu vẫn còn** | `lib/features/profile/screens/profile_people_screen.dart` **các const/rows demo V2 cũ** | Khi API follower/friends chạy thật. | Xoá **nhánh sample**, **KHÔNG xoá screen**. Tìm `kGoMateProfileDemoPeople`, `_demoFollowers`, `_demoFriends` nếu local chưa nâng lên V4. |

### 7.2. File giữ lại UI, nhưng phải xoá/thay các nhánh giả lập

| File/đối tượng | Mã/vị trí tìm kiếm | Bắt buộc thay sau backend | Cần giữ |
|---|---|---|---|
| `lib/features/notifications/screens/notification_screen.dart` | `NotificationUiDemo`, `_demo.feed`, `_showDemoTools`, `_buildTestingControls`, `_chooseRealtime`, `privateAccount`, `acceptedFollowIds`, `requestedFollowIds`, `mutualFollowIds`, `acceptedTripIds`, `_previewTrip`, `_openPost`, `_openPlace`, `_openOwnMoment`, `_openMessage`, `_openMapTrip` | Bỏ tools/nút Private–Public/Test popup, sample profile/place/post/trip/chat/Moment, local accept/follow/read; dùng item IDs thật & API. | Row layout, grouping, header, follow-requests screen, **pending-invite pin/focus và route helper**. |
| `lib/core/widgets/gomate_notification_popup.dart` | `GoMateNotificationPopup.show` | Chuyển caller từ nút demo sang global event listener; không tự sửa shell để nhét nút xanh. | **Giữ file** và popup duy nhất. |
| `lib/features/notifications/models/gomate_notification.dart` | `GoMateNotificationItem`, `GoMateNotificationPeriod`, `GoMateNotificationAction` | Map JSON thật, kiểm tra ID/status, tính period từ timestamp; bỏ enum/field không còn dùng. | **Giữ model** hoặc refactor tương thích. |
| `lib/features/profile/screens/profile_screen.dart` | `ProfileUiPreview`, `_posts`/`_visiblePosts` fallback, `_favorites` fallback, demo profile navigation, count sample. | Load posts-by-owner, favorite-by-user, counts thật, bỏ nút **“Xem thử hồ sơ người khác · Demo UI”** và fallback. | Layout header/avatar/bio/tabs. |
| `lib/features/profile/screens/public_profile_screen.dart` | `previewPerson`, `_previewMuted`, `_previewBlocked`, `ProfileUiPreview.findPerson`, `isPreviewId`, `_locallyMutedRealUser`, chặn/follow cục bộ. | Mở profile theo userId thật; quyền private từ server; follow/mute/block theo state thật; bỏ các Snackbar “(demo)”. | Giao diện hai trạng thái public/private, menu đúng quan hệ, confirm unfollow private. |
| `lib/features/profile/screens/profile_people_screen.dart` | `usePreviewPeople`, `_preview`, `ProfileUiPreview.followerRows`, `friendRows`, local follow toggle. | Dùng list API thật, pagination, mutation theo userId. | Tab, search, rows, empty state. |
| `lib/features/profile/screens/profile_post_feed_screen.dart` | `DemoPostInteractionRepository`, `_likedPostIds`, `_savedPostIds`, `ProfileUiPreview.findPerson`, preview author. | API post/likes/saves/comments/share + ownerId/media; persist trạng thái và kiểm tra quyền. | Full-width feed UI, scroll order, comment/share sheets. |
| `lib/features/profile/screens/profile_edit_screen.dart` | `_genderPreview`, `_linkPreview`, local avatar image preview (`ImagePicker`), limit validation. | Persist link/gender/avatar; cập nhật profile/refetch; thống nhất 50 ký tự nickname với backend. | Editor, camera badge, màu/style, trailing chevron cố định. |
| `lib/features/search/widgets/search_widgets.dart` | `searchPostPreviewImage`, `assets/images/home/post_*.jpg` fallback | Khi data Search chứa media URL thật thì bỏ fallback mock. | `SearchPostGrid(onTapIndex:)`, UI search. |
| `lib/features/search/screens/search_screen.dart` | `_openPostFeed`/`_openSearchPost`, `'ui-preview-search-post-'`, `authorId: ''` | Chuyển SearchPostItem thành post thật có ownerId/media/IDs; xử lý private. | Cả 2 callback preview và tab Posts. |
| `lib/features/map/screens/place_detail_screen.dart` | `_buildRelatedPosts`, `postImages`, `'ui-preview-related-'`, `_buildDemoReviews`, `_shareRepository = DemoPostInteractionRepository()` | Backend posts-by-place, review data, favorites, share; xoá mock từng phần. | Map/place hero, header, route/add-to-trip, ảnh related grid, InkWell. |
| `lib/features/map/state/map_ui_session.dart` và `lib/features/trip/screens/trip_screen.dart` | `requestedCreateTrip` và `requestOpenTripOnMap`, các state UI-only | Chỉ refactor notifier nếu app có navigator/state contract mới; **không tự xoá** khi nối backend. | Intent điều hướng Maps → Trip/Create, trip/day focus. |
| `lib/features/messages/screens/*`, `lib/features/home/screens/home_screen.dart`, `lib/features/moments/*` | `DemoMessageRepository`, `DemoMomentsRepository`, `DemoPostInteractionRepository`, sample post/contacts/moments. | Thay default demo bằng real repository ở production và giữ sample chỉ trong test fixtures. | UI tin nhắn, khoảnh khắc, nút chuông Home, content sheets. |
| `lib/features/profile/widgets/profile_ui_widgets.dart`, `lib/core/widgets/gomate_name_editor_content.dart` | Các component/profile preview model | Chỉ đổi model adapter nếu API yêu cầu. | **Giữ component UI**, không xoá vì tên trông giống demo. |

### 7.3. Các cờ/mẫu ID phải tìm trên TOÀN `lib/`

```text
ProfileUiPreview.enabled
NotificationUiDemo.enabled
kGoMateProfileDemoPeople       # chỉ nếu còn bản V2 cũ
TODO(BACKEND-PROFILE-UI-PREVIEW)
TODO(BACKEND-PROFILE-MOMENTS)
TODO(BACKEND-NOTIFICATIONS)
ui-preview-
demo-follow-
demo-trip-
demo-message
DemoMomentsRepository
DemoMessageRepository
DemoPostInteractionRepository
_profilePreview / previewPerson
acceptedTripIds / spotlightNotificationId
_genderPreview / _linkPreview
```

Kiểm tra dùng VS Code global Search (`Ctrl+Shift+F`) hoặc PowerShell `Select-String`/`git grep`; **chỉ xoá sau khi đã kiểm tra tất cả call-site**, đặc biệt các notification sample đang phụ thuộc ProfilePreviewPerson và các fake trip/place IDs.

### 7.4. Checklist backend nhận triển khai — chia giai đoạn

**P0 — An toàn ID và điều hướng**

- [ ] Tất cả `postId`, `momentId`, `placeId`, `tripId`, `invitationId`, `conversationId`, `actorId`, `notificationId` là ID thật, không còn `ui-preview-*` trong request.
- [ ] Quyền Private và mutual friends được xác nhận bởi server, không dựng từ username/count hay một cờ local.
- [ ] `tripInvitation: PENDING` chạm popup → mở **inbox**, lời mời ưu tiên **#1**; không auto-accept/không TripDetail, không lặp hàng; khi accept server thành công mới mở được TripDetail.
- [ ] Có trạng thái `ACCEPTED/REJECTED/EXPIRED/REVOKED` và đối chiếu realtime từ server, phân biệt `notification.isRead` với `invitation.status`.
- [ ] Profile mute/unmute, block user, report có contract rõ ràng và quyền xác thực.

**P1 — Dữ liệu social và thông báo**

- [ ] Profile info và chỉnh sửa: avatar, gender, link, bio, nickname/fullName max length được thống nhất.
- [ ] Follower/friend list, follow request accept/cancel/follow back/search/pagination.
- [ ] Post feed, post owner, media, like/save/comment/share, search post, related-by-place, target post đơn từ notification.
- [ ] Notifications inbox list, grouping timestamp, mark-read/readAll, badge, realtime push, trigger event nhận tin nhắn/follow/moment/post/invite.
- [ ] Story 24h, viewed-once, mute/unmute, hide/show, replies vào chat; momentReaction tìm đúng momentId.
- [ ] Saved/favorite places persist, cập nhật từ Place Detail và Profile.

**P1 — GPS và Trip**

- [ ] Background GPS always permission trước khi pin; từ chối → pin không thành công.
- [ ] Arrival được xác minh theo member/location/stop, Map focus đúng member; permission/TTL/cải tiến GPS.
- [ ] Scheduler stop reminder đúng **T-60 và T-30** theo timezone và cập nhật khi lịch trình đổi; chống duplicate.
- [ ] Chấp nhận lời mời thay đổi membership/trip data thật; sau accept mới thấy trip detail.
- [ ] Nhóm chỉ Leader/Member (không code deputy).

**P2 — Dọn mock/QA**

- [ ] Bỏ `NotificationUiDemo` + nút thử Private/Public/popup và dữ liệu preview trên NotificationScreen.
- [ ] Bỏ `ProfileUiPreview` và mọi nơi khởi tạo mock user/post/place.
- [ ] Bỏ fallback asset post mock và local like/save/follow/accept; giữ component UI và navigation.
- [ ] Bỏ data demo còn sót ở Place Detail, Home, Message/Moments **sau khi đã thay call-site**.
- [ ] Kiểm tra `git grep 'ui-preview-\|TODO(BACKEND-\|Demo.*Repository' -- lib` và phân loại từng kết quả còn hợp lệ (fixtures/test) hay chưa.
- [ ] Chạy `git diff --check`, `dart format` những file thay, `flutter analyze`, `flutter test`, thiết bị kích thước khác nhau, test production server/staging.

---

## 8. Kịch bản QA bắt buộc trước bàn giao backend

| Case | Thao tác | Kết quả |
|---|---|---|
| N01 | Bật demo Private | Có yêu cầu theo dõi phía trên danh sách; bấm mở màn requests. |
| N02 | Xác nhận follow request rồi follow back trang public | Trạng thái → Theo dõi lại → Nhắn tin, quan hệ 2 chiều. |
| N03 | Follow back đối tượng Private | Trạng thái → Chờ xác nhận; không tự trở thành friend. |
| N04 | Chạm thông báo like/comment/mention | Chỉ một post, back về Notifications. |
| N05 | Chạm reaction Moment | Moment chính mình đúng ID (demo có thể chọn 1 mẫu; backend phải đúng ID). |
| N06 | Chạm đề xuất một địa điểm | Place Detail đúng ID. |
| **N07** | Mở popup trip pending nhưng **chưa bấm popup** | Không đổi màn, không reorder danh sách, không accept. |
| **N08** | Bấm popup trip pending **từ Home/Maps/địa điểm bất kỳ** | Chuyển Notifications; lời mời đó #1, trước Follow requests/date groups, nút Chấp nhận. |
| **N09** | Bấm popup trip pending **ngay trong Notification Screen demo** | Vẫn ở Notification Screen, lời mời được pin #1, không push duplicate. |
| **N10** | Bấm **nội dung hàng** pending | Vẫn ở Notifications, không Trip Detail. |
| **N11** | Bấm chữ xanh **Chấp nhận** trên inbox | Sau accept thành công: bỏ pin, còn đúng 1 bản hàng trong nhóm thời gian, bấm mới mở Trip Detail. |
| **N12** | Có 2 lời mời pending A/B, nhấn popup B rồi A | B/A lần lượt lên #1, không mất/nhân bản thông báo. |
| **N13** | Popup cũ của invitation expired/revoked | Không chấp nhận giả, không mở Trip Detail; refresh/empty state rõ. |
| N14 | Popup message mới | Không có chữ xanh; tap mở đúng conversationId. |
| N15 | Member arrived | Map trip/day đúng, focus member với GPS thật; nếu thiếu GPS hiện unavailable. |
| N16 | Scheduled reminder ở T-60, T-30 | Đủ hai sự kiện đúng trip/stop/day và timezone, không gửi duplicate. |
| P01 | Hồ sơ private chưa được duyệt → Followers/Friends | Popup yêu cầu được duyệt, không lộ danh sách. |
| P02 | Friend menu `⋮` | Báo cáo, Chặn, Ẩn/Bỏ ẩn Moments. Non-friend chỉ Báo cáo, Chặn. |
| P03 | Chạm bài số 4 trong 4 bài | Feed `4→1→2→3`, không lặp. |
| P04 | Search quick result/tab Post/Place-related posts | Đều nhấn được và vào feed chung; back đúng màn gốc. |
| M01 | Maps picker không có trip → icon tạo | Sang tab Lịch trình, mở Create Trip theo flow TripScreen. |
| M02 | Từ chối GPS Always/background khi pin | Không ghim, không sinh theo dõi vị trí giả. |

---

## 9. Hướng dẫn merge và thay backend an toàn

1. Chọn branch tích hợp; chốt code đang chạy và so sánh với `master`, vì `master` đối chiếu vẫn ở commit nền, trong khi các gói Profile/Notification là file bàn giao ngoài Git.
2. Chỉ bổ sung **các file Dart cần thiết** và source of truth từ repository thật; không paste React/Figma absolute layout.
3. Khi thay các fields từ mock sang API, viết adapter (`NotificationDto → GoMateNotificationItem`, `PostDto → GoMateProfilePostPreview`, `UserDto → SearchUserProfile`) và unit test theo bảng trạng thái ở trên; sau đó mới xoá demo fixture.
4. Với invitations: route resolver kiểm tra **status thật** và `notificationId/invitationId/tripId`, không dùng `acceptedTripIds` RAM; khi popup đang ở màn khác, route về Inbox với `focusPendingInvitationId` và pin lên đầu danh sách, hoàn toàn không gọi accept.
5. Kiểm thử race: một thiết bị nhận popup PENDING, thiết bị khác chấp nhận/hủy; thao tác đầu tiên phải fetch lại đúng trạng thái. Nếu đã accepted, không hiển thị nút accept sai.
6. Test quyền private, avatar navigation, post-only feed, comment/share, back, snackbar, overlay, Mapbox colors, GPS. Chỉ sau đó mới tắt/xóa toàn bộ preview.
7. **Không xoá giữ nguyên UI contract:** `GoMateMainTabHeader`, `GoMateBottomSheet`, `GoMateSnackBar`, `GoMateNotificationPopup`, `GoMateProfilePostFeedScreen`, `GoMateProfilePageHeader`, `SearchPostGrid`, `GoMateMapUiSession` (hoặc phiên bản refactor tương đương), `TripDetailScreen` và `PlaceDetailScreen`.

### 9.1. Danh sách tài liệu/gói liên quan

- Profile UI V1 → V2 → V3 (mock) → V4 (feed/menu/Map), sau đó gói sửa `public_profile_screen.dart` + `profile_ui_preview.dart` cho Ẩn/Bỏ ẩn Khoảnh khắc.
- Bộ ba file Search + Place Detail để nhấn vào bài viết.
- Notifications V1 (4 file Dart + docs); **bản sửa pending-invite popup đính kèm tài liệu này** thay `notification_screen.dart` và `notification_ui_demo.dart` V1.
- `docs/BACKEND_HANDOFF_NOTIFICATIONS.md` trong Notifications V1 có mô tả API/scheduler ban đầu; **quy tắc ở mục 6.3 của tài liệu này là bản chốt ưu tiên** nếu có điểm diễn đạt khác.

**Kết luận triển khai:** Giữ UI dùng chung, dùng ID/trạng thái từ backend làm nguồn sự thật, loại demo theo danh sách đường dẫn ở mục 7. Riêng pending invitation popup, nguyên tắc bắt buộc là **popup → trang Thông báo → lời mời số 1 → chấp nhận trên inbox → rồi mới được mở Trip Detail**. Không có đường tắt bỏ qua bước xác nhận.
