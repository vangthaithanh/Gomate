# GOMATE — TỔNG HỢP NGHIỆP VỤ TẠO VÀ QUẢN LÝ BÀI VIẾT

**Bản bàn giao:** Create Post UI/UX V1 → V2 + yêu cầu bổ sung Camera ngày 15/10/2026  
**Đối tượng:** Backend / API / media processing / Flutter tích hợp backend / QA  
**Phạm vi:** Tạo bài viết từ Profile; ảnh và video; caption; hashtag; gắn người và địa điểm; quyền xem; đăng; xem; ghim/bỏ ghim; sửa quyền; xóa.  
**Trạng thái mã được đối chiếu:** Gói `GoMate_Create_Post_UIUX_V2.zip` và hướng dẫn/hand-off V1–V2 đã bàn giao. Người dùng xác nhận đã cập nhật và giao diện hiện ổn; **chưa kiểm chứng độc lập code local mới nhất sau V2**.  
**Quy ước trong tài liệu:** **[ĐÃ CHỐT]** = nghiệp vụ người dùng yêu cầu; **[DEMO V2]** = mã UI hiện có nhưng chưa có lưu trữ thật; **[MỚI — CHƯA TRIỂN KHAI]** = bổ sung sau V2; **[ĐỀ XUẤT]** = chi tiết kỹ thuật để backend thảo luận, không mặc định là endpoint/hợp đồng đã tồn tại.

---

## 1. Phạm vi, nguyên tắc chung

1. **[ĐÃ CHỐT]** Tại **trang cá nhân của chính mình**, nhấn dấu `+` trên header để mở **Bài viết mới**. Đây là luồng đăng bài viết, **không được điều hướng sang camera Khoảnh khắc**.
2. **[ĐÃ CHỐT]** Giao diện chung dùng hệ màu GoMate (xanh đậm `#0A43A8`, gradient `#0A43A8 → #0C6ECF → #0D8AE8`, xám `#828282`/`#DADADA`), responsive, không fix khung theo ảnh Figma. Header, bottom sheet, nút quay lại và lề phải dùng những component chung hiện có; không tạo bản sao riêng nếu chức năng tương tự.
3. **[ĐÃ CHỐT]** Chỉ chỉnh logic backend ở tầng data/service khi tích hợp; **giữ lại giao diện Flutter đã duyệt**, tránh sửa Mapbox, Trip, Messages hoặc authentication nếu không liên quan.
4. **[ĐÃ CHỐT]** Tác vụ ảnh/video, tìm kiếm người/địa điểm phải tuân theo quyền riêng tư, quyền sở hữu và trạng thái tài khoản. Không coi màn demo hoạt động đồng nghĩa API thật đã kết nối.
5. **[ĐÃ CHỐT]** Sau khi đăng thành công, bài phải đọc được từ Profile, feed và các điểm điều hướng hợp lệ khác, theo **cùng một ID bài viết thật**; không dựng bài khác nhau ở mỗi màn.

## 2. Luồng tạo bài viết tổng thể

```text
Profile của tôi → dấu +
    ↓
Bài viết mới — album thiết bị trực tiếp
    ├── [Ô đầu tiên: Camera]      ← MỚI, CHƯA TRIỂN KHAI
    │      ├── Chụp ảnh
    │      └── Quay video
    └── Các ảnh/video trong album hệ thống
    ↓
Chọn 1–12 ảnh/video (tổng hợp cả Camera và thư viện)
    └── Video >60 giây → chọn đoạn tối đa 60 giây
    ↓
Tiếp tục → trang biên tập
    ├── Xem và kéo đổi thứ tự media
    ├── Nhập caption
    ├── Chọn/tạo hashtag (tối đa 5)
    ├── Gắn thẻ bạn bè (nhiều người)
    ├── Chọn một địa điểm
    └── Chọn đối tượng xem (phụ thuộc Public/Private)
    ↓
Chia sẻ → chuẩn bị/cắt video thật → upload media → tạo Post → cập nhật Profile/feed
    ↓
Mở bài vừa đăng → tương tác bình thường + menu quản lý chủ bài
```

**Chú ý:** Trong V2, bước **Chia sẻ** chỉ ghi dữ liệu vào RAM để thử giao diện; chuỗi upload/cắt video/tạo Post ở sơ đồ là **luồng tích hợp tương lai**, không phải chức năng backend đã hoàn thành.

---

## 3. Màn chọn ảnh và video — thư viện hệ thống

### 3.1. Hiển thị album [ĐÃ CHỐT; đã có UI V2]

- Khi mở **Bài viết mới**, **hiển thị trực tiếp thư viện ảnh/video chính của điện thoại** trong lưới; không bắt nhấn thêm nút "Ảnh" để mới mở thư viện.
- Mặc định khung xem trước trên cùng hiển thị **media gần nhất** trong album. Khi người dùng chọn media, khung xem trước đổi theo media đang chọn.
- Media trong lưới gồm **ảnh và video**; video có dấu phát và thời lượng.
- Cho chọn một hoặc nhiều, vòng tròn ở góc item và **số thứ tự 1…12** theo thời điểm chọn; khi chọn nhiều, giữ thứ tự đã chọn, không tự sắp theo tên file.
- Thư viện hiển thị các mục mà hệ điều hành cho phép đọc; hỗ trợ quyền toàn bộ, quyền giới hạn, từ chối quyền, album rỗng, tải dần khi cuộn và quyền bị thu hồi giữa phiên.
- Dữ liệu hiện V2: `photo_manager` → `AssetPathEntity` / `AssetEntity`; không dùng gallery fixture. `getAssetListPaged(page: ..., size: 72)` là cách phân trang UI hiện tại, **không phải giới hạn nghiệp vụ**.
- **[ĐÃ CHỐT]** Tổng số media **ít nhất 1, tối đa 12** cho một bài, bất kể ảnh/video kết hợp thế nào; phải chặn mục thứ 13 với thông báo rõ.

