# Knowledge Base — Schema

This is the constitution of `knowledge/`: the page types, naming rules, link and citation rules, and
the ingest / query / lint workflows an agent follows to be a disciplined knowledge-base maintainer
rather than a generic chatbot. It is co-evolved with the project — when a convention stops working,
update this file in the same change that updates the pages.

## Page types

| Directory | Page type | Compiled from | Agent role |
| --------- | --------- | ------------- | ---------- |
| `modules/` | one page per workspace / package | `3_memory.md` durable outcomes, index rows | keep current |
| `concepts/` | one page per recurring pattern | `3_memory.md` durable outcomes | strengthen/challenge synthesis |
| `decision-records/` | compiled ADRs, one per file | task `adr/NNNN-*.md` | near-direct copy, provenance-cited |
| `verified-facts/` | what was proven and how | task `4_verify.md` | evidence, not narration |
| `sources/` | one synopsis page per task | task directory + index row | pointer to the raw artifact |

## Naming rules

- Page files are `snake_case` (`[a-z0-9_]`), 3–5 words, matching the task slug when the page is
  compiled from one task.
- `decision-records/` keeps the source ADR's `NNNN-<title>.md` name so numbering round-trips.
- No placeholder pages, ever: a page exists only when it has real content.

## Link and citation rules (mandatory)

- Every page uses `[[wiki-link]]` cross-links to related modules/concepts/decisions.
- Every page ends with a `Sources:` footer listing the **raw artifact paths** it was compiled from
  (e.g. `apps/api/.agents/artifacts/task_2026_06_03_huawei_webhook_handler/3_memory.md`). A claim with
  no source footer is a claim that must not ship.
- Raw artifacts are immutable; `knowledge/` pages are regenerable. Never edit a raw artifact from an
  ingest.

## Workflows

### Ingest (task end, incremental — the only ingest path)

Triggered by `/monorepo-harness-build` after `3_memory.md` / `4_verify.md` / `adr/` are written, or
by `core/scripts/kb-ingest.sh <task_dir>` directly. For the task's artifacts:

1. Read `3_memory.md`. If the workspace/module it names already has a `modules/` page, update it;
   else create one. Extract recurring patterns into `concepts/<pattern>.md` (create/update).
2. For each `adr/NNNN-*.md`, create/update `decision-records/NNNN-<title>.md` (cited copy).
3. When the task has `4_verify.md`, create/update `verified-facts/<task_slug>.md` (what was proven,
   how).
4. Write `sources/<task_slug>.md` (one-paragraph synopsis + pointer to the raw task dir).
5. Append a `log.md` row and refresh the relevant `index.md` catalog sections.
6. Every changed/created file lands in the **same commit** as the task's memory/verify.

Research-only tasks (no `3_memory.md`) are skipped — nothing to ingest, no log entry.

### Query (fast path)

On a question: read `index.md`, open the linked pages, synthesize with citations. Only when the KB
lacks coverage, scan the per-workspace artifact trees (`apps/*/.agents/artifacts/`). Good answers
can be filed back into the KB as `concepts/` or `decision-records/` additions (append to `log.md`).

### Lint (periodic, explicit)

Scan every page for:

1. A concept/module/decision referenced via `[[wiki-link]]` but lacking its own page — flag for creation.
2. Contradictions between pages — flag **both** positions, do not silently resolve; escalate to the
   user (`status: PENDING` marker on the page).
3. Broken `Sources:` links (raw artifact moved/deleted) — flag, do not edit the raw artifact.
4. Stale pages (source task older than a threshold and never re-ingested) — flag for review.

Write flags to `log.md` and optionally a one-page lint report; do not modify pages during a lint pass.
A human decides whether to let the agent apply fixes automatically or review them first.