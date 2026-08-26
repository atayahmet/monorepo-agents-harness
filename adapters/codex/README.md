# Codex CLI Adapter — User Guide

This adapter wires the harness into **Codex CLI**. Codex toggles plan mode with `/plan` and exposes the `update_plan` tool, so the plan/spec reminder fires after a plan update. The `/monorepo-harness-build` skill provides a manual fallback for the same step.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Plan/spec reminder** — after `update_plan` is called (and at session start), Codex is nudged to create the task directory and write `1_plan.md` + `2_spec.md`.
- **`/monorepo-harness-build`** — a manual fallback skill that triggers the same plan/spec build step. Use it if the automatic reminder is missed.
- **`/monorepo-harness-update`** — compares your installed harness against upstream and upgrades the agent-neutral core with your consent.
- **Memory reminder + universal hard gate** — the `Stop` hook warns if `3_memory.md` or (when required) `4_verify.md` is missing; the git pre-commit / CI gate actually blocks commits.
- **Feedback Loop, without a dedicated subagent** — Codex has no subagent primitive, so run your verification commands inline in the main session before writing `4_verify.md`; the underlying instructions are the same ones a `verifier` subagent would follow on Claude Code (see `PORTABILITY.md`).

## Day-to-day commands

### `/monorepo-harness-build` — Build plan/spec artifacts

Use `/monorepo-harness-build` right after plan approval (or whenever the plan/spec reminder did not fire) and **before the first Edit/Write**. The skill points to the shared `agent-workflow` skill, which tells the agent to:

1. Pick the target workspace (`apps/<name>` or `packages/<name>`).
2. Create `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`.
3. Write `1_plan.md` and `2_spec.md`.
4. Add a row to `<workspace>/.agents/artifacts/index.md`.

Example:

```
User: /monorepo-harness-build
Agent:  → creates apps/web/.agents/artifacts/task_2026_08_23_add_login_form/
        → writes 1_plan.md + 2_spec.md
```

### `/monorepo-harness-update` — Check for harness updates

Use `/monorepo-harness-update` when you suspect the harness is out of date or after a release announcement. It reports the installed vs. latest version and asks for consent before upgrading.

## Typical workflow

1. Start a non-trivial task and enter plan mode with `/plan`.
2. Update/approve the plan. Codex normally fires the plan/spec reminder automatically.
3. If the reminder is missed, type `/monorepo-harness-build`.
4. Implement the task, scoped to the target workspace.
5. Verify the work against `2_spec.md`'s "Test / verification plan" — run the commands it describes
   yourself (Codex has no subagent to delegate this to).
6. Commit your changes.
7. Write `3_memory.md`, and `4_verify.md` (unless the verification plan is `N/A`), in the same task
   directory and update the workspace index.
8. If you try to end the turn without `3_memory.md`/`4_verify.md`, the `Stop` hook warns you; the git pre-commit hook blocks the commit until they are written.

## Notes

- The automatic reminder and `/monorepo-harness-build` both use the same shared `core/skills/agent-workflow/SKILL.md` instructions.
- Codex `Stop` hooks are **soft reminders** only — the real enforcement is the universal hard gate installed as a git pre-commit hook or CI step.
