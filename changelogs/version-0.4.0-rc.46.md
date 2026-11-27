---
version: 0.4.0-rc.46
from: 0.4.0-rc.45
date: 2026-11-27
---

# Version 0.4.0-rc.46 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.45 to 0.4.0-rc.46. This release sets one
policy for the three per-workspace state files in worktrees (issue #90).

## What changed

- `lessons.md` is tracked and merged with `merge=union`. The sync adds `**/.agents/lessons.md merge=union`
  to `.gitattributes`.
- `session-log.md` and `todo.md` are git-ignored per checkout. The sync adds their two ignore lines to
  `.gitignore`.
- `worktree.sh create` and `setup` copy the main checkout's `session-log.md` into a worktree that has
  none, when git ignores it there. At their `.agents/` paths both files count as junk for `remove` and
  `prune`; a project's own file with the same name is kept.
- `audit-install.sh` warns when a project rule git-ignores a workspace `lessons.md`.

## Commands to run

- None.

## Manual follow-ups for the user

- If a project rule ignores `lessons.md` (for example `**/.agents/lessons.md` in `.gitignore`), remove
  that rule yourself, then commit the file. The sync adds lines and never removes one, so the rule
  stays until you remove it. `audit-install.sh` warns about each ignored workspace `lessons.md` until then.
- Commit the sync's `.gitignore` and `.gitattributes` changes. A new worktree checks out the committed
  files, so an uncommitted ignore line is not seen there.
- If `session-log.md` or `todo.md` is already tracked, it stays tracked. Decide whether to untrack it
  (`git rm --cached`). The harness does not untrack files.

## Release summary

- Per-workspace state in worktrees: `lessons.md` tracked with `merge=union`; `session-log.md` and
  `todo.md` per checkout and junk; `create` seeds the session log (issue #90).
- `create` no longer exits 4 for a tracked file in the copy list.
- `audit-install.sh` warns about an ignored workspace `lessons.md`.
