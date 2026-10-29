# GoMate – Backend Logic Contract cho Home Feed, Gợi ý địa điểm và Search
**Phiên bản tổng hợp:** 2026-10-06  
**Mốc frontend đã đối chiếu:** `master` – commit `f2265af02af85f4e80b98adbf85dd189252914fa`  
**Mục đích:** tài liệu bàn giao cho backend, tổng hợp logic từ:
- phần **1. Giao diện trang chính bài viết** trong file Word;
- phần **2. Khung gợi ý địa điểm** trong file Word;
- các thay đổi bổ sung đã chốt trong đoạn chat;
- logic Search đã thiết kế trước đó;
- trạng thái code frontend mới nhất hiện tại.

> Quy ước trạng thái:
>
> - **[REAL]**: frontend hiện đã gọi backend/repository thật.
> - **[MOCK]**: UI/logic đã có nhưng dữ liệu hoặc action vẫn đang local/demo.
> - **[PENDING-FE]**: backend cần chuẩn bị contract, nhưng frontend hiện còn một bước wiring chưa hoàn tất.
> - **[BACKEND-REQ]**: yêu cầu backend production phải đáp ứng.

---

# 0. Nguyên tắc kiến trúc chung

Frontend không gọi API trực tiếp trong widget.

```text
UI
↓
Feature Repository / Service
↓
ApiClient
↓
Backend
```

Các repository chính liên quan:

```text
Home Feed / Comment / Share
↓
PostInteractionRepository
↓
Backend Social

Home / Search Recommendation
↓
RecommendationRepository
↓
Recommendation backend

Search
↓
SearchRepository
↓
Search backend + Recommendation backend
```

Khi backend hoàn thiện, mục tiêu là **không phải dựng lại UI**. Backend DTO nên được map về model frontend tại repository layer.

---

# 1. GIAO DIỆN TRANG CHÍNH BÀI VIẾT

## 1.1. Feed và cấu trúc một bài viết

Mỗi Post trong feed cần tối thiểu:

```text
postId
author
location
caption
hashtags[]
media[]
likeCount
commentCount
likedByMe
savedByMe
createdAt
```

Khuyến nghị response:

```json
{
  "id": 12045,
  "author": {
    "id": 501,
    "displayName": "Thune",
    "avatarUrl": "https://...",
    "hasActiveMoment": true
  },
  "caption": "#Hashtag Một chuyến đi rất đẹp",
  "hashtags": ["#Hashtag"],
  "media": [
    {
      "id": 9001,
      "type": "IMAGE",
      "url": "https://...",
      "thumbnailUrl": "https://...",
      "order": 0
    }
  ],
  "likeCount": 120,
  "commentCount": 34,
  "likedByMe": false,
  "savedByMe": true,
  "location": {
    "label": "Thành phố Hồ Chí Minh",
    "placeId": null,
    "latitude": 10.77,
    "longitude": 106.69
  },
  "createdAt": "2026-10-06T12:00:00Z"
}
```

### Media của Post

**[BACKEND-REQ]**
- Mỗi bài viết tối đa **12 ảnh/video**.
- Thứ tự media phải được backend lưu ổn định.
- Frontend hiển thị số chấm đúng bằng số media.
- Nếu 1 media: không cần pagination dot.
- Backend nên trả `type = IMAGE | VIDEO`.
- Video nên có `thumbnailUrl`.

Frontend hiện tại đã `.take(12)` khi render.

### Feed pagination

Production không nên tải toàn bộ feed một lần.

Khuyến nghị:

```text
GET /feed?cursor=...&limit=...
```

Response:

```json
{
  "items": [],
  "nextCursor": "...",
  "hasMore": true
}
```

---

## 1.2. Like / Unlike bài viết

Người dùng có 2 cách like:

```text
Cách 1: bấm nút tim
Cách 2: double tap vào media bài viết
```

Behavior:

```text
not liked
→ like
→ heart full màu xanh
→ likeCount + 1
```

Bấm nút tim lần nữa:

```text
liked
→ unlike
→ heart outline
→ likeCount - 1
```

Double tap khi đã liked:

```text
không unlike
→ chỉ giữ liked
→ hiện animation heart
```

### Backend contract

Không nên dùng một endpoint `toggle` duy nhất vì retry có thể làm đảo trạng thái ngoài ý muốn.

Khuyến nghị idempotent:

```text
PUT    /posts/{postId}/like
DELETE /posts/{postId}/like
```

Response tối thiểu:

```json
{
  "postId": 12045,
  "likedByMe": true,
  "likeCount": 121
}
```

**[MOCK]** Code Home hiện mới cập nhật state local.

---

## 1.3. Lưu / bỏ lưu bài viết

Bấm bookmark:

```text
chưa lưu
→ lưu bài
→ icon bookmark full màu
→ snackbar "Đã lưu vào bộ sưu tập"
```

Bấm lần nữa:

```text
đã lưu
→ bỏ lưu
→ icon bookmark outline
→ snackbar "Đã gỡ khỏi bộ sưu tập"
```

Popup nhanh dùng hệ thống `GoMateSnackBar`, mặc định hiển thị **10 giây**.

Trong yêu cầu Word có action `"Xem bộ sưu tập"`. Backend cần hỗ trợ danh sách bài đã lưu dù action này hiện frontend chưa hoàn thiện điều hướng.

### Backend contract

```text
PUT    /posts/{postId}/save
DELETE /posts/{postId}/save
GET    /me/saved-posts?cursor=...
```

Response:

```json
{
  "postId": 12045,
  "savedByMe": true
}
```

**[MOCK]** Frontend hiện lưu state local trên card.

---

## 1.4. Menu 3 chấm của bài viết

Menu hiện có 2 action:

