---
version: 0.4.0-rc.6
from: 0.4.0-rc.5
date: 2026-09-28
---

# Version 0.4.0-rc.6 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.5 to 0.4.0-rc.6, which adds two
questions to `/monorepo-harness-intent-dispatch`: one before it files anything, one after.

## What changed

**Before filing:** the command now checks whether that work is **already open** on your project
tracker and shows you every match, so the same intent is not filed twice. The check is read-only —
it comments, labels, assigns and closes nothing — and it is advisory: no issue is created without an
explicit yes in the current turn.

**After filing:** once every issue URL has been reported, the command asks **"Merge the intent PR
(#N) now?"**. A yes merges it with a merge commit; anything else changes nothing. The merge runs
last on purpose, so an unapproved PR is never hidden behind a dispatch that failed later. The script
re-checks that the PR really carries an approving review, never passes `--admin`, and never deletes
the branch.

**One behavior change to be aware of:** an approving review is now read per reviewer with the newest
review winning. At least one reviewer's latest review must be `APPROVED`, and no reviewer may have
`CHANGES_REQUESTED` as their latest. Previously any single historical `APPROVED` passed the gate, so
an approval that was later retracted still let dispatch through.

## Commands to run

- None. No file is added to the bundle or to an adapter, so there is no manifest row to add — the
  normal update sync (`/monorepo-harness-update`) installs the changed
  `core/scripts/task-state.sh`, `core/scripts/tracker-issue.sh`,
  `core/skills/intent-workflow/SKILL.md`, `core/governance/intents/AGENTS.md` and the three dispatch
  entry points, and the adapter refresh places the `tracker` subagent note.

## Manual follow-ups

- **If an intent's approval was retracted after the fact, re-run `/monorepo-harness-intent` on it** or
  re-open the PR for review. The gate now refuses it, which is the point: an intent whose reviewer
  asked for changes is not approved work.
- **If you already have open issues for work a new intent covers, expect the duplicate check to
  find them.** Nothing is commented on or closed automatically — you choose "stop" or "re-split" and
  the command files nothing.

## Verify

```bash
# 1. the open-work check is read-only and finds nothing on a quiet board
bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh \
  --list-open --search <a-distinctive-word>

# 2. the merge decision is a dry run unless you pass --yes
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr \
  <your-intent.md>
```

Expect `open-match count=0` (or your open issues) from the first, and a `would merge` summary with no
GitHub write from the second. Without `gh` authenticated, both exit 3 and say so — a skip you can see.
