---
version: 0.2.0-rc.1
from: 0.2.0-rc.0
date: 2026-09-03
---

# Version 0.2.0-rc.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.0 to 0.2.0-rc.1 (hardens the
`0_intent.md` reference-stub invariant).

## Commands to run

Re-apply every installed adapter so the updated `/monorepo-harness-spec` command files reach your
project. The harness-update workflow's step 7.5 does this already; running it directly is harmless
and idempotent (`--refresh` skips config rows). Run it once per installed adapter (`claude-code`,
`opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

This installs the updated command text that points agents at the new
`core/scripts/write-intent-ref.sh` helper.

## Manual follow-ups for the user

- **Convert any copied `0_intent.md` files to reference stubs.** If a task directory already
  contains a `0_intent.md` that duplicates the full intent content, run:

  ```bash
  bash .agents/monorepo-agents-harness/core/scripts/write-intent-ref.sh \
    <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug> \
    <workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md
  ```

  Then commit the corrected stub. Until this is done, `task-state.sh check-chain` will fail for that
  task.

## Release summary

- New `core/scripts/write-intent-ref.sh` helper mechanically creates the `0_intent.md` reference
  stub (`phase: intent-ref`) for intent-seeded tasks. It validates intent approval and computes the
  relative `source:` path so agents no longer need to hand-write the stub.
- `core/scripts/task-state.sh check-chain` now rejects any `0_intent.md` whose `phase:` is not
  `intent-ref`, catching full-intent copies that slip through.
- All three adapters' `/monorepo-harness-spec` commands now instruct the agent to call
  `write-intent-ref.sh` instead of composing the stub manually.
- `core/skills/agent-workflow/SKILL.md` documents the helper script in the reference-stub section.
