# GoMate Codex Knowledge Pack

This folder is a token-efficient coding context derived from the GoMate Master Spec, redesigned roadmap, older plan (only for non-conflicting historical context), and the teammate Auth README.

## Put these in the repository

```text
GOMATE/
├── AGENTS.md
└── docs/
    ├── CODEX_INDEX.md
    ├── PROJECT_CONTRACT.md
    ├── DATABASE_CONTRACT.md
    ├── AUTH_CURRENT_STATE.md
    └── ROADMAP_AND_DONE.md
```

## Reading policy for Codex

1. Always read `AGENTS.md`.
2. Read `docs/CODEX_INDEX.md`.
3. Load only the task-specific compact file(s).
4. Inspect actual source code involved in the task.
5. Consult the original DOCX only if a compact file says the canonical detail is intentionally omitted/incomplete or a new conflict must be resolved.

This avoids loading the full 51-page specification for every small task while preserving the project's architectural and business constraints.

## What each file contains

- `AGENTS.md` — non-negotiable agent/team rules, source precedence, target repo structure, safety, Git, Flyway, Auth/core boundaries.
- `CODEX_INDEX.md` — routing table telling Codex what compact context to load for each task.
- `PROJECT_CONTRACT.md` — architecture, locked decisions, business rules, API catalog, non-functional constraints.
- `DATABASE_CONTRACT.md` — official PostgreSQL/MongoDB model, key columns/enums/indexes, Flyway policy.
- `AUTH_CURRENT_STATE.md` — what teammate Auth already implements, run commands, Google extension, and conflicts with the canonical target.
- `ROADMAP_AND_DONE.md` — build order, 12-week milestones, demo flow, acceptance tests, Definition of Ready/Done.

## Important distinction

`AUTH_CURRENT_STATE.md` describes **current working implementation state**. It does not override the canonical Master Spec. During a structure-only refactor, preserve working behavior first. Schema/API/business alignment should be performed as explicit coordinated tasks, not hidden inside file moves.
