# opencode Adapter — User Guide

This adapter wires the harness into **opencode**. Because opencode has no `ExitPlanMode`-style hook, the plan/spec build step is triggered manually via the `/monorepo-harness-build` slash command.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **`/monorepo-harness-build`** — manually create the task directory and write `1_spec.md` + `2_plan.md` before implementation.
- **`/monorepo-harness-update`** — compare your installed harness against upstream and upgrade the agent-neutral core with your consent.
- **Universal hard gate** — the git pre-commit / CI version of `core/scripts/memory-gate.sh` blocks commits until `3_memory.md` exists, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement).
- **Feedback Loop, without a dedicated subagent** — opencode has no subagent primitive, so run your verification commands inline in the main session before writing `4_verify.md`; the underlying instructions are the same ones a `verifier` subagent would follow on Claude Code (see `PORTABILITY.md`).

## Day-to-day commands

### `/monorepo-harness-build` — Build plan/spec artifacts

Use `/monorepo-harness-build` right after you approve a plan and **before the first Edit/Write**. The command points to the shared `agent-workflow` skill, which tells the agent to:

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

### `/monorepo-harness-update` — Check for harness updates

Use `/monorepo-harness-update` when you suspect the harness is out of date or after a release announcement. It reports the installed vs. latest version and asks for consent before upgrading.

## Typical workflow

1. Start a non-trivial task and create your plan.
2. Once the plan is approved, type `/monorepo-harness-build`.
3. Implement the task, scoped to the target workspace.
4. Verify the work against `1_spec.md`'s "Test / verification plan" — run the commands it describes
   yourself (opencode has no subagent to delegate this to).
5. Commit your changes.
6. Write `3_memory.md`, and `4_verify.md` (unless the verification plan is `N/A`), in the same task
   directory and update the workspace index.
7. The git pre-commit hook blocks the commit until `3_memory.md` (and `4_verify.md`, when required) is written.

## Notes

- `/monorepo-harness-build` is the primary way to start the plan/spec build on opencode; there is no automatic plan-mode hook.
- Memory-gate enforcement is the universal hard gate (`core/scripts/memory-gate.sh`) installed as a git pre-commit hook or CI step; opencode cannot block its own stop.
