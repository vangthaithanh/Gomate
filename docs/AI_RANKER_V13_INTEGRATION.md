# AI_RANKER_V13_INTEGRATION.md

Updated: 2026-10-10

## Scope

Integrate the GoMate Ranker research v13 artifact from `origin/buitrong` without merging the whole `buitrong` branch.

The whole branch was not merged because it is based on older code and would remove many current modules such as Moment, Message, Search, Semantic foundation and newer Flutter UI work.

## Files Added From `origin/buitrong`

```text
KPDL/train_ml_research_v13.py
KPDL/place_catalog_v11.csv
KPDL/training_output_research_final/gomate_ranker_research_v13.joblib
KPDL/training_output_research_final/training_report_research_v13.json
KPDL/training_output_research_final/research_model_comparison_v13.csv
KPDL/training_output_research_final/test_candidate_scores_research_v13.csv
docs/BACKEND_HANDOFF_GOMATE_V13.md
```

## Runtime Change

Updated:

```text
KPDL/api_service.py
```

Public API remains:

```text
GET  /health
POST /recommend
```

The runtime now loads:

```text
model_version = gomate-ranker-research-v13
selected_strategy = semantic_v1_with_legacy_fallback
selected_research_formula = uncertaintyHybrid
semantic_data_version = semantic-v1
```

Spring does not need a new endpoint because `/recommend` keeps the same response shape.

## Scoring Flow

```text
Spring request
  destination_key
  selected_interest_codes
  context_codes
  top_k
        ↓
semantic-v1 deterministic survey scorer
        ↓
v13 feature frame from ml_training_dataset_v12_semantic_v1.csv
        ↓
v13 RandomForest selected strategy
        ↓
uncertaintyHybrid final score
        ↓
top_k external_id result
        ↓
Spring maps external_id to PostgreSQL Place and reranks Screen 3 context
```

Important boundary:

- `candidate_external_id` stays the AI/backend stable catalog identity.
- Screen 3 context codes such as `GAN_TOI` stay Spring/backend reranking inputs.
- Distance, route time, reviews and live hot signals are not inside v13 training and are not added in AI runtime.

## Runtime Adapter Note

The v13 model bundle expects historical tour/place feature columns. At runtime, the adapter builds the feature frame from the frozen `ml_training_dataset_v12_semantic_v1.csv` candidate defaults and joins it with the live semantic-v1 survey scorer output.

This is intentionally safer than only renaming the v12 model path, but it is still a demo/runtime adapter rather than retraining v13 with live user survey rows.

## Validation Run

Executed:

```text
docker compose build ai
docker compose run --rm ai python -c "... health() and recommend(...) ..."
```

Result:

```text
health.model_loaded = true
health.model_version = gomate-ranker-research-v13
health.selected_strategy = semantic_v1_with_legacy_fallback
health.selected_research_formula = uncertaintyHybrid

sample request:
destination_key = da_lat
selected_interest_codes = [THIEN_NHIEN]
context_codes = [GAN_TOI]
top_k = 5

total_candidates = 41
items returned = 5
```

Sample top external IDs:

```text
da_lat:nac_thang_thien_duong
da_lat:royal_garden
da_lat:thien_vien_truc_lam
da_lat:langbiang
da_lat:chua_linh_phuoc
```

## Docker

No compose topology change was needed. Existing service remains:

```text
ai:
  build: ./KPDL
  ports:
    - "${AI_PORT:-8000}:8000"
```

`docker compose build ai` now packages the v13 model artifact.

## Rollback

Rollback options:

1. Restore `KPDL/api_service.py` to the previous semantic-v1 implementation.
2. Keep the v13 artifact files in place but do not load `V13_MODEL_PATH`.
3. Rebuild only the AI image:

```text
docker compose build ai
docker compose up -d ai
```

Spring fallback remains available if AI is unavailable.

## Remaining Risk

- Full Spring end-to-end recommendation regression was not completed in this audit step.
- The adapter does not invent Screen 3 logic in AI; Spring remains responsible for contextual reranking.
- If future v13 training adds live survey-conditioned features, the runtime adapter should be replaced with the official feature builder.
