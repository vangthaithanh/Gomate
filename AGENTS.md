# AGENTS.md — GoMate Codex Rules

> Root instructions for Codex/AI coding agents working in the GoMate repository.
> Updated: 2026-09-11.
>
> Goal: keep the team consistent, protect working code, and avoid spending tokens rereading the full DOCX specifications for ordinary coding tasks.

## 0. Mandatory startup behavior

Before editing code:

1. Inspect the repository tree and `git status`.
2. Read this file.
3. Read `docs/CODEX_INDEX.md`.
4. Load only the task-specific knowledge file(s) listed there.
5. Inspect the actual files involved in the task before proposing changes.
6. Never assume a README is newer than the canonical Master Spec; use the source precedence below.
7. Do not silently "fix" unrelated architecture, schema, API, UI, or teammate code.

When current code conflicts with the canonical design:
- report the conflict,
- preserve working behavior unless the requested task explicitly includes alignment,
- separate structural refactor from business/schema changes whenever possible.

## 1. Source precedence

Use this order when sources conflict:

1. User's newest explicit instruction.
2. This `AGENTS.md`.
3. `GoMate_Master_Spec_v1_FIXED` — canonical Business & System Design Baseline, locked 2026-09-04.
4. `Ke_Hoach_GoMate` — redesigned 12-week roadmap.
5. Current repository behavior/code and teammate implementation notes.
6. `Ke_Hoach_12_Tuan_GoMate_HoanChinh` — historical/superseded migration-oriented plan; use only for history/role context where it does not conflict with items 1-4.

Known conflict:
- The historical plan says gradually migrate the existing Supabase system.
- The newer redesigned plan + Master Spec say build the new GoMate architecture and use the old system only as a source of business knowledge/UI/assets/experience; do **not** migrate Supabase 1:1.
- Therefore Codex must follow the newer design.

## 2. User-selected repository structure target

Unless the user later changes this decision, target:

```text
GOMATE/
├── android/                  # Flutter
├── ios/                      # Flutter
├── lib/                      # Flutter
├── assets/                   # Flutter assets
├── pubspec.yaml
│
├── backend/                  # Spring Boot modular monolith
│   ├── pom.xml
│   └── src/
│       └── main/
│           ├── java/
│           └── resources/
│               └── db/
│                   └── migration/
│
├── docker-compose.yml        # local infrastructure entry point
├── .env.example
├── .gitignore
├── AGENTS.md
└── docs/
```

The current teammate Auth README refers to a `/mobile` folder and Compose being run from `/backend`. That is **current implementation state, not the final structure target**.

When asked to reorganize:
- preserve working Flutter behavior and assets,
- preserve working backend behavior,
- move files carefully rather than recreating them,
- fix relative paths, Compose build contexts, scripts, README commands, IDE/run instructions, tests, and CI references affected by moves,
- do not mix the structural move with unnecessary schema/business changes.

## 3. Architecture boundaries — locked

```text
Flutter
   -> REST / WebSocket
Spring Boot modular monolith
   -> PostgreSQL          business source of truth
   -> MongoDB             events/messages/location/audit/recommendation logs
   -> Cloudinary          binary media
   -> Firebase            FCM + product analytics only
   -> AI FastAPI          recommendation score/rank only
```

Rules:
- Flutter never queries PostgreSQL/MongoDB directly.
- Flutter never owns important permission/business transactions.
- Spring Boot owns auth, permission, server validation, transactions and business rules.
- PostgreSQL is the final source of truth for business state.
- MongoDB must not duplicate User/Trip/Place as a second business source of truth.
- AI never writes business state; Spring decides final eligibility.
- Firebase is not the business database.
- Cloudinary/media provider stores binary media, not core business metadata.
- Do not create Java microservices for GoMate during the thesis. Spring Boot is one deployable modular monolith.

## 4. Backend package baseline

Use domain modules. A module may contain `controller/service/repository/entity/dto/mapper` as needed.