### 3.2. Ô Camera ở vị trí đầu tiên [MỚI — CHƯA TRIỂN KHAI]

**YÊU CẦU MỚI CẦN BỔ SUNG KHI HOÀN THIỆN TÍCH HỢP:**

1. Thay **ô đầu tiên của lưới album** bằng một ô có **icon Camera** theo phong cách GoMate. Ô này luôn ở vị trí số 0 của lưới; các ô tiếp theo là ảnh/video thật của điện thoại. **Ô Camera là điều khiển thao tác, không tính vào số lượng 12 media**.
2. Khi nhấn ô Camera, cho người dùng chọn hoặc chuyển chế độ **Chụp ảnh** và **Quay video** bằng camera thiết bị.
3. Sau khi chụp/quay thành công, media tạo mới được đưa vào **danh sách media đang chọn**, xuất hiện ở khung xem trước; có thumbnail, đúng loại `IMAGE`/`VIDEO` và **được tính chung vào tổng 12 mục** với media đã chọn từ thư viện.
4. Ví dụ nghiệp vụ: 8 ảnh trong album + 2 video từ album + 1 ảnh chụp mới + 1 video quay mới = **12/12 hợp lệ**. Thêm tiếp một media bất kỳ phải bị chặn. **Không** được coi mỗi nguồn có hạn mức 12 riêng.
5. Nếu trước khi mở camera đã đủ 12 mục, ngăn thêm mục mới (có thể vô hiệu hóa thao tác chụp/quay hoặc thông báo cần bỏ chọn một mục). Không âm thầm thay một media đã chọn.
6. Nếu người dùng đóng camera/hủy thao tác/chưa cấp quyền, quay về màn chọn media và **giữ nguyên danh sách, thứ tự, caption nháp và các lựa chọn trước đó**.
7. Video quay bằng camera chịu **cùng quy tắc tối đa 60 giây** như video thư viện. Có thể ưu tiên giới hạn quay 60 giây ngay ở camera; nếu file kết quả vẫn dài hơn 60 giây, **phải vào cùng màn chọn đoạn** trước khi cho đăng.
8. Media vừa tạo cần hiển thị đúng sau khi thiết bị lưu ảnh vào album hoặc trả tệp tạm. **[ĐỀ XUẤT]** Khử trùng lặp theo asset ID/URI/tệp khi cùng tệp vừa xuất hiện ở "đã chọn" vừa được hệ điều hành thêm vào lưới.
9. Thứ tự đã chọn vẫn là thứ tự chính thức, bất kể nguồn Camera hay thư viện. Sau đó vẫn có thể kéo đổi thứ tự ở màn biên tập.

**Phân công phải hiểu chính xác:** Hiển thị ô Camera, mở camera và xin quyền **thuộc Flutter/mobile + hệ điều hành**, **không phải một API web của backend**. Backend phụ trách **tiếp nhận media đã tạo, xử lý/tải lên, xác thực loại file, quyền sở hữu và giới hạn**. Hạng mục này cần cả Flutter lẫn backend phối hợp; đừng chờ backend làm widget Camera rồi mới bổ sung.

**Quyền thiết bị cần lưu ý khi hoàn thiện Flutter:** `CAMERA`, quyền microphone khi quay có âm thanh (Android/iOS theo hệ điều hành), các usage descriptions iOS. Tránh yêu cầu quyền microphone nếu chỉ chụp ảnh. Trạng thái quyền cần được đọc thực tế, không lấy từ các nhãn mô phỏng ở Settings.

### 3.3. Quy tắc giới hạn media [ĐÃ CHỐT]

| Tình huống | Kết quả kỳ vọng |
|---|---|
| Chọn 0 media, nhấn Tiếp tục | Không cho qua, thông báo cần ít nhất một ảnh/video |
| Chọn 1 ảnh hoặc 1 video | Hợp lệ |
| Chọn 12 ảnh/video từ nhiều nguồn | Hợp lệ, tổng 12 |
| Chọn media thứ 13 bằng album | Bị chặn, không mất danh sách đã chọn |
| Chọn media thứ 13 bằng Camera | Bị chặn tương tự |
| Bỏ chọn một media | Cho phép chọn thêm một media mới |
| Một video dài hơn 60 giây | Buộc chọn đoạn hợp lệ trước khi có thể đăng |
| Chọn đồng thời video quay và video thư viện | Mỗi video vẫn phải <=60 giây sau xử lý |

---

## 4. Video — tối đa 1 phút, cắt video

- **[ĐÃ CHỐT]** Giới hạn **60 giây trên từng video** trong bài viết; không phải 60 giây cho tổng 12 media. Áp dụng **đồng đều cho video quay mới và video có sẵn trong album**.
- Video gốc <=60 giây: được dùng bình thường nếu đọc và kiểm tra hợp lệ.
- Video gốc >60 giây: mở màn **Cắt video**, người dùng chọn **đoạn bất kỳ có độ dài tối đa 60 giây**, không bắt buộc lấy 60 giây đầu. Có thể chọn đoạn ngắn hơn.
- **[DEMO V2]** `post_video_trim_screen.dart` phát preview và trả `GoMatePostTrimRange { startMs, endMs }`; hiện **chưa xuất file video đã cắt**. Đường dẫn tệp gốc `video-file:` + metadata cắt **không phải file kết quả**.
- **[CẦN TÍCH HỢP]** Flutter/native media layer hoặc media processing service cần thực sự tạo/chuẩn bị phần video đã chọn; backend/media worker kiểm tra duration, codec, kích thước, MIME, xử lý encode/thumbnail, lưu media và trả URL/metadata. Phải chốt phương án client trim hay server trim; cả hai vẫn cần backend kiểm chứng nội dung kết quả.
- Thất bại cắt, codec không hỗ trợ, file quá lớn, rời app giữa chừng, hết bộ nhớ và lỗi upload phải có trạng thái lỗi/ràng buộc retry; **không lưu bài như đã đăng thành công** nếu video chưa được xử lý hợp lệ.

