---
version: 0.4.0-rc.14
from: 0.4.0-rc.13
date: 2026-10-11
---

# Version 0.4.0-rc.14 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.13 to 0.4.0-rc.14. This release makes
the root "Query Knowledge First" rule point at the ranked knowledge-base index, and widens the
knowledge-base skill so it loads at the start of a spec or a plan.

## What changed

`core/root-AGENTS.md` mentioned the knowledge base in two places — the Before You Start checklist and
Agent Lifecycle 9 — but both described the slow path: read `knowledge/index.md` by hand and grep the
pages. Since `0.4.0-rc.13` the KB has a SQLite FTS5 index (`core/scripts/kb-index.sh query`), so both
mentions now make the ranked query the first step:

```
bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<keywords>"
```

It returns BM25-ranked paths with snippets (and falls back to grep when `sqlite3`/FTS5 is
unavailable), so the agent opens only the top pages. `knowledge/index.md` stays the browsing path for
the full catalog. The `core/skills/knowledge-base/SKILL.md` description now also triggers "at the
start of a spec or a plan (query prior art first)".

No script, manifest, or adapter file changed. This is a text-only release.

## Commands to run

- None by hand. There is nothing to install: the change lives in the root `AGENTS.md` template and a
  skill description, both carried by the normal update.

## Manual follow-ups for the user

- **The root `AGENTS.md` merge is automatic and consent-gated.** The next update reconciles your root
  `AGENTS.md` with the fresh template through `core/skills/agents-md-merge/SKILL.md`: it keeps 100% of
  your content and asks before writing. Accept the new "Query Knowledge First" wording when it is
  offered — you do not edit the file by hand.
- Nothing else: no `.gitignore` change, no new file, no command.

## Release summary

- `core/root-AGENTS.md`: the checklist item and Agent Lifecycle 9 now name
  `kb-index.sh query` as the read path, with `knowledge/index.md` kept for browsing (closes #30).
- `core/skills/knowledge-base/SKILL.md`: `description` widened so the skill triggers at spec/plan
  start, not only at task end.