```text
Không quan tâm
Báo cáo
```

Bottom sheet dùng component chung, tap vùng xám hoặc vuốt xuống đều có thể đóng.

---

## 1.5. Không quan tâm

### UI flow

```text
3 chấm
↓
Không quan tâm
↓
bài viết bị ẩn ngay
↓
snackbar "Đã ẩn bài viết đối với bạn"
↓
Hoàn tác
```

Snackbar có action `"Hoàn tác"` và hiển thị nhanh trong 10 giây.

### Ý nghĩa business

Không chỉ ẩn duy nhất Post hiện tại.

**[BACKEND-REQ]** Action này phải tạo **negative preference signal** để giảm khả năng đề xuất:
- chính bài viết;
- nội dung tương tự;
- topic/hashtag tương tự;
- có thể giảm trọng số location/category tương tự;
- tùy recommendation model có thể cân nhắc author, nhưng không mặc định block author.

Backend nên lưu event:

```text
userId
postId
createdAt
source = HOME_FEED
```

Nếu hệ recommendation cần metadata:

```text
postTopics[]
hashtags[]
placeId
categoryIds[]
embedding/reference
```

### Backend contract

Đề xuất:

```text
POST   /posts/{postId}/not-interested
DELETE /posts/{postId}/not-interested
```

Hoặc dùng một preference endpoint tương đương.

`DELETE` dùng cho Undo.

Response:

```json
{
  "postId": 12045,
  "notInterested": true
}
```

**[MOCK]** Code hiện chỉ `_hiddenPostIndexes` local, chưa gửi backend.

---

## 1.6. Báo cáo bài viết

### Các lý do đã chốt trong UI

Backend không nên phụ thuộc label tiếng Việt. Nên dùng code ổn định:

```text
NEGATIVE_OR_VIOLENCE
NUDITY_OR_INAPPROPRIATE
SCAM_OR_SPAM
PROHIBITED_GOODS
FALSE_INFORMATION
INTELLECTUAL_PROPERTY
```

Mapping UI hiện tại:

```text
NEGATIVE_OR_VIOLENCE
→ Nội dung mang tính tiêu cực, bạo lực hoặc công kích

NUDITY_OR_INAPPROPRIATE
→ Ảnh khoả thân hoặc hoạt động không chuẩn mực

SCAM_OR_SPAM
→ Nội dung lừa đảo, gian lận hoặc spam

PROHIBITED_GOODS
→ Kinh doanh hoặc quảng bá mặt hàng vi phạm

FALSE_INFORMATION
→ Thông tin sai sự thật

INTELLECTUAL_PROPERTY
→ Vi phạm quyền sở hữu trí tuệ
```

Report sheet hiện được thiết kế chiều cao ổn định; nếu tương lai thêm nhiều lý do thì danh sách sẽ scroll bên trong.

### UI flow

```text
3 chấm
↓
Báo cáo
↓
chọn lý do
↓
gửi report
↓
snackbar "Cảm ơn bạn đã đóng góp ý kiến"
↓
action "Xem báo cáo"
```

### Backend contract

```text
POST /posts/{postId}/reports
```

Request:

```json
{
  "reasonCode": "SCAM_OR_SPAM",
  "description": null
}
```

Response:

```json
{
  "reportId": 88001,
  "postId": 12045,
  "status": "PENDING",
  "createdAt": "..."
}
```

Người dùng cần xem lịch sử report:

```text
GET /me/reports?cursor=...
GET /me/reports/{reportId}
```

Admin cần quản lý:

```text
GET   /admin/reports
GET   /admin/reports/{reportId}
PATCH /admin/reports/{reportId}
```

Status đề xuất:

```text
PENDING
REVIEWING
RESOLVED
REJECTED
```

**[MOCK]** Frontend hiện chỉ hoàn thiện flow UI, chưa gửi report thật.

---

# 1.7. Bình luận

## 1.7.1. Hiển thị comment

Mỗi comment cần:

```text
commentId
postId
user
body
createdAt
likeCount
likedByMe
isMine
replyCount
media[]
```

Response root comment nên có `replyCount`.

Ví dụ:

```json
{
  "id": "c-1001",
  "postId": 12045,
  "user": {
    "id": 501,
    "displayName": "Thune",
    "avatarUrl": "https://..."
  },
  "body": "Chỗ này đẹp quá",
  "likeCount": 2,
  "likedByMe": false,
  "isMine": false,
  "replyCount": 3,
  "media": [],
  "createdAt": "..."
}
```

### Reply collapse

Mặc định:

```text
root comment
↓
Hiển thị 3 câu trả lời
```

Không render toàn bộ reply ngay.

Khi người dùng bấm:

```text
Hiển thị 3 câu trả lời
↓
load/render replies
```

Có thể bấm:

```text
Ẩn câu trả lời
```

### Backend production nên tách:

```text
GET /posts/{postId}/comments?cursor=...
GET /comments/{commentId}/replies?cursor=...
```

Không bắt buộc trả toàn bộ replies trong request comments ban đầu.

**[MOCK]** Demo frontend hiện đang load list local rồi collapse bằng UI.

---

## 1.7.2. Like / Unlike comment

Behavior:

```text
outline heart
→ bấm
→ full heart màu xanh
→ likeCount + 1
```

Bấm lần nữa:

```text
unlike
→ likeCount - 1
```

Backend:

```text
PUT    /comments/{commentId}/like
DELETE /comments/{commentId}/like
```

Response:

```json
{
  "commentId": "c-1001",
  "likedByMe": true,
  "likeCount": 3
}
```

**[MOCK]** Current `DemoPostInteractionRepository.toggleCommentLike()` mới local.

---

## 1.7.3. Trả lời comment