**Đề xuất nguyên tắc xác thực server:** Kiểm tra duration thực từ file hoặc bản media sau xử lý, không tin duy nhất `startMs/endMs` hay `durationMs` do app gửi; sai thời lượng trả lỗi cụ thể. Không coi việc UI có thanh cắt đồng nghĩa file đã bị cắt.

---

## 5. Màn biên tập bài viết

### 5.1. Media và thứ tự [ĐÃ CHỐT]

- Một media: hiển thị một preview. Nhiều media: xem bằng cách **vuốt ngang**.
- Thứ tự gốc là **thứ tự người dùng chọn** (từ album và Camera), được phép **nhấn giữ rồi kéo** để sắp xếp. Thứ tự sau khi kéo là thứ tự cuối cùng khi đăng.
- Backend lưu `sortOrder` cho **từng item**, bất kể upload kết thúc sớm/muộn; không được sắp lại theo URL hoặc thời điểm upload.
- Preview ảnh/video phải giữ tỷ lệ nhất quán với feed đã được thiết kế; không dùng kích thước pixel cố định theo Figma.

### 5.2. Caption [ĐÃ CHỐT]

- Chạm "Thêm chú thích" → mở bàn phím, nhập trực tiếp, nội dung hiển thị ngay trên ô caption.
- Caption thuộc bài viết, lưu chính xác nội dung hợp lệ, hỗ trợ tiếng Việt, emoji và xuống dòng. UI V2 có `maxLength: 2200`; **[ĐỀ XUẤT]** backend và Flutter cùng thống nhất giới hạn này khi định nghĩa API; không xem là giới hạn người dùng đã xác nhận riêng biệt.
- Nếu rời màn đang có dữ liệu nháp, UI hiện hỏi xác nhận bỏ bài viết. Lưu bản nháp bền vững là **chức năng chưa được yêu cầu/chưa triển khai**.

### 5.3. Hashtag [ĐÃ CHỐT]

- Nhấn "Nhập hashtag" mở bottom sheet nhập/tìm hashtag có sẵn; người dùng **không cần tự gõ dấu `#`**.
- Khi nhấn một hashtag gợi ý hoặc "Hoàn tất" với chữ tự nhập, kết quả tự chuẩn hóa thành `#TênHashtag` và hiển thị trên màn biên tập.
- **Tối đa 5 hashtag khác nhau/bài**; có thể nhấn `x` để xóa một hashtag rồi nhập hashtag khác. Ngăn trùng lặp **không phân biệt hoa/thường**.
- Tìm kiếm hashtag hiện được mô phỏng trong `SearchRepository.searchHashtags`; server cần cung cấp tra cứu, kiểm tra/sanitize và chỉ mục hashtag (hạn chế lạm dụng nếu cần).
- **[ĐÃ CHỐT — điều hướng sau đăng]** Nhấn hashtag ở **bài viết đã đăng** phải mở **Tìm kiếm chung**, điền từ khóa `#Hashtag` và chọn sẵn **tab Bài viết**. Kết quả lọc theo hashtag và quyền xem của người đang truy cập; không được trả bài Private/Only Me trái phép.

### 5.4. Gắn thẻ bạn bè [ĐÃ CHỐT]

- Tái sử dụng **giao diện tìm/chọn người** đang được dùng khi thêm thành viên vào lịch trình/nhóm; có thể chọn **nhiều người**.
- Sau khi chọn, hàng "Gắn thẻ bạn bè" hiển thị chữ xám ở phía phải như `2 người`, căn cố định sát mép phải cùng dấu `>`.
- **Không gửi lời mời tham gia lịch trình, không thêm vào nhóm chat, không tự gửi tin nhắn**; thao tác chọn này chỉ lưu danh sách `taggedUserIds` vào Post.
- Server xác thực người dùng được tag tồn tại, chính sách được gắn thẻ, quan hệ chặn và quyền riêng tư. Gắn thẻ không tự cấp quyền đọc một bài `ONLY_ME` hoặc bài `FOLLOWERS` nếu người được gắn không thuộc đối tượng được xem.
- **[ĐỀ XUẤT]** Sau khi tạo thành công, backend cân nhắc phát thông báo gắn thẻ theo chính sách của sản phẩm; không tự coi tính năng thông báo này đã được chốt trong luồng mới.

### 5.5. Gắn địa điểm [ĐÃ CHỐT]

- Nhấn "Địa điểm" để mở lại chính màn tìm địa điểm của Maps: `MapPlaceSearchScreen`; nguồn Place thực từ hệ thống Maps hiện có.
- **Mỗi bài chỉ được gắn tối đa 1 địa điểm**. Chọn lại là **thay thế** địa điểm cũ, không thêm một dòng địa điểm thứ hai.
- Sau khi chọn, hàng hiển thị **thumbnail nhỏ + tên địa điểm** thay icon/nhãn mặc định, đồng bộ các hàng địa điểm khác của GoMate; dấu `>` vẫn nằm cuối hàng.
- Backend lưu `placeId` thật, kiểm tra Place còn hợp lệ/quyền truy cập; trả dữ liệu gắn địa điểm phục vụ Profile, Home, Search và Place Detail. Không chỉ lưu text địa điểm vì không thể điều hướng chi tiết đáng tin cậy.

### 5.6. Quyền xem bài viết / Đối tượng [ĐÃ CHỐT]

