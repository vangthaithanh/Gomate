> For current DM first-send/Share/Global Block permissions, see DIRECT_MESSAGE_PRIVACY_REQUESTS.md and GLOBAL_USER_BLOCK.md. Conflicting older scoped-block or create-on-open descriptions below are SUPERSEDED.

# GoMate — Message Backend Business Specification

> Tài liệu nghiệp vụ backend cho module **Tin nhắn (Messages)** của GoMate.  
> Đây là bản tổng hợp các quyết định đã chốt trong quá trình thiết kế và triển khai UI/UX sau tài liệu Moment trước đó.
>
> Mục tiêu: khi nối backend, team chỉ thay data source/repository, không phải suy diễn lại business rule từ giao diện.

---

# 1. Phạm vi module

Module Message thay thế hoàn toàn feature **Explore** ở tab thứ 2 của MainShell.

Các phạm vi chính:

1. Danh sách conversation.
2. Tìm người dùng và nhóm chat.
3. Direct/private chat.
4. Group chat.
5. Tin nhắn đang chờ (message request).
6. Trạng thái đọc/chưa đọc.
7. Block/unblock.
8. Mute/unmute notification.
9. Search trong đoạn chat.
10. Nickname theo conversation.
11. Media/video/link trong conversation.
12. Report.
13. Liên kết conversation với lịch trình.
14. Group chat gắn bắt buộc với group itinerary.
15. Quản lý role và member của group.
16. Invite member/pending invitation.
17. Tin nhắn phát sinh từ Moment.
18. Chia sẻ bài viết tới user hoặc group chat.

---

# 2. Thuật ngữ

## 2.1. Direct Conversation

Conversation giữa hai người dùng.

```text
type = DIRECT
```

Một cặp user không được tạo nhiều direct thread độc lập một cách vô tình.

Nếu tìm một user:

```text
accepted direct tồn tại
→ mở accepted direct

không có accepted direct
nhưng có pending request
→ mở pending request

không có conversation
→ tạo direct thread mới
```

---

## 2.2. Group Conversation

Conversation nhiều thành viên.

```text
type = GROUP
```

Group chat của GoMate **không được tạo độc lập**.

Business rule bắt buộc:

```text
Tạo group itinerary
        ↓
đồng thời tạo group conversation
```

Mỗi group conversation phải có:

```text
linkedItineraryId != null
```

---

## 2.3. Pending Message / Message Request

Direct conversation chưa được người nhận chấp nhận.

```text
isPending = true
```

Pending request vẫn là một conversation thật:
- có lịch sử message;
- có sender;
- có block state;
- có thể report;
- có thể search/xem detail;
- nhưng chưa trở thành conversation thông thường cho đến khi được accept.

---

## 2.4. Blocked Conversation

Direct conversation có:

```text
isBlocked = true
```

Block **không đồng nghĩa delete**.

Conversation, lịch sử và trạng thái pending/accepted phải được giữ nguyên.

---

# 3. Model nghiệp vụ cốt lõi

## 3.1. Conversation

Backend nên có các field tương đương:

```text
id
type: DIRECT | GROUP
title
coverMediaId?
createdAt
updatedAt

lastMessageId?
lastMessageAt?
```

Các state theo user không nên chỉ lưu trực tiếp trên conversation chung nếu có nhiều user; backend thực tế nên tách participant state.

UI hiện dùng conceptual state:

```text
unreadCount
isPending
isMuted
isBlocked
linkedItineraryId?
```

---

## 3.2. Participant

```text
conversationId
userId
role
nickname?
joinedAt
leftAt?
notificationMuted
```

Group role:

```text
MEMBER
DEPUTY
LEADER
```

Direct chat không cần group role.

---

## 3.3. Message

```text
id
conversationId
senderId
type
text?
media?
createdAt
```

Message type backend có thể mở rộng:

```text
TEXT
IMAGE
VIDEO
LINK
MOMENT_CONTEXT
SYSTEM
ITINERARY_CONTEXT
```

UI hiện tập trung vào text + media/link mock.

