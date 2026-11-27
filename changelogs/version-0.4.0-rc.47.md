---
version: 0.4.0-rc.47
from: 0.4.0-rc.46
date: 2026-11-27
---

# Version 0.4.0-rc.47 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.46 to 0.4.0-rc.47. This release makes the
build arming and the memory gate see the other checkouts of the repository (issue #91).

## What changed

- A write into another checkout of the same repository (a worktree) arms the plan in that checkout.
- The memory gate warns about an unfinished build-stage task in another checkout. It never blocks for
  another checkout.
- The Codex `Stop` hook command passes that warning through.

## Commands to run

- None.

## Manual follow-ups for the user

- Only for projects with a `.codex/hooks.json`: an update never rewrites that file. Compare the `Stop`
  command with `.agents/monorepo-agents-harness/adapters/codex/.codex/hooks.json`. The end of the old
  command is `--json | jq 'if .decision == "block" then {"systemMessage":(.reason)} else empty end'`.
  Show the user the change and apply it to that one command only after they agree. Keep every other
  hook the project added. Codex may ask to review the changed hook again.

## Release summary

- Gates and other checkouts: arm by written path; warn, never block, for another checkout (issue #91).
- `docs/worktrees.md` "Gates and other checkouts"; run the task stages inside the worktree.
