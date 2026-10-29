# Database Flyway Auth Baseline

## Purpose

This note records the cutover from Spring SQL init (`schema.sql`) to Flyway for the current working Auth database.

## Scope

- Baseline only the current Auth schema.
- Do not create Place tables in this step.
- Do not add `password_reset_tokens`, interest catalog tables, or `user_interests` in this step.
- Preserve Firebase Auth/Google login behavior, including Google-only users with `users.password_hash` set to `NULL`.

## V1 Baseline

Migration:

```text
backend/src/main/resources/db/migration/V1__auth_current_baseline.sql
```

It contains exactly the current four Auth business tables:

- `users`
- `user_profiles`
- `user_settings`
- `refresh_sessions`

It also keeps the current constraints and indexes, including:

- unique `users.email`
- unique `users.google_subject`
- `users.password_hash IS NOT NULL OR users.google_subject IS NOT NULL`
- role/status checks
- cascade foreign keys from profile/settings/session to user
- `ix_sessions_user`
- `ix_sessions_expiry`

## Existing Local Database

The local Docker database already had Auth data before the Flyway cutover. With:

```yaml
spring.flyway.baseline-on-migrate: true
spring.flyway.baseline-version: 1
```

Flyway marks the existing non-empty schema as baseline version 1 and does not rerun V1 on top of existing tables.

## New Machine / Clean Database

On a completely empty PostgreSQL database, Flyway runs `V1__auth_current_baseline.sql` from scratch and creates the four Auth tables plus `flyway_schema_history`.

## Rollback Note

Do not reset the Docker volume for rollback. Use the pre-cutover `pg_dump` backup if data restoration is needed. For ordinary config/build issues, stop the API container, fix or revert the code/config change, and restart without deleting the Postgres volume.