---

# 4. Danh sách Messages chính

## 4.1. Chỉ hiển thị accepted conversation

Main list:

```text
isPending = false
```

Pending request không trộn vào main list.

---

## 4.2. Preview luôn dựa trên message cuối

Conversation row luôn hiển thị message/event cuối cùng.

### Tin cuối do current user gửi

Hiển thị:

```text
Đã gửi <time>
```

Ví dụ:

```text
Đã gửi 4 giờ trước
```

### Tin bạn gửi, đã đọc

Hiển thị nội dung cuối bình thường:

```text
Nhớ sửa lại nhe  •  3 ngày
```

### Tin bạn gửi, chưa đọc

Tên và preview đậm.

Unread presentation:

```text
1 tin nhắn mới
2 tin nhắn mới
...
5 tin nhắn mới
5+ tin nhắn mới
```

Rule:

```text
unreadCount <= 5 → "{n} tin nhắn mới"
unreadCount > 5  → "5+ tin nhắn mới"
```

Có dot xanh bên phải.

---

# 5. Read / unread

Backend nên lưu per-user read cursor, ví dụ:

```text
conversation_participant.lastReadMessageId
conversation_participant.lastReadAt
```

Không cần update từng message boolean cho production nếu dùng cursor.

## 5.1. Accepted chat

Khi current user mở accepted conversation:
- mark read;
- unreadCount về 0.

## 5.2. Pending request

Mở pending request **không được coi là accepted**.

Việc current user xem request không làm sender có quyền tương tác như accepted chat.

Chỉ sau:

```text
Accept request
```

conversation mới chuyển sang trạng thái chat thường.

---

# 6. Tin nhắn đang chờ — rule đã chốt

## 6.1. Entry luôn tồn tại

Trên MessageScreen, mục:

```text
Tin nhắn đang chờ
```

**luôn hiển thị**, kể cả pending count = 0.

Nếu không có request:

```text
Không có tin nhắn chờ nào
```

---

## 6.2. Pending list

Mỗi row luôn hiển thị:
- sender;
- avatar;
- message cuối;
- thời gian;
- unread indicator nếu phù hợp.

---

## 6.3. Accept request

### Accept từ danh sách quản lý

Chọn một hoặc nhiều:

```text
Chấp nhận (n)
```

Sau khi thành công:

```text
isPending = false
```

Các conversation được chuyển sang main Messages.

UI trở về màn Messages chính.

### Accept ngay trong pending chat

Không tạo route/thread mới.

Conversation hiện tại chỉ đổi:

```text
isPending: true → false
```

Người dùng **vẫn ở chính đoạn chat đang xem**.

Footer tự chuyển:

```text
Accept/Delete actions
→ normal composer
```

---

## 6.4. Delete pending

Delete request là hành động khác Block.

```text
Delete pending
→ request bị xoá khỏi Pending
```

Có confirm trước.

Sau delete:
- conversation request hiện tại biến mất;
- không có restore UI;
- một request mới trong tương lai từ user đó có thể được backend tạo lại theo policy messaging.

---

# 7. Block / Unblock — rule đã chốt

## 7.1. Block accepted direct chat

Khi block:

```text
isPending giữ nguyên false
isBlocked = true
```

Không được:
- xoá conversation;
- xoá history;
- tạo thread khác.

Sau block:
- conversation vẫn ở main Messages;
- history vẫn xem được;
- composer bị khoá;
- call/video bị disable/gray;
- UI hiển thị CTA `Bỏ chặn`.

Backend phải từ chối gửi message mới trong direct conversation khi blocker vẫn đang block peer.

---

## 7.2. Block pending request

Đây là rule đã sửa và chốt cuối cùng:

```text
isPending = true
isBlocked = false
       ↓ Block
isPending = true
isBlocked = true
```

Request **không được biến mất**.

Nó vẫn nằm trong:

```text
Tin nhắn đang chờ
```

Mở lại request:

```text
Bạn đã chặn <user>
[Bỏ chặn]
```

---

