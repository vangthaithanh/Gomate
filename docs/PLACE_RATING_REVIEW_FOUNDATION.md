# Place Rating & Review Foundation — V27

> Rule updated 2026-10-30: count=0 shows “Chưa có đánh giá”, not numeric 5.0/0.0. See PLACE_UNRATED_DISPLAY_TEAM_HANDOFF.md; default-five notes/results below are historical, superseded for new UI builds.

Status: implemented and deployed locally (work started 2026-10-29; validation continued 2026-10-30). **Core two-account native CRUD PASS; owner requested delete-confirmation UI alignment then packaging, with remaining native variants recorded below.** No automatic master publication or AI/model change.

## Decisions and audit

- Audited runtime before changes: Flyway V1–V26, 38 business tables; 146 Places, all `avg_rating=0` and `review_count=0`; no `reviews`, `review_media` or review endpoints. No imported ratings to migrate or overwrite. V2 cache columns already exist (`NUMERIC(3,2)`, integer count).
- Existing Place detail generated four fictional reviews; composer only mutated local state, including selected local image paths. Map list omitted rating fields and its adapter forced zero. Home Place suggestion used AI score as fallback stars. These paths are replaced with real reviews/ratings, not seeded data.
- **Historical owner decision, superseded by the 2026-10-30 hotfix:** zero real reviews displays **5.0 + “Chưa có đánh giá”**. This is presentation only. API/DB remain `avgRating=0, reviewCount=0`; no virtual five-star vote, prior, fake count or AI feature. After any review, display the actual average. Delete the last review restores the empty display.
- Raw average cache uses 2 decimals (existing column); UI formats 1 decimal. Count is the number of ACTIVE/VISIBLE reviews, never sum of stars. A 5 + 3 yields 4.0/2; editing 5→4 yields 3.5/2; deleting 3 yields 4.0/1.
- PUBLIC Place aggregate is global. Global Block hides authors/review rows in either direction; it does not delete reviews or create a different average per viewer. No notification or review interaction-event pipeline is introduced (none exists).
- Optional text keeps existing UI limit **1000 characters**. Review images were never uploaded/persisted: existing attachment affordance explains that review attachments are not supported in this phase. No fake successful image upload, new media table, or Cloudinary policy change.

## Data and permissions

`V27__place_reviews.java` adds **only `reviews`**: BIGSERIAL id, UUID user FK, BIGINT Place FK, integer 1–5 rating, optional content, ACTIVE/DELETED publication, VISIBLE/HIDDEN moderation, UTC timestamps. Unique partial index on `(user_id,place_id)` for ACTIVE; a generated-null equivalent is used only by H2 tests. Read index covers Place/publication/moderation/created/id. No V1–V26 edit.

JWT owns actor identity; extra userId is rejected by the existing strict JSON configuration. Only ACTIVE actors write to ACTIVE Places with active categories. No check-in, Trip, Pin, friendship or visit requirement. Another actor cannot edit/delete a review. Hidden moderation is preserved on edit/retry, never reset to VISIBLE. Owner can see their own hidden review. Public lists expose public display name/avatar/id only, filtered by account status and Global Block.

Mutation transaction locks actor then Place; every mutation of one Place serializes on its row, writes review and recomputes the existing cache atomically. DB uniqueness additionally prevents duplicate active rows. POST retries upsert the same active review; PATCH addresses that review; soft DELETE is idempotent and retains old rows. Re-create after delete receives a new review id. Concurrent edits are serialized with last committed edit winning, not accumulated as extra votes. Aggregate failure rolls back review and cache together.

Future moderation must use the same Place lock/recompute transaction when hiding/restoring reviews. **No moderation endpoint/Web Admin is authorized here.** Direct ad-hoc SQL edits are not the feature's write API.

## API (additive to existing Place contracts)

| Method / path | Behavior |
|---|---|
| POST `/api/v1/places/{placeId}/reviews` | Authenticated create or update own active review; `{rating:1..5,content?:string}` |
| PATCH `/api/v1/reviews/{id}` | Owner edits existing active review |
| DELETE `/api/v1/reviews/{id}` | Owner soft-delete; repeat is safe |
| GET `/api/v1/places/{placeId}/reviews/me` | Authenticated aggregate + own review (or null) |
| GET `/api/v1/places/{placeId}/reviews?size=20&beforeId=...&sort=newest` | Authenticated public rows, current Block filtering; sort also highest/lowest; bounded size 1–50, nextBeforeId cursor |

