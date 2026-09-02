---
version: 0.1.0-rc.10
from: 0.1.0-rc.9
date: 2026-09-02
---

# Version 0.1.0-rc.10 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.9 to 0.1.0-rc.10.

## Commands to run

None.

## Manual follow-ups for the user

None.

## Release summary

- `0_intent.md` is now a reference stub, not a copy. Task directories seeded by an approved intent
  write a stub with a `source:` frontmatter link back to the real intent file instead of duplicating
  its content, keeping the intent file the single source of truth. `core/scripts/task-state.sh`
  `check-chain` resolves that link and checks approval on the original intent file. Updated in
  `core/skills/agent-workflow/SKILL.md`, `core/governance/intents/AGENTS.md`,
  `core/scripts/task-state.sh`, and the three adapters' `/monorepo-harness-spec` stubs and READMEs.
