# Agent Harness for Monorepos

A portable **plan → spec → memory** workflow harness that makes AI coding agents **auditable and
self-documenting** in any JavaScript/TypeScript monorepo — with **any agent**: Claude Code, opencode, Cursor,
Codex, and more.

## What you get

- **Auditable tasks** — every non-trivial task produces `1_plan.md`, `2_spec.md`, and `3_memory.md`
  in a dedicated per-task directory, so you can always answer "why was this built this way?"
- **Per-workspace working state** — each app/package owns `.agents/{session-log,lessons,todo}.md`;
  agents read them before work and record what they learned after.
- **Enforced follow-through** — the memory-gate blocks the task from ending until `3_memory.md`
  exists (agent stop-hook where supported, git pre-commit / CI everywhere else).
- **Updatable** — the bundle carries a version; a `/tah:update` command compares your install
  against upstream and, with your consent, the active agent upgrades it in place by following the
  `changelogs/version-X.Y.Z.md` prompts.
- **Agent portability** — an agent-neutral `core/` plus thin per-agent `adapters/`; switching or
  mixing agents never loses a capability (mandatory-parity rule).

## How it works

Every plan-mode task produces three artifacts inside the workspace it targets, cataloged by a
mandatory searchable index:

```
<workspace>/.agents/artifacts/
├── index.md                          # searchable task index (entry point)
└── task_<YYYY_MM_DD>_<slug>/
    ├── 1_plan.md                     # the "how" (approved plan)
    ├── 2_spec.md                     # the "what" (contract, acceptance criteria)
    └── 3_memory.md                   # the outcome (findings, decisions, commit SHAs)
```

The bundle is split into a shared core and per-agent adapters:

```
monorepo-agents-harness/
├── core/        # agent-neutral: rules, skill templates, enforcement scripts, docs governance
└── adapters/    # per-agent enforcement wiring — install the ones you use
    ├── claude-code/
    ├── opencode/
    └── codex/
```

## Quickstart

From your monorepo root:

1. **Copy this bundle** into your repo root as `monorepo-agents-harness/`.
2. **Install the core** (agent-neutral — same for everyone): copy `core/root-AGENTS.md` to
   `AGENTS.md`, seed the docs governance tree, scaffold per-workspace `.agents/` dirs, resolve
   placeholders.
   → Step-by-step: **[INSTALL.md](INSTALL.md)** (Phase 1)
3. **Install your agent's adapter**:
   - Claude Code → [adapters/claude-code/INSTALL.md](adapters/claude-code/INSTALL.md)
   - opencode → [adapters/opencode/INSTALL.md](adapters/opencode/INSTALL.md)
   - Codex CLI → [adapters/codex/INSTALL.md](adapters/codex/INSTALL.md)
   - Another agent → author one: [PORTABILITY.md](PORTABILITY.md)

Whichever adapter you pick, wire the universal hard gate (works even with no agent at all):

```bash
ln -s ../../.agents/monorepo-agents-harness/scripts/memory-gate.sh .git/hooks/pre-commit
```

## Adapters

| Adapter       | Enforcement provided                                                                                                                                                               |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude-code` | `PostToolUse[ExitPlanMode]` hook (plan reminder), `/tah-build` manual plan/spec trigger, `Stop` hook memory-gate (**hard block**), skill auto-registration, `/tah:update` command  |
| `opencode`    | Universal git/CI gate (hard), `/tah-update` command, `/tah-build` manual plan/spec trigger                                                        |
| `codex`       | `PostToolUse[update_plan]` hook (plan reminder), `Stop` hook memory reminder (soft) + universal git/CI gate (hard), skill auto-registration, `/tah-update` and `/tah-build` skills |
| yours         | Follow the capability matrix in [PORTABILITY.md](PORTABILITY.md) — new adapters are the intended growth path                                                                       |

## Documentation map

| File                                                                       | What it covers                                                                             |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [INSTALL.md](INSTALL.md)                                                   | Full install: core phase, adapter phase, placeholders, verification                        |
| [PORTABILITY.md](PORTABILITY.md)                                           | Cross-agent capability matrix; how to author a new adapter                                 |
| [core/root-AGENTS.md](core/root-AGENTS.md)                                 | Template root instructions — the single source of truth copied into target repos as `AGENTS.md` |
| [core/skills/agent-workflow/SKILL.md](core/skills/agent-workflow/SKILL.md) | Plan/spec/memory file templates                                                            |
| [core/skills/harness-update/SKILL.md](core/skills/harness-update/SKILL.md) | Update-check / upgrade workflow (shared by both adapter commands)                          |
| [core/skills/monorepo/SKILL.md](core/skills/monorepo/SKILL.md)             | Monorepo guidance (framework-agnostic + Turborepo/Nx/Lerna/workspaces)                     |
| [core/governance/artifacts/AGENTS.md](core/governance/artifacts/AGENTS.md) | Task-index format & searchability rules for every `<workspace>/.agents/artifacts/index.md` |

## Requirements

- A **JavaScript/TypeScript monorepo** (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) with an `apps/*` layout (optionally `packages/*` or `libs/*`)
- `git`; `jq` only if your adapter needs it (claude-code and codex do)
