---
version: 0.4.0-rc.49
from: 0.4.0-rc.48
date: 2026-11-28
---

# Version 0.4.0-rc.49 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.48 to 0.4.0-rc.49. This release says what
a checkout of an unreviewed branch runs, and makes `worktree.sh create` name the agent files that
differ from the main checkout (issue #102).

## What changed

- `create` may print `agent files differ ...`, `agent files: could not compare ...` or
  `agent files: not compared ...` on stderr. stdout and exit codes are unchanged.
- `docs/worktrees.md` has a new section, "What an unreviewed branch controls".

## Commands to run

- None.

## Manual follow-ups for the user

- Worktrees made before this release are not checked on their own. A worktree of a branch nobody
  reviewed runs that branch's bundle scripts, hooks and agent configuration: review it before you run
  a command, a commit or an agent session there. To list its differing agent files, run
  `worktree.sh create <slug>` again from your own checkout (add `--branch <name>` when the branch is
  not named like the slug): it changes nothing. This is the user's step: show it, do not run it for
  them.

## Release summary

- `create` names the differing agent files; the docs state what an unreviewed branch controls
  (issue #102).