UI có action:

```text
Trả lời
```

Khi reply:

```text
replyingToName = user được trả lời
parentId = root comment
```

Frontend hiện hiển thị reply dạng **1 tầng thread**.

Nếu người dùng reply vào một reply:

```text
reply mới vẫn thuộc root thread
```

Backend nên lưu:

```text
parentCommentId = rootCommentId
replyToUserId = user đang được trả lời (optional)
```

Request đề xuất:

```json
{
  "body": "@Thune Chỗ này đẹp quá",
  "parentCommentId": "c-1001",
  "replyToUserId": 501,
  "mediaIds": []
}
```

---

## 1.7.4. Viết bình luận text / ảnh

Composer mới nhất đã chốt:

### Khi chưa nhập text

Có thể hiện:

```text
camera
Viết bình luận...
emoji
gallery
```

### Khi bắt đầu nhập text

Các nút thêm media biến mất:

```text
camera / emoji / gallery
→ ẩn
```

Chỉ giữ:

```text
text field
send button
```

### Khi đã chọn ảnh trước đó

Ảnh đang chọn được preview phía trên composer:
- có nút `X` để bỏ từng ảnh;
- vẫn có thể nhập text kèm ảnh;
- khi đã nhập text thì **không thêm ảnh mới** qua nút nữa;
- ảnh đã chọn trước đó vẫn giữ.

Frontend hiện giới hạn **tối đa 6 ảnh cho một comment**.

Cho phép:

```text
text only
image only
text + image
```

Không cho phép:

```text
body rỗng + media rỗng
```

### Backend media flow

Khuyến nghị:

```text
1. upload media
2. nhận mediaId
3. create comment với mediaIds
```

Ví dụ:

```text
POST /media/uploads
POST /posts/{postId}/comments
```

Request:

```json
{
  "body": "Chỗ này đẹp quá",
  "parentCommentId": null,
  "mediaIds": ["m-1", "m-2"]
}
```

Backend validation:

```text
body optional
mediaIds optional
nhưng ít nhất 1 trong 2 phải có

max comment media = 6
```

Media response nên có:

```text
id
url
thumbnailUrl
width
height
type
```

Hiện UI comment hỗ trợ image; nếu tương lai cho video comment thì cần chốt thêm.

---

## 1.7.5. Xóa comment

Yêu cầu hiện tại:

```text
ấn giữ comment của chính mình
↓
bottom sheet GoMate
↓
Xóa bình luận
```

Backend phải kiểm tra quyền sở hữu, không tin `isMine` từ client.

Endpoint:

```text
DELETE /comments/{commentId}
```

### Root comment có replies

Current UI demo đang xử lý:

```text
xóa root
→ root biến mất
→ các reply của root cũng biến mất khỏi thread
```

Backend production phải thống nhất đúng behavior này.

Có thể:
- soft delete root + hide thread;
- hoặc cascade delete logical replies khỏi view.

Nếu backend giữ replies cho audit, API comment không được trả lại thread đã bị xóa theo behavior hiện tại.

---

# 1.8. Share bài viết

## 1.8.1. Đối tượng được phép share

Theo yêu cầu đã chốt, sheet Share chỉ lấy:
- bạn bè;
- người user đang follow;
- các đoạn chat nhóm / group conversation đủ điều kiện.

Không search toàn bộ user của hệ thống.

### Ưu tiên sắp xếp

Backend nên sort theo mức độ tương tác:

```text
interactionScore DESC
lastInteractionAt DESC
```

Có thể tính từ:
- số message gần đây;
- số lần share;
- lượt vào profile;
- reaction/reply;
- conversation recency.

---

## 1.8.2. Multi-select

Người dùng có thể chọn nhiều recipient cùng lúc.

```text
tap user/group
→ selected

tap lại
→ unselected
```

Khi có ít nhất 1 recipient:

```text
hiện composer "Soạn tin nhắn"
```

Tin nhắn:
- optional;
- có thể gửi bài viết mà không nhập message.

### Share target model

Backend nên trả unified model:

```json
{
  "targetId": "u-100",
  "targetType": "USER",
  "displayName": "Thune",
  "subtitle": "Thành phố Hồ Chí Minh",
  "avatarUrl": "https://...",
  "relation": "FRIEND",
  "conversationId": "dm-123",
  "interactionScore": 0.91
}
```

Group:

```json
{
  "targetId": "g-50",
  "targetType": "GROUP",
  "displayName": "Team Đà Nẵng",
  "avatarUrl": "https://...",
  "conversationId": "group-50",
  "interactionScore": 0.88
}
```

---

## 1.8.3. Search contact trong Share

Khi bấm thanh `"Tìm liên hệ"`:
- search realtime;
- chỉ search trong eligible share targets;
- không trả user ngoài danh sách bạn bè/follow/group hợp lệ;
- selection đang có phải được giữ khi vào/ra search mode.

Bấm `"Huỷ"`:
- clear keyword;
- quay lại grid contact;
- **không clear selected recipients**.

Endpoint đề xuất:

```text
GET /share-targets?q=...
```

Hoặc scoped theo post:

```text
GET /posts/{postId}/share-targets?q=...
```

Backend nên hỗ trợ debounce-friendly request.

---

## 1.8.4. Gửi share

Endpoint đề xuất:

```text
POST /posts/{postId}/shares
```

Request:

```json
{
  "recipients": [
    {
      "targetId": "u-100",
      "targetType": "USER"
    },
    {
      "targetId": "g-50",
      "targetType": "GROUP"
    }
  ],
  "message": "Đi chỗ này không?"
}
```

`message = null` là hợp lệ.

Response nên trả kết quả từng recipient:

