# Claude Code Adapter — User Guide

This adapter wires the harness into **Claude Code**. It gives you an automatic plan/spec reminder when you leave plan mode, a hard memory-gate at task end, and two slash commands for harness plumbing.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Automatic plan/spec reminder** — when you exit plan mode (`ExitPlanMode`), Claude Code is nudged to create the task directory and write `1_plan.md` + `2_spec.md` before any implementation.
- **`/tah-build`** — a manual fallback that triggers the same plan/spec build step. Use it if the automatic reminder is missed or if you skipped plan mode.
- **`/tah:update`** — compares your installed harness against upstream and upgrades the agent-neutral core with your consent.
- **Hard memory-gate** — the `Stop` hook refuses to end the task until today's task directory contains `3_memory.md`.

## Day-to-day commands

### `/tah-build` — Build plan/spec artifacts

Use `/tah-build` right after plan approval (or whenever the plan/spec reminder did not fire) and **before the first Edit/Write**. The command points to the shared `agent-workflow` skill, which tells the agent to:

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

### `/tah:update` — Check for harness updates

Use `/tah:update` when you suspect the harness is out of date or after a release announcement. It reports the installed vs. latest version and asks for consent before upgrading.

## Typical workflow

1. Start a non-trivial task and enter plan mode.
2. Approve the plan. Claude Code normally fires the plan/spec reminder automatically.
3. If the reminder is missed, type `/tah-build`.
4. Implement the task, scoped to the target workspace.
5. Commit your changes.
6. Write `3_memory.md` in the same task directory and update the workspace index — the `Stop` hook will block until you do.

## Notes

- The automatic reminder and `/tah-build` both use the same shared `core/skills/agent-workflow/SKILL.md` instructions.
- The memory-gate is a **hard block** in Claude Code; you cannot end the task until `3_memory.md` exists.
