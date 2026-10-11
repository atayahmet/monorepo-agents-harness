---
version: 0.4.0-rc.19
from: 0.4.0-rc.18
date: 2026-10-11
---

# Version 0.4.0-rc.19 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.18 to 0.4.0-rc.19. This release adds a
guard for a claude-code pointer file that exists but no longer imports `AGENTS.md` — the whole root
`AGENTS.md` (checklist, gotchas, KB-first rule) is invisible to the agent when that line is missing.

## What changed

The claude-code adapter reads the single source of truth through a thin root `CLAUDE.md` that imports
`AGENTS.md` with `@AGENTS.md`. That file is a `tmpl` manifest row, so an existing file is never
overwritten. A repo that already had its own `CLAUDE.md` — with no `@AGENTS.md` line — kept it, and
Claude Code then loaded none of `AGENTS.md`.

`core/scripts/audit-install.sh` now reports this: for every adapter `tmpl`/`merge` file, it reads the
`@<path>` import the shipped template carries and flags the project's file when the import is missing
(the check is template-driven, so a future pointer-based adapter is covered too).
`core/scripts/install-adapter.sh` names the same one-line fix in its `Needs you:` list when an
existing config file lacks the template's import. Neither ever edits your file.

Files: `core/scripts/audit-install.sh` (new `check_pointer_imports` + call site);
`core/scripts/install-adapter.sh` (import-aware `Needs you:` note);
`core/skills/harness-update/SKILL.md` (step 9.5 `@AGENTS.md` import-gap bullet);
`adapters/claude-code/INSTALL.md` and `PORTABILITY.md` (the rule). No manifest row changes.

## Commands to run

- None by hand. There is nothing to install: the scripts and docs ship inside `core/` and
  `adapters/`, carried by the existing install rows.

## Manual follow-ups for the user

- **Only if you keep your own root `CLAUDE.md`:** make sure it imports the single source of truth. If
  it has no `@AGENTS.md` line, add one line `@AGENTS.md` at the end of the file (or merge
  `CLAUDE.md.harness-proposed`). The audit reports it by exact path on the next check, so nothing is
  hidden if you skip this now.

## Release summary

- `core/scripts/audit-install.sh`: new template-driven `check_pointer_imports` gap (closes #31).
- `core/scripts/install-adapter.sh`: warns with the one-line fix, still never edits the file.
- `core/skills/harness-update/SKILL.md`: step 9.5 documents the `@AGENTS.md` import gap.
- `adapters/claude-code/INSTALL.md`, `PORTABILITY.md`: the pointer must import `AGENTS.md`.
- `tests/audit-import.test.sh`: repo-local test for the guard.