| Loại trang cá nhân | Đối tượng mặc định khi tạo | Các lựa chọn được phép hiển thị |
|---|---|---|
| **PUBLIC** | **Mọi người (`EVERYONE`)** | Mọi người, Người theo dõi, Chỉ mình tôi |
| **PRIVATE** | **Người theo dõi (`FOLLOWERS`)** | Người theo dõi, Chỉ mình tôi; **không có Mọi người** |

- Chọn một lựa chọn trong popup dạng radio **tròn** và xác nhận bằng nút gradient; chữ xám ở hàng ngoài thay đổi tương ứng.
- Quy tắc trên áp dụng cho **tạo bài** và **chỉnh sửa quyền riêng tư bài đã đăng**.
- Backend phải cung cấp trạng thái `isPrivate` thật của tài khoản đăng nhập; không dựa vào công tắc demo `SettingsUiDemo.privatePreview` khi triển khai thật.
- Backend **không được chấp nhận** `EVERYONE` cho tác giả đang PRIVATE, kể cả request bị chỉnh tay. Có thể trả lỗi validation/forbidden.
- `FOLLOWERS` chỉ bao gồm người có quan hệ theo dõi **đã được chấp nhận**; đang `PENDING` không có quyền xem bài thuộc nội dung riêng tư.
- `ONLY_ME` chỉ tác giả nhìn thấy. Quyền này bắt buộc áp dụng nhất quán với endpoint Post, feed, Profile, Search, Place Detail, chia sẻ và thông báo.
- **[ĐỀ XUẤT]** Quyền xem hiệu lực = chính sách PRIVATE/PUBLIC của tác giả **kết hợp** đối tượng của bài. Nếu chủ tài khoản đổi PUBLIC → PRIVATE, bài cũ gắn `EVERYONE` không được vô tình công khai. Cần thống nhất cách chuyển đổi/lưu hiệu lực khi đổi trạng thái tài khoản.

### 5.7. Chia sẻ [ĐÃ CHỐT; demo hiện tại]

- Nhấn **Chia sẻ** sau khi đã chọn media và điền các thông tin mong muốn.
- **[DEMO V2]** `_share()` trong `create_post_screen.dart` gọi `GoMatePostUiDemoStore.instance.publish(...)` và quay về Profile; bài mới hiện trong lưới nhưng chỉ tồn tại trong **RAM**.
- **[TƯƠNG LAI]** Khi backend hoàn thiện, nút Chia sẻ phải có loading/progress, upload media, tạo Post và chỉ thông báo thành công **sau khi server xác nhận**. Nếu lỗi hoặc mất mạng, không tự đóng màn/hiển thị thành công; có khả năng retry hoặc giữ trạng thái biên tập theo thiết kế tích hợp.

---

## 6. Quản lý bài viết đã đăng

### 6.1. Menu dấu ba chấm theo chủ sở hữu [ĐÃ CHỐT]

**Bài của tôi:**

- `Ghim bài viết` / `Bỏ ghim bài viết` (khi bỏ ghim, icon `pin_off` có dấu chéo).
- `Chỉnh sửa quyền riêng tư` → mở lại **cùng popup Audience** của luồng tạo bài.
- `Xoá` → xác nhận qua popup chung; chỉ xoá khi người dùng xác nhận.

**Bài người khác:** giữ menu người xem hiện hành (ví dụ `Không quan tâm`, `Báo cáo`); **không** được hiển thị các lựa chọn ghim, sửa quyền hoặc xoá của chủ bài.

Backend xác định chủ sở hữu theo access token và `post.authorId`, **không tin cờ `isOwner` từ client**. Các mutation phải kiểm tra ownership/authorization phía server.

### 6.2. Ghim bài [ĐÃ CHỐT]

- **Tối đa 3 bài đang ghim trên mỗi tác giả**, tính chung bài đã đăng trước đó và bài mới. Không phải 3 cho mỗi trang/grid.
- Ghim mới → bài chuyển **lên đầu trang cá nhân**, nằm trước bài chưa ghim. Khi bỏ ghim → bài trở lại nhóm bình thường theo thứ tự quy định.
- Khi đã đủ 3 mà ghim bài thứ 4 → bị từ chối, không tự bỏ ghim một bài khác. Thông báo rõ lý do.
- **[ĐỀ XUẤT]** Trong nhóm ghim, sắp `pinnedAt DESC`; nhóm còn lại `createdAt DESC`. Nếu cần ưu tiên khác, thống nhất một quy tắc trước khi triển khai.
- Giới hạn cần được kiểm tra **atomic** ở backend (transaction/concurrent requests), không chỉ vô hiệu nút UI.
- Xóa bài ghim đồng thời gỡ trạng thái ghim và giảm số lượng bài ghim của tác giả.

### 6.3. Đổi Audience, xoá và lan truyền dữ liệu [ĐÃ CHỐT]

- Đổi Audience trên một bài không làm thay đổi Audience các bài khác.
- Sau thay đổi, mọi nơi đọc bài phải phản ánh dữ liệu mới, không để bài đã hạn chế quyền vẫn xuất hiện trong cache, search hoặc thông báo ở người không được xem.
- Xoá sau xác nhận: cập nhật ngay Profile, feed, lượt thích/bình luận/lưu, kết quả hashtag và nội dung bài ở địa điểm nếu có. Cách soft delete/retention là quyết định backend (**đề xuất**, chưa chốt).
- Bài có nhiều media cần giữ đúng liên kết Post–PostMedia; dọn media theo chính sách lưu trữ, không xoá nhầm media đang được nội dung khác sử dụng.

### 6.4. Xem bài và tương tác [liên thông module đã có]

