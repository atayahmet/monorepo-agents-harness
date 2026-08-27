# Cross-Agent Portability — core + adapters, and how to author a new one

The harness is agent-neutral by construction: **`core/` holds everything every agent shares**
(rules, templates, scripts, docs governance) and **`adapters/<agent>/` holds only the per-agent
enforcement wiring**. The bundle ships three adapters — `claude-code`, `opencode`, and `codex` — as reference
implementations. This guide explains the model and how to add your own agent.

## The golden rule (mandatory parity)

> **For every harness capability, the agent you install MUST have a live equivalent.** Never drop a
> capability because your agent lacks another agent's exact hook. If there is no direct equivalent,
> fall back to the **agent-agnostic row** (an `AGENTS.md` rule and/or the git/CI gate) so the
> capability is *preserved, not lost*.

## The three portability layers

| Layer | Portable? | How |
|---|---|---|
| **Instructions** (rules, workflow mandates) | ✅ Universal | `AGENTS.md` is read natively by Claude Code, opencode, Cursor, Codex, Zed, … Put the *rules* here — and only here (single source of truth). |
| **Templates** (plan/spec/memory, monorepo) | ✅ Universal | `core/skills/**/SKILL.md` files are plain markdown. They are installed into `.agents/monorepo-agents-harness/core/skills/` at install time and referenced through each agent's instruction mechanism. |
| **Enforcement** (hooks that remind/block) | ⚠️ Per-agent | `core/scripts/*.sh` implement the logic; each adapter wires them into the agent's hook/plugin API — or falls back to git/CI where the agent can't block. |

