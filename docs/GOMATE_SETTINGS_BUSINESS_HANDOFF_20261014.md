# GOMATE — TỔNG HỢP NGHIỆP VỤ CÀI ĐẶT, HỢP ĐỒNG DỮ LIỆU VÀ CHECKLIST XÓA DEMO

**Phạm vi:** Toàn bộ cụm **Cài đặt và hoạt động** từ bản thiết kế Settings V1 → Settings V2 → các yêu cầu điều chỉnh tiếp theo (đến 14/10/2026).  
**Mục đích:** Tài liệu thống nhất giữa Flutter UI/UX, backend, tích hợp mobile và QA; dùng để hoàn thiện tính năng mà **không thiết kế lại giao diện** và **không xóa nhầm code thật**.  
**Nguồn đối chiếu:** Yêu cầu/ảnh của chủ đề GoMate trong cuộc trao đổi; gói `GoMate_Settings_UIUX_V1.zip`, `GoMate_Settings_UIUX_V2.zip`; hai tài liệu `BACKEND_HANDOFF_SETTINGS.md`, `BACKEND_HANDOFF_V2.md` và hướng dẫn V2. Branch `xuanthu` commit `dce3a2f...` được đối chiếu làm mốc **trước Settings V1**; source local của người phát triển có thể mới hơn và là nơi quyết định khi tích hợp.

> **QUAN TRỌNG VỀ TRẠNG THÁI:** Đây là **nghiệp vụ đã chốt và yêu cầu tích hợp**, không có nghĩa là backend đã hỗ trợ mọi chức năng. Một số liên kết tới màn thật đã tồn tại (ví dụ `AuthService.logout`, `PublicProfileScreen`, `MyMomentsScreen`, `PlaceDetailScreen`), nhưng **danh sách hoạt động, privacy, chặn/ẩn, lịch sử, thời gian, quyền hệ điều hành đang có phần DEMO**. Các chỉnh sửa **sau khi xuất ZIP V2** (lọc 30 ngày mặc định, màu toggle tắt, bỏ chữ “Mẫu:”, thu nhỏ tiêu đề Bài viết) là yêu cầu được bổ sung/sửa thủ công, cần kiểm tra trên source local; không mặc định đã nằm trong ZIP V2 ban đầu.

---

## 0. Thuật ngữ và nguyên tắc chung

| Thuật ngữ | Ý nghĩa |
|---|---|
| **Settings** | Trang “Cài đặt và hoạt động”, nơi tìm kiếm và truy cập mục con. |
| **Activity** | “Hoạt động của bạn”: nội dung đã thích, bình luận, đánh giá, lưu, chặn, báo cáo, lịch sử, thống kê. |
| **PublicProfileScreen** | Màn hồ sơ **chung** khi xem người dùng khác; dùng cho cả bình thường/private/bị chặn và người đã ẩn Khoảnh khắc. |
| **Private** | Tài khoản riêng tư; yêu cầu theo dõi cần được chấp nhận; không có quyền không xem được phần bị bảo vệ. |
| **Bạn bè** | Quan hệ theo dõi **hai chiều**, không suy ra chỉ từ lượt theo dõi một chiều. |
| **Ẩn Khoảnh khắc (mute)** | Người dùng A ẩn Khoảnh khắc của B trong bảng tin của A; không tương đương block/unfollow. |
| **Chặn (block)** | Quan hệ chặn người dùng; ảnh hưởng tới quyền truy cập hồ sơ và liên hệ theo luật backend. |
| **Preview/demo** | Dữ liệu cục bộ để test giao diện; ID như `ui-preview-*`, `blocked-1` **không tồn tại trong DB**. |
| **Source of truth** | Backend hoặc adapter hệ điều hành chịu trách nhiệm lưu/xác minh trạng thái; không lấy dữ liệu demo làm chuẩn. |

**Các nguyên tắc bất biến:**

1. **Không phá logic đã có:** tích hợp thông qua repository/state/action; giữ các màn, widget, popup và màu GoMate. Không tạo thêm màn xem Profile/Place/Post/Moment trùng chức năng.
2. **Quyền xác minh ở server:** client được phép ẩn/hiện UI theo quyền nhưng backend vẫn phải xác thực user, ownership và đối tượng.
3. **Mọi list thuộc tài khoản đang đăng nhập:** không trả lịch sử, nội dung đã lưu, report, block, muted list của user khác.
4. **Không truyền ID demo vào API thật** và không hiện SnackBar “thành công” trước phản hồi backend.
5. **Tương tác chéo đồng bộ:** thao tác thích/lưu/xóa/chặn/ẩn từ Settings phải được phản ánh ở Home, feed, hồ sơ, Khoảnh khắc, Maps, Messages và ngược lại.
6. **Responsive:** không copy các kích thước artboard/absolute layout từ Figma. Header các màn phụ dùng cỡ chữ nhỏ hơn tab chính. Chữ xám giá trị + dấu `>` giữ cùng lề phải trên mọi hàng Settings.

---

## 1. Cấu trúc trang Cài đặt chính

### 1.1. Danh mục đã chốt

**Header:** “Cài đặt và hoạt động”, mũi tên Back theo pattern màn phụ.  
**Tìm kiếm:** nhập từ khóa để lọc **cả mục cấp 1 và các mục nằm sâu trong “Hoạt động của bạn”**. Chạm kết quả mở thẳng màn con, không bắt buộc đi qua trang Activity.

| Nhóm | Mục con | Màn đích / chức năng |
|---|---|---|
| Tài khoản | Chỉnh sửa hồ sơ | `ProfileEditScreen` đang dùng từ Profile |
| Tài khoản | Hoạt động của bạn | `SettingsActivityScreen` |
| Bảo mật | Quyền riêng tư | `SettingsOptionsScreen(privacy)` |
| Bảo mật | Đổi mật khẩu | `ForgotPasswordScreen(changePasswordMode: true)` |
| Tùy chọn | Ngôn ngữ giao diện | Trang lựa chọn ngôn ngữ, chưa áp dụng locale thật |
| Tùy chọn | Chế độ tối | Toggle; hiện chưa đổi Theme toàn app |
| Tùy chọn | Quyền truy cập thiết bị | Danh sách quyền Camera/Danh bạ/Vị trí/Micro/Thông báo/Ảnh |
| Hỗ trợ | Trợ giúp & Hỗ trợ | Chưa phát triển nghiệp vụ |
| Hỗ trợ | Điều khoản & chính sách | Chưa phát triển nghiệp vụ |
| Hỗ trợ | Giới thiệu GoMate | Chưa phát triển nghiệp vụ |
| Cuối trang | Đăng xuất | Giữ luồng `AuthService.instance.logout()` |

**Hiển thị thông tin tài khoản:** ảnh, tên hiển thị, email lấy từ `AuthService`/user profile. Không fake số liệu tài khoản.  
**Logout:** popup xác nhận → gọi service logout sẵn có → xóa stack điều hướng đến Login, không thể Back về nội dung đã đăng nhập. Khi lỗi phải giữ trạng thái đăng nhập và hiển thị thất bại.

### 1.2. Tìm kiếm mục cài đặt

- Có thể tìm theo tên section hoặc tên mục con; kết quả là **entrypoint màn thật**, không phải tìm dữ liệu người dùng.
- Gợi ý thiết kế tích hợp: danh sách route metadata ổn định ở Flutter, so khớp không phân biệt hoa/thường, có thể chuẩn hóa dấu tiếng Việt nếu quyết định hỗ trợ.
- **Không cần endpoint search Settings riêng** khi danh sách mục là cố định trong phiên bản ứng dụng.

---

## 2. “Hoạt động của bạn”: cấu trúc danh mục

| Nhóm | Các màn |
|---|---|
| **Lượt tương tác** | Lượt thích, Bình luận, Đánh giá, Đã lưu, **Thư viện Khoảnh khắc** |
| **Nội dung** | Đã chặn, Nội dung đã báo cáo, Khoảnh khắc đã ẩn |
| **Hoạt động** | Quản lý thời gian, Lịch sử xem, Tìm kiếm gần đây |

- **Thư viện Khoảnh khắc:** bắt buộc điều hướng đến **`MyMomentsScreen` hiện có**, dùng cùng `MomentsRepository`. Không tạo thư viện thứ hai trong Settings.
- Không dùng cùng khái niệm cho **“Địa điểm đã thích”** và **“Địa điểm yêu thích/đã lưu vào thư mục”** nếu backend định nghĩa chúng khác nhau. Cần thống nhất kiểu tương tác và API trước khi map dữ liệu.
- Mỗi list phải có: loading, empty, pagination/cursor, lỗi mạng, đối tượng đã xóa/mất quyền xem, làm mới sau mutation và UI chọn nhiều khi thích hợp.

---

## 3. Lượt thích — Địa điểm / Bài viết

**UI:** hai tab `Địa điểm` và `Bài viết`; chọn item mở màn chi tiết đúng loại. Có icon **Quản lý** hình `copy`: **xám khi tắt / đen khi bật**, nhấn lại hủy chọn; tick chọn một/nhiều, Chọn tất cả, nút gradient **Bỏ thích (n)**. Việc đổi tab bỏ vùng chọn cũ (không áp dụng chọn lẫn hai loại nếu chưa có quy tắc batch).

### 3.1. Nghiệp vụ

1. Lấy danh sách item user hiện tại đã thích, phân biệt `PLACE` và `POST`.
2. Chạm item khi không quản lý: PLACE → `PlaceDetailScreen`, POST → `GoMateProfilePostFeedScreen(posts: [post])` (chỉ bài được chọn).
3. Quản lý: các item tick chỉ được gửi thao tác **bỏ thích**, tuyệt đối không xóa bài viết hoặc địa điểm gốc.
4. Thành công: bỏ item ra list, đồng bộ `isLiked` ở Home/feed/Place Detail; khi thất bại: không giả kết quả thành công, hoàn nguyên nếu optimistic update.

### 3.2. Data contract gợi ý (chưa xác nhận API tồn tại)

- `likedItemId`/`targetId`, `targetType: POST|PLACE`, `likedAt`, `isLiked`.
- Với POST: `postId`, `authorId`, caption, preview media, quyền xem.
- Với PLACE: `placeId`, name, address, rating, cover media.
- Có phân trang; batch unlike nếu backend hỗ trợ, nếu không xử lý nhiều mutation với báo cáo thành công/thất bại theo item.

---

## 4. Bình luận — chỉ quản lý/xóa bình luận của chính mình

**Quy tắc đặc biệt đã chốt:** một entry gồm **hai tầng**:

- **Hàng trên:** bài viết gốc/caption hoặc **bình luận cha** mà người dùng đã trả lời; **chỉ hiển thị tham chiếu** và cho mở bài viết. **KHÔNG có hình tròn chọn, không bị xóa từ màn này.**
- **Hàng dưới:** bình luận do **chính tài khoản hiện tại** viết (kể cả reply); **chỉ hàng này có checkbox tròn và được xóa**.

**Quản lý:** icon `copy` **không đổi thành dấu X**, trạng thái xám/đen. Khi chọn nhiều, nút gradient `Gỡ bình luận (n)`; chỉ gửi danh sách `commentId` của user hiện tại. Xóa bình luận không xóa bài viết/bình luận cha, không xóa nội dung của người khác.

**Điều hướng:** chạm bài viết gốc hoặc mục bình luận ở chế độ xem → mở **một bài viết chính xác**, không mở cả dải feed; nếu cần tập trung vào comment/reply nên truyền thêm `commentId`/`parentCommentId` khi feed hỗ trợ.

**Contract dữ liệu đề xuất:**

```text
commentId; postId; ownerUserId; parentCommentId?;
body; createdAt; isReply;
postPreview{postId, caption, mediaThumbnail, authorId};
parentCommentPreview?{commentId, authorId, body};
canDelete; status (AVAILABLE/REMOVED/UNAVAILABLE).
```

**Xác thực server:** `DELETE comment/{id}` chỉ chấp nhận khi `comment.ownerUserId == currentUserId` hoặc một chính sách quản trị **riêng biệt**; màn “Hoạt động của bạn” không cấp quyền admin. UI không tin `canDelete` một cách tuyệt đối. Sau xóa đồng bộ thread/comment count nếu server trả dữ liệu mới.

---

## 5. Đánh giá địa điểm

- Chỉ hiển thị đánh giá do tài khoản hiện tại viết: `reviewId`, `placeId`, `rating`, caption/nội dung, ảnh, `createdAt`.
- Chạm card mở **`PlaceDetailScreen`** tương ứng; giữ mô hình đánh giá của Place Detail (không tự tạo một nguồn đánh giá thứ hai).
- Icon `copy` xám/đen, có tick chọn nhiều, **Xóa đánh giá (n)**; xóa review **không** xóa địa điểm.
- Backend cần xác minh ownership; cập nhật aggregate rating/reviewCount qua cơ chế hiện có (nếu backend tính aggregate).
- Nếu place bị xóa, trả trạng thái không khả dụng nhưng vẫn xử lý lịch sử review theo chính sách lưu dữ liệu đã được quyết định.

---

## 6. Bài viết Đã lưu

- Danh sách **chỉ POST được bookmark** của user hiện tại (khác với thích và lưu địa điểm vào thư mục).
- Chạm một ảnh → màn xem chi tiết bài viết **chỉ chứa bài đó**.
- Quản lý icon `copy` xám/đen, chọn nhiều / Chọn tất cả → **Bỏ lưu (n)**.
- Bỏ lưu chỉ xóa quan hệ `savedPost(userId,postId)`, **không xóa nội dung bài viết gốc**.
- Đồng bộ icon bookmark ở Home và Feed; quyền xem bài private đã hết hiệu lực thì không tiết lộ nội dung.

---

## 7. Người dùng Đã chặn

