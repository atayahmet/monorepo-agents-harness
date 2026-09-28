# Codex CLI Adapter — User Guide

This adapter wires the harness into **Codex CLI**. Codex toggles plan mode with `/plan` and exposes the `update_plan` tool, so the plan/spec reminder fires after a plan update. The SDLC is driven by the per-stage skills `/monorepo-harness-spec`, `/monorepo-harness-plan`, and `/monorepo-harness-build`.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Plan/spec reminder** — after `update_plan` is called (and at session start), Codex is nudged to create the task directory and write `1_spec.md` + `2_plan.md`.
- **`/monorepo-harness-spec <intent.md?>`** — create the task directory and write `1_spec.md`, gated on an approved intent when a path is given.
- **`/monorepo-harness-plan <spec.md>`** — write `2_plan.md`, gated on a valid spec, asking about plan mode first.
- **`/monorepo-harness-build <2_plan.md>`** — run the implementation, gated on the full spec/plan/intent chain, then write `3_memory.md` + `4_verify.md`.
- **`/monorepo-harness-changeset <2_plan.md>`** — draft a changesets-compatible release entry into `.changeset/` from the task's spec/plan/memory (deterministic filename, revision-based multi-changeset flow), gated on `check-plan` and user-confirmed bumps. No `@changesets/cli` dependency — it consumes your project's own `changeset` CLI later.
- **Memory reminder + universal hard gate** — the `Stop` hook warns if `3_memory.md` or (when required) `4_verify.md` is missing; the git pre-commit / CI gate actually blocks commits.
- **`/monorepo-harness-update`** — check the installed harness version against upstream and, on your consent, upgrade the core and every installed adapter.
- **Automatic ADR capture** — the `adr-workflow` skill (symlinked into `.agents/skills/`, so it also appears in the slash list) fires automatically while `1_spec.md`/`2_plan.md` are written whenever the task makes an architecture-affecting decision, producing `adr/NNNN-<title>.md` records referenced from the spec's `## Architectural decisions` section.
- **`/monorepo-self-improve`** — harvest recurring patterns from lessons and task memories, then propose durable project-owned rules (`.agents/rules/*.md`) and skills (`.agents/skills/*/SKILL.md`). Requires explicit approval before writing anything.
- **`/monorepo-harness-intent-dispatch <intent.md>`** — turn an **approved** intent into scoped work: confirm the workspace scope, split it into 3-5 phases, record your sign-off, ask before filing work the tracker already has open, open one GitHub issue per phase (run inline — Codex has no subagent primitive), then ask whether to merge the intent's PR — writing no spec, plan or task directory. It stops after that answer — each phase is scoped and built separately, starting with `/monorepo-harness-spec <intent.md>`. No credential is ever installed or stored; without `gh` you get paste-ready issue text instead, and an unreachable PR yields an explicit "approval unknown" rather than a merge.
- **Feedback Loop, without a dedicated subagent** — Codex has no subagent primitive, so run your verification commands inline in the main session before writing `4_verify.md`; the underlying instructions are the same ones a `verifier` subagent would follow on Claude Code (see `PORTABILITY.md`).

## Day-to-day commands

### `/monorepo-harness-spec <intent.md?>` — Create the spec

Use it right after plan approval (or whenever the plan/spec reminder did not fire) and **before the
first Edit/Write**. It resolves the target workspace, and if you pass an intent path it verifies via
`core/scripts/task-state.sh` that the intent is `approved` (refusing to write otherwise) and links it
as `0_intent.md` (a reference stub, not a copy); then writes `1_spec.md` and adds a row to the
workspace index. With no path, it creates a normal ad-hoc spec.

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

### `/monorepo-harness-intent-dispatch <intent.md>` — Turn an approved intent into phases and issues

