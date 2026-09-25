---
name: monorepo-harness-intent-dispatch
description: Execute an approved intent - confirm the workspace scope, split it into phases, and open one task directory and one tracker issue per phase (no implementation). Use when the user types /monorepo-harness-intent-dispatch, or asks to turn an approved intent into scoped, tracked work.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/intent-workflow/SKILL.md`, section
**"Workflow — Dispatch"**, exactly. The intent path is the argument the user typed after the command
(`/monorepo-harness-intent-dispatch <intent.md>`); if it is missing, ask which approved intent to use.

1. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`
   **first**. If it exits non-zero, report the reason and stop — write nothing, create nothing.
2. If the intent has a `pr:` field, push the commit carrying its `## Review` section to that PR's
   branch (`git push <remote> <sha>:<branch>`) and report the remote ref. No `pr:` field → skip.
3. Confirm the workspace scope (primary + secondary) and propose 3-5 phases — a phase is worth its
   own review. Ask "Start these N phases?" and write nothing before an explicit yes.
4. For each approved phase write `0_intent.md` (reference stub), `1_spec.md` and `2_plan.md` under
   `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<phase_slug>/`, add the index rows, then create the
   issue in this session (Codex has no subagent primitive — see `PORTABILITY.md`):

   ```
   bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
     --plan <2_plan.md> --title "<issue title>" --body-file <file> --create
   ```

   Record the returned URL in the plan's `## Tracker` section. On exit 3 (`gh` missing or
   unauthenticated) keep the task directory, write "no issue yet", and tell the user to open it by
   hand — never report an issue that does not exist.
5. Report the per-phase task directory, issue URL, and the next command
   (`/monorepo-harness-build <2_plan.md>`), then **stop**. This command does not implement: no
   source edits, no `3_memory.md` / `4_verify.md`.

The tracker is resolved from `--tracker`, then the plan's `tracker:` frontmatter, then by asking the
user once. This version implements `github` (GitHub Issues via the `gh` CLI) only; the harness never
asks for a token and never stores one.
