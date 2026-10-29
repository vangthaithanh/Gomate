> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Phase 4.1 - Invitation UI Sync Final

Ngày: 2026-10-15. UI chuẩn: xuanthu `f11c6f7`.

Bản sửa tiếp theo cùng ngày: `TRIP_INVITE_IMMEDIATE_SEND_FIX.md`. Trip đã lưu nhưng chưa có chat cũng gửi lời mời ngay khi bấm Thêm; bỏ bước Gửi phụ. Bộ Flutter test sau fix: 14 pass.

Cập nhật yêu cầu sau đó: `TRIP_INVITATION_CANCELLATION.md` triển khai nhóm trưởng hủy PENDING (V11/CANCELLED). Các ghi chú revoke-deferred bên dưới chỉ mô tả thời điểm recovery ban đầu; cancel pending hiện đã có, expiry/member-originated approval vẫn deferred.

## Nghiệp vụ mới thay thế Phase 1.2

Mọi người được chọn, dù lúc tạo lịch trình hay thêm vào lịch trình đã tồn tại, đều nhận lời mời `PENDING`.

```text
Chọn B/C khi tạo -> lưu Trip PERSONAL + A là LEADER
-> lưu 2 trip_invitations PENDING + 2 notifications -> COMMIT
-> B/C chưa là member, chưa có chat nhóm

B bấm Chấp nhận trong Thông báo -> transaction thêm B
-> Trip GROUP -> tạo 1 linked GROUP conversation -> đồng bộ A/B -> ACCEPTED

C chấp nhận -> dùng lại cùng conversation -> đồng bộ A/B/C
```

Mọi kiểm tra quyền và membership dựa trên PostgreSQL, không dựa vào thông báo đã đọc hoặc state RAM.

## Transaction và quyền

- Create: validate toàn bộ danh sách trước; loại trùng và bỏ self-reference theo validation đang có. Có user không hợp lệ thì không tạo Trip/invitation/notification nào.
- Existing Trip: chỉ LEADER gửi; lock Trip trước khi kiểm tra duplicate PENDING; cả batch thành công hoặc rollback.
- Accept: lock invitation; chỉ invitee được nhận; lock Trip để tuần tự hóa accept đồng thời; member/chat/status/notification cùng transaction.
- Accept lại ACCEPTED là idempotent; không tạo chat/member/accepted-event lần hai.
- Nếu lỗi ghi accepted notification, rollback cả membership/chat/status.
- Inviter nhận `TRIP_INVITATION_ACCEPTED` chỉ khi transaction accept commit.
- Pending không cho đọc Trip hoặc chat. Người ngoài không đọc/đánh dấu thông báo của người khác.
- Không tự chuyển GROUP về PERSONAL. Không sửa dữ liệu membership cũ đã tồn tại trước task.

## UI nhận lời mời

- Home bell -> giao diện Thông báo của f11c6f7.
- Popup là overlay đầu màn, không dim, không có nút Chấp nhận.
- Nhận popup chưa làm đổi route hoặc spotlight.
- Nhấn popup: fetch thông báo mới nhất; PENDING -> mở/focus inbox, pin notification đó #1 và chỉ hiện một lần.
- Nhấn body hàng PENDING: ở lại inbox; chỉ mark read, không accept/mở Trip.
- Nút Chấp nhận nằm trên hàng inbox; đang gửi thì chặn bấm lặp và hiển thị loading tại nút.
- ACK thành công -> bỏ spotlight, hàng quay về nhóm ngày; nhấn hàng ACCEPTED mới mở TripDetail đúng tripId.
- Lỗi accept: giữ/refresh trạng thái thật, không thêm member cục bộ.
- Popup cũ: luôn resolve lại status. Target đã xóa -> UNAVAILABLE, không có nút Chấp nhận giả.
- Không có nút Từ chối tự thêm. Endpoint decline từ V9 giữ làm API chưa nối UI.
- Lời mời đang chờ của người gửi được trả trong `TripDetail.pendingInvitations`, tách khỏi `members`.

## ID contract

| ID | Nguồn | Dùng để |
|---|---|---|
| notificationId (`notifications.id`) | UUID riêng của event/inbox | fetch/read/focus/spotlight |
| invitationId (`trip_invitations.id`) | UUID nghiệp vụ lời mời | accept/decline |
| tripId (`trips.id`) | UUID business Trip | load Trip và mở TripDetail |

Không dùng ba ID thay thế cho nhau. Không gửi `ui-preview-*` vào API thật.

## API hiện thực

```text
POST /api/v1/trips                          selectedMemberIds -> invitations
POST /api/v1/trips/{id}/members             bulk invitation compatibility route
POST /api/v1/trips/{id}/invitations         {inviteeUserId}
GET  /api/v1/trip-invitations/incoming      status mặc định PENDING
POST /api/v1/trip-invitations/{id}/accept
POST /api/v1/trip-invitations/{id}/decline   chưa đưa lên UI

GET   /api/v1/notifications?page=0&size=30   {items,page,size,total,unreadCount}
GET   /api/v1/notifications/{notificationId}
PATCH /api/v1/notifications/{notificationId}/read
POST  /api/v1/notifications/read-all
```

