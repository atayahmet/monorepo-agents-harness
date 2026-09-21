---
description: Run the implementation for the task, gated on a valid spec/plan/intent chain, then write memory and verify
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` exactly, and gate with
`core/scripts/task-state.sh`:

1. Resolve the plan path the user typed after the command: `/monorepo-harness-build <2_plan.md>`.
2. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-chain <2_plan.md>`. If
   it exits non-zero, do **not** start; report the reason and stop.
3. Run the implementation for the task following the plan/spec, **confined to `## Scope` /
   `## Acceptance criteria` in `1_spec.md` and `## Affected files / modules` in `2_plan.md`** — never
   create or touch an app, package, or file neither lists. If the scope must grow, stop and get the
   spec/plan extended and approved first.
4. On completion, write `3_memory.md` (frontmatter `phase: memory`, with `commits:` filled after the
   implementation commits) and `4_verify.md` (whenever the spec's "Test / verification plan" is not
   `N/A`) per Phase 3/4, and update `<workspace>/.agents/artifacts/index.md`. Commit the work.

Do **not** write `1_spec.md` or `2_plan.md` here — those belong to `/monorepo-harness-spec` and
`/monorepo-harness-plan`.
