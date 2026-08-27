---
version: 0.1.0-rc.3
from: 0.1.0-rc.2
date: 2026-08-27
---

# Version 0.1.0-rc.3 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.2 to 0.1.0-rc.3.

## Commands to run

Re-apply every installed adapter so the new per-stage SDLC commands reach your project. This follows
the normal step 7.5 of the harness-update workflow, but the intent of the changed `-build` semantics
below is a behavior change you should be aware of.

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

Run it once per installed adapter (`claude-code`, `opencode`, and/or `codex`). This copies the new
`/monorepo-harness-spec` and `/monorepo-harness-plan` commands/skills and the rewritten
`/monorepo-harness-build` into place.

## Manual follow-ups for the user

- **`/monorepo-harness-build` has changed meaning.** It no longer writes `1_spec.md`/`2_plan.md`.
  From now on use `/monorepo-harness-spec <intent.md?>` then `/monorepo-harness-plan <spec.md>`, then
  `/monorepo-harness-build <2_plan.md>` to implement. On completion, `-build` now automatically
  writes `3_memory.md` and `4_verify.md` (when required) and updates the index.
- **Intent approval is conditional.** `-spec` enforces an approved intent only when you pass an intent
  path; ad-hoc tasks (no intent) are unaffected. `-build` enforces intent approval only for tasks
  that are intent-seeded (their directory contains a `0_intent.md`).

## Release summary

- New `core/scripts/task-state.sh` (read-only chain validator) and three gated SDLC stage commands
  (`-spec`, `-plan`, `-build`) replace the single monolithic `-build` in all three adapters, with the
  command tables and docs updated.
