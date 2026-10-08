---
version: 0.4.0-rc.13
from: 0.4.0-rc.12
date: 2026-10-07
---

# Version 0.4.0-rc.13 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.12 to 0.4.0-rc.13. The knowledge base
now has a ranked, self-healing search index: `core/scripts/kb-index.sh` answers queries and both
link lints from a gitignored SQLite FTS5 cache, and `/monorepo-harness-kb-index` teaches every
adapter to call it.

## What changed

`kb-index.sh` (a new bundle file, carried by a manifest row) builds `knowledge/.index.sqlite` over
`knowledge/**/*.md`: BM25-ordered hits with `snippet()` highlights, columns derived from the page
shapes `schema.md` documents (`kind`, `workspace`, `task_slug`, `date`), and
`links --missing` / `links --orphans` as one SQL pass each. `query` and `links` detect staleness
and rebuild before answering, so `kb-ingest.sh` is byte-identical to the previous release and a
page written at task end is found with no manual reindex. When `sqlite3` or FTS5 is unavailable the
script exits 1 with exactly one warning and the documented `index.md` + grep fallback still answers
— same results, no ranking.

The cache must never be committed, so the new bundle row `core/gitignore-fragment.txt` carries the
ignore lines; `install-harness.sh` merges them into the consumer's root `.gitignore` (idempotent,
absent lines only, and also under `--sync-only`), and `audit-install.sh` verifies them verbatim in
Check 5c alongside an explicit check that `kb-index.sh` is in the installed bundle.

## Commands to run

- None by hand: this release is fully covered by the manifests. The normal update
  (`/monorepo-harness-update`, which runs `install-harness.sh --sync-only` and then
  `install-adapter.sh <agent> --refresh`) copies the new script, merges the `.gitignore` lines and
  installs `/monorepo-harness-kb-index` on the active adapter.

## Manual follow-ups for the user

- **Look at your root `.gitignore`.** It gains two lines — one comment and
  `knowledge/.index.sqlite*` — on the next install. They are appended only when absent, and
  `audit-install.sh` names the line by value if you ever remove it.
- **No indexing step to schedule.** The first `query` builds the index (sub-second at KB scale) and
  every later `query` rebuilds it when pages changed. Deleting `knowledge/.index.sqlite*` at any
  time is safe: it is a derived cache and the next query recreates it.
- **Ranking needs `sqlite3` with FTS5.** Without it the skill falls back to `index.md` + grep and
  loses only the ordering; install `sqlite3` if you want the ranked path. Nothing else changes for
  agents — the index has no adapter-specific wiring.

## Release summary

- New `core/scripts/kb-index.sh`: ranked FTS5 search (`rebuild` / `query` / `links`) over
  `knowledge/`, atomic temp-file + rename rebuilds, staleness self-heal at query time (closes #25).
- `knowledge/.index.sqlite*` stays out of every consumer repo through an audited gitignore
  fragment merged by the installer.
- `/monorepo-harness-kb-index` ships on claude-code, opencode and codex (one `copy` row each).
- Docs: knowledge-base skill query/lint workflows, a new index-layer section in `knowledge/schema.md`,
  `PORTABILITY.md`, `README.md`, `INSTALL.md` and the three adapter READMEs/INSTALLs.
- 38 cases in the repo-local `tests/kb-index.test.sh`, including a deterministic proof that an
  interrupted rebuild never replaces the previous index.
