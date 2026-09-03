---
version: 0.2.0-rc.3
from: 0.2.0-rc.2
date: 2026-09-03
---

# Version 0.2.0-rc.3 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.2 to 0.2.0-rc.3 (adds component mapping
for `/monorepo-self-improve`).

## Commands to run

Re-apply every installed adapter so the updated `/monorepo-self-improve` command files reach your
project. The harness-update workflow's step 7.5 does this already; running it directly is harmless
and idempotent (`--refresh` skips config rows). Run it once per installed adapter (`claude-code`,
`opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

## Manual follow-ups for the user

- None. Root `AGENTS.md` reconciliation is handled by the normal harness-update flow via
  `agents-md-merge`.

## Release summary

- New `.agents/.harness-map.json` records every project-owned rule, skill, agent, and command
created by `/monorepo-self-improve`.
- New `core/scripts/update-harness-map.sh` helper maintains the map deterministically and prevents
duplicates via the `name` + `type` unique key.
- `core/skills/self-improvement-workflow/SKILL.md` now reads the map before proposing components,
marks each proposal as `new` or `update`, and invokes `update-harness-map.sh` after writing files.
- All three adapter `/monorepo-self-improve` entry points (claude-code, codex, opencode) instruct the
agent to read the map first and update it on apply.
