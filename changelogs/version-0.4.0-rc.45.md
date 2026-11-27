---
version: 0.4.0-rc.45
from: 0.4.0-rc.44
date: 2026-11-27
---

# Version 0.4.0-rc.45 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.44 to 0.4.0-rc.45. This release tells
agents to create worktrees only through the harness script, and documents how to adopt the
worktrees they already made elsewhere (issue #89).

## What changed

- The root `AGENTS.md` template has a new Critical Gotcha 9. It applies only when a task needs its
  own checkout: the agent then runs `worktree.sh create <slug>` (the slug is the tracker key, else
  the task slug). It never runs `git worktree add` itself, never uses an agent tool's own worktree
  option, and never puts a worktree inside the repository or in a temp directory. When you ask for
  a specific tool or path, that is your call. The update's `AGENTS.md` merge step offers this gotcha.
- `prune` now keeps a worktree with no create record: one moved under the root with
  `git worktree move`, one made by hand there, or a detached one. Before, a fresh adopted worktree
  could be listed and removed. `remove <slug>` still removes such a worktree after its checks.
- The worktree docs have a new section, "Adopting a worktree made elsewhere".

## Commands to run

- None.

## Manual follow-ups for the user

- Optional: adopt the worktrees agents already made. In a terminal at the project root,
  `bash .agents/monorepo-agents-harness/core/scripts/worktree.sh list --all` shows them as
  `external` (for example under `.claude/worktrees/` or in a temp directory). For each one you want
  to keep, follow "Adopting a worktree made elsewhere" in
  `.agents/monorepo-agents-harness/docs/worktrees.md`: create the parent folder, run
  `git worktree move`, then `setup <slug>`. Close any agent session working in it first. A worktree
  whose folder is already gone is only a record; `git worktree prune` drops it.

## Release summary

- Root `AGENTS.md` Critical Gotcha 9 and an `agent-workflow` Edge-cases bullet: agents create
  worktrees with `worktree.sh create <slug>` only (issue #89).
- `prune` keeps a present worktree with no create record (adopted, made by hand, or detached).
- New docs section on adopting existing worktrees. No change to the entry points, the manifests,
  adapter settings files or `core/gitignore-fragment.txt`.
