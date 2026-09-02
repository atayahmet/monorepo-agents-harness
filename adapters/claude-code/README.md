# Claude Code Adapter — User Guide

This adapter wires the harness into **Claude Code**. It gives you an automatic plan/spec reminder when you leave plan mode, a hard memory-gate at task end, and slash commands for each SDLC stage plus harness plumbing.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Automatic plan/spec reminder** — when you exit plan mode (`ExitPlanMode`), Claude Code is nudged to create the task directory and write `1_spec.md` + `2_plan.md` before any implementation.
- **Automatic ADR capture** — the `adr-workflow` skill (symlinked into `.claude/skills/`) fires automatically while `1_spec.md`/`2_plan.md` are written whenever the task makes an architecture-affecting decision (new dependency, data-model or cross-workspace contract change, delivery-guarantee change, …), producing `adr/NNNN-<title>.md` records referenced from the spec's `## Architectural decisions` section.
- **`/monorepo-harness-spec <intent.md?>`** — create the task directory and write `1_spec.md`, gated on an approved intent when a path is given.
- **`/monorepo-harness-plan <spec.md>`** — write `2_plan.md`, gated on a valid spec, asking about plan mode first.
- **`/monorepo-harness-build <2_plan.md>`** — run the implementation, gated on the full spec/plan/intent chain, then write `3_memory.md` + `4_verify.md`.
- **Hard memory-gate** — the `Stop` hook refuses to end the task until today's task directory contains `3_memory.md`, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement).
- **`/monorepo-self-improve`** — harvest recurring patterns from lessons and task memories, then propose durable project-owned rules (`.agents/rules/*.md`) and skills (`.agents/skills/*/SKILL.md`). Requires explicit approval before writing anything.
- **`verifier` subagent** — an isolated, read-only subagent that runs the task's verification commands and reports pass/fail evidence for `4_verify.md`, without touching any files.

## Day-to-day commands

### `/monorepo-harness-spec <intent.md?>` — Create the spec

Use it right after plan approval (or whenever the plan/spec reminder did not fire) and **before the
first Edit/Write**. It resolves the target workspace, and if you pass an intent path it verifies via
`core/scripts/task-state.sh` that the intent is `approved` (refusing to write otherwise) and copies it
as `0_intent.md`; then writes `1_spec.md` and adds a row to the workspace index. With no path, it
creates a normal ad-hoc spec.

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

### `/monorepo-self-improve` — Harvest patterns into project-owned rules and skills

Run it when you have accumulated several tasks and want to turn repeated corrections or workflows
into reusable instructions. It reads every workspace's `lessons.md`, `artifacts/index.md`, and recent
`3_memory.md` files, detects recurring themes, and proposes `.agents/rules/<topic>.md` and
`.agents/skills/<new-skill>/SKILL.md` files plus Reference Map updates. It **stops and asks** before
writing anything; on approval it writes only consumer-owned files and reconciles root `AGENTS.md`.

### Checking for harness updates

There is no `/monorepo-harness:update` command in this adapter. To check or upgrade the harness,
follow the "Update from the repo" prompt in the project README, or run the shared
`core/skills/harness-update/SKILL.md` workflow directly (backed by `core/scripts/harness-update.sh`).

## Typical workflow

1. Start a non-trivial task and enter plan mode. Optionally capture and approve an intent
   (`/monorepo-harness-intent`) if the work is intent-driven.
2. Type `/monorepo-harness-spec` (optionally `<intent.md>` to seed the spec). Claude Code also fires
   the plan/spec reminder automatically on plan-mode exit. **It stops there** — do not write
   `2_plan.md` or start implementation until you run the next command.
3. Type `/monorepo-harness-plan <1_spec.md>`; approve plan mode when asked. **It stops there** — do
   not start implementation until you run `/monorepo-harness-build`.
4. Type `/monorepo-harness-build <2_plan.md>` to implement the task.
5. `/monorepo-harness-build` invokes the `verifier` subagent (or you run the same commands) and writes
   `3_memory.md` and `4_verify.md` (unless the verification plan is `N/A`), updating the index.
6. Commit your changes. The `Stop` hook blocks until `3_memory.md` (and `4_verify.md`, when required) exists.

## Notes

- The automatic reminder and `/monorepo-harness-spec`/`-plan`/`-build` all share the same `core/skills/agent-workflow/SKILL.md` instructions and `core/scripts/task-state.sh` gates. ADRs are validated by `task-state.sh check-adr` before commit and re-checked by the PR-review skill.
- The memory-gate is a **hard block** in Claude Code; you cannot end the task until `3_memory.md` exists, and until `4_verify.md` exists too whenever required.
- The `verifier` subagent (`.claude/agents/verifier.md`) is claude-code-specific — opencode/codex have no subagent primitive, so those adapters run the same verification instructions inline in the main session instead (see `PORTABILITY.md`). No capability is lost, just the isolated context.
