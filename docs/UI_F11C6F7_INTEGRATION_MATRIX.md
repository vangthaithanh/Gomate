# UI f11c6f7 - Integration Matrix

Ngày: 2026-10-15. Nhánh tích hợp: `codex/ui-f11c6f7-invitation-sync`.

## Nguồn đã khóa

- UI: `origin/xuanthu`, commit `f11c6f73a271781e16d0f0488fc9b92b606a51fe`.
- Recovery request: `CODEX_RECOVERY_SYNC_F11C6F7_INVITATION_FINAL.md` do người dùng cung cấp.
- `GOMATE_UI_BUSINESS_CLEANUP_20261013.md`.
- `GOMATE_SETTINGS_BUSINESS_HANDOFF_20261014.md`.
- `GOMATE_CREATE_POST_BUSINESS_HANDOFF_20261015.md`.

Quyết định mới được xác nhận: chọn người lúc tạo Trip cũng gửi lời mời, không thêm thẳng thành viên. Đổi mật khẩu giữ UI PIN và chưa kích hoạt backend.

Cập nhật tiếp theo 2026-10-15: `TRIP_INVITATION_CANCELLATION.md` triển khai hủy PENDING (V11/CANCELLED). Theo quyết định UI mới nhất, hủy ở danh sách đang chờ bên ngoài màn Thành viên; popup thêm ẩn người đã mời và không có nút hủy. Các trạng thái deferred bên dưới mô tả scope recovery ban đầu; pending cancel hiện đã là chức năng thật cho PERSONAL/GROUP.

## Ma trận tích hợp

| Module | UI f11c6f7 | REAL_EXISTING | DEMO_UI_ONLY / NEW_BUSINESS_NOT_IMPLEMENTED | Kết quả tích hợp |
|---|---|---|---|---|
| Profile của tôi | Header, avatar, thống kê, tab, editor mới | AuthService, cập nhật tên/biệt danh/bio, thống kê quan hệ, Moments | Post backend, link/gender, upload avatar binary; Favorites vẫn là store UI hiện có | Dùng hồ sơ/count thật; không bật fallback người/bài/số liệu mẫu; dấu + mở Create Post |
| Profile người khác | Profile chung, menu, follower/friend UI | User profile/search, follow/unfollow, mutual, direct chat; mute Moment hiện hành | Account privacy/follow-request/global block/report chưa hoàn chỉnh; unmute UI hiện chưa có nguồn trạng thái bền vững | Giữ real follow/profile refresh và DM; không suy privacy từ quan hệ; các phần mới chưa có backend được ghi là deferred |
| Followers/Friends | Tab, search, row, action giữ nguyên | user_follows; thống kê và mutation thật | QA fixtures được giữ tách khỏi production | Nối list có phân trang về đúng userId; quan hệ từng row tính theo viewer; tải lại count sau mutation |
| Settings | Toàn bộ menu/màn con, search entry, header, copy/select UI | Auth logout; edit Profile; MyMomentsScreen | Activity likes/comments/reviews/saved/report/history/usage; privacy/theme/locale/OS adapter | Giữ layout; tắt dữ liệu seed mặc định; không báo thống kê/quyền thiết bị giả là thật; PIN chưa gửi mã/đổi mật khẩu |
| Create Post | Album, compose, media reorder, caption, tags, place, audience, feed/menu | PhotoManager album, ImagePicker camera, tìm user và Place thật | Post/media upload, xuất clip thật, pin/audience/delete/engagement backend | Dấu + đúng route; ô camera đầu lưới; ảnh/video chung tối đa 12; nút Chia sẻ giữ draft và báo chưa khả dụng, không publish RAM thành bài thật |
| Notifications | Popup, header, row/action, nhóm ngày, pin/focus | V9 invitations; inbox PostgreSQL V10; API list/detail/read | Notification types ngoài invitation; follow-request approvals; FCM/WebSocket/SSE | Không dùng NotificationUiDemo trong inbox production; pending chỉ có Chấp nhận; status lấy từ server |
| Trip | List/detail/create/member picker của UI hiện có | Phase 1 chat/name, Phase 2 stop/time/reorder/optimize, Phase 3 pin/location snapshot | Member-originated invite + leader approval, revoke/expire lifecycle, leave/kick expansion | Tạo/add sau đều PENDING; membership/chat chỉ sau accept; bỏ khu accept/decline tự thêm ở Trip tab |
| Map/Place | Giữ source UI f11c6f7, related-post navigation và create-trip intent | Place API, route/GPS, markers, stop/member LAST_KNOWN, performance fixes | Related posts/reviews còn fixture UI riêng | Không thay map architecture; controller/state performance khớp snapshot trước sync; Map screen chỉ thêm intent mở Create Trip |
| Messages | Trang cá nhân mở Profile chuẩn; invite dùng shared picker | Direct/group text, linked Trip, rename, search | Media/realtime chat, pending cancel/remove chưa triển khai | Invite từ group/direct gọi API thật và chờ ACK; không tạo membership trong client |
| Home/Search/AI | Bell mở Notifications; post grid/feed navigation mới | Recommendation AI v13, user search/follow, Moments | Post feed/search/hashtag/social interaction phần cũ còn demo | Giữ API/gateway thật; không đưa model/schema AI mới vào recovery |

