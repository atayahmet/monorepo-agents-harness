---
name: agent-workflow
description: 4-phase plan/spec/memory/verify agent workflow — opens one directory per plan-mode task at <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/ and writes 1_spec.md ("what", Design) before 2_plan.md ("how", Build) per the AI-native SDLC order, then 3_memory.md plus 4_verify.md on task completion (verify only when the spec's Test/verification plan is not N/A); <workspace> is the target app or package the task touches. Active on every plan-mode task, entered via the agent's plan-mode approval signal or the stage commands /monorepo-harness-spec, /monorepo-harness-plan, /monorepo-harness-build, optionally seeded via /monorepo-harness-intent. Each stage stops and waits for the user before the next; implementation never begins before an approved plan.
---

# Agent Workflow — Per-Task Plan / Spec / Memory Artifacts

This skill requires you to open a separate directory for every plan-mode task and produce the four
artifacts — the spec, plan, memory, and (when applicable) verify files. Your agent adapter's
enforcement layer (hooks, plugins, or the git/CI gate) reminds you; you write the contents. The
five fill-in templates live in `templates/` next to this file — read the one for the phase you are
writing, then create the artifact in the task directory.

**Write in simple English.** Every file and developer message this skill produces follows
`../../governance/rules/simple-english.md` — short sentences, common words, active voice.

## Directory layout

This repo is a monorepo with multiple apps under `apps/` (optionally `packages/`). Artifacts are
partitioned by **workspace** — the app or package the task primarily targets. Each workspace owns
its artifacts **inside its own `.agents/` directory**, next to its working-state files:

```
apps/api/
└── .agents/
    ├── session-log.md / lessons.md / todo.md   # working state (per-workspace)
    └── artifacts/                              # ★ task history for this workspace
        ├── index.md                            # task index for the workspace
        └── task_<YYYY_MM_DD>_<slug>/
            ├── 0_intent.md     # optional — approved-intent reference stub (never a copy)
            ├── 1_spec.md       # the "what" (contract, acceptance criteria) — written first
            ├── 2_plan.md       # the "how" (implementation plan) — written after the spec
            ├── adr/            # optional — decisions the spec's ## Architectural
            │   └── NNNN-<title>.md   #   decisions section links (adr-workflow skill, Phase 1)
            ├── 3_memory.md     # task end
            └── 4_verify.md     # task end, unless the spec's Test/verification plan is N/A
```

`packages/<name>` workspaces use the identical layout under `packages/<name>/.agents/`.

**`<workspace>`** — the target app or package name. Apps use their `apps/<name>` directory name; named
packages under `packages/` use their package directory name. Any existing `apps/*` or `packages/*`
directory in the project is a valid `<workspace>` — resolve it from the files the task actually
touches (see the selection rule below), never from a fixed list.

**`<slug>`** — a `snake_case` (underscored) identifier of 3–5 words summarizing the task. Example directory name: `task_2026_06_03_huawei_webhook_handler/`.

### Workspace selection rule

Pick `<workspace>` from the file paths the task will touch:

- All edits under `apps/api/**` → `api`
- All edits under `apps/web/**` → `web`
- All edits under `packages/example-pkg/**` → `example-pkg`
- Cross-workspace task → pick the **primary** workspace (where the bulk of work happens) and mention the secondary workspace in the plan's "Affected files / modules" section.
- Other `packages/**` changes (shared utilities, root configs, `turbo.json`) → pick the workspace whose consumer is the actual driver; if truly orthogonal, default to `api`.

The memory-gate scans `apps/*/.agents/artifacts/` and `packages/*/.agents/artifacts/` for today's task — placement matters for the gate to find it. It enforces only the tasks that reached the **build** stage; a spec-only or plan-only task can always end. See "Build stage" below.

**Important**: All files for one task live in the **same directory**. The numeric prefix (`1_`, `2_`, `3_`, `4_`) indicates phase order — and matches the AI-native SDLC artifact order `intent → spec → plan → memory → verify`, so the **spec (`1_spec.md`) is written before the plan (`2_plan.md`)**. `4_verify.md` is required whenever `1_spec.md`'s "Test / verification plan" section is not `N/A` — see Phase 4.

## Stage commands — one SDLC phase per command

The workflow is driven one stage at a time by dedicated slash commands, each validating its input
before writing anything. Use them in order; a stage refuses to run against a stale or unwarranted
input (see `core/scripts/task-state.sh` for the checks):

| Command | Validates | Writes |
| ------- | --------- | ------ |
| `/monorepo-harness-intent [review]` | — | `<workspace>/.agents/intents/intent_*.md` (`status: pending`, then `approved`) |
| `/monorepo-harness-spec [<intent.md>] [<phase-number> \| <task-issue-url>]` | intent **approved** (only when a path is given); if the intent lists several tasks, pick one by phase number, link or answer | `1_spec.md` (+ `0_intent.md` = reference stub linking the approved intent; one task per invocation) |
| `/monorepo-harness-plan <spec.md>` | spec present (`phase: spec`) + plan-mode consent | `2_plan.md` |
| `/monorepo-harness-build <plan.md>` | chain: plan + spec present; intent approved **if** the task is intent-seeded | `build_started` on the plan, then for a `red-first` task the failing tests and their recorded output **before** implementation, then implementation (**confined to the spec/plan scope**, see Build scope below) + `3_memory.md` + `4_verify.md` (including `## Red evidence`) + `check-red-evidence` advisory + `kb-ingest.sh <task_dir>` + `check-kb` + a review suggestion (`build-review-tier.sh`, see "After the build" below) |

**Intent-approval policy:** an approved intent is mandatory only when a task was seeded by one (i.e.
its directory contains a `0_intent.md`). Ad-hoc tasks (no intent behind them) are exempt — this is
the common case, and `check-chain` treats the absence of `0_intent.md` as valid. `-spec` enforces an
approved intent whenever an intent path is passed to it, and writes a reference stub linking to that
approved intent as `0_intent.md`, so the chain has the evidence it needs downstream — the intent
file itself stays the single source of truth, never copied.

**Research-only tasks (plan, no implementation):** the `-plan`/`-build` gates above chain a
verifiable implementation (spec → plan → code → memory/verify), so they do **not** apply to
research-only work. A research-only task writes `2_plan.md` **by hand** (`status: approved`) without
`/monorepo-harness-plan` or `/monorepo-harness-build`; it is exempt from `1_spec.md`, `3_memory.md`,
and `4_verify.md` (nothing verifiable was ever claimed). The memory-gate agrees: with no
`build_started` on the plan the task reads as plan-stage and nothing is enforced on it. See Edge
cases.

Each command stub lives in your agent adapter (`.claude/commands/`, `.opencode/commands/`, or a
codex skill) and is purposely thin: it calls the relevant `task-state.sh` check, handles the only
adapter-specific concern (plan-mode detection in `-plan`), then runs the phase below. The writing
templates live here in `templates/` — they are never duplicated into an adapter.

## Tiered red-first rule (issue #46)

Choose the tier in Phase 1 and put it on the first line of the spec's `## Test / verification plan`:

- `Tier: red-first`
- `Tier: evidence-only`

| Kind of work | Tier | Rule |
| ------------ | ---- | ---- |
| Bug fix | `red-first` | Write a test that reproduces the bug. Watch it fail. Then fix. Required. |
| New behavior with a clear contract (API, domain logic, CLI) | `red-first` | Turn the acceptance criteria into scenario tests. Watch them fail. Then implement. |
| UI / config / glue / exploration | `evidence-only` | No test-first rule. Manual or browser evidence is enough. |

**Red-first in the plan and build.** For a `red-first` task, `2_plan.md`'s `## Steps` lists one
failing test → implementation pair per acceptance criterion. `/monorepo-harness-build` writes the
test first, runs it, and records the verbatim failure **before** touching implementation files. The
failure must match the expected behavior, not an import, compilation or setup error. The recorded
output goes in `4_verify.md`'s `## Red evidence`.

**Fallback.** If red was not captured first, or the test changed after red was seen, save your work
(a diff or stash), revert **only** the fix, rerun the test, and record that failure as the
after-the-fact negative check in `## Red evidence`. Restore your work afterwards; never discard
unrelated uncommitted changes.

**Advisory only.** After `4_verify.md` is written, run
`bash <bundle>/core/scripts/task-state.sh check-red-evidence <task_dir>`. It prints a warning when a
`red-first` task has no `## Red evidence` content and **always exits 0**. A spec with no tier line is
a legacy task: it produces no warning and stays valid, because the check may read that the section
exists but cannot prove the test really ran first. Do not turn this into a hard gate without evidence
from real tasks.

## Phase 1 — `1_spec.md` (via `/monorepo-harness-spec`, or on plan-mode exit)

When plan mode is approved (e.g., `ExitPlanMode` is invoked on Claude Code, or the user runs
`/monorepo-harness-spec <intent.md?>` on any agent), **before the first implementation tool call**,
create the directory and write `1_spec.md` — the "what": the contract and acceptance criteria. The
spec is written **before** the plan, matching the AI-native SDLC order (`intent → spec → plan`:
Design precedes Build); `2_plan.md` (the "how") then builds against this spec in Phase 2.

**Before writing it**, four checks:

1. **Query the knowledge base first (mandatory)** — run
   `bash <bundle>/core/scripts/kb-index.sh query "<1–3 keywords>"` over the repo-root `knowledge/`
   (BM25-ranked; grep fallback when `sqlite3`/FTS5 is unavailable) and read the top pages it ranks.
   Keep their `[[wiki-link]]`s ready to cite in `2_plan.md`'s `## Related prior work` (Phase 2), as a
   `- KB:` line — `- KB: [[<page>]] (knowledge/…)` for hits, or `- KB: no relevant pages` for none.
   That line is the recorded trace that this query happened (issue #32). See
   `core/skills/knowledge-base/SKILL.md`.
2. **Prior art in the task indexes (mandatory)** — grep `<workspace>/.agents/artifacts/index.md` with
   the same keywords for anything the knowledge base does not cover. On a match, read that task's
   `1_spec.md` (and `3_memory.md` if marked ◆) and keep its relevance ready to cite in `2_plan.md`'s
   `## Related prior work` (Phase 2). When the task creates a **new workspace** that has no index yet,
   grep every existing workspace index instead
   (`cat apps/*/.agents/artifacts/index.md packages/*/.agents/artifacts/index.md`); for a
   **cross-cutting** task, also grep the sibling workspace indexes. When the project has no `apps/` or
   `packages/` (the workspace is the repo root), the index is `.agents/artifacts/index.md`.
3. **Approved intent (via `-spec`, else best-effort)** — `/monorepo-harness-spec` accepts
   `[<intent.md>] [<phase-number> | <task-issue-url>]`. An intent is a **seed reference**, not a task: one
   dispatched intent may be split into several phases/issues. A spec always covers **exactly one
   task** and, when seeded by an approved intent, must be linked back via `0_intent.md`.
   - **If a phase number is given** (a positive integer): it is the **1-based position** of a phase in
     the `Phases:` list of the intent's **newest `## Dispatch` block**. A number only means something
     inside one intent, so an intent is required: use the path given, else the single approved intent
     that has a `## Dispatch` block under `<workspace>/.agents/intents/` — if there are none or several,
     ask which intent, never guess. Run `task-state.sh check-intent-approved <intent.md>` (refuse if not
     approved). A number outside the list writes nothing and reports "Phase N not found — newest
     Dispatch block lists M phases (1–M)". Take the phase's tracker key from its line and run
     `bash <bundle>/core/scripts/tracker-issue.sh --show <key>` to read the issue. A line reading
     `no issue yet (<reason>)`, or a failed read (exit 3), leaves no scope to read: ask the user what
     the spec covers — never guess. Write the spec for that single task only, creating `0_intent.md`
     via `write-intent-ref.sh`.
   - **If a task link is given:** run `bash <bundle>/core/scripts/tracker-issue.sh --show <task-issue-url>`
     (GitHub via `gh`, exit 3 handoff otherwise). Find which **approved intent** contains that issue
     in its **newest `## Dispatch` block** (`#<number>` or URL). If no intent path was provided,
     search `<workspace>/.agents/intents/` for an approved intent whose newest `## Dispatch` block
     lists it; if none or multiple match, ask the user **which task this spec covers** and which
     intent to use — never guess. Run `task-state.sh check-intent-approved <intent.md>` (refuse if
     not approved). Match the issue to the phase/slug and write the spec for that single task only,
     creating `0_intent.md` via `write-intent-ref.sh`. If there is no match or the read fails (exit
     3), ask which task this spec covers and its scope — never guess.
   - **If an intent path is given without a phase number or task link:** run `task-state.sh check-intent-approved`,
     refuse to write if it is not approved, and **if the newest `## Dispatch` block lists more than one
     phase/task, stop and ask "This intent has several tasks — which task should this spec cover?"**
     (show each phase's number, slug and issue link; the user can answer with the number). Do **not** create multiple task directories or write multiple
     specs in one invocation. If exactly one phase exists or there is no `## Dispatch` block,
     proceed for that task and write a reference stub linking to the approved intent as `0_intent.md`
     (never a copy of its content, so the intent file stays the single source of truth).
   - **Plan-mode exit / no `-spec`:** fall back to the best-effort check below: if
     `<workspace>/.agents/intents/` exists, check whether an `approved` intent plausibly matches this
     task (by slug, keywords, or affected files). On a match, write the same reference stub into the
     task directory as `0_intent.md`, include `intent: 0_intent.md` in the spec frontmatter, and
     reference it from `2_plan.md`'s `## Problem` (Phase 2). Most ad-hoc tasks have no intent behind
     them — omit the `intent:` frontmatter line and skip silently if none matches or the directory
     doesn't exist. See `core/skills/intent-workflow/SKILL.md`.

   To avoid copying the intent by mistake, generate this stub mechanically with
   `bash <bundle>/core/scripts/write-intent-ref.sh <task_dir> <intent.md>`. The script validates that
   the intent is approved, computes the relative `source:` path, and writes `0_intent.md` (pattern:
   `templates/0_intent_ref.md`).
4. **Architecture decisions (via the `adr-workflow` skill)** — while writing `1_spec.md`, fill its
   `## Architectural decisions` section. When it lists one or more decisions, immediately apply
   `core/skills/adr-workflow/SKILL.md` and write the matching `adr/NNNN-<title>.md` files in the
   same pass, **before** moving on to the plan. When the section is `N/A`, create no `adr/` directory.
   Before leaving Phase 1, run
   `bash <bundle>/core/scripts/task-state.sh check-adr <task>/1_spec.md` to confirm every referenced
   ADR exists.

**Template:** `templates/1_spec.md` — fill it into `<task_dir>/1_spec.md`. The guide text inside
each section is normative; the `intent:` frontmatter line only when the task is intent-seeded.

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

**Record the prior-art query (required):** the `## Related prior work` section must open with the
Phase 1 knowledge-base trace — a `- KB:` line naming the pages the query returned, or
`- KB: no relevant pages` for none — before the task-dir citations (or `- none found`). This is the
only recorded evidence that the mandatory Phase 1 query happened; `task-state.sh check-plan` and
`check-chain` print an advisory (never a failure) when the line is missing.

**Template:** `templates/2_plan.md` — fill it into `<task_dir>/2_plan.md` with `status: approved`.
For a `red-first` spec, order `## Steps` as failing test → implementation pairs (see "Tiered
red-first rule" above).

**After Phase 2, stop and wait.** Once `2_plan.md` is written (frontmatter `status: approved`) and
the index updated, **do not** start implementation on your own. Report that the plan is approved and
that the user must run `/monorepo-harness-build <task_dir>/2_plan.md` next. Implementation only
begins when that command gates the plan/spec chain (`task-state.sh check-chain`) successfully.
Stopping here is a legal end to a turn: the task is in the plan stage, and the memory-gate does not
enforce memory/verify on a plan-stage task (see "Build stage" below).

## Build scope — `-build` implements the approved artifacts, nothing else

`/monorepo-harness-build <2_plan.md>` runs the implementation for the approved task. The
implementation is **confined to the boundaries the approved artifacts already declare**:

- `1_spec.md` — `## Scope` and `## Acceptance criteria`
- `2_plan.md` — `## Affected files / modules` (and its `## Steps` sketch)

Hard rules:

1. Create or modify **only** the files, apps, and packages those sections list. Never scaffold a new
   workspace, app, package, or file that the plan does not name — `-build` implements the approved
   plan, it does not invent scope.
2. If a step reveals that something outside that scope is genuinely required, **stop implementing**
   and report to the user. Only after approval, extend `1_spec.md`'s `## Scope` and `2_plan.md`'s
   `## Affected files / modules` (append a `revisions:` log entry to the plan) and resume.
3. Any file, app, or package touched that is not in those lists is a scope violation — treat it like a
   broken gate: do not paper it over, surface it and stop.

## Build stage — how the memory-gate knows a task is being built

The memory-gate only enforces a task that reached the build stage, and it learns that from one field
on one file: `build_started: <ISO-8601>` in the plan's frontmatter. Write it with the script, never
by hand:

```bash
bash <bundle>/core/scripts/task-state.sh mark-build <task_dir>/2_plan.md
```

- `/monorepo-harness-build` runs this as its first step, so the ordinary path is armed by the command
  itself. It is **write-once**: a re-run leaves the first timestamp, so "when the build started"
  cannot be rewritten by running the command again.
- `task-state.sh stage <task_dir>` is the reader. It answers `none` / `spec` / `plan` / `build`, and
  the gate asks it — there is one answer to "which stage is this?", not two.
- **Implementation that starts without `-build`** (leaving plan mode writes the spec and plan, then
  edits code) is armed by the adapter's write hook, `core/scripts/hook-arm-build.sh`, on the first
  write outside the task-artifacts directory. An adapter without such a hook names the `mark-build`
  command in its plan-mode reminder instead (`PORTABILITY.md` records which). Either way, run the
  command yourself if you are starting implementation by hand.

**Never** add `build_started` to a plan by hand, and never edit or remove it: it is the record that
distinguishes "the build is running" from "the build has not started", and hand-editing it turns the
memory-gate into a comment.

## Phase 3 — `3_memory.md` (task end / via `/monorepo-harness-build`)

When the task ends, write `3_memory.md` **in the same task directory**. Without it, the memory-gate
(agent stop-hook, editor plugin, or git/CI check — depending on your adapter) will not let a
build-stage task close. `/monorepo-harness-build <plan.md>` runs `task-state.sh check-chain`, then on completion of
the implementation **automatically** writes `3_memory.md` (below) and `4_verify.md` (Phase 4) and
updates the workspace index — so the memory/verify stages need no separate command.

**Template:** `templates/3_memory.md` — filled into `<task_dir>/3_memory.md` by `-build`, or by hand
on other paths.

**Knowledge-base ingest (same commit):** after `3_memory.md` / `4_verify.md` / `adr/` are written,
`-build` runs `core/scripts/kb-ingest.sh <task_dir>` and verifies with `task-state.sh check-kb
<task_dir>` so the task's durable outcomes land in the repo-root `knowledge/` layer in the same
commit (Karpathy "LLM Wiki" pattern — see `core/skills/knowledge-base/SKILL.md`). Research-only /
`N/A` tasks (no `3_memory.md`) skip this cleanly; `check-kb` requires the KB to be seeded first
(`core/scripts/scaffold-knowledge.sh`).

**Do not write**: what the code does (the code already says so), summaries derivable from the commit
list, ephemeral task details.

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

For a `red-first` task, `4_verify.md` also carries `## Red evidence`: the verbatim failure captured
before implementation (or the after-the-fact negative check described in "Tiered red-first rule").
`-build` runs `task-state.sh check-red-evidence <task_dir>` after writing it. The check is advisory
and always exits 0; it never blocks the task.

**Template:** `templates/4_verify.md` — filled into `<task_dir>/4_verify.md`.

## After the build — suggest a review (advisory)

Issue #41: when `/monorepo-harness-build` finishes (after `3_memory.md` / `4_verify.md` / `kb-ingest`),
point the developer at `/monorepo-harness-review`. The strength of that point is **not** the model's
free judgement — run the deterministic helper and follow its first output line:

```bash
bash <bundle>/core/scripts/build-review-tier.sh <task_dir>
```

- **`simple`** (≤3 changed files **and** no architectural signal) — add one informational line to the
  closing report: the developer may run `/monorepo-harness-review` to review the diff. Also mention
  `/monorepo-harness-security-review` as an optional deeper security review if desired. Do **not** ask.
- **`comprehensive`** (more files, or an architectural signal: an `adr/` file, or a non-`N/A`
  `## Architectural decisions` / `## API / contracts` / `## Data model` section) — ask the developer
  whether to run reviews now. Offer both `/monorepo-harness-review` (`pr-review` skill) and
  `/monorepo-harness-security-review` (`security-review` skill). On **yes**, run the chosen review(s)
  inline and report their findings; on **no**, finish normally.

This step is **advisory**: it never blocks a task from closing, never writes a file, and never runs a
review without the developer's choice. The reviews are report-only — see
`core/skills/pr-review/SKILL.md` and `core/skills/security-review/SKILL.md`.

## Slug & directory naming rules

- **Slug**: `snake_case`, only `[a-z0-9_]`, 3–5 words. Decide it in the plan phase and reuse the same directory in later phases.
- **Directory name**: `task_<YYYY_MM_DD>_<slug>` — dashes in the date also become `_` (the `date:` field in frontmatter stays in ISO `YYYY-MM-DD` format).
- If unsure, find the latest directory across all workspaces: `ls -td apps/*/.agents/artifacts/task_* packages/*/.agents/artifacts/task_* | head -1`. Note that `ls -t` orders by file modification time, which is not the task's age — a dir touched today by an unrelated edit sorts first. When the choice is between two dirs dated the same day, `ls -t` is the right tie-break; when the dates differ, the date in the name is authoritative (`memory-gate.sh` and `hook-arm-build.sh` share `harness_task_dirs_newest_first` in `core/scripts/harness-common.sh` for exactly this).

## Edge cases

- **Implementation without plan mode**: Skill is inactive; hooks do not warn. If you are writing the
  plan via `/monorepo-harness-plan`, it will have asked about plan mode first.
- **Ending the turn at a stage boundary**: stopping after Phase 1 or Phase 2 is normal and must not be
  blocked. The task has no `build_started`, so the gate has nothing to enforce. It blocks at most once
  per stop anyway — a hook that already blocked sees `stop_hook_active: true` and stands down.
- **Plan exists, no implementation (research only)**: see "Research-only tasks" in Stage commands —
  plan written **by hand** (`status: approved`) outside `-plan`/`-build`; spec, memory, and verify
  are skipped (nothing verifiable was ever claimed), and the gate enforces nothing on the task.
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
- **A rewritten history**: a `commits:` sha is a name a commit has on one branch, so a rebase, a squash
  or a force-push leaves it pointing at nothing while the change itself survives. Write
  `patch_ids:` alongside `commits:` (see `templates/3_memory.md`) — a `git patch-id --stable` value
  is the identity of the change, not of the history. To repair an existing memory:
  `bash <bundle>/core/scripts/task-state.sh sync-commits <task_dir>/3_memory.md [--ref <branch>] --write`
  — a dry run without `--write`, `--ref` defaults to `origin/HEAD`, then `main`, then `master`, and a
  sha it cannot map by content is left alone and reported rather than guessed. The memory-gate does not
  require `patch_ids:`, so a memory written before this field existed stays valid.
- **No matching approved intent**: normal and expected for most tasks — `0_intent.md` is simply
  omitted; nothing warns about this, unlike the mandatory prior-art search above. As long as the
  task dir also has no `0_intent.md`, `task-state.sh check-chain` treats it as a valid ad-hoc task.
- **Architecture-affecting decisions**: capture them in Phases 1–2 via the `adr-workflow` skill, not
  at task end; `3_memory.md` keeps only a one-line pointer to the ADR(s). `task-state.sh check-adr`
  validates every ADR the spec's `## Architectural decisions` section references; a spec without that
  section is treated as "no ADRs declared" (fail-open, so in-flight tasks are never blocked).
- **No `- KB:` line in the plan**: `check-plan`/`check-chain` print an advisory (never a failure) and
  the reviewer raises a Nit. A plan written before this convention, or a **spec-only** task with no
  plan, is never blocked — the check is a visibility aid, not a gate.
- **Spec has no tier line (legacy task)**: `check-red-evidence` stays silent and exits 0. Existing
  task dirs written before issue #46 keep passing every gate unchanged.
- **`red-first` task with missing or empty `## Red evidence`**: `check-red-evidence` prints an
  advisory and exits 0. Nothing is blocked; the build's own `4_verify.md` is still required by the
  memory-gate when the verification plan is not `N/A`.