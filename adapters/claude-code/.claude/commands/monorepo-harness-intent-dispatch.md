---
description: Turn an approved intent into phased tracker issues - check the intent's PR for an approval, record it, and open one issue per phase, writing no spec, plan or task directory (no implementation)
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/intent-workflow/SKILL.md`, section
**"Workflow — Dispatch"**, exactly. The intent path is the argument the user typed after the command
(`/monorepo-harness-intent-dispatch <intent.md>`); if it is missing, ask which approved intent to use.

1. Check the approval **first, PR before file**. Read the intent's `pr:` field, then run
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md> --pr <ref>`
   when it names a GitHub PR, and the same command **without** `--pr` otherwise. If it exits non-zero,
   report the reason and stop — write nothing, create nothing. If it reports `source: PR` while the
   file still says `pending`, set `status: approved` and append the `## Review` section, taking the
   reviewer and date from the script's output — never invent them. If the file is already approved,
   change nothing.
2. If the intent has a `pr:` field, push the commit carrying its `## Review` section to that PR's
   branch (`git push <remote> <sha>:<branch>`) and report the remote ref. No `pr:` field → skip.
3. Confirm the workspace scope (primary + secondary) and propose 3-5 phases — a phase is worth its
   own review. Ask "Start these N phases?" and write nothing before an explicit yes.
4. Find the tracker and **confirm it with the developer** before any issue exists (skill step 6):
   use `<repo-root>/.agents/tracker.md` if it records one, otherwise run
   `bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh --infer` and show the result,
   then ask — with the inferred platform, **a different platform**, and `--tracker` all on the table.
   Write the cache only on their answer. If the platform is not `github`, `jira` or `linear`, ask how
   their team files work in it and record that. **The harness repo is never a target and never an
   option.** Only `github` is implemented (GitHub Issues via `gh`); `jira` / `linear` hand off to the
   developer's own tooling, and the harness never asks for a token.
5. For each approved phase, put the scope, workspace, verification command and the intent link in the
   issue body, then dispatch the `tracker` subagent (`.claude/agents/tracker.md`) once per phase. It
   runs exactly this and returns the issue URL:

   ```
   bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
     --title "<issue title>" --body-file <file> --create
   ```

   **Write no file of your own**: no `task_<YYYY_MM_DD>_<phase_slug>/`, no `0_intent.md`, no
   `1_spec.md`, no `2_plan.md`, no `index.md` row. Those belong to `/monorepo-harness-spec` and
   `/monorepo-harness-plan`, which scope one task at a time; delete the throwaway body file when
   done. If the subagent reports exit 3 (`gh` missing or unauthenticated, or a confirmed `jira` /
   `linear` project), tell the user how to open the phase by hand, keep going with the remaining
   phases, and never report an issue that does not exist.
6. Report each phase's issue URL and the next command (`/monorepo-harness-spec <intent.md>`), then
   **stop**. This command does not implement and does not plan: no source edits, no task directory,
   no spec or plan.
