# AI Handoff Semantic V1 FINAL

This folder is the frozen `semantic-v1` training handoff package for GoMate.

## Identity

- Stable AI Place key: `external_id`
- Runtime backend Place key: `places.id`
- Catalog version: `tour_places_v11`
- Semantic release: `semantic-v1 FINAL`

## Counts

- Canonical places: 188
- Runtime eligible: 146
- Runtime ineligible: 42
- READY: 114
- PARTIAL: 65
- NEED_REVIEW: 9
- Place-tag links: 831

## Use

Use `semantic_v1/ai_place_semantic_matrix_v1.csv` for wide content features, or `semantic_v1/ai_place_tags_v1.csv` for explainable long-form features.

Do not train on `places.id` as a stable cross-machine key. Join model output back to backend runtime data through `external_id`.

QA helpers:

- `semantic_v1/semantic_interest_coverage_v1.csv`
- `semantic_v1/semantic_category_coverage_v1.csv`
- `semantic_v1/semantic_sanity_scenarios_v1.csv`

Missing `0.0` values on `PARTIAL` places mean unknown or insufficient evidence, not a confirmed negative signal.
