# GoMate — Moment Backend Business Specification

> Tài liệu nghiệp vụ backend cho tính năng **Khoảnh khắc (Moments)** của GoMate.  
> Mục tiêu: cung cấp rule nghiệp vụ, mô hình dữ liệu, trạng thái và contract API đủ rõ để backend có thể triển khai mà không phải suy diễn từ giao diện.

---

## 1. Phạm vi tính năng

Moment là nội dung ảnh ngắn hạn theo mô hình social story/moment.

Các luồng chính:

1. Hiển thị danh sách bạn bè có/không có moment trên Home.
2. Chỉ cho phép xem moment của **bạn bè hai chiều**.
3. Moment chưa xem có viền xanh và có thể mở.
4. Người dùng chỉ được xem moment của người khác **một lần duy nhất**.
5. Khi xem:
   - hiển thị vị trí nếu có;
   - thả cảm xúc;
   - gửi tin nhắn cho chủ moment;
   - báo cáo;
   - tắt/ẩn moment của người đó.
6. Người dùng có thể đăng moment của mình.
7. Người dùng có trang quản lý moment của bản thân:
   - xem lịch sử;
   - xem chi tiết;
   - lưu ảnh;
   - xoá;
   - chọn nhiều ảnh để tải/xoá.
8. Chủ moment có thể xem người đã thả cảm xúc và gửi tin nhắn lại.
9. Emoji/reaction dùng một bộ thống nhất toàn ứng dụng.

---

# 2. Thuật ngữ

## 2.1. Current User
Người dùng hiện đang đăng nhập.

## 2.2. Mutual Friend
Hai người là bạn bè hai chiều khi:

- A follow B;
- đồng thời B follow A.

Chỉ người dùng thỏa điều kiện này mới xuất hiện trong thanh Moments trên Home.

## 2.3. Available Moment
Moment mà current user hiện còn được phép xem.

Tối thiểu phải thỏa:

- owner là mutual friend;
- moment chưa bị xoá;
- owner chưa bị current user mute/tắt moment;
- current user chưa xem moment đó;
- moment còn hiệu lực theo chính sách thời gian của backend.

## 2.4. Viewed Moment
Moment đã được current user mở/xem và được backend ghi nhận.

Rule đã chốt:

> Moment của người khác chỉ được xem **một lần duy nhất**. Sau khi đã xem, người dùng không được mở lại moment đó.

## 2.5. Active Moment
Moment của chính current user đang còn trong khoảng thời gian hiển thị công khai.

---

# 3. Quan hệ người dùng và quyền xem

## 3.1. Rule hiển thị trên Home

Thanh Moments chỉ lấy:

```text
currentUser follows friend
AND
friend follows currentUser
```

Không hiển thị:

- người current user chỉ follow một chiều;
- follower một chiều;
- người lạ;
- tài khoản không còn quan hệ mutual.

Avatar của chính current user luôn ở vị trí đầu tiên.

## 3.2. Rule sắp xếp

Sau avatar của current user:

### Nhóm A — Có moment chưa xem
Sắp xếp theo:

```text
latestAvailableMoment.createdAt DESC
```

Người có moment mới nhất đứng trước.

### Nhóm B — Không có moment chưa xem
Hiển thị sau nhóm A.

Backend nên trả thứ tự ổn định để UI không nhảy vị trí bất thường. Có thể giữ theo:
- thứ tự quan hệ hiện tại;
- hoặc interaction recency;
- hoặc name/order đã có của hệ thống.

Backend không nên để client tự suy luận toàn bộ việc sắp xếp từ nhiều endpoint rời rạc.

---

# 4. Rule viền xanh

## 4.1. Có viền xanh

Friend có viền xanh khi:

```text
availableMomentCount > 0
```

## 4.2. Không viền xanh

Không có viền xanh khi:

```text
availableMomentCount == 0
```

