# GOMATE KNOWLEDGE PACK — Trip, Maps & Messaging Pre-Big-Update V1

> **Ngày chốt:** 2026-10-09  
> **Mục đích:** Đây là file tri thức bắt buộc Codex phải đọc trước khi thực hiện Big Update Trip/Maps/Group Messaging.
>
> **Nguồn chính:** `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` do người dùng cung cấp.
>
> **Quy tắc ưu tiên:** Quyết định mới nhất trong file này thay thế các mô tả cũ mâu thuẫn. Không được biến các mục “chưa chốt” thành business rule mới.

---

## 1. Trạng thái hệ thống trước Big Update

Các foundation đã REAL và phải được bảo toàn:

```text
Auth / Current User
Profile / Settings real data
Real User Search
Follow / Unfollow
Mutual Friend
Direct Message V1
MongoDB Foundation
Moment Backend V1
Place / Mapbox routing foundation
Trip Core V1
AI Recommendation
```

Big Update sắp tới tập trung vào:

```text
Trip
↕
Maps
↕
Group Messaging
↕
Member Location
```

Không được rollback các module REAL ở trên khi đồng bộ UI mới.

---

# 2. QUYẾT ĐỊNH MỚI NHẤT — PHẢI XEM LÀ CANONICAL

## 2.1. Bỏ hoàn toàn vai trò Phó nhóm

Từ nay group business chỉ có:

```text
LEADER
MEMBER
```

Không còn:

```text
DEPUTY
CO_LEADER
VICE_LEADER
PHO_NHOM
```

Điều này áp dụng xuyên:

```text
Trip Group
Group Chat
Member management
Permission UI
Role model/DTO
Leave/Delete flow
```

Tuy nhiên ở bước **pre-big-update**:

```text
CHƯA xóa mù backend role cũ nếu backend migration chưa làm.
```

Phải:
1. inventory toàn bộ reference cũ;
2. ghi rõ file/enum/API/UI nào còn deputy/co-leader;
3. xử lý chính thức trong Big Update theo dependency order.

---

## 2.2. Trip Stop là một “lần xuất hiện”, không phải Place

Phân biệt:

```text
Place
= địa điểm chuẩn dùng chung toàn hệ thống.

Trip Stop
= một lần Place xuất hiện tại một vị trí cụ thể trong lịch trình.
```

Do đó:

```text
A → B → A
```

là hợp lệ.

Hai `A` trên là hai Trip Stop khác nhau:
- có thứ tự khác nhau;
- có thể có thời gian riêng;
- không được đồng nhất chỉ vì `placeId` giống nhau.

Không lưu thời gian Trip vào Place.

---

## 2.3. Không có hai Place giống nhau nằm liền nhau

Invariant:

```text
stops[i].placeId != stops[i + 1].placeId
```

Hợp lệ:

```text
A → B → C
A → B → A
```

Không hợp lệ:

```text
A → A
A → B → B
```

Invariant phải được kiểm tra lại sau:
- add;
- insert;
- edit/replace Place;
- delete;
- reorder/drag;
- optimize route.

Ví dụ:

```text
A → B → A
```

đang hợp lệ.

Nếu delete `B`:

```text
A → A
```

thì thao tác không được lưu kết quả sai.

Không tự ý xóa một trong hai `A` để “sửa hộ” user nếu business chưa quy định.

---

## 2.4. Time thuộc Trip Stop occurrence

Start/end time gắn với:

```text
TripStop
```

không phải:

```text
Place
```

Rule:

```text
start + end
→ khoảng thời gian hợp lệ.

không có start
→ bỏ/ignore cả end.

có start nhưng không có end
→ chưa có khoảng thời gian hoàn chỉnh.
```

UI không được hiển thị một start time đơn lẻ như lịch hẹn đã được xác nhận.

Hai lần cùng Place:

```text
A1 → B → A2
```

có thể có hai time range độc lập.

---

## 2.5. Route optimization

Mọi Trip Stop đều tham gia tối ưu, kể cả:

```text
stop chưa có giờ
```

Mục tiêu đã chốt:

```text
ưu tiên tối ưu khoảng cách / km
```

Không tự loại stop thiếu thời gian.

Sau optimize phải bảo toàn:
- đúng tập Trip Stop occurrence;
- time vẫn gắn đúng occurrence;
- không tạo adjacent duplicate Place;
- không tự merge hai stop cùng Place.

Các chi tiết **chưa chốt**:
- thuật toán cụ thể;
- cố định điểm đầu/cuối hay không;
- xung đột time vs km;
- traffic/ETA/cost.

Không tự invent.

---

# 3. PERSONAL TRIP vs GROUP TRIP

Hai context phải phân biệt rõ:

```text
PERSONAL TRIP
GROUP TRIP
```