**Danh sách:** avatar, tên, thông tin phụ, hành động **Bỏ chặn**. Bỏ chặn thành công thì **xóa ngay người đó khỏi danh sách** và các nơi liên quan cập nhật trạng thái.

**Trang cá nhân của người bị chặn:**

1. Chạm tên/avatar từ Settings phải mở **`PublicProfileScreen` chuẩn**, không dùng `SettingsPreviewPersonScreen` hoặc layout Profile tự dựng.
2. Khi `isBlockedByMe=true`, màn Profile hiện trạng thái **“Bạn đã chặn người dùng này”**, che nội dung bị chặn, có nút **Bỏ chặn** (theo mẫu đã chốt).
3. **Dấu ba chấm** vẫn dùng **chính `GoMateBottomSheet`/menu ba chấm của Profile**, nhưng mục **Chặn** phải đổi thành **Bỏ chặn**. Các tùy chọn khác theo menu Profile đã thống nhất.
4. Bỏ chặn trong profile hoặc danh sách đều thực hiện **cùng một use-case**; khi Back về Settings người đó biến mất khỏi list.
5. Không mặc định khôi phục follow/friend hoặc chat khi unblock; backend quyết định chính sách quan hệ và cập nhật nhất quán.

**Contract đề xuất:** `blockedUserId`, `blockedAt`, profile summary, `isBlockedByMe`, trạng thái lỗi/truy cập. Chỉ user chặn mới được xem list riêng của họ.

**Cross-module:** Messages, Search, Home, Profile người khác, follow và thông báo phải tuân thủ cùng trạng thái block. Nếu thao tác chặn từ cuộc trò chuyện hiện cần `conversationId`, team backend/mobile cần một use-case **block theo userId** khi mở từ Settings/Profile (không gửi ID giả vào Chat API).

---

## 8. Nội dung Đã báo cáo

- **Chỉ xem lịch sử báo cáo đã gửi**, không phải danh sách để xóa các bài/người/địa điểm bị báo cáo.
- Mỗi item thể hiện **lý do**, loại nội dung và thumbnail/avatar nếu có; chạm item mở target theo loại: `PROFILE` → `PublicProfileScreen`, `POST` → feed đúng **một bài**, `PLACE` → `PlaceDetailScreen`; nếu có loại khác (comment/moment) cần contract/navigation tương ứng trong tương lai.
- Nếu báo cáo được ẩn danh, đối tượng bị xóa hoặc đã bị khóa do quyền riêng tư: hiển thị **không khả dụng**, không vượt qua các kiểm tra truy cập.
- Contract gợi ý: `reportId`, `targetType`, `targetId`, `reasonCode`/reasonText, `reportedAt`, `status`, target preview nếu còn quyền. Có phân trang.
- Không hiển thị thông tin xử lý kiểm duyệt nội bộ mà user không có quyền biết.

---

## 9. Khoảnh khắc Đã ẩn

**Chủ thể trong danh sách:** bạn bè mà chính user đã chọn **Ẩn Khoảnh khắc** từ menu hồ sơ hoặc luồng Moments.

1. Chạm dòng người dùng → **trang `PublicProfileScreen` bình thường** như mọi nơi khác, **không mở trang khoá/bị chặn** chỉ vì đã ẩn Moments.
2. Nếu hai chiều bạn bè: menu ba chấm có **Bỏ ẩn khoảnh khắc** thay cho **Ẩn khoảnh khắc** khi `isMomentMutedByMe=true`.
3. Bấm Bỏ ẩn trong list hoặc ở hồ sơ → xác nhận theo pattern GoMate → gửi mutation → **thành công mới xóa khỏi danh sách**; đồng bộ strip Moments và nút menu của hồ sơ.
4. **Chỉ bạn bè hai chiều mới có Khoảnh khắc tương tác với nhau**; không hiển thị hành động Ẩn cho người theo dõi một chiều theo nghiệp vụ đã chốt. Khi quan hệ thay đổi, backend quyết định trạng thái mute còn lưu hay không.
5. **Ẩn ≠ chặn ≠ bỏ theo dõi**.

**Cần tích hợp:** backend hiện có `POST /api/v1/moment-mutes/{userId}` và `DELETE /api/v1/moment-mutes/{userId}` ở mốc đối chiếu; Flutter `MomentsRepository` khi đó mới có `muteUser()`, **thiếu method `unmuteUser()` và nguồn danh sách đã ẩn**. Team tích hợp Flutter phải bổ sung abstraction/repository khi backend cung cấp contract; không tự bắn HTTP từ widget Settings.

---

## 10. Quản lý thời gian sử dụng

**UI:** màn chỉ xem, biểu đồ **7 ngày** theo phong cách xanh GoMate, hiển thị bình quân phút/ngày; không yêu cầu chế độ đặt giới hạn hoặc chế độ ngủ trong phạm vi Settings đã chốt.

- Dãy cột cùng đường cơ sở; nhãn `Hôm nay` có thể 2 dòng nhưng **không làm cột nhô lên hoặc lệch khung**. Không cố định frame theo ảnh Instagram.
- **Dữ liệu hiện là giả** (`values = [12,24,68,31,41,84,55]`, tiêu đề `42 phút` trong `settings_history_screen.dart` V2), tuyệt đối không được báo là thống kê thực tế.
- Cần quyết định đơn vị đo: **thời gian app ở foreground** (có thể dùng app lifecycle có xử lý pause/resume) hay Screen Time/UsageStats của hệ điều hành. Backend không tự truy cập Screen Time điện thoại.
- Nếu dùng Flutter app lifecycle: mobile ghi nhận thời lượng theo ngày/múi giờ; cân nhắc aggregate local/server và nhiều thiết bị. Nếu dùng OS analytics: kiểm tra quyền/giới hạn platform trước khi thiết kế endpoint.
- DTO báo cáo gợi ý: `timezone`, `periodStart`, `periodEnd`, `dailyMinutes[{localDate,minutes}]`, `averageMinutesPerDay`, `peakMinutes`; không tự suy ra thời gian từ số lần login.
- Không bật tracking nền trái quyền riêng tư; chỉ thu thập dữ liệu đúng phạm vi user chấp nhận.

---

## 11. Lịch sử xem: POST / PLACE, tối đa 30 ngày

**Hai tab:** `Địa điểm` và `Bài viết`; chọn item vào **đúng màn chi tiết**. Lưu hoạt động **đã xem** không đồng nghĩa **đã thích/đã lưu**.

### 11.1. Bộ lọc cuối cùng đã chốt (mới hơn Settings V2 ZIP)

Chỉ có **ba** lựa chọn:

| Lọc | Ngữ nghĩa đề nghị theo ngày lịch địa phương |
|---|---|
| **Ngày hôm qua** | Từ 00:00 ngày hôm qua tới trước 00:00 hôm nay |
| **1 tuần qua** | 7 ngày lịch, **bao gồm hôm nay** |
| **30 ngày qua** | 30 ngày lịch, **bao gồm hôm nay**, **MẶC ĐỊNH KHI MỞ** |