```text
common          exception, response, security, requestId, config
auth            users/session/password reset authentication concerns
user            profile/settings/interests/follow/block
place           place/category/review/save/submission/search
social          post/comment/hashtag/bookmark
chat            conversation metadata, WebSocket, Mongo messages
trip            trip/member/invite/stop/reminder/checkin
location        Mongo current/history/archive policies
notification    notification record/device token/FCM
recommendation  interaction logging + AI client + fallback
media           Cloudinary/media adapter
admin           moderation/report/audit orchestration
```

Rules:
- Controller = HTTP boundary, not a place for large business logic.
- Service = business rules/transactions/permissions.
- Repository = persistence.
- Use DTOs at API boundaries; do not casually expose JPA entities.
- Do not cross-read/write another module's storage just because it is convenient.

## 5. Flutter baseline

Target organization over time:

```text
core/network        Dio, auth interceptor, error mapper
core/storage        secure token storage
core/router         go_router/navigation guard
features/auth
features/home
features/place
features/social
features/chat
features/trip
features/map
features/notification
features/recommendation
shared
```

Do not mass-refactor unrelated Flutter code only to make the tree look perfect.

Rules:
- preserve existing UI unless redesign is explicitly requested,
- no direct DB access,
- no secrets,
- keep API calls in the network/service/repository layer rather than scattering `Dio()` through widgets,
- store auth tokens securely,
- include loading/error/empty/permission-denied states where relevant,
- do not add a new state-management package without need.

## 6. PostgreSQL + Docker + Flyway — mandatory

Local PostgreSQL is run through Docker/Compose.

Never commit:
- PostgreSQL Docker volume,
- local database files,
- raw `.env`,
- real passwords/secrets.

Schema synchronization uses **Flyway**.

Migration location:

```text
backend/src/main/resources/db/migration/
```

Canonical staged migrations:

```text
V1 -> Auth/User/Interest
V2 -> Place/category/tag/save/review/submission
V3 -> Social/follow/post/comment/bookmark
V4 -> Conversation metadata (+ Mongo messages/WebSocket integration)
V5 -> Trip/member/invite/stop/reminder/checkin (+ Mongo location)
V6 -> Notification/device/report/admin/audit
then -> AI/recommendation pipeline
```

Migration rules:
1. Once a migration is shared/merged/run by the team, do not rewrite it casually.
2. Create a new migration for later schema changes.
3. Do not delete/renumber old shared migrations.
4. Do not use `schema.sql` or Hibernate `ddl-auto=create/update` as the long-term schema source of truth.
5. Prefer `ddl-auto=validate` after migrations are established.
6. Flyway must automatically apply missing versions.
7. Seed/demo data is separate from production schema migrations unless deliberately designed otherwise.
8. Do not run destructive `docker compose down -v` without explicit permission.

## 7. Auth core — locked baseline

Core MVP Auth is:
- email/password,
- reset password through email token/link,
- Spring Security + JWT,
- short-lived access token + revocable refresh session,
- secure token storage in Flutter.

Core does **not require** SMS/OAuth.

Security:
- normalize email lowercase and unique,
- nickname unique and trimmed,
- never store plain-text password,
- never store raw refresh token,
- login checks account status,
- LOCKED -> 403,
- wrong credentials -> 401,
- logout revokes current refresh session,
- protected "my" operations derive user identity from JWT/principal, not a client-supplied userId,
- do not log raw password/token/secret.

Important: the teammate implementation currently contains Google sign-in/linking. It is an existing extension and conflicts with the canonical "OAuth not in core" decision. **Do not silently delete it during a structure-only refactor.** See `docs/AUTH_CURRENT_STATE.md`.

## 8. API conventions — locked

Base path:

```text
/api/v1
```

Canonical success envelope:

```json
{
  "data": {},
  "meta": {},
  "requestId": "..."
}
```

