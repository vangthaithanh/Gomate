# Place Rating & Review V27 — AI handoff, 2026-10-30

## What is delivered

This is an additive source patch against clean baseline **84ac0372c4618a04088be441473bac355145b546**. It is a local handoff package, **not a new published master commit**. Preserve teammate AI changes; apply only after patch/conflict review. Do not merge old credential-bearing history or copy entire reference source folders over a modified checkout.

Backend V27 adds only `reviews`; existing `places.avg_rating` and `places.review_count` now hold real GoMate aggregate values. Place list/basic Search add these two fields; detail, paged Search and Place recommendations keep reading the same cache. Schema, API, locking, author permissions and Global Block details: [foundation report](../PLACE_RATING_REVIEW_FOUNDATION.md).

No Place AI model, Post AI, recommender feature pipeline, review event logging, seed, media upload or Web Admin is implemented by this package. Existing Post/DM/Trip/Map/GPS/media/notifications retain their accepted behavior.

## Identity and signal semantics

| Field | Meaning |
|---|---|
| `external_source` + `external_id` | Canonical external identity, currently tour_places_v11; use stable external_id for AI/catalog linkage |
| `destination_key`, `canonical_name` | Master catalog fields; both canonical CSVs have the same 188 unique external_id values |
| `place_id` / backend `places.id` | BIGINT business identity in the exporting database; do not use as a portable training key |
| `avg_rating` | GoMate ACTIVE/VISIBLE mean, cached NUMERIC(3,2), zero when review_count=0 |
| `review_count` | Number of ACTIVE/VISIBLE reviews, not total stars and not imported/source review count |
| `rating_has_evidence` | Export-derived flag review_count>0; not a database column |

**Zero reviews is missing evidence, not a five-star vote.** Owner requires UI display-five with “Chưa có đánh giá”; database/API/export remain **0/0**. Never train on the UI default or substitute AI ranking score as rating. When reviews exist, use the real average and its evidence count. Keep any future external/source ratings separate, with provenance and approval, rather than silently merging them.

One active review per actor/Place; edits retain identity/count; deletion is soft and DELETED/HIDDEN rows do not contribute. No check-in/Pin requirement. A future moderation action must lock the same Place and recompute the existing aggregate transactionally. No direct AI writes to business data.

## Included data versus private data

The package's `data/place_rating_snapshot.csv` exports **146 ACTIVE Places** with public identifiers, catalog mapping, category, address, coordinates and GoMate aggregate/evidence fields only. Both 188-row canonical CSVs are included as existing public catalog metadata. A Flyway history/checksum manifest records V1–V27 without credentials.

At acceptance closure there are **0 ACTIVE reviews**. The two reviews used for the real-device test were deleted through the owner UI; history is retained locally. This snapshot therefore contains **no real active review training labels**. Do not fabricate labels, treat 146 empty Places as five-star examples, or include deleted test reviews in training.

No review text, actor identifiers, user/account/profile/session data, messages, GPS snapshots, private Post media, credentials, raw database dump, `lib/main.dart`, Firebase JSON or binary media is included. Existing private run configurations are supplied separately by the owner. Author information returned for the app review UI is not permission to export it for training.

## Recipient workflow

1. Read the package root `README_AI_HANDOFF.md` and manifest. Work from the correct GoMate root and preserve local AI work.
2. Use `git apply --check` on the patch. On conflicts, stop and review the relevant hunks; reference source files are for comparison, not blanket overwrite. Do not reset/drop local work or bypass a failing check.
3. Build API with all tests, then recreate only the API. Flyway automatically upgrades the existing V26 database to V27; old V26 data backups are still compatible. No new seed or restoration is required on an existing database.
4. Verify health UP, V1–V27 valid, existing Place/media counts retained, zero/real review aggregates as appropriate. New empty review data is normal. Use the new Flutter APK/source if exercising review UI.
5. Further AI feature/export/training or Post recommendation changes need a separate approved task. AI may read this contract; it does not gain authority to change permissions or scrape private data.

## Acceptance and limits

Backend Docker: 283 discovered / 279 executed PASS / 4 opt-in skips, plus clean/restored PostgreSQL migration probes separately PASS. Flutter full suite: 327 PASS; analyze 0 errors/14 pre-existing warnings (lint infos remain). See the foundation report for exact checkpoints and the follow-up UI-only check/build.

Native confirmed with Thanh and Xuân Thu: 5/1 → 4/2 → edit 3.5/2 → delete 3/1 → empty; own content is separate, review ids/count survive edits/re-entry, soft deletion preserves history. Owner then requested visual alignment of the delete confirmation and packaging. The new confirmation reuses the GoMate sheet/buttons; its visual update is covered by automated checks/build, **not a further native confirmation**.

Still not manually confirmed in this phase: offline error behavior, Map/Search/Home cross-screen star/media behavior, native review-list Global Block permutations and two physical devices concurrently. Automated coverage is recorded separately; none of these are labeled native PASS. Owner instructed packaging at this point with these limits preserved.
