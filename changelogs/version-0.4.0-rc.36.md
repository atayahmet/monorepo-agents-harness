---
version: 0.4.0-rc.36
from: 0.4.0-rc.35
date: 2026-11-22
---

# Version 0.4.0-rc.36 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.35 to 0.4.0-rc.36, which fixes how
`kb-ingest.sh` writes rows into `knowledge/index.md` (issue #75).

## What changed

- A catalog section's table header is written once. New rows go after the last row of the table.
- A Decision records row's overview is the ADR's `# ` title, not `---`.
- A re-run of `kb-ingest.sh` finds an existing row by its link target, so it never adds a second row
  for a page whose overview was edited.
- `task-state.sh check-kb` now fails when one `### ` section in `knowledge/index.md` has a repeated
  table header or two rows linking the same page.

## Commands to run

- Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-kb <task_dir>` for any
  recently ingested task dir. If it reports `knowledge/index.md catalog damaged`, do the follow-up below.

## Manual follow-ups for the user

- Only if `check-kb` reports damage: earlier versions may have left repeated `| Page | Overview |` /
  `| ---- | -------- |` pairs, `---` overviews, and duplicate rows in `knowledge/index.md`. In each
  section named in the report, keep the first header pair and one row per page, and replace each `---`
  overview with the ADR's title. Show the diff to the user before committing it.

## Release summary

- Fixed `kb-ingest.sh` catalog rows: one header per section, ADR title as overview, link-target dedup.
- Added a catalog lint to `task-state.sh check-kb`.
- Added the repo-local test `tests/kb-ingest-catalog.test.sh`.
- No change to `core/root-AGENTS.md`.
