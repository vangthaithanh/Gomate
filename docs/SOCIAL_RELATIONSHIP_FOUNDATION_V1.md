# SOCIAL_RELATIONSHIP_FOUNDATION_V1.md

Updated: 2026-10-07

## Scope

This step adds the real Social Relationship foundation for GoMate:

- source of truth: PostgreSQL;
- follow edge table: `user_follows`;
- mutual friend is derived, not stored;
- MongoDB records best-effort interaction events only.

This step does not implement Moment backend, Message backend, Share backend, post feed backend, global block, or follow request workflow.

## PostgreSQL Schema

Migration:

```text
backend/src/main/resources/db/migration/V5__social_relationship_foundation.sql
```

Table:

```text
user_follows
```

Columns:

```text
follower_user_id UUID NOT NULL FK users(id) ON DELETE CASCADE
followed_user_id UUID NOT NULL FK users(id) ON DELETE CASCADE
created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
```

Constraints:

```text
PRIMARY KEY (follower_user_id, followed_user_id)
CHECK (follower_user_id <> followed_user_id)
```

Indexes:

```text
ix_user_follows_followed_follower
ix_user_follows_follower_created
ix_user_follows_followed_created
```

No `friends`, `friendships`, `mutual_friends`, `user_relationships`, or `user_blocks` table was created.

## Relationship Rule

Directed follow:

```text
A follows B
→ user_follows(follower_user_id=A, followed_user_id=B)
```

Mutual friend:

```text
EXISTS(A follows B)
AND
EXISTS(B follows A)
```

Unfollow one direction immediately makes the relationship non-mutual.

## API

Base path:

```text
/api/v1
```

Endpoints:

```text
PUT    /users/{userId}/follow
DELETE /users/{userId}/follow
GET    /users/{userId}/relationship
GET    /users/me/following?page=&size=
GET    /users/me/followers?page=&size=
GET    /users/me/mutual-friends?page=&size=
```

The actor is always resolved from the JWT. Client-supplied `followerUserId` is ignored.

Relationship response:

```json
{
  "userId": "target-user-id",
  "followingByMe": true,
  "followsMe": false,
  "mutualFriend": false
}
```

Paged list response:

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "total": 0
}
```

Page size is capped at 50.

## Validation

Follow/unfollow are idempotent.

Rejected:

- self-follow;
- relationship lookup against self;
- missing/non-ACTIVE target user;
- unauthenticated requests.

Current V1 uses direct follow for ACTIVE users only. `PRIVATE -> follow request` remains deferred because `follow_requests` is outside this task's approved schema.

## Mongo Event

After a successful PostgreSQL write commits, Spring emits best-effort interaction events:

```text
USER_FOLLOWED
USER_UNFOLLOWED
```

Fields:

```text
userId     = actor user
entityType = USER
entityId   = target user
source     = SOCIAL_RELATIONSHIP
metadata   = { mutualAfter: true|false }
```

If MongoDB is down, follow/unfollow still succeeds and only a warning is logged. PostgreSQL remains the authority.

## Future Consumers

Moment should reuse:

```text
SocialRelationshipService.isMutualFriend(viewer, owner)
SocialRelationshipService.listMutualFriends(user)
```

Message/Share can use following/followers/mutual-friends later, but Message pending/block state remains a separate domain.

## Deferred

- global/social block decision;
- follow request workflow for PRIVATE users;
- Moment backend;
- Message backend;
- Share targets backend;
- User Suggestions ranking and real UI source.
