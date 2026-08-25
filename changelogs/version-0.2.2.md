---
version: 0.2.2
from: 0.2.1
date: 2026-08-25
---

# Version 0.2.2 Upgrade Instructions

You are upgrading the turborepo-agent-harness from 0.2.1 to 0.2.2.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
the installed `turborepo-harness-template/` directory. Directories ending in `/`
should be copied recursively and replace the existing directory entirely.

- `changelogs/version-0.2.2.md` -> `changelogs/version-0.2.2.md`
- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `INSTALL.md` -> `INSTALL.md`
- `README.md` -> `README.md`
- `changelogs/README.md` -> `changelogs/README.md`
- `changelogs/version-0.2.0.md` -> `changelogs/version-0.2.0.md`

## Files to delete from the installed bundle (only if they exist)

Nothing to delete in this release.

## Commands to run

No commands to run in this release.

## Manual follow-ups for the user

The following steps are intentionally not automated because they touch
user-owned configuration files. Present them to the user after the upgrade.

- Compare your project's root `AGENTS.md` against the fresh
  `core/root-AGENTS.md` template and merge any new rows/rules manually. The
  harness never auto-merges this file to avoid overwriting your project-specific
  rules.
- If your install docs or scripts previously referenced the old repo-root
  `AGENTS.md` path as the template source, update them to point to
  `core/root-AGENTS.md`.

## Release summary

- Moved the installable root agent-guidelines template from repo-root `AGENTS.md`
  to `core/root-AGENTS.md`.
- The repo-root `AGENTS.md` is now independent and contains only
  harness-template-specific rules.
- Updated install docs and changelog prompts to reference `core/root-AGENTS.md`
  as the source of the installable template.