Mutation/me response: `{placeId, avgRating, reviewCount, myReview}`. Own review includes `{id,placeId,rating,content,publicationStatus,moderationStatus,createdAt,updatedAt}`. Public page includes `{placeId,avgRating,reviewCount,items,nextBeforeId}`; author rows add `{userId,displayName,avatarUrl}`. No email/private account metadata.

Existing Place detail and paged Search/recommendation already read the shared `places` cache; normal list/basic search now add `avgRating`/`reviewCount` too. No business IDs, coordinates, media URLs or request paths are replaced. Anonymous public Place reading is preserved; review/me reads require login before the broader public Place security matcher. Invalid rating/content/malformed body →400; anonymous/invalidated LOCKED session→401; inactive actor service/other owner→403; missing/hidden Place or deleted edit→404. No frontend success before ACK.

## Flutter and performance

- Existing detail/cards/list/composer are reused. Load own review on entry/account change; preserved stars/content rehydrate from API; edit and delete are real. Loading/error/retry states are explicit.
- Public aggregate ACKs update only local rating badges/text through `PlaceRatingBuilder`, including Home Place recommendation and Search/Map cards. No Feed reload, media eviction, Map marker rebuild, GPS/Trip/route change or network polling is added for rating mutations.
- Detail re-entry reads fresh data. Changing account clears own/review state; Global Block changes invalidate author rows. Reviews are bounded/paged; existing highest/lowest UI uses server order rather than claiming a global sort from one local page.
- Home AI score is no longer shown as review stars. Related-place demo star cards were removed from the active detail rail; no new recommendation algorithm is substituted. Existing unrelated Place favorite/share/related-Post preview limitations remain outside scope.
- `lib/main.dart` remains private/unchanged. No package/dependency or `.env` change.

## AI handoff boundary (package AFTER native acceptance)

Stable model/catalog key: `external_id`; backend Place business key: `places.id`. Join using existing canonical mapping, never rename IDs or manufacture review authors/votes. Real GoMate signals: `avg_rating`, `review_count`, and (only in an approved private dataset/export) real review `id/place_id/rating/status/timestamps`. Public author IDs in a UI response are **not** approval to export PII or personal interactions for training.

Zero-count display-five must never be fed into training as a real five-star rating. Keep external/source rating and GoMate rating separate if external ratings are introduced later. Review event logging, Post AI, retraining, seeding and Web Admin remain deferred.

After owner confirms native PASS, prepare a reviewed source/contract delta plus migration/runbook and an explicitly agreed data snapshot if needed. Current existing V26 backups require V27 auto-upgrade on the teammate's machine; do not rewrite V26 history, reset their volume or commit private configs/main. No package is labeled accepted or pushed before that step.

## Verification / native checklist

Automated evidence directory (ignored/private): `backups/place-review-20261029/`. Report final counts/results here after checks finish; failed intermediate assertions or environment issues are not successful tests.

Automated verification:

- Full Docker `clean verify -Dtest=*`: **283 tests, 0 failures, 0 errors, 4 opt-in skips (279 executed PASS)** across 40 suites. PlaceReviewApiTest: **7 PASS**, including rollback, concurrency, sort/cursor and DB uniqueness. Test XMLs copied from the *cached exact build stage* because BuildKit clipped Maven stdout at 2 MiB; the copy did not rerun/skip tests. Temporary extraction container removed.
- Skipped in the general run: DirectMessageMongoTest, PostShareMongoTest, GlobalBlockPostgresMigrationTest, PlaceReviewPostgresMigrationTest. The **new review PostgreSQL probe was explicitly run separately twice and PASS**, for clean and restored V26. Do not relabel the three unrelated opt-in probes as executed here.
- Host full Maven earlier source checkpoint: **281 tests, 0 failures/errors, 4 skips** (before adding the two final rollback/sort tests). Final 283-test Docker run above is authoritative for backend source.
- Full Flutter tests: **327 PASS**, including 4 new default-five/badge isolation/stale read/form-lifecycle cases. After final adapter fixes, a second full run again passed **327**.
- Analyze checkpoint: **0 errors / 14 existing warnings** (lint infos also remain; command exits nonzero for existing issues, not a clean-lint claim). Final confirmation/build hashes are recorded with the local acceptance handoff.
- Final-source analyze confirms **0 errors / 14 existing warnings / 366 lint infos**. Final APK debug build PASS; SHA-256 `5752a9bee41cf7bfbb55922c053768701ba7ea678188e119fe73d1ec1c183382`, 287,427,972 bytes. Owner chose to install it manually. `lib/main.dart` byte hash matches the prior private release hash. No Git commit/push was made.
- Local API uses tested image `sha256:97fb2885e0ca80190a6240edcdbe7160377e2250b2ba570c2e3b60bb17d25604`, health UP, V1–V27 all successful. Initial cutover verified **39→40 total tables**, no old business-table count change; subsequent idempotent startup verification remained 40/40. 146 Places, 7 Place media and **0 reviews** before native tests. No fake review or notification was generated by the feature rollout.
- Backup taken before cutover; no volume reset/Flyway repair or rewrite of V1–V26. Source audit against clean published `84ac037` confirms all previous migration files unchanged and unrelated backend/UI implementations retained. API remains port 8081. Native bridge RF8N32408EN currently maps 8081→8081.

Intermediate fixes caught by checks: strict JSON rejects client-supplied userId (test updated to assert rejection); normalize review UTC timestamps on H2/PostgreSQL; preserve existing Place detail timestamp contract while accepting H2 OffsetDateTime; correct the supported existing delete icon; widget tests exercise real hit targets below the floating header. A narrow Flexible constraint prevents the existing related-Post heading row overflowing at mobile widths; no visual redesign. The offline host `clean` plugin was initially missing, so host full verification downloaded that plugin and reran successfully; no test bypass.

Migration probes: clean PostgreSQL and restored V26 PostgreSQL **PASS**; V1–V27 valid/re-run no-op, only one added table (39 business / 40 including history), every old table's row count and V1–V26 checksums preserved. Probe fixtures roll back and the temporary PostgreSQL container is removed. Pre-cutover backup is `pre-v27.dump`; it is private, not an AI publication artifact.

Native acceptance evidence (core PASS; remaining variants explicitly unconfirmed):

Guided evidence — 2026-10-30: owner confirmed Thanh submitted 5 stars with text on Hồ Xuân Hương and re-entry preserved both with 1 review. Read-only PostgreSQL verification agrees: Place id 3 has avg_rating=5.00/review_count=1; exactly one review, ACTIVE/VISIBLE, rating 5, non-empty content. **Create + re-entry PASS for Thanh only**; two-account average/edit/delete and the remaining native checklist are still pending. No API mutation was used to create this review.

Next guided result — owner confirmed Xuân Thu's form did not inherit Thanh's text; submitting 3 stars and re-entry showed 4.0/2. PostgreSQL agrees: two distinct ACTIVE/VISIBLE reviews (ids 1 and 2, stars 5 and 3), both with text; cached average=4.00/count=2. **Account separation + two-account average + re-entry PASS**. Edit/delete and remaining native variants are still pending; no server-side review mutation was performed by the agent.

Edit guided result — owner confirmed Thanh edited 5→4 and re-entry retained 4 stars with overall 3.5/2. PostgreSQL confirms the SAME review id 1 now has rating 4, review id 2 remains 3, both ACTIVE/VISIBLE; average=3.50/count=2, no new row. **Owner edit + preserved identity/count + recompute PASS**. Next deletion test starts with Thanh (currently logged in): deleting Thanh's 4 must leave Thu's 3 at 3.0/1; deleting Thu's remaining review must restore empty 0/0 storage and default-five UI. This changes only test order, not business behavior.

First-delete guided result — owner confirmed Thanh's review disappeared while Xuân Thu's 3-star review remained, with 3.0/1 after re-entry. PostgreSQL agrees: review id 1 is DELETED (retained history), id 2 remains ACTIVE/VISIBLE with rating 3; average=3.00/count=1. **Own soft-delete + preservation of the other user's review + aggregate recompute PASS**. Last-review deletion and remaining native variants are pending.

