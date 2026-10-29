# AI Semantic Data Handoff V1

`semantic-v1` is the **FINAL TRAINING RELEASE** for the current GoMate canonical Place catalog.

## Location

Main generated package:

```text
AI_HANDOFF_SEMANTIC_V1_FINAL/
```

Runtime resource copy:

```text
backend/src/main/resources/data/ai_handoff/semantic_v1/
```

## Files

```text
ai_interest_taxonomy_v1.csv
ai_place_tag_taxonomy_v1.csv
ai_interest_tag_mapping_v1.csv
ai_place_tags_v1.csv
ai_place_semantic_matrix_v1.csv
ai_context_strategy_v1.csv
semantic_v1_manifest.json
semantic_v1_qa_summary.json
semantic_v1_sanity_scores.csv
semantic_interest_coverage_v1.csv
semantic_category_coverage_v1.csv
semantic_sanity_scenarios_v1.csv
```

## Stable Keys

- AI/training stable Place key: `external_id`
- Backend runtime Place key: `places.id`
- Catalog source: `tour_places_v11`
- Semantic data version: `semantic-v1`
- Release status: `FINAL`

Do not train on `places.id` as a stable cross-machine identity. It is a runtime database identity and can differ between machines.

## File Purpose

`ai_interest_taxonomy_v1.csv`
Lists survey option codes and classifies them as `SEMANTIC` or `CONTEXT`.

`ai_place_tag_taxonomy_v1.csv`
Canonical tag dictionary. Do not fork, rename, or create local synonyms for tag codes.

`ai_interest_tag_mapping_v1.csv`
Maps semantic interests to place tags. Only Screen 1 and Screen 2 semantic choices are included.

`ai_place_tags_v1.csv`
Long-form Place tag dataset. Each row includes:

```text
external_id
canonical_name
destination_key
category
tag_code
weight
source_type
source_ref
reason
semantic_status
runtime_eligible
semantic_data_version
```

`ai_place_semantic_matrix_v1.csv`
Wide matrix with one row per canonical Place and one numeric column per tag. Missing tags are `0.0`.

`ai_context_strategy_v1.csv`
Defines Screen 3 as contextual re-ranking strategy, not long-term user taste.

`semantic_v1_manifest.json`
Release counts and version metadata.

`semantic_v1_qa_summary.json`
Machine-readable QA result: status counts, runtime eligibility, validation errors, weight/source distribution, and tag coverage.

`semantic_v1_sanity_scores.csv`
Simple weighted-match sanity ranking samples for key interests. This is a QA helper, not the production model.

`semantic_interest_coverage_v1.csv`
Coverage report for the six main semantic interests used in final QA.

`semantic_category_coverage_v1.csv`
Coverage report by Place category, including READY/PARTIAL/NEED_REVIEW counts and average tags per Place.

`semantic_sanity_scenarios_v1.csv`
Thirty QA scenarios: five destinations multiplied by six main interests, top ten rows per scenario when matches exist.

## Weight Scale

Semantic v1 uses only:

```text
1.0 = CORE
0.8 = HIGH
0.6 = MEDIUM
0.3 = LOW
0.0 = no tag / no mapping
```

Do not introduce arbitrary values such as `0.73` without a new evaluated semantic version.

## Survey Boundary

Screen 1 and Screen 2 are semantic profile input:

```text
KET_BAN
NGHI_DUONG
CHECKIN_HOT
THIEN_NHIEN
VAN_HOA
AM_THUC
BIEN_NUI
TRUNG_TAM
DIA_DANH_NOI_TIENG
LANG_NGHE_DI_TICH
NGOAI_O_DONG_QUE
```

Screen 3 is contextual strategy:

```text
GAN_TOI
LOCAL
DANG_HOT
DI_TRONG_NGAY
CO_REVIEW
UU_TIEN_KHAC
```

Avoid double-counting. If an AI model includes distance/review/trend, the model response should expose score components. Otherwise Spring can apply Screen 3 context at runtime.

## Status Fields

`semantic_status`:

```text
READY
PARTIAL
NEED_REVIEW
```

`runtime_eligible`:

```text
true
false
```

`runtime_eligible=false` means the canonical Place remains useful for AI/catalog alignment but is not currently available as an ACTIVE PostgreSQL runtime Place.

Important: missing tags or `0.0` values on `PARTIAL` Places should be treated as unknown or insufficiently reviewed, not as strong negative evidence.

## Source And Reason

Each Place tag carries evidence:

```text
source_type
source_ref
reason
```

Current source types:

```text
CATEGORY_RULE
CATALOG_NAME_RULE
MANUAL_REVIEW
```

No external web source is encoded in this release.

## Join Rule

AI output should use:

```text
external_id
```

Spring resolves:

```text
external_id -> places.id
```

Flutter receives backend runtime IDs and API DTOs. The AI team should not maintain a separate Place catalog fork.

## Model Freedom

The AI teammate may choose content-based, association rules, hybrid scoring, offline evaluation, or other models. The requirement is to keep the semantic contract stable:

- use `external_id` as training key;
- use the provided tag taxonomy;
- respect `semantic_status`;
- respect `runtime_eligible` for runtime recommendations;
- report any contract change as a new semantic version.

## Regeneration

Regenerate the package with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate_semantic_v1.ps1
```

This also regenerates the AI handoff package folder and QA summary.
