# MONGODB_FOUNDATION.md

Updated: 2026-10-07

## What Was Added

MongoDB is now part of local Docker infrastructure and Spring Boot configuration.

Docker service:

```text
mongo
image: mongo:7.0
internal: mongo:27017
local: 127.0.0.1:27017
volume: mongo_data
```

Spring config:

```text
MONGO_DATABASE=gomate
MONGO_URI=mongodb://mongo:27017/gomate?serverSelectionTimeoutMS=1500&connectTimeoutMS=1500&socketTimeoutMS=1500
```

Local non-Docker backend fallback:

```text
MONGO_URI=mongodb://127.0.0.1:27017/gomate?serverSelectionTimeoutMS=1500&connectTimeoutMS=1500&socketTimeoutMS=1500
```

## Implemented Collection

```text
interaction_events
```

Document fields:

```text
_id
eventId
userId
eventType
entityType
entityId
source
createdAt
metadata
```

Implemented event:

```text
eventType = HOME_RECOMMENDATION_SERVED
source = spring.recommendations.home
```

## Indexes

Created idempotently on startup:

```text
ux_interaction_events_event_id: eventId unique
idx_interaction_events_user_created: userId + createdAt desc
idx_interaction_events_type_created: eventType + createdAt desc
idx_interaction_events_entity_created: entityType + entityId + createdAt desc
```

No TTL index is created in this foundation step.

## API/Health

Existing health endpoint remains:

```text
GET /api/v1/health
```

Mongo-specific check:

```text
GET /api/v1/health/mongo
```

This endpoint reports Mongo connectivity but core application health is not tied to Mongo availability.

## Runtime Behavior

`RecommendationService` calls `InteractionEventService` after generating Home recommendations.

If MongoDB write fails:
- event persistence fails closed at the logging boundary;
- the recommendation response is still returned;
- Spring logs a warning with event type and user ID;
- no token/header/raw GPS data is persisted.

## Not Included

This foundation step deliberately does not add:
- PostgreSQL migration;
- Moment backend API;
- Message backend API;
- Mongo collections for messages/moments/location;
- Flutter Mongo SDK;
- Mongo Express.

