---
version: 0.4.0-rc.50
from: 0.4.0-rc.49
date: 2026-11-28
---

# Version 0.4.0-rc.50 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.49 to 0.4.0-rc.50. This release makes
`worktree.sh` ignore the caller's git repository variables (`GIT_DIR` and the others), which git sets
for a hook and for a shell alias run in a linked worktree (issue #104).

## What changed

- `worktree.sh` drops those variables when it starts. `git -c` and CI settings stay.
- `.agents/worktree-setup.sh` gets the same environment: a git command in it answers for the new
  worktree.
- The script works on the repository of the current folder. A `GIT_DIR` or `git --git-dir` that
  names another repository is now ignored, without a warning.
- A repository reachable only through `GIT_DIR` now exits 3. Run the script from inside the
  repository.

## Commands to run

- None.

## Manual follow-ups for the user

- A worktree made before this release through a git alias or a hook can hold a wrong start commit, so
  `prune` may list it although you still use it. Read the dry run (`worktree.sh prune`) before you
  pass `--yes`. To keep a listed worktree, run `git worktree lock <path>`.
- If the project's `.agents/worktree-setup.sh`, or a hook or alias that calls `worktree.sh`, relied on
  the caller's `GIT_DIR`, `GIT_WORK_TREE` or `GIT_INDEX_FILE`, change it to name the repository
  itself. For another repository, run it from a folder of that repository (`git -C <dir> <alias>`).

## Release summary

- `worktree.sh` reads and writes only the folders it names, whatever git variables the caller has
  (issue #104).