- Mốc V2 ZIP cũ chỉ có `yesterday` / `lastWeek`, mặc định `lastWeek`; **phải cập nhật thành `last30Days` mặc định** theo yêu cầu cuối.
- Phạm vi lọc UI **khác** thời hạn lưu trữ: dữ liệu quá **30 ngày** phải được dọn thật theo chính sách backend, không chỉ ẩn khỏi danh sách khi query.
- Sử dụng múi giờ user khi tính ngày lịch; trả `viewedAt` là UTC ISO 8601, diễn giải theo timezone ở truy vấn/UI. Quy tắc cutoff khi đổi múi giờ cần thống nhất để không mất sự kiện.
- Ghi event xem khi nội dung thật sự được mở/hiển thị theo ngưỡng quy định; tránh ghi lại nhiều lần do rebuild Flutter. Chính sách gom trùng cần backend quyết định và mô tả cho UI.
- Contract gợi ý: `historyId`, `targetType=POST|PLACE`, `targetId`, `viewedAt`, `targetSummary`, `canOpen`. Hỗ trợ paging + filter.

### 11.2. Hành vi bất thường

- Nội dung private bị thu hồi quyền: không hiển thị media bị khóa; có thể giữ một dòng không khả dụng theo chính sách.
- Nội dung bị xóa: không điều hướng đến đối tượng khác vì trùng tên; dùng `targetId` thật.
- Tab và bộ lọc giữ trạng thái khi xem chi tiết rồi Back nếu thiết kế giữ State màn.

---

## 12. Tìm kiếm gần đây: mọi nguồn, tối đa 30 ngày

**Đầu màn:** tiêu đề `Tìm kiếm gần đây`, nút **Xoá tất cả**.  
**Mỗi dòng:** icon/ảnh theo loại, tên/từ khóa, phụ đề xám nếu có; dấu **X** ở lề phải để xóa **một** item. Tên dài ellipsis, dấu X luôn cố định sát lề phải. Dữ liệu xếp mới nhất trước.

### 12.1. Nguồn cần ghi

- Tìm kiếm **chung** trên GoMate.
- Tìm **người dùng**.
- Tìm **địa điểm**, bao gồm từ Maps/Place Search nếu là chức năng tìm kiếm của ứng dụng.
- Tìm **lịch trình**.
- Các nguồn tìm kiếm khác của GoMate khi được triển khai cần đăng ký vào cùng hợp đồng history, không tạo các list tách biệt không đồng bộ.

### 12.2. Quy tắc điều hướng theo loại — PHẢI ĐÚNG

| `type` chuẩn đề nghị | Nội dung | Khi nhấn vào dòng |
|---|---|---|
| `USER` | Lần mở/tìm user | `PublicProfileScreen(userId: targetId)` |
| `PLACE` | Địa điểm | `PlaceDetailScreen` với place thật lấy bằng ID |
| `TRIP` | Lịch trình | `TripDetailScreen` với Trip thật của user được phép xem |
| `GENERAL` | Từ khóa chung | `SearchScreen(initialQuery: query, startSubmitted: true)`, giữ scope/filter nếu có |

- Nếu entity đã xóa/không còn quyền, **báo không khả dụng** thay vì mở bằng ID demo hoặc tên trùng.
- Không gọi `TripRepository.detail()` bằng `ui-preview-settings-trip`; `_PreviewTripDetailScreen` V2 chỉ phục vụ test và cần bỏ sau migration.
- Từ khóa/chữ đã gõ có thể không đại diện `targetId`: phân biệt rõ **lịch sử truy vấn** và **lịch sử nhấn kết quả**; event schema/UX chọn loại nào phải thống nhất.
- Xóa từng item / Xóa tất cả: backend phải xóa **chỉ history của account hiện tại**; UI hiển thị trạng thái chờ và thông báo sau thành công.
- **Retention tối đa 30 ngày** phải purge thật hoặc TTL, độc lập với 30-day history view. Cân nhắc chuẩn hóa và hợp nhất lượt tìm kiếm trùng; không giả định chỉ giữ 1 lần nếu chưa thống nhất.

### 12.3. Contract gợi ý

```text
historyId: stable unique id
userId: derived from session, not trusted from client
kind: GENERAL | USER | PLACE | TRIP
query: string
source: MAIN_SEARCH | USER_SEARCH | MAP_PLACE_SEARCH | TRIP_SEARCH | ...
targetId?: string                 // required for entity result navigation
createdAt: UTC timestamp
scope?: optional scope / hashtags / filters
preview?: short title / subtitle / cover/avatar (permission-aware)
```

**Đề xuất hành động:** ghi khi người dùng thực hiện tìm kiếm hoặc chọn kết quả theo quy tắc được chốt; list (mới→cũ, paging); delete one; clear all; purge. Đây là **gợi ý hợp đồng**, không phải endpoint hiện hữu.

---

## 13. Quyền riêng tư (Private/Public)

**UI:** công tắc `Tài khoản riêng tư` ở màn Quyền riêng tư. **Tắt** là public, **bật** là private. Nền track ở trạng thái tắt **xám nhạt** (điều chỉnh UX sau V2).

**Nghiệp vụ bắt buộc khi PRIVATE:**

1. Người chưa theo dõi/đang chờ xác nhận **không xem nội dung riêng tư** và **không mở danh sách Người theo dõi / Bạn bè**. Khi nhấn hai thống kê phải xuất hiện **popup “Cần theo dõi để xem”** theo luồng Profile.
2. Theo dõi tài khoản private → **yêu cầu chờ chấp nhận**; không chuyển ngay thành follower. Phía nhận có danh sách yêu cầu và thông báo riêng (module Notifications).
3. Chấp nhận yêu cầu → người gửi trở thành follower (một chiều), **không tự biến thành bạn bè hai chiều** nếu chủ tài khoản chưa follow ngược lại.
4. Trạng thái `friend` chỉ xuất hiện khi **theo dõi hai chiều**. Khoảnh khắc chỉ hiển thị giữa bạn bè theo nghiệp vụ GoMate.
5. Nếu public, theo dõi theo nghiệp vụ tự động được chấp nhận hiện hành; bỏ theo dõi cập nhật quyền truy cập kịp thời.
6. Thay đổi private/public phải thống nhất ở **Profile, Search, feed bài viết, danh sách người dùng, Moments, Notifications**. Không được chỉ sửa boolean cục bộ trong Settings.

**Contract dự kiến:** `isPrivate`, `followRequestStatus`, `followingByMe`, `followsMe`, `mutualFriend`, `canViewProfileContent`, `canViewPeopleLists`; backend đánh giá quyền mỗi request. **Không** suy luận private từ số follower hoặc message.

**Trạng thái V2:** `SettingsUiDemo.privatePreview` chỉ đổi công tắc / SnackBar. Chưa chứng minh đã có API/persist private setting. Cần nguồn dữ liệu và mutation server thật trước khi gỡ mock.

---

## 14. Đổi mật khẩu / quên mật khẩu