## 7.3. Unblock pending

```text
isPending = true
isBlocked = true
       ↓ Unblock
isPending = true
isBlocked = false
```

Sau đó UI trở lại:

```text
[Chấp nhận] [Xoá]
```

Unblock **không tự accept request**.

---

## 7.4. Unblock accepted direct

```text
isBlocked = false
```

Composer và các interaction bình thường hoạt động trở lại.

---

# 8. Search liên hệ / group chat

Search Messages phải tìm đồng thời:

```text
USER
GROUP CONVERSATION
```

Không tạo một tab search riêng.

## 8.1. Search user

Match:
- display name;
- subtitle/profile metadata phù hợp.

Tap user:

```text
accepted direct exists
→ open it

else pending direct exists
→ open the pending request

else
→ create/open empty direct conversation
```

## 8.2. Search group

Match:
- group title;
- member name;
- member nickname.

Tap:

```text
open group conversation
```

Pending request không hiển thị thành một loại target riêng trong search.

---

# 9. Direct chat

## 9.1. Empty chat

Conversation mới chưa có message:

```text
message body trống bình thường
```

Không hiển thị placeholder gây nhiễu.

## 9.2. Header

Thông tin:
- back;
- avatar;
- display name/nickname;
- activity status;
- call;
- video.

Call/video hiện mới là UI hook, backend có thể nối sau.

## 9.3. Composer

Hiện hỗ trợ:
- text input;
- send;
- UI icons cho camera/mic/emoji/image.

Media/voice/call backend được nối sau.

---

# 10. Group chat

## 10.1. Avatar

Nếu có group cover:

```text
render cover như avatar thường
```

Nếu không có cover:

```text
render stacked member avatars
```

---

## 10.2. Incoming message

Tin từ thành viên khác phải hiển thị:
- display name;
- nickname nếu có;
- role indicator nếu có.

### Leader

```text
key màu xanh
```

### Deputy

```text
key màu xám
```

### Member

Không có key.

Tin của current user không cần hiển thị sender name trên bubble.

---

# 11. Group chat ↔ Itinerary

Rule bắt buộc:

```text
Group conversation <-> Group itinerary
```

Không tồn tại group conversation hợp lệ mà:

```text
linkedItineraryId == null
```

## 11.1. Tạo nhóm

Không có API:

```text
POST /group-chat-only
```

Theo nghiệp vụ hiện tại.

Nên triển khai transaction:

```text
Create group itinerary
→ create conversation
→ assign leader = itinerary creator
→ link conversationId ↔ itineraryId
→ commit
```

Nếu một bước thất bại, rollback.

## 11.2. Xem lịch trình

Nút `Xem lịch trình` mở đúng itinerary gắn với group.

UI Trip Detail thật sẽ nối sau; hiện frontend dùng placeholder.

---

# 12. Role trong group

Có 3 role:

```text
MEMBER
DEPUTY
LEADER
```

---

## 12.1. MEMBER

Được:
- chat;
- xem members;
- xem itinerary;
- tìm kiếm chat;
- nickname;
- report;
- mute;
- xem media/link;
- rời nhóm.

Không được:
- invite member;
- remove member;
- promote/revoke;
- rename group.

---

## 12.2. DEPUTY

Được:
- toàn bộ quyền member;
- invite member;
- remove **member thường**;
- rename group.

Không được:
- remove leader;
- remove deputy;
- promote member thành deputy;
- revoke deputy;
- cancel pending invite theo quyền leader;
- delete group.

Deputy hiện được phép **rời nhóm**.

---

## 12.3. LEADER

Leader là người tạo group itinerary.

Được:
- rename group;
- invite member;
- cancel pending invitation;
- remove member;
- remove deputy;
- promote member → deputy;
- revoke deputy → member;
- delete group + linked itinerary.

Không được rời nhóm.

Reason:

```text
leader owns group itinerary lifecycle
```

Muốn kết thúc nhóm:

```text
Delete group
→ Delete linked itinerary
```

---

# 13. Group member list

## 13.1. Normal view