```json
{
  "sentCount": 2,
  "failedCount": 0,
  "results": [
    {
      "targetId": "u-100",
      "success": true,
      "messageId": "msg-1"
    }
  ]
}
```

Frontend hiện snackbar:

```text
Đã gửi bài viết cho N người
```

**[MOCK]** `DemoPostInteractionRepository.sharePost()` hiện chưa có backend.

---

# 1.9. Địa điểm trên bài viết

## 1.9.1. Nguồn địa điểm

Ưu tiên:

```text
Nếu lúc đăng Post user chọn một Place của project
→ lưu placeId
→ label theo Place

Nếu không chọn Place
→ lưu snapshot GPS tại thời điểm đăng
→ lưu latitude + longitude + location label
```

Quan trọng:

**Không dùng GPS hiện tại của người xem để thay cho location của Post.**

Post response:

```json
{
  "location": {
    "label": "Thành phố Hồ Chí Minh",
    "placeId": 120,
    "latitude": 10.77,
    "longitude": 106.69
  }
}
```

Hoặc GPS-only:

```json
{
  "location": {
    "label": "Quận 1, TP.HCM",
    "placeId": null,
    "latitude": 10.775,
    "longitude": 106.700
  }
}
```

---

## 1.9.2. Khi người dùng bấm location

Flow đã chốt:

```text
Post
↓ tap location
MainShell
↓
chuyển selected tab sang Map
↓
bottom navbar vẫn hiển thị
↓
Map focus Place / coordinate
```

Ưu tiên focus:

```text
placeId tồn tại
→ load/focus Place

không có placeId nhưng có lat/lng
→ focus coordinate
```

Vì Home và Map nằm trong `IndexedStack`, khi quay lại Home cần giữ:
- vị trí feed;
- post đang xem;
- liked state tạm;
- saved state tạm;
- current media page.

### Trạng thái frontend mới nhất

**[PENDING-FE]**

`HomeScreen` đã có callback `onOpenPostLocation`, nhưng `MainShell` hiện vẫn khởi tạo:

```text
const HomeScreen()
```

nên callback chưa được truyền xuống. Backend vẫn nên chuẩn bị đầy đủ `placeId/lat/lng`.

---

# 1.10. Hashtag trong caption

Hashtag trong caption là clickable.

Flow:

```text
tap #Hashtag
↓
mở SearchScreen
↓
initialQuery = "#Hashtag"
initialTab = Bài viết
initialHashtags = {"#Hashtag"}
startSubmitted = true
```

UI Search hiển thị:
- keyword = hashtag;
- tab Bài viết active;
- hashtag chip đã được chọn;
- user có thể thêm/bỏ hashtag filter.

Đặc biệt:

```text
Huỷ
→ quay lại bài viết ban đầu
```

Không quay về Search Discovery trong trường hợp Search được mở từ hashtag.

### Backend requirement

Khi create/edit post:
- parse hashtags;
- normalize;
- lưu quan hệ `post_hashtag`.

Nên lưu:

```text
originalTag
normalizedTag
```

Ví dụ:

```text
#ĐàNẵng
→ normalized: #danang
```

Search backend cần hỗ trợ exact filter + text search.

---

# 1.11. Gợi ý người dùng trên Home – logic chưa nằm trong file Word

Frontend hiện có một khung user suggestion nằm xen giữa các Post.

UI:
- avatar;
- tên;
- số bạn chung;
- nút `"Theo dõi"`;
- horizontal scroll.

**[MOCK]** Current `_userSuggestions` đang hard-code.

Backend sau này nên có endpoint riêng:

```text
GET /recommendations/users?cursor=...&limit=...
```

Candidate nên loại:
- chính user;
- blocked users;
- user đã block viewer;
- account disabled;
- user đã follow nếu UI chỉ muốn “new suggestions”.

Ranking có thể dựa trên:
- mutual friends;
- mutual follows;
- cùng location;
- cùng interest;
- interaction graph;
- popularity có kiểm soát.

Response:

```json
{
  "id": 601,
  "displayName": "Thune",
  "avatarUrl": "https://...",
  "mutualCount": 2,
  "relation": "NONE",
  "reason": "2 bạn chung"
}
```

Nút Theo dõi phải gọi backend relationship thật, không chỉ đổi UI.

---

# 2. KHUNG GỢI Ý ĐỊA ĐIỂM

## 2.1. Home chỉ hiển thị tối đa 10 địa điểm

Logic hiện tại đã chốt:

```text
Home
↓
RecommendationRepository.getMine(topK: 10)
↓
lọc placeId > 0
↓
take(10)
↓
horizontal place rail
```

**[REAL]** Đây là phần đã gọi Recommendation backend thật.

Backend phải trả tối đa hoặc ít nhất đủ dữ liệu để Home hiển thị 10 item tốt nhất.

---

## 2.2. Dữ liệu recommendation

Place recommendation nên có:

```text
placeId
name
locationText
thumbnailUrl
rating
reviewCount
saveCount
category
score
displayReason
address
district
province
```

Ví dụ:

```json
{
  "placeId": 120,
  "name": "Cầu Vàng, Bà Nà Hills",
  "locationText": "Đà Nẵng",
  "thumbnailUrl": "https://...",
  "rating": 4.8,
  "reviewCount": 1200,
  "saveCount": 532,
  "category": "CHECKIN",
  "score": 0.93,
  "displayReason": "Phù hợp sở thích check-in"
}
```

---

## 2.3. Gần tôi và GPS

Current Home chỉ lấy GPS khi context/interest hiện tại chứa `"GAN_TOI"`.

Flow:

```text
user có context Gần tôi
↓
client xin current location
↓
latitude + longitude
↓
RecommendationRepository.getMine(...)
```