- Settings bấm **Đổi mật khẩu** phải dùng **chung luồng** `ForgotPasswordScreen` đã có, **chỉ đổi title theo ngữ cảnh**: từ Settings `Đổi mật khẩu`, từ Login vẫn `Quên mật khẩu?`.
- `ForgotPasswordScreen(changePasswordMode: true)` dùng chung validate email/điện thoại → cấp PIN/OTP → xác minh → đặt mật khẩu. **Không nhân đôi màn**.
- Xác minh mã, thời hạn, số lần thử, giới hạn tần suất, anti-bruteforce, invalidation phiên (nếu chính sách) phải do backend xử lý. UI mẫu ở source cũ có logic PIN demo; không xem là server đã hỗ trợ thật.
- Cần quyết định đổi mật khẩu khi đang đăng nhập có yêu cầu mật khẩu cũ hoặc re-authentication không; nếu dùng chung reset flow, bảo đảm xác minh quyền sở hữu kênh khôi phục. **Đây là điểm backend/security cần chốt**, không tự mặc định bảo mật được bảo đảm vì có màn PIN.
- Không log PIN/password; server chỉ lưu password hash; trả thông báo lỗi không lộ tình trạng tài khoản ngoài chính sách.

---

## 15. Ngôn ngữ, chế độ tối, quyền truy cập thiết bị

### 15.1. Ngôn ngữ

- Settings hiển thị `Ngôn ngữ giao diện` và giá trị `Tiếng Việt`; sau này có thể ưu tiên cấu hình ngôn ngữ máy / lựa chọn user.
- **Flutter/app root** chịu trách nhiệm `Locale`/localization, backend chỉ lưu user preference nếu sản phẩm yêu cầu sync giữa thiết bị.
- Chưa có tính năng đổi ngôn ngữ thực; không báo đã thay toàn ứng dụng khi mới đổi label.

### 15.2. Chế độ tối

- Toggle on/off; track **tắt: xám nhạt `#F0F0F0`**, thumb trắng; bật theo xanh GoMate. **Đây là style, không cần endpoint**.
- V2 hiện `SettingsUiDemo.darkModePreview`; bật chỉ đổi công tắc, **không thay `ThemeMode` thật**.
- Khi phát triển: Flutter điều khiển `ThemeMode` ở app root, có đầy đủ palette/theme dark cho các màn; backend tùy chọn sync setting nhiều thiết bị, không nên quyết định dark chỉ từ server.

### 15.3. Quyền truy cập thiết bị

Các hàng gồm **Camera, Danh bạ, Vị trí, Micro, Thông báo, Ảnh**. Text trạng thái hiển thị đúng **“Đã cho phép”** hoặc **“Chưa cho phép”**; **bỏ tiền tố “Mẫu:”** trên giao diện theo yêu cầu sau V2. Tuy nhiên **việc bỏ nhãn “Mẫu” không biến giá trị đang hardcode thành giá trị thật**; team phải sớm thay bằng OS status để tránh gây hiểu nhầm.

- **Flutter/native platform adapter** (Android/iOS) kiểm tra trạng thái thật, không phải backend tự cấp quyền OS. Chạm một dòng mở request permission khi thích hợp hoặc điều hướng tới **App Settings của OS** khi cần.
- Nội bộ phải phân biệt `granted`, `denied`, `restricted`, `permanentlyDenied`, `limited`, `notDetermined` khi hệ điều hành hỗ trợ; UI có thể quy về 2 nhãn đã chốt.
- **Riêng ghim lịch trình (Maps/Trip):** nghiệp vụ đã chốt yêu cầu GPS **Always/background location** để ghim; nếu chưa có thì hỏi và kiểm tra đủ quyền; từ chối thì **không cho ghim**. Không chỉ dựa vào nhãn “Đã cho phép” đơn giản trong Settings để quyết định đủ quyền chạy nền.
- Các quyền Camera/Micro/Ảnh/Danh bạ/Thông báo khác cần kiểm tra theo feature sử dụng và OS version, không xin hàng loạt quyền ngay khi mở Settings.

---

## 16. Hỗ trợ, Điều khoản, Giới thiệu

Chỉ là điểm điều hướng/giao diện định hướng phát triển sau. Khi sản phẩm có chính sách, cần đường dẫn nội dung pháp lý/version được phê duyệt; **không dựng API hoặc tự nhận nội dung này đã xong**. Nếu giới thiệu hiển thị phiên bản, lấy từ app build info; backend chỉ cần nếu có dữ liệu động.

---

## 17. Yêu cầu UI/UX xuyên suốt — GIỮ KHI ĐỔI BACKEND

1. Header **Cài đặt và hoạt động**, **Hoạt động của bạn**, Lượt thích/Bình luận/Đánh giá/Đã lưu... sử dụng **cỡ chữ màn phụ** khoảng 14.5–16.5 (responsive) như trang Tạo lịch trình, Xem bài viết, Đánh giá; không làm tiêu đề giống chữ lớn tab Home/Profile.
2. Chữ xám trạng thái **và dấu `>` cùng nằm sát mép phải**, giữ một `trailing` slot cố định; tên item dài chỉ co/ellipsis bên trái. Không để giá trị đẩy dấu `>` thụt vào.
3. Nút Quản lý **luôn là icon `copy`**, xám khi tắt, đen khi bật; không đổi thành dấu `X` khi đang quản lý. Tick chọn riêng dùng hình tròn.
4. Bình luận chỉ cho tick **bình luận của bản thân ở hàng dưới**; hàng trên chỉ là tham chiếu.
5. Tỷ lệ ảnh/grid, avatar, khoảng cách, Back, gradient `#0A43A8 → #0C6ECF → #0D8AE8`, shadow của GoMate giữ đồng đều các module.
6. Ở màn **Xem chi tiết bài viết**, nhãn `Bài viết` cần **nhỏ hơn** theo yêu cầu mới nhất; nếu dùng header shared thì chỉ tùy chỉnh màn này (hoặc thống nhất kích thước toàn màn phụ) **không thu nhỏ header của các tab chính**.
7. Chart `Hôm nay` căn đáy và khung nhãn tương đương 6 ngày khác; đủ chỗ chữ xuống hai dòng.
8. Dark mode/Private switch **tắt có track xám nhạt**; trạng thái thật về sau phải phản ánh từ nguồn dữ liệu, không từ cảm giác màu.
9. Mọi lối mở một người từ **Đã chặn**, **Khoảnh khắc đã ẩn**, **Báo cáo** và **Tìm kiếm gần đây** → `PublicProfileScreen` chuẩn (profile đã chặn dùng state chặn của cùng màn). Không giữ widget profile preview trùng màn sau migration.

---

## 18. Đề xuất phân lớp tích hợp (không phải kiến trúc đã triển khai)

