---
description: Turn an approved intent into phased tracker issues - check the intent's PR for an approval, record it, ask before filing work that may already be open, ask whether 2+ phases should be grouped under one parent epic issue, file the epic and its child issues, record every number back on the intent, then ask before merging the intent PR; writing no spec, plan or task directory (no implementation)
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/intent-workflow/SKILL.md`, section
**"Workflow — Dispatch"**, exactly. The intent path is the argument the user typed after the command
(`/monorepo-harness-intent-dispatch <intent.md>`); if it is missing, ask which approved intent to use.

1. Check the approval **first, PR before file**. Read the intent's `pr:` field, then run
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md> --pr <ref>`
   when it names a pull request **on any forge** — GitHub, GitLab, Bitbucket, Gitea — and the same
   command **without** `--pr` only when there is no `pr:` field at all. The script resolves the forge
   and probe-verifies a real read through that platform's CLI or REST; do not assume `gh` or GitHub.
   If it exits non-zero, report the reason and stop — write nothing, create nothing. If it reports
   `source: PR` while the file still says `pending`, set `status: approved` and append the `## Review`
   section, taking the reviewer and date from the script's output — never invent them. If the file is
   already approved, change nothing. If the script says the approval is **UNKNOWN** (it could not
   read the PR, and it names the MCP server or project skill that could), read it with that mechanism
   using your own tools and apply the same rule — and if you cannot, say so and stop. **Never** re-run
   without `--pr` to get a "yes" out of the file.
2. If the intent has a `pr:` field, push the commit carrying its `## Review` section to that PR's
   branch (`git push <remote> <sha>:<branch>`) and report the remote ref. No `pr:` field → skip.
3. Confirm the workspace scope (primary + secondary) and propose 3-5 phases — a phase is worth its
   own review. Ask **"Start these N phases?"** and write nothing before an explicit yes.
   **At 2 or more phases, ask about the epic in the same breath:** add an **Epic** row to the table
   (title + tracker) and ask **"Start these N phases under an epic?"** (`yes` / `no epic` / `edit` /
   `fewer`). At **1 phase** there is no epic, no row and no extra question — never invent a second
   phase to justify one. Propose the intent's own short title as the epic title.
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
   → say in those words that the check could **not** be run and why, then carry on. Unknown is never
   "nothing is open", so do not answer the question yourself either. It reads only: never comment,
   label, assign or close what it finds.
6. **File the epic, or reuse one — only if step 3 asked and got a "yes", and before any phase exists.**
   Reuse in this order: the epic named in the intent's newest `## Dispatch` block (create nothing —
   this is what makes a re-run safe), then an issue the developer nominates from step 5's rows in this
   turn (create nothing). Only if neither, create it with the command in step 7 and no `--parent`, and
   **keep the `number=` it prints** — every phase links to it. Exit 3 from that create (a
   `jira`/`linear` tracker, no `gh`, or a `gh` too old for `--parent`) → **no epic; carry on and file
   the phases flat.** Never block a phase on its parent. Never match a candidate yourself, and never
   link children under an issue the developer did not name this turn.
7. For each approved phase, put the scope, workspace, verification command and the intent link in the
   issue body, then create the issue in this session (opencode has no subagent primitive — see
   `PORTABILITY.md`) — once for the epic if there is one, then once per phase, passing
   `--parent <epic number>` on **every** phase when there is an epic and on none when there is not:

   ```
   bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
     --title "<issue title>" --body-file <file> [--parent <epic number>] --create
   ```

   Keep both lines the script prints: `tracker-issue: created number=<n>` and the URL (which is last).

   Then **append the intent's `## Dispatch` block**: today's date, the tracker, the `Epic:` line
   (omitted entirely when there is no epic) and one `Phases:` line per phase slug with the `#<number>`
   and URL that came back, or `no issue yet (<reason>)` for a phase that was not filed. Append a new
   block; never rewrite the previous one. Record **only what the script printed** — never a number
   inferred from a title or carried over from an earlier turn. Format and full rules:
   `core/governance/intents/AGENTS.md`.

   **Write no other file of your own**: no `task_<YYYY_MM_DD>_<phase_slug>/`, no `0_intent.md`, no
   `1_spec.md`, no `2_plan.md`, no `index.md` row. Those belong to `/monorepo-harness-spec` and
   `/monorepo-harness-plan`, which scope one task at a time; delete the throwaway body files when
   done. On exit 3 (`gh` missing or unauthenticated, an old `gh` that cannot set a parent, or a
   confirmed `jira` / `linear` project), tell the user how to open the phase by hand, record it as
   `no issue yet`, keep going with the remaining phases, and never report an issue that does not
   exist. Exit 1 means nothing was created — including a refused `--parent` link, which is atomic — so
   do not name that phase as filed.
8. **Ask whether to merge the intent PR — the last step** (skill step 9). No `pr:` field → skip
   silently. Otherwise show the read-only summary first, then ask:

   ```
   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr <intent.md>
   ```

   **"Merge the intent PR (#N) now?"** (yes / no / later). Only on a **yes**, re-run it **with
   `--yes`**; the script refuses without it, and it re-checks the approval itself, so a PR nobody
   approved is never merged. Merge commit only — no `--admin`, no branch deletion, no
   squash/rebase. On **1**, the harness looked and refused: the PR is still open, report that and
   stop. On **3**, the harness could not read the PR at all, so the approval is unknown and **nothing
   was merged** — the script names the MCP server or project skill that could reach it. Read the PR
   that way with your own tools, merge only on a fresh yes and only with a merge commit, or give them
   the PR URL. Never report a merge that did not happen.
9. Report the epic (number and URL, or "no epic", or "no issue yet" with the reason), each phase's
   issue number and URL, the `## Dispatch` block you appended, whether the open-work check could run,
   what happened to the intent PR (merged / left open with its URL / no `pr:` field), and the next
   command (`/monorepo-harness-spec <intent.md>`), then **stop**. This command does not implement and does not plan: no source edits, no task directory,
   no spec or plan.