Nếu GPS unavailable:
- recommendation vẫn phải hoạt động;
- backend không được phụ thuộc tuyệt đối vào lat/lng.

Fallback có thể dựa vào:
- interest profile;
- selected province/city;
- popularity;
- recent behavior.

---

## 2.4. Xem tất cả

Home:

```text
Gợi ý cho bạn          Xem tất cả
```

Bấm `"Xem tất cả"`:

```text
SearchScreen
↓
DISCOVERY
↓
toàn bộ danh sách địa điểm được gợi ý
```

Search và Home phải dùng **cùng nguồn Recommendation backend**, không tạo 2 recommendation engine khác nhau.

### Current frontend

Home:

```text
topK = 10
```

Search Discovery hiện tạm:

```text
topK = 50
```

Đây chỉ là giải pháp UI tạm.

### Backend production

Không hard-limit `50`.

Nên dùng pagination/cursor:

```text
GET /recommendations/places?cursor=...&limit=20
```

Response:

```json
{
  "items": [],
  "nextCursor": "...",
  "hasMore": true
}
```

Home có thể gọi:

```text
limit = 10
```

Search Discovery:
- load first page;
- load more khi scroll.

---

## 2.5. Click địa điểm gợi ý

Bấm place card:
- mở Place Detail tương ứng `placeId`;
- không search bằng tên nếu đã có ID.

Backend Place Detail cần:

```text
GET /places/{placeId}
```

Recommendation item phải luôn có `placeId > 0`.

---

## 2.6. Recommendation feedback từ Feed

Recommendation service nên có khả năng nhận các signal từ Home:

```text
LIKE_POST
UNLIKE_POST
SAVE_POST
UNSAVE_POST
NOT_INTERESTED
UNDO_NOT_INTERESTED
OPEN_PLACE
SEARCH_PLACE
SHARE_POST
```

Không nhất thiết tất cả signal phải đồng bộ trực tiếp trong request action; có thể publish event sau khi transaction chính thành công.

Signal `"NOT_INTERESTED"` có trọng số negative mạnh hơn `"UNLIKE_POST"`.

---

# 3. SEARCH – BẢN CẬP NHẬT THEO CODE HIỆN TẠI

Search có 3 nhóm kết quả:

```text
Địa điểm
Người dùng
Bài viết
```

Ngoài ra:
- Recommendation Discovery;
- Recent Search;
- Live Search;
- Submitted Search;
- Place filters;
- Hashtag filters;
- mở Search trực tiếp từ hashtag của Post.

---

# 3.1. Kiến trúc Search

```text
SearchScreen
↓
SearchRepository
├── RecommendationRepository
├── Search API
├── Recent Search API
└── Hashtag API
```

UI không gọi API trực tiếp.

---

# 3.2. State machine

## A. DISCOVERY

Khi mở Search từ icon Home hoặc `"Xem tất cả"`:

```text
Back + Search bar
↓
Gợi ý cho bạn
↓
recommended places
```

Search bar được giữ cố định khi scroll.

Backend source:

```text
Recommendation backend
```

---

## B. EDITING

### Query rỗng

Hiển thị recent search nếu có:

```text
Gần đây
Thune      X
Biển hồ    X
```

Không có recent:
- không render section Gần đây.

### Query khác rỗng

Live Search trả đồng thời:

```text
places[]
users[]
posts[]
```

Section nào rỗng thì không render section đó.

---

## C. SUBMITTED

User bấm Search trên keyboard:

```text
save recent
↓
submitted = true
↓
tabs:
Địa điểm | Người dùng | Bài viết
```

Mở từ Search bình thường:

```text
default tab = places
```

Mở từ hashtag Post:

```text
default tab = posts
```

---

# 3.3. Search từ hashtag Post

Constructor frontend hiện hỗ trợ:

```text
initialQuery
initialTab
initialHashtags
startSubmitted
cancelReturnsToPrevious
```

Flow:

```text
tap hashtag
↓
SearchScreen(
  initialQuery = hashtag,
  initialTab = posts,
  initialHashtags = {hashtag},
  startSubmitted = true,
  cancelReturnsToPrevious = true
)
```

`Huỷ` trong flow này:

```text
Navigator.pop()
→ quay lại Post trước đó
```

Backend Search chỉ cần nhận keyword + hashtag filter; behavior quay lại là frontend concern.

---

# 3.4. SearchRepository contract cần giữ

```dart
Future<List<SearchPlaceItem>> getSuggestedPlaces();

Future<List<String>> getRecentSearches();

Future<void> saveRecentSearch(String query);

Future<void> removeRecentSearch(String query);

Future<SearchBundle> search({
  required String query,
  Set<SearchPlaceFilter> placeFilters,
  Set<String> hashtags,
});

Future<List<SearchHashtagItem>> searchHashtags(String query);
```

---

# 3.5. Search models hiện tại

## SearchPlaceItem

Frontend hiện cần:

```text
id
name
location
rating
imageUrl
description
address
reviewCount
saveCount
category
filterTags
```

## SearchUserItem

```text
id
name
subtitle
avatarUrl
relation
```

Relation hiện tại:

```text
friend
following
followsYou
none
pending
```

Mapping UI:

```text
friend      → Bạn bè
following   → Đang theo dõi
followsYou  → Theo dõi lại
none        → Theo dõi
pending     → Chấp nhận
```

## SearchPostItem

Production cần tối thiểu:

```text
id
thumbnailUrl
caption
hashtags[]
```

Current demo model vẫn còn `imageAsset`; khi nối backend nên chuyển về URL/media DTO.

## SearchHashtagItem

```text
tag
postCount
```

## SearchBundle

```text
places[]
users[]
posts[]
```

---

# 3.6. Unified Search API

Đề xuất:

```text
GET /search
```

Query params:

```text
q
types
placeFilters
hashtags
lat
lng
cursor
limit
```

Ví dụ live preview:

```text
/search?q=da&types=place,user,post&limit=5
```

Full Place tab:

```text
/search?q=da&types=place&cursor=...&limit=20
```

Post + hashtag:

```text
/search?q=%23Danang&types=post&hashtags=%23Danang
```

Backend có thể dùng endpoint riêng nếu architecture yêu cầu, nhưng `SearchRepository` phải ẩn khác biệt đó khỏi UI.

---

# 3.7. Realtime Search

User gõ:

```text
D
Da
Dan
Da Nang
```

Frontend hiện có `_searchToken` để chống response cũ ghi đè response mới.

Ví dụ:

```text
request A = "D"
request B = "Da"

B về trước
A về sau

→ bỏ A nếu token cũ
```

### Debounce

**Lưu ý current code mới nhất:** chưa có Timer debounce thực sự; query change gọi search gần như ngay.

Trước khi nối production backend nên bổ sung:

```text
debounce 250–350ms
```

Backend cũng cần:
- query nhanh;
- index text;
- timeout hợp lý;
- rate limit không quá chặt cho typeahead.

---

# 3.8. Recent Search

Current frontend behavior:
- recent được de-duplicate;
- search lại keyword cũ → đưa lên đầu;
- giới hạn **8 items**;
- xóa từng item.

Backend contract:

```text
GET    /me/recent-searches
POST   /me/recent-searches
DELETE /me/recent-searches/{id}
```

Hoặc delete bằng normalized query.

Request save:

```json
{
  "query": "Đà Nẵng"
}
```

Backend phải normalize duplicate nhưng vẫn có thể giữ original text để hiển thị.

---

# 3.9. Place Search Filter

Filter UI hiện tại dùng ID:

```text
nature
checkin
history
nearby
```

Mapping:

```text
nature  → Thiên nhiên
checkin → Checkin
history → Di tích lịch sử
nearby  → Gần tôi
```

Đây là ID trong code mới nhất, backend API nên giữ ổn định hoặc repository map rõ ràng.

Multi-filter:
- user có thể chọn nhiều filter;
- chip nào bỏ thì search lại ngay.

Current prototype logic thiên về:

```text
AND
```

Production phải chốt rõ AND/OR. Nếu không có yêu cầu khác thì giữ AND:

```text
place phải match tất cả selected filters
```

---

# 3.10. Nearby Search

Nếu có `nearby`:

```text
client lấy GPS
↓
lat/lng
↓
Search API
```

Request:

```text
lat
lng
```

Có thể thêm:

```text
radiusMeters
```

Nếu GPS unavailable:
- bỏ nearby hoặc trả state yêu cầu bật location;
- không crash toàn Search.

---

# 3.11. User Search

Search theo:
- username;
- display name.

Backend phải trả relationship state để UI không tự suy luận.

Ví dụ:

```json
{
  "id": 501,
  "name": "DaDaDa",
  "subtitle": "Thanh Thuý",
  "avatarUrl": "https://...",
  "relation": "FOLLOWING"
}
```

Security:
- loại blocked users;
- respect privacy;
- disabled/banned account không trả;
- không leak private profile fields.

---

# 3.12. Post Search

Backend phải hỗ trợ:
- caption text;
- hashtag;
- visibility;
- moderation state.

Result nên trả lightweight thumbnail, không tải full media.

```json
{
  "id": 12045,
  "thumbnailUrl": "https://...",
  "caption": "...",
  "hashtags": ["#Danang"]
}
```

---

# 3.13. Hashtag Search và filter

Bấm filter ở tab Bài viết:

```text
Hashtag bottom sheet
↓
type keyword
↓
realtime hashtag search
```

Endpoint:

```text
GET /search/hashtags?q=da
```

Response:

```json
[
  {
    "tag": "#Danang",
    "postCount": 120
  }
]
```

Chọn hashtag:

```text
selectedHashtags.add(tag)
↓
search posts lại ngay
```

Bỏ chip:

```text
selectedHashtags.remove(tag)
↓
search lại ngay
```

Nếu nhiều hashtags:
- current logic dùng `every()`;
- tức là Post phải chứa **tất cả** selected hashtags.

Backend production nên giữ semantics AND để khớp UI hiện tại.

---

# 3.14. Vietnamese normalization

Current demo frontend normalize:
- trim;
- lowercase;
- bỏ dấu tiếng Việt;
- `đ → d`.

Production logic phải nằm backend/search engine.

Các query sau nên match tương đương hợp lý:

```text
Đà Nẵng
Da Nang
đà nẵng
DA NANG
```

Hashtag cũng cần canonical form.

---

# 3.15. Empty state

Live preview:

```text
section nào không có kết quả
→ không render
```

Submitted tab:

```text
Places empty
→ Không có địa điểm phù hợp

Users empty
→ Không có người dùng phù hợp

Posts empty
→ Không có bài viết phù hợp
```

Backend chỉ cần trả array rỗng, không dùng `null` thay cho list nếu contract có thể tránh.

---

# 3.16. Search pagination

Production cần pagination cho:
- place;
- user;
- post;
- recommendation list.

Ưu tiên cursor pagination.

```json
{
  "items": [],
  "nextCursor": "...",
  "hasMore": true
}
```

Không tải toàn bộ kết quả một lần.

---

# 3.17. Search ranking

Backend quyết định ranking.

Có thể dùng:

```text
text relevance
personalization
popularity
rating
distance
freshness
relationship
behavior history
```

UI không tự sort score production.

---

# 3.18. Search security

### User result

Respect:
- block;
- privacy;
- account status;
- moderation.

### Post result

