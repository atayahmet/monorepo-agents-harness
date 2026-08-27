---
phase: spec
date: 2026-08-27
slug: sdlc_commands
status: approved
---

# Spec: Per-SDLC-stage slash commands with a gated artifact chain

## Problem

The harness currently exposes a single `/monorepo-harness-build` command that writes the spec
(`1_spec.md`) and the plan (`2_plan.md`) in one step, and treats an approved intent as optional
best-effort input. There is no way to drive the SDLC one stage at a time, no command-level gate that
an intent is approved before a spec is produced, no plan-mode awareness for the plan step, and no
enforcement that implementation starts only after the spec/plan/intent chain is valid.

We introduce separate stage commands that compose in order — intent → spec → plan → build — each
validating its input against the shared artifact contract, so a stale or unwarranted stage cannot be
run.

## Requirements

1. New shared validation script `core/scripts/task-state.sh` with four subcommands:
   - `check-intent-approved <intent.md>` — exit 0 iff the file exists and its frontmatter carries
     `status: approved`; otherwise exit 1 with a reason.
   - `check-spec <spec.md>` — exit 0 iff the file exists and its frontmatter carries `phase: spec`.
   - `check-plan <plan.md>` — exit 0 iff the file exists and its frontmatter carries `phase: plan`.
   - `check-chain <plan.md>` — verify the plan's task directory also contains a `1_spec.md`; and, if
     the task was seeded by an intent (a `0_intent.md` is present), verify that intent was approved;
     ad-hoc tasks without a `0_intent.md` are exempt from the intent requirement. Exit 1 otherwise
     with a reason naming the missing/invalid artifact.
   All checks are read-only. Frontmatter is parsed with plain `grep`/`sed`, matching the style of
   `memory-gate.sh`.
2. New `/monorepo-harness-spec <intent.md>` command (all 3 adapters, thin stub):
   - Run `check-intent-approved <intent>`. If it fails, do **not** write anything; report the reason.
   - On success: create the task dir, write `1_spec.md` (Phase 1 of `agent-workflow`), copy the
     approved intent into the task dir as `0_intent.md`, and update the workspace index.
   - If no intent path is given, fall back to the existing ad-hoc behavior (spec without intent).
3. New `/monorepo-harness-plan <spec.md>` command (all 3 adapters, thin stub):
   - Run `check-spec <spec>`. If it fails, do not write the plan; report.
   - Determine whether the agent is currently in plan mode (adapter-specific). If not, ask the user:
     "Enable plan mode?" — **yes** → enter plan mode; **no** → continue and write `2_plan.md` without
     entering plan mode.
   - On go: write `2_plan.md` (Phase 2 of `agent-workflow`) and update the workspace index.
4. Rewrite `/monorepo-harness-build <plan.md>` (all 3 adapters):
   - Run `check-chain <plan>`. If it fails, report and do not start implementation.
   - On success: proceed with implementation for the task; on completion automatically write
     `3_memory.md` (with `commits:` filled after the implementation commits) and `4_verify.md`
     (whenever the spec's Test/verification plan is not `N/A`), and update the workspace index.
   - The old behavior of `/monorepo-harness-build` (writing spec+plan in one step) is removed; those
     responsibilities move to `-spec` and `-plan`.
5. `core/skills/agent-workflow/SKILL.md` gains explicit per-phase entry points (Phase 1 = spec,
   Phase 2 = plan, Phase 3/4 = build-completion memory/verify) plus the gating rules and the
   intent-requirement policy ("mandatory only when a task was seeded by an intent").
6. Adapter command files: new `monorepo-harness-spec.*` and `monorepo-harness-plan.*` for
   claude-code, opencode, codex; rewrite each `monorepo-harness-build.*`. Add the two new rows to each
   adapter `manifest.txt`. Keep adapters thin — the gating logic lives in `task-state.sh`, the writing
   templates in `agent-workflow/SKILL.md`; plan-mode detection is the only adapter-specific piece.
7. Docs in the same commit: `PORTABILITY.md` (command matrix + semantic-difference notes),
   each adapter `README.md` (command table + workflow), `README.md`, `INSTALL.md` if affected.
8. Version consistency: bump `VERSION` to `0.1.0-rc.3` with a `CHANGELOG.md` section and Upgrade
   Note reflecting the changed `-build` semantics (no longer writes spec/plan).

## Intent-approval policy (build)

The user confirmed: **intent approval is mandatory only when a task was seeded by an intent.**
Ad-hoc tasks (no intent behind them) are exempt. A task is considered intent-seeded when its
directory contains a `0_intent.md`. `task-state.sh check-chain` implements exactly this.

## Test / verification plan

- `bash -n` on every `core/scripts/*.sh` (all must pass).
- `task-state.sh` unit smoke tests against temporary fixture files: approved intent → exit 0;
  pending/rejected/missing intent → exit 1; valid spec/plan → exit 0; missing/invalid → exit 1; a
  complete chain → exit 0; a chain with a missing spec → exit 1; a chain with an un-approved
  `0_intent.md` → exit 1; an ad-hoc chain (no `0_intent.md`) → exit 0.
- Install the adapter into a scratch monorepo twice (idempotence) and run `audit-install.sh` (exit
  0), confirming the new `-spec`/`-plan` command files and updated `-build` are present and in sync
  with each adapter manifest.

(Note: this is a research/refactor-style infra task — behavior is command dispatch + script gating,
fully checked by the script smoke tests and the install/audit run above; no app unit tests apply.)

## N/A note

The spec's Test/verification plan above is concrete and runnable, so `4_verify.md` is required for
this task.
