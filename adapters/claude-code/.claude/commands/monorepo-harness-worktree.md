---
description: Create, set up, list, remove or prune the git worktrees the harness owns, in one root outside the repository (~/.harness-worktrees) that every adapter shares
argument-hint: "[list [--all] | path <slug> | create <slug> [--base <ref>] [--branch <name>] [--setup] | setup <slug> | remove <slug> [--delete-branch] [--force] | prune [--yes]]"
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
- Ignored files (`node_modules`, `.env`, build output) are not checked out. `create` copies the
  ones the project lists in `.agents/worktree-copy.txt` by itself; show what the script reported
  as not copied. Pass `--setup`, or run `setup <slug>`, only when the developer typed it in this
  turn: it runs the project's `.agents/worktree-setup.sh` (code, often a long install). Otherwise
  relay the next step the script printed: `setup <slug>` to run in a terminal, or the project's
  own install (e.g. `pnpm install`) and any `.env` brought over by hand.
  Never run an install yourself.
- `remove`: never add `--force` or `--delete-branch` unless the developer typed them in this turn.
  On a refusal, show the reasons the script printed and stop.
- `prune`: run it without `--yes` and show the candidates and the kept reasons. Then ask
  "Remove these N worktrees?" and run `prune --yes` only on an explicit yes in this turn.
- Never move, remove or recreate an `external` worktree (one the harness did not create).
- Exit 1: the script refused; report its reason. Exit 3 is a setup problem (for example the root
  is not writable, or `HARNESS_WORKTREE_ROOT` points inside the repository): report it and never
  retry with `--force`.
- Exit 4: the worktree exists at the printed path, but the copy or setup step failed. Show the
  path and the reasons, and suggest `setup <slug>` once the cause is fixed. Never retry on your own.
