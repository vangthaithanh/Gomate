# MONGODB_DATA_OWNERSHIP_V1.md

Updated: 2026-10-08

## Goal

MongoDB is the flexible/event data store for GoMate. PostgreSQL remains the business source of truth for core entities and permissions.

## Ownership Rules

PostgreSQL owns:
- users, auth sessions, profiles, settings, interests;
- places, categories, media metadata, reviews, saved places;
- trips, trip members, trip stops, reminders, permissions;
- conversation metadata when Message is implemented;
- moderation decisions and business records.

MongoDB owns:
- `interaction_events`;
- Message body/history when Message backend is implemented;
- Moment content/social events when Moment backend is implemented;
- runtime location/history/archive documents when Location backend is implemented;
- audit/recommendation logs that do not become business source of truth.

Cloudinary owns binary media. MongoDB/PostgreSQL only store Cloudinary URL/public_id references and metadata.

## Current Implementation

MongoDB Foundation V1 first implemented:

```text
interaction_events
```

The first event is:

```text
HOME_RECOMMENDATION_SERVED
```

It is written after successful `/api/v1/recommendations/home` and records a safe summary of the recommendation result.

## Moment Scope Update

Moment is now product scope because the latest UI includes Moment surfaces and the user approved the direction.

Moment Backend V1 implements:

```text
moments
moment_views
moment_reactions
moment_mutes
```

Moment media is stored in Cloudinary; MongoDB stores only URL/public_id metadata. Permissions continue to derive from PostgreSQL users and mutual follows. Moment V1 intentionally does not create PostgreSQL tables or Flyway migrations.

## Privacy/Safety Rules

Mongo events must not store:
- raw JWT/access/refresh tokens;
- Firebase or OAuth credentials;
- passwords or auth secrets;
- full request headers;
- exact runtime GPS for recommendation logging.

For nearby/GPS recommendation context, store only coarse context metadata such as context code, candidate count, returned place IDs, and scoring source.

## Failure Policy

MongoDB logging is non-critical. If MongoDB is down:
- Auth/Place/Trip/Route/Home recommendation must still return according to their own rules;
- Spring logs a warning;
- no PostgreSQL transaction is rolled back only because interaction logging failed.