Bao gồm:
- không có moment;
- tất cả moment đã xem;
- moment hết hạn;
- user đã mute moment của friend;
- moment đã bị xoá.

## 4.3. Khả năng click

- Avatar friend có viền xanh → click được.
- Avatar friend không viền xanh → không mở viewer.
- Avatar current user → luôn dùng để đi vào flow tạo/quản lý moment.

---

# 5. Nghiệp vụ xem Moment

## 5.1. Mở viewer

Client gửi owner/user đang được chọn hoặc moment đầu tiên.

Backend trả hàng đợi moment current user còn được xem.

Ưu tiên:

1. moment chưa xem của user được chọn;
2. các moment chưa xem tiếp theo của cùng user;
3. sau khi hết → chuyển sang user tiếp theo theo thứ tự Home.

## 5.2. Xem một lần

Ngay khi một moment được xác định là đã xem, backend ghi:

```text
viewerId
momentId
viewedAt
```

Sau đó:

```text
GET available moments
```

không được trả moment đó cho viewer nữa.

### Khuyến nghị thời điểm mark viewed

Backend/API nên hỗ trợ explicit action:

```text
POST /moments/{momentId}/view
```

Client gọi khi moment thực sự được hiển thị trong viewer.

Không nên chỉ dựa vào việc fetch dữ liệu để tính là đã xem.

## 5.3. Hết moment của một owner

Nếu còn owner tiếp theo:
- viewer chuyển tiếp owner tiếp theo.

Nếu hết toàn bộ:
- viewer đóng;
- Home refresh state;
- viền xanh tương ứng biến mất.

---

# 6. Thời gian hiệu lực

UI hiện có nhóm:

```text
24 giờ qua
Tháng 9
Tháng 8
...
```

Nghiệp vụ social hiện tại được thiết kế theo mô hình moment ngắn hạn.

### Rule đã chốt

```text
activeWindow = 24 giờ kể từ createdAt
```

Trong 24 giờ kể từ `createdAt`:
- mutual friends có thể thấy moment nếu họ chưa xem và không mute owner;
- moment có thể xuất hiện với viền xanh trên Home.

Sau đúng 24 giờ:
- moment không còn được trả cho bạn bè;
- không còn xuất hiện trong available queue;
- không còn tạo viền xanh đối với bạn bè;
- nhưng **vẫn được giữ trong thư viện cá nhân của owner**.

Thư viện cá nhân lưu **toàn bộ khoảnh khắc của chính người dùng**, không phụ thuộc mốc 24 giờ, cho đến khi chính owner xoá moment đó.

---

# 7. Tạo Moment

## 7.1. Input tối thiểu

Một moment cần:

```text
ownerId
mediaId / mediaUrl
createdAt
locationText? / location metadata?
```

## 7.2. GPS

Rule đã chốt:

- Khi user đăng moment, hệ thống lấy GPS/vị trí để cập nhật thông tin ở header.
- Backend chịu trách nhiệm lưu và trả location.
- UI chỉ render dữ liệu backend trả về.

Có thể lưu:

```text
latitude
longitude
locationLabel
placeId?
```

Backend nên ưu tiên trả một field dùng trực tiếp:

```json
{
  "locationText": "Hồ Xuân Hương, Đà Lạt"
}
```

Nếu không xác định được:

```json
{
  "locationText": null
}
```

UI sẽ hiển thị:

```text
Không tìm thấy vị trí
```

## 7.3. Media

Frontend hiện mới hoàn thiện UI; flow capture/upload thật sẽ nối sau.

Backend cần hỗ trợ:
- upload media;
- tạo moment sau khi upload thành công;
- trả URL/id ổn định;
- không tạo moment nếu upload media thất bại.

---

# 8. Moment của bản thân

Owner có quyền:

- xem toàn bộ lịch sử moment của mình;
- xem detail;
- xem reactions;
- lưu/download media;
- xoá một moment;
- xoá nhiều moment;
- tải nhiều moment.

Owner **không bị rule “xem một lần”** đối với moment của chính mình.

Moment của owner được lưu trong thư viện cá nhân kể cả sau khi quá 24 giờ. Thời hạn 24 giờ chỉ giới hạn việc **bạn bè xem Moment**, không giới hạn lịch sử cá nhân.

---

# 9. Trang quản lý Moment

## 9.1. Grouping và lưu trữ thư viện cá nhân

Thư viện của owner lưu **tất cả khoảnh khắc của chính owner**, bao gồm cả moment đã quá 24 giờ.

Moment chỉ hết quyền xem của bạn bè sau 24 giờ; không tự biến mất khỏi thư viện cá nhân.

Backend có thể trả flat list, client group theo thời gian, nhưng response phải có đầy đủ:

```text
createdAt
```

UI hiện group:

```text
24 giờ qua
Tháng <n>
```

Moment chỉ biến mất khỏi thư viện khi owner chủ động xoá.

## 9.2. Selection mode

Selection mode là state UI.

Backend chỉ cần hỗ trợ batch operation.

### Batch delete

Ví dụ:

```text
DELETE /moments/batch
```

body:

```json
{
  "momentIds": ["m1", "m2"]
}
```

Response nên trả:

```json
{
  "requested": 2,
  "deleted": 2,
  "failed": []
}
```

## 9.3. Download

Download/save ảnh là thao tác thiết bị/client.

Backend chỉ cần:
- trả media URL có quyền truy cập;
- hoặc endpoint download hợp lệ.

---

# 10. Xoá Moment

## 10.1. Single delete

Chỉ owner được xoá moment của mình.

Sau khi xoá:

- moment bị **xoá hoàn toàn**;
- biến mất khỏi Home của tất cả viewer;
- không còn trong available queue;
- không còn trong thư viện/history của owner;
- không có thùng rác;
- không có chức năng restore;
- backend không dùng soft-delete để người dùng có thể khôi phục lại moment.

Backend phải xoá bản ghi moment và xử lý xoá media/association liên quan theo chính sách lưu trữ của hệ thống.

UI hiển thị snackbar xác nhận sau thành công.

## 10.2. Batch delete

Chỉ các moment thuộc current user mới được xử lý.

Backend bắt buộc kiểm tra ownership từng id.

Không tin danh sách ID từ client.

---

# 11. Reaction / Emoji

## 11.1. Bộ reaction

Hệ thống dùng một bộ emoji thống nhất toàn app.

Default quick reactions ban đầu:

```text
❤️ Heart
😂 Haha
😮 Wow
```

Có thể mở rộng:

```text
🔥 Fire
👏 Clap
😍 Love
😢 Sad
😡 Angry
```

Backend không nên lưu emoji Unicode làm business key.

Nên lưu enum/code:

```text
HEART
HAHA
WOW
FIRE
CLAP
LOVE
SAD
ANGRY
```

Client tự map code → emoji asset/widget.

## 11.2. Top 3 reaction của viewer

Yêu cầu sản phẩm:

- viewer hiển thị 3 emoji được người dùng đó dùng thường xuyên nhất;
- ban đầu nếu chưa có lịch sử → Heart, Haha, Wow.

Backend cần lưu thống kê reaction usage theo user hoặc có endpoint trả:

```json
{
  "quickReactions": ["HEART", "HAHA", "WOW"]
}
```

### Có thể triển khai sau

Nếu chưa triển khai ranking:
- backend có thể chưa trả field;
- UI fallback Heart/Haha/Wow.

## 11.3. Thả reaction

Một reaction cần:

```text
momentId
senderId
reactionType
createdAt
```

Owner xem được người đã reaction.

### Rule đã chốt

Sau khi reaction/emoji đã được gửi thành công:

> **Không thể xoá reaction đó.**

Backend không cung cấp chức năng undo/remove reaction cho Moment.

