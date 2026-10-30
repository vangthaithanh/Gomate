# CODEX_INDEX.md — What Codex Should Read

This folder is a compact knowledge base for GoMate. It exists to reduce context/token use.

## Always

Codex always reads root `AGENTS.md`.

## Load by task

| Task | Read |
|---|---|
| Recommended Home ranking / viewed-post history / snapshot cursor | `POST_RECOMMENDED_HOME_VIEW_HISTORY.md` + `POST_HOME_FEED_P2.md` + `GLOBAL_USER_BLOCK.md`; viewed filtering applies only to current friend/follow groups, never the scored remainder |
| Place unrated display / real rating/review | `PLACE_UNRATED_DISPLAY_TEAM_HANDOFF.md` + `PLACE_RATING_REVIEW_FOUNDATION.md`; count=0 displays “Chưa có đánh giá”, no numeric score; old display-five instructions are superseded |
| Docker build fails PostPublish tagged-user 422/404 / teammate sync | `POST_PUBLISH_TAG_VALIDATION_HOTFIX.md`; keep Global Block, replay/idempotency and full Docker test gate; no DB re-restore |
| Publish local baseline / AI Post handoff | `AI_HANDOFF/00_START_HERE.md` through `07_GIT_RELEASE_REPORT.md`; Post AI and seed remain proposals, no permission to change current UI/business |
| Global Block / legacy DIRECT conversion / viewer-scoped Trip GPS / group warning | `GLOBAL_USER_BLOCK.md` + `ACCOUNT_PRIVACY_FOUNDATION_P1A.md` + `DIRECT_MESSAGE_PRIVACY_REQUESTS.md`; final user decision 29/10/2026 supersedes independent DIRECT block |
| Long-press Post Like list / guided Android Post notification tests | `POST_LIKERS_AND_ANDROID_ACCEPTANCE.md` + `POST_INTERACTION_NOTIFICATIONS.md` |
| Post Like / Comment / Reply notifications, unread badges and sent message label | `POST_INTERACTION_NOTIFICATIONS.md` + `REALTIME_NOTIFICATION_FOUNDATION_V1.md` + `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md`; supersedes older deferred Post notification notes |
| New/recent DM below old groups / ONLY_ME reference Share to DM | `DM_INBOX_ORDER_AND_REFERENCE_SHARE_FIX.md` + `DIRECT_MESSAGE_PRIVACY_REQUESTS.md` + `POST_SHARE_SEARCH_P4.md` |
| DM recipient privacy / create-on-send / message requests / accepted Share | `DIRECT_MESSAGE_PRIVACY_REQUESTS.md` + `ACCOUNT_PRIVACY_FOUNDATION_P1A.md` + `POST_SHARE_SEARCH_P4.md`; older DM V1 opening semantics are superseded |
| P4 real Post Share / Search / recent history | `POST_SHARE_SEARCH_P4.md` + `SETTINGS_POST_ACTIVITY.md` + `POST_COMMENT_REPORT_P3.md` + `UI_BUSINESS_HOME_RECOMMENDATION_SEARCH.md` sections 1.8 / 3 / 4.4 / 4.6 |
| Settings own Post Likes / Comments / Saved, two-way mutation ACK | `SETTINGS_POST_ACTIVITY.md` + `POST_COMMENT_REPORT_P3.md` + `POST_HOME_FEED_P2.md` |
| Home Feed media lifecycle / native video retention / 5-minute return TTL | `HOME_FEED_MEDIA_LIFECYCLE_FIX.md` + `POST_MEDIA_PERFORMANCE.md` (supersedes tile-owned Home retention) |
| Post P3 real Comment / protected comment images / Report history + video retention | `POST_COMMENT_REPORT_P3.md` + `POST_HOME_FEED_P2.md` + `POST_MEDIA_PERFORMANCE.md` |
| Home Feed reloading media while scrolling / bounded retention | `HOME_FEED_VIEW_RETENTION.md` + `POST_MEDIA_PERFORMANCE.md` |
| Post V21 ownership menu / Home creation selector / Feed scrolling | `POST_OWNERSHIP_CREATION_PERFORMANCE_HOTFIX.md` + `POST_HOME_FEED_P2.md` |
| Post P2 real Home Feed / Like / Save | `POST_HOME_FEED_P2.md` + `PROFILE_POST_P1C.md` + `POST_MEDIA_PERFORMANCE.md` |
| Post/Profile repeated image loading / privacy-safe performance | `POST_MEDIA_PERFORMANCE.md` + `PROFILE_POST_P1C.md` |
| UI f11c6f7 recovery / invitation UI synchronization | `CODEX_RECOVERY_SYNC_F11C6F7_INVITATION_FINAL.md` + `GOMATE_UI_BUSINESS_CLEANUP_20261013.md` + `GOMATE_SETTINGS_BUSINESS_HANDOFF_20261014.md` + `GOMATE_CREATE_POST_BUSINESS_HANDOFF_20261015.md` + `UI_F11C6F7_INTEGRATION_MATRIX.md` + `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md` |
| Restructure repo / move Flutter or backend | `AUTH_CURRENT_STATE.md` + relevant parts of `PROJECT_CONTRACT.md` |
| Auth/register/login/JWT/refresh/reset/profile/onboarding | `AUTH_CURRENT_STATE.md` + `DATABASE_CONTRACT.md` + `PROJECT_CONTRACT.md` |
| PostgreSQL/Flyway/schema/index/seed | `DATABASE_CONTRACT.md` |
| Flutter API integration/router/network/storage | `PROJECT_CONTRACT.md` + feature-specific current code |
| Xuanthu UI merge / Home Feed / Search / Message / Moment UI handoff | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `UI_BUSINESS_HOME_RECOMMENDATION_SEARCH.md` + `MOMENT_BACKEND_BUSINESS_SPEC.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md` |
| MongoDB foundation / data ownership / interaction events / Moment scope alignment | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `MONGODB_DATA_OWNERSHIP_V1.md` + `MONGODB_FOUNDATION.md` + `MOMENT_BACKEND_BUSINESS_SPEC.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` |
| Moment Backend V1 / Moment API / Moment Flutter integration | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `MONGODB_DATA_OWNERSHIP_V1.md` + `MOMENT_BACKEND_BUSINESS_SPEC.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `MOMENT_BACKEND_V1.md` |
| Place/search/review/save | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Place catalog/data alignment | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `PLACE_CATALOG_V11_ALIGNMENT.md` + `PLACE_DB_ALIGNMENT_DALAT_ENRICHMENT.md` + `PLACE_CATALOG_V11_COMPLETION.md` when V11 catalog/import status matters |
| Place media/Cloudinary seed | `DATABASE_CONTRACT.md` + `PLACE_CATALOG_V11_COMPLETION.md` + `PLACE_MEDIA_COMPLETION.md` + `PLACE_SEED_CLOUDINARY_IMPORT.md` |
| Map/place/routing/performance | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + relevant map/place step note + `MAP_PERFORMANCE_AUDIT_AND_OPTIMIZATION.md` when pan/zoom lag matters |
| Map draggable Trip panel / pin current Trip button | `MAP_TRIP_PANEL_DRAG_AND_PIN.md` + `BIG_UPDATE_PHASE3_PINNED_TRIP_MEMBER_LOCATION.md` + `MAP_PERFORMANCE_AUDIT_AND_OPTIMIZATION.md` |
| Trip pending invitations loading loop / summary member count | `TRIP_PENDING_LOAD_AND_MEMBER_COUNT_FIX.md` + `TRIP_INVITATION_CANCELLATION.md` + `TRIP_MEMBER_LIFECYCLE_PHASE4_4A.md` |
| Trip date-only D-2/D-1 20:00 reminders / calendar guard | `TRIP_DATE_ONLY_D2_D1_REMINDERS.md` + `MAP_PIN_SWITCH_LAST_KNOWN_FIX.md` + `TRIP_PIN_CENTRIC_BUSINESS_RESET.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md`; `TRIP_START_REMINDER_T60_T30.md` is superseded history |
| Trip/group/invite/location/check-in | `MAP_PIN_SWITCH_LAST_KNOWN_FIX.md` + `TRIP_PIN_CENTRIC_BUSINESS_RESET.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Historical Phase 4.5 (SUPERSEDED; read TRIP_PIN_CENTRIC_BUSINESS_RESET.md first) | `TRIP_LOCATION_SHARING_PHASE4_5.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `TRIP_LEADER_LIFECYCLE_PHASE4_4B.md` + `MAP_PERFORMANCE_AUDIT_AND_OPTIMIZATION.md` |
| Historical Phase 4.6 (SUPERSEDED; read TRIP_PIN_CENTRIC_BUSINESS_RESET.md first) | `TRIP_COMPLETION_CANCELLATION_PHASE4_6.md` + `TRIP_LOCATION_SHARING_PHASE4_5.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Pre-Big-Update Trip/Maps/Group Messaging readiness | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `TRIP_MAPS_BIG_UPDATE_READINESS_AUDIT.md` |
| Big Update Phase 1 Group Trip Chat | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE1_GROUP_TRIP_CHAT.md` + `BIG_UPDATE_PHASE1_UI_CLOSURE.md` + `BIG_UPDATE_PHASE1_CREATE_TRIP_MEMBERSHIP_CLOSURE.md` + `TRIP_PHASE1_UI_TEST_FIXES.md` |
| Big Update Phase 2 Trip Stop/time/reorder/optimize | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md` |
| Trip Stop time persistence/edit/validation hotfix | `TRIP_STOP_TIME_PERSIST_EDIT_VALIDATION_HOTFIX.md` + Trip Stop sections of `PROJECT_CONTRACT.md` / `DATABASE_CONTRACT.md`; preserve `TRIP_DATE_ONLY_D2_D1_REMINDERS.md` |
| Big Update Phase 3 pinned Trip/member location | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md` + `BIG_UPDATE_PHASE3_PINNED_TRIP_MEMBER_LOCATION.md` |
| Big Update Phase 4.1 Trip invitation lifecycle | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_LIFECYCLE.md` |
| Account privacy / private follow requests (P1A) | `ACCOUNT_PRIVACY_FOUNDATION_P1A.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Post P1C Profile list/pin/audience/delete + device gallery + 30s video override | `PROFILE_POST_P1C.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` (P1B report is historical 60s) |
| Post P1B publish / protected media / audience | `POST_PUBLISH_P1B.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Social/follow/post/chat | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Social relationship foundation / follow / mutual friend | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md` + `MONGODB_DATA_OWNERSHIP_V1.md` + `MONGODB_FOUNDATION.md` + `MOMENT_BACKEND_BUSINESS_SPEC.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` |
| Account/Profile + Direct Message V1 | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `AUTH_CURRENT_STATE.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `ACCOUNT_PROFILE_AND_DIRECT_MESSAGE_V1.md` |
| Real User Search + Follow UI V1 | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md` + `SOCIAL_RELATIONSHIP_FOUNDATION_V1.md` + `ACCOUNT_PROFILE_AND_DIRECT_MESSAGE_V1.md` + `AUTH_CURRENT_STATE.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `REAL_USER_SEARCH_FOLLOW_UI_V1.md` |
| Notification/FCM | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Phase 4.2 foreground realtime notifications | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `REALTIME_NOTIFICATION_FOUNDATION_V1.md` + `TRIP_INVITATION_CANCELLATION.md` |
| Phase 4.3 Android background push | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `REALTIME_NOTIFICATION_FOUNDATION_V1.md` + `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md` |
| Phase 4.4A Trip member leave/remove and chat lifecycle | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `TRIP_MEMBER_LIFECYCLE_PHASE4_4A.md` |
| Phase 4.4B leader transfer / soft-delete Trip | `TRIP_LEADER_LIFECYCLE_PHASE4_4B.md` + `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `TRIP_MEMBER_LIFECYCLE_PHASE4_4A.md` + `TRIP_PENDING_LOAD_AND_MEMBER_COUNT_FIX.md` |
| AI/recommendation | `PROJECT_CONTRACT.md` + `ROADMAP_AND_DONE.md` + `PLACE_CATALOG_V11_COMPLETION.md` + `SEMANTIC_FOUNDATION_V4.md` + `SEMANTIC_ENRICHMENT_V1_FINAL.md` + `AI_SEMANTIC_DATA_HANDOFF_V1.md` + `AI_BACKEND_INTEGRATION.md` + `BACKEND_HANDOFF_GOMATE_V13.md` + `AI_RANKER_V13_INTEGRATION.md` when recommending Places |
| Sprint planning / what to build next | `ROADMAP_AND_DONE.md` |
| Acceptance, demo, code freeze | `ROADMAP_AND_DONE.md` |

## Canonical source hierarchy

1. User's newest explicit instruction.
2. Root `AGENTS.md`.
3. Master Spec: `GoMate_Master_Spec_v1_FIXED`, baseline locked 2026-09-04.
4. Redesigned roadmap: `Ke_Hoach_GoMate`.
5. Current code/teammate README as implementation state.
6. Old adjusted plan: `Ke_Hoach_12_Tuan_GoMate_HoanChinh` only as historical context.

## Known document conflict

The old adjusted plan describes migrating the existing Supabase application module-by-module.

The newer redesigned plan and the Master Spec explicitly replace that direction:
- build the new architecture,
- reuse old business knowledge, screens/assets and lessons selectively,
- do not carry old Supabase schema/data 1:1.

Therefore Codex must not revive Supabase migration as the default implementation strategy.

## Current Auth conflict

The teammate Auth package works but was built before full canonical alignment. In particular it:
- uses four tables only,
- uses `schema.sql`,
- deliberately does not use Flyway,
- stores onboarding choices in `user_settings`,
- includes Google OAuth/sign-in/linking.

Those choices are documented as **current implementation state**, not a replacement for the Master Spec. Read `AUTH_CURRENT_STATE.md` before changing Auth.

## Current UI merge state

Newest reference is xuanthu `f11c6f7` (2026-10-15). Read `UI_F11C6F7_INTEGRATION_MATRIX.md` and `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md` first for this integration. Create-time selected users are now invitations, never direct membership. Accept is only in Notifications. Settings PIN backend is deferred. Older phase documents below describe historical implementation unless explicitly retained.

Latest `xuanthu` UI integration is tracked in `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md`.

The handoff specs for UI/business boundaries are:
- `UI_BUSINESS_HOME_RECOMMENDATION_SEARCH.md`
- `MOMENT_BACKEND_BUSINESS_SPEC.md`
- `MESSAGE_BACKEND_BUSINESS_SPEC.md`

Important update: Moment is now product scope after the MongoDB ownership alignment. Moment Backend V1 is implemented in `MOMENT_BACKEND_V1.md`; Home Moment data now uses API/Mongo/Cloudinary, while Post feed remains mock/deferred. Post create/read P1B is now real and documented in `POST_PUBLISH_P1B.md`; Profile grid/management is implemented in `PROFILE_POST_P1C.md` (V20), which overrides NEW Post video to 30s while preserving old published 31-60s videos.

Current Account/Profile + Direct Message V1 status is tracked in `ACCOUNT_PROFILE_AND_DIRECT_MESSAGE_V1.md`. Direct message is real for one-to-one conversations.

Pre-Big-Update Trip/Maps/Messaging knowledge is tracked in:
- `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md`
- `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md`
- `TRIP_MAPS_BIG_UPDATE_READINESS_AUDIT.md`

Latest AI v13 runtime integration is tracked in `AI_RANKER_V13_INTEGRATION.md`.

Latest Group Trip Chat Phase 1 backend foundation is tracked in `BIG_UPDATE_PHASE1_GROUP_TRIP_CHAT.md`.
Latest Group Trip UI closure status is tracked in `BIG_UPDATE_PHASE1_UI_CLOSURE.md`.
Latest create-time Trip membership closure is tracked in `BIG_UPDATE_PHASE1_CREATE_TRIP_MEMBERSHIP_CLOSURE.md`.
Latest user-facing Trip Phase 1 bugfix notes are tracked in `TRIP_PHASE1_UI_TEST_FIXES.md`.
Latest Trip Stop occurrence/time/reorder/optimize Phase 2 status is tracked in `BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md`.
Latest pinned Trip/member location Phase 3 status is tracked in `BIG_UPDATE_PHASE3_PINNED_TRIP_MEMBER_LOCATION.md`.
Current Trip business is `TRIP_PIN_CENTRIC_BUSINESS_RESET.md` (V16), with the 2026-10-21 clarification in `MAP_PIN_SWITCH_LAST_KNOWN_FIX.md`: no journey status, Start/Complete/Cancel or Share switch. Explicit pin ACK immediately selects that Trip on Map; passive restore preserves a viewed preview. PIN alone authorizes own GPS; UNPIN/switch stops old-Trip publishing but RETAINS the real last-known snapshot for current members. Leave/remove/delete still revoke/clean location. Preserve existing native 15s/60s driver, membership, invitations, leader transfer, chat/delete and Map performance. Phase 4.5/4.6 are historical only.
Latest Trip invitation lifecycle/UI status is tracked in `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md`; `BIG_UPDATE_PHASE4_1_TRIP_INVITATION_LIFECYCLE.md` is superseded history.
Latest saved-PERSONAL Trip member-picker fix is `TRIP_INVITE_IMMEDIATE_SEND_FIX.md`: Add sends immediately; no second Send step after create succeeds.
Latest Leader pending-invitation cancellation is `TRIP_INVITATION_CANCELLATION.md`: V11 enables CANCELLED; cancel belongs to the outer pending list for PERSONAL/GROUP. The saved-Trip Add popup hides already-invited users and has no cancellation action.
Latest foreground delivery foundation is `REALTIME_NOTIFICATION_FOUNDATION_V1.md`: authenticated SSE after commit, one global Flutter receiver, REST/PostgreSQL truth, unchanged 12s polling fallback. No new migration, push, or GPS realtime.
Android FCM/device registration extends that foundation in `PUSH_NOTIFICATION_FOUNDATION_ANDROID_V1.md` with V12 device_tokens. Phase 4.3 is closed after physical Android background/normal-termination delivery, foreground dedupe and stale-cancel tap checks; the document distinguishes automated-only remaining variants. iOS/APNs and GPS/schedulers remain deferred.
Latest safe Map performance audit/optimization status is tracked in `MAP_PERFORMANCE_AUDIT_AND_OPTIMIZATION.md`.
Latest member leave/remove rules are in `TRIP_MEMBER_LIFECYCLE_PHASE4_4A.md`: Phase 4.4A closed with V13 live/clean/restored migration, 101 backend and 61 Flutter tests. Last MEMBER removal makes Trip PERSONAL, closes/retains C1, and later acceptance creates fresh C2. This explicitly supersedes the historical no-downgrade rule. Native member UI remains to be manually tested; V13 changes only conversation lifecycle/active-link uniqueness.

## If compact docs are insufficient

Only then consult the original DOCX/PDF source. Do not invent a missing rule.
