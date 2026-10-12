---
version: 0.4.0-rc.20
from: 0.4.0-rc.19
date: 2026-10-12
---

# Version 0.4.0-rc.20 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.19 to 0.4.0-rc.20. This release makes the
intent stage reach the knowledge base, so prior art is queried when an intent is captured or reviewed
instead of never.

## What changed

`/monorepo-harness-intent` never reached the repo-root `knowledge/`. Capture wrote the intent file
directly and Review only grepped the intent frontmatter, so an intent could be filed over prior
compiled knowledge without reading it — even though the spec stage already queries the KB first
(`0.4.0-rc.15`/`-rc.16`).

Now, in `core/skills/intent-workflow/SKILL.md`:

- **Capture** runs
  `bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<1-3 keywords>"` (the ranked
  SQLite FTS5 index over `knowledge/`; grep fallback without `sqlite3`/FTS5) **before** it writes the
  intent file, and records the result in a new `## Prior art` section —
  `- KB: [[<page>]] (knowledge/…)` per hit, or `- KB: no relevant pages` when there are none.
- **Review** runs the same query per pending intent, shows the ranked hits, and fills in `## Prior
  art` when it is missing.

`core/governance/intents/AGENTS.md` lists `## Prior art` in the intent file format and states that
Capture is its only writer (Review only fills a gap). The three intent stubs
(`adapters/claude-code/.claude/commands/monorepo-harness-intent.md`,
`adapters/opencode/.opencode/commands/monorepo-harness-intent.md`,
`adapters/codex/.agents/skills/monorepo-harness-intent/SKILL.md`) name the step; all three are existing
`copy` rows — no manifest change. `README.md` Scenario 1, `PORTABILITY.md` and `INSTALL.md` were synced.
This mirrors the plan's `- KB:` trace (`0.4.0-rc.18`, issue #32) one stage earlier.

No script, manifest, adapter row, hook, or gate changed. Instruction-only.

## Commands to run

- None by hand. There is nothing to install: the intent skill and its governance doc ship in the
  bundle sync, and the three intent stubs are existing `copy` rows that reach the project on the
  normal adapter refresh.

## Manual follow-ups for the user

- None. Existing intents are untouched; the new Capture/Review query takes effect on the next
  `/monorepo-harness-intent` run. On a project with no committed `knowledge/` yet, the query finds
  nothing and the intent records `- KB: no relevant pages`, exactly as before this release.

## Release summary

- `core/skills/intent-workflow/SKILL.md`: Capture queries the KB before writing and records a
  `## Prior art` section; Review queries per pending intent and fills the section in (closes #39).
- `core/governance/intents/AGENTS.md`: `## Prior art` added to the intent format, with the query rule.
- The three intent stubs (claude-code, opencode, codex) name the `kb-index.sh query` step.
- `README.md` Scenario 1, `PORTABILITY.md`, `INSTALL.md`: docs synced to the intent stage's KB read.
- `tests/prior-art.test.sh`: repo-local text guards for the intent skill + governance doc.
