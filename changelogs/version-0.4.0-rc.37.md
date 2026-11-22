---
version: 0.4.0-rc.37
from: 0.4.0-rc.36
date: 2026-11-22
---

# Version 0.4.0-rc.37 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.36 to 0.4.0-rc.37, which adds the
`--no-plan-mode` flag to `/monorepo-harness-plan` (issue #76).

## What changed

**`/monorepo-harness-plan <spec.md> --no-plan-mode` skips the plan-mode question.**
- When the agent is not in plan mode, it does not ask "Enable plan mode?" and does not enter plan mode.
  It goes straight on to the knowledge-base query and writes `2_plan.md`.
- When the agent is already in plan mode, the flag does nothing. The agent prints one short note and
  continues.
- The flag works in any position after the command name: before or after the spec path.
- Without the flag, nothing changes.

The flag only skips the question. `task-state.sh check-spec` still runs first, the knowledge-base query
still runs, and the command still stops after `2_plan.md`. You still run `/monorepo-harness-build
<2_plan.md>` next.

The three entry points (claude-code, opencode, codex) carry the same text. The claude-code menu hint is
now `<1_spec.md> [--no-plan-mode]`.

## Commands to run

- None. The update flow's `install-adapter.sh <agent> --refresh` step re-copies the changed
  `/monorepo-harness-plan` entry points, and `install-harness.sh --sync-only` updates
  `core/skills/agent-workflow/SKILL.md`.

## Manual follow-ups for the user

- Optional: if you always answer "no" to "Enable plan mode?", run
  `/monorepo-harness-plan <1_spec.md> --no-plan-mode` from now on.

## Release summary

- Added the `--no-plan-mode` flag to `/monorepo-harness-plan` on claude-code, opencode and codex, with
  the same text in `core/skills/agent-workflow/SKILL.md` Phase 2 (issue #76).
- Added the repo-local test `tests/no-plan-mode-flag.test.sh`.
- No change to `core/root-AGENTS.md`.
