---
version: 0.4.0-rc.5
from: 0.4.0-rc.4
date: 2026-09-28
---

# Version 0.4.0-rc.5 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.4 to 0.4.0-rc.5, which fixes what
`/monorepo-harness-intent-dispatch` wrote on its first real run.

## What changed

The command used to create `0_intent.md`, `1_spec.md` and `2_plan.md` per phase, plus an
`artifacts/index.md` row. Those belong to `/monorepo-harness-spec` and `/monorepo-harness-plan`,
which scope one task at a time — dispatch was running the whole chain N times over in one turn. It now
opens one tracker issue per phase and writes nothing else. A task is the issue.

It also checks the intent's **PR** for an approving review before the intent file, so an intent
approved on GitHub while the local file still said `pending` is no longer refused.

## Commands to run

- None. No file is added to the bundle or an adapter, so there is no manifest row to add — the normal
  update sync (`/monorepo-harness-update`) installs the changed
  `core/scripts/task-state.sh`, `core/scripts/tracker-issue.sh`,
  `core/skills/intent-workflow/SKILL.md`, `core/governance/intents/AGENTS.md` and the three dispatch
  entry points, and the adapter refresh places the `tracker` subagent update.

## Manual follow-ups

- **If you already ran dispatch on `0.4.0-rc.4`, keep the task directories it wrote.** They are valid
  tasks and work unchanged with `/monorepo-harness-plan` and `/monorepo-harness-build`. There is
  nothing to convert and nothing to delete. Re-running dispatch now opens issues rather than
  rewriting those files, so a re-run cannot overwrite a spec or plan you have edited.
- **When you scope a phase, read its issue body first.** The phase's scope, workspace and
  verification command are in the issue now instead of in a `1_spec.md` on disk. The approved intent
  file is still the single source of truth, and `/monorepo-harness-spec <intent.md>` links it as
  `0_intent.md` exactly as before.

## Verify

```bash
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved \
  <your-intent.md> --pr <pr-number>
```

Exit 0 and a `source:` in the message means the gate passed. `--pr` needs `gh` authenticated; with
`gh` missing it warns and falls back to the file's own `status:`.
