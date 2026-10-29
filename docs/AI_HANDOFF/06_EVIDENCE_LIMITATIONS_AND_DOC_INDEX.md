# Evidence, giới hạn và index

## Hai nguồn khác nhau

- **Quyết định owner mới:** task publish ngày29/10 xác nhận source local là chuẩn và nói có xác nhận PASS mới hơn cho các phase liên quan. Đây là lời xác nhận owner, không phải agent chạy lại toàn bộ tests/native.
- **Evidence gốc:** [Global Block](../GLOBAL_USER_BLOCK.md) ghi V26/38 business tables, scoped131 backend PASS, Flutter323 PASS, analyze0 errors/14 warnings, 6 ca Android PASS rồi dừng theo owner. Không đổi các ca native còn thiếu thành PASS vì task mới nói baseline được duyệt.

Report gốc còn thiếu native GPS phía bị chặn/khôi phục sau Unblock, hai thiết bị cùng xem Map/SSE/C/D, Profile Unblock, lỗi mạng/ACK/popup nhiều user, ma trận Post/media/Search đang mở và follow race. Backend/Flutter có evidence riêng; không có GLOBAL_BLOCK_FULL_PASS trong chứng cứ gốc. Bản publish redacts device/account/business identifiers, bản nguyên giữ private local; kết quả/hạn chế không đổi.

| Phần | Report/source |
|---|---|
| Post Publish 422/404 build regression / teammate sync | [Hotfix](../POST_PUBLISH_TAG_VALIDATION_HOTFIX.md) — lỗi đã tái hiện trên baseline d94ebf6; smoke 26 test trước đó không bao gồm PostPublishApiTest, không thay thế full build |
| Privacy P1A | [ACCOUNT_PRIVACY_FOUNDATION_P1A](../ACCOUNT_PRIVACY_FOUNDATION_P1A.md) |
| Publish/Profile | [P1B](../POST_PUBLISH_P1B.md), [P1C](../PROFILE_POST_P1C.md) — mới30s supersedes P1B60s, không sửa migration cũ |
| Home/Like/Save | [P2](../POST_HOME_FEED_P2.md), [My Activity](../SETTINGS_POST_ACTIVITY.md) |
| Comment/Reply/Report | [P3](../POST_COMMENT_REPORT_P3.md) |
| Share/Search | [P4](../POST_SHARE_SEARCH_P4.md), [reference Share fix](../DM_INBOX_ORDER_AND_REFERENCE_SHARE_FIX.md) |
| DM/requests | [DM Privacy](../DIRECT_MESSAGE_PRIVACY_REQUESTS.md) |
| Post notifications/native | [interactions](../POST_INTERACTION_NOTIFICATIONS.md), [likers/native](../POST_LIKERS_AND_ANDROID_ACCEPTANCE.md), [SSE](../REALTIME_NOTIFICATION_FOUNDATION_V1.md), [FCM](../PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md) |
| Trip/Map | [pin-centric](../TRIP_PIN_CENTRIC_BUSINESS_RESET.md), [last-known](../MAP_PIN_SWITCH_LAST_KNOWN_FIX.md) |
| Reminder/stop | [D2/D1](../TRIP_DATE_ONLY_D2_D1_REMINDERS.md), [stop hotfix](../TRIP_STOP_TIME_PERSIST_EDIT_VALIDATION_HOTFIX.md) |
| Global Block | [V26/native](../GLOBAL_USER_BLOCK.md) |
| Media/cache | [lifecycle](../HOME_FEED_MEDIA_LIFECYCLE_FIX.md), [performance](../POST_MEDIA_PERFORMANCE.md) |
| Place catalog/media | [canonical](../PLACE_CATALOG_V11_ALIGNMENT.md), [completion](../PLACE_CATALOG_V11_COMPLETION.md), [media](../PLACE_MEDIA_COMPLETION.md) |
| Place AI v13/semantic | [v13](../AI_RANKER_V13_INTEGRATION.md), [backend handoff](../BACKEND_HANDOFF_GOMATE_V13.md), [semantic-v1](../AI_SEMANTIC_DATA_HANDOFF_V1.md), [foundation](../SEMANTIC_FOUNDATION_V4.md), [enrichment](../SEMANTIC_ENRICHMENT_V1_FINAL.md) |

## Xung đột docs cũ ↔ source

| Mô tả cũ | Rule/source hiện tại |
|---|---|
| README Auth4 tables/V1-only/backend-local env | root Compose, V1–V26, 38 tables, runbook01 |
| saved_posts/blocked_users/trip_invites trong roadmap | actual post_saves/user_blocks/trip_invitations; migrations/source/current inventory |
| DRAFT/ACTIVE/COMPLETE/CANCEL journey controls | legacy DB value không cấp phép Start/Complete/Cancel; pin-centric |
| DEPUTY | chỉ LEADER/MEMBER |
| Member-origin invite được nói trong business target | source TripService requireLeader khi createInvitation/addMembers; approval phase chưa triển khai, không giả endpoint |
| T-60/T-30/giờ khởi hành Trip | D-2/D-1 local20:00; history cũ giữ, không revive |
| Share chỉ DM có sẵn/create-on-open/DIRECT-only block | first-send/mutual Share; PENDING không autoaccept; Global Block duy nhất |
| Video mới60s | mới30s, lịch sử31–60s còn đọc |
| KPDL README selected legacy v12 | api_service.py ưu tiên v13 cho Place, chưa có Post model |

[Release report07](07_GIT_RELEASE_REPORT.md) ghi fresh checks của lần publish, không gộp với baseline cũ. Private logs/dump/credentials không nằm trong clone; tái kiểm chứng bằng test source, không xin backup cá nhân. Không dựng báo cáo PASS hay dữ liệu thử khi thiếu chứng cứ.
