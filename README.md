# Agent Harness for Monorepos

A portable **plan → spec → memory** workflow harness that makes AI coding agents **auditable and
self-documenting** in any JavaScript/TypeScript monorepo — with **any agent**: Claude Code, opencode, Cursor,
Codex, and more.

## What you get

- **Auditable tasks** — every non-trivial task produces `1_plan.md`, `2_spec.md`, `3_memory.md`, and
  (when there's something verifiable) `4_verify.md` in a dedicated per-task directory, so you can
  always answer "why was this built this way, and how do we know it works?"
- **Per-workspace working state** — each app/package owns `.agents/{session-log,lessons,todo}.md`;
  agents read them before work and record what they learned after.
- **Enforced follow-through (Feedback Loop)** — the memory-gate blocks the task from ending until
  `3_memory.md` exists, and until `4_verify.md` exists whenever the spec's Test/verification plan
  is not `N/A` (agent stop-hook where supported, git pre-commit / CI everywhere else).
- **Updatable** — the bundle carries a version; a `/monorepo-harness:update` command compares your install
  against upstream and, with your consent, the active agent upgrades it in place by following the
  `changelogs/version-X.Y.Z.md` prompts.
- **Agent portability** — an agent-neutral `core/` plus thin per-agent `adapters/`; switching or
  mixing agents never loses a capability (mandatory-parity rule).
- **CI integration** — `/monorepo-harness-ci` detects your project's CI provider and wires
  `memory-gate.sh` into it: a new, dedicated workflow file for GitHub Actions (after your consent),
  or a guided snippet + paste location for GitLab/Bitbucket/CircleCI, whose single-pipeline-file
  formats can't be auto-integrated as a separate file.
- **PR review** — `/monorepo-harness-review` checks a diff against `REVIEW.md` policy (or sensible
  defaults) and, when the diff maps to a tracked task, against that task's own
  `1_plan.md`/`2_spec.md`/`4_verify.md` — a ground truth generic review bots don't have. Reports
  Important/Nit findings; never posts to a PR platform or merges anything.
- **Intent capture** — `/monorepo-harness-intent` lets any stakeholder file a problem description
  before it's scoped into a task, and a product owner/manager approve or reject it explicitly. An
  approved intent optionally seeds a later task's plan as `0_intent.md`; rejected ones are kept, not
  deleted, as an audit trail.

## How it works

Every plan-mode task produces three artifacts inside the workspace it targets, cataloged by a
mandatory searchable index:

```
<workspace>/.agents/artifacts/
├── index.md                          # searchable task index (entry point)
└── task_<YYYY_MM_DD>_<slug>/
    ├── 1_plan.md                     # the "how" (approved plan)
    ├── 2_spec.md                     # the "what" (contract, acceptance criteria)
    ├── 3_memory.md                   # the outcome (findings, decisions, commit SHAs)
    └── 4_verify.md                   # the proof (verification run, per-criterion pass/fail)
```

The bundle is split into a shared core and per-agent adapters:

```
.agents/monorepo-agents-harness/
├── core/        # agent-neutral: rules, skill templates, enforcement scripts, docs governance
└── adapters/    # per-agent enforcement wiring — install the ones you use
    ├── claude-code/
    ├── opencode/
    └── codex/
```

## Quickstart

From your monorepo root:

1. **Copy this bundle** into `.agents/monorepo-agents-harness/` under your repo root.
2. **Install the core** (agent-neutral — same for everyone): copy `core/root-AGENTS.md` to
   `AGENTS.md` (or merge it into your existing `AGENTS.md` with your approval — see
   `core/skills/agents-md-merge/SKILL.md`), seed the docs governance tree, scaffold per-workspace
   `.agents/` dirs, resolve placeholders.
   → Step-by-step: **[INSTALL.md](INSTALL.md)** (Phase 1)
3. **Install your agent's adapter**:
   - Claude Code → [adapters/claude-code/INSTALL.md](adapters/claude-code/INSTALL.md)
   - opencode → [adapters/opencode/INSTALL.md](adapters/opencode/INSTALL.md)
   - Codex CLI → [adapters/codex/INSTALL.md](adapters/codex/INSTALL.md)
   - Another agent → author one: [PORTABILITY.md](PORTABILITY.md)

Whichever adapter you pick, wire the universal hard gate (works even with no agent at all):

```bash
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
```

## Adapters

| Adapter       | Enforcement provided                                                                                                                                                               |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude-code` | `PostToolUse[ExitPlanMode]` hook (plan reminder), `/monorepo-harness-build` manual plan/spec trigger, `Stop` hook memory-gate (**hard block**), skill auto-registration, `/monorepo-harness:update` command, `/monorepo-harness-ci` CI integration, `/monorepo-harness-review` PR review, `/monorepo-harness-intent` intent capture, `verifier` subagent  |
| `opencode`    | Universal git/CI gate (hard), `/monorepo-harness-update` command, `/monorepo-harness-build` manual plan/spec trigger, `/monorepo-harness-ci` CI integration, `/monorepo-harness-review` PR review, `/monorepo-harness-intent` intent capture                                                        |
| `codex`       | `PostToolUse[update_plan]` hook (plan reminder), `Stop` hook memory reminder (soft) + universal git/CI gate (hard), skill auto-registration, `/monorepo-harness-update`, `/monorepo-harness-build`, `/monorepo-harness-ci`, `/monorepo-harness-review`, and `/monorepo-harness-intent` skills |
| yours         | Follow the capability matrix in [PORTABILITY.md](PORTABILITY.md) — new adapters are the intended growth path                                                                       |

## Documentation map

| File                                                                       | What it covers                                                                             |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [INSTALL.md](INSTALL.md)                                                   | Full install: core phase, adapter phase, placeholders, verification                        |
| [PORTABILITY.md](PORTABILITY.md)                                           | Cross-agent capability matrix; how to author a new adapter                                 |
| [core/root-AGENTS.md](core/root-AGENTS.md)                                 | Template root instructions — the single source of truth copied into target repos as `AGENTS.md` |
| [core/skills/agent-workflow/SKILL.md](core/skills/agent-workflow/SKILL.md) | Plan/spec/memory file templates                                                            |
| [core/skills/agents-md-merge/SKILL.md](core/skills/agents-md-merge/SKILL.md) | Reconciles a project's root `AGENTS.md` with the harness template on install/upgrade       |
| [core/skills/harness-update/SKILL.md](core/skills/harness-update/SKILL.md) | Update-check / upgrade workflow (shared by both adapter commands)                          |
| [core/skills/monorepo/SKILL.md](core/skills/monorepo/SKILL.md)             | Monorepo guidance (framework-agnostic + Turborepo/Nx/Lerna/workspaces)                     |
| [core/skills/ci-integration/SKILL.md](core/skills/ci-integration/SKILL.md) | Detects the target project's CI provider and wires `memory-gate.sh` into it (`/monorepo-harness-ci`) |
| [core/skills/pr-review/SKILL.md](core/skills/pr-review/SKILL.md) | Reviews a diff against `REVIEW.md` policy and, when possible, a task's plan/spec/verify artifacts (`/monorepo-harness-review`) |
| [core/root-REVIEW.md](core/root-REVIEW.md) | Optional installable review-policy template — copied into target repos as `REVIEW.md` |
| [core/skills/intent-workflow/SKILL.md](core/skills/intent-workflow/SKILL.md) | Captures stakeholder intents and lets a product owner approve/reject them (`/monorepo-harness-intent`) |
| [core/governance/intents/AGENTS.md](core/governance/intents/AGENTS.md) | Intent file format and status-lifecycle rules for every `<workspace>/.agents/intents/` |
| [core/governance/artifacts/AGENTS.md](core/governance/artifacts/AGENTS.md) | Task-index format & searchability rules for every `<workspace>/.agents/artifacts/index.md` |

## Requirements

- A **JavaScript/TypeScript monorepo** (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) with an `apps/*` layout (optionally `packages/*` or `libs/*`)
- `git`; `jq` only if your adapter needs it (claude-code and codex do)
