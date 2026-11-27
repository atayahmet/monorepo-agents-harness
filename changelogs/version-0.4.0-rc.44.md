---
version: 0.4.0-rc.44
from: 0.4.0-rc.43
date: 2026-11-27
---

# Version 0.4.0-rc.44 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.43 to 0.4.0-rc.44. This release changes
`/monorepo-harness-worktree remove` and `prune` so that they read the project's junk list from the
main checkout (issue #93).

## What changed

- `remove` and `prune` now read `.agents/worktree-junk.txt` from the main checkout, the same place
  as `.agents/worktree-copy.txt` and `.agents/worktree-setup.sh`. Before, they read it from the
  checkout the script ran in, so a branch could add `.env` to its own list and `remove` would delete
  an `.env` in another worktree without `--force`.
- When you run the script from a worktree whose own list differs, stderr says the main checkout's
  list is used.
- A bare repository has no main checkout, so the checkout you run the script in stands in. The
  exception is a harness worktree: run from one, only the default list applies, and stderr says so.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step replaces `core/scripts/worktree.sh`
  and `docs/worktrees.md`.

## Manual follow-ups for the user

- Optional: if the project uses `.agents/worktree-junk.txt`, check that the main checkout's copy has
  every entry you rely on. A list that exists only on another branch no longer counts. `remove`
  then refuses the files it used to treat as junk, and `prune` keeps those worktrees. In a bare
  repository, run `remove` and `prune` from your own checkout, not from a harness worktree.

## Release summary

- `core/scripts/worktree.sh`: the junk list is read from the main checkout, with a note when the
  current checkout's copy differs (issue #93).
- `docs/worktrees.md` "Junk list" and "After `create`" updated.
- No change to the entry points, `core/root-AGENTS.md`, the manifests, adapter settings files or
  `core/gitignore-fragment.txt`.
