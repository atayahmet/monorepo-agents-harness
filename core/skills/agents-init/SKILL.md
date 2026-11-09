---
name: agents-init
description: Build or audit the nested AGENTS.md tree for one workspace - survey the repo's existing instruction files, rank candidate directories, show a directory map and wait for approval, then write a short workspace-root AGENTS.md that routes to nested files near the code, add CLAUDE.md/GEMINI.md symlinks, and lint the result. Use when the user types /monorepo-harness-agents-init, asks to document a workspace for agents, to add AGENTS.md files across a workspace, or to check a workspace's AGENTS.md files for drift (--audit).
---

# Workspace AGENTS.md Tree

The agent writes the content. `core/scripts/agents-tree.sh` does the repeatable mechanics (survey,
candidates, link, lint). Call it as
`bash .agents/monorepo-agents-harness/core/scripts/agents-tree.sh <subcommand>`; its header documents
every option and exit code.

**Canonical form (fixed by the harness, never guessed):** `AGENTS.md` is the file; `CLAUDE.md` and
`GEMINI.md` next to it are symlinks to it (`PORTABILITY.md`). A plain nested `CLAUDE.md` is **drift**:
report it, never copy its shape.

**The approved map is the plan.** A run creates no task directory and no spec/plan/build stages. The
developer's explicit yes to the map in Step 3 is the approval. A developer who wants the full workflow
starts it with `/monorepo-harness-spec`.

## Arguments

`<workspace> [--audit]`. `<workspace>` is a path (`apps/web`), a package name, or a short alias.
`--audit` runs Step 1 and Step 6 only and **writes nothing**.

## Workflow

### Step 0 — Resolve the workspace and load the rules
1. Resolve `<workspace>` to a directory with
   `bash .agents/monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh --workspaces`
   (fall back to `apps/*` and `packages/*`; match a package name through its `package.json`). If it
   is ambiguous, ask. Never guess.
2. Read the root `AGENTS.md` and every `.agents/rules/*.md`. These rules are **linked** from the new
   files, never copied into them.
3. Read the workspace's `package.json` (or equivalent) for its scripts: these become the commands
   section, narrowest verification first.

### Step 1 — Survey the convention
Run `agents-tree.sh survey`. From it, write a short convention summary for the developer:
- common `##` sections across existing `AGENTS.md` files, their typical size and depth;
- drift: plain `CLAUDE.md`/`GEMINI.md` without `AGENTS.md`, missing or wrong symlinks.

Drift is reported only. Moving plain `CLAUDE.md` files to `AGENTS.md` plus symlinks is a separate,
opt-in step and out of scope here. With `--audit`, also run `agents-tree.sh survey --workspace <ws>`
and go to Step 6.

### Step 2 — Find candidate directories
Run `agents-tree.sh candidates <ws>` (add `--limit N` for large workspaces). The score adds source
files, an index/barrel file (a public surface), its own tests, importers from elsewhere, and a
framework name hint (store, routes, config, locales, generated...). Read the code of the top entries
before you propose anything: the ranking finds areas, not their rules.

### Step 3 — Show the map and wait
Propose the tree as one table:

| Directory | Covers | New / update |
|---|---|---|
| `<ws>/` (workspace root) | scope, commands, workspace gotchas, routing table | new |
| `<ws>/src/store/` | state boundaries, selectors, traps | new |

Choose the fewest directories that hold distinct rules. A directory whose rules fit in one line of
its parent's file does not get its own file. **Stop here. Write nothing until the developer
explicitly says yes.** They can add, drop or merge entries; show the revised map before going on.

### Step 4 — Write the files
- **Workspace-root `AGENTS.md`** (budget 80 lines): scope (what lives here, what does not), commands
  (narrowest first, e.g. `pnpm --filter <name> test`), workspace-wide gotchas, and a **routing table**
  that lists every nested file by its relative path (`src/store/AGENTS.md`).
- **Nested `AGENTS.md`** (budget 150 lines): boundaries (what may import what), patterns to follow,
  traps, and the files to read first, with real paths.
- Say only what an agent cannot see quickly in the code. No empty or placeholder files.
- Rules that already live in the root `AGENTS.md` or `.agents/rules/*.md` get a one-line link, never
  a copy.
- An **existing** `AGENTS.md` is never overwritten: show the diff and apply it only after a yes.
- Write every file in English.

### Step 5 — Link
Run `agents-tree.sh link <ws>`. It adds `CLAUDE.md` and `GEMINI.md` symlinks next to every
`AGENTS.md` and leaves any plain file alone (report what it printed with `!`).

### Step 6 — Lint
Run `agents-tree.sh lint <ws>` (`--root-max` / `--nested-max` override the 80 / 150 budgets). It
fails on an over-budget file, a missing or wrong symlink, a broken path reference, a nested file its
parent does not route to, and a block copied from the root `AGENTS.md` or `.agents/rules/*.md`.
Fix each `FAIL` and re-run until it exits 0. A path that only looks like one can carry
`agents-tree:ignore` on its line. With `--audit`, report the failures and the survey drift, and fix
nothing.

### Step 7 — Report
List the files written or updated, the lint result, and the drift that was left alone. Commit the
files as the project's root `AGENTS.md` requires.

## Hard nevers
- Never write a file before the developer approves the map.
- Never overwrite an existing `AGENTS.md`, `CLAUDE.md` or `GEMINI.md` silently.
- Never copy rules from the root `AGENTS.md` or `.agents/rules/*.md`; link them.
- Never write a placeholder file, and never write anything during `--audit`.
- Never change the root `AGENTS.md` here (that is `agents-md-merge`).
