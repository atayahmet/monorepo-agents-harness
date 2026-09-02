# opencode Adapter — User Guide

This adapter wires the harness into **opencode**. Because opencode has no `ExitPlanMode`-style hook, the SDLC is driven manually via the per-stage slash commands `/monorepo-harness-spec`, `/monorepo-harness-plan`, and `/monorepo-harness-build`.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **`/monorepo-harness-spec <intent.md?>`** — create the task directory and write `1_spec.md`, gated on an approved intent when a path is given.
- **`/monorepo-harness-plan <spec.md>`** — write `2_plan.md`, gated on a valid spec, asking about plan mode first.
- **`/monorepo-harness-build <2_plan.md>`** — run the implementation, gated on the full spec/plan/intent chain, then write `3_memory.md` + `4_verify.md`.
- **Universal hard gate** — the git pre-commit / CI version of `core/scripts/memory-gate.sh` blocks commits until `3_memory.md` exists, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement).
- **Automatic ADR capture** — the `adr-workflow` SKILL.md (listed in `opencode.jsonc` `instructions`) fires automatically while `1_spec.md`/`2_plan.md` are written whenever the task makes an architecture-affecting decision, producing `adr/NNNN-<title>.md` records referenced from the spec's `## Architectural decisions` section.
- **Feedback Loop, without a dedicated subagent** — opencode has no subagent primitive, so run your verification commands inline in the main session before writing `4_verify.md`; the underlying instructions are the same ones a `verifier` subagent would follow on Claude Code (see `PORTABILITY.md`).

## Day-to-day commands

### `/monorepo-harness-spec <intent.md?>` — Create the spec

Run it right after you approve a plan and **before the first Edit/Write**. It resolves the target
workspace, and if you pass an intent path it verifies via `core/scripts/task-state.sh` that the
intent is `approved` (refusing to write otherwise) and links it as `0_intent.md` (a reference stub,
not a copy); then writes `1_spec.md` and adds a row to the workspace index. With no path, it creates
a normal ad-hoc spec.

Example:
```
User: /monorepo-harness-spec apps/web/.agents/intents/intent_2026_08_23_add_login_form.md
Agent:  → creates apps/web/.agents/artifacts/task_2026_08_23_add_login_form/
        → writes 0_intent.md + 1_spec.md
```
It **stops** after writing the spec — the agent must not write `2_plan.md` or start implementation
until you run `/monorepo-harness-plan <1_spec.md>`.

### `/monorepo-harness-plan <spec.md>` — Create the plan

Run it after the spec, still **before the first Edit/Write**. It validates the spec via
`task-state.sh check-spec`, then checks plan mode: if you are not in plan mode it asks "Enable plan
mode?" — yes enters plan mode, no proceeds without it. Then it writes `2_plan.md`
(`phase: plan`, `status: approved`) and updates the index. It **stops** there — the agent must not
start implementation until you run `/monorepo-harness-build <2_plan.md>`.

### `/monorepo-harness-build <2_plan.md>` — Implement, then write memory/verify

Run it once your plan is ready. It validates the whole chain via `task-state.sh check-chain` (plan +
spec present, and the intent approved if the task is intent-seeded), then runs the implementation.
On completion it writes `3_memory.md` (with `commits:` filled after the commits) and `4_verify.md`
(whenever the spec's Test/verification plan is not `N/A`), and updates the index.

### Checking for harness updates

There is no `/monorepo-harness-update` command in this adapter. To check or upgrade the harness,
follow the "Update from the repo" prompt in the project README, or run the shared
`core/skills/harness-update/SKILL.md` workflow directly (backed by `core/scripts/harness-update.sh`).

## Typical workflow

1. Start a non-trivial task. Capture an intent (`/monorepo-harness-intent`) and approve it if the
   work is intent-driven; most quick tasks are ad-hoc and skip this.
2. Type `/monorepo-harness-spec` (optionally `<intent.md>` to seed the spec from an approved intent).
   **It stops there** — do not write `2_plan.md` or start implementation until you run the next
   command.
3. Type `/monorepo-harness-plan <1_spec.md>`; approve plan mode when asked. **It stops there** — do
   not start implementation until you run `/monorepo-harness-build`.
4. Type `/monorepo-harness-build <2_plan.md>` to implement the task.
5. `/monorepo-harness-build` writes `3_memory.md` and `4_verify.md` (unless the verification plan is
   `N/A`) and updates the index as it finishes.
6. The git pre-commit hook blocks the commit until `3_memory.md` (and `4_verify.md`, when required) is written.

## Notes

- `/monorepo-harness-spec`/`-plan`/`-build` are the way to drive the SDLC on opencode; there is no automatic plan-mode hook, so each stage is invoked explicitly and validated by `task-state.sh`.
- Memory-gate enforcement is the universal hard gate (`core/scripts/memory-gate.sh`) installed as a git pre-commit hook or CI step; opencode cannot block its own stop.