Run it once the intent is `approved`. It checks the approval first — an approving review on the
intent's `pr:` before the file's own `status:` (`task-state.sh check-intent-approved --pr <ref>`) —
and stops on anything else; records the decision on the intent; pushes the approval commit if the
intent names a `pr:`; confirms the workspace scope; and proposes 3-5 phases, where a phase is worth
its own review. After you answer
**"Start these N phases?"** it checks whether that work is **already open** on the tracker
(`tracker-issue.sh --list-open`, read-only) and asks *"create these phases anyway?"* if it finds any,
then opens one GitHub issue per phase (creation is GitHub-only, whatever forge the PR is on). Last, it
asks **"Merge the intent PR (#N) now?"** and merges it only on a yes
(`task-state.sh merge-intent-pr --yes`, which re-checks that the PR really carries an approving review
and merges with a merge commit only). The PR itself does not have to be on GitHub: those reads go
through `core/scripts/forge.sh`, which decides GitHub / GitLab / Bitbucket / Gitea from the PR's own
host and reaches it with that platform's CLI or REST, using a token the project already exports. If
nothing can reach the PR it says the approval is **unknown** and merges nothing — it will not read an
intent file's own `status: approved` in place of a human's decision. Throughout it writes nothing else: no
`task_<date>_<phase_slug>/`, no `0_intent.md`, no `1_spec.md`, no `2_plan.md`, no index row. The phase
scope lives in the issue body, and `/monorepo-harness-spec <intent.md>` is where each phase becomes a
task directory. The platform comes from `<repo-root>/.agents/tracker.md` if you have confirmed it
before; otherwise `tracker-issue.sh --infer` reads this project's `origin` remote and asks you
to confirm it — with a different platform always on the table — and records the answer there. GitHub
Issues via `gh` is the only platform this version implements; `jira` / `linear` are recognized but
need an MCP server or CLI that you install yourself, and any other platform is asked about, never
guessed at. The harness repo is never an issue target.

Then build each phase on its own:
```
/monorepo-harness-build apps/api/.agents/artifacts/task_2026_09_25_auth_endpoint/2_plan.md
```

### `/monorepo-harness-changeset <2_plan.md>` — Draft a changeset release entry

Run it after `-build` when the project uses `changeset` for releases. It validates the plan
(`check-plan`), confirms `.changeset/` exists, proposes packages + bump levels (heuristics only — you
confirm each), shows the draft, and writes it only on your explicit OK. Use `--revision N` for the
second and later changesets from the same plan: each merge of a long-lived plan gets its own changeset
(see the `revisions:` log), and the `v…-alpha.0`/`alpha.1` sequencing is done by the consumer's
`changeset pre` + `changeset version`, never by this command.

### `/monorepo-self-improve` — Harvest patterns into project-owned rules and skills

Run it when you have accumulated several tasks and want to turn repeated corrections or workflows
into reusable instructions. It reads every workspace's `lessons.md`, `artifacts/index.md`, and recent
`3_memory.md` files, detects recurring themes, and proposes `.agents/rules/<topic>.md` and
`.agents/skills/<new-skill>/SKILL.md` files plus Reference Map updates. It **stops and asks** before
writing anything; on approval it writes only consumer-owned files and reconciles root `AGENTS.md`.
A declined, deferred, or partly applied proposal is saved as
`.agents/self-improve-proposals/<YYYY_MM_DD>-<slug>.md` so the finding survives the turn.

### `/monorepo-harness-update` — Check for and apply harness updates

Run it when upstream announces a harness release, or when you suspect your install is out of date. It
applies the paste-in prompt in `core/prompts/harness-update.md` and then follows the shared
`core/skills/harness-update/SKILL.md` workflow end to end: check the installed version, report,
ask **"Upgrade now?"**, then re-run the new release's own installers (`install-harness.sh
--sync-only`, plus `install-adapter.sh codex --refresh`), reconcile the root `AGENTS.md` behind
its own second approval, audit, and clean up. No file is ever copied by hand.

With no adapter installed, paste that same prompt from `core/prompts/harness-update.md` into Codex
instead. The version check alone is
`bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check`.

## Typical workflow

1. Start a non-trivial task and enter plan mode with `/plan`. Optionally capture and approve an
   intent (`/monorepo-harness-intent`) if the work is intent-driven.
2. Type `/monorepo-harness-spec` (optionally `<intent.md>` to seed the spec). Codex also fires the
   plan/spec reminder automatically on `update_plan`. **It stops there** — do not write `2_plan.md`
   or start implementation until you run the next command.
3. Type `/monorepo-harness-plan <1_spec.md>`; approve plan mode when asked. **It stops there** — do
   not start implementation until you run `/monorepo-harness-build`.
4. Type `/monorepo-harness-build <2_plan.md>` to implement the task.
5. `/monorepo-harness-build` writes `3_memory.md` and `4_verify.md` (unless the verification plan is
   `N/A`) and updates the index as it finishes.
6. If the project uses `changeset`, type `/monorepo-harness-changeset <2_plan.md>` to draft the release entry.
7. Commit your changes. If you try to end the turn without `3_memory.md`/`4_verify.md`, the `Stop`
   hook warns you; the git pre-commit hook blocks the commit until they are written.

## Notes

- The automatic reminder and `/monorepo-harness-spec`/`-plan`/`-build` all share the same `core/skills/agent-workflow/SKILL.md` instructions and `core/scripts/task-state.sh` gates.
- Codex `Stop` hooks are **soft reminders** only — the real enforcement is the universal hard gate installed as a git pre-commit hook or CI step.
