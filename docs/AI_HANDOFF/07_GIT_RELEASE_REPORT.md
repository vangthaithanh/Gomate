# Git release preparation — 2026-10-29

## PRE-PUSH: owner-approved private entrypoint exception

**PRIVATE FILE REQUIRED:** `lib/main.dart` is intentionally absent from the release Git tree. The owner supplies it through an approved private channel at exactly that path before Flutter build/run. A Git-only clone **cannot compile or run Flutter** without it. No fake entrypoint or startup refactor is included. This is the only additional source exclusion approved by `CODEX_TASK_GOMATE_RELEASE_MASTER_EXCLUDE_PRIVATE_MAIN_20261029.md`.

This committed report describes preparation, not a push that has not happened yet. The final verified SHA/result is recorded in the publication response and a local result note after the actual push. Do not rewrite master again just to insert its own SHA here.

| Item | Prepared value |
|---|---|
| Remote / target | `origin`, `github.com/vangthaithanh/Gomate.git`, only `refs/heads/master` |
| Current source checkout | `codex/ui-f11c6f7-invitation-sync` |
| Original local HEAD | `738d548c45fd07756e41a84d488e5609f5b14b45`; current accepted source includes working changes |
| Remote SHA re-read for this release | `738d548c45fd07756e41a84d488e5609f5b14b45` |
| Existing local safety ref retained | `refs/safety/master-before-publish-20261029` at the previous SHA |
| New release branch | `codex/publish-private-main-excluded-20261029` |
| New history | One parentless snapshot; no old or rejected commit inherited |
| Push method | Exact `--force-with-lease=refs/heads/master:738d548c45fd07756e41a84d488e5609f5b14b45`; abort if remote changes/auth/protection rejects |

Source local is authoritative. No pull/merge/rebase/cherry-pick/reset/clean or feature rewrite is part of the publication. The original checkout, index, branches, private backups and source files are preserved. Only a separate release index/tree excludes the private entrypoint. No other branch/tag is pushed.

## Earlier security stop and resolution

The first gate found actual DB/JWT secrets in historical env templates. **Previously completed with owner approval:** private DB/config backup; DB password/JWT rotation; API recreate; separate-container authentication proved old password rejected and new accepted; business counts unchanged and refresh sessions untouched. This new publication step does not rotate again, restart Docker or write PostgreSQL/MongoDB.

The earlier root commit `70de06cc9408ff23e90f1b40ef4abb39839763a6` was rejected by GitHub GH013 because `lib/main.dart` contained a Mapbox token. It stays local and is not an ancestor of this release. The owner chose exclusion/private handoff rather than `--dart-define`. No token value, encoded substitute, allow-secret link or protection bypass is used.

Removing a file from the Git tree does not secure the embedded token. **Recommend a separate least-privilege Mapbox AI/dev token and private owner review of existing token rotation/restrictions.** No token/runtime change is authorized here. Never re-add/forward the private file to Git, issues, CI logs or chat. On receiving checkouts verify:

```powershell
git check-ignore lib/main.dart
git status --short
git ls-files lib/main.dart
```

The last command must return no file. `/lib/main.dart` is in the committed ignore policy; the verifier rejects it if force-added. Hash comparisons proving the local file is unchanged are kept private, not printed publicly.

Old credential-bearing branches/tags/clones/hosting caches are **not cleaned by this release**. Owner/team coordination remains necessary; never push private safety/old/rejected refs or merge them back into the new baseline.

## Included and excluded

Included: reviewed Flutter feature source except the one entrypoint, complete Spring source/tests, unchanged V1–V26 SQL/Java migrations, Compose, KPDL Place AI/data/model artifacts, and [handoff 00–06](00_START_HERE.md). The v12 semantic (~31.5 MB) and v13 research (~25.4 MB) models remain under the remote single-file size limit. No runtime model is dropped.

Excluded, preserved on disk:

- **`lib/main.dart`**, the sole new private source exception.
- Existing actual `.env`/Firebase configs/service accounts/signing credentials, backups, build outputs, caches, logs and private exports.
- `gomate.dump`, `AI_HANDOFF_SEMANTIC_V1_FINAL.rar`, `backend/src/main/resources/data/ai_handoff/semantic_v1.rar`, `docs/tonghop.zip`; relevant expanded documentation/static data remains included.

The two exact `backend/src/test/resources/firebase/test-only-*.pem` paths retain their documented self-signed unit-test fixture exception. They cannot authenticate a real project; this does not allow production private keys.

Publication-only changes: `.gitignore`, `scripts/verify-release-snapshot.py`, `AGENTS.md`, README/testing notices, handoff 00/01/07 and previously prepared canonical docs/index/template/redactions. No UI/business/runtime, schema or dependency changes. Historical report copies preserve outcomes/limitations while redacting account/device identifiers; private originals remain outside Git.

## Validation and limits

**Previously run on the complete local source, not rerun in this exclusion-only step:**

| Check | Previous actual evidence |
|---|---|
| Backend scoped smoke | 26 PASS, no failures/errors/skips; GoogleFlowTest / GlobalBlockApiTest / PostFeedApiTest / ContextualRecommendationRerankerTest |
| Flutter scoped smoke | 36 PASS; Global Block / Home media lifecycle / DM privacy |
| Analyze | 0 errors, 14 warnings, 355 infos; nonzero diagnostic exit, not lint-clean |
| Rotation / health | API UP, Place AI v13 `ok`, business counts preserved |

This step verifies explicit file manifest, unchanged local entrypoint/runtime hashes, exactly one approved source exclusion, retained models/migrations/docs, relative links, real staged tree + exact root-commit token/credential/size gates, absence of old/rejected ancestry, and remote SHA equality after actual push. Results are recorded in the final local result note/response. The token gate still scans **all** included blobs for both Mapbox `pk`/`sk`, JWT/private-key material and server credentials; no scanning exemption for the private file's token in a different path or LFS pointer is allowed.

Pre-commit checks actually completed for the new exclusion: **814 selected files**, 100 relative links / 0 broken, 502 local runtime hashes unchanged including the privately retained entrypoint; original index unchanged. Staged-tree exact current/retired DB/JWT/Cloudinary/Firebase/private-main-token checks and the versioned pattern/size gate report **0 findings**. Tree comparison against the rejected snapshot changes only approved release docs/ignore/verifier and removes `lib/main.dart`; all other source/migrations/models are identical. Root-commit and remote checks still occur after this pre-push report is committed.

`git diff --check` has known pre-existing whitespace advisories: EOF blank lines in backend test/verification files and legacy reports, plus Markdown hard-break lines in two imported UI handoffs. Accepted runtime/report formatting is not rewritten to hide warnings. No claim of a full suite rerun or lint-clean tree is made.

**Git-only clean-clone validation:** file/tree/history/docs/secret checks are supported; no successful Flutter compile/run/test is claimed without the privately supplied entrypoint and other required private config. No native tests or new APK builds occur for this release.

## Handoff safety and stop boundary

All actual env/Firebase/signing/DB credentials remain outside Git and are delivered privately only as needed. Prefer isolated staging/scoped credentials, never clone real-user DB data. Empty databases can migrate schema; they do not acquire live Posts/users/Places through this release.

AI ranking remains advisory. Spring authorizes candidates and media at access time and Home retains newest-first fallback. Preserve Post audience, mutual/private accepted-follow rules, single Global Block, DM PENDING/ACCEPTED, protected Cloudinary media, Trip/Pin/GPS/LAST_KNOWN, D-2/D-1 at local 20:00, Stop times, Place AI, Notifications, approved UI and pagination/cache.

Sample Posts/hashtags/media require approved licensed/traceable sources, synthetic provenance, separation from real engagement, approved dev/staging scope, idempotency and limited rollback. No unapproved production seed, fake likes/follows/comments, impersonation or real-user data cloning. No AI implementation, sample generation, new migrations or further phase follows publication.
