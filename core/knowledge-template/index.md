# Knowledge Base — {{PROJECT_NAME}}

Compiled, agent-maintained knowledge layer for this repository (Karpathy "LLM Wiki" pattern).
Raw task artifacts are the immutable source of truth; the pages below are the compiled, regenerable
view an agent reads first to answer questions fast.

## How to use (agents)

1. **Query fast-path:** before scanning any `.agents/artifacts/` tree, read this `index.md` and the
   pages it links. Synthesize the answer from the compiled pages. Scan the raw artifacts **only**
   when the KB lacks coverage.
2. **Ingest at task end:** after a task writes `3_memory.md` / `4_verify.md` / `adr/`, run
   `core/scripts/kb-ingest.sh <task_dir>` (driven automatically by `/monorepo-harness-build`).
3. **Lint (periodic):** apply `core/skills/knowledge-base/SKILL.md`'s lint workflow to surface
   contradictions, stale pages, and orphans.

Rules, page types, naming, and citation conventions: `schema.md`. Operated state: `log.md`.

## Catalog

<!-- One row per page, grouped by section. Keep rows greppable: fixed columns, concrete identifiers.
     This file is updated by kb-ingest.sh and by agents following the knowledge-base skill. -->

### Modules (workspace / package pages)

| Page | Overview |
| ---- | -------- |
| _(add `<snake_case>.md` rows as modules gain pages)_ | |

### Concepts (durable patterns)

| Page | Overview |
| ---- | -------- |
| _(add `<snake_case>.md` rows as recurring patterns are extracted)_ | |

### Decision records (compiled from adr/)

| Page | Decision |
| ---- | -------- |
| _(add `NNNN-<title>.md` rows when ADRs are compiled)_ | |

### Verified facts (from 4_verify.md)

| Page | Claim |
| ---- | ----- |
| _(add `<task_slug>.md` rows when verifications are compiled)_ | |

### Sources (per-task synopses)

| Page | Task |
| ---- | ---- |
| _(add `<task_slug>.md` rows as task artifacts are ingested)_ | |