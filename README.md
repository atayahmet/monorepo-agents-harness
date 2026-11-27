# Agent Harness for Monorepos

A portable **intent → spec → plan → build → memory → verify** workflow harness that makes AI coding agents **auditable and self-documenting**, and wires them into intent intake, CI, and PR review — in any monorepo, with any agent (Claude Code, opencode, Cursor, Codex, and more).

## Start here

| I want to… | Go to |
| --- | --- |
| Install the harness | [Quickstart](#quickstart) ↓ / [INSTALL.md](INSTALL.md) |
| Run a task (spec → build) | [core/skills/agent-workflow/SKILL.md](core/skills/agent-workflow/SKILL.md) |
| File or approve an intent (PO) | [docs/intents.md](docs/intents.md) |
| Wire CI / PR review | [core/skills/ci-integration/SKILL.md](core/skills/ci-integration/SKILL.md), [core/skills/pr-review/SKILL.md](core/skills/pr-review/SKILL.md) |
| Update the harness | [core/skills/harness-update/SKILL.md](core/skills/harness-update/SKILL.md) |
| Support a new agent | [PORTABILITY.md](PORTABILITY.md) |

## Quickstart

Two commands from your monorepo root (idempotent, non-destructive):

```bash
# 1. core (agent-neutral)
git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-install
bash .agents/.harness-install/core/scripts/install-harness.sh

# 2. your agent's adapter
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code   # or codex, opencode

# 3. verify
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
```

Details: [INSTALL.md](INSTALL.md) · Adapters: [claude-code](adapters/claude-code/INSTALL.md) · [opencode](adapters/opencode/INSTALL.md) · [codex](adapters/codex/INSTALL.md) · [PORTABILITY.md](PORTABILITY.md)

<details>
<summary>Or hand it to your agent</summary>

Paste this into Claude Code, opencode, Codex CLI — any agent — from your monorepo root:

```text
Install the monorepo-agents-harness into this repository.

1. Clone it and run its own installer — do NOT copy any files by hand, and do not
   follow install prose step by step. The scripts are the install:

     git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness \
       .agents/.harness-install
     bash .agents/.harness-install/core/scripts/install-harness.sh

2. Then install the adapter for the agent you are:

     bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <claude-code|codex|opencode>

3. Then verify and show me the result:

     bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh

Rules while you do this:
- Never overwrite a config file I already have. If a script writes a
  <file>.harness-proposed, leave the original alone and show me the diff.
- If I already have a root AGENTS.md, do not touch it. Report that the merge skill
  (core/skills/agents-md-merge/SKILL.md) needs to run, and ask me before running it.
- If any script exits non-zero, stop and show me its output verbatim. Do not improvise
  a fix or hand-copy the missing files.
- Report the "Needs you:" list from both scripts, and the audit result, before doing
  anything else. Do not commit without asking me.
```

</details>

## Command cheat sheet

| Command | When | Produces | Details |
| --- | --- | --- | --- |
| `/monorepo-harness-intent` | Capture/review/approve/reject intents | `<ws>/.agents/intents/intent_*.md` | [docs/intents.md](docs/intents.md) |
| `/monorepo-harness-intent-dispatch <intent.md>` | Dispatch approved intent | Epic/sub-issues, `## Dispatch` block | [docs/intents.md](docs/intents.md) |
| `/monorepo-harness-spec` | Start a task | `1_spec.md` (+ optional `0_intent.md`) | [agent-workflow](core/skills/agent-workflow/SKILL.md) |
| `/monorepo-harness-plan <spec.md> [--no-plan-mode]` | Plan after spec | `2_plan.md` (+ optional `adr/`) | [agent-workflow](core/skills/agent-workflow/SKILL.md) |
| `/monorepo-harness-build <plan.md>` | Implement | `3_memory.md`, `4_verify.md` (if required) | [agent-workflow](core/skills/agent-workflow/SKILL.md) |
| `/monorepo-harness-review [--auto-fix]` | Before merging PR | Review report vs spec/plan/policy; `--auto-fix`: bounded fix loop, local commits only | [pr-review](core/skills/pr-review/SKILL.md) |
| `/monorepo-harness-ci` | Wire CI enforcement | CI workflow/snippet | [ci-integration](core/skills/ci-integration/SKILL.md) |
| `/monorepo-harness-update` | Upgrade harness | Updated bundle/adapters + What's new summary | [harness-update](core/skills/harness-update/SKILL.md) |
| `/monorepo-harness-changeset <plan.md>` | Draft changeset | `.changeset/*.md` | [changeset-workflow](core/skills/changeset-workflow/SKILL.md) |
| `/monorepo-harness-kb-index` | Query knowledge base | Ranked results | [knowledge-base](core/skills/knowledge-base/SKILL.md) |
| `/monorepo-harness-team` | Set up the team registry (`.agents/team.yml`) | People, IDs, assignee routing | [team-registry](core/skills/team-registry/SKILL.md) |
| `/monorepo-harness-init` | Document one workspace for agents (`<ws> [--audit]`) | Nested `AGENTS.md` tree + `CLAUDE.md`/`GEMINI.md` symlinks, lint | [agents-init](core/skills/agents-init/SKILL.md) |
| `/monorepo-harness-worktree` | Work on a branch in its own checkout (`create <slug> [--setup]`, `setup`, `list`, `remove`, `prune`) | Worktree under `~/.harness-worktrees/<repo-id>/`, the same for every adapter | [docs/worktrees.md](docs/worktrees.md) |
| `/monorepo-self-improve` | Harvest learnings | Rules/skills/proposals | [self-improvement-workflow](core/skills/self-improvement-workflow/SKILL.md) |

## Features

- **Auditable tasks** — Per-task `1_spec.md`, `2_plan.md`, `3_memory.md`, `4_verify.md` in `<ws>/.agents/artifacts/`. [agent-workflow](core/skills/agent-workflow/SKILL.md)
- **Tiered red-first tests** — `Tier: red-first` or `evidence-only`; failures recorded in `4_verify.md`. [agent-workflow](core/skills/agent-workflow/SKILL.md)
- **Architecture decisions** — ADRs written next to plan/spec when needed. [adr-workflow](core/skills/adr-workflow/SKILL.md)
- **Intent capture & dispatch** — File, approve, and dispatch intents to tracked work; `--pr` pushes the intent branch and opens its PR on your forge; approve/reject directly from an intent PR link (`--approve` submits a real review, `--reject` declines on the branch and merges). [docs/intents.md](docs/intents.md)
- **One worktree root** — `/monorepo-harness-worktree` puts every worktree it creates at `~/.harness-worktrees/<repo-id>/<slug>`, outside the repo and the same for every adapter, and lists, removes and prunes them safely. A project can list files to copy into each new worktree (`.agents/worktree-copy.txt`) and add a setup script (`.agents/worktree-setup.sh`, run on `--setup`). [docs/worktrees.md](docs/worktrees.md)
- **Deterministic install/update** — Manifest-driven scripts, self-healing adapters. [INSTALL.md](INSTALL.md)
- **CI & PR review** — Enforce memory-gate in CI and review diffs against task artifacts. [ci-integration](core/skills/ci-integration/SKILL.md) · [pr-review](core/skills/pr-review/SKILL.md)
- **Knowledge base & self-improvement** — Query past work, harvest reusable rules/skills. [knowledge-base](core/skills/knowledge-base/SKILL.md) · [self-improvement-workflow](core/skills/self-improvement-workflow/SKILL.md)

## Scenarios

- [Scenario 1: Non-engineer's request becomes a shipped, verified feature](docs/scenarios/01-non-engineer-request-becomes-shipped-feature.md)
- [Scenario 2: An ad-hoc bugfix reuses prior art automatically](docs/scenarios/02-ad-hoc-bugfix-reuses-prior-art.md)
- [Scenario 3: Wiring CI enforcement](docs/scenarios/03-wiring-ci-enforcement.md)
- [Scenario 4: PR review catches scope creep against the task's own spec](docs/scenarios/04-pr-review-catches-scope-creep.md)
- [Scenario 5: Updating the harness itself, reliably](docs/scenarios/05-updating-harness-itself.md)

## Adapters

| Capability | claude-code | opencode | codex |
| --- | --- | --- | --- |
| Stop/memory-gate enforcement | ✓ (hard block) | ✓ (hard, git/CI) | soft + hard (git/CI) |
| SDLC slash/skills commands | ✓ | ✓ | ✓ |
| Intent/spec/plan/build/review/CI/update | ✓ | ✓ | ✓ |
| Verifier subagent | ✓ | — | — |
| Argument hints | ✓ | — | — |
| Shared worktree root (`/monorepo-harness-worktree`) | ✓ | ✓ | ✓ |
| Auto-registered skills/commands | ✓ | ✓ | ✓ |

New agents: see [PORTABILITY.md](PORTABILITY.md).

## Documentation map

**Install**
- [INSTALL.md](INSTALL.md) — Install steps, flags, human follow-ups
- [adapters/claude-code/INSTALL.md](adapters/claude-code/INSTALL.md), [opencode](adapters/opencode/INSTALL.md), [codex](adapters/codex/INSTALL.md)
- [core/install-manifest.txt](core/install-manifest.txt), [adapters/*/manifest.txt](adapters/)

**Workflow**
- [core/skills/agent-workflow/SKILL.md](core/skills/agent-workflow/SKILL.md) — Plan/spec/memory/verify
- [docs/intents.md](docs/intents.md) — Intent capture, review, dispatch
- [docs/worktrees.md](docs/worktrees.md) — One worktree root for every adapter; create, list, remove, prune
- [core/skills/adr-workflow/SKILL.md](core/skills/adr-workflow/SKILL.md) — Architecture decisions
- [core/skills/pr-review/SKILL.md](core/skills/pr-review/SKILL.md) — PR review
- [core/skills/ci-integration/SKILL.md](core/skills/ci-integration/SKILL.md) — CI wiring

**Governance**
- [core/root-AGENTS.md](core/root-AGENTS.md) — Installable root instructions
- [core/governance/artifacts/AGENTS.md](core/governance/artifacts/AGENTS.md) — Artifact indexing
- [core/governance/intents/AGENTS.md](core/governance/intents/AGENTS.md) — Intent rules
- [core/root-REVIEW.md](core/root-REVIEW.md) — Review policy template

**Extending**
- [PORTABILITY.md](PORTABILITY.md) — Cross-agent portability & new adapters
- [core/skills/monorepo/SKILL.md](core/skills/monorepo/SKILL.md) — Monorepo guidance
- [core/skills/knowledge-base/SKILL.md](core/skills/knowledge-base/SKILL.md), [core/skills/self-improvement-workflow/SKILL.md](core/skills/self-improvement-workflow/SKILL.md), [core/skills/harness-update/SKILL.md](core/skills/harness-update/SKILL.md)
- [changelogs/README.md](changelogs/README.md) — Upgrade prompts

## Requirements

- A git repo in **any language**. JavaScript/TypeScript workspaces (Turborepo, Nx, Lerna, npm/yarn/pnpm)
  are detected. For every other layout, list yours in `.agents/workspaces.txt`, one path or glob per
  line: `crates/*`, `services/*`, `billing`, or `.` for a single-package repo. The file replaces
  detection. The `monorepo` skill and changeset support are still JS/TS-only.
- `git`; `jq` only if your adapter needs it (claude-code and codex do)
