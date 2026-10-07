---
name: monorepo-harness-kb-index
description: Query, rebuild or link-lint the knowledge base through its SQLite FTS5 index. Use when the user types /monorepo-harness-kb-index or asks a project-knowledge question, wants the knowledge index rebuilt, or wants the KB orphan/broken-link lint.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/knowledge-base/SKILL.md` (query and lint workflows):

1. **No arguments** (the user's question) → run
   `bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<keywords from the question>"`,
   open only the top hits it prints, and synthesize with citations.
2. **`rebuild`** → `... kb-index.sh rebuild --stats`. Only when explicitly asked — every query
   rebuilds the index itself as soon as a page changed, so a manual rebuild is rarely needed.
3. **`links`** → `... kb-index.sh links --missing` and `... kb-index.sh links --orphans`, then
   follow the skill's lint workflow for the half SQL cannot do (contradictions, stale sources).
4. Pass `--kind <k>`, `--workspace <w>`, `--limit <n>` through when the user scoped the question;
   `--kb <root>` relocates the knowledge root.

If the command prints one warning and exits non-zero (no `sqlite3`, or a build without FTS5), say
that once and fall back to the skill's `index.md` + grep path — never fail the task over the cache.
Never hand-edit `knowledge/.index.sqlite`: it is a derived cache, safe to delete and rebuilt on
demand.
