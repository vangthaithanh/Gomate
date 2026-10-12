# XUANTHU UI + Backend Integration Audit

Updated: 2026-10-08

Scope: merge latest `origin/xuanthu` UI into the current GoMate codebase while preserving the working Auth, Place, Map/Route, Trip, AI FastAPI, global cold-start recommendation, and Screen 3 contextual reranking flows.

Pre-Big-Update update 2026-10-10:
- After `git fetch --all --prune`, `origin/xuanthu` advanced to `01b24f7` (`Cập nhật chính lịch trình, maps, mess`).
- The new UI delta touches Trip, Map and Messaging heavily. It overlaps local real-integration edits in `home_screen.dart`, `main_shell.dart`, `map_screen.dart`, `message_repository.dart`, `message_screen.dart`, and `message_widgets.dart`.
- Do not checkout/overwrite those files blindly. Use `PRE_BIG_UPDATE_XUANTHU_SYNC_AUDIT.md` as the merge checklist before applying the latest UI commit to the dirty working tree.

Phase 1.1 UI closure update 2026-10-10:
- Create Trip UI has no manual personal/group picker.
- The default trip name must be changed before creation.
- Flutter sends `selectedMemberIds`; backend derives `PERSONAL/GROUP` from persisted membership.
- The main Trip tab no longer seeds production rows from demo trip data.
- Trip -> Chat uses the real `linkedConversationId`; Chat -> Trip uses the real `linkedTripId`.
- MessageScreen now uses the real conversation repository for both direct and group conversation rows.
- This closes the create-time selected member Group Trip + linked Group Chat test path. Add/remove member after an existing Trip remains deferred.

This audit records integration boundaries only. It does not replace the detailed business handoff files:

- `UI_BUSINESS_HOME_RECOMMENDATION_SEARCH.md`
- `MOMENT_BACKEND_BUSINESS_SPEC.md`
- `MESSAGE_BACKEND_BUSINESS_SPEC.md`

## Merge Summary

| Item | Result |
|---|---|
| Source branch | `origin/xuanthu` |
| Merge type | Fast-forward from `87cd4fa` to `28a41b9` |
| Conflict files | None |
| New UI preserved | Home feed interactions, Search, Message tab, Moment UI, Profile/Settings/Auth visual updates |
| Backend/schema changes | None introduced by this audit task |
| MongoDB | Foundation added after UI merge for interaction events; Message/Moment APIs still not implemented |

## Module Audit

