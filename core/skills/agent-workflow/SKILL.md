---
name: agent-workflow
description: 4-phase agent workflow — opens a dedicated task directory per task; writes 1_spec.md then 2_plan.md (spec = what/Design before plan = how/Build, per the AI-native SDLC order), and 3_memory.md plus 4_verify.md on task completion (verify only when the spec's Test/verification plan is not N/A), under <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/ where <workspace> is the target app or package (api, web, example-pkg, ...). Driven manually via the stage commands /monorepo-harness-spec, -plan and -build, before implementation starts; also used when the task ends. Each stage stops and waits for the user before the next; implementation never begins before an approved plan.
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
            ├── 0_intent.md                  # optional — only if an approved intent seeded this task
            ├── 1_spec.md                    # the "what" (contract, acceptance criteria) — written first
            ├── 2_plan.md                    # the "how" (implementation plan) — written after the spec
            ├── adr/                         # optional — architecture decisions the spec's
            │   └── NNNN-<title>.md          #   "## Architectural decisions" section links
            ├── 3_memory.md
            └── 4_verify.md
```

```
packages/example-pkg/.agents/artifacts/
└── task_<YYYY_MM_DD>_<slug>/
    ├── 0_intent.md   # optional — see Phase 1
    ├── 1_spec.md     # the "what" (contract) — written first
    ├── 2_plan.md     # the "how" (implementation plan) — written after the spec
    ├── adr/          # optional — see the adr-workflow skill (Phase 1)
    ├── 3_memory.md
    └── 4_verify.md
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

**Important**: All files for one task live in the **same directory**. The numeric prefix (`1_`, `2_`, `3_`, `4_`) indicates phase order — and matches the AI-native SDLC artifact order `intent → spec → plan → memory → verify`, so the **spec (`1_spec.md`) is written before the plan (`2_plan.md`)**. `4_verify.md` is required whenever `1_spec.md`'s "Test / verification plan" section is not `N/A` — see Phase 4.

## Stage commands — one SDLC phase per command

The workflow is driven one stage at a time by dedicated slash commands, each validating its input
before writing anything. Use them in order; a stage refuses to run against a stale or unwarranted
input (see `core/scripts/task-state.sh` for the read-only checks):

| Command | Validates | Writes |
| ------- | --------- | ------ |
| `/monorepo-harness-intent [review]` | — | `<workspace>/.agents/intents/intent_*.md` (`status: pending`, then `approved`) |
| `/monorepo-harness-spec <intent.md?>` | intent **approved** (only when a path is given) | `1_spec.md` (+ `0_intent.md` = copy of the approved intent) |
| `/monorepo-harness-plan <spec.md>` | spec present (`phase: spec`) + plan-mode consent | `2_plan.md` |
| `/monorepo-harness-build <plan.md>` | chain: plan + spec present; intent approved **if** the task is intent-seeded | implementation + `3_memory.md` + `4_verify.md` |

**Intent-approval policy:** an approved intent is mandatory only when a task was seeded by one (i.e.
its directory contains a `0_intent.md`). Ad-hoc tasks (no intent behind them) are exempt — this is
the common case, and `check-chain` treats the absence of `0_intent.md` as valid. `-spec` enforces an
approved intent whenever an intent path is passed to it, and copies that approved intent into the
task dir as `0_intent.md`, so the chain has the evidence it needs downstream.

Each command stub lives in your agent adapter (`.claude/commands/`, `.opencode/commands/`, or a
codex skill) and is purposely thin: it calls the relevant `task-state.sh` check, handles the only
adapter-specific concern (plan-mode detection in `-plan`), then runs the phase below. The writing
templates live here — they are never duplicated into an adapter.

## Phase 1 — `1_spec.md` (via `/monorepo-harness-spec`, or on plan-mode exit)

When plan mode is approved (e.g., `ExitPlanMode` is invoked on Claude Code, or the user runs
`/monorepo-harness-spec <intent.md?>` on any agent), **before the first implementation tool call**,
create the
directory and write `1_spec.md` — the "what": the contract and acceptance criteria. The spec is
written **before** the plan, matching the AI-native SDLC order (`intent → spec → plan`: Design
precedes Build); `2_plan.md` (the "how") then builds against this spec in Phase 2.

**Before writing it**, three checks:

1. **Prior art (mandatory)** — grep `<workspace>/.agents/artifacts/index.md` using 1–3 keywords
   derived from the task. On a match, read that task's `1_spec.md` (and `3_memory.md` if marked ◆)
   and keep its relevance ready to cite in `2_plan.md`'s `## Related prior work` (Phase 2).
2. **Approved intent (via `-spec`, else best-effort)** — when `/monorepo-harness-spec <intent.md>`
   is used, it runs `task-state.sh check-intent-approved`, refuses to write if the intent is not
   approved, and copies the approved intent into the task dir as `0_intent.md`. When the spec is
   written without `-spec` (plan-mode exit), fall back to the best-effort check below: if
   `<workspace>/.agents/intents/` exists, check
   whether an `approved` intent plausibly matches this task (by slug, keywords, or affected files).
   On a match, copy it into the task directory as `0_intent.md` and reference it from `2_plan.md`'s
   `## Problem` (Phase 2). Most ad-hoc tasks have no intent behind them — skip silently if none
   matches or the directory doesn't exist. See `core/skills/intent-workflow/SKILL.md`.
3. **Architecture decisions (via the `adr-workflow` skill)** — while writing `1_spec.md`, fill its
   `## Architectural decisions` section. When it lists one or more decisions, immediately apply
   `core/skills/adr-workflow/SKILL.md` and write the matching `adr/NNNN-<title>.md` files in the
   same pass, **before** moving on to the plan. When the section is `N/A`, create no `adr/` directory.
   Before leaving Phase 1, run
   `bash <bundle>/core/scripts/task-state.sh check-adr <task>/1_spec.md` to confirm every referenced
   ADR exists.

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

## Architectural decisions
<Architecture-affecting decisions this task makes — one bullet per decision, linking the record the
`adr-workflow` skill writes into this task's `adr/` directory (Phase 1, below):
- [0001 - <Title>](adr/0001-<title>.md) — <one-line rationale>
Write "N/A" when the task makes no architecture-affecting decision (see
`core/skills/adr-workflow/SKILL.md` for the threshold).>
```

**After Phase 1, stop and wait.** Once `1_spec.md` is written (and the index updated), **do not**
proceed to Phase 2 or start implementation on your own. Report that the spec is ready and that the
user must run `/monorepo-harness-plan <task_dir>/1_spec.md` next. Implementation may not begin until
an approved plan (`2_plan.md`, `status: approved`) exists — the plan defines the "how" that build
executes against, and it must be user-approved first.

## Phase 2 — `2_plan.md` (via `/monorepo-harness-plan`, before implementation)

`/monorepo-harness-plan <spec.md>` first runs `task-state.sh check-spec` (refusing to write if the
spec is missing/invalid) and checks plan mode: if the agent is not in plan mode it asks "Enable plan
mode?" — on **yes** it enters plan mode, on **no** it proceeds without. Then, in the task directory
created by Phase 1, write `2_plan.md` — the "how" built against the just-written spec; the spec
defines "what", the plan the implementation sketch that an engineer who never saw the conversation
could follow.

**Decisions not yet recorded:** when writing `2_plan.md` surfaces a decision the spec's
`## Architectural decisions` did not record (or the `## Approach` would contradict one), apply the
`adr-workflow` skill and write/amend the `adr/NNNN-*.md` file(s) then, citing them from
`## Approach` — do not defer them to task end.

```markdown
---
phase: plan
date: <YYYY-MM-DD>
slug: <slug>
status: approved
---

# Plan: <Task title>

## Problem
<The problem being solved, 1–3 sentences — reference `0_intent.md` when one seeded the task>

## Approach
<High-level strategy, 2–5 sentences>

## Related prior work
<Cite matches from the Phase 1 prior-art grep as
`- [slug](task_YYYY_MM_DD_slug/1_spec.md) — why relevant`, or `- none found`.>

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

**After Phase 2, stop and wait.** Once `2_plan.md` is written (frontmatter `status: approved`) and
the index updated, **do not** start implementation on your own. Report that the plan is approved and
that the user must run `/monorepo-harness-build <task_dir>/2_plan.md` next. Implementation only
begins when that command gates the plan/spec chain (`task-state.sh check-chain`) successfully.

## Phase 3 — `3_memory.md` (task end / via `/monorepo-harness-build`)

When the task ends, write `3_memory.md` **in the same task directory**. Without it, the memory-gate (agent stop-hook, editor plugin, or git/CI check — depending on your adapter) will not let the task close. `/monorepo-harness-build <plan.md>` runs `task-state.sh check-chain`, then on completion of the implementation **automatically** writes `3_memory.md` (below) and `4_verify.md` (Phase 4) and updates the workspace index — so the memory/verify stages need no separate command.

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
`core/governance/artifacts/AGENTS.md` in the harness bundle for the full indexing rules. The `◆`
marker's meaning is unchanged by Phase 4 below — it still means "plan + memory both present."

## Phase 4 — `4_verify.md` (task end, alongside memory)

Required whenever `1_spec.md`'s "## Test / verification plan" section is **not** `N/A` — i.e.
whenever there was something verifiable to check. Records the *actual* verification run as
evidence, not narration: this is what makes "Verification Before Done" (root `AGENTS.md` Agent
Lifecycle) checkable rather than a self-report. The memory-gate enforces this the same way it
enforces `3_memory.md` (see `core/scripts/memory-gate.sh`); when a spec's verification plan is
`N/A`, `4_verify.md` is not required, mirroring the existing research-only exemption.

If a dedicated `verifier` subagent is available (see `adapters/claude-code/.claude/agents/verifier.md`
for Claude Code; other agents run the same commands inline in the main session — no capability is
lost, see `PORTABILITY.md`), delegate the verification run to it and transcribe its findings here.

```markdown
---
phase: verify
date: <YYYY-MM-DD>
slug: <slug>
---

# Verify: <Task title>

## Verification run
<Command(s) actually executed, verbatim, plus their real output/exit code — evidence, not narration>

## Acceptance criteria results
- [x]/[ ] <criterion copied from 1_spec.md> — <how it was confirmed>

## Deviations
<Any acceptance criterion not met, or verification steps skipped and why>
```

## Slug & directory naming rules

- **Slug**: `snake_case`, only `[a-z0-9_]`, 3–5 words. Decide it in the plan phase and reuse the same directory in later phases.
- **Directory name**: `task_<YYYY_MM_DD>_<slug>` — dashes in the date also become `_` (the `date:` field in frontmatter stays in ISO `YYYY-MM-DD` format).
- If unsure, find the latest directory across all workspaces: `ls -td apps/*/.agents/artifacts/task_* packages/*/.agents/artifacts/task_* | head -1`.

## Edge cases

- **Implementation without plan mode**: Skill is inactive; hooks do not warn. If you are writing the
  plan via `/monorepo-harness-plan`, it will have asked about plan mode first.
- **Plan exists, no implementation (research only)**: Spec and memory can be skipped; plan stays.
- **Un-approved intent or broken chain via the commands**: `-spec`/`-plan`/`-build` refuse to write
  and print the reason from `task-state.sh`; they never silently proceed on a stale input.
- **Spec's verification plan is `N/A`**: `4_verify.md` is not required (mirrors the research-only
  exemption above — nothing verifiable was ever claimed).
- **Updating an existing task directory**: Overwrite files; add a `revisions:` log to `2_plan.md`.
- **Commit requirement**: Memory must be written *after* the commit so `commits:` can be filled in.
  When `/monorepo-harness-build` auto-generates memory/verify, it does so after the implementation
  commits land, so the `commits:` list is populated.
  `4_verify.md` has no such ordering constraint relative to `3_memory.md` — both are required by
  task end, in either order.
- **No matching approved intent**: normal and expected for most tasks — `0_intent.md` is simply
  omitted; nothing warns about this, unlike the mandatory prior-art search above. As long as the
  task dir also has no `0_intent.md`, `task-state.sh check-chain` treats it as a valid ad-hoc task.
- **Architecture-affecting decisions**: capture them in Phases 1–2 via the `adr-workflow` skill, not
  at task end; `3_memory.md` keeps only a one-line pointer to the ADR(s). `task-state.sh check-adr`
  validates every ADR the spec's `## Architectural decisions` section references; a spec without that
  section is treated as "no ADRs declared" (fail-open, so in-flight tasks are never blocked).
