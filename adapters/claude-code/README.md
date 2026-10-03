# Claude Code Adapter — User Guide

This adapter wires the harness into **Claude Code**. It gives you an automatic plan/spec reminder when you leave plan mode, a hard memory-gate at task end, and slash commands for each SDLC stage plus harness plumbing.

> **Installing the adapter?** See [INSTALL.md](INSTALL.md) for copy-paste setup steps.

## What you get

- **Automatic plan/spec reminder** — when you exit plan mode (`ExitPlanMode`), Claude Code is nudged to create the task directory and write `1_spec.md` + `2_plan.md` before any implementation.
- **Automatic ADR capture** — the `adr-workflow` skill (symlinked into `.claude/skills/`) fires automatically while `1_spec.md`/`2_plan.md` are written whenever the task makes an architecture-affecting decision (new dependency, data-model or cross-workspace contract change, delivery-guarantee change, …), producing `adr/NNNN-<title>.md` records referenced from the spec's `## Architectural decisions` section.
- **`/monorepo-harness-spec <intent.md?>`** — create the task directory and write `1_spec.md`, gated on an approved intent when a path is given.
- **`/monorepo-harness-plan <spec.md>`** — write `2_plan.md`, gated on a valid spec, asking about plan mode first.
- **`/monorepo-harness-build <2_plan.md>`** — run the implementation, gated on the full spec/plan/intent chain, then write `3_memory.md` + `4_verify.md`.
- **`/monorepo-harness-changeset <2_plan.md>`** — draft a changesets-compatible release entry into `.changeset/` from the task's spec/plan/memory (deterministic filename, revision-based multi-changeset flow), gated on `check-plan` and user-confirmed bumps. No `@changesets/cli` dependency — it consumes your project's own `changeset` CLI later.
- **Hard memory-gate** — once a task's build has started, the `Stop` hook refuses to end it until the task directory contains `3_memory.md`, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement). The build start is recorded as `build_started` on `2_plan.md`, so a spec-only or plan-only task ends without a block, and the hook stands down (`stop_hook_active`) instead of looping when it has already blocked once.
- **Gate arming on plan-mode exit** — a `PreToolUse` hook on file writes runs `hook-arm-build.sh`, which records `build_started` on the first write outside `.agents/` that belongs to a workspace that has a plan-only task from today (a task that already wrote `3_memory.md` is left alone). Implementation that starts right out of plan mode, without `/monorepo-harness-build`, is therefore still gated.
- **`/monorepo-harness-update`** — check the installed harness version against upstream and, on your consent, upgrade the core and every installed adapter.
- **`/monorepo-self-improve`** — harvest recurring patterns from lessons and task memories, then propose durable project-owned rules (`.agents/rules/*.md`) and skills (`.agents/skills/*/SKILL.md`). Requires explicit approval before writing anything.
- **`/monorepo-harness-intent-dispatch <intent.md>`** — turn an **approved** intent into scoped work: confirm the workspace scope, split it into 3-5 phases, record your sign-off, ask before filing work the tracker already has open, ask whether 2+ phases should be grouped under one parent epic issue (a single phase gets none), open the epic and file every phase as its sub-issue via the `tracker` subagent, record the keys back on the intent, then ask whether to merge the intent's PR — writing no spec, plan or task directory. It stops after that answer — each phase is scoped and built separately, starting with `/monorepo-harness-spec <intent.md>`. No credential is ever installed or stored; without `gh` you get paste-ready issue text instead, and an unreachable PR yields an explicit "approval unknown" rather than a merge.
- **`verifier` subagent** — an isolated, read-only subagent that runs the task's verification commands and reports pass/fail evidence for `4_verify.md`, without touching any files.

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
(`tracker-issue.sh --list-open`, read-only) and asks *"create these phases anyway?"* if it finds any.
At two or more phases it also asks **"Start these N phases under an epic?"** in the same breath, then
opens one GitHub epic issue and files every phase as its sub-issue — a real parent/child link, not a
label (creation is GitHub-only, whatever forge the PR is on); a single phase gets no epic, and a re-run
reuses the one the intent already records. It appends the epic and every phase key to the intent's
`## Dispatch` block. Last, it
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
`changeset pre` + `changeset version`, never by this command. Artifacts source the summary:
`3_memory.md` → `1_spec.md` → `2_plan.md`.

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
--sync-only`, plus `install-adapter.sh claude-code --refresh`), reconcile the root `AGENTS.md` behind
its own second approval, audit, and clean up. No file is ever copied by hand.

With no adapter installed, paste that same prompt from `core/prompts/harness-update.md` into Claude
Code instead. The version check alone is
`bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check`.

## Typical workflow

1. Start a non-trivial task and enter plan mode. Optionally capture and approve an intent
   (`/monorepo-harness-intent`) if the work is intent-driven — an approved intent that needs
   planning becomes `/monorepo-harness-intent-dispatch <intent.md>`, which hands you one issue per
   phase (and can merge the intent's PR once you say so).
2. Type `/monorepo-harness-spec` (optionally `<intent.md>` to seed the spec). Claude Code also fires
   the plan/spec reminder automatically on plan-mode exit. **It stops there** — do not write
   `2_plan.md` or start implementation until you run the next command.
3. Type `/monorepo-harness-plan <1_spec.md>`; approve plan mode when asked. **It stops there** — do
   not start implementation until you run `/monorepo-harness-build`.
4. Type `/monorepo-harness-build <2_plan.md>` to implement the task.
5. `/monorepo-harness-build` invokes the `verifier` subagent (or you run the same commands) and writes
   `3_memory.md` and `4_verify.md` (unless the verification plan is `N/A`), updating the index.
6. If the project uses `changeset`, type `/monorepo-harness-changeset <2_plan.md>` to draft the release entry.
7. Commit your changes. The `Stop` hook blocks until `3_memory.md` (and `4_verify.md`, when required) exists.

## Notes

- The automatic reminder and `/monorepo-harness-spec`/`-plan`/`-build` all share the same `core/skills/agent-workflow/SKILL.md` instructions and `core/scripts/task-state.sh` gates. ADRs are validated by `task-state.sh check-adr` before commit and re-checked by the PR-review skill.
- The memory-gate is a **hard block** in Claude Code, scoped to a task that reached the build stage: you cannot end a task in its build until `3_memory.md` exists, and until `4_verify.md` exists too whenever required. It blocks **once** — on the retry the hook input carries `stop_hook_active: true` and the gate prints nothing.
- The `tracker` subagent (`.claude/agents/tracker.md`) is claude-code-specific — opencode/codex run the same
  `core/scripts/tracker-issue.sh` inline (see `PORTABILITY.md`). The harness never installs, asks for,
  or stores a tracker credential on any agent.
- The `verifier` subagent (`.claude/agents/verifier.md`) is claude-code-specific — opencode/codex have no subagent primitive, so those adapters run the same verification instructions inline in the main session instead (see `PORTABILITY.md`). No capability is lost, just the isolated context.
