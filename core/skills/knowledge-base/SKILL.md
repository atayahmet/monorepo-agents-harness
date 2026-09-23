---
name: knowledge-base
description: Maintain the compiled knowledge base at the repo root — knowledge/. Compiled incrementally at task end (kb-ingest.sh, driven by /monorepo-harness-build) from a task's 3_memory.md, 4_verify.md and adr/ files; answers questions fast against compiled, interlinked pages instead of re-deriving from per-workspace artifact trees (Karpathy LLM Wiki pattern). Use when the user asks the agent a question that spans project knowledge, when a task is ending and its memory/verify must reach the KB, or to lint the KB for stale/contradictory/orphan pages.
---

# Knowledge Base — Ingest / query / lint compiled knowledge at the repo root

The repo root `knowledge/` is the compiled view of every workspace's task history (Karpathy "LLM
Wiki": compile once at task end, keep current, never re-derive per query). Raw task artifacts under
`.agents/artifacts/` stay immutable; `knowledge/` is regenerable agent-maintained output. Engine:
`core/scripts/kb-ingest.sh`; constitution: `knowledge/schema.md` (read it before ingesting or
writing pages). No vector DB, no tooling — markdown + grep.

## Concepts

1. **Compile once, query cheap.** Questions are answered from `knowledge/index.md` + linked pages,
   not by scanning `apps/*/.agents/artifacts/` trees per query. Scan raw artifacts only when the KB
   lacks coverage.
2. **Task end is the only ingest point.** `/monorepo-harness-build` runs `kb-ingest.sh` right after
   `3_memory.md`/`4_verify.md` are written; the KB update lands in the same commit. Research-only
   tasks (no memory) are skipped. There is no batch/backfill compiler.
3. **Everything cited, nothing orphaned.** Every page carries `[[wiki-link]]` cross-links and a
   `Sources:` footer naming the raw artifact paths it was compiled from. A claim without a source
   footer must not ship.

## Workflow — ingest (task end)

1. Resolve `<task_dir>` (the `/monorepo-harness-build <2_plan.md>` task dir has done this for you).
2. Read `3_memory.md`. Update/create `modules/<module>.md` for the workspace it names; if it states
   a recurring pattern, update/create `concepts/<pattern>.md`. Copy durable outcomes verbatim where
   they are decisions, paraphrase where they are context — always citing.
3. For each `adr/NNNN-*.md`, create/update `decision-records/NNNN-<title>.md` (cited copy; the raw ADR
   stays the source of truth — numbering round-trips).
4. When the task has `4_verify.md`, write `verified-facts/<task_slug>.md` (claim + how it was proven).
5. Write `sources/<task_slug>.md` (one-paragraph synopsis + pointer to the raw task dir).
6. Append a `knowledge/log.md` row (`YYYY-MM-DD <task_slug> → <page>: <one-line>`) and update the
   matching `knowledge/index.md` catalog sections.
7. Commit the KB change in the task's final commit; never block on a page edit — `check-kb` (below)
   proves coverage.

## Workflow — query (fast path)

1. Read `knowledge/index.md` and open the linked pages; synthesize with citations.
2. On a match, done — do not open artifact trees. Only with no coverage, grep
   `apps/*/.agents/artifacts/` + `packages/*/.agents/artifacts/` (global discovery recipes in
   `core/governance/artifacts/AGENTS.md`).
3. Consider filing good answers back into `knowledge/` (a comparison, an analysis) as a
   `concepts/` or `decision-records/` addition, appending to `log.md`.

## Workflow — lint (periodic, explicit)

Scan all pages: `[[wiki-link]]` targets without a page (flag for creation), contradictions (flag
**both** positions, `status: PENDING`, escalate to the user — never silently resolve), broken
`Sources:` footers (flag; never edit the raw artifact), stale pages (source task old and never
re-ingested). Write flags to `log.md`/a lint report; do not modify pages during the pass. The user
decides whether fixes apply automatically or are reviewed first.

## Gate — `check-kb`

`bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-kb <task_dir>` — read-only.
When the task has `3_memory.md`, every page its memory/verify/ADR reference must exist under
`knowledge/` and be cataloged in `knowledge/index.md`. Run it before declaring a KB change done;
never bypass it with a "trust me" edit.

## Never do

- Never edit a raw task artifact from an ingest, or re-derive `knowledge/` wholesale from all
  artifacts (no backfill compiler exists by design).
- Never create a placeholder/orphan page; a page exists only with real content and citations.
- Never resolve a contradiction silently — document both positions and escalate.
- Never skip `check-kb` for a task that wrote `3_memory.md`.

## Edge cases

- **Research-only / N/A task** (no `3_memory.md`): ingest is a no-op; no log entry; gate green.
- **Task dir outside a workspace** (harness repo itself): `<workspace>` is the repo root; the same
  rules apply with the task dir under `.agents/artifacts/`.
- **Harness not installed** → inactive until `INSTALL.md` Phase 1 completes.