Notification item: id, type, actorId, actorName, avatarUrl, message, isRead, occurredAt (UTC), invitationId, invitationStatus, tripId, tripName.

Trip summary bổ sung `currentUserRole` từ server để không đoán user trong GROUP luôn là leader. Read adapters `/users/{id}/followers` và `/users/{id}/mutual-friends` tái dùng user_follows cho UI Profile mới; các account hiện tại vẫn public-only, chưa bật private setting.

## Persistence và migrations

- V1-V9 giữ nguyên. V9 đã chạy trên DB trước phiên này, không rewrite.
- V10 `V10__trip_invitation_notifications.java`: chỉ thêm bảng `notifications` theo DATABASE_CONTRACT, FK recipient/actor về users; unique `(user_id,type,entity_type,entity_id)`; index inbox/time.
- Java migration dùng JDBC để backfill invitation cũ với notification UUID riêng, hỗ trợ cả PostgreSQL và H2.
- `trip_invitations` là business truth; notifications chỉ là inbox event; status trong API được join từ invitation.
- Xóa Trip xóa invitation theo FK V9; notification còn lại được trả UNAVAILABLE, không làm mất event lịch sử hoặc cấp quyền giả.
- Không thay collection Mongo, không sửa Auth/Place/AI schema.

## Delivery reality

```text
INBOX_PERSISTENCE_REAL
FOREGROUND_SYNC = REST polling mỗi 12 giây + refresh khi app resume/inbox mở
REALTIME_DELIVERY = DEFERRED (chưa WebSocket/SSE)
PUSH = DEFERRED (chưa FCM cho invitation)
```

Chỉ có một inbox store/listener ở MainShell. Dừng polling khi app không ở foreground và reset theo account. Nhận dữ liệu mới có thể dùng popup shell hiện có; không gọi đây là hoàn tất realtime/push.

## Recovery và phần chưa làm

- Tận dụng repository/service/accept transaction/test của bước trước; bỏ UI nhận/từ chối sai vị trí.
- UI/Profile/Settings/Create Post lấy từ commit đã kiểm chứng; xem `UI_F11C6F7_INTEGRATION_MATRIX.md` để biết phần thật/demo/deferred.
- Post backend/media-upload/video-export/pin/audience mutation chưa triển khai; Share không tạo bài RAM giả.
- PIN backend deferred theo quyết định người dùng; không giả gửi/xác minh PIN hoặc gọi API current-password.
- Member-originated invite + LEADER approval, revoke/expire policy, push và full notification/social triggers chưa nằm trong recovery này.
- Không reset volume, không sửa migration cũ; backup DB trước cutover.

## Verification

### Lệnh đã chạy và kết quả