```text
UI Settings (giữ giao diện và component)
  |
  +-- SettingsActivityDataSource  --> social likes/comments/reviews/saved
  +-- SettingsSocialDataSource    --> blocks, muted moments, reports, profile relation
  +-- ViewHistoryRepository      --> POST/PLACE events, 30-day retention
  +-- SearchHistoryRepository    --> GENERAL/USER/PLACE/TRIP events, 30-day retention
  +-- UsageAnalyticsAdapter      --> Flutter lifecycle / được phép từ OS
  +-- UserPreferencesRepository  --> privacy (server); theme/locale (app + optional sync)
  +-- DevicePermissionAdapter    --> OS permission state, app settings
  +-- AuthService hiện có        --> account, password flow, logout

Shared destinations (không tạo màn mới):
  PublicProfileScreen | PlaceDetailScreen | GoMateProfilePostFeedScreen
  TripDetailScreen | SearchScreen | MyMomentsScreen
```

**Phân ranh trách nhiệm:**

- **Backend:** dữ liệu theo tài khoản, follow/private/block/mute/report, quyền xóa, like/bookmark/review, lưu trữ/TTL lịch sử, API đổi mật khẩu, event nếu có sync.
- **Flutter/mobile:** hiển thị, navigation, trạng thái tải/lỗi, multi-select, trạng thái OS permissions, dark theme, localization, thu thập foreground usage nếu được phê duyệt.
- **QA:** xác nhận giao diện chung; bảo mật owner/mutual/private; history TTL; navigation khi target mất quyền; đồng bộ giữa các màn.

### 18.1. API/data contract đề xuất (cần backend xác nhận)

| Tài nguyên | Read | Mutation | Chú ý |
|---|---|---|---|
| Preferences | Đọc `isPrivate`, có thể locale/theme | Update privacy | Privacy được enforce tại server |
| Activity likes | Trang POST/PLACE đã thích | Unlike one/batch | Không xóa target |
| Comments by me | List có parent/post preview | Delete own comment | Ownership bắt buộc |
| Reviews by me | List rating/place/media | Delete own review | Cập nhật rating aggregate |
| Saved posts | List đã bookmark | Unsave one/batch | Không xóa bài viết |
| Blocks | List user đã chặn | Block/unblock bằng user ID thật | Đồng bộ DM/Profile |
| Reports by me | List report/target status | Không cần delete trong UX hiện tại | Ẩn nội dung không có quyền |
| Muted moments | List user bị mute | Mute/unmute | Mutual friends + refresh strip |
| View history | List events + filters | Ghi event, purge | 30 ngày thực |
| Search history | List theo source/type | Record, delete one, clear all, purge | 30 ngày thực |
| Usage time | Report 7 ngày | Thu thập theo nguồn hợp pháp | Chỉ để xem |

Các đường dẫn cụ thể, phương thức HTTP, schema response cuối cùng, phân trang và error codes **chưa được chốt trong cuộc trao đổi**; bảng trên là định nghĩa chức năng để backend tự thiết kế hoặc đối chiếu endpoint hiện có, **không khẳng định đã có sẵn**.

---

## 19. MA TRẬN HIỆN TRẠNG: sử dụng thật vs DEMO

| Tính năng | Đang dùng lại code thật | Chưa thể coi là hoàn tất backend |
|---|---|---|
| Trang Settings / tìm mục | Widget Flutter thật | Không cần search backend riêng |
| Chỉnh sửa Profile | Route tới `ProfileEditScreen` | Chỉ các trường backend thực hỗ trợ mới persist; không mặc định avatar/gender/link đã lưu |
| Đổi mật khẩu | Reuse `ForgotPasswordScreen(changePasswordMode: true)` | PIN/OTP source có phần UI demo; cần xác nhận backend thật |
| Đăng xuất | `AuthService.instance.logout()` | Cần E2E check server revoke phiên |
| Thư viện Khoảnh khắc | Reuse `MyMomentsScreen` + repository | Không thêm thư viện Settings |
| Thích/đã lưu/bình luận/đánh giá | List + thao tác `SettingsUiDemo` | Chưa đọc/mutate backend từ màn Settings |
| Đã chặn / Đã ẩn / Báo cáo | Có route vào `PublicProfileScreen`, Place/Post | Item ID và mutation hiện là demo; chưa đồng bộ server |
| Thời gian | Chart Flutter | Mock minutes, chưa đo |
| Lịch sử xem/tìm kiếm | Có lọc UI, điều hướng từ mẫu | Chưa có nguồn/purge server |
| Private/Dark | Công tắc Flutter | Chỉ là boolean demo, không persist root/server |
| Quyền thiết bị | List Flutter | Trạng thái hardcode, không kiểm tra OS |
| Ngôn ngữ | Hiển thị UI | Chưa đổi locale |
| Support/Terms/About | Placeholder UI | Phát triển sau |

---

## 20. CHECKLIST XÓA / THAY MOCK SAU KHI BACKEND HOÀN THÀNH

**Không xóa toàn bộ file Settings một lần.** Thứ tự an toàn: tạo repository thật → map DTO → thay một call-site → test cả chiều đi và chiều về → mới xóa seed/field demo không còn dùng.

### 20.1. Điểm thay thế theo file cụ thể

| File | Tìm đoạn/biến/tag | Phải thay hoặc xóa khi tích hợp | Phải giữ |
|---|---|---|---|
| `lib/features/profile/ui_preview/settings_ui_demo.dart` | `SettingsUiDemo`, `SettingsDemo*`, `TODO(BACKEND-SETTINGS-UI)`, `likedPosts`, `savedPosts`, `likedPlaceIds`, `comments`, `reviews`, `blocked`, `hiddenMoments`, `reports`, `visits`, `searches` | **Xóa toàn bộ file chỉ sau khi tất cả consumer đã sang data source thật** | Không giữ seed để production đọc được |
| `.../screens/setting_screen.dart` | `SettingsUiDemo.instance` listener, `darkModePreview` | Lấy dark state từ app theme manager, private từ server; bỏ phụ thuộc demo | Header, cấu trúc Settings, tìm kiếm mục con, ProfileEdit, logout |
| `.../screens/settings_activity_screen.dart` | route theo category | Có thể giữ nguyên; chỉ bảo đảm các màn con nhận data thật | Nhóm menu và điều hướng thư viện Khoảnh khắc |
| `.../screens/settings_collection_screen.dart` | `_demo`, `_ids`, `_remove`, `_openPost`, `_openPlace`, `TODO(BACKEND-SETTINGS-UI)` | Replace likes/posts/places/comments/reviews/saved lists và mutation; kiểm tra owner comment; bỏ phụ thuộc `ProfileUiPreview` cho media/id thật | Grid/tab, icon `copy`, selection, gradient, card comment 2 tầng |
| `.../screens/settings_account_lists_screen.dart` | `demo.blocked`, `demo.hiddenMoments`, `demo.reports`, `SettingsDemoPerson`, `SettingsDemoReport`, `_openPerson`, `_openReport`, `_unblock`, `_unhide` | Thay bằng list Block/Mute/Report thật; route `PublicProfileScreen` bằng `userId` thật; xóa callback state giả sau khi query đồng bộ | Màn list, avatar, Back, menu Profile chung |
| `.../screens/public_profile_screen.dart` | `initialPreviewBlocked`, `initialPreviewMuted`, `onPreviewBlockedChanged`, `onPreviewMutedChanged`, `_previewBlocked`, `_previewMuted`, `TODO(BACKEND-SETTINGS-UI)` | Chuyển về `isBlockedByMe`/`isMomentMutedByMe` source thật; bỏ **chỉ các tham số demo** khi không còn call-site; dùng actual mutation | **PublicProfileScreen**, trạng thái bị chặn, private, `GoMateBottomSheet` ba chấm, Mute/Unmute |
| `.../screens/settings_history_screen.dart` | `demo.visits`, `demo.searches`, `_recent`, `_dateMatches`, `_PreviewTripDetailScreen`, `_timeChart()`, `values = [...]` | Gắn ViewHistory/SearchHistory/Usage thật; bỏ màn trip mẫu khi đã có targetId thật; retention/paging | 3 lựa chọn lọc (mặc định 30 ngày), history tabs, link target, chart layout |
| `.../screens/settings_preferences_screen.dart` | `privatePreview`, `darkModePreview`, `_permissions() const data`, `_language()`, `_future()` | Thay source privacy/server, theme root, locale root, device permission adapter; đổi hardcode demo quyền thành OS state | Hàng cài đặt, toggle, màu tắt, chevron, mô tả |
| `.../widgets/settings_shared_widgets.dart` | `SettingsPageShell`, `SettingsCompactHeader`, `SettingsMenuRow`, `SettingsGradientButton`, `SettingsVisualAvatar`, `SettingsMediaImage`, `SettingsEmpty` | **KHÔNG XÓA** cùng seed; chỉ nâng loading/empty/error khi cần | Toàn bộ widget cơ sở |
| `lib/features/auth/screens/forgot_password_screen.dart` | `changePasswordMode`, `_titleForStep()` và mã PIN giả trong source cũ (nếu còn) | Giữ switch nhan đề; thay **phần giả gửi/xác minh mã** khi auth backend thật sẵn sàng | Quên/Đổi mật khẩu dùng chung và validation đúng |
| `lib/features/profile/ui_preview/profile_ui_preview.dart` | `ProfileUiPreview.*`, `ProfilePreviewPerson` | **Mock dùng chung module Profile, không thuộc Settings riêng**. Chỉ xoá sau khi Profile/Search/Notifications/Settings đều bỏ tham chiếu | Profile, feed, maps chi tiết thật |
| `lib/core/widgets/gomate_main_tab_header.dart` / `.../screens/profile_post_feed_screen.dart` | `titleSizeOverride`/nhãn `Bài viết` (nếu đã sửa thủ công) | Không liên quan demo; chỉ bảo đảm size riêng không ảnh hưởng tab chính | Header dùng chung |

> Ký hiệu `.../` trong bảng là **`lib/features/profile/`**. Đường dẫn chuẩn vẫn được ghi tại mục 21 dưới đây. Trước khi xóa, **tìm trong toàn bộ `lib/`** chứ không chỉ mục Settings, vì profile preview và navigation được các module khác tái sử dụng.

### 20.2. Các `TODO` và ID bắt buộc loại bỏ

Tìm trong VS Code (`Ctrl+Shift+F`) hoặc terminal:

```powershell
rg -n "TODO\(BACKEND-SETTINGS-UI\)|SettingsUiDemo|SettingsDemo|ui-preview-|blocked-1|hidden-1|_PreviewTripDetailScreen" lib
rg -n "initialPreviewBlocked|initialPreviewMuted|onPreviewBlockedChanged|onPreviewMutedChanged" lib
rg -n "Mẫu:|last30Days|_VisitRange|darkModePreview|privatePreview" lib/features/profile
```

- `ui-preview-*` trong `ProfileUiPreview` của **các module khác** không tự động xóa chỉ vì Settings đã có API.
- `blocked-1`, `hidden-1`, `c1`, `r1` từ preview **không dùng làm user/comment/review IDs thật**.
- Nếu muốn bật chế độ preview trong build dev, phải bảo đảm release không tự hiển thị seed như dữ liệu thật và không gọi backend bằng ID mẫu.
- Sau thay xong, chấm dứt sử dụng `SettingsUiDemo.instance`, loại bỏ import và **chỉ lúc đó** xóa `settings_ui_demo.dart`. Đánh dấu TODO đã xử lý cùng PR để không sót.

### 20.3. Thứ tự tích hợp ưu tiên (đề nghị)

1. **P0:** xác nhận contract user/privacy/follow & quyền chặn, ownership bình luận, app auth/password; tránh lộ dữ liệu.
2. **P1:** blocks/mutes + `PublicProfileScreen` làm source of truth; đồng bộ Messages, Search, Moments và danh sách Settings.
3. **P1:** like/save/comment/review thật; hoàn thiện list & batch action + refresh event.
4. **P1:** search history + view history + TTL 30 ngày; route theo type/targetId; test private/404.
5. **P2:** permission adapter, theme/locale global, usage analytics có đồng ý.
6. **P2:** trợ giúp/điều khoản/giới thiệu khi có nội dung chính thức.
7. **Cuối cùng:** rà toàn project, xóa SettingsUiDemo/SettingsDemo và preview screen không dùng; test regression trước release.

---

## 21. Danh sách file Settings V2 để chuyển giao (đường dẫn thật)

```text
lib/features/profile/screens/setting_screen.dart
lib/features/profile/screens/settings_activity_screen.dart
lib/features/profile/screens/settings_collection_screen.dart
lib/features/profile/screens/settings_account_lists_screen.dart
lib/features/profile/screens/settings_history_screen.dart
lib/features/profile/screens/settings_preferences_screen.dart
lib/features/profile/screens/public_profile_screen.dart
lib/features/profile/widgets/settings_shared_widgets.dart
lib/features/profile/ui_preview/settings_ui_demo.dart

Các file tích hợp có liên quan nhưng không phải file Settings mới:
lib/features/profile/screens/profile_edit_screen.dart
lib/features/profile/screens/profile_post_feed_screen.dart
lib/features/profile/ui_preview/profile_ui_preview.dart
lib/features/moments/screens/my_moments_screen.dart
lib/features/moments/data/moments_repository.dart
lib/features/map/screens/place_detail_screen.dart
lib/features/search/screens/search_screen.dart
lib/features/trip/screens/trip_detail_screen.dart
lib/features/auth/screens/forgot_password_screen.dart
lib/core/widgets/gomate_main_tab_header.dart
lib/core/services/auth_service.dart
```

**Lưu ý trạng thái gói:** ZIP V2 có **9 file Dart** + hướng dẫn và một patch đổi title auth; các chỉnh sửa thủ công sau V2 (3 bộ lọc, switch màu xám, quyền bỏ “Mẫu:”, chữ `Bài viết` nhỏ) **không tự có trong ZIP V2 gốc**. Backend dev phải nhận commit local cuối cùng thay vì dựa vào ZIP V2 đơn lẻ.

---

## 22. Bộ kiểm thử chấp nhận (Acceptance Criteria)