Respect:
- visibility;
- block;
- deleted status;
- moderation;
- author privacy.

### Place result

Respect:
- active status;
- approval;
- moderation.

---

# 3.19. Search analytics đề xuất

Có thể log:

```text
SEARCH_TYPED
SEARCH_SUBMITTED
SEARCH_RESULT_OPENED
SEARCH_FILTER_ADDED
SEARCH_FILTER_REMOVED
SEARCH_HASHTAG_SELECTED
SEARCH_HASHTAG_REMOVED
```

Payload:

```text
userId
query
resultType
resultId
filters
timestamp
requestId
```

Không log dữ liệu nhạy cảm không cần thiết.

---

# 3.20. Trạng thái Search trong code mới nhất

## [REAL]

```text
Suggested Places
→ RecommendationRepository
→ Recommendation backend
```

## [MOCK]

Hiện vẫn mock/local:

```text
Recent Search
User Search
Post Search
Hashtag Search
Place filter mapping
```

Current `SearchRepository`:
- `_recentSearches` local;
- `_demoUsers`;
- `_demoPosts`;
- `_hashtags`;
- place filter tags hiện được gán demo từ index.

Backend team không nên coi các list demo này là business rule.

---

# 4. CONTRACT TỔNG HỢP BACKEND

## 4.1. Post / Feed

```text
GET    /feed
GET    /posts/{postId}

PUT    /posts/{postId}/like
DELETE /posts/{postId}/like

PUT    /posts/{postId}/save
DELETE /posts/{postId}/save
GET    /me/saved-posts

POST   /posts/{postId}/not-interested
DELETE /posts/{postId}/not-interested

POST   /posts/{postId}/reports
GET    /me/reports
```

---

## 4.2. Comment

```text
GET    /posts/{postId}/comments
GET    /comments/{commentId}/replies

POST   /posts/{postId}/comments

PUT    /comments/{commentId}/like
DELETE /comments/{commentId}/like

DELETE /comments/{commentId}
```

---

## 4.3. Media

```text
POST /media/uploads
```

Backend cần support:
- post media max 12;
- comment image max 6 theo UI hiện tại;
- ordering;
- thumbnail;
- media ownership/temp token.

---

## 4.4. Share / Messaging

```text
GET  /posts/{postId}/share-targets?q=...
POST /posts/{postId}/shares
```

Eligible:
- friends;
- following;
- group conversations.

---

## 4.5. Recommendation

```text
GET /recommendations/places
GET /recommendations/users
```

Place:
- Home `limit=10`;
- Search Discovery paginated.

---

## 4.6. Search

```text
GET /search
GET /search/hashtags

GET    /me/recent-searches
POST   /me/recent-searches
DELETE /me/recent-searches/{id}
```

---

# 5. EVENT / ANALYTICS CHO RECOMMENDATION VÀ FEED

Nếu hệ thống recommendation có event pipeline, nên chuẩn hóa event:

```text
POST_VIEW
POST_LIKE
POST_UNLIKE
POST_SAVE
POST_UNSAVE
POST_COMMENT
POST_SHARE
POST_NOT_INTERESTED
POST_NOT_INTERESTED_UNDO
PLACE_OPEN
SEARCH_SUBMIT
SEARCH_RESULT_OPEN
USER_FOLLOW
```

Event chung:

```json
{
  "eventType": "POST_NOT_INTERESTED",
  "userId": 100,
  "entityType": "POST",
  "entityId": 12045,
  "timestamp": "...",
  "context": {
    "surface": "HOME_FEED"
  }
}
```

Transaction chính phải thành công trước; analytics failure không nên làm action UI fail.

---

# 6. IDEMPOTENCY VÀ CONCURRENCY

Các action có khả năng retry nên idempotent:

```text
like
save
not interested
follow
```

Ưu tiên:

```text
PUT = đặt trạng thái true
DELETE = đặt trạng thái false
```

thay vì toggle.

Share/report/create comment có thể nhận:

```text
Idempotency-Key
```

để tránh double submit khi mạng chậm.

---

# 7. ERROR CONTRACT

Backend nên trả lỗi thống nhất:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Invalid request",
  "details": {}
}
```

Nhóm error cần phân biệt:

```text
400 VALIDATION_ERROR
401 UNAUTHORIZED
403 FORBIDDEN
404 NOT_FOUND
409 CONFLICT
413 MEDIA_TOO_LARGE
422 BUSINESS_RULE_ERROR
429 RATE_LIMITED
500 INTERNAL_ERROR
```

UI không nên parse raw exception text.

---

# 8. SECURITY VÀ PERMISSION

Backend luôn tự kiểm tra:

```text
user hiện tại từ token
ownership
block relation
privacy
visibility
moderation
```

Không tin các field client như:

```text
isMine
likedByMe
savedByMe
relation
```

để authorize action.

Comment delete:
- chỉ owner hoặc moderator/admin.

Report:
- không expose reporter cho author.

Share:
- chỉ gửi tới target user có quyền message/share theo policy.

---

# 9. CÁC ĐIỂM FRONTEND HIỆN CÒN CHƯA HOÀN TẤT – BACKEND CẦN BIẾT

## 9.1. Location Post → Map

`HomeScreen` đã chuẩn bị:
- `placeId`;
- `latitude`;
- `longitude`;
- callback location.

Nhưng `MainShell` chưa wire callback sang Map.

Backend vẫn triển khai field location ngay để sau khi frontend nối xong không phải đổi API.

---

## 9.2. Search vẫn còn nhiều mock

Backend cần ưu tiên:
1. unified Search;
2. recent search;
3. user search;
4. post search;
5. hashtag;
6. place filters;
7. pagination.

---

## 9.3. Comment / Share vẫn là Demo Repository

UI đã sẵn contract nhưng backend chưa có.

Backend implementation sau này nên thay:

```text
DemoPostInteractionRepository
```

bằng repository thật mà không đổi widget.

---

## 9.4. Recommendation Search “Xem tất cả”

Current Search đang tạm `topK=50`.

Production phải chuyển sang cursor pagination.

---

# 10. THỨ TỰ BACKEND NÊN TRIỂN KHAI

## Giai đoạn 1 – Feed interaction

- [ ] feed response có viewer state;
- [ ] like/unlike Post;
- [ ] save/unsave Post;
- [ ] saved posts;
- [ ] not interested + undo;
- [ ] report + report history.

## Giai đoạn 2 – Comment

- [ ] root comments;
- [ ] reply count;
- [ ] replies pagination;
- [ ] create comment;
- [ ] comment media upload;
- [ ] like comment;
- [ ] delete own comment.

## Giai đoạn 3 – Share

- [ ] eligible share targets;
- [ ] ranking by interaction;
- [ ] share contact search;
- [ ] multi-recipient send;
- [ ] optional message;
- [ ] group conversation support.

## Giai đoạn 4 – Recommendation

- [ ] Home top 10;
- [ ] Search all pagination;
- [ ] location-aware recommendation;
- [ ] negative signal từ Not Interested;
- [ ] user suggestions.

## Giai đoạn 5 – Search

- [ ] unified place/user/post search;
- [ ] recent search;
- [ ] hashtag search;
- [ ] hashtag post filter;
- [ ] place filters;
- [ ] nearby;
- [ ] pagination;
- [ ] Vietnamese normalization;
- [ ] security filters.

---

# 11. CHECKLIST ACCEPTANCE CHO BACKEND

## Post

- [ ] 1 Post tối đa 12 media.
- [ ] Like bằng button/double tap không tạo duplicate state.
- [ ] Save state tồn tại sau restart.
- [ ] Not Interested ẩn Post và tác động recommendation.
- [ ] Undo Not Interested khôi phục preference đúng.
- [ ] Report lưu reason đúng enum.

## Comment

- [ ] Comment có `replyCount`.
- [ ] Replies load riêng khi mở.
- [ ] Like comment persisted.
- [ ] Text-only hợp lệ.
- [ ] Image-only hợp lệ.
- [ ] Text + images hợp lệ.
- [ ] Blank + no media bị reject.
- [ ] Comment media max 6.
- [ ] User chỉ xóa comment được phép.
- [ ] Xóa root xử lý thread theo behavior đã chốt.

## Share

- [ ] Chỉ trả target hợp lệ.
- [ ] Search không leak user ngoài eligible list.
- [ ] Multi-select gửi được.
- [ ] Message optional.
- [ ] Group target gửi được.
- [ ] Ranking ưu tiên contact tương tác nhiều.

## Post Location

- [ ] Post có `placeId` nếu attach Place.
- [ ] Không attach Place thì lưu GPS snapshot.
- [ ] API không phụ thuộc current viewer location.

## Recommendation

- [ ] Home tối đa 10.
- [ ] Search Discovery có pagination.
- [ ] Same recommendation source.
- [ ] GPS optional/fallback.
- [ ] Not Interested ảnh hưởng recommendation.

## Search

- [ ] Place/User/Post cùng query.
- [ ] Empty section không lỗi.
- [ ] Recent max 8 theo UI hiện tại.
- [ ] Recent de-duplicate.
- [ ] Hashtag filter AND semantics.
- [ ] `nature/checkin/history/nearby` hoạt động.
- [ ] Nearby dùng lat/lng.
- [ ] Vietnamese normalization.
- [ ] User relation trả đúng.
- [ ] Search từ hashtag mở đúng result.
- [ ] Pagination production.
- [ ] Block/privacy/moderation được áp dụng.

---

# 12. TÓM TẮT DATA FLOW TOÀN BỘ

```text
HOME
│
├── Feed
│   ├── Like / Unlike
│   ├── Save / Unsave
│   ├── Not Interested / Undo
│   ├── Report
│   ├── Comment
│   │   ├── Root comments
│   │   ├── Replies
│   │   ├── Like
│   │   ├── Text / Images
│   │   └── Delete
│   ├── Share
│   │   ├── Eligible contacts
│   │   ├── Search contacts
│   │   ├── Multi-select
│   │   └── Optional message
│   ├── Location
│   │   └── Map tab
│   └── Hashtag
│       └── Search Post tab
│
├── Place Recommendations
│   ├── Home: top 10
│   └── See All: Search Discovery + pagination
│
├── User Suggestions
│   └── Follow
│
└── SEARCH
    ├── DISCOVERY
    │   └── Recommended Places
    ├── EDITING
    │   ├── Recent Search
    │   └── Live Place/User/Post
    └── SUBMITTED
        ├── Place
        │   ├── nature
        │   ├── checkin
        │   ├── history
        │   └── nearby
        ├── User
        └── Post
            └── Hashtag filters
```

---

# 13. KẾT LUẬN

Backend nên được triển khai theo nguyên tắc:

```text
UI state
↓
Repository contract
↓
Backend API
↓
Persistence/Search/Recommendation
```

Những phần đã có backend thật hiện tại chủ yếu là:

```text
Place Recommendation
```

Những phần UI đã hoàn thành nhưng backend vẫn cần nối:

```text
Post Like
Post Save
Not Interested
Report
Comment
Comment Media
Comment Like
Comment Delete
Share
Share Contacts
User Suggestions
Recent Search
User Search
Post Search
Hashtag Search
Place Search Filter
```

Mục tiêu cuối là thay implementation repository, **không viết lại Home/Search/BottomSheet UI**.