- Nhấn một bài từ Profile mở cùng `GoMateProfilePostFeedScreen`, ảnh full-width tỷ lệ gần Home, nhiều media vuốt ngang; nút Tim, Bình luận, Chia sẻ, Lưu dùng các component/flow chung đã có.
- Quy tắc mở feed khi bấm bài `k` giữa danh sách: **bài được chọn đứng trước**, sau đó những bài còn lại theo thứ tự gốc; ví dụ 4 bài, chọn #2 → `[2,1,3,4]`, chọn #4 → `[4,1,2,3]`, không lặp bài được chọn.
- Các sự kiện like/comment/share/bookmark phải dùng **Post ID thật**, không sử dụng ID demo. Dữ liệu thống kê/đếm/trạng thái tương tác cần đi từ API/server thay vì state in-memory.
- Khi nhấn hashtag trong feed sau đăng: Search → tab Bài viết, query có dấu `#`, điều kiện truy cập được áp dụng từ server.
- Nội dung truy cập qua người khác, bài gắn địa điểm và chia sẻ phải cùng kiểm tra audience; nội dung không hợp lệ nên có trạng thái "không thể xem" thay vì lộ dữ liệu.

---

## 7. Hợp đồng dữ liệu dự kiến cho backend [ĐỀ XUẤT, CHƯA PHẢI API HIỆN CÓ]

### 7.1. Post và media

```text
Post {
  id:               stable id do server cấp
  authorId:         từ phiên đăng nhập (không tin client tự khai)
  caption:          string
  audience:         EVERYONE | FOLLOWERS | ONLY_ME
  hashtags:         List<string> (chuẩn hóa, tối đa 5)
  taggedUserIds:    List<userId>
  placeId?:         id của đúng 1 Place
  media:            List<PostMedia> (1..12 item)
  pinned:           boolean
  pinnedAt?:        ISO-8601
  createdAt:        ISO-8601
  updatedAt:        ISO-8601
  likeCount:        number
  commentCount:     number
  viewerLiked?:     boolean
  viewerSaved?:     boolean
}

PostMedia {
  mediaId:          id do server cấp
  kind:             IMAGE | VIDEO
  source:           GALLERY | CAMERA   // chỉ nếu cần thống kê, không để phân quyền khác nhau
  mediaUrl:         URL hoặc media key đã lưu trong storage
  thumbnailUrl?:    thumbnail thực cho ảnh/video
  sortOrder:        số thứ tự cuối sau kéo thả
  durationMs?:      thời lượng VIDEO sau xử lý, yêu cầu <= 60000
  width?:           chiều ngang thực
  height?:          chiều cao thực
  mimeType:         MIME sau kiểm tra server
  byteSize?:        kích thước thực
}

MediaProcessingRequest {  // phương án tùy kiến trúc
  temporaryMediaId:  id file upload tạm
  trimStartMs?:      điểm bắt đầu trong file gốc
  trimEndMs?:        điểm kết thúc trong file gốc
}
```

`source: CAMERA|GALLERY` là **thông tin tùy chọn**, không ảnh hưởng giới hạn 12 hay quyền xem. Backend không nên lưu đường dẫn cục bộ `file://`, `video-file:` hoặc asset ID OS như một URL media có thể phục vụ người dùng khác.

### 7.2. Các nhóm API/service cần có

| Nhóm | Mục đích | Ghi chú |
|---|---|---|
| **Media upload** | Nhận ảnh/video chụp/quay/thư viện, tạo URL/mediaId thật | Validate MIME, kích thước, ownership, content; có retry, cleanup upload dở |
| **Media processing** | Cắt/encode video, thumbnail, kiểm tra mỗi video <=60s | Có thể xử lý client + server hoặc worker async; server luôn xác thực |
| **Create Post** | Tạo bài từ 1–12 media, caption, hashtags, tags, placeId, audience, sortOrder | Atomic validation; ID chủ bài từ auth |
| **Get/List Posts** | Trang cá nhân của tôi/người khác, Home, bài theo Place và hashtag | Cursor/page, lọc quyền riêng tư, pinned-first ở Profile |
| **Post audience** | Đổi audience của đúng bài | Ràng buộc tài khoản PRIVATE |
| **Pin/Unpin** | Ghim/bỏ ghim, enforce 3 bài/tác giả | Chống race condition, trả lỗi giới hạn |
| **Delete Post** | Xóa theo ID, kiểm tra chủ sở hữu | Đồng bộ quan hệ tương tác, tìm kiếm, cache |
| **Hashtag search** | Gợi ý/tra cứu hashtag, tìm bài theo hashtag | Không trả bài người dùng không có quyền xem |
| **User tag search** | Tìm user hợp lệ để gắn thẻ | Tái sử dụng service tìm user/contact, không tạo Trip invitation |
| **Place reference** | Đảm bảo `placeId` hợp lệ, cho phép tìm bài theo địa điểm | Tái dùng Places hệ thống Maps |
| **Account privacy** | `isPrivate` thật; đồng bộ Settings/Profile và Post audience | Không để client demo làm nguồn dữ liệu chính |
| **Engagement** | Like, comment, share, saved state | Tích hợp repository Home/Profile đang dùng, không tạo cơ chế tương tác song song |

**Không tự giả định tên route REST**. Backend chốt URL, verb, DTO, pagination, error code, storage, cơ chế upload và phiên xác thực cùng team Flutter. Các API chưa có phải đánh dấu chưa triển khai.

### 7.3. Lỗi nghiệp vụ cần thống nhất [ĐỀ XUẤT]

