---
version: 0.4.0-rc.34
from: 0.4.0-rc.33
date: 2026-11-09
---

# Version 0.4.0-rc.34 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.33 to 0.4.0-rc.34, which adds a command
that builds the `AGENTS.md` files for one workspace.

## What changed

**`/monorepo-harness-agents-init <workspace> [--audit]` documents one workspace for agents.**
1. The agent surveys the instruction files already in the repo and ranks the directories that need
   their own file.
2. It shows a directory map and writes nothing until you say yes.
3. It writes a short workspace-root `AGENTS.md` with a routing table, plus nested `AGENTS.md` files near
   the code they describe.

Every `AGENTS.md` gets `CLAUDE.md` and `GEMINI.md` symlinks next to it. A run creates no task directory:
the approved map is the plan. Rules from your root `AGENTS.md` and `.agents/rules/*.md` are linked, never
copied, and an existing `AGENTS.md` changes only through a diff you approve. `--audit` reports stale or
drifting files and writes nothing.

**`core/scripts/agents-tree.sh` does the mechanics:**
- `survey`, `candidates` and `lint` only read.
- `link` only creates missing symlinks. It never replaces a plain file.
- `lint` fails on:
  - a file over its budget (80 lines for the workspace root, 150 for nested files);
  - a missing or wrong symlink;
  - a path reference that no longer exists;
  - a nested file its parent does not route to;
  - a block copied from the root `AGENTS.md` or `.agents/rules/*.md`.

**`scaffold-workspace-agents.sh` ends with a `next:` line** that names the workspaces with no
`AGENTS.md` of their own.

## Commands to run

- None. The new script, skill and command reach your project through new manifest rows, which the update
  flow's `install-harness.sh --sync-only` and `install-adapter.sh <agent> --refresh` steps apply.

## Manual follow-ups for the user

- Optional: run `bash .agents/monorepo-agents-harness/core/scripts/agents-tree.sh survey` once to see
  your current instruction files and their drift. It writes nothing. It reports:
  - plain `CLAUDE.md` or `GEMINI.md` files with no `AGENTS.md` (agents other than Claude Code or Gemini
    do not see them);
  - `AGENTS.md` files that have no `CLAUDE.md` / `GEMINI.md` symlink.

  The harness never moves a plain `CLAUDE.md` for you. Turning it into `AGENTS.md` plus symlinks is your
  choice.
- Optional: run `/monorepo-harness-agents-init <workspace>` for a workspace that has no `AGENTS.md` yet,
  and `/monorepo-harness-agents-init <workspace> --audit` for one that already has them.

## Release summary

- Added `/monorepo-harness-agents-init` on claude-code, opencode and codex, with
  `core/skills/agents-init/SKILL.md` and `core/scripts/agents-tree.sh` (issue #71).
- `scaffold-workspace-agents.sh` points to the new command for workspaces without an `AGENTS.md`.
- No change to `core/root-AGENTS.md`.
