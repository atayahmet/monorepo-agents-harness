# monorepo-agents-harness — Agent Guidelines

This repository is the **agent harness template** itself. It produces the bundle that other
monorepo projects install under `.agents/monorepo-agents-harness/`. Treat every change here as a
change to a reusable template, not to a single application.

## Critical Gotchas

1. **This is a template, not an app.** Every file in the bundle may be copied into another repo.
   Do not put project-specific secrets, names, or rules into files that are meant to be installed
   unchanged (e.g. `core/`, adapters, skills, scripts).

2. **Version consistency is mandatory.** When changing the harness, update all of the following
   together:
   - `core/VERSION`
   - `CHANGELOG.md`
   - `changelogs/version-X.Y.Z.md` (the upgrade prompt for that version)
   - Any docs that mention the current version.

3. **`core/root-AGENTS.md` is the installable template.** It is copied to the consuming project's
   root as `AGENTS.md`. Any change to `core/root-AGENTS.md` affects every project that installs the
   harness, so it must be listed in `CHANGELOG.md` and the corresponding `changelogs/version-X.Y.Z.md`.

4. **Keep adapters thin.** Adapters (`adapters/claude-code/`, `adapters/opencode/`, `adapters/codex/`)
   should only contain the minimal wiring each agent needs. They must not duplicate rules that belong
   in `core/root-AGENTS.md` or in skills.

5. **Plan/spec/memory/verify artifact workflow is mandatory for plan-mode tasks.** When you signal
   plan approval, create a per-task directory `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`
   (where `<workspace>` is the primary target: an app under `apps/` or a package under `packages/`,
   or the repo root when neither exists — see Workspace Routing below) containing `1_plan.md`,
   `2_spec.md`, (at task end) `3_memory.md`, and `4_verify.md` (required unless the spec's Test/
   verification plan is `N/A`). Every add/update/delete on a task directory must be reflected in
   that workspace's searchable index `<workspace>/.agents/artifacts/index.md` in the same commit.
   The memory-gate (`core/scripts/memory-gate.sh`) scans every workspace's artifacts dir and blocks
   until today's task dir has `3_memory.md` and (when required) `4_verify.md`.

6. **Always run the narrowest workspace-scoped verification command first.** Use
   `pnpm --filter <workspace>` or `turbo run <task> --filter=<workspace>` before widening scope.

7. **Commits are mandatory at the end of any file-changing task** unless the user explicitly opts out.

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
> `core/workspace-agents-template/` (or run `core/scripts/scaffold-workspace-agents.sh`).

## Core Principles

1. **Simplicity First** — Impact minimal code.
2. **No Laziness** — Find root causes. Senior developer standards.
3. **Minimal Impact** — Only touch what's necessary.
4. **Iterate Rapidly** — Fix immediately, don't get stuck.
5. **Commit on Completion** — Every file-changing task ends with a commit unless the user explicitly opts out.

## Workspace Routing & Execution

This repo has a Turborepo-shaped layout but exists to ship the harness template. Default context is
`apps/<name>` or `packages/<name>` when they exist; otherwise the root.

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
2. **Plan Mode** — Enter for any non-trivial task. Write specs upfront. If something goes sideways, stop and re-plan. The `agent-workflow` skill (`core/skills/agent-workflow/SKILL.md`) produces the plan/spec/memory artifacts.
3. **Subagent Strategy** — Offload research and exploration to subagents. One task per subagent.
4. **Self-Improvement** — After any user correction: (1) update `<target-workspace>/.agents/lessons.md`; (2) if the correction reveals a module-specific rule, update the relevant workspace instruction file so the mistake is not repeated.
5. **Verification Before Done** — Never mark complete without proof. Prefer narrowest scope first.
6. **Demand Elegance** — For non-trivial changes, pause and ask "is there a more elegant way?" Don't over-engineer obvious fixes.
7. **Autonomous Bug Fixing** — Treat bugs as execution tasks: investigate, fix root cause, verify.
8. **Memory / Knowledge Base** — Record durable outcomes in the task's `3_memory.md`; promote recurring architectural decisions or reusable patterns into specs and `lessons.md`.

## Reference Map

| Topic | Rule File |
| ----- | --------- |
| Workspace artifact indexing | `core/governance/artifacts/AGENTS.md` |
| Plan/spec/memory workflow | `core/skills/agent-workflow/SKILL.md` |
| Monorepo guidance | `core/skills/monorepo/SKILL.md` |
| Portability / adapter rules | `adapters/AGENTS.md` |

## Additional Context Locations

- `<workspace>/.agents/` — Per-workspace working state (`session-log.md`, `lessons.md`, `todo.md`)
  plus the task-artifact tree `.agents/artifacts/` (per-task plan/spec/memory dirs + mandatory
  searchable `index.md`). Read before any task targeting that workspace; update the index in the
  same commit as any task-dir change.
- `core/governance/artifacts/AGENTS.md` — Indexing rules for every workspace's
  `.agents/artifacts/index.md`.
- `core/root-AGENTS.md` — The installable root agent-guidelines template copied to consuming
  projects as `AGENTS.md`. Changes here must be propagated and documented per release.
- `core/` — Agent-neutral harness core: skill templates (`skills/`), enforcement scripts (`scripts/`),
  workspace seeds (`workspace-agents-template/`), governance docs (`governance/`).