### 22.1. Cài đặt, điều hướng, giao diện

- [ ] Tìm “Bình luận” trên Settings chính hiện đúng entry; nhấn mở thẳng màn Bình luận.
- [ ] Header cỡ màn phụ, cùng mép trái/phải; các hàng giá trị xám + `>` thẳng hàng dù tiêu đề dài.
- [ ] Icon quản lý `copy` tắt xám, bật đen; nhấn lại hủy chọn, không biến thành dấu X.
- [ ] Đăng xuất thành công không Back vào MainShell; lỗi server xử lý hợp lý.
- [ ] Chỉnh sửa hồ sơ từ Settings đúng **màn ProfileEditScreen** chung, không xuất hiện màn cũ.
- [ ] Từ Settings → Đổi mật khẩu tiêu đề đúng; từ Login → Quên mật khẩu vẫn giữ nguyên.

### 22.2. Hoạt động

- [ ] Likes PLACE/POST mở đúng target, bỏ thích xóa **quan hệ like** và refresh nguồn chung.
- [ ] Bình luận: **hàng trên không có tick**, chỉ hàng dưới tick; cố xóa comment người khác từ API bị từ chối dù thay request thủ công.
- [ ] Xóa comment của mình không xóa comment cha/post gốc.
- [ ] Đánh giá chính mình được xóa, người khác không; rating địa điểm được tính lại đúng.
- [ ] Bỏ lưu không xóa bài viết gốc; Home/feed cập nhật bookmark.
- [ ] MyMomentsScreen mở đúng kho sẵn có, không clone thư viện.
- [ ] Danh sách Đã báo cáo chỉ hiển thị báo cáo của tài khoản; target private/xóa xử lý đúng.

### 22.3. Quan hệ / private

- [ ] Blocked user từ Settings mở Profile chung với trạng thái khóa; ba chấm hiển thị **Bỏ chặn**; sau thành công biến khỏi list.
- [ ] Unblock từ Profile và Settings đồng bộ với Messages/Search.
- [ ] Hidden Moments user mở **Profile chung bình thường**, có **Bỏ ẩn** cho bạn bè; sau thành công xóa khỏi list muted.
- [ ] Không hiển thị quyền Moments cho người chỉ following một chiều.
- [ ] Private chưa duyệt: không mở người theo dõi/bạn bè; popup yêu cầu theo dõi hiện đúng; API từ chối dữ liệu không được phép.

### 22.4. Lịch sử và OS

- [ ] Lịch sử xem có **Ngày hôm qua / 1 tuần qua / 30 ngày qua**, **mặc định 30 ngày qua**; dữ liệu ngoài 30 ngày không còn trong storage theo TTL.
- [ ] Tab Địa điểm → Place Detail; tab Bài viết → feed **một bài**; target xóa trả trạng thái không khả dụng.
- [ ] Search lịch sử từ Main/Users/Places/Trips, nhấn item mở đúng **4 loại**; xóa một và xóa tất cả đều persist server.
- [ ] Search của user A không lộ sang user B; dữ liệu tự hết hạn sau 30 ngày.
- [ ] Biểu đồ 7 ngày có dữ liệu đo hợp lệ; “Hôm nay” không làm lệch đáy cột.
- [ ] Toggle tắt có nền xám nhạt; private bật/tắt làm thay đổi quyền **thật**, dark bật/tắt đổi **theme toàn app** khi feature sẵn sàng.
- [ ] Permissions hiển thị **Đã cho phép/Chưa cho phép** dựa trên OS state thật, không có chữ “Mẫu:”; vào OS Settings được khi cần.
- [ ] Ghim lịch trình không thành công nếu thiếu **quyền vị trí luôn luôn/background** theo nghiệp vụ đã chốt.

---

## 23. Các vấn đề cần người phụ trách backend/mobile cùng xác nhận

1. API nào thực sự có cho post likes/bookmarks và place likes? **Không đồng nhất với FavoritePlaceStore** khi chưa có nghiệp vụ thống nhất.
2. Có mutation batch không? Nếu không, lỗi một item trong danh sách nhiều item phản hồi và rollback như thế nào?
3. Post/comment/review bị xóa thì history/notifications/reports giữ preview hay redacted?
4. Block theo `userId` có được hỗ trợ ở API độc lập, hay hiện chỉ theo conversation?
5. API list muted Moments có chưa? Flutter cần `unmuteUser()` qua repository nào?
6. Privacy public/private có API và chính sách duyệt follow request hoàn chỉnh chưa? Quyền list followers/friends ở backend đã chặn chưa?
7. Quy tắc event: mở bài/địa điểm bao lâu mới ghi `viewHistory`? Ghi mọi lần hay hợp nhất `lastViewedAt`?
8. SearchHistory lưu truy vấn đã nhập hay chỉ khi bấm chọn kết quả? Nếu cả hai, có phân loại event không?
9. TTL 30 ngày theo thời điểm UTC hay ngày lịch của user? Cần định nghĩa cụ thể, UI filter vẫn phải đúng timezone.
10. Đo usage time bằng app lifecycle hay OS data? Ai giữ kết quả, có xin quyền/consent không?
11. Settings đổi mật khẩu dùng reset PIN hay xác minh mật khẩu hiện tại? Cơ chế mã PIN demo phải được loại bỏ trước release.
12. Ngôn ngữ/dark sync server hay chỉ local? Permissions là client OS state — backend không thể trả kết quả “được OS cấp” thay cho hệ điều hành.

---

## 24. Bàn giao và tiêu chí kết thúc tích hợp

**Bàn giao backend nên có:** mô tả từng endpoint/DTO và policy, mapping state UI, mã lỗi chuẩn (`UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMITED` nếu có), phân trang, retention jobs, mẫu response + kiểm thử endpoint. **Tên endpoint trong bản spec này chỉ là gợi ý nếu chưa tồn tại trong repository.**

Một tính năng được coi là **xong backend + dọn mock** chỉ khi:

- Gọi API thật qua repository/adapter đúng lớp; quyền được kiểm tra server; lỗi/loading/empty được xử lý.
- State được đồng bộ khi từ Settings ↔ các màn khác và sau khi khởi động lại/login lại.
- Đã xóa ID/seed/callback preview liên quan **mà không xóa widget UI**, và đã quét `TODO(BACKEND-SETTINGS-UI)`.
- Đã test thiết bị thật hoặc môi trường Flutter đầy đủ với `flutter analyze`, widget/integration tests và các trường hợp bảo mật.
- Đối chiếu giao diện với mẫu và các màn trước đó: đúng màu, header, lề phải, kích thước, icon chọn, luồng Back.

**Kết luận:** Giữ nguyên cụm Settings V2/V2+ làm lớp hiển thị. Chỉ thay **nguồn dữ liệu, các mutation và quyền hệ thống**. Đừng xây lại UI, đừng coi dữ liệu mẫu là nghiệp vụ thật, và **không xóa file preview cho đến khi các module khác không còn phụ thuộc**.
