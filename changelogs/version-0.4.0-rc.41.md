---
version: 0.4.0-rc.41
from: 0.4.0-rc.40
date: 2026-11-26
---

# Version 0.4.0-rc.41 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.40 to 0.4.0-rc.41, which adds one
worktree root for every adapter and the `/monorepo-harness-worktree` command (issue #85).

## What changed

**`/monorepo-harness-worktree` keeps the worktrees the harness creates in one place.**
- Every worktree it creates lives at `~/.harness-worktrees/<repo-id>/<slug>`, outside the
  repository, the same for Claude Code, OpenCode and Codex. `<repo-id>` is `<name>-<hash8>` of the
  shared git directory, so every worktree of a repo gets the same id.
- `create <slug> [--base <ref>] [--branch <name>]` makes a new branch from the default branch (or
  `--base`) with no upstream, or checks out an existing branch. A re-run prints the existing path and
  changes nothing. A branch that several remotes have needs `checkout.defaultRemote`, as in git.
- `list [--all]` shows kind, slug, branch, state (`clean`/`dirty`/`missing`), merged, last commit and
  path. `--all` adds worktrees an agent tool made itself (`external`); the harness never touches those.
- `remove <slug> [--delete-branch] [--force]` refuses uncommitted work, ignored files outside the junk
  list (an `.env`) and unmerged commits unless you pass `--force`. `--delete-branch` deletes only a
  merged branch.
- `prune [--yes]` is a dry run until `--yes` and never deletes a branch.
- After `create`, open a new agent session in the printed path and run the project's own install
  there: ignored files such as `node_modules` and `.env` are not copied.
- `HARNESS_WORKTREE_ROOT` moves the root only for CI and containers where `$HOME` does not work. It
  must be an absolute path outside the repository.

Nothing changes until you run the command: no `.gitignore`, settings or `AGENTS.md` change.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step installs
  `core/scripts/worktree.sh` and `docs/worktrees.md`. The `install-adapter.sh <agent> --refresh` step
  copies the new `/monorepo-harness-worktree` entry point for each installed adapter.

## Manual follow-ups for the user

- Optional, only if you edit a worktree from a session in the main checkout: Claude Code and Codex
  need the root as an extra directory (`--add-dir ~/.harness-worktrees`, or
  `permissions.additionalDirectories` / `sandbox_workspace_write.writable_roots`). A new session
  started in the worktree needs no setup. The harness never changes these settings for you.
- Optional, Codex: its sandbox blocks `.git` writes in every checkout, so a commit needs
  `codex --add-dir "$(git rev-parse --git-common-dir)"` or an approved escalation. Review the harness
  hooks once in the main checkout ("Trust all"); after that they run in every worktree.
- Optional: list project-specific rebuildable output (for example `.terraform`) in
  `.agents/worktree-junk.txt`, so `remove` does not stop on it. An entry matches the ignored file or
  folder's own name, never a folder above it.

Details for all three: `.agents/monorepo-agents-harness/docs/worktrees.md`.

## Release summary

- Added `core/scripts/worktree.sh` (`path`, `create`, `list`, `remove`, `prune`) and its manifest row
  (issue #85).
- Added the `/monorepo-harness-worktree` entry point on claude-code, opencode and codex, with the same
  body; the claude-code menu hint lists the subcommands.
- Added `docs/worktrees.md`: layout, safety rules, junk list, what to do after `create`, per-adapter
  notes.
- Added the repo-local tests `tests/worktree.test.sh` and `tests/worktree-parity.test.sh`.
- No change to `core/root-AGENTS.md`, adapter settings files or `core/gitignore-fragment.txt`.
