---
version: 0.4.3
from: 0.4.2
date: 2026-08-26
---

# Version 0.4.3 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.2 to 0.4.3.

This release renames the harness-plumbing command/skill namespace from `/tah-*`
to `/monorepo-harness-*` across all three adapters (claude-code, opencode,
Codex CLI). The old `tah-*` prefix was a leftover from the project's
pre-0.4.0 name (`turborepo-agent-harness`); this finishes aligning the
command namespace with the current project name, `monorepo-agents-harness`.
There are no changes to the plan/spec artifact layout or the update engine
itself — only command/skill file names and their slash-command triggers.

> **Breaking command rename.** The old `/tah-build`, `/tah:update`, and
> `/tah-update` commands stop working once the old files are deleted. Users
> must start typing `/monorepo-harness-build`, `/monorepo-harness:update`
> (claude-code), and `/monorepo-harness-update` (opencode/Codex CLI) instead.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`. Directories ending in `/` should be copied
recursively and replace the existing directory entirely.

- `core/VERSION` -> `core/VERSION`
- `VERSION` -> `VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `changelogs/version-0.4.3.md` -> `changelogs/version-0.4.3.md`
- `README.md` -> `README.md`
- `INSTALL.md` -> `INSTALL.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `core/skills/agent-workflow/SKILL.md` -> `core/skills/agent-workflow/SKILL.md`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`
- `adapters/claude-code/` -> `adapters/claude-code/` (recursive directory copy)
- `adapters/opencode/` -> `adapters/opencode/` (recursive directory copy)
- `adapters/codex/` -> `adapters/codex/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

The recursive adapter copies above do not remove files that no longer exist in
the new bundle. Delete the old `tah-*` command/skill files explicitly:

- `.agents/monorepo-agents-harness/adapters/claude-code/.claude/commands/tah-build.md`
- `.agents/monorepo-agents-harness/adapters/claude-code/.claude/commands/tah/`
- `.agents/monorepo-agents-harness/adapters/opencode/.opencode/commands/tah-build.md`
- `.agents/monorepo-agents-harness/adapters/opencode/.opencode/commands/tah-update.md`
- `.agents/monorepo-agents-harness/adapters/codex/.agents/skills/tah-build/`
- `.agents/monorepo-agents-harness/adapters/codex/.agents/skills/tah-update/`

## Commands to run

- None. This release only renames files and updates documentation text; no
  scripts, hooks, or artifact-layout paths changed.

## Manual follow-ups for the user

The project-root command/skill files (outside the bundle directory) are
user-owned and must be swapped by hand, per adapter in use:

- **Claude Code:**
  - Delete `.claude/commands/tah-build.md` and `.claude/commands/tah/`.
  - Copy `.claude/commands/monorepo-harness-build.md` and the
    `.claude/commands/monorepo-harness/` directory (containing `update.md`) from
    the new bundle's `adapters/claude-code/.claude/commands/`.
  - The commands now register as `/monorepo-harness-build` and
    `/monorepo-harness:update`.
- **opencode:**
  - Delete `.opencode/commands/tah-build.md` and `.opencode/commands/tah-update.md`.
  - Copy `.opencode/commands/monorepo-harness-build.md` and
    `.opencode/commands/monorepo-harness-update.md` from the new bundle's
    `adapters/opencode/.opencode/commands/`.
  - The commands now register as `/monorepo-harness-build` and
    `/monorepo-harness-update`.
- **Codex CLI:**
  - Delete `.agents/skills/tah-build/` and `.agents/skills/tah-update/`.
  - Copy `.agents/skills/monorepo-harness-build/` and
    `.agents/skills/monorepo-harness-update/` from the new bundle's
    `adapters/codex/.agents/skills/`.
  - The skills now surface as `/monorepo-harness-build` and
    `/monorepo-harness-update`.

## Release summary

- Renamed the harness-plumbing command/skill namespace from `/tah-*` to
  `/monorepo-harness-*` across claude-code, opencode, and Codex CLI.
- Renamed the backing files: `tah-build.md` -> `monorepo-harness-build.md`,
  `tah/update.md` -> `monorepo-harness/update.md`, `tah-update.md` ->
  `monorepo-harness-update.md`, `tah-build/` -> `monorepo-harness-build/`,
  `tah-update/` -> `monorepo-harness-update/`.
- Updated `README.md`, `INSTALL.md`, `PORTABILITY.md`, every adapter
  `README.md`/`INSTALL.md`, and `core/skills/agent-workflow/SKILL.md` /
  `core/skills/harness-update/SKILL.md` to reference the new command names.
- No changes to the plan/spec artifact layout, update engine, hooks, or
  scripts.