| Trường hợp | Mã đề xuất | Hành vi Flutter |
|---|---|---|
| Không có media / quá 12 | `MEDIA_COUNT_INVALID` | Giữ màn biên tập, giải thích số mục |
| Video sau xử lý >60s | `VIDEO_DURATION_EXCEEDED` | Quay lại cắt hoặc chọn clip khác |
| File không hợp lệ | `UNSUPPORTED_MEDIA` | Chỉ ra media lỗi, cho chọn lại |
| Hashtag >5/trùng | `HASHTAG_INVALID` | Giữ danh sách hợp lệ, cho sửa |
| Place/User tag sai | `INVALID_REFERENCE` | Cho chọn lại đối tượng |
| PRIVATE nhưng audience EVERYONE | `AUDIENCE_NOT_ALLOWED` | Tự về FOLLOWERS/cho chọn lại sau xác thực |
| Ghim bài thứ 4 | `PIN_LIMIT_REACHED` | Báo giới hạn 3, không đổi trạng thái |
| Không phải tác giả | `POST_FORBIDDEN` | Không cho sửa/ghim/xóa |
| Upload thất bại | `MEDIA_UPLOAD_FAILED` | Giữ nháp và cho retry, không báo đăng thành công |

---

## 8. Trạng thái implementation hiện tại (đối chiếu gói V2)

| Chức năng | Trạng thái đúng theo V2 | Còn phải làm |
|---|---|---|
| Dấu `+` Profile → Bài viết mới | Đã nối UI | Giữ route hiện có |
| Album trực tiếp ảnh/video của thiết bị | Có `photo_manager` và phân trang | Hoàn thiện quyền, hiệu năng đa thiết bị |
| **Ô Camera đứng đầu lưới** | **CHƯA có trong V2** | **Bổ sung widget tile + mở Camera ảnh/video** |
| Ảnh/video từ Camera cũng tính vào 12 | **MỚI CHỐT, CHƯA có trong V2** | Hợp nhất source/selection/preview/order trước upload |
| Chọn tối đa 12 | Có ràng buộc ở UI/store | Bắt buộc validate lại server |
| Video >60 giây | Có chọn đoạn, preview | **Chưa xuất clip thật**; tích hợp cắt/upload và verify |
| Sửa nút Tiếp tục bị che | Đã sửa ở V2 | Giữ căn lề header |
| Caption, hashtag, gắn người/địa điểm | UI đã có | Hashtag lookup + post metadata thật |
| Public/Private default | Có qua AuthService field + Settings demo fallback | Lấy `isPrivate` thật, server enforce |
| Đăng bài | Chỉ store RAM | Upload + Create Post API, retry |
| Ghim tối đa 3 | Chỉ store RAM | Server atomic enforcement, query pinned-first |
| Menu chủ bài / đổi audience / xoá | UI + store demo | API mutation thật, quyền chủ bài |
| Nhấn hashtag sang Search Posts | UI điều hướng | Search/index bài theo tag + privacy thật |
| Like/comment/share/save | UI/Home interactions demo/đã có component | Repository dữ liệu và đồng bộ thật theo Post ID |

---

## 9. CHECKLIST XÓA MOCK / THAY THẾ MÃ SAU KHI HOÀN THÀNH BACKEND

**Nguyên tắc:** **Không xóa toàn bộ file UI** khi kết nối backend. Chỉ thay nguồn dữ liệu, trạng thái demo và các mutation; giữ lại widget mà người dùng đã duyệt. Xóa file demo **sau khi** không còn import/caller. Không sửa ồ ạt Home/Maps/Messages.

