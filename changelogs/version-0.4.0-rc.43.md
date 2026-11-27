---
version: 0.4.0-rc.43
from: 0.4.0-rc.42
date: 2026-11-27
---

# Version 0.4.0-rc.43 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.42 to 0.4.0-rc.43, which adds a
project-owned setup step after `/monorepo-harness-worktree create` (issue #88).

## What changed

**A new worktree can get the project's ignored files and install step.**
- `.agents/worktree-copy.txt` (optional, the project's): files to copy from the main checkout into
  every new worktree, one path or glob per line (e.g. `.env`, `apps/*/.env.local`). It runs no code,
  so `create` applies it every time. Only files git ignores are copied, with their mode.
- `.agents/worktree-setup.sh` (optional, the project's): an executable run in the new worktree (e.g.
  `pnpm install`). It runs only on `create --setup` or the new `setup <slug>`. The agent passes
  either one only when the developer typed it.
- Both files are read from the main checkout, never from the new worktree's branch.
- New exit code 4: the worktree exists, but the copy or setup step failed. The path is still printed;
  `setup <slug>` retries both steps.
- `remove` and `prune` no longer stop on an ignored file that is byte-identical to the main
  checkout's file at the same path (a copied `.env`).
- Without the two files, nothing changes.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step replaces `core/scripts/worktree.sh`
  and `docs/worktrees.md`, and `install-adapter.sh <agent> --refresh` replaces the
  `/monorepo-harness-worktree` entry points.

## Manual follow-ups for the user

- Optional: to have new worktrees set up, add `.agents/worktree-copy.txt` and/or
  `.agents/worktree-setup.sh` (`chmod +x`) to the project and commit them.
  `.agents/monorepo-agents-harness/docs/worktrees.md`, "After `create`", has examples. The harness
  never creates these files.
- Optional: a project script that calls `worktree.sh create` should treat exit 4 as "the worktree
  exists, but a step after it failed" (the path is still on stdout).
- Codex: start a new session after the update so it loads the updated `monorepo-harness-worktree`
  skill.

## Release summary

- `core/scripts/worktree.sh`: copy step, setup step, `create --setup`, `setup <slug>`, exit 4,
  byte-identical ignored files are recoverable (issue #88).
- The three `/monorepo-harness-worktree` entry points, `docs/worktrees.md`, README, PORTABILITY and
  the adapter READMEs updated.
- No change to `core/root-AGENTS.md`, the manifests, adapter settings files or
  `core/gitignore-fragment.txt`.
