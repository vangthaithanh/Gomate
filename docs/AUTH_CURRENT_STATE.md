# AUTH_CURRENT_STATE.md — Current Auth Implementation vs Canonical GoMate

This file records what the teammate's current Auth README says, and how Codex must treat it.

## 1. Current implemented Auth behavior

The teammate package documents:

```text
Flutter -> Spring Boot Java 17 -> PostgreSQL
```

Docker currently runs:
- `postgres` container,
- `api` Spring Boot container.

Current email registration:
1. nickname + email + password,
2. API validates,
3. password BCrypt hash,
4. create account/profile/settings/session in one transaction,
5. duplicate email/nickname rolls back.

Current login:
- checks password + account status,
- access token lifetime documented as 15 minutes,
- refresh token lifetime documented as 30 days,
- database stores SHA-256 of refresh token rather than raw token.

Current remember-login behavior:
- if remember is enabled, token uses secure storage,
- startup attempts session validation/refresh,
- access expiration triggers one refresh + retry,
- remember disabled keeps session only in RAM.

Current logout:
- revoke server refresh session,
- remove device-side tokens.

These are useful working behaviors and should be preserved during a structure-only refactor unless the user asks otherwise.

## 2. Current Google behavior

Current package also implements Google:
- Flutter obtains Google ID token.
- Spring validates signature, issuer, audience, expiration and verified email.
- Backend finds/creates account and issues GoMate tokens.
- If Google email is verified and does not exist in GoMate, backend creates a Google-only user automatically.
- If Google email already exists as an email/password account and is not linked yet, backend auto-links that verified Google subject and logs in.
- If the email is already linked to a different Google subject, backend rejects with 409.
- `/auth/google`
- `/auth/google/link`

Current README also documents:
- Google Web Client ID,
- Android OAuth Client,
- debug SHA-1,
- package mentioned there: `com.example.gomate`.

Important:
- Inspect actual Android `applicationId` before changing OAuth configuration. README may become stale after repository refactor.
- Never put Google Client Secret in Flutter.

## 3. Current database documented by teammate

Only four tables:

```text
users
user_profiles
user_settings
refresh_sessions
```

Current deviations documented:
- `users.password_hash` may be NULL for Google account,
- `users.google_subject` exists/unique,
- onboarding completion/option codes stored in `user_settings`,
- no separate interest tables,
- no OAuth table,
- schema initialized through `backend/src/main/resources/schema.sql`,
- Flyway intentionally not used in that package.

Current DB:
```text
database: gomate_auth
user: gomate
host: localhost
port: 5432
```

Password is generated into `backend/.env`, which must not be committed.

## 4. Current run commands documented

Backend package currently expects PowerShell from `backend`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-env.ps1
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://localhost:8080/api/v1/health
```

Logs:
```powershell
docker compose logs --tail 100 api
docker compose logs --tail 100 postgres
```

Flutter package currently expects `/mobile`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Android Emulator uses `10.0.2.2` for host Windows backend.

Current README warns:
- `docker compose down` keeps volume,
- do not use `-v` if you want to retain accounts,
- release must use HTTPS,
- Flutter Web/Windows native Google is not supported by this package,
- iOS/macOS Google setup not configured/tested.

## 5. Current API documented

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/google
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
POST /api/v1/auth/google/link
POST /api/v1/auth/change-password
GET  /api/v1/users/me
PUT  /api/v1/users/me/onboarding
```

Canonical Master Spec additionally expects:
```text
POST /api/v1/auth/password/forgot
POST /api/v1/auth/password/reset
PATCH /api/v1/users/me
GET/PATCH /api/v1/users/me/settings
PUT /api/v1/users/me/interests
```

Do not add all missing endpoints automatically during a structure-only task.

## 6. Canonical mismatches that Codex must know

### Mismatch A — Google OAuth

Canonical Master Spec:
```text
Auth MVP = email/password + email reset
No SMS/OAuth in core
```

Current package:
```text
Google login/linking implemented
```

Rule:
- Existing Google code is an **extension outside canonical core**, not the core requirement.
- Do not silently delete working Google code when only reorganizing structure.
- Do not let Google-specific schema/API redefine the canonical core without user approval.
- If the team wants strict Master Spec alignment later, this requires an explicit scope decision.

