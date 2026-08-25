<!--
  TEMPLATE — root AGENTS.md for a Turborepo project using the agent harness.
  This is the SINGLE SOURCE OF TRUTH for agent instructions — every agent reads it natively
  (Claude Code, opencode, Cursor, Codex, ...). Claude Code users additionally get a thin root
  CLAUDE.md that just imports this file (see adapters/claude-code/).
  Resolve the placeholders before use:
    {{PROJECT_NAME}}    -> your monorepo name
    {{PROJECT_GOTCHAS}} -> project-specific rules (architecture/layering/etc.); delete if none
  The "Reference Map" was intentionally trimmed to files this template actually ships. Add rows
  only for `.agents/rules/*.md` you create — never reference a rule file that does not exist.
-->

# {{PROJECT_NAME}} — Agent Guidelines

A Turborepo-managed monorepo with multiple workspaces under `apps/` and `packages/`.

## Critical Gotchas

<!-- {{PROJECT_GOTCHAS}} — replace the example below with your own project rules, or remove. -->
1. **(example) Respect module boundaries.** Cross-module communication goes through a defined public
   port; never import concrete implementations from another module directly.

2. **Always run the narrowest workspace-scoped verification command first.** Use
   `pnpm --filter <workspace>` or `turbo run <task> --filter=<workspace>` before widening scope.

3. **Commits are mandatory at the end of any file-changing task** unless the user explicitly opts out.

4. **Plan/spec/memory artifact workflow is mandatory for plan-mode tasks.** When your agent signals
   plan approval, apply the `agent-workflow` skill templates and create a per-task directory
   `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` (where `<workspace>` is the primary
   target: an app name under `apps/` or a package name under `packages/`) containing `1_plan.md`,
   `2_spec.md`, and (at task end) `3_memory.md`. Every add/update/delete on a task directory must be
   reflected in that workspace's searchable index `<workspace>/.agents/artifacts/index.md` in the
   same commit. The memory-gate (your agent adapter's stop-hook and/or
   `core/scripts/memory-gate.sh` at git pre-commit/CI) scans every workspace's artifacts dir and
   blocks until today's task dir has `3_memory.md`.

## Before You Start — Mandatory Checklist

- [ ] Resolve the **target workspace** (`apps/<name>` or `packages/<name>`) — see Workspace Routing below.
- [ ] Read `<target-workspace>/.agents/session-log.md`, bump version, write an entry — include the session's **artifact dir** path (`<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`).
- [ ] Read `<target-workspace>/.agents/lessons.md`.
- [ ] Write `<target-workspace>/.agents/todo.md` plan.
- [ ] Enter plan mode if task has 3+ steps.
- [ ] All `.md` files must be in English. Code comments and commit messages must be in English.
- [ ] Read this file before implementation, plus the target workspace `AGENTS.md` / `CLAUDE.md` if one exists.

> **Working state is per-workspace.** `session-log.md`, `lessons.md`, and `todo.md` (plus the
> `artifacts/` task tree with its mandatory searchable `index.md`) live under **each**
> `apps/<name>/.agents/` and `packages/<name>/.agents/` — never at the repo root. Always read and
> write the ones belonging to the workspace your task targets. Seed new workspaces from
> `turborepo-agent-harness/core/workspace-agents-template/` (or run
> `turborepo-agent-harness/core/scripts/scaffold-workspace-agents.sh`).

## Core Principles

1. **Simplicity First** — Impact minimal code.
2. **No Laziness** — Find root causes. Senior developer standards.
3. **Minimal Impact** — Only touch what's necessary.
4. **Iterate Rapidly** — Fix immediately, don't get stuck.
5. **Commit on Completion** — Every file-changing task ends with a commit unless the user explicitly opts out.

## Workspace Routing & Execution

This is a Turborepo monorepo. Default context is the repository root.

**Target styles:** `apps/<name>`, `packages/<name>`, workspace package name, or short aliases.

**Before any work:**

1. Resolve the target workspace path.
2. Read local `AGENTS.md` / `CLAUDE.md` inside that workspace if it exists.
3. Apply in order: root `AGENTS.md` → target workspace instructions → user task.
4. Keep changes scoped to the target workspace.
5. Only edit outside the target if: it depends on that package, that package depends on it, the feature spans workspaces, or shared config/tooling must change.

**Execution style:**

- Do not require the user to `cd` into a workspace.
- Prefer the narrowest verification scope first: `pnpm --filter <workspace>` or `turbo run <task> --filter=<workspace>`.
- Expand scope only when dependencies or consumers require it.

**Command-like prompts** (e.g., `/apps/api create endpoint`) are workspace routing metadata, not part of the feature itself.

## Agent Lifecycle

1. **Load Context** — Prioritize technical specs, architecture docs, and recent sessions (`<target-workspace>/.agents/session-log.md`).
2. **Plan Mode** — Enter for any non-trivial task. Write specs upfront. If something goes sideways, stop and re-plan. The `agent-workflow` skill (`core/skills/agent-workflow/SKILL.md` in the harness bundle) produces the plan/spec/memory artifacts.
3. **Subagent Strategy** — Offload research and exploration to subagents. One task per subagent.
4. **Self-Improvement** — After any user correction: (1) update `<target-workspace>/.agents/lessons.md`; (2) if the correction reveals a module-specific rule, update the relevant workspace instruction file so the mistake is not repeated.
5. **Verification Before Done** — Never mark complete without proof. Prefer narrowest scope first.
6. **Demand Elegance** — For non-trivial changes, pause and ask "is there a more elegant way?" Don't over-engineer obvious fixes.
7. **Autonomous Bug Fixing** — Treat bugs as execution tasks: investigate, fix root cause, verify.
8. **Memory / Knowledge Base** — Record durable outcomes in the task's `3_memory.md`; promote recurring architectural decisions or reusable patterns into specs and `lessons.md`.

## Reference Map

Team-specific rule files are optional. Create them under `.agents/rules/*.md` and add a row here for
each one you add. This template ships none — do not link a rule file that does not exist.

| Topic | Rule File |
| ----- | --------- |
| _(add your own rows as you create `.agents/rules/*.md`)_ | |

## Additional Context Locations

- `<workspace>/.agents/` — Per-workspace working state (`session-log.md`, `lessons.md`, `todo.md`)
  plus the task-artifact tree `.agents/artifacts/` (per-task plan/spec/memory dirs + mandatory
  searchable `index.md`). Read before any task targeting that workspace; update the index in the
  same commit as any task-dir change.
- `turborepo-agent-harness/core/governance/artifacts/AGENTS.md` — Indexing rules for every
  workspace's `.agents/artifacts/index.md`.
- `turborepo-agent-harness/core/` — Agent-neutral harness core: skill templates (`skills/`),
  enforcement scripts (`scripts/`), workspace seeds (`workspace-agents-template/`), governance docs
  (`governance/`).