| Kiểm tra | Kết quả thực tế |
|---|---|
| `git show --stat/--name-status f11c6f7`, kiểm tra ancestor của origin/xuanthu | PASS, full SHA `f11c6f73a271781e16d0f0488fc9b92b606a51fe` |
| `docker compose build api` (Dockerfile chạy Maven `clean verify`) | PASS, 78 tests, 0 failures/errors/skipped; BUILD SUCCESS |
| `docker compose up -d api`, `docker compose ps`, GET `/health` | PASS, API UP; PostgreSQL/Mongo healthy, AI running |
| Flyway DB hiện tại | PASS, V1-V10 success; V1 cũ vẫn BASELINE, V9 không sửa |
| Flyway PostgreSQL sạch riêng | PASS, chạy thật V1 -> V10 từ đầu |
| `pwsh -File backend/scripts/verify-trip-invitation-ui-sync.ps1` trên API test port 18082 | PASS, register A/B/C, create/invite/read/permission/accept/idempotency/profile/follow |
| `flutter test --no-pub` | PASS, 9 tests |
| `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos` | PASS exit 0, 0 errors; còn 285 warning/info, gồm code UI được nhập và code cũ |
| `flutter build apk --debug --no-pub` | PASS, `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | PASS, chỉ cảnh báo LF/CRLF khi Git chuyển line ending |

Log local (gitignored): `backups/docker_build_ui_sync_final.log`, `backups/flutter_test_ui_sync_final.log`, `backups/flutter_analyze_f11c6f7_final.log`, `backups/flutter_build_ui_sync_final.log`.

### DB hiện tại trước/sau cutover

Backup trước V10: `backups/gomate_pre_ui_invite_v10_20261015.dump` (pg_dump custom format, 106197 bytes).

| Bảng | Trước | Sau |
|---|---:|---:|
| users | 37 | 37 |
| places | 146 | 146 |
| place_media | 7 | 7 |
| trips | 5 | 5 |
| trip_members | 8 | 8 |
| conversations | 3 | 3 |
| trip_invitations | 1 | 1 |
| notifications | chưa có | 1 |

Một invitation PENDING cũ được backfill inbox với notification UUID mới, không đổi invitation/trip/member. Không chạy fixture tạo user/Trip vào DB dự án. Không reset Docker volume, không Flyway repair.

Flyway history thực tế: V1 Auth baseline, V2 Place, V3 Trip, V4 Semantic, V5 Social relationship, V6 Direct message, V7 Group Trip chat, V8 Trip pin, V9 Invitation lifecycle, V10 Invitation notifications. Tất cả success.

### PostgreSQL sạch và invitation invariants

DB test riêng `gomate_ui_sync_clean_bd4dbb5f`, container `gomate-ui-sync-clean-1015`, chỉ bind `127.0.0.1:18082`; Firebase/Cloudinary tắt để không tạo external asset.

- Sau create A chọn B/C (có ID B lặp): PERSONAL, chỉ A trong members, 2 PENDING invitations, 2 inbox records, không conversation.
- B không đọc Trip trước accept; A/C không đọc/đánh dấu inbox của B hoặc accept hộ B.
- Mark read không đổi PENDING/membership; gửi invitation lại không duplicate.
- B accept: GROUP, 1 linked GROUP conversation, A/B trong cả hai membership.
- C accept: giữ cùng linkedConversationId, A/B/C trong cả hai membership.
- Accept lại không tạo thêm member/chat/notification.
- Kết thúc fixture: 3 users, 1 Trip, 3 trip_members, 1 conversation, 3 conversation_members, 2 ACCEPTED invitations, 4 notifications (2 mời + 2 báo đã nhận).
- Fixture còn kiểm tra profile nickname/bio và follower/friend list tính theo viewer.
- Đã dọn container và DB test riêng sau verify. Không thay Mongo collection/schema cho task này.

Backend tests bổ sung còn xác minh rollback khi ghi accepted-event thất bại; accept đồng thời dùng chung một chat; Trip bị xóa trả event UNAVAILABLE; invalid invitee rollback toàn create/bulk.

### Flutter và regression

Widget/unit test mới kiểm tra ID separation; reload status từ API; popup -> inbox pin #1 tại width 360 và 430; body PENDING không accept/mở Trip; không có Từ chối; accept fail giữ PENDING; ACK bỏ spotlight; accepted row load đúng tripId; Profile/Settings/Notifications mở; Profile + mở Create Post/camera cell; PIN không giả gửi mã.

Maven regression 78 tests bao gồm Auth/Google/Firebase verifier, Place, Route, Semantic/Recommendation, Follow, DM, Moments, Trip Phase 1/2/3 và Invitation. Đây là automated tests, không phải thao tác Google login/camera/GPS thật trên điện thoại.

API route thực trên backend hiện tại: Hồ Xuân Hương (`places.id=3`) -> Thiền Viện Trúc Lâm (`places.id=7`): `distanceMeters=6352.558`, `durationSeconds=846.391`, geometry 302 points. Place IDs từ PostgreSQL; Mapbox được gọi thật. Controller/state tối ưu Map giữ hash snapshot; Map screen chỉ thêm intent quick-create như matrix.

### Giới hạn và bước test thiết bị

- Chưa kiểm tra thủ công APK mới trên Samsung `ANDROID_DEVICE_SERIAL`. Không tuyên bố camera/video/Mapbox/GPS/độ mượt/popup native đã nghiệm thu trên máy thật.
- UI Messages và Trip detail/list giữ call-site thật, backend regression pass; cần người dùng đi lại các màn trên thiết bị để nghiệm thu layout/navigation đầy đủ.
- Inbox bền vững là thật. Popup transport hiện là REST foreground polling 12 giây; không phải realtime WebSocket/SSE và chưa có push FCM/background delivery.
- PIN chỉ giữ UI, chưa activate. Post Share không persist, không báo publish thành công. Avatar binary/link/gender và phần Settings chưa có API vẫn deferred/preview đúng phạm vi.
- Privacy chưa bật; account hiện public-only. Khi bổ sung private/follow-request phải bổ sung quyền cho read adapters followers/friends, không chỉ đổi toggle UI.
- Không có revoke/expire/member-originated approval trong scope này. Backend decline cũ không đưa lên UI.
- Có dependency/plugin native mới `photo_manager`, `video_player`; Android/iOS permission và generated registrant/lockfile tương ứng đã cập nhật. `.gitignore` bỏ qua Kotlin build cache; không đưa snapshot/secret/build artifact vào Git.
- Không có commit/push tự động. Thay đổi đang ở branch `codex/ui-f11c6f7-invitation-sync` để người dùng review.

Đóng app/run cũ rồi chạy lại từ root (không chỉ hot reload vì có plugin native mới):

```powershell
.\scripts\run-android-dev.ps1 -DeviceId ANDROID_DEVICE_SERIAL -NoDockerStart
```

API đã chạy ở `http://127.0.0.1:8081`; runner thiết lập adb reverse và dùng ApiConfig hiện có. Không cần reset DB.

Checklist nghiệm thu người dùng: A tạo Trip chọn B/C -> đăng nhập B trên cùng máy -> Home bell/Thông báo -> nhấn body vẫn ở inbox -> Chấp nhận -> mở đúng Trip -> chat nhóm A/B -> C chấp nhận dùng lại chat -> đăng xuất/đăng nhập kiểm tra state vẫn đúng. Popup cần một event mới trong lúc app foreground sau initial inbox load; không phát lại popup cho lịch sử cũ.
