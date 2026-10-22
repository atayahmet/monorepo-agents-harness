# Todo — monorepo-agents-harness

Working plan for the current task in **this workspace**. Overwrite per task.

## Issue #46 — tiered red-first test rule — 2026-10-22

Plan approved → implement red-first → verify → release `0.4.0-rc.24`.

- [x] Branch `feat/red-first-test-rule-46`
- [x] Task artifacts `1_spec.md` + `2_plan.md` (red-first tier)
- [x] `tests/red-first-rule.test.sh` first → capture red output
- [x] `core/scripts/task-state.sh` — advisory `check-red-evidence <task_dir>`
- [x] `1_spec.md` / `2_plan.md` / `4_verify.md` templates
- [x] `agent-workflow/SKILL.md` — tier table, ordered steps, fallback, advisory
- [x] Three adapter build stubs — ordered red-first step before implementation
- [x] `core/root-AGENTS.md` one-sentence rule + README/PORTABILITY sync
- [x] Tests green, mutation checks fail the suite as expected
- [x] Release: VERSION, CHANGELOG, changelog prompt
- [x] `3_memory.md` + `4_verify.md`, index ◆, session log
- [x] Commit, push, open PR against `main`
