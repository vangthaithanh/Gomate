# Recommended Home + durable viewed-post history

Current implementation (2026-10-30) extends Home without changing the Post,
privacy, follow, friendship or Global Block contracts.

## Feed contract

- Flutter Home reads `GET /api/v1/feed/recommended` and preserves server order.
- A new request without a cursor creates a server snapshot. Friend posts are
  first (mutual active follow), followed-author posts are second, and all other
  eligible posts keep the existing 80% Place / 10% hashtag / 10% interaction
  ranking. Pagination reads the same snapshot and rechecks current access.
- Refresh or re-entering Home starts a new snapshot and reads current
  relationships. Profile and other Post lists do not use Home view history.
- This is Spring ranking that consumes the existing Place recommendation
  scores. It is not a separately trained Post model and does not change AI v15.

## What counts as viewed

Only a card rendered by Home may call
`PUT /api/v1/feed/recommended/{postId}/view`. Flutter starts the two-second
timer while the application/Home route is active and at least 50% of the
viewable vertical region is in the scroll viewport. The denominator is
`min(post height, viewport height)`, so a card taller than the viewport must
occupy at least half of the viewport continuously. API prefetch, off-screen
cards, Profile, and visibility shorter than two seconds do not count.

The endpoint derives the viewer from JWT, authorizes the Post before writing,
and writes `post_home_views(viewer_user_id, post_id, viewed_at)`. The composite
primary key makes duplicate delivery idempotent. Flutter acknowledges only a
successful response; after a failure it waits for a new qualifying viewport
exposure before retrying, avoiding a request loop.

## Filtering scope and snapshot behavior

Every valid Home view may be stored because a remainder author can later become
followed. During new snapshot construction, a stored view filters the Post only
when the viewer currently follows its author; mutual follow (friendship) is a
subset of this condition. Therefore:

- currently friend/followed + viewed: hidden from the new Home snapshot;
- currently not followed + viewed: remains eligible for the scored remainder;
- followed then unfollowed: can reappear in the scored remainder;
- remainder then followed: the existing view starts filtering it;
- another viewer is unaffected;
- the current snapshot never removes a card immediately after view ACK.

If refresh races an in-flight view request, only a view committed before the
snapshot candidate query is filtered. A later successful ACK applies on the
next refresh. A failed/unconfirmed request creates no server history.

## Schema

`V28__post_home_views.sql` adds one table and does not modify V1-V27. Both
foreign keys cascade only if the owning user/Post row is physically removed;
normal Post deletion remains the existing tombstone flow.