Canonical error envelope:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Readable message",
    "fieldErrors": {}
  },
  "requestId": "..."
}
```

`meta` and `fieldErrors` are optional.

Status baseline:
- 400 validation/request invalid
- 401 unauthenticated/invalid credential
- 403 forbidden/account/permission
- 404 not found or intentionally hidden
- 409 conflict/duplicate
- 422 business-rule violation where useful

Other rules:
- ISO-8601 UTC on backend/API; Flutter converts for display.
- UUID/BIGINT types must be explicit and consistent.
- Flutter must not guess JSON shape.
- Breaking contract changes require planned contract/doc/test updates.

## 9. Locked business rules

Do not change these without explicit approval:

- No Moments/Story domain in the new system.
- Post is the social sharing content type.
- PUBLIC account follows immediately; PRIVATE account creates follow request.
- Friendship = mutual active follow; no mandatory `friends` source table.
- Block overrides follow/DM privileges.
- Review does not require check-in; valid check-in may set verified-visit signal.
- Official Place comes from Admin, controlled external import, or approved user submission.
- One Trip domain handles PERSONAL and GROUP.
- Exactly one active LEADER per Trip.
- Only LEADER edits/reorders stops, starts/completes/cancels Trip, kicks members, approves member-originated invites.
- Member invite flow: invitee accepts first, then Leader approves.
- Leader-originated invite: invitee acceptance is enough to join.
- PERSONAL can become GROUP when another member joins; it does not automatically downgrade.
- Only ACTIVE Trip permits location sharing/check-in.
- Location sharing is opt-in per Trip member.
- Auto check-in must be idempotent per user/stop.
- Raw location is kept 0-7 days; archive must succeed before raw purge.
- Notification business record is written to PostgreSQL before FCM; FCM failure does not roll back business state.
- Turning push off stops FCM, not Notification Center records.
- AI only suggests/ranks; Spring applies business eligibility.
- Admin moderation actions require audit log.

## 10. Change control

Before coding a feature, establish:
- use case,
- permission/business rules,
- API request/response,
- relevant table/collection/event,
- edge/error cases,
- minimum acceptance tests.

Schema/API change:
- update design/contract,
- add migration,
- update tests.

Business-rule change:
- do not silently implement it,
- get team/user agreement,
- update rule/use-case/permission/tests.

Scope change such as adding Moments/OAuth as a core requirement:
- requires explicit approval.

Definition of Done is end-to-end:
- API + DB + UI + test data + error state + related event/audit/notification where applicable.

## 11. Git/team safety

- Inspect `git status` first.
- Never discard teammate changes without explicit instruction.
- Avoid direct unrelated edits on `main`; follow the team's feature-branch/PR workflow.
- Keep commits focused.
- Do not force-push/reset/rewrite other people's history without permission.
- Do not resolve merge conflicts by blindly choosing one side.
- Do not mass-format unrelated files.

Suggested branch examples:

```text
feature/auth
feature/place
feature/trip
```

## 12. Secrets and generated files

Never commit:
- `.env`
- JWT secret/private keys
- OAuth client secrets
- service-account credentials
- DB passwords
- `target/`
- Flutter `build/`
- IDE caches
- Docker DB volume

Commit `.env.example` with placeholders only.

## 13. Validation after changes

Run only the checks relevant to the task, but do run them when possible.

Flutter:
```text
flutter pub get
flutter analyze
flutter test
```

Spring:
- prefer repository Maven wrapper if present,
- run tests,
- validate application startup where relevant.

Database:
- if migration changed, test Flyway against local PostgreSQL when possible.

Docker:
```text
docker compose up -d
docker compose ps
```

Never claim a test passed if it was not actually run.

## 14. Required final report from Codex

After a task, report:
1. what changed,
2. important files changed/created,
3. how the flow now works,
4. migrations/config/dependencies added,
5. tests/commands actually run and results,
6. exact next command/action for the user if needed,
7. unresolved conflicts or risks.

## 15. Token-efficient knowledge loading

Do not reread the original 51-page Master Spec for every task.

Read `docs/CODEX_INDEX.md`, then load only:
- `PROJECT_CONTRACT.md` for architecture/business/API work,
- `DATABASE_CONTRACT.md` for schema/Flyway/data work,
- `AUTH_CURRENT_STATE.md` for current Auth refactor/integration,
- `ROADMAP_AND_DONE.md` for planning/milestones/testing/scope.

The compact files are derived from the project documents and are intended to be the default coding context.
