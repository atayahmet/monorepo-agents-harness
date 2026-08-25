---
description: Manually trigger the plan/spec build for the current task
---

Follow the shared instructions in
`turborepo-agent-harness/core/skills/agent-workflow/SKILL.md` exactly:

1. Resolve the target workspace (`apps/<name>` or `packages/<name>`).
2. Create the task directory `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`.
3. Write `1_plan.md` (frontmatter `phase: plan`, `status: approved`).
4. Write `2_spec.md` (`phase: spec`) in the same directory.
5. Update `<workspace>/.agents/artifacts/index.md` with a new row for this task.

Do this **before the first Edit/Write call** for the task.
