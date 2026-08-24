# opencode Adapter — User Guide

This adapter wires the harness into **opencode**. Because opencode has no `ExitPlanMode`-style hook, the plan/spec build step is triggered manually via the `/tah-build` slash command.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **`/tah-build`** — manually create the task directory and write `1_plan.md` + `2_spec.md` before implementation.
- **`/tah-update`** — compare your installed harness against upstream and upgrade the agent-neutral core with your consent.
- **Universal hard gate** — the git pre-commit / CI version of `core/scripts/memory-gate.sh` blocks commits until `3_memory.md` exists.

## Day-to-day commands

### `/tah-build` — Build plan/spec artifacts

Use `/tah-build` right after you approve a plan and **before the first Edit/Write**. The command points to the shared `agent-workflow` skill, which tells the agent to:

1. Pick the target workspace (`apps/<name>` or `packages/<name>`).
2. Create `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`.
3. Write `1_plan.md` and `2_spec.md`.
4. Add a row to `<workspace>/.agents/artifacts/index.md`.

Example:

```
User: /tah-build
Agent:  → creates apps/web/.agents/artifacts/task_2026_08_23_add_login_form/
        → writes 1_plan.md + 2_spec.md
```

### `/tah-update` — Check for harness updates

Use `/tah-update` when you suspect the harness is out of date or after a release announcement. It reports the installed vs. latest version and asks for consent before upgrading.

## Typical workflow

1. Start a non-trivial task and create your plan.
2. Once the plan is approved, type `/tah-build`.
3. Implement the task, scoped to the target workspace.
4. Commit your changes.
5. Write `3_memory.md` in the same task directory and update the workspace index.
6. The git pre-commit hook blocks the commit until `3_memory.md` is written.

## Notes

- `/tah-build` is the primary way to start the plan/spec build on opencode; there is no automatic plan-mode hook.
- Memory-gate enforcement is the universal hard gate (`core/scripts/memory-gate.sh`) installed as a git pre-commit hook or CI step; opencode cannot block its own stop.
