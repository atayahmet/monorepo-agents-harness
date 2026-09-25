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
- **Hard memory-gate** — the `Stop` hook refuses to end the task until today's task directory contains `3_memory.md`, and `4_verify.md` too whenever the spec's Test/verification plan is not `N/A` (Feedback Loop enforcement).
- **`/monorepo-harness-update`** — check the installed harness version against upstream and, on your consent, upgrade the core and every installed adapter.
- **`/monorepo-self-improve`** — harvest recurring patterns from lessons and task memories, then propose durable project-owned rules (`.agents/rules/*.md`) and skills (`.agents/skills/*/SKILL.md`). Requires explicit approval before writing anything.
- **`/monorepo-harness-intent-execute <intent.md>`** — turn an **approved** intent into scoped work: confirm the workspace scope, split it into 3-5 phases, record your sign-off, then write one task directory and one GitHub issue per phase (via the `tracker` subagent). It stops there — each phase is built separately with `/monorepo-harness-build <2_plan.md>`. No credential is ever installed or stored; without `gh` you get paste-ready issue text instead.
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

### `/monorepo-harness-intent-execute <intent.md>` — Turn an approved intent into phases and issues

Run it once the intent is `approved`. It checks the approval first (`task-state.sh check-intent-approved`)
and stops on anything else; pushes the approval commit if the intent names a `pr:`; confirms the
workspace scope; and proposes 3-5 phases, where a phase is worth its own review. After you answer
**"Start these N phases?"** it writes one `task_<date>_<phase_slug>/` per phase (`0_intent.md`,
`1_spec.md`, `2_plan.md` + an index row) and opens one GitHub issue per phase, recording the URL in
the plan. The platform is resolved from `--tracker`, then the plan's `tracker:` frontmatter, then by
asking you once — GitHub Issues via `gh` is the only platform this version implements, and Linear/Jira
need an MCP server or token that you install yourself.

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
   planning becomes `/monorepo-harness-intent-execute <intent.md>`, which hands you one task
   directory and one issue per phase.
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
- The memory-gate is a **hard block** in Claude Code; you cannot end the task until `3_memory.md` exists, and until `4_verify.md` exists too whenever required.
- The `tracker` subagent (`.claude/agents/tracker.md`) is claude-code-specific — opencode/codex run the same
  `core/scripts/tracker-issue.sh` inline (see `PORTABILITY.md`). The harness never installs, asks for,
  or stores a tracker credential on any agent.
- The `verifier` subagent (`.claude/agents/verifier.md`) is claude-code-specific — opencode/codex have no subagent primitive, so those adapters run the same verification instructions inline in the main session instead (see `PORTABILITY.md`). No capability is lost, just the isolated context.
