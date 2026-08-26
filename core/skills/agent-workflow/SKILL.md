---
name: agent-workflow
description: 3-phase agent workflow — opens a dedicated task directory per task; writes 1_plan.md and 2_spec.md on plan approval, and 3_memory.md on task completion, under <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/ where <workspace> is the target app or package (api, web, example-pkg, ...). Triggered automatically when exiting plan mode, or manually via /monorepo-harness-build, before implementation starts; also used when the task ends.
---

# Agent Workflow — Per-Task Plan / Spec / Memory Artifacts

This skill requires you to open a separate directory for every plan-mode task and produce three markdown files. Your agent adapter's enforcement layer (hooks, plugins, or the git/CI gate) reminds you; you write the contents.

## Directory layout

This repo is a monorepo with multiple apps under `apps/` (optionally `packages/`). Artifacts are
partitioned by **workspace** — the app or package the task primarily targets. Each workspace owns
its artifacts **inside its own `.agents/` directory**, next to its working-state files:

```
apps/api/
└── .agents/
    ├── session-log.md                       # working state (per-workspace)
    ├── lessons.md / todo.md
    └── artifacts/                           # ★ task history for this workspace
        ├── index.md                         # task index for the workspace
        └── task_<YYYY_MM_DD>_<slug>/
            ├── 1_plan.md
            ├── 2_spec.md
            └── 3_memory.md
```

```
packages/example-pkg/.agents/artifacts/
└── task_<YYYY_MM_DD>_<slug>/
    ├── 1_plan.md
    ├── 2_spec.md
    └── 3_memory.md
```

**`<workspace>`** — the target app or package name. Apps use their `apps/<name>` directory name; named packages under `packages/` use their package directory name. Current workspaces: `api`, `web`, `example-pkg`.

**`<slug>`** — a `snake_case` (underscored) identifier of 3–5 words summarizing the task. Example directory name: `task_2026_06_03_huawei_webhook_handler/`.

### Workspace selection rule

Pick `<workspace>` from the file paths the task will touch:

- All edits under `apps/api/**` → `api`
- All edits under `apps/web/**` → `web`
- All edits under `packages/example-pkg/**` → `example-pkg`
- Cross-workspace task → pick the **primary** workspace (where the bulk of work happens) and mention the secondary workspace in the plan's "Affected files / modules" section.
- Other `packages/**` changes (shared utilities, root configs, `turbo.json`) → pick the workspace whose consumer is the actual driver; if truly orthogonal, default to `api`.

The memory-gate scans `apps/*/.agents/artifacts/` and `packages/*/.agents/artifacts/` for today's task — placement matters for the gate to find it.

**Important**: All three files for one task live in the **same directory**. The numeric prefix (`1_`, `2_`, `3_`) indicates phase order.

## Phase 1 — `1_plan.md` (after plan approval or `/monorepo-harness-build`)

When plan mode is approved (e.g., `ExitPlanMode` is invoked on Claude Code, or the user runs `/monorepo-harness-build` on any agent), **before the first implementation tool call**, create the directory and write `1_plan.md`.

**Before writing it**, search for prior art: grep `<workspace>/.agents/artifacts/index.md` using
1–3 keywords derived from the task. On a match, read that task's `2_spec.md` (and `3_memory.md` if
marked ◆) and summarize its relevance in the `## Related prior work` section below.

```markdown
---
phase: plan
date: <YYYY-MM-DD>
slug: <slug>
status: approved
---

# Plan: <Task title>

## Problem
<The problem being solved, 1–3 sentences>

## Approach
<High-level strategy, 2–5 sentences>

## Related prior work
<Grep `<workspace>/.agents/artifacts/index.md` for related keywords. List matches as
`- [slug](task_YYYY_MM_DD_slug/2_spec.md) — why relevant`, or `- none found`.>

## Steps
1. ...
2. ...

## Affected files / modules
- ...

## Risks & assumptions
- ...

## Definition of done
- [ ] ...
```

## Phase 2 — `2_spec.md` (before implementation starts)

Immediately after the plan file, **before the first Edit/Write call**, write `2_spec.md` in the same directory. The spec is the declarative/contractual counterpart of the plan — the plan says "how", the spec defines "what".

```markdown
---
phase: spec
date: <YYYY-MM-DD>
slug: <slug>
---

# Spec: <Task title>

## Scope
<The boundaries of this change — what is included, what is excluded>

## Behavioral contract
- Input: ...
- Output: ...
- Side effects: ...

## API / contracts
<Endpoints, function signatures, event payloads — changing contracts>

## Data model
<Fields/types/structure of any persisted or transmitted data this task reads or writes —
table/column names, JSON payload shape, event schema. Write "N/A" if no data model is touched.>

## Acceptance criteria
- [ ] ...

## Test / verification plan
<How each acceptance criterion above is checked — command, test file, or manual repro steps.
Write "N/A" only for research-only tasks with no verifiable behavior change.>

## Architectural constraints
<Layer rules, module boundaries, and non-functional requirements (performance, security,
compatibility) — consistent with root AGENTS.md gotchas>
```

## Phase 3 — `3_memory.md` (task end / Stop)

When the task ends, write `3_memory.md` **in the same task directory**. Without it, the memory-gate (agent stop-hook, editor plugin, or git/CI check — depending on your adapter) will not let the task close.

```markdown
---
phase: memory
date: <YYYY-MM-DD>
slug: <slug>
commits: [<sha1>, <sha2>]
---

# Memory: <Task title>

## What was done (single paragraph)
<Outcome, 2–4 sentences>

## Surprising findings
<Facts not foreseen during planning — code, system, behavior>

## If I did it again
<What you would do differently, or an approach worth repeating. Knowledge worth preserving.>

## Related decisions
<Decisions made and their reasons — so future readers know why it was done this way>
```

**Do not write**: what the code does (the code already says so), summaries derivable from the commit list, ephemeral task details.

**Index update (mandatory, same commit):** every task-dir change must be reflected in
`<workspace>/.agents/artifacts/index.md` — new dir → new row; `3_memory.md` written → append `◆`.
Keep rows greppable: fixed columns, stable slug, concrete identifiers in a ≤10-word summary. See
`core/governance/artifacts/AGENTS.md` in the harness bundle for the full indexing rules.

## Slug & directory naming rules

- **Slug**: `snake_case`, only `[a-z0-9_]`, 3–5 words. Decide it in the plan phase and reuse the same directory in later phases.
- **Directory name**: `task_<YYYY_MM_DD>_<slug>` — dashes in the date also become `_` (the `date:` field in frontmatter stays in ISO `YYYY-MM-DD` format).
- If unsure, find the latest directory across all workspaces: `ls -td apps/*/.agents/artifacts/task_* packages/*/.agents/artifacts/task_* | head -1`.

## Edge cases

- **Implementation without plan mode**: Skill is inactive; hooks do not warn.
- **Plan exists, no implementation (research only)**: Spec and memory can be skipped; plan stays.
- **Updating an existing task directory**: Overwrite files; add a `revisions:` log to `1_plan.md`.
- **Commit requirement**: Memory must be written *after* the commit so `commits:` can be filled in.
