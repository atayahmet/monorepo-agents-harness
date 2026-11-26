---
name: monorepo-harness-worktree
description: Create, list, remove or prune the git worktrees the harness owns, in one root outside the repository (~/.harness-worktrees) that every adapter shares. Use when the user types /monorepo-harness-worktree, or asks to create, list, remove or clean up a harness worktree.
---

Manage the harness worktrees with
`bash .agents/monorepo-agents-harness/core/scripts/worktree.sh <args>`
(`.agents/monorepo-agents-harness/docs/worktrees.md`). Pass the developer's arguments through.
No arguments: run `list`.

- Never build a worktree path and never call `git worktree` for a harness worktree yourself. The
  script owns the root (`~/.harness-worktrees/<repo-id>/<slug>`) and every safety rule.
- After `create`, show the printed path and tell the developer to open a new agent session in it.
  This session stays in its own directory. A new session in the worktree needs no setup; editing
  the worktree from this session needs the adapter's extra-directory setting (see the docs).
- Also say that ignored files are not copied: `node_modules`, `.env` and build output are not in
  the new worktree. The developer runs the project's own install there (e.g. `pnpm install`) and
  brings over any `.env` by hand. Never run an install yourself as part of `create`.
- `remove`: never add `--force` or `--delete-branch` unless the developer typed them in this turn.
  On a refusal, show the reasons the script printed and stop.
- `prune`: run it without `--yes` and show the candidates and the kept reasons. Then ask
  "Remove these N worktrees?" and run `prune --yes` only on an explicit yes in this turn.
- Never move, remove or recreate an `external` worktree (one the harness did not create).
- Exit 1: the script refused; report its reason. Exit 3 is a setup problem (for example the root
  is not writable, or `HARNESS_WORKTREE_ROOT` points inside the repository): report it and never
  retry with `--force`.
