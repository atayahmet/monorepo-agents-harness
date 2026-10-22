---
version: 0.4.0-rc.24
from: 0.4.0-rc.23
date: 2026-10-22
---

# Version 0.4.0-rc.24 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.23 to 0.4.0-rc.24. This release adds a
**tiered red-first test rule**: the spec declares whether a failing test must come before the
implementation, and verify records that failure.

## What changed

- **`core/skills/agent-workflow/templates/1_spec.md`** — the test plan starts with
  `Tier: red-first` (bug fixes, clear contracts) or `Tier: evidence-only` (UI, config, glue,
  exploration).
- **`core/skills/agent-workflow/templates/2_plan.md`** — red-first steps are failing test →
  implementation pairs.
- **`core/skills/agent-workflow/templates/4_verify.md`** — new `## Red evidence` section for the
  verbatim failure captured before the implementation, including the save/revert/restore fallback.
- **`core/skills/agent-workflow/SKILL.md`** — the tier table, build order, fallback and advisory
  check.
- **The three adapter build entry points** — the same ordered step: read the tier, write and run the
  failing tests first, then implement, then record `## Red evidence`.
- **`core/scripts/task-state.sh`** — new advisory `check-red-evidence <task_dir>`. It warns for a
  red-first task with no evidence and always exits 0. A spec with no tier line stays silent.
- **`core/root-AGENTS.md`** — Critical Gotcha 5 carries the rule, so it stays in context.
- Docs sync in `README.md`, `PORTABILITY.md`. No new file, no manifest row, no hard gate.

## Commands to run

- None by hand. The release is instruction/script-only: the normal upgrade's bundle re-sync
  (`install-harness.sh --sync-only`) carries `task-state.sh`, the templates and the skill, and the
  adapter refresh (`install-adapter.sh <agent> --refresh`) re-applies the three build entry points.

## Manual follow-ups for the user

- None required. The `agents-md-merge` skill can carry the new Gotcha 5 sentence into an existing
  root `AGENTS.md` if you already merged one.
- Optional: on your next task, add a `Tier:` line to the spec's `## Test / verification plan`.
  Existing task dirs without one keep passing unchanged; `check-red-evidence` stays silent for them.
- The check is advisory on purpose. Do not wire it as a hard gate: it can see that the section
  exists, not that the test really came first.

## Release summary

- Tiered red-first rule across the spec/plan/verify templates, the agent-workflow skill and all three
  build entry points (closes #46).
- New advisory `task-state.sh check-red-evidence`, fail-open and silent for legacy tasks.
- Root `AGENTS.md`, README and PORTABILITY synced.
- Repo-local `tests/red-first-rule.test.sh`: 88 cases plus four mutation checks.

**Note.** The release itself needs no command or manual follow-up, so `changelogs/README.md` would
normally omit this prompt. It is added at the maintainer's request.