### Mismatch B — schema.sql vs Flyway

Canonical:
- reproducible DB migration uses Flyway,
- staged V1 begins Auth/User/Interest.

Current:
- `schema.sql`,
- no Flyway.

Rule:
- Structure-only refactor: preserve runtime first.
- DB-alignment task: migrate intentionally to Flyway; do not just rename `schema.sql` to `V1` if existing DBs already contain data/schema without planning baseline/migration history.

### Mismatch C — four tables vs canonical Auth V1

Canonical Auth/User/Interest includes:
```text
users
refresh_sessions
password_reset_tokens
user_profiles
user_settings
interest_groups
interest_options
user_interests
```

Current has only four.

Rule:
- Do not pretend current four-table schema is the final canonical V1.
- Do not add missing tables during unrelated restructuring.
- When user asks for canonical DB alignment, add them via planned Flyway migrations and preserve existing data.

### Mismatch D — onboarding storage

Canonical:
- load `interest_groups` / `interest_options`,
- upsert/replace `user_interests`,
- skip allowed.

Current:
- onboarding option codes stored directly in `user_settings`.

Rule:
- current behavior may continue until a dedicated onboarding/data alignment task,
- canonical target is normalized interest tables.

### Mismatch E — users schema

Canonical `users` baseline:
- `password_hash NOT NULL`,
- no `google_subject` in core baseline.

Current Google extension:
- nullable password hash,
- `google_subject`.

Rule:
- this is a deliberate extension conflict.
- Never "fix" it by making password NOT NULL if that would destroy Google-only accounts.
- Requires explicit decision on how Google extension coexists with canonical core.

### Mismatch F — API envelope

Master Spec requires:
```json
{"data": ..., "requestId": "..."}
```

Teammate README's PowerShell example accesses:
```text
$session.accessToken
```

This suggests the current response may be unwrapped, but README alone is not enough to prove actual code shape.

Rule:
- inspect actual controller/DTO before changing,
- do not change Flutter/backend response shape during structure-only refactor,
- contract-alignment is a separate coordinated backend+Flutter task.

## 7. User-requested structure refactor target

The user intends to ask Codex to reorganize the teammate package.

Target:
```text
GOMATE/
├── android/
├── ios/
├── lib/
├── assets/
├── pubspec.yaml
├── backend/
├── docker-compose.yml
├── .env.example
├── AGENTS.md
└── docs/
```

Expected refactor work:
- move Flutter from `/mobile` to repository root if that is what the actual repo currently uses,
- keep Spring under `/backend`,
- move/centralize Compose entry point to root as user requested,
- update Compose `build.context`, env-file paths, volume names only when needed,
- update PowerShell scripts and README paths,
- update Flutter/Android relative paths,
- update run instructions,
- update `.gitignore`,
- verify backend still connects to PostgreSQL,
- verify Flutter still points to API correctly,
- verify Auth behavior unchanged.

Do not:
- redesign screens,
- replace JWT implementation,
- remove Google code,
- switch DB schema to Flyway in the same change unless the user explicitly asks,
- delete local Docker data,
- rename applicationId casually because Google OAuth SHA/client config depends on it.

## 8. Minimum regression after structure refactor

Backend:
```text
health endpoint returns OK
register succeeds
duplicate email rejected
duplicate nickname rejected
wrong login rejected
valid login succeeds
refresh rotation works
logout revokes current session
GET /users/me works with Bearer token
```

Flutter:
```text
flutter pub get
flutter analyze
flutter test
register UI -> API works
login UI -> API works
remember-me behavior works
logout works
app restart behavior works
```

Google, if configured:
```text
Google login for new Google email
password-account with same verified Google email auto-links and logs in
Google login after auto-link
reject same email with different Google subject
```

Infrastructure:
```text
docker compose up -d --build
docker compose ps
backend -> postgres connectivity
no loss of existing volume unless intentionally reset
```

## 9. What to preserve as knowledge even after alignment

Good implementation choices already documented:
- transaction on multi-record registration,
- BCrypt password,
- hashed refresh token,
- token rotation/revocation,
- secure token storage,
- API base URL via `--dart-define`,
- emulator host uses `10.0.2.2`,
- `.env` excluded from Git,
- HTTPS required for release.

These should not be lost merely because structure/schema is being aligned.