Tất cả member row hiển thị:
- avatar;
- display name;
- original name/subtitle;
- distance nếu có;
- role key.

Chevron rule:

```text
current user → không có chevron
mọi người khác → có chevron
```

Normal mode **không có selection circle**.

---

## 13.2. Management mode

Selection circle chỉ xuất hiện sau khi bấm nút quản lý.

Không reserve selection rail ở normal mode.

Frontend có animation chuyển layout nhẹ để tránh row nhảy mạnh.

---

# 14. Promote / Revoke / Remove member

## 14.1. Promote

Chỉ leader.

Chỉ chọn:

```text
role = MEMBER
```

Action:

```text
Uỷ quyền (n)
```

Sau confirm:

```text
MEMBER → DEPUTY
```

---

## 14.2. Revoke deputy

Chỉ leader.

Action:

```text
Hủy uỷ quyền
```

Sau confirm:

```text
DEPUTY → MEMBER
```

---

## 14.3. Remove member

### Leader

Có thể remove:
- MEMBER;
- DEPUTY.

Không remove chính mình bằng member-management action.

### Deputy

Chỉ remove:

```text
MEMBER
```

Không remove:
- LEADER;
- DEPUTY;
- chính mình bằng selection action.

---

# 15. Invite member

## 15.1. Candidate filter

Không trả user đã là participant.

```text
existing members
→ excluded
```

User đã được invite nhưng chưa accept:
- vẫn được hiển thị;
- ưu tiên lên đầu;
- có trạng thái invitation.

---

## 15.2. Multi select

Có thể chọn nhiều candidate:

```text
(n) Thêm
```

Selected target có thể bỏ chọn trước khi submit.

---

## 15.3. Pending group invitation

Backend cần model trạng thái invite:

```text
conversationId
inviteeId
invitedById
status: PENDING | ACCEPTED | DECLINED | CANCELLED
createdAt
```

UI hiện có conceptual `pendingInvites`.

---

## 15.4. Cancel invitation

Leader có quyền:

```text
Huỷ lời mời
```

đối với invite chưa accept.

Deputy được invite member nhưng không có quyền cancel invite theo rule UI đã chốt.

---

# 16. Mute / Unmute notification

Mute conversation:

```text
muted = true
```

Không có auto expiry.

Giữ cho đến khi user tự bật lại.

UI:
- bell → bell-off;
- `Tắt` → `Bật`;
- snackbar feedback.

Backend nên lưu per participant:

```text
conversation_participant.muted
```

---

# 17. Nickname

Nickname là context theo conversation/member.

Không thay đổi profile global.

```text
conversationId
participantId
nickname
```

UI rule:

### Chưa có nickname

```text
input empty
action = Lưu
```

### Đã có nickname và chưa sửa input

```text
input = nickname hiện tại
action = Xoá
```

### Đã có nickname nhưng user sửa text

```text
action = Lưu
```

Delete nickname:

```text
nickname = null
```

Group bubble phải ưu tiên:

```text
nickname ?? originalName
```

---

# 18. Search trong conversation

Search realtime theo text.

Backend production nên hỗ trợ:

```text
GET /conversations/{id}/messages/search?q=
```

hoặc cursor/search index nếu message lớn.

Result tối thiểu:

```text
messageId
sender
text/snippet
createdAt
```

Tap result:

```text
return to conversation
→ scroll/focus đúng messageId
```

---

# 19. Media / Video / Link

Detail conversation có 2 tab chính:

```text
Media (ảnh/video)
Link
```

Backend cần query theo message attachment type.

Ví dụ:

```text
GET /conversations/{id}/media
GET /conversations/{id}/links
```

hoặc unified endpoint có filter.

UI media grid hiển thị **full-width / full-bleed**.

---

# 20. Report

Message dùng **chung hệ thống Report** với Post và Moment.

Không tạo report subsystem riêng.

Target:

```text
DIRECT_CONVERSATION
GROUP_CONVERSATION
USER_FROM_MESSAGE_REQUEST
MESSAGE?
```

