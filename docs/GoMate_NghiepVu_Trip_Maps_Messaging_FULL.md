# GOMATE — ĐẶC TẢ NGHIỆP VỤ TRIP, MAPS & MESSAGING

**Phiên bản tổng hợp:** 09/10/2026  
**Phạm vi:** Lịch trình cá nhân/nhóm, điểm dừng, thời gian, tối ưu tuyến đường, ghim lịch trình và định vị, Maps, Messaging và quan hệ giữa các module.  
**Mục đích:** Tài liệu thống nhất để đối chiếu UI/UX, triển khai backend và kiểm thử.  
**Nguyên tắc:** Quyết định mới nhất thay thế mọi mô tả cũ mâu thuẫn. Không tự ý thay logic backend khi công việc chỉ yêu cầu chỉnh UI/UX.

> **Độ tin cậy tài liệu:** Các mục đánh dấu **[ĐÃ CHỐT]** là quyết định đã truy xuất được từ cuộc trò chuyện “Cập nhật UIUX GoMate”. Các mục **[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** không được xem là yêu cầu mới hoặc mặc định backend đã triển khai.

---

## 1. Các thay đổi bắt buộc ưu tiên

1. **[ĐÃ CHỐT] BỎ HOÀN TOÀN PHÓ NHÓM:** Chỉ tồn tại hai vai trò trong nhóm: **nhóm trưởng** và **thành viên thường**. Backend, model, UI, màn thành viên, menu thao tác, phân quyền, xử lý rời nhóm và dữ liệu liên quan đến phó nhóm phải được rà soát. **Lưu ý trình tự:** Ghi nhận danh mục code/UI phó nhóm để xóa sạch **sau khi backend đã được xử lý**; không tùy tiện xóa trước khi phụ thuộc được giải quyết.
2. **[ĐÃ CHỐT] Ghim lịch trình phải có quyền vị trí luôn luôn và chạy nền:** Kiểm tra quyền hiện tại; nếu đã đạt yêu cầu thì không hỏi lại. Nếu chưa có, yêu cầu quyền vị trí **Always / Cho phép mọi lúc** cùng điều kiện định vị nền tương ứng. Người dùng từ chối thì **không thể ghim**.
3. **[ĐÃ CHỐT] Vị trí thành viên trong lịch trình nhóm:** Mở lịch trình nhóm có thể xem vị trí của những thành viên có dữ liệu GPS. Người không có GPS thì không hiện trên bản đồ. Trường hợp chỉ cho phép vị trí khi dùng ứng dụng, vẫn có thể hiển thị **vị trí cập nhật gần nhất** khi có dữ liệu; không trình bày như đang được cập nhật trực tiếp.
4. **[ĐÃ CHỐT] Thời gian gắn với từng vị trí trong THỨ TỰ điểm dừng**, không gắn cố định vào bản thân địa điểm. Thiếu thời gian bắt đầu thì bỏ cả thời gian kết thúc; chỉ có thời gian bắt đầu mà thiếu kết thúc thì điểm dừng được xem là **chưa có khoảng thời gian được đặt**.
5. **[ĐÃ CHỐT] Không có hai địa điểm giống nhau nằm sát nhau:** Quy tắc áp dụng cả khi thêm, sửa, xóa, kéo thả đổi thứ tự và các thao tác làm thay đổi danh sách. `A → B → A` hợp lệ; `A → A` không hợp lệ.
6. **[ĐÃ CHỐT] Tối ưu lộ trình vẫn bao gồm các điểm chưa có thời gian**, hướng tới tối ưu theo khoảng cách/km; không tự động loại các điểm thiếu giờ.
7. **[ĐÃ CHỐT] Danh sách yêu thích là một danh sách chung**, không sử dụng cấu trúc thư mục yêu thích.
8. **[ĐÃ CHỐT] Nhóm chat chỉ được tạo sau khi lịch trình nhóm tạo thành công.** Tên nhóm chat và tên lịch trình phải đồng bộ **hai chiều** khi đổi tên.
9. **[ĐÃ CHỐT] Không áp đặt thời hạn cố định cho việc duyệt GPS/GPA** (thuật ngữ ghi nhận trong cuộc trao đổi); cách duyệt/xử lý thuộc trách nhiệm backend. Frontend không tự đặt timeout nghiệp vụ.

---

## 2. Mô hình nghiệp vụ và quan hệ

### 2.1. Thực thể nghiệp vụ

| Thực thể | Ý nghĩa | Ghi chú |
|---|---|---|
| User | Người dùng GoMate | Có thể tham gia lịch trình nhóm |
| Trip / Lịch trình | Lịch trình du lịch cá nhân hoặc nhóm | Có tên, các điểm dừng theo thứ tự |
| Trip stop / Điểm dừng | Một lần xuất hiện của địa điểm trong một vị trí của danh sách | **Không đồng nhất** với thực thể Place; cùng một Place có thể xuất hiện nhiều lần không liên tiếp |
| Place / Địa điểm | Địa điểm có thông tin, vị trí, đánh giá | Được tái sử dụng trong Maps, tìm kiếm, Trip |
| Group membership | Thành viên tham gia lịch trình nhóm | Vai trò chỉ gồm trưởng và thành viên |
| Group chat | Cuộc trò chuyện tương ứng với lịch trình nhóm | Được tạo sau khi Trip nhóm thành công, tên đồng bộ hai chiều |
| Pinned trip | Lịch trình được ghim | Điều kiện tiên quyết: đủ quyền vị trí Always + nền |
| Member location | Vị trí đã nhận được của thành viên | Cần phân biệt tọa độ gần nhất và cập nhật thời gian thực |
| Favorite place | Địa điểm người dùng lưu yêu thích | Một danh sách duy nhất |

### 2.2. Trách nhiệm chính

- **Frontend/UI:** Hiển thị trạng thái và điều kiện của các thao tác, yêu cầu quyền vị trí khi cần, chống thao tác sai trên giao diện, phản hồi lỗi backend, phân biệt GPS gần nhất với GPS đang cập nhật; không tự quyết định kết quả duyệt thuộc backend.
- **Backend:** Là nguồn quyết định cuối cùng cho tính hợp lệ dữ liệu, phân quyền vai trò, tạo nhóm chat gắn với Trip, đồng bộ tên, trạng thái ghim và chính sách xử lý/duyệt GPS/GPA; kiểm tra ràng buộc khi dữ liệu được ghi.
- **Tích hợp:** Các thao tác cần được kiểm thử xuyên Trip ↔ Maps ↔ Messaging; không tạo hai nguồn trạng thái độc lập có thể lệch nhau.

---

## 3. Lịch trình (Trip)

### 3.1. Lịch trình cá nhân và nhóm

**[ĐÃ CHỐT]** Phân biệt ngữ cảnh lịch trình cá nhân với lịch trình nhóm. Với lịch trình nhóm, dữ liệu thành viên và nhóm chat được liên kết cùng Trip.

**[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** Các trường bắt buộc khi tạo Trip, quy tắc sửa/xóa Trip, giới hạn số thành viên, lời mời, trạng thái chấp nhận và thuật toán sắp xếp cụ thể không có đủ chi tiết trong phần lịch sử đã truy xuất; phải lấy từ backend hiện hành hoặc xác nhận riêng, không suy diễn.

### 3.2. Điểm dừng và thứ tự

**[ĐÃ CHỐT]** Danh sách điểm dừng là danh sách **có thứ tự**; một địa điểm có thể xuất hiện nhiều lần trong một Trip nếu không kề nhau.

| Danh sách | Hợp lệ? | Lý do |
|---|---|---|
| `A → B → C` | Có | Không trùng liên tiếp |
| `A → B → A` | Có | A lặp lại nhưng cách nhau bởi B |
| `A → A → B` | Không | A lặp liên tiếp |
| `A → B → B` | Không | B lặp liên tiếp |

**Ràng buộc bất biến:** Với danh sách `stops`, mọi cặp kề nhau `stops[i]` và `stops[i+1]` phải có `placeId` khác nhau.

Quy tắc phải được tái kiểm tra sau **mọi thao tác ảnh hưởng đến tính kề nhau**:

- Thêm điểm dừng ở đầu, giữa hoặc cuối.
- Đổi địa điểm tại điểm dừng hiện tại.
- Xóa điểm dừng (có thể khiến hai điểm trước/sau trở thành kề nhau).
- Kéo thả/reorder.
- Áp dụng kết quả tối ưu tuyến đường (nếu thay đổi thứ tự).

**Ví dụ quan trọng:** `A → B → A` đang hợp lệ. Nếu xóa `B` thì kết quả `A → A` không hợp lệ; hệ thống phải chặn hoặc áp dụng cơ chế xử lý đã được quy định ở tầng nghiệp vụ. **Không tự ý mặc định tự xóa một điểm A.**

### 3.3. Thời gian của điểm dừng

**[ĐÃ CHỐT]** Thời gian áp dụng cho **lần xuất hiện của địa điểm ở một vị trí thứ tự**; không phải thuộc tính thời gian toàn cục của `Place`.

| Dữ liệu người dùng | Cách hiểu theo nghiệp vụ |
|---|---|
| Có bắt đầu và có kết thúc | Có khoảng thời gian được đặt cho điểm dừng |
| Không có bắt đầu, có/không có kết thúc | Không đặt thời gian; loại bỏ cả giá trị kết thúc |
| Có bắt đầu nhưng không có kết thúc | Không đặt khoảng thời gian cho điểm dừng; không lưu như một lịch hẹn thời gian hoàn chỉnh |
| Cùng Place xuất hiện ở hai thứ tự khác nhau | Có thể có hai khoảng thời gian riêng tương ứng hai điểm dừng |

**Lưu ý triển khai:** Tầng UI cần tránh hiển thị một thời gian đơn lẻ như một khoảng đã được xác nhận. Backend chuẩn hóa/kiểm tra các trường thời gian theo quy tắc này.

### 3.4. Tối ưu lộ trình

**[ĐÃ CHỐT]** Mọi điểm dừng vẫn tham gia xét tối ưu kể cả chưa có thời gian. Tiêu chí được chốt là **ưu tiên tối ưu khoảng cách (km)**; không bỏ điểm thiếu giờ ra khỏi lộ trình.

Sau tối ưu phải bảo toàn:

- Tập hợp những lần xuất hiện điểm dừng (trừ thay đổi được người dùng yêu cầu và backend xác nhận).
- Ràng buộc không trùng địa điểm kề nhau.
- Mối liên hệ giữa *lần xuất hiện của điểm dừng* và khoảng thời gian của nó; không gán nhầm giờ của stop này sang một stop khác chỉ vì cùng `placeId`.

**[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** Chưa đủ chứng cứ để chốt dùng loại thuật toán nào, điểm đầu/cuối có khóa không, cách giải quyết xung đột giữa thời gian và km. Không tự thêm các chính sách này.

### 3.5. Vai trò nhóm

**[ĐÃ CHỐT]** Chỉ hai vai trò:

- **Nhóm trưởng (Leader):** Vai trò trưởng của lịch trình/nhóm.
- **Thành viên (Member):** Thành viên bình thường.

**Không còn:** Phó nhóm, co-leader, deputy leader và mọi đặc quyền hay thao tác chỉ dành riêng cho vai trò đó.

**Phần cần rà soát về phân quyền:** màn danh sách thành viên, nhãn vai trò, chọn vai trò, popup thao tác thành viên, tạo/chỉnh sửa Trip, quản lý nhóm chat, rời nhóm, giải tán/xóa nhóm, lịch trình, dữ liệu role và kiểm tra điều kiện trong code. Các quy tắc cũ như 'phó nhóm không thể rời' **không còn áp dụng**.

**[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** Chi tiết quyền của leader/member (ai được sửa Trip, thêm/xóa thành viên, chuyển trưởng, xóa nhóm) phải đối chiếu logic backend đã chốt; không tự suy từ tên vai trò.

---

## 4. Ghim lịch trình và GPS

### 4.1. Điều kiện tiên quyết bắt buộc

**[ĐÃ CHỐT]** Ghim lịch trình yêu cầu đủ điều kiện:

1. Kiểm tra trạng thái quyền truy cập vị trí của thiết bị/người dùng.
2. Nếu đã có quyền **Always / mọi lúc** và đủ khả năng định vị nền theo nền tảng thì tiếp tục thao tác ghim, **không hỏi lại**.
3. Nếu chưa đạt, hướng dẫn/yêu cầu cấp quyền tương ứng trước khi thực hiện.
4. Nếu từ chối hoặc không thể cấp đủ quyền thì **không ghim lịch trình**; thông báo rõ lý do và cách cấp quyền.
5. Không coi quyền **While Using App / khi dùng ứng dụng** là đủ cho thao tác ghim.

**Quan trọng:** Kiểm tra cả quyền ứng dụng và trạng thái dịch vụ vị trí cần thiết; triển khai theo quy tắc Android/iOS thực tế. UI không được thông báo ghim thành công khi backend hoặc hệ điều hành chưa thỏa điều kiện.

### 4.2. Xem GPS của thành viên trong lịch trình nhóm

**[ĐÃ CHỐT]** Khi vào lịch trình nhóm, người dùng có thể xem vị trí các thành viên có dữ liệu GPS khả dụng.

| Tình huống | Kết quả hiển thị |
|---|---|
| Thành viên có tọa độ cập nhật | Hiện marker vị trí |
| Không có dữ liệu GPS khả dụng | Không hiện marker người đó |
| Thành viên chỉ cấp quyền khi dùng app, đã từng gửi vị trí | Có thể hiện **vị trí gần nhất** được lưu, không gắn nhãn vị trí trực tiếp |
| Thành viên không bật quyền Always | Không mặc nhiên được phép ghim Trip; quy tắc xem GPS gần nhất vẫn tách biệt |

**Nguyên tắc phân biệt:** Quyền GPS để **ghim lịch trình** và dữ liệu GPS để **hiển thị vị trí thành viên** là hai điều kiện khác nhau, không được gộp một cách sai lệch.

**[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** Khoảng thời gian cập nhật vị trí, thời hạn 'vị trí gần nhất', quyền xem vị trí theo vai trò, cơ chế tắt chia sẻ và quy tắc bảo mật dữ liệu vị trí cần tuân theo backend và quyền riêng tư đã được thiết kế; không tự bịa giá trị phút/giờ.

### 4.3. Duyệt GPS/GPA

**[ĐÃ CHỐT]** Người dùng yêu cầu **không có thời hạn cố định** cho tác vụ duyệt được đề cập là “GPA”; việc duyệt và xác định kết quả thuộc backend.

Do thuật ngữ xuất hiện ở dạng **GPA** trong nội dung truy xuất, cần giữ nguyên ghi chú, **không tự diễn giải** đó là GPS hay một hình thức phê duyệt cụ thể. Frontend chỉ hiển thị trạng thái do backend cung cấp, không tự áp thời gian hết hạn hay auto-approve.

---

## 5. Maps — Giao diện và luồng liên quan nghiệp vụ

Các luồng Maps dưới đây là phạm vi UI/UX đã xác định trong dự án. **Không thay backend khi chỉ sửa giao diện.**

### 5.1. Bản đồ chính

- **[ĐÃ CHỐT]** Chỉ hiển thị phần/lối truy cập **lịch trình ghim** khi thực sự có lịch trình đã ghim; không tạo dữ liệu giả để làm hiện tính năng.
- Có giao diện tìm kiếm, tìm kiếm gần đây và địa điểm yêu thích.
- Yêu thích là **một danh sách**, không có thư mục con.
- Luồng tương tác địa điểm và tuyến đường phải phù hợp trạng thái hiển thị đang có.

### 5.2. Tìm kiếm địa điểm trên Maps

- Hiển thị giao diện tìm kiếm và kết quả phù hợp với dữ liệu/nguồn hiện tại.
- Có lịch sử tìm kiếm gần đây khi có dữ liệu.
- Khi mở địa điểm có thể đến phần xem trước/chi tiết theo luồng hiện hành.
- **[CẦN ĐỐI CHIẾU CODE]** Cơ chế lưu history, giới hạn số mục, thuật toán xếp hạng hoặc debounce: không tự chốt ngoài logic sẵn có.

### 5.3. Tuyến đường

- **[ĐÃ XÁC ĐỊNH PHẠM VI UI]** Có các thao tác xem tuyến đường, đảo chiều, thêm điểm dừng và kéo thả đổi thứ tự.
- Panel tổng quan tuyến đường bám vị trí thiết kế, phần nội dung dài có thể cuộn.
- Những thao tác thay thứ tự điểm dừng nếu cập nhật Trip phải đồng thời tuân thủ ràng buộc không có hai điểm cùng Place kề nhau.
- **[CẦN ĐỐI CHIẾU CODE]** Không tự thay công thức km/ETA, dịch vụ điều hướng hoặc logic tối ưu backend.

### 5.4. Chi tiết địa điểm

- Hiển thị thông tin địa điểm, ảnh, đánh giá, địa điểm/bài đăng liên quan.
- Đánh giá có phạm vi giao diện top 3, ưu tiên đánh giá của người dùng khi có, các lọc **Mới nhất / Cao nhất / Thấp nhất**.
- Xem ảnh toàn màn hình sử dụng cơ chế chung; không nhân bản nhiều photo viewer.
- Các tác vụ liên quan: yêu thích, chia sẻ, thêm vào lịch trình.
- Chi tiết địa điểm có header và các thao tác nhất quán với UI/UX mới, tránh lặp logic chọn lịch trình ở nhiều module.
- **[LƯU Ý PHẠM VI]** Thay đổi vị trí nút chỉ đường/thêm lịch trình ở các cuộc trao đổi chỉnh source khác cần đối chiếu bản thiết kế mới nhất trước khi kết luận là nghiệp vụ backend.

### 5.5. Responsive/UI chung

- Không dùng frame cố định làm khóa kích thước màn hình; bố cục responsive theo kích thước có sẵn và SafeArea.
- Component chung tái sử dụng, đặc biệt thanh tìm kiếm, header, bottom sheet, snackbar, viewer ảnh; không tạo nhiều biến thể lệch kích cỡ.
- Thiết kế xanh/trắng hiện hành, icon Lucide, đổ bóng ngoài theo design system; không tùy ý áp nền viền xám khi thiết kế là full-bleed trắng.

---

## 6. Messaging — Tin nhắn cá nhân và nhóm

### 6.1. Nguồn tạo nhóm chat từ lịch trình

**[ĐÃ CHỐT]** Trình tự nghiệp vụ:

1. Tạo **lịch trình nhóm**.
2. Chỉ khi thao tác tạo lịch trình nhóm **thành công** mới tạo/khởi tạo nhóm chat liên kết.
3. Dữ liệu liên kết chat ↔ Trip phải đảm bảo không tạo chat rời không có Trip thành công.

**[CẦN ĐỐI CHIẾU BACKEND]** Cách bảo đảm tính nhất quán khi khởi tạo chat thất bại sau khi tạo Trip thành công (transaction/retry/idempotency) thuộc backend; frontend không tự sinh một chat tạm độc lập rồi xem như đã hoàn thành.

### 6.2. Đồng bộ tên hai chiều

**[ĐÃ CHỐT]** Tên chat nhóm = tên lịch trình liên kết. Khi tên lịch trình thay đổi, tên nhóm chat cũng thay đổi; khi tên nhóm chat thay đổi, tên lịch trình cũng thay đổi.

| Nguồn thao tác | Dữ liệu cần đồng bộ |
|---|---|
| Đổi tên Trip nhóm | Tên Group Chat |
| Đổi tên Group Chat | Tên Trip nhóm |

**Yêu cầu kỹ thuật suy ra để tránh lỗi đồng bộ:** Có một nguồn dữ liệu được backend phối hợp; tránh vòng lặp sự kiện cập nhật qua lại hoặc hai tên mâu thuẫn. Quy tắc xử lý đồng thời là chi tiết triển khai backend.

### 6.3. Vai trò trong chat nhóm

**[ĐÃ CHỐT]** Cũng chỉ có nhóm trưởng và thành viên. Mọi UI riêng cho phó nhóm phải được đưa vào danh sách loại bỏ.

**[CẦN ĐỐI CHIẾU CODE]** Quyền thao tác theo role phải cùng nguồn với nhóm lịch trình; không dùng role co-leader còn sót trong chat và role member ở Trip.

### 6.4. Luồng nhắn tin hiện có cần giữ

Các thành phần đã được thiết kế trong GoMate:

- Danh sách tin nhắn cá nhân và nhóm; tìm kiếm người liên hệ.
- Phân biệt tin do bản thân gửi, tin người khác gửi đã đọc, và tin chưa đọc; badge unread.
- Chi tiết chat cá nhân/nhóm, nhập nội dung, emoji, đính kèm và nút gửi.
- Xem thành viên, đổi biệt danh, thao tác chặn/bỏ chặn trong phạm vi màn chat; xem lịch trình liên kết ở chat nhóm.
- Nhóm chỉ được khởi tạo gắn với lịch trình theo quy tắc ở mục 6.1.

**[CẦN ĐỐI CHIẾU CODE / CHƯA CHỐT]** Quyền rời/xóa nhóm, cách xử lý trưởng nhóm rời nhóm, quyền đổi biệt danh, chế độ chặn và hành vi sau khi chặn phải xác minh theo nghiệp vụ/backend mới nhất, đặc biệt sau khi loại bỏ phó nhóm. Không chép lại quy tắc cũ dành cho phó nhóm.

### 6.5. Chọn lịch trình từ nhiều ngữ cảnh

Luồng chọn/thêm lịch trình từng có kết nối từ **chi tiết chat cá nhân** và **chi tiết địa điểm**. Cần dùng một nguồn UI/logic chia sẻ thay vì giữ hai bộ picker độc lập tạo sai khác trong giao diện và trạng thái.

Việc hợp nhất này là **khuyến nghị dọn code UI** và phải kiểm tra toàn bộ usage/routes trước khi xóa implementation cũ; không tự sửa hợp đồng repository/backend.

---

## 7. Các luồng xuyên module bắt buộc kiểm thử

### F01 — Tạo lịch trình nhóm

**Kỳ vọng:** Trip nhóm được tạo thành công → tạo chat tương ứng → hiển thị liên kết Trip/Chat và tên giống nhau. Nếu Trip tạo thất bại, không có chat nhóm được tạo từ thao tác thất bại đó.

### F02 — Đổi tên từ Trip

**Kỳ vọng:** Tên Trip cập nhật và phản ánh vào tên chat nhóm tương ứng.

### F03 — Đổi tên từ Messaging

**Kỳ vọng:** Tên nhóm chat cập nhật và phản ánh vào tên Trip tương ứng.

### F04 — Ghim khi đã đủ GPS Always + nền

**Kỳ vọng:** Không hỏi quyền lại; tiếp tục ghim theo kết quả nghiệp vụ/backend.

### F05 — Ghim khi chỉ có GPS While Using

**Kỳ vọng:** Không cho ghim trực tiếp; yêu cầu nâng quyền. Từ chối → không ghim.

### F06 — Xem vị trí nhóm

**Kỳ vọng:** Người có dữ liệu hiện marker; người không có dữ liệu không hiện; vị trí gần nhất được phân biệt với dữ liệu đang cập nhật.

### F07 — Trùng điểm liền kề khi thêm/sửa

**Kỳ vọng:** Không thể tạo `A → A`.

### F08 — Trùng điểm do xóa

**Đầu vào:** `A → B → A`; xóa `B`. **Kỳ vọng:** Không lưu kết quả `A → A`; không tự xóa A ngoài quy tắc được chốt.

### F09 — Trùng điểm do reorder/tối ưu

**Kỳ vọng:** Sau kéo thả hoặc tối ưu, không có hai stop kề nhau cùng `placeId`.

### F10 — Thiếu thời gian

**Kỳ vọng:** Xóa start sẽ bỏ cả end; có start mà chưa có end thì điểm dừng không được tính là có khoảng thời gian đầy đủ.

### F11 — Cùng địa điểm nhiều lần

**Đầu vào:** `A (lần 1) → B → A (lần 2)`. **Kỳ vọng:** Hợp lệ và thời gian của hai điểm A độc lập theo từng lần xuất hiện.

### F12 — Tối ưu với điểm chưa đặt giờ

**Kỳ vọng:** Điểm chưa có giờ vẫn được đưa vào tính toán khoảng cách; không bị loại bỏ.

### F13 — Bỏ phó nhóm

**Kỳ vọng:** Không còn nhãn, menu, nút phân quyền, enum/API mapping phó nhóm trên bản phát hành sau migration backend. Không làm mất vai trò trưởng và thành viên hiện tại.

### F14 — Danh sách yêu thích

**Kỳ vọng:** Một danh sách chung, không xuất hiện UI tạo hoặc chọn thư mục yêu thích.

---

## 8. Checklist rà soát code & dọn sạch sau cập nhật backend

### 8.1. Vai trò phó nhóm — ưu tiên cao nhất

Tìm tất cả tên tương tự: `coLeader`, `co_leader`, `deputy`, `viceLeader`, `phoNhom`, `phó nhóm`, `vice`, role enum/map, permission flags, CTA và thông báo dành cho phó nhóm.

Rà soát tại:

- Model / DTO / deserialize / serialize / enum role.
- Repository / service / request payload / response mapping.
- Trang chi tiết lịch trình nhóm, danh sách thành viên, quản lý thành viên.
- Chat detail nhóm, popup/menu thành viên, danh sách chat nhóm.
- Dialog rời nhóm, xóa/giải tán nhóm, chuyển vai trò.
- Conditional rendering, route arguments, mock/demo seed và test.

**Quy trình:** Xác định dependency → backend migrate/xóa role → cập nhật frontend theo hợp đồng mới → xóa widget/helper/file không còn được sử dụng → tìm tham chiếu còn sót → chạy phân tích/build/test. **Không xóa mù trước khi backend sẵn sàng.**

### 8.2. Các thành phần UI dễ bị trùng

- Picker tìm kiếm/chọn lịch trình từ Messages và Place Detail.
- Search bar và header trên Maps, Trip, Messaging.
- Bottom sheet/modal xác nhận và snackbar feedback.
- Fullscreen image viewer.
- Logic bố cục cố định kích thước ở trang tìm kiếm lịch trình.

### 8.3. Phân tách không được phá vỡ

- UI/UX có thể chỉnh sửa, component có thể gom dùng chung nhưng không tự thay contract backend/API.
- Không thay logic tạo Trip/chat, cập nhật tên hoặc quyền GPS chỉ để khớp ảnh UI.
- Không xóa file cho đến khi đối chiếu imports, references, routes, dependencies và trạng thái code mới nhất.
- Khi sửa lớn/nhiều file Dart, cung cấp đầy đủ file thay vì patch rời khó áp dụng.

---

## 9. Những phần chưa đủ thông tin để khẳng định là đã chốt

Danh sách này giúp người triển khai không vô tình biến giả định thành yêu cầu:

1. Chính xác các quyền CRUD và chuyển trưởng nhóm của Leader/Member; chính sách rời hoặc giải tán Trip/Group Chat sau khi bỏ phó nhóm.
2. Chi tiết việc 'duyệt GPA' (tên trạng thái, đối tượng duyệt, đầu vào/đầu ra), ngoài hai quy tắc đã rõ: backend quyết định và không có thời hạn cố định.
3. Thuật toán tối ưu km, cách ưu tiên ràng buộc lịch hẹn, điểm xuất phát/kết thúc cố định, phí di chuyển và ETA.
4. Thời hạn lưu vị trí gần nhất, chu kỳ đồng bộ vị trí, privacy/consent ngoài quyền hệ điều hành.
5. Các trạng thái Trip cụ thể, số lượng tối đa stop/member, quy định chuyển Trip cá nhân sang nhóm.
6. Chi tiết request/response API, database schema, rollback/retry khi tạo Trip thành công mà tạo chat thất bại.

Các mục này phải đối chiếu với source/backend hoặc đoạn chat nguyên văn bổ sung; **không được mặc định đã được duyệt**.

---

## 10. Tiêu chí nghiệm thu tài liệu và triển khai

- [ ] Mọi màn nhóm chỉ có **Trưởng nhóm** và **Thành viên**.
- [ ] Danh sách UI/code phó nhóm được ghi nhận và xử lý sau migration backend.
- [ ] Ghim Trip thiếu Always/background bị từ chối; đủ quyền không bị hỏi lại.
- [ ] Map Trip nhóm xử lý đúng hiện/ẩn GPS và phân biệt vị trí gần nhất.
- [ ] Không có hai điểm `placeId` giống nhau nằm liền nhau sau mọi biến đổi danh sách.
- [ ] Start/end chỉ được xem là khoảng thời gian khi có đủ cả hai; thiếu start hủy end.
- [ ] Tối ưu không loại stop chưa có thời gian; vẫn xét km.
- [ ] Chat nhóm chỉ tạo sau Trip thành công.
- [ ] Đổi tên Trip ↔ Chat đồng bộ cả hai hướng.
- [ ] Favorite không có thư mục.
- [ ] Backend chịu trách nhiệm duyệt GPS/GPA; frontend không áp thời hạn tự tạo.
- [ ] Maps, Messaging, Trip dùng chung các UI component phù hợp; layout không fixed frame.
- [ ] Không tự sửa logic backend khi yêu cầu chỉ chỉnh giao diện.

---

## 11. Thứ tự ưu tiên triển khai đề nghị

1. Chốt và migrate backend **hai role**; lập danh sách xóa phó nhóm.
2. Đồng bộ contract Trip ↔ Group Chat: thứ tự tạo và đồng bộ tên hai chiều.
3. Ràng buộc Stop / time / reorder / tối ưu km tại frontend và backend.
4. Ghim Trip, quyền vị trí Always/background; hiển thị GPS thành viên.
5. Ghép các entry point Maps ↔ Trip ↔ Messaging, thống nhất UI picker.
6. Dọn duplicate/dead code và kiểm thử hồi quy xuyên module.

*Hết tài liệu. Những mục đánh dấu chưa chốt là vùng cần xác minh, không phải nghiệp vụ mới do tài liệu tự thêm.*
