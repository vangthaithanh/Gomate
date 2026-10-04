# AI Backend Integration

Updated: 2026-10-02

## Scope

This note records the current cold-start Home recommendation wiring after pulling the AI service code from `origin/master`.

The runtime flow is:

```text
Flutter Home
-> GET /api/v1/recommendations/home
-> Spring Boot recommendation module
-> POST AI FastAPI /recommend
-> AI returns external_id ranked candidates
-> Spring resolves external_id to ACTIVE PostgreSQL places
-> Flutter renders _PlaceSuggestionSection cards
```

Flutter never calls the AI service directly.

## Docker

Root `docker-compose.yml` now has three services:

```text
postgres
api
ai
```

Inside Docker, Spring calls AI by service name:

```text
AI_SERVICE_BASE_URL=http://ai:8000
```

For local non-Docker backend runs, use:

```text
AI_SERVICE_BASE_URL=http://localhost:8000
```

`KPDL/requirements.txt` pins `scikit-learn==1.8.0` because the bundled model artifact was trained with that version. Do not loosen this dependency unless the model is retrained or validated again.

## Environment

Relevant variables:

```text
AI_PORT=8000
AI_SERVICE_BASE_URL=http://ai:8000
AI_RECOMMENDATION_CANDIDATE_K=50
AI_RECOMMENDATION_HOME_LIMIT=10
AI_RECOMMENDATION_TIMEOUT_MS=2500
RECOMMENDATION_SEMANTIC_WEIGHT=0.75
RECOMMENDATION_CONTEXT_WEIGHT=0.25
RECOMMENDATION_DISTANCE_SCALE_KM=20
```

`AI_RECOMMENDATION_URL` remains supported by Spring config as an older alias, but new setup should use `AI_SERVICE_BASE_URL`.

Home recommendation no longer uses an implicit default destination. `destinationKey` is optional and only filters candidates when the client explicitly sends it.

## API Contract

Backend Home endpoint:

```text
GET /api/v1/recommendations/home?topK=10
```

Destination-filtered endpoint:

```text
GET /api/v1/recommendations/home?destinationKey=da_lat&topK=10
```

Compatibility endpoint:

```text
GET /api/v1/recommendations/me
```

AI request from Spring to FastAPI:

```json
{
  "destination_key": null,
  "selected_interest_codes": ["THIEN_NHIEN", "CHECKIN_HOT"],
  "context_codes": ["GAN_TOI", "DANG_HOT"],
  "top_k": 50,
  "include_runtime_ineligible": false
}
```

AI response is joined by:

```text
items[].external_id -> places.external_id -> places.id
```

Spring filters to ACTIVE places and does not expose unmapped AI-only places to Flutter.

## Interest Boundary

Screen 1 and Screen 2 semantic choices come from `user_interests`.

Screen 3 context choices remain in `user_settings.interest_codes` and are forwarded to AI as `context_codes`; AI returns them for transparency while Spring keeps runtime reranking responsibility.

Spring contextual reranking currently implements:

```text
finalScore = 0.75 * semanticScore + 0.25 * contextScore
distanceScore = 1 / (1 + distanceKm / 20)
```

`GAN_TOI` uses Flutter GPS when available and Haversine distance inside Spring. It boosts closer matching Places but never filters far matching Places out of the candidate list. If GPS is unavailable, Home returns HTTP 200 and keeps semantic ranking.

`CO_REVIEW` uses `avg_rating` and `review_count` from PostgreSQL.

`DANG_HOT` uses a popularity-v1 signal from `save_count`, `review_count`, and `avg_rating`. It is not a real time-window trend yet.

`DI_TRONG_NGAY` reuses the distance feasibility signal when GPS is available. It does not call Mapbox Directions for Home candidates.

`LOCAL` and `UU_TIEN_KHAC` are accepted context codes but do not affect ranking yet because there is no reliable runtime signal in PostgreSQL.

If the user has no semantic interests, or if AI is unavailable, Spring returns PostgreSQL fallback places instead of crashing Home.

## Flutter

`lib/features/home/screens/home_screen.dart` uses `_PlaceSuggestionSection` with `RecommendationRepository`.

The section has:

```text
loading
error + retry
empty
network image fallback
tap -> PlaceDetailScreen with real placeId
```

It does not use the old hard-coded place asset list anymore.

## Important Notes

- Flyway schema is unchanged by this integration.
- Auth, Place, Trip, Route and semantic data migrations are not refactored here.
- AI training data still uses stable `external_id`; Flutter receives runtime `places.id`.
- Candidate pool defaults to 50 and Home card limit defaults to 10.
