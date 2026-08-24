---
version: 1.1.0
from: 1.0.0
date: 2026-08-24
---

# Version 1.1.0 Upgrade Instructions

You are upgrading the turborepo-agent-harness from 1.0.0 to 1.1.0.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
the installed `turborepo-harness-template/` directory. Directories ending in `/`
should be copied recursively and replace the existing directory entirely.

- `changelogs/version-1.1.0.md` -> `changelogs/version-1.1.0.md`
- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `core/scripts/` -> `core/scripts/` (recursive directory copy)
- `core/skills/` -> `core/skills/` (recursive directory copy)
- `core/governance/` -> `core/governance/` (recursive directory copy)
- `core/workspace-agents-template/` -> `core/workspace-agents-template/` (recursive directory copy)
- `adapters/codex/` -> `adapters/codex/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

These files were replaced by the new `/tah:update` and `/tah-update` command
locations. Remove them only if they exist; do not fail if they are missing.

- `.claude/commands/turborepo-harness/update-check.md`
- `.opencode/commands/turborepo-harness-update-check.md`

## Commands to run

Run the workspace scaffold script to re-seed per-workspace state. Existing files
are never overwritten, so this is safe to run repeatedly.

```bash
bash core/scripts/scaffold-workspace-agents.sh
```

## Manual follow-ups for the user

The following steps are intentionally not automated because they touch
user-owned configuration files. Present them to the user after the upgrade.

- Merge any new rows from the fresh `AGENTS.md` template into the repo-root `AGENTS.md`.
- Re-apply adapter config merges per the relevant adapter install guide:
  - claude-code -> `adapters/claude-code/INSTALL.md`
  - opencode -> `adapters/opencode/INSTALL.md`
  - codex -> `adapters/codex/INSTALL.md`

## Release summary

- Harness versioning infrastructure added: `core/VERSION`, `CHANGELOG.md`, and
  `core/scripts/harness-update.sh`.
- `/tah:update` (Claude Code) and `/tah-update` (opencode/Codex CLI) commands
  added for checking and upgrading the harness.
- `/tah-build` manual plan/spec build trigger added.
- Codex CLI adapter added under `adapters/codex/`.
- Task artifacts moved out of the docs app into each workspace's
  `.agents/artifacts/` tree with a mandatory searchable `index.md`.
- Docs-placement guard capability removed entirely.