Backend có thể dùng taxonomy chung:

```json
{
  "targetType": "...",
  "targetId": "...",
  "reasonCode": "..."
}
```

---

# 21. Profile

Nút `Trang cá nhân` sẽ mở profile của user.

Frontend hiện chỉ có placeholder vì Profile Detail chưa hoàn thiện.

Backend không cần thêm nghiệp vụ riêng cho phần này ngoài userId.

---

# 22. Tin nhắn từ Moment

Rule đã chốt từ Moment:

Message gửi từ một Moment **không tạo hệ chat riêng**.

Flow:

```text
Moment
→ gửi tin nhắn
→ resolve/create direct conversation
→ insert message vào direct conversation đó
```

Message nên có context:

```json
{
  "type": "TEXT",
  "text": "Đẹp thế",
  "context": {
    "type": "MOMENT",
    "momentId": "moment-123"
  }
}
```

Conversation xuất hiện bình thường trong Messages.

---

# 23. Share Post → User / Group

Share Post search hỗ trợ:

```text
USER
GROUP
```

## 23.1. User target

Share vào direct conversation với user.

## 23.2. Group target

Share vào group conversation.

Group không cover:
- UI hiển thị stacked avatars.

Group có cover:
- UI dùng cover.

## 23.3. Selection

Search không gửi ngay khi tap.

Tap target:

```text
selected = true
→ quay về grid chính
→ target được đưa lên đầu
→ có check
```

Tap lại:
- deselect.

Sau khi user xác nhận gửi, backend insert share/message vào các conversation target.

---

# 24. Search Share Post

Repository/backend nên trả unified share target:

```text
id
type: USER | GROUP
displayName
subtitle
avatar/cover
memberPreview?
```

Search theo:
- user name;
- group title;
- optional subtitle.

---

# 25. Main navigation

Explore bị loại khỏi app navigation.

Tab 2:

```text
MessageScreen
```

Không còn:

```text
ExploreScreen
```

---

# 26. API đề xuất

Tên endpoint điều chỉnh theo convention backend GoMate.

## Conversation

```text
GET    /conversations
GET    /conversations/{id}
POST   /conversations/direct
```

## Messages

```text
GET    /conversations/{id}/messages
POST   /conversations/{id}/messages
POST   /conversations/{id}/read
GET    /conversations/{id}/messages/search
```

## Requests

```text
GET    /message-requests
POST   /message-requests/{conversationId}/accept
DELETE /message-requests/{conversationId}
```

## Block

```text
POST   /users/{userId}/block
DELETE /users/{userId}/block
```

Nếu block là global social block thì Messaging phải consume state đó; nếu chỉ message-block thì scope endpoint theo messaging.

## Mute

```text
POST   /conversations/{id}/mute
DELETE /conversations/{id}/mute
```

## Nickname

```text
PUT    /conversations/{id}/participants/{userId}/nickname
DELETE /conversations/{id}/participants/{userId}/nickname
```

## Group members

```text
GET    /conversations/{id}/members

POST   /conversations/{id}/invites
DELETE /conversations/{id}/invites/{userId}

DELETE /conversations/{id}/members/{userId}

POST   /conversations/{id}/deputies/{userId}
DELETE /conversations/{id}/deputies/{userId}

PATCH  /conversations/{id}/name
```

## Group lifecycle

```text
POST   /group-itineraries
DELETE /group-itineraries/{id}
```

Create itinerary transaction phải tạo conversation.

## Search targets

```text
GET /message-targets/search?q=
```

Có thể trả user + group unified.

## Share targets

```text
GET /share-targets/search?q=
POST /posts/{postId}/share
```

---

# 27. Authorization bắt buộc

Backend không tin role do client truyền.

Luôn resolve role từ DB.

## Group member

Không được:
- add;
- remove;
- promote;
- revoke;
- rename.

## Deputy

Không được:
- remove leader;
- remove deputy;
- promote;
- revoke;
- delete group.

## Leader

