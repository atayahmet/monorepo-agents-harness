---
version: 0.4.0-rc.52
from: 0.4.0-rc.51
date: 2026-11-28
---

# Version 0.4.0-rc.52 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.51 to 0.4.0-rc.52. This release shows how
to move work into a new worktree, and the harness writes no adapter setting for it (issue #99).

## What changed

- After `create`, `/monorepo-harness-worktree` shows the way to move into the worktree. You run it:
  - Claude Code: `/cd <path>` (the conversation continues);
  - Codex: exit, run `codex resume --all -C "<path>"` and pick the session (the conversation
    continues);
  - OpenCode: `opencode "<path>"` (a new session);
  - or start a new agent session in the path.
- The docs no longer suggest giving a session the whole worktree root.

## Commands to run

- None.

## Manual follow-ups for the user

- No setting is changed for you. If you opened the whole worktree root (`~/.harness-worktrees`) to a
  session by hand, you can remove that and move the session instead. Look for:
  - Claude Code: `permissions.additionalDirectories` in `.claude/settings.local.json`, or
    `--add-dir` in a shell alias or script;
  - Codex: `sandbox_workspace_write.writable_roots`, or `--add-dir` in a shell alias or script;
  - OpenCode: an `external_directory` rule for the root.
- `/cd` needs Claude Code 2.1.246 or later to apply the worktree's configuration at once.
- Review a branch before you move a session into its worktree. A moved session is not a new one:
  - it keeps the earlier conversation, and the branch's hooks get the path of the session record;
  - on Claude Code, the harness hooks still run the scripts of the checkout the session started in.

## Release summary

- Move work into a worktree with one step; the harness widens no permissions for it (issue #99).
