---
name: monorepo-harness-plan
description: Create the plan (2_plan.md), gated on the spec and plan-mode consent. Use when the user types /monorepo-harness-plan <spec.md>.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` exactly (Phase 2), and gate
with `core/scripts/task-state.sh`:

1. Resolve the spec path the user typed after the command: `/monorepo-harness-plan <spec.md>`.
2. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-spec <spec.md>`. If it
   exits non-zero, do **not** write the plan; report the reason and stop.
3. Check whether you are currently in plan mode.
   - If you are, skip to step 4.
   - If not, ask the user: "Enable plan mode?" — on **yes** enter plan mode; on **no** proceed
     without it.
4. Write `2_plan.md` (frontmatter `phase: plan`, `status: approved`) in the same task directory per
   Phase 2, then update `<workspace>/.agents/artifacts/index.md`.
5. After writing `2_plan.md` (and updating the index), **STOP here**. Do **not** start
   implementation. The user must run `/monorepo-harness-build <2_plan.md>` next — implementation may
   only begin after the plan is approved.