| Đường dẫn file / từ khóa trong code V2 | Đang giả lập điều gì | Cần xóa/thay sau backend | Giữ nguyên gì |
|---|---|---|---|
| `lib/features/posts/ui_preview/post_ui_demo_store.dart` | `GoMatePostUiDemoStore`, `GoMateDemoPublishedPost`, `ui-post-*`, `ui-preview-post-*`, `_posts`, `_previewPinned`, `_previewRemoved`, `_previewAudiences`, `publish`, `togglePin`, `togglePreviewPin`, `changeAudience`, `changePreviewAudience`, `remove` | Thay bằng Post Repository + DTO + state/query thật; khi không còn dùng thì **xóa store demo**. Có thể chuyển `GoMatePostAudience`, `GoMatePostTrimRange` sang model chính thống trước khi xóa file | Nghiệp vụ enum và giới hạn đã chốt, giao diện dùng các model này |
| `lib/features/posts/screens/create_post_screen.dart` | `_share()` → `GoMatePostUiDemoStore.instance.publish`, `_trimRanges` giữ clip metadata, fallback `SettingsUiDemo.instance.privatePreview`, ID `ui-preview-self` | Thay `publish()` bằng upload media + create API; privacy từ hồ sơ thật; media clip thật; loại bỏ fallback ID/cờ private giả. **Bổ sung ô Camera đầu tiên** ở `_galleryPage` / `GridView.builder` (yêu cầu mới, không phải mock có sẵn để xóa) | Màn chọn, preview, multi-select, reorder, hashtag/tag/location/audience, header |
| `lib/features/posts/screens/post_video_trim_screen.dart` | `GoMatePostTrimRange` chọn đoạn và preview, **không xuất clip** | Thêm pipeline xuất/cắt/encode và báo trạng thái; xác nhận output <=60s trước create | Range UI, player, nút sử dụng đoạn |
| `lib/features/posts/widgets/post_media_widget.dart` | Chấp nhận `file://`, `video-file:` và media local để test | Sau upload dùng mediaId/URL/CDN; giải phóng cache/tệp tạm đúng lúc, không ghi local path DB | Responsive image/video widget và xử lý loading/error |
| `lib/features/posts/widgets/post_hashtag_content.dart` | `SearchRepository.searchHashtags()` còn mock | Đổi nguồn sang Hashtag API/Search thật; có debounce, pagination nếu cần | Bottom sheet, trường nhập, định dạng tag |
| `lib/features/posts/widgets/post_audience_content.dart` | `isPrivate` do caller demo truyền | Đọc trạng thái thật và enforce server; **không xóa popup** | Hai/ba option, radio tròn, nút gradient |
| `lib/features/profile/screens/profile_screen.dart` | `_createdPosts`, `ProfileUiPreview.posts`, merge mẫu + bài mới, sort ghim local | Lấy danh sách post theo user từ API (lọc quyền và sort ghim), bỏ listener/store demo; sau đó xoá import mock | Profile header, dấu `+`, grid, navigation feed, moment, favorite |
| `lib/features/profile/screens/profile_post_feed_screen.dart` | `_ownPostActions`, `store.find`, `togglePin`, `togglePreviewPin`, `changeAudience`, `remove`, demo `DemoPostInteractionRepository` | Thay bằng API owner actions, engagement API, phản ánh dữ liệu sau mutation; không gửi ID `ui-post-*` lên server | Feed UI, popup menu, confirm, hashtag navigation, like/comment/share widgets |
| `lib/features/profile/ui_preview/profile_ui_preview.dart` | Các bài/author mẫu `ui-preview-post-*`, placeholder khi tài khoản trống | Chỉ xóa fallback sau khi nguồn Post thật phục vụ UI; kiểm tra các nơi khác cũng dùng file preview | Các màn Profile đã hoàn thiện |
| `lib/features/profile/ui_preview/settings_ui_demo.dart` | `SettingsUiDemo.privatePreview` | Loại khỏi quyết định privacy bài; thay bằng account privacy thật đồng bộ với Settings | Toggle UI Settings và màn chọn audience |
| `lib/features/search/data/search_repository.dart` | Mẫu hashtag và một phần bài viết | Thay lookup/index bởi API; kiểm soát quyền | SearchScreen/tab Bài viết và routing hashtag |
| `lib/core/widgets/gomate_member_invite_content.dart` | UI chọn liên hệ được dùng lại để tag | Đừng dùng side effect gửi lời mời Trip/Message; nếu cần thêm adapter chọn tags theo hợp đồng mới | **Không xóa** widget vì Trip/Messenger còn sử dụng |
| `lib/features/map/screens/map_place_search_screen.dart` | Không phải mock mới trong Create Post | Giữ picker; dùng Place ID thật trong Post, không duplicate search | **Không xóa** hoặc sửa luồng tìm địa điểm Maps |
| `lib/features/home/screens/home_screen.dart` | Feed mẫu có ID/ảnh mẫu riêng | Khi tích hợp Posts API, dùng dữ liệu bài thật/cùng Post ID; thay `DemoPostInteractionRepository` theo kế hoạch của module Home | Home UI, Moments, recommendation, Mapbox navigation |

**Các cụm tìm kiếm khi dọn code:**

```text
TODO(BACKEND-CREATE-POST)
TODO(BACKEND-CREATE-POST-VIDEO)
TODO(BACKEND-PROFILE-UI-PREVIEW)
GoMatePostUiDemoStore
GoMateDemoPublishedPost
SettingsUiDemo.privatePreview
ui-post-
ui-preview-post-
ui-preview-self
video-file:
file://
_demo
_previewPinned
_previewRemoved
_previewAudiences
```

**Không xóa các TODO trước khi thay thế hoàn chỉnh tất cả caller.** Cũng không xóa các đường dẫn local quá sớm nếu Flutter còn cần chúng để phát preview và upload; chỉ ngăn chúng trở thành URL dữ liệu server hoặc media của bài đã công khai.

### 9.1. Thứ tự triển khai & dọn sạch được khuyến nghị

1. **Chốt DTO/Auth/permission**: Privacy thực, ownership, audience, Post ID, Media ID, sort order, pin limit và error contract.
2. **Hoàn thiện Flutter Camera tile** (yêu cầu mới): ô đầu tiên, capture ảnh/video, permission, hợp nhất selection, giới hạn 12 và luồng cắt video.
3. **Triển khai media pipeline**: upload tệp camera+album, trim thực, transcode, thumbnail, validate <=60 giây, cleanup temp, trạng thái lỗi/retry.
4. **Triển khai Create/Get/List Post**: trả dữ liệu thật; Profile đọc server; bài mới và clip có thể xem từ thiết bị khác.
5. **Triển khai pin/audience/delete/engagement** và đồng bộ Profile, Home, Search, Place Detail, Settings, Notifications.
6. **Chuyển người gắn thẻ và hashtag search** sang dữ liệu thật; xác minh quyền xem trên tất cả lối mở.
7. **Bật API ở môi trường test, tắt fallback demo**; lần lượt xóa import + caller của `GoMatePostUiDemoStore`, `ProfileUiPreview.posts`, demo interaction và `SettingsUiDemo.privatePreview` khi không còn sử dụng.
8. Chạy `flutter analyze`, kiểm thử Android/iOS và test tích hợp server; sau đó mới xóa hẳn file demo nếu zero-reference.

---

## 10. Ma trận kiểm thử nghiệm thu

### 10.1. Lấy media từ album và Camera

- [ ] Mở Profile → dấu `+` → hiện album ảnh/video thật ngay, không picker trung gian.
- [ ] **Ô số 0 có icon Camera**, vẫn hiển thị khi album rỗng hoặc phải xin quyền album (phụ thuộc camera permission, không được phụ thuộc thumbnail album).
- [ ] Chạm Camera → chụp ảnh → ảnh hiện trong preview và danh sách chọn; quay video → video hiện đúng thumbnail/thời lượng.
- [ ] Ảnh/video Camera và album có **một bộ đếm chung** `0…12`.
- [ ] 10 media thư viện + 2 media Camera = 12 hợp lệ; media tiếp theo từ nguồn nào cũng bị chặn.
- [ ] Đã chọn 12, quay thêm không âm thầm bỏ một media cũ; thao tác bị chặn với thông báo.
- [ ] Bỏ chọn media, chọn thêm thành công và số thứ tự cập nhật nhất quán.
- [ ] Người dùng hủy Camera hoặc không cấp quyền Camera/microphone → màn cũ còn nguyên lựa chọn.
- [ ] Hệ điều hành thêm ảnh/video vừa quay vào thư viện → không trùng lặp trong selection.
- [ ] Quyền ảnh full/limited/denied, album rỗng, tải >72 item, thiếu bộ nhớ, file hỏng và quay lại app hoạt động có kiểm soát.

