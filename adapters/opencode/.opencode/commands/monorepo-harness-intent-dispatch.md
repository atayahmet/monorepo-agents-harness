---
description: Turn an approved intent into phased tracker issues - check the intent's PR for an approval, record it, ask before filing work that may already be open, open one issue per phase, then ask before merging the intent PR; writing no spec, plan or task directory (no implementation)
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
5. **Check whether the work is already open, before anything is filed** (skill step 7). Pick 1-2
   distinctive words from the intent's proposed outcome and the phase titles, then run:

   ```
   bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
     --list-open --search <word> --tracker <platform> [--repo <owner/name>]
   ```

   `count=0` → carry on. Matches → show every row and ask **"This work may already be open — create
   these phases anyway?"** (create anyway / stop / re-split) and file nothing without a yes. Exit 3
   → say in those words that the check could **not** be run and why, then carry on. It reads only:
   never comment, label, assign or close what it finds.
6. For each approved phase, put the scope, workspace, verification command and the intent link in the
   issue body, then create the issue in this session (opencode has no subagent primitive — see
   `PORTABILITY.md`):

   ```
   bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
     --title "<issue title>" --body-file <file> --create
   ```

   **Write no file of your own**: no `task_<YYYY_MM_DD>_<phase_slug>/`, no `0_intent.md`, no
   `1_spec.md`, no `2_plan.md`, no `index.md` row. Those belong to `/monorepo-harness-spec` and
   `/monorepo-harness-plan`, which scope one task at a time; delete the throwaway body file when
   done. On exit 3 (`gh` missing or unauthenticated, or a confirmed `jira` / `linear` project), tell
   the user how to open the phase by hand, keep going with the remaining phases, and never report an
   issue that does not exist.
7. **Ask whether to merge the intent PR — the last step** (skill step 9). No `pr:` field → skip
   silently. Otherwise show the read-only summary first, then ask:

   ```
   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr <intent.md>
   ```

   **"Merge the intent PR (#N) now?"** (yes / no / later). Only on a **yes**, re-run it **with
   `--yes`**; the script refuses without it, and it re-checks the approval itself, so a PR nobody
   approved is never merged. Merge commit only — no `--admin`, no branch deletion, no
   squash/rebase. On 1, the PR is still open: report that and stop. On 3 (`gh` missing), nothing was
   merged — give them the PR URL.
8. Report each phase's issue URL, whether the open-work check could run, what happened to the intent
   PR (merged / left open with its URL / no `pr:` field), and the next command
   (`/monorepo-harness-spec <intent.md>`), then **stop**. This command does not implement and does not plan: no source edits, no task directory,
   no spec or plan.
