---
name: monorepo-harness-spec
description: Create the spec (1_spec.md) for the current task, gated on an approved intent. Use when the user types /monorepo-harness-spec <intent.md>.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` exactly (Phase 1), and gate
with `core/scripts/task-state.sh`:

1. Resolve the target workspace (`apps/<name>` or `packages/<name>`).
2. Resolve the intent path the user typed after the command: `/monorepo-harness-spec <intent.md>`.
   - If a path was given, run
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`.
   - If it exits non-zero, do **not** write anything; report the reason and stop.
   - If it passes, copy the approved intent into the task dir as `0_intent.md`.
3. Create the task directory and write `1_spec.md` (the "what": contract, acceptance criteria) per
   Phase 1.
4. Update `<workspace>/.agents/artifacts/index.md` with a new row for this task.
5. If no intent path was given, proceed as a normal ad-hoc spec (no `0_intent.md`).
6. After writing `1_spec.md` and updating the index, **STOP here**. Do **not** write `2_plan.md`,
   and do **not** start implementation. The user must run `/monorepo-harness-plan <1_spec.md>` next —
   implementation may not begin until an approved plan exists.
