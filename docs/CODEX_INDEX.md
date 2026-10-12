# CODEX_INDEX.md — What Codex Should Read

This folder is a compact knowledge base for GoMate. It exists to reduce context/token use.

## Always

Codex always reads root `AGENTS.md`.

## Load by task

| Task | Read |
|---|---|
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
| Map/place/routing | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + relevant map/place step note |
| Trip/group/invite/location/check-in | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Pre-Big-Update Trip/Maps/Group Messaging readiness | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `TRIP_MAPS_BIG_UPDATE_READINESS_AUDIT.md` |
| Big Update Phase 1 Group Trip Chat | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE1_GROUP_TRIP_CHAT.md` + `BIG_UPDATE_PHASE1_UI_CLOSURE.md` + `BIG_UPDATE_PHASE1_CREATE_TRIP_MEMBERSHIP_CLOSURE.md` + `TRIP_PHASE1_UI_TEST_FIXES.md` |
| Big Update Phase 2 Trip Stop/time/reorder/optimize | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md` |
| Big Update Phase 3 pinned Trip/member location | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `GoMate_NghiepVu_Trip_Maps_Messaging_FULL.md` + `GOMATE_TRIP_MAPS_MESSAGING_KNOWLEDGE_PRE_BIG_UPDATE_V1.md` + `BIG_UPDATE_PHASE2_TRIP_STOP_TIME_REORDER_OPTIMIZE.md` + `BIG_UPDATE_PHASE3_PINNED_TRIP_MEMBER_LOCATION.md` |
| Social/follow/post/chat | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Social relationship foundation / follow / mutual friend | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md` + `MONGODB_DATA_OWNERSHIP_V1.md` + `MONGODB_FOUNDATION.md` + `MOMENT_BACKEND_BUSINESS_SPEC.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` |
| Account/Profile + Direct Message V1 | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `AUTH_CURRENT_STATE.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `ACCOUNT_PROFILE_AND_DIRECT_MESSAGE_V1.md` |
| Real User Search + Follow UI V1 | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` + `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md` + `SOCIAL_RELATIONSHIP_FOUNDATION_V1.md` + `ACCOUNT_PROFILE_AND_DIRECT_MESSAGE_V1.md` + `AUTH_CURRENT_STATE.md` + `MESSAGE_BACKEND_BUSINESS_SPEC.md` + `REAL_USER_SEARCH_FOLLOW_UI_V1.md` |
| Notification/FCM | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
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

Latest `xuanthu` UI integration is tracked in `XUANTHU_UI_BACKEND_INTEGRATION_AUDIT.md`.

The handoff specs for UI/business boundaries are:
- `UI_BUSINESS_HOME_RECOMMENDATION_SEARCH.md`
- `MOMENT_BACKEND_BUSINESS_SPEC.md`
- `MESSAGE_BACKEND_BUSINESS_SPEC.md`

Important update: Moment is now product scope after the MongoDB ownership alignment. Moment Backend V1 is implemented in `MOMENT_BACKEND_V1.md`; Home Moment data now uses API/Mongo/Cloudinary, while Post feed remains mock/deferred.

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

## If compact docs are insufficient

Only then consult the original DOCX/PDF source. Do not invent a missing rule.
