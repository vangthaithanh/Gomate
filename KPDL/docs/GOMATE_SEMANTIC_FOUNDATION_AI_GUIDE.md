# Semantic Foundation V4

## Scope

This step adds the first shared semantic foundation between Survey/User Interest and Place.

Included:

- canonical interest groups/options,
- normalized `user_interests`,
- canonical place tag taxonomy,
- interest-to-tag mapping,
- place-to-tag links from conservative category rules,
- read-only semantic API,
- AI handoff package `semantic-v1`.

Not included:

- full AI model training,
- final recommendation formula,
- AI FastAPI integration,
- interaction event pipeline,
- Home recommendation UI,
- Map/Route/Trip refactor.

## Migration

Migration file:

```text
backend/src/main/resources/db/migration/V4__semantic_interest_place_foundation.sql
```

V1, V2, and V3 are unchanged.

New tables:

```text
interest_groups
interest_options
user_interests
place_tags
place_tag_links
interest_tag_mappings
```

The migration also seeds semantic taxonomy and category-rule mappings idempotently.

## Survey Boundary

Screen 1 and Screen 2 options are semantic profile inputs and are persisted to `user_interests`.

Screen 3 options are context strategy. They are still preserved in `user_settings.interest_codes` for existing app compatibility, but they are not written to long-term `user_interests`.

## API

Read-only endpoints:

```text
GET /api/v1/semantic/interests
GET /api/v1/semantic/place-tags
GET /api/v1/semantic/interest-tag-mappings
GET /api/v1/semantic/places/{placeId}/tags
GET /api/v1/users/me/interests
```

The current API style remains direct JSON responses, matching the existing backend modules.

## Place Tag Rules

Semantic v1 only uses category-derived tags:

```text
lake     -> lake, nature, scenic
heritage -> heritage, cultural, historical
market   -> market, local
food     -> food, local_food
landmark -> landmark, photo_spot, iconic
nature   -> nature, scenic
```

Subjective tags such as `social`, `quiet`, `trendy`, `group_friendly`, and `cafe_meeting` are not assigned to Places unless later backed by verified source or manual review.

## AI Handoff

Generated package:

```text
backend/src/main/resources/data/ai_handoff/semantic_v1/
```

Regenerate with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate_semantic_v1.ps1
```

See:

```text
docs/AI_SEMANTIC_DATA_HANDOFF_V1.md
```

## Important Notes

- Backend runtime Place ID remains `places.id`.
- AI/training stable Place ID remains `external_id`.
- Semantic v1 is a baseline expert prior, not a trained/evaluated final model.
- No negative weights are used in semantic v1.