API Moment **không được có endpoint DELETE reaction**.

Nếu hệ thống giới hạn một reaction cho mỗi user trên mỗi moment thì có thể dùng:

```text
UNIQUE(momentId, senderId)
```

Quy tắc đổi từ emoji này sang emoji khác chưa được định nghĩa trong phạm vi hiện tại; mặc định không triển khai thao tác xoá để đổi reaction.

---

# 12. Messaging từ Moment

## 12.1. Viewer → Owner

User xem moment có thể nhập message và gửi cho owner.

Sau thành công UI hiển thị:

```text
Đã gửi tin nhắn cho <displayName>
```

## 12.2. Owner → Reactor

Trong detail của moment của bản thân:

- nếu có user thả reaction;
- owner có thể gửi message lại user đó.

## 12.3. Backend integration

Moment không nên tự tạo một hệ chat riêng.

Nên reuse messaging/conversation service hiện có.

Payload nên có context:

```json
{
  "recipientId": "user-x",
  "text": "Đẹp thế",
  "context": {
    "type": "MOMENT",
    "momentId": "moment-123"
  }
}
```

Tin nhắn gửi từ Moment **phải xuất hiện trong đoạn chat riêng (direct/private chat)** giữa hai người dùng.

Moment không tạo một hộp thư riêng. Message được lưu vào conversation riêng hiện có và kèm context Moment để UI chat có thể hiển thị nguồn/preview phù hợp.

Ví dụ context:

```json
{
  "type": "MOMENT",
  "momentId": "moment-123"
}
```

---

# 13. Mute / Tắt khoảnh khắc của người khác

## 13.1. Rule

Viewer có thể chọn:

```text
Tắt ảnh khoảnh khắc của <user>
```

Sau khi xác nhận:
- current user không thấy moment của target user nữa;
- Home target user không có available blue ring đối với current user;
- target user không bị block/follow change;
- chỉ ảnh hưởng feature Moments;
- trạng thái ẩn **không tự hết hạn**;
- target user chỉ xuất hiện lại khi current user chủ động bật lại/unmute.

## 13.2. Data model

Ví dụ:

```text
moment_mutes
- user_id
- muted_user_id
- created_at
```

Unique:

```text
(user_id, muted_user_id)
```

## 13.3. API

```text
POST /moment-mutes/{userId}
DELETE /moment-mutes/{userId}
```

Unmute/bật lại là nghiệp vụ bắt buộc để người dùng có thể khôi phục việc hiển thị Moment của target user.

Mute tồn tại vô thời hạn cho đến khi current user gọi unmute.

---

# 14. Report Moment

Moment **bắt buộc dùng chung hệ thống Report hiện có** của bài viết/nội dung social.

Không tạo report subsystem riêng cho Moment.

Request nên phân biệt target:

```json
{
  "targetType": "MOMENT",
  "targetId": "moment-123",
  "reasonCode": "..."
}
```

Report reason dùng cùng taxonomy/report flow đã có của post nếu backend hiện tại hỗ trợ.

---

# 15. Mô hình dữ liệu đề xuất

## 15.1. moments

```text
id
owner_id
media_id / media_url
created_at
updated_at
expires_at
latitude?
longitude?
location_text?
place_id?
status
```

Status tối thiểu:

```text
ACTIVE
EXPIRED
```

Không cần trạng thái `DELETED` phục vụ thùng rác vì Moment bị hard delete khi owner xoá.

## 15.2. moment_views

```text
id
moment_id
viewer_id
viewed_at
```

Constraint:

```text
UNIQUE(moment_id, viewer_id)
```

## 15.3. moment_reactions

```text
id
moment_id
sender_id
reaction_type
created_at
updated_at
```

Khuyến nghị:

```text
UNIQUE(moment_id, sender_id)
```

## 15.4. moment_mutes

```text
id
user_id
muted_user_id
created_at
```

Constraint:

```text
UNIQUE(user_id, muted_user_id)
```

---

# 16. DTO đề xuất

## 16.1. Home Moment Friend

```json
{
  "userId": "u2",
  "displayName": "ChiThanh",
  "avatarUrl": "...",
  "isMutualFriend": true,
  "availableMomentCount": 2,
  "hasAvailableMoment": true,
  "latestMomentAt": "2026-10-06T20:30:00+07:00"
}
```

## 16.2. Moment item

```json
{
  "id": "m123",
  "owner": {
    "id": "u2",
    "displayName": "ChiThanh",
    "avatarUrl": "..."
  },
  "mediaUrl": "...",
  "createdAt": "2026-10-06T20:30:00+07:00",
  "locationText": "Hồ Xuân Hương, Đà Lạt",
  "viewed": false
}
```

## 16.3. Own Moment detail

```json
{
  "id": "m123",
  "mediaUrl": "...",
  "createdAt": "...",
  "locationText": "Phố cổ, Hội An",
  "reactions": [
    {
      "user": {
        "id": "u9",
        "displayName": "Thanh",
        "avatarUrl": "..."
      },
      "type": "HEART",
      "createdAt": "..."
    }
  ]
}
```

---

# 17. API đề xuất

Tên endpoint có thể điều chỉnh theo convention backend GoMate.

```text
GET    /moments/home
GET    /moments/available
GET    /moments/users/{userId}/available

POST   /moments
POST   /moments/{momentId}/view

POST   /moments/{momentId}/reactions

GET    /moments/me
GET    /moments/{momentId}

DELETE /moments/{momentId}
DELETE /moments/batch

POST   /moment-mutes/{userId}
DELETE /moment-mutes/{userId}

POST   /reports
```

Messaging sử dụng API chat hiện có.

---

# 18. Endpoint Home tối ưu

Để tránh Home phải gọi N API:

```text
GET /moments/home
```

nên trả một lần:

```json
{
  "me": {
    "activeMomentCount": 2
  },
  "friends": [
    {
      "userId": "u2",
      "displayName": "ChiThanh",
      "avatarUrl": "...",
      "availableMomentCount": 2,
      "latestMomentAt": "..."
    }
  ]
}
```

Backend phải:
- filter mutual friend;
- filter muted;
- filter expired;
- exclude viewed moments;
- sort available friends trước.

---

# 19. Concurrency và tính nhất quán

## 19.1. View idempotent

```text
POST /moments/{id}/view
```

phải idempotent.

Gọi lại không được tạo nhiều view record.

## 19.2. Delete

Delete là **hard delete**.

Sau khi xoá thành công:
- moment không thể khôi phục;
- không tồn tại trong thư viện;
- không có trash/restore flow.

Nếu DELETE được gọi lại cho một moment không còn tồn tại:
- backend xử lý theo convention chung của hệ thống (ví dụ 404 hoặc idempotent success).

## 19.3. Reaction

Reaction đã gửi không được xoá.

Backend không cung cấp DELETE reaction.

Nếu áp dụng unique `(moment_id, sender_id)`, POST lặp lại phải tuân theo rule sản phẩm đã cấu hình; tuyệt đối không dùng thao tác delete/undo để thay đổi reaction.

---

# 20. Security

Backend bắt buộc tự kiểm tra:

### Xem moment
- viewer có mutual relation với owner?
- viewer có mute owner?
- moment còn active?
- viewer đã xem chưa?
- owner có phải viewer không?

### Quản lý own moment
- current user có phải owner?

### Reaction
- user có quyền xem/đã xem moment?
- moment có tồn tại?

### Delete
- ownership.

Không sử dụng các boolean client gửi như:

```text
isMutualFriend
isOwner
canDelete
```

làm nguồn authority.

---

# 21. Privacy

Location của moment là dữ liệu theo nội dung social.