Có quyền cao nhất nhưng:
- không thể leave group;
- delete group phải xoá linked itinerary.

---

# 28. Concurrency / idempotency

## Accept pending

Idempotent.

Nếu đã accepted:
- request accept lặp lại không tạo conversation mới.

## Block

Idempotent.

```text
blocked → block lại
```

không tạo duplicate record.

## Unblock

Idempotent.

## Group invite

Unique:

```text
(conversationId, inviteeId, activePending)
```

Không tạo nhiều pending invite giống nhau.

## Promote

Chỉ MEMBER → DEPUTY.

Promote deputy lần nữa không thay đổi.

---

# 29. Dữ liệu UI hiện đang mock

Frontend hiện dùng `DemoMessageRepository`.

Mock hiện có:
- direct chat;
- group chat;
- unread/read;
- pending request;
- blocked state;
- group roles;
- linked itinerary;
- pending invitation;
- media/link;
- nickname;
- mute.

Khi backend sẵn sàng:

```text
giữ models/screens/widgets
→ thay repository/data source
```

Không dựng lại UI.

---

# 30. Dữ liệu mẫu Pending hiện tại

Để test UI, frontend seed nhiều request:

```text
Thune
Thune
DaDaDa
Thanh
Trọng Bùi
```

Đây chỉ là mock/test data, không phải business requirement.

---

# 31. State machine quan trọng

## 31.1. Pending request

```text
PENDING + UNBLOCKED
      │
      ├── Accept
      │      ↓
      │   ACCEPTED + UNBLOCKED
      │
      ├── Block
      │      ↓
      │   PENDING + BLOCKED
      │      │
      │      └── Unblock
      │             ↓
      │         PENDING + UNBLOCKED
      │
      └── Delete
             ↓
          REMOVED
```

## 31.2. Accepted direct

```text
ACCEPTED + UNBLOCKED
      │
      └── Block
             ↓
         ACCEPTED + BLOCKED
             │
             └── Unblock
                    ↓
                ACCEPTED + UNBLOCKED
```

Block không bao giờ tự chuyển:
- pending → accepted;
- accepted → pending;
- conversation → deleted.

---

# 32. Checklist backend MVP

- [ ] Conversation list.
- [ ] Direct resolve/create không duplicate.
- [ ] User + group search.
- [ ] Message list.
- [ ] Send text.
- [ ] Read cursor / unread count.
- [ ] Pending request list.
- [ ] Accept single/batch request.
- [ ] Delete request.
- [ ] Block/unblock accepted direct.
- [ ] Block/unblock pending request mà vẫn giữ request.
- [ ] Mute/unmute.
- [ ] Nickname.
- [ ] Search messages.
- [ ] Media/video/link query.
- [ ] Shared report flow.
- [ ] Moment → direct message context.
- [ ] Share post → user/group.
- [ ] Group tied to itinerary.
- [ ] Group roles.
- [ ] Rename group.
- [ ] Invite/cancel invite.
- [ ] Remove member.
- [ ] Promote/revoke deputy.
- [ ] Leave group for member/deputy.
- [ ] Prevent leader leave.
- [ ] Delete group + itinerary for leader.
- [ ] Authorization tests.
- [ ] Idempotency/concurrency tests.

---

# 33. Các phần chưa cần backend ngay

Hiện có thể tiếp tục mock:
- call;
- video call;
- voice message;
- camera/image picker;
- realtime typing indicator;
- online presence chính xác;
- push notification;
- profile detail screen;
- itinerary detail screen;
- media upload.

Khi bổ sung không được thay đổi business state machine đã chốt ở trên.

---

## Kết luận

Core Message của GoMate được xây quanh 4 nguyên tắc:

```text
1. Pending là conversation thật, không phải item tạm.
2. Block không delete conversation/request.
3. Group chat không tồn tại độc lập khỏi group itinerary.
4. UI state đọc từ conversation/repository, không suy diễn từ navigation route.
```

Repository thật sau này phải bảo toàn đúng các rule này để frontend hiện tại có thể nối backend mà không đổi luồng.
