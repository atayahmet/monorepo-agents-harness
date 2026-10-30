---
version: 0.4.0-rc.32
from: 0.4.0-rc.31
date: 2026-10-30
---

# Version 0.4.0-rc.32 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.31 to 0.4.0-rc.32, which makes a finished
task's knowledge-base pages searchable the moment ingest ends.

## What changed

**`kb-ingest.sh` now updates the search index itself.** Until now the SQLite index
(`knowledge/.index.sqlite`) was only repaired by the next `kb-index.sh query`, so right after
`/monorepo-harness-build` it did not hold the new task. Ingest now adds every page it writes to the
index through the new `kb-index.sh add <path>...`. The step is best-effort: without `sqlite3` or FTS5, or
if the add fails, the ingest still succeeds and the next `query` or `rebuild` repairs the index.

**`kb-index.sh add <path>...` upserts single pages.** Each page's old row, search entry and link edges
are replaced in one transaction, so repeating it duplicates nothing. If any other page changed since the
index was written, it rebuilds the whole index instead, so a page can never be left unindexed. With no
index yet it does nothing. `rebuild` is unchanged and stays the full, safe path.

## Commands to run

- None. `core/install-manifest.txt` already copies the whole `core/` directory, so the update flow's
  `install-harness.sh --sync-only` step installs the changed scripts and skill. An existing
  `knowledge/.index.sqlite` stays valid and is updated in place by the next ingest.

## Manual follow-ups for the user

- Optional: your project's `knowledge/schema.md` was seeded once and is never overwritten. Its "Index
  layer" section still says `kb-ingest.sh` never touches the index. Replace that sentence with: ingest
  adds the pages it writes to the index with `kb-index.sh add`; `rebuild` and the query-time self-heal
  remain the full path. Nothing depends on the old wording.

## Release summary

- Added `kb-index.sh add <path>...` and made `kb-ingest.sh` use it (issue #63).
- No change to `core/root-AGENTS.md`.
