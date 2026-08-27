# Todo — Per-SDLC-stage commands with a gated artifact chain

## Task: task_2026_08_27_sdlc_commands

- [x] Decide design (user: shared script; intent mandatory only when given; build auto-writes memory/verify; plan questions on plan-mode; build = implement)
- [x] core/scripts/task-state.sh: check-intent-approved / check-spec / check-plan / check-chain
- [x] agent-workflow/SKILL.md: stage-commands table + gating + per-phase entry points
- [x] Adapter stubs: -spec (new), -plan (new), -build (rewrite) across claude-code/opencode/codex
- [x] Manifests: 2 new rows each (no new skill registration / jsonc change needed)
- [x] Docs: PORTABILITY.md, adapter READMEs + INSTALL.md rows, root README
- [x] VERSION 0.1.0-rc.3 + CHANGELOG + changelogs prompt (manual follow-up: re-run adapter installer)
- [x] Verify: bash -n, task-state.sh smoke cases, scratch install (idempotence) + audit exit 0
- [ ] Memory + verify artifacts + commit