**Design principle:** push as much as possible into `core/` (universal), and keep the per-agent
adapter as thin as possible (only the enforcement the instructions can't guarantee).

## Capability matrix

| Harness capability | Core artifact | claude-code adapter | opencode adapter | codex adapter | Agent-agnostic fallback (always available) |
|---|---|---|---|---|---|
| Project instructions / rules | root `AGENTS.md` | native + root `CLAUDE.md` = `@AGENTS.md` pointer | native | native | `AGENTS.md` — read by most agents |
| Per-workspace working state (`session-log`/`lessons`/`todo` under `<ws>/.agents/`) | `core/workspace-agents-template/` + `core/scripts/scaffold-workspace-agents.sh` | `AGENTS.md` "Before You Start" mandate | same | same | `AGENTS.md` mandate (instruction-level → **universal**, no hook needed) |
| Plan/spec/memory templates | `.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` | symlinked into `.claude/skills/` (auto-registered skill) | referenced via `opencode.jsonc` `instructions` | symlinked into `.agents/skills/` (auto-registered skill) | reference the shared runtime templates via your agent's instruction mechanism |
| Monorepo guidance | `.agents/monorepo-agents-harness/core/skills/monorepo/SKILL.md` | same as above | same as above | same as above | link from `AGENTS.md` |
| Plan/spec reminder (start of impl.) | `AGENTS.md` gotcha #4 | `PostToolUse[ExitPlanMode]` hook + `/monorepo-harness-spec`/`-plan` commands | `AGENTS.md` mandate + `/monorepo-harness-spec`/`-plan` commands | `PostToolUse[update_plan]` hook + `SessionStart` reminder + `/monorepo-harness-spec`/`-plan` skills | `AGENTS.md` mandate |
| Per-SDLC-stage commands (intent → spec → plan → build) | `core/skills/agent-workflow/SKILL.md` (stage entry points) + `core/scripts/task-state.sh` (read-only chain validation) | `.claude/commands/monorepo-harness-{spec,plan,build}.md` | `.opencode/commands/monorepo-harness-{spec,plan,build}.md` | `.agents/skills/monorepo-harness-{spec,plan,build}/SKILL.md` | run the `task-state.sh` checks and follow the stage phases by hand |
| **Memory-gate** (no finish without `3_memory.md`, plus `4_verify.md` when the spec's Test/verification plan is not N/A) | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (**hard block**) | universal hard gate (git pre-commit / CI) | `Stop` hook → script `--json` (soft reminder) | **script default mode as git pre-commit / CI — hard block, universal** |
| Verifier subagent (produces the `4_verify.md` evidence) | `core/skills/agent-workflow/SKILL.md` Phase 4 | `.claude/agents/verifier.md` (isolated context, read-only) | — main session runs the same verification commands inline | — same as opencode | Universal: verification commands run in the main session per the skill's Phase 4 instructions — no capability lost, just no isolated context |
| Update check / upgrade | `.agents/monorepo-agents-harness/core/scripts/harness-update.sh` + `.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md` | no adapter command — follow the README "Update from the repo" prompt | same | same | run `.agents/monorepo-agents-harness/core/scripts/harness-update.sh check` directly, then follow the skill by hand |
| Root `AGENTS.md` reconciliation (install + upgrade) | `.agents/monorepo-agents-harness/core/skills/agents-md-merge/SKILL.md` | performed by the active agent — no adapter wiring needed | same | same | run the skill's `git merge-file` one-liners by hand |
| CI provider detection + `memory-gate.sh` integration (`/monorepo-harness-ci`) | `core/scripts/detect-ci-provider.sh` + `core/skills/ci-integration/SKILL.md` | `.claude/commands/monorepo-harness-ci.md` → `/monorepo-harness-ci` | `.opencode/commands/monorepo-harness-ci.md` → `/monorepo-harness-ci` | `.agents/skills/monorepo-harness-ci/SKILL.md` → `/monorepo-harness-ci` | run `.agents/monorepo-agents-harness/core/scripts/detect-ci-provider.sh --provider` directly and follow `core/skills/ci-integration/SKILL.md` by hand |
| PR review (`/monorepo-harness-review`) | `core/root-REVIEW.md` (installed policy) + `core/skills/pr-review/SKILL.md` | `.claude/commands/monorepo-harness-review.md` → `/monorepo-harness-review` | `.opencode/commands/monorepo-harness-review.md` → `/monorepo-harness-review` | `.agents/skills/monorepo-harness-review/SKILL.md` → `/monorepo-harness-review` | follow `core/skills/pr-review/SKILL.md` by hand — it's plain `git diff` + read/report, no agent-specific mechanism needed |
| Intent capture + review (`/monorepo-harness-intent`) | `core/governance/intents/` + `core/skills/intent-workflow/SKILL.md` | `.claude/commands/monorepo-harness-intent.md` → `/monorepo-harness-intent` | `.opencode/commands/monorepo-harness-intent.md` → `/monorepo-harness-intent` | `.agents/skills/monorepo-harness-intent/SKILL.md` → `/monorepo-harness-intent` | follow `core/skills/intent-workflow/SKILL.md` by hand — plain file read/write + a consent question, no agent-specific mechanism needed |
| Slash commands | — | `.claude/commands/**/*.md` (subdir = namespace) | `.opencode/commands/**/*.md` (flat filename or subdir = command ID) | `.agents/skills/**/*.md` auto-register as slash commands | n/a (agent-specific convenience) |

### Semantic differences you must not paper over

- **Hard block vs. soft reminder.** claude-code's `Stop` hook can *refuse to let the agent stop*.
  opencode has no stop hook that can block, so it relies entirely on the universal hard gate.
  Codex's `Stop` hook is advisory: it can surface a `systemMessage` but cannot reject the turn.
  → The **universal hard gate is `core/scripts/memory-gate.sh`** wired as a git pre-commit hook
  and/or CI step. Install it for *every* agent whose stop you cannot block (and it's a good
  belt-and-braces even for claude-code).
- **Manual plan/spec build fallback.** Any agent that lacks an `ExitPlanMode` hook (or where the
  automatic reminder is missed) can fall back to the `/monorepo-harness-spec` and
  `/monorepo-harness-plan` commands to drive the same `agent-workflow` spec/plan creation steps,
  before the first implementation Edit/Write. `/monorepo-harness-build` then runs the implementation
  and writes memory/verify. Each stage gates its input via `core/scripts/task-state.sh` before
  acting (`-spec` requires an approved intent when a path is given; `-plan` validates the spec and
  asks about plan mode; `-build` validates the whole chain).
- **Plan-mode detection is per-agent.** `/monorepo-harness-plan` must know whether the session is in
  plan mode. This is not scriptable — each stub relies on the model's own knowledge of its active
  mode, then asks for consent ("Enable plan mode?") when it is not in plan mode, proceeding without
  it if the user declines. The yes/no semantics are identical across agents; only the model's
  self-reporting differs.
- **No `ExitPlanMode` tool on Codex.** Codex toggles plan mode with the `/plan` slash command; the
  closest local function tool is `update_plan`, so the Codex adapter uses `PostToolUse[update_plan]`
  for the plan→spec reminder. The root `AGENTS.md` mandate remains the universal fallback.
- **Codex slash commands come from skills.** Codex does not support user-defined slash commands
  directly; skills under `.agents/skills/` auto-register and appear in the slash list. The harness
  update check no longer ships a per-adapter entry point on any agent — it is invoked from the
  README's "Update from the repo" prompt or directly via `core/skills/harness-update/SKILL.md`.
- **CI integration is tiered by provider, not by agent.** GitHub Actions supports independent
  workflow files, so `/monorepo-harness-ci` writes a new, dedicated one after consent. GitLab,
  Bitbucket Pipelines, and CircleCI each read exactly one pipeline file, so the skill only shows the
  matching snippet and where to paste it — it never edits those files itself, on any agent.
- **PR review is a report, not a service, on every agent.** `/monorepo-harness-review` never posts
  to a PR platform, tags comments, or merges/approves anything, on claude-code, opencode, or codex
  alike — that's deliberately left to platform-specific products (Claude Code's own Code Review,
  `claude-code-action`, or equivalents), which the harness does not commit to.
- **No subagent primitive on opencode/codex.** Only claude-code has an isolated-context subagent
  mechanism (`.claude/agents/*.md`). The `verifier` subagent is a claude-code-only convenience, not
  a capability the other two agents lack outright: `agent-workflow` SKILL.md Phase 4's verification
  instructions are agent-neutral, so opencode/codex sessions run the same commands inline in the
  main session — the *capability* (verification before `4_verify.md`) is universal; only the
  *isolated-context delivery mechanism* is claude-code-specific.

## Authoring a new adapter

1. **Read the matrix column for your agent.** For each capability, decide: native mechanism, or
   fallback row?
2. **Instructions:** ensure the agent reads root `AGENTS.md` (native in most). If your agent uses a
   different file (e.g. `.cursor/rules`), make that file a thin pointer to `AGENTS.md` — never a
   copy of its content.
3. **Templates:** reference `.agents/monorepo-agents-harness/core/skills/**/SKILL.md` through the
    agent's instruction/config mechanism. If the agent requires physical presence for
    auto-registration (claude-code does), symlink the shared runtime skill into the agent's skill
    directory rather than copying it.
4. **Enforcement:** wire `core/scripts/memory-gate.sh` into the agent's hook/plugin API if it has
   one; otherwise install the git/CI gate. The script is fail-open and dependency-light (`git` +
   coreutils; `--json` output mode for agents needing structured hook output). The update check
   needs no adapter entry point: point users at the README "Update from the repo" prompt or
   `core/skills/harness-update/SKILL.md` directly.
5. **Package it** as `adapters/<your-agent>/` with a `manifest.txt` — one `copy`/`link`/`merge`/`tmpl`
   row per file the adapter installs, which is what `core/scripts/install-adapter.sh` executes and
   `core/scripts/audit-install.sh` verifies. Never describe a copy step in prose (`adapters/AGENTS.md`
   rule 4). Add the agent to the `for agent in ...` loop in `audit-install.sh`, then write an
   `INSTALL.md` (≤100 lines: prerequisites, the one install command, the "what maps to what" table,
   verification, semantic-difference notes) and a `README.md` (user guide: commands, workflow,
   notes). Open a PR — new adapters are the intended growth path of this bundle.

## The universal hard gate (every agent, or none)

`core/scripts/memory-gate.sh` fails when today's task dir is missing its spec (`1_spec.md`, or legacy
`2_spec.md`) / `3_memory.md`.
It depends only on `git` + coreutils, so it works with any agent — or none.

```bash
# as a git pre-commit hook
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
chmod +x .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
# …or as a CI step
bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

This is what makes the memory-gate real on agents that cannot block their own stop.