Group Trip mới có:
- group membership;
- group chat linkage;
- member location.

Các field bắt buộc khi tạo Trip, giới hạn số member, invite lifecycle và chi tiết permission Leader/Member phải đối chiếu backend/current contract trong Big Update.

Không tự suy diễn ở bước pre-update.

---

# 4. PINNED TRIP

## 4.1. Điều kiện ghim

Ghim Trip yêu cầu:

```text
Location permission = ALWAYS / Allow all the time
+
background location capability phù hợp nền tảng
```

Flow:

```text
Check permission/service
    ↓
đã đủ
→ không hỏi lại
→ tiếp tục ghim

chưa đủ
→ yêu cầu/hướng dẫn cấp Always + background

user từ chối
→ KHÔNG GHIM
```

`While Using App` không đủ để ghim.

UI không được hiện “đã ghim” khi OS/backend condition chưa pass.

---

## 4.2. Pinned Trip trên Maps

Maps chỉ hiện section/entry “Lịch trình đã ghim” khi thật sự có pinned trip.

Không tạo mock Trip để làm section xuất hiện.

---

# 5. MEMBER LOCATION TRONG GROUP TRIP

Mở Group Trip/Map có thể hiển thị vị trí member nếu backend có GPS data.

Rule:

```text
Có location data
→ show marker.

Không có location data
→ không show marker.
```

Nếu member chỉ cấp `While Using App` nhưng từng gửi GPS:

```text
có thể show last known location
```

nhưng UI phải phân biệt:

```text
LAST KNOWN
```

với:

```text
LIVE / CURRENT
```

Không được gắn nhãn live nếu chỉ là tọa độ gần nhất.

**Quan trọng:**

```text
Permission để PIN TRIP
!=
Data location để HIỂN THỊ MEMBER
```

Không gộp hai rule này.

Chưa chốt:
- location refresh interval;
- max age của last-known location;
- privacy/consent chi tiết;
- ai được xem theo role.

Không tự đặt 5 phút/10 phút/1 giờ.

---

# 6. MAPS BUSINESS

## 6.1. Main Map

Giữ:
- Place/Mapbox foundation hiện tại;
- search;
- recent search nếu có source;
- favorite places;
- pinned trip entry khi thật sự tồn tại.

Favorite:

```text
1 danh sách chung
```

Không có:
- favorite folders;
- folder picker;
- collection hierarchy.

---

## 6.2. Route UI

UI có scope:
- xem route;
- reverse;
- add stop;
- drag/reorder.

Nếu thao tác đang chỉnh Trip:
- phải tuân adjacency invariant;
- không tự đổi backend distance/ETA formula;
- không đổi routing provider;
- không tự viết thuật toán optimize mới.

---

## 6.3. Place Detail

Giữ contract Place hiện tại.

Có thể:
- favorite;
- share;
- add to Trip;
- route/directions.

Picker chọn Trip từ Place Detail và Message nên hướng tới component/repository dùng chung, nhưng không refactor phá contract chỉ vì muốn gom UI.

---

# 7. GROUP CHAT ↔ GROUP TRIP

## 7.1. Group Chat không tồn tại độc lập

Canonical creation order:

```text
Create Group Trip
    ↓ SUCCESS
Create/Initialize linked Group Chat
```

Nếu Trip create fail:

```text
KHÔNG được có Group Chat từ thao tác đó.
```

Frontend không tự tạo temporary independent group chat rồi coi là thành công.

Cross-store consistency/retry/outbox/compensation là trách nhiệm Big Update backend, chưa chốt implementation cụ thể.

---

## 7.2. Một Group Chat gắn với một Group Trip

Group chat phải có linkage rõ:

```text
linkedTripId / linkedItineraryId
```

Không tạo orphan group conversation.

---

## 7.3. Đồng bộ tên hai chiều

Canonical:

```text
Rename Group Trip
→ Group Chat name cập nhật.

Rename Group Chat
→ Group Trip name cập nhật.
```

Backend phải phối hợp để tránh:
- hai tên khác nhau;
- event update loop vô tận;
- frontend giữ hai source-of-truth.

Chi tiết concurrency chưa chốt.

---

## 7.4. Role Group Chat

Group Chat cũng chỉ dùng:

```text
LEADER
MEMBER
```

Không còn deputy/co-leader.

Permission chi tiết phải dùng cùng authority với Group Trip.

Không tạo Chat role khác Trip role.

---

# 8. DIRECT MESSAGE PHẢI GIỮ NGUYÊN

Direct Message V1 hiện đã REAL.

Big Update Group Message không được phá:
- direct conversation uniqueness;
- PENDING/ACCEPTED;
- block/mute/read;
- Mongo message body;
- Moment → Direct Message context.

Group Messaging là extension mới, không phải rewrite Direct Message từ đầu.

---

# 9. GPS / GPA APPROVAL

Tài liệu gốc có thuật ngữ `GPS/GPA`.

Canonical duy nhất hiện chốt:

```text
Frontend KHÔNG áp timeout cố định.
Backend quyết định trạng thái/duyệt.
```

Không tự diễn giải `GPA` thành một nghiệp vụ khác nếu chưa xác minh.

Không invent:
- auto approve sau N phút;
- expire sau N giờ.

---

# 10. FRONTEND vs BACKEND AUTHORITY

Frontend chịu trách nhiệm:
- render đúng state;
- kiểm tra UX sớm;
- xin permission OS;
- ngăn thao tác rõ ràng sai;
- show lỗi backend;
- phân biệt last-known/live location.

Backend là final authority cho:
- Trip validity;
- roles/permissions;
- stop/time invariants;
- pinned state;
- group chat linkage;
- rename synchronization;
- member-location business policy;
- approval state.

UI không được là source-of-truth.

---

# 11. NHỮNG GÌ CHƯA CHỐT — CODEX KHÔNG ĐƯỢC TỰ BỊA

Chưa có đủ dữ liệu để chốt:

1. Exact CRUD quyền Leader/Member.
2. Leader leave / transfer leadership / dissolve policy.
3. Member limit.
4. Group invitation exact state machine.
5. Exact optimize algorithm.
6. Fixed route start/end.
7. Time-vs-distance conflict policy.
8. Member-location refresh period.
9. Last-known location TTL/age.
10. Full GPS privacy/consent model.
11. Exact GPA semantics.
12. Exact retry/rollback pattern khi Trip success nhưng Group Chat init fail.
13. Exact Trip status enum.
14. Personal → Group Trip conversion policy.

Với các mục này:

```text
inspect existing backend/current contracts
→ nếu có canonical rule thì reuse
→ nếu vẫn không có thì mark TBD
→ KHÔNG invent
```

---

# 12. CROSS-MODULE ACCEPTANCE FLOWS

## F01 — Create Group Trip

```text
Trip success
→ linked group chat created/initialized
→ names match

Trip fail
→ no group chat
```

## F02 — Rename Trip

```text
Trip rename
→ Group Chat rename
```

## F03 — Rename Group Chat

```text
Group Chat rename
→ Trip rename
```

## F04 — Pin with Always permission

```text
already allowed
→ no re-prompt
→ pin flow continues
```

## F05 — Pin with While Using only

```text
not enough
→ ask/guide Always
→ reject = no pin
```

## F06 — Group member location

```text
has current GPS → marker
no GPS → no marker
last known only → marker labeled/styled as last-known, not live
```

## F07 — Adjacent duplicate via add/edit

```text
A → A
→ reject
```

## F08 — Adjacent duplicate caused by delete

```text
A → B → A
delete B
→ reject result A → A
```

## F09 — Adjacent duplicate via reorder/optimize

Result must still satisfy invariant.

## F10 — Incomplete time

```text
no start → remove end
start without end → no complete interval
```

## F11 — Repeated non-adjacent Place

```text
A1 → B → A2
→ valid
→ A1/A2 times independent
```

## F12 — Optimize unscheduled stop

Unscheduled stop remains in optimization.

## F13 — Deputy removal

After backend migration:
- no deputy enum;
- no deputy label;
- no deputy menu/action;
- no deputy-specific permission.

## F14 — Favorites

One list only.

---

# 13. PRE-BIG-UPDATE OBJECTIVE

Bước đồng bộ trước Big Update phải tạo ra trạng thái:

```text
LATEST xuanthu UI
+
CURRENT REAL integrations preserved
+
Trip/Maps/Group Messaging business contract documented
+
all stale/deputy references inventoried
+
AI model updated separately to v13-compatible runtime
+
no premature Trip backend rewrite
```

Sau bước này mới bắt đầu Big Update chính thức.

---

# 14. BIG UPDATE ENTRY CRITERIA

Chỉ bắt đầu Big Update khi đã có:

```text
[ ] Latest xuanthu UI merged/synced
[ ] Auth/Profile/Search/Follow/Message/Moment integrations preserved
[ ] Current Map/Place/Route integration preserved
[ ] Trip/Maps/Messaging business knowledge committed under docs/
[ ] Deputy/co-leader dependency inventory complete
[ ] Current Trip schema/API audited
[ ] Current Message schema/API audited
[ ] Current Map/location permission implementation audited
[ ] v13 recommendation runtime validated/defaulted
[ ] Full regression passes
[ ] Git working tree state understood and backed up
```

Đây là điều kiện “ready for Big Update”, không phải yêu cầu implement toàn bộ Big Update trong bước chuẩn bị.