| Module | UI status after merge | Current data source | State | Existing backend dependency | Future backend dependency | Conflict/mismatch discovered | Action taken | Deferred action |
|---|---|---|---|---|---|---|---|---|
| Home | New `xuanthu` feed layout integrated with Moments rail, Post cards, user suggestions, and place suggestions | Mixed: demo posts/users/moments, real place recommendation | REAL + MOCK | `RecommendationRepository -> /api/v1/recommendations/home`; Social Relationship API is now available for follow actions | Feed, social interactions, user suggestions | Home had `onOpenPostLocation` hook but `MainShell` was not wiring it | Wired Home location callback to Map tab and added Map focus target support; backend follow/mutual API added without wiring mock suggestions | Replace demo feed/user suggestions with real Social/User APIs later |
| Recommendation | Existing global cold-start and Screen 3 rerank preserved | Real Spring recommendation + AI FastAPI + PostgreSQL Place | REAL | `/api/v1/recommendations/home`, AI FastAPI `/recommend` | Recommendation events and paginated recommendation endpoint | Risk of UI merge reverting to demo/hard-coded places | Verified Home/Search both use `RecommendationRepository`; no `da_lat` default reintroduced | Add cursor pagination for Search Discovery later |
| Search | New Search UI and repository boundary integrated | Suggested Places real; user search real; recent/post/hashtag mock | REAL + MOCK | Recommendation backend for discovery places; `GET /api/v1/users/search`; Social Relationship APIs | Unified `/search`, recent search, post/hashtag search | Place and User are wired through current real APIs; Post/recent/hashtag remain deferred | Replaced runtime demo users with backend user search; added public profile/follow/direct-message wiring | Implement Post Search backend and persistent recent search later |
| Post/Feed | New feed cards, comments, share, report/not-interested UI integrated | Demo repository/local state | MOCK | None for post interactions yet | Social Post, Comment, Share, Report APIs | Business spec requires idempotent backend actions; current UI is local demo | Preserved mock via `PostInteractionRepository`; no schema/API invented | Build Social backend in a separate scoped task |
| Comment | Comment sheet UI integrated | Demo repository/local state | MOCK | None | Comment/reply/media/like/delete APIs | UI supports richer behavior than backend currently has | Preserved demo boundary | Implement comment backend later |
| Share | Share sheet UI integrated | Demo repository/local state | MOCK | None | Eligible share targets, message/share APIs | Message backend not present yet | Preserved demo boundary | Implement share targets + message integration later |
| Moment | Moment strip, viewer, camera, own moment screens integrated | Real `ApiMomentsRepository` backed by Spring/Mongo/Cloudinary | REAL V1 | `/api/v1/moments/**`, `/api/v1/moment-mutes/**`, Direct Message V1 for Moment messages | Report/Admin backend and richer camera/location metadata | UI report hook exists but no shared Report backend yet | Implemented Moment Backend V1 and switched active Home Moment source from demo to API | Add shared Report/Admin integration later |
| Message | Message tab replaces Explore and includes direct/group/pending/chat management UI | Real conversation repository for DIRECT and GROUP; some rich UI controls remain future scoped | REAL + DEFERRED | Conversation metadata in PostgreSQL, message bodies in MongoDB | WebSocket/realtime, media messages, richer group management | Message UI still contains controls beyond Phase 1 backend scope | Wired DIRECT/GROUP list/detail/text send to real APIs; no fake production group fallback | Implement media/realtime/group-member actions later |
| Trip/Group | Existing Trip screens remain; Message UI includes group concepts | Real Trip API for list/detail/create/update/delete; linked group chat through backend V7 | REAL + DEFERRED | Trip core APIs + V7 group conversation linkage | Invite/member lifecycle, leader-only management actions, realtime location | UI has member-management affordances that exceed Phase 1.1 backend scope | Wired creator-only Group Trip -> linked Chat -> Chat -> Trip flow using real IDs | Build invite/member lifecycle in later phase |
| Profile/Settings | `xuanthu` Profile/Settings UI preserved | Existing Auth session and Account/Profile APIs | REAL + MOCK | Auth/logout/session; `PATCH /users/me/profile`; `POST /auth/change-password` | User avatar binary upload if needed | Current profile supports avatar URL, not binary upload | Wired edit profile/avatar URL/change password to existing APIs | Add Cloudinary-backed user avatar upload later if product requires it |
| Map/Place | Existing Mapbox/Place API integration preserved | Real Place API and route APIs | REAL | Place, route, Mapbox | Post location focus from feed | Home location hook was not wired | Added `MapFocusTarget` and MainShell-to-Map bridge | Backend Post response should include `placeId` or coordinate for real focus |

## Recommendation Contract Check

| Behavior | Status |
|---|---|
| Home default global recommendation | Preserved |
| `destinationKey` optional | Preserved |
| Candidate pool 50 | Preserved |
| Home section limit 10 | Preserved |
| Screen 1-2 semantic handled by AI | Preserved |
| Screen 3 contextual rerank handled by Spring | Preserved |
| `GAN_TOI` with GPS boosts near places | Preserved |
| No GPS semantic fallback | Preserved |
| `_PlaceSuggestionSection` uses real recommendation backend | Preserved |
| Search Discovery uses same recommendation source | Preserved |

## Active Mismatches / Gaps

1. Moment V1 is real for image upload, home strip, view, reaction, mute, delete, and Moment-to-message. Report remains deferred until shared Report/Admin backend exists.
2. Message UI is much richer than current backend scope. Direct one-to-one messaging and creator-only linked Group Trip Chat are real; invite/member lifecycle, richer group actions, and message media remain deferred.
3. Post/Feed interactions are visually complete but not production persisted. They remain behind `PostInteractionRepository`.
4. Search has real recommended places and real user search/follow profile flow, but posts/hashtags/recent searches remain mock/deferred.
5. Post location can now switch to Map and focus when `placeId` or coordinate exists, but current demo posts mostly only provide a label.
6. Home User Suggestions are still mock/hard-coded. Search User is real, but Home suggestion ranking/source still needs a real user/recommendation repository before production wiring.

## Deferred Backend Work

- MongoDB foundation now exists for interaction events; message body/history and Moment collections are future scoped tasks.
- Conversation metadata and Message repository implementation.
- Social Post/Feed APIs for like/save/not-interested/report/comment/share.
- Unified Search API with Place/User/Post/Hashtag and recent search.
- Dedicated Moment backend implementation, if prioritized after the MongoDB foundation.

## No-Go Items Confirmed

- No new Flyway migration.
- No MongoDB dependency/container/config.
- No new production business table.
- No fake production API for mock UI.
- No direct AI call from Flutter.
- No direct DB access from Flutter.