Các tên enum/model có chữ Preview không tự động là dữ liệu giả: giữ chúng khi component đang dùng. Không xóa hàng loạt fixture/repository dùng chung.

## Audit thay thế lớn

So sánh ba nguồn: bản trước sync (snapshot), commit UI, bản tích hợp hiện tại. `HEAD=738d548` là nền đã commit; snapshot còn chứa phần Phase 4.1 chưa commit và tối ưu Map.

| File | HEAD | Trước sync | f11c6f7 | Sau tích hợp | Giải thích và phần thật được nối lại |
|---|---:|---:|---:|---:|---|
| `profile_screen.dart` | 744 | 744 | 497 | 585 | Bỏ layout Profile cũ và sample post cứng; dùng header/avatar/tab của UI mới. AuthService listener, load/update profile, real stats còn hoạt động; không thay bằng sample stats |
| `setting_screen.dart` | 923 | 923 | 232 | 404 | Bố cục Settings cũ được tách thành các màn/widget UI mới. Giữ logout thật và edit Profile; password sheet cũ không nối vào PIN theo quyết định người dùng, API hiện hành vẫn còn |
| `public_profile_screen.dart` | 457 | 457 | 699 | 859 | Giữ follow/unfollow, refetch profile/count và direct chat; thêm menu/layout bàn giao. Preview chỉ dùng QA, không gửi ID mẫu tới API |
| `trip_screen.dart` | 1255 | 1492 | 1274 | 1275 | Bỏ khu invitation tự thêm ở Trip tab (state, action, card). Chuyển accept sang Notifications; list/create/detail/pin/actions/map session/chat hooks giữ nguyên |
| `notification_screen.dart` | chưa có | chưa có | 823 | 641 | Thay fake router/mutations, nút test popup và local acceptedTripIds bằng inbox thật. Giữ row, group ngày, popup shell, pin #1/focus; UI follow-request chưa bật vì server chưa có feature |

Số dòng tăng so với source ở Profile/Settings còn gồm format Dart, không phải tự thêm layout. City và nhập avatar URL ở sheet cũ không có trong editor mới được duyệt: giữ nguyên API/compatibility sheet, không tự thêm field vào UI mới; avatar binary vẫn chỉ preview theo handoff. Không tuyên bố đây là chức năng upload avatar hoàn tất.

Các diff lớn ở `map_screen.dart`, `mapbox_layer_controller.dart`, `map_state.dart` so với HEAD là tối ưu đã có trước task. So với snapshot trước sync, controller/state giữ cùng SHA256; Map screen chỉ thêm `GoMateMapUiSession.requestCreateTrip()` vào callback quick-create. Không xóa route/marker/location/performance logic.

Các file nhỏ có nhiều dòng thay do format (`gomate_name_editor_content.dart`, shared header/picker, Message adapters, Place detail) đã đối chiếu với source: giữ component/layout; chỉ nối navigation và chờ API ACK. Không xóa repository/permission/Phase 2/3 để làm file ngắn hơn. Số dòng giảm tự nó không phải bằng chứng mất chức năng.

Snapshot: `backups/pre_f11c6f7_sync_20261015/` (gitignored). Analyzer bỏ qua snapshot này, vẫn phân tích toàn bộ code ứng dụng.

## File UI tích hợp từ source

Đường dẫn dưới đây tính từ root repository. Không merge toàn branch và không đổi HEAD của nhánh hiện tại.

```text
assets/images/google_logo.png
lib/core/widgets/gomate_main_tab_header.dart
lib/core/widgets/gomate_name_editor_content.dart
lib/core/widgets/gomate_notification_popup.dart
lib/features/auth/screens/forgot_password_screen.dart
lib/features/home/screens/home_screen.dart
lib/features/map/screens/place_detail_screen.dart
lib/features/map/state/map_ui_session.dart
lib/features/messages/screens/message_detail_screen.dart
lib/features/notifications/models/gomate_notification.dart
lib/features/notifications/screens/notification_screen.dart
lib/features/notifications/ui_preview/notification_ui_demo.dart
lib/features/posts/screens/create_post_screen.dart
lib/features/posts/screens/post_video_trim_screen.dart
lib/features/posts/ui_preview/post_ui_demo_store.dart
lib/features/posts/widgets/post_audience_content.dart
lib/features/posts/widgets/post_hashtag_content.dart
lib/features/posts/widgets/post_media_widget.dart
lib/features/profile/screens/profile_edit_screen.dart
lib/features/profile/screens/profile_people_screen.dart
lib/features/profile/screens/profile_post_feed_screen.dart
lib/features/profile/screens/profile_screen.dart
lib/features/profile/screens/public_profile_screen.dart
lib/features/profile/screens/setting_screen.dart
lib/features/profile/screens/settings_account_lists_screen.dart
lib/features/profile/screens/settings_activity_screen.dart
lib/features/profile/screens/settings_collection_screen.dart
lib/features/profile/screens/settings_history_screen.dart
lib/features/profile/screens/settings_preferences_screen.dart
lib/features/profile/ui_preview/profile_ui_preview.dart
lib/features/profile/ui_preview/settings_ui_demo.dart
lib/features/profile/widgets/profile_ui_widgets.dart
lib/features/profile/widgets/settings_shared_widgets.dart
lib/features/search/screens/search_screen.dart
lib/features/search/widgets/search_widgets.dart
lib/features/trip/screens/trip_screen.dart
pubspec.yaml
```

`map_screen.dart` không copy đè vì đang có tối ưu chưa commit; giữ nguyên code đã audit và chỉ nối intent tương thích nêu trên. Fixture vẫn được lưu, nhưng inbox production không import fixture; Profile/Settings preview mặc định tắt.

## Kết quả cuối

- Maven verify qua Docker: 78 tests, 0 failures/errors/skipped.
- Flutter: 9 tests pass; analyze exit 0, 0 error, 285 warning/info chưa cleanup toàn repo.
- Android debug APK build thành công; chưa cài/chạy bản mới để kiểm tra thủ công trên điện thoại.
- PostgreSQL hiện tại V1-V10 pass, số bản ghi business cũ không đổi; PostgreSQL sạch chạy thật V1-V10 và API smoke A/B/C pass.
- API route thật Hồ Xuân Hương -> Thiền Viện Trúc Lâm pass; không có chỉnh sửa routing architecture.
- Xem báo cáo final để biết lệnh chạy, backup, số liệu và giới hạn nghiệm thu thiết bị.

## Ranh giới kiểm chứng

- Widget/unit tests chứng minh điều hướng/state UI, không thay thế test camera/Mapbox/GPS trên điện thoại.
- Maven verify bao gồm regression các module hiện có.
- Không khẳng định Firebase Google login trên thiết bị đã được chạy lại nếu chỉ có automated verifier/API tests.
- Realtime/push được báo riêng, không đánh đồng inbox bền vững với push notification.