### 10.2. Video

- [ ] Video từ **hai nguồn** dài 59 giây hợp lệ; dài 61 giây đều buộc cắt/chọn đoạn.
- [ ] Có thể chọn đoạn giữa/cuối của video, không ép lấy đoạn đầu.
- [ ] Đoạn 60 giây và ngắn hơn hợp lệ; >60 giây bị từ chối cả trên server.
- [ ] Video đăng thành công là **file clip đã được xử lý thật**, không phải metadata + video gốc dài.
- [ ] Hỗ trợ preview, thumbnail, xoay màn hình/tạm dừng playback, lỗi codec/upload/timeout và retry.

### 10.3. Nội dung, gắn thẻ, địa điểm, quyền riêng tư

- [ ] 0/1/5/6 hashtag; duplicate khác hoa/thường; tự thêm `#`, xóa hashtag và tìm hashtag gợi ý.
- [ ] Bấm hashtag của bài đã đăng → Tìm kiếm, tab Bài viết với query `#...`.
- [ ] Gắn nhiều bạn bè → hàng ngoài hiển thị `N người`; **không gửi lời mời lịch trình**.
- [ ] Gắn một địa điểm thật, đổi địa điểm được; Place Detail mở đúng từ bài.
- [ ] Public: default EVERYONE, đủ 3 option. Private: default FOLLOWERS, chỉ 2 option. Backend không chấp nhận EVERYONE ở Private.
- [ ] Account Private và follow PENDING **không** nhìn thấy bài FOLLOWERS; ONLY_ME chỉ chủ sở hữu xem.

### 10.4. Quản lý và đồng bộ bài

- [ ] Đăng thành công từ Camera, album hoặc hỗn hợp: bài thật xuất hiện Profile, xem từ thiết bị khác, đúng media order.
- [ ] Chọn một bài trong 4 mở `[được chọn, các bài còn lại theo thứ tự gốc]`, không lặp lại bài được chọn.
- [ ] Ghim 3 bài → bài ghim lên đầu; ghim bài thứ 4 bị từ chối; bỏ ghim một rồi ghim bài khác thành công.
- [ ] Ghim 3 bài từ hai thiết bị cùng lúc vẫn không vượt 3 khi race condition.
- [ ] Menu chủ bài khác menu người xem; người không phải chủ bài bị chặn API pin/edit/delete.
- [ ] Sửa audience trên một bài, xóa bài có confirm; thông tin cập nhật ở Profile, Home, Search, Place Detail, Notifications và lịch sử thích/lưu.
- [ ] Logout/restart app, bài đã đăng thật vẫn tồn tại; ID mẫu không bao giờ gửi qua API.

---

## 11. Công việc theo vai trò và điều cần ghi nhớ

| Nhóm | Trách nhiệm |
|---|---|
| **Flutter/UI** | Giữ UI đã chốt; thêm **ô Camera đầu tiên**; chụp ảnh/quay video; quản lý quyền thiết bị; hợp nhất media nguồn Camera/album; chọn 1–12, preview, kéo sắp thứ tự; UI cắt video; gọi upload/API; tiến trình và lỗi |
| **Backend/API** | Cung cấp Post/media endpoints và DTO; xác thực tài khoản/quyền; 1–12 media; <=60s/video; hashtag <=5; audience theo Private/Public; tag user/Place; limit ghim 3; CRUD; Search/feed/cache; trả lỗi có cấu trúc |
| **Media worker/Storage** | Video trim/transcode/thumbnail, validate file và thời lượng sau xử lý; chống media mồ côi; URL public/private đúng quyền và chính sách lưu trữ |
| **QA/BA** | Test 2 nguồn media cùng giới hạn 12; quyền Camera/album; video; privacy; ghim; routing hashtag; xoá mock đúng nơi; kiểm thử trên thiết bị thật |

### Các điểm backend phải xác nhận trước khi tích hợp

- Định dạng ID (`UUID`/kiểu ID hiện hành), Post DTO, Media upload flow, trạng thái upload/processing, giới hạn kích thước/codec/định dạng file.
- Đường đi của bước cắt video: Flutter xuất clip trước khi tải lên **hay** upload bản gốc và backend/worker xử lý đoạn — cần chọn kiến trúc để không gửi file không cần thiết.
- Quy tắc thay đổi từ tài khoản Public sang Private đối với bài đã là `EVERYONE`.
- Chính sách báo lỗi/retry, dọn media chưa được gắn bài, chính sách ảnh/video được lưu trong album sau khi chụp.
- Đồng bộ Post với Feed/Home, Search, Profile, thông báo, tag/mention và các mục Hoạt động của bạn trong Settings.

**Lưu ý cuối:** Việc tạo ô Camera là **yêu cầu mới phát sinh sau gói V2**. Trong quá trình bàn giao cần tạo hạng mục Flutter riêng cho ô Camera, **không đánh dấu là backend đã xong**, và phải nghiệm thu nó trước khi coi toàn bộ Create Post hoàn tất. Đối với backend, ảnh/video từ Camera và album đều là `PostMedia` như nhau và **cùng giới hạn 12 mục/bài**, còn mỗi video sau cắt **không quá 60 giây**.
