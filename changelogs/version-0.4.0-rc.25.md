# Upgrade notes — v0.4.0-rc.25

This release adds `argument-hint` to the Claude Code command frontmatter and a task-linked
`/monorepo-harness-spec` flow (`tracker-issue.sh --show`). There is **nothing to run** — no
manifest row was added and no command outside the normal sync is required.

## What changes

- **Claude Code**: the seven commands with arguments show hints in the slash menu. `review`, `ci`,
  `update` and `self-improve` remain argument-less.
- **Spec**: `/monorepo-harness-spec [<intent.md>] [<task-issue-url>]` can take a task link; a
  multi-phase dispatched intent asks which task to spec if no link is given. `tracker-issue.sh --show`
  reads an issue (GitHub via `gh`) read-only.

## How to pick up the change

If you have an installed harness/adapter, sync as usual:
1. `bash .agents/monorepo-agents-harness/core/scripts/install-harness.sh --sync-only` (or the upgrade flow)
2. `bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code --refresh` (and your other agents if needed)

No root `AGENTS.md` reconciliation is special for this release; the normal upgrade steps cover it.
