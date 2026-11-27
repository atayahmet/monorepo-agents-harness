---
version: 0.4.0-rc.48
from: 0.4.0-rc.47
date: 2026-11-27
---

# Version 0.4.0-rc.48 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.47 to 0.4.0-rc.48. This release stops a
harness worktree of a bare repository from supplying the copy list or the setup script (issue #95).

## What changed

Only in a bare repository, when `worktree.sh` runs inside a harness worktree:

- `create` copies nothing and says why.
- `create --setup` and `setup <slug>` exit 1. Nothing is created, copied or run.

## Commands to run

- None.

## Manual follow-ups for the user

- Only for a bare repository (`git worktree list` marks its first entry `(bare)`): run
  `create --setup` and `setup <slug>` from your own checkout, not from inside a harness worktree. If
  you have no checkout of your own, add one with
  `git worktree add <path> <branch>`, outside `~/.harness-worktrees` (or `HARNESS_WORKTREE_ROOT`),
  on a branch you trust. This is the user's step: never run it for them.

## Release summary

- Bare repository: a harness worktree never supplies the copy list or the setup script (issue #95).
