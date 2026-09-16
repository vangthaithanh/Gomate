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
| Place/search/review/save | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Trip/group/invite/location/check-in | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Social/follow/post/chat | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| Notification/FCM | `PROJECT_CONTRACT.md` + `DATABASE_CONTRACT.md` |
| AI/recommendation | `PROJECT_CONTRACT.md` + `ROADMAP_AND_DONE.md` |
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

## If compact docs are insufficient

Only then consult the original DOCX/PDF source. Do not invent a missing rule.
