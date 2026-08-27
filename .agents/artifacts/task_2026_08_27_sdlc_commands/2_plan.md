---
phase: plan
date: 2026-08-27
slug: sdlc_commands
status: approved
---

# Plan: Per-SDLC-stage slash commands with a gated artifact chain

## Problem

One oversized `/monorepo-harness-build` currently writes spec+plan together with no intent gate, no
plan-mode awareness, and no chain validation before implementation. We replace it with four
composable stage commands (`-intent`, `-spec`, `-plan`, `-build`) each validating its input against
the shared artifact contract. See `1_spec.md`.

## Approach

Introduce a read-only shared validator (`core/scripts/task-state.sh`) and split workflow authoring
into per-phase entry points already present in `agent-workflow/SKILL.md`. Adapters stay thin: their
command stubs call the validator, handle the only adapter-specific piece (plan-mode detection), and
point at the relevant phase of `agent-workflow/SKILL.md`. The writing templates for spec/plan/memory/
verify are NOT duplicated into any adapter.

## Related prior work

- [install_root_review](task_2026_08_27_install_root_review/1_spec.md) — established that `memory-gate.sh`
  is the precedent for a runtime existence/frontmatter validator living in `core/scripts/`.
- [align_artifact_order](task_2026_08_27_align_artifact_order/1_spec.md) — established the
  `1_spec`/`2_plan`/`3_memory`/`4_verify`/`0_intent` file contract and the index rules these commands
  must keep in sync.

## Steps

1. Write `core/scripts/task-state.sh` (four read-only subcommands; plain grep/sed frontmatter
   parsing matching `memory-gate.sh` style). It ships automatically — `core/` is already a single
   `core/install-manifest.txt` row, so no manifest change is needed for the script.
2. Extend `core/skills/agent-workflow/SKILL.md`: add a short "Stage commands" section spelling out
   the gating rules and the four entry points (Phase 1, Phase 2, Phase 3/4) that the new command
   stubs reference, plus the intent-approval policy.
3. Write the 2 new command files + rewrite the build command for each adapter:
   - `adapters/claude-code/.claude/commands/monorepo-harness-spec.md`, `...-plan.md`, rewrite
     `...-build.md`.
   - `adapters/opencode/.opencode/commands/monorepo-harness-spec.md`, `...-plan.md`, rewrite
     `...-build.md`.
   - `adapters/codex/.agents/skills/monorepo-harness-spec/SKILL.md`, `...-plan/SKILL.md`, rewrite
     `...-build/SKILL.md`.
4. Add the two new rows per adapter `manifest.txt`. No new shared-skill wiring needed because the
   commands reference the already-registered `agent-workflow` skill (`link`/`instructions` rows exist
   in every adapter).
5. Docs: `PORTABILITY.md` command matrix + notes; each adapter `README.md` command table + workflow;
   `README.md`; `INSTALL.md` only if the Phase-2 table or workflow text names the commands.
6. Version: `VERSION` → `0.1.0-rc.3`; `CHANGELOG.md` section + Upgrade Note; write
   `changelogs/version-0.1.0-rc.3.md` noting the changed `-build` semantics (release prompt required —
   this is a semantic-difference manual follow-up the manifests can't express).

## Affected files / modules

- `core/scripts/task-state.sh` (new)
- `core/skills/agent-workflow/SKILL.md`
- `adapters/{claude-code,opencode,codex}/.../monorepo-harness-{spec,plan}.md|SKILL.md` (new) and
  `monorepo-harness-build.*` (rewrite)
- `adapters/{claude-code,opencode,codex}/manifest.txt`
- `PORTABILITY.md`, `adapters/*/README.md`, `README.md`, `INSTALL.md` (as needed)
- `VERSION`, `CHANGELOG.md`, `changelogs/version-0.1.0-rc.3.md`
- `.agents/artifacts/task_2026_08_27_sdlc_commands/` (+ index), session-log, todo, lessons

## Risks & assumptions

- Ad-hoc tasks remain common; intent approval gate applies only to intent-seeded tasks.
- Plan-mode detection is genuinely per-agent and non-scriptable — the stubs rely on the model's own
  knowledge of its active mode, so semantics differ slightly per agent. Accepted portability cost,
  documented in PORTABILITY.md.
- No new shared skill registration is required; reuses the already-wired `agent-workflow` skill.

## Definition of done

- [ ] `task-state.sh` passes all smoke cases (approved/pending/rejected/missing intent, valid/
  missing spec/plan, complete/ad-hoc/unapproved-intent chain).
- [ ] `bash -n` clean on every `core/scripts/*.sh`.
- [ ] All 3 adapters have `-spec`/`-plan`/`-build` stubs; manifests list the new files.
- [ ] Install each adapter into a scratch repo twice + `audit-install.sh` exits 0.
- [ ] `VERSION` = `0.1.0-rc.3`; CHANGELOG + changelogs prompt updated; docs updated.
- [ ] 3_memory.md + 4_verify.md written; commit made.