Backend chỉ trả location cho user có quyền xem moment.

Không expose:
- GPS raw không cần thiết;
- moment expired/private cho user không hợp lệ;
- reaction list cho người không phải owner nếu product không cho phép.

---

# 22. Trạng thái UI ↔ Backend

| UI | Backend condition |
|---|---|
| Friend có viền xanh | availableMomentCount > 0 |
| Friend không viền | availableMomentCount == 0 |
| Không click được | không có available moment |
| “Không tìm thấy vị trí” | locationText == null/empty |
| Badge preview trong create screen | tổng available friend moments > 0 |
| Detail “Chưa có cảm xúc” | reactions empty |
| Viewer đóng sau ảnh cuối | available queue empty |
| Sau mute mất viền | mute active; giữ nguyên cho đến khi user unmute |
| Sau unmute | Moment của target có thể xuất hiện lại nếu còn available moment |
| Sau delete ảnh biến mất | hard delete thành công; không có trash/restore |
| Reaction đã thả | tồn tại, không có thao tác xoá/undo |
| Message gửi từ Moment | xuất hiện trong private/direct chat tương ứng |

---

# 23. Những phần backend chưa cần xử lý ngay

Frontend hiện tại có thể mock các state sau trong giai đoạn UI:

- moment viewed state;
- mute state;
- reaction state;
- delete mock;
- message success.

Khi backend hoàn thiện cần thay repository mock bằng API repository, không thay UI architecture.

---

# 24. Checklist backend hoàn thành MVP

- [ ] Mutual friend query.
- [ ] Home moments summary.
- [ ] Create moment.
- [ ] Store location.
- [ ] Available moment queue.
- [ ] Mark viewed idempotent.
- [ ] One-time viewing enforcement.
- [ ] Reaction create và enforce không cho xoá reaction.
- [ ] Owner reaction list.
- [ ] Messaging context integration vào private/direct chat.
- [ ] Moment mute + unmute tồn tại cho đến khi user bật lại.
- [ ] Report moment.
- [ ] Own moments history.
- [ ] Own moment detail.
- [ ] Single delete.
- [ ] Batch delete.
- [ ] Active-window đúng 24 giờ cho viewer + giữ lịch sử owner vô thời hạn đến khi owner xoá.
- [ ] Authorization checks.
- [ ] API DTO compatible with UI.

---

# 25. Các rule sản phẩm đã chốt cho production

1. Bạn bè chỉ được xem Moment trong **24 giờ** kể từ lúc đăng.
2. Thư viện cá nhân lưu **tất cả Moment của owner** sau 24 giờ, cho đến khi owner xoá.
3. Moment của bạn bè chỉ được xem **một lần duy nhất** đối với mỗi viewer.
4. Emoji/reaction đã gửi **không thể xoá/undo**.
5. Ẩn Moment của một người tồn tại **cho đến khi current user chủ động bật lại/unmute**.
6. Moment dùng **chung hệ thống Report** hiện có.
7. Xoá Moment là **hard delete hoàn toàn**, không có thùng rác và không restore.
8. Tin nhắn gửi từ Moment được lưu và hiển thị trong **đoạn chat riêng/direct chat** giữa hai người dùng.

Các quyết định kỹ thuật còn lại (storage provider, transaction strategy, HTTP status convention...) tuân theo convention backend chung của GoMate và không được làm thay đổi các rule sản phẩm trên.

---

## Kết luận

Backend Moment nên được xây như một feature social độc lập nhưng tái sử dụng:

- Follow/friend relation;
- Messaging;
- Report;
- Media storage;
- User/profile.

Core business rule quan trọng nhất:

```text
Mutual friend
→ Available moment
→ Blue ring
→ Viewer opens
→ Mark viewed
→ Never available again for that viewer
```

UI hiện tại đã được tách theo repository/model để backend có thể thay mock implementation bằng API thật mà không phải dựng lại giao diện.