Last-delete guided result — owner confirmed Xuân Thu deleted the last review; after re-entry, no public review remained and UI showed default 5 stars + “Chưa có đánh giá”. PostgreSQL confirms Place id 3 at **0.00/0**, both test reviews DELETED, and **0 ACTIVE reviews globally**. **Last-delete + empty default-five presentation PASS**. No synthetic five-star review is stored; deleted test rows remain history and are excluded from aggregates/training eligibility. Core native two-account create/read/edit/delete is now PASS. Cross-screen rating/media behavior and offline-error native variants remain unconfirmed (automated checks already PASS); AI package is still pending acceptance closure.

1. Thanh opens a no-review Place: 5.0 and “Chưa có đánh giá”; submit 5, re-enter: one real review, same stars/content.
2. Xuân Thu same Place submits 3: 4.0/2. Reopen Thanh, edit 5→4: 3.5/2, no additional review.
3. Delete Thu's 3: 4.0/1. Delete Thanh's 4: 0 real reviews and default-five empty display.
4. Network failure keeps form/draft with error, never fake success; retry does not double count. Changing account never inherits another user's composer state.
5. Map/basic Search/paged Search/Home Place stars agree after entry/ACK; no unrelated media/marker reload. Place images, existing Trip/Pin/GPS and Post/DM are preserved.
6. Review list respects two-way Global Block; no author information appears for a blocked pair. No new review FCM/Inbox notification.

Guided first Place: **Hồ Xuân Hương, GoMate Place id 3**, verified before native tests as 0.00/0 and no review rows anywhere. Hồ Tuyền Lâm id 8 is another empty option. Do not insert test reviews on behalf of real users via API; the owner uses the actual UI.

## Files in this feature delta

Packaging decision — 2026-10-30: owner instructed replacing the purple/default delete dialog with the existing GoMate visual form, then creating the AI handoff. Only the review confirmation changes: `GoMateBottomSheet` + existing `MessageConfirmContent` (black title, gray description, blue gradient confirm) + explicitly styled gray Close. Shared components and backend logic/schema are unchanged; Close still does not delete and confirmation still calls the same owner API. The new visual adjustment has automated/build verification, not new native acceptance. Offline/cross-screen/native Block variants remain unconfirmed. AI handoff contract: `AI_HANDOFF/08_PLACE_RATING_REVIEW_V27.md`; no private DB/account export or master push.

Follow-up UI verification: **4 review Flutter tests PASS**, including the full form lifecycle, shared confirmation component/colors, Close preserving the review, then confirmed deletion. Debug APK rebuild PASS, SHA-256 **2495a9621eac92155f79a74744fd9f45f9ac263f34025ee4e60ffeccfd8935a0**, 287,428,207 bytes (supersedes the earlier APK hash above). Backend bytes remain those of the 283-test image; no repeated backend build/migration was needed for this UI-only adjustment.

- Backend new: `src/main/java/db/migration/V27__place_reviews.java`, `src/main/java/vn/gomate/place/review/{PlaceReviewRepository,PlaceReviewService,PlaceReviewController}.java`.
- Backend adapted: `auth/SecurityConfig.java` (only review GET authentication matcher), `place/dto/PlaceDtos.java`, `place/repository/PlaceRepository.java`, `place/service/PlaceService.java`.
- Tests: new `PlaceReviewApiTest.java`, `PlaceReviewPostgresMigrationTest.java`; exact table assertion in `PlaceApiTest.java` includes `reviews`.
- Flutter new: `lib/features/place/data/place_review_repository.dart`, `lib/features/place/widgets/place_rating_builder.dart`, `test/place_reviews_test.dart`.
- Flutter adapted: Place API/models; Map `place_detail_screen.dart`, summary data source and bottom sheet rating; Home Place badge; Search Place repository/badge; recommendation repository *display aggregate synchronization only* (no ranking or backend AI change).
- Knowledge: this file, root `AGENTS.md`, `CODEX_INDEX.md`, `PROJECT_CONTRACT.md`, `DATABASE_CONTRACT.md`. Temporary evidence/scripts/backups remain ignored and are not release or AI-package contents.

Rollback: stop new API if startup validation fails; investigate migration transaction and restore the private pre-V27 backup only into an isolated recovery DB first. Do not use Flyway repair/clean, drop the business schema, delete volumes, or roll back V1–V26. Once real reviews exist, retain them and use a reviewed forward migration/fix.
