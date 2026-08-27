# Claude Code Adapter — User Guide

This adapter wires the harness into **Claude Code**. It gives you an automatic plan/spec reminder when you leave plan mode, a hard memory-gate at task end, and two slash commands for harness plumbing.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Automatic plan/spec reminder** — when you exit plan mode (`ExitPlanMode`), Claude Code is nudged to create the task directory and write `1_spec.md` + `2_plan.md` before any implementation.
- **`/monorepo-harness-build`** — a manual fallback that triggers the same plan/spec build step. Use it if the automatic reminder is missed or if you skipped plan mode.
- **`/monorepo-harness:update`** — compares your installed harness against upstream and upgrades the agent-neutral core with your consent.
- **Hard memory-gate** — the `Stop` hook refuses to end the task until today's task directory contains `3_memory.md`, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement).
- **`verifier` subagent** — an isolated, read-only subagent that runs the task's verification commands and reports pass/fail evidence for `4_verify.md`, without touching any files.

## Day-to-day commands

### `/monorepo-harness-build` — Build plan/spec artifacts

Use `/monorepo-harness-build` right after plan approval (or whenever the plan/spec reminder did not fire) and **before the first Edit/Write**. The command points to the shared `agent-workflow` skill, which tells the agent to:

1. Pick the target workspace (`apps/<name>` or `packages/<name>`).
2. Create `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`.
3. Write `1_spec.md` and `2_plan.md`.
4. Add a row to `<workspace>/.agents/artifacts/index.md`.

Example:

```
User: /monorepo-harness-build
Agent:  → creates apps/web/.agents/artifacts/task_2026_08_23_add_login_form/
        → writes 1_spec.md + 2_plan.md
```

### `/monorepo-harness:update` — Check for harness updates

Use `/monorepo-harness:update` when you suspect the harness is out of date or after a release announcement. It reports the installed vs. latest version and asks for consent before upgrading.

## Typical workflow

1. Start a non-trivial task and enter plan mode.
2. Approve the plan. Claude Code normally fires the plan/spec reminder automatically.
3. If the reminder is missed, type `/monorepo-harness-build`.
4. Implement the task, scoped to the target workspace.
5. Verify the work against `1_spec.md`'s "Test / verification plan" — invoke the `verifier` subagent
   (`Task` tool, `subagent_type: verifier`) or run the same commands yourself.
6. Commit your changes.
7. Write `3_memory.md`, and `4_verify.md` (unless the verification plan is `N/A`), in the same task
   directory and update the workspace index — the `Stop` hook will block until both exist.

## Notes

- The automatic reminder and `/monorepo-harness-build` both use the same shared `core/skills/agent-workflow/SKILL.md` instructions.
- The memory-gate is a **hard block** in Claude Code; you cannot end the task until `3_memory.md` exists, and until `4_verify.md` exists too whenever required.
- The `verifier` subagent (`.claude/agents/verifier.md`) is claude-code-specific — opencode/codex have no subagent primitive, so those adapters run the same verification instructions inline in the main session instead (see `PORTABILITY.md`). No capability is lost, just the isolated context.
