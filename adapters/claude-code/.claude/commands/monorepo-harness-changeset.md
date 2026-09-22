---
description: Draft a changesets-compatible release entry for a finished task, derived from its plan/spec/memory artifacts, gated on the plan and user-confirmed bumps
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/changeset-workflow/SKILL.md` exactly, and gate with
`core/scripts/task-state.sh`:

1. Resolve the plan path the user typed after the command: `/monorepo-harness-changeset <2_plan.md>`;
   if absent, ask which task's plan to use.
2. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-plan <2_plan.md>`. If
   it exits non-zero, do **not** draft; report the reason and stop.
3. Confirm `.changeset/` exists; if not, report that the project does not appear to use changesets
   and suggest `changeset init` — never create it yourself.
4. Read `2_plan.md` / `1_spec.md` / `3_memory.md` per the skill, propose packages + bump levels, and
   ask the user to confirm the package list, every bump, and the summary before writing anything.
5. Show the draft: run `draft-changeset.sh <plan>` (--dry-run), then on explicit consent re-run with
   `--write` and report the created path. Use `--revision N` for second and later changesets from the
   same plan.

Never run `changeset` itself, never create `.changeset/config.json`, and never write a changeset
without user-confirmed packages, bumps, and summary.