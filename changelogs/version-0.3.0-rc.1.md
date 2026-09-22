---
version: 0.3.0-rc.1
from: 0.3.0-rc.0
date: 2026-09-22
---

# Version 0.3.0-rc.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.3.0-rc.0 to 0.3.0-rc.1 (a starter project
rule that keeps local `AGENTS.md` files current).

## Commands to run

Seed the new starter rule into the project's `.agents/rules/` (idempotent — existing rules are
never overwritten):

```bash
bash .agents/monorepo-agents-harness/core/scripts/scaffold-project-agents.sh
```

## Manual follow-ups for the user

- None. The root `AGENTS.md` reconciliation (step 9) adds the Reference Map row for the seeded rule
  as part of the normal merge, and `audit-install.sh` confirms the seed landed.

## Release summary

- The installer now seeds `.agents/rules/local-agents-md.md` into every consumer project: when an
  agent works in any directory inside a workspace — the workspace root or a nested subdirectory at
  any depth — whose current state needs agent instructions, it must add or update `AGENTS.md` there.
- New `core/scripts/scaffold-project-agents.sh` seeds from `core/project-rules-template/` and
  registers each created rule in `.agents/.harness-map.json`; `install-harness.sh` runs it on
  install, `audit-install.sh` verifies the seed. `core/root-AGENTS.md` ships the matching Reference
  Map row. Version bumped to `0.3.0-rc.1`.