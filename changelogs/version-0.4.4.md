---
version: 0.4.4
from: 0.4.3
date: 2026-08-26
---

# Version 0.4.4 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.3 to 0.4.4.

This release makes install and update always delete the installed
`changelogs/` directory as their final step. It was never actually read from
the installed copy — every upgrade prompt is sourced from a freshly cloned
temporary bundle (see `core/skills/harness-update/SKILL.md` step 2-3) — so it
was pure accumulated clutter, growing by one file per applied release since
0.2.0. There are no changes to the plan/spec artifact layout or the update
engine itself.

## Files to copy from the new bundle to the installed bundle

Copy the following files from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`:

- `core/VERSION` -> `core/VERSION`
- `VERSION` -> `VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `INSTALL.md` -> `INSTALL.md`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`

## Files to delete from the installed bundle (only if they exist)

- `.agents/monorepo-agents-harness/changelogs/` (the entire directory — this
  is the actual behavior change: whatever historical prompt files have
  accumulated there get removed, and no `changelogs/` directory is left
  behind by this or any future install/update).

## Commands to run

```bash
rm -rf .agents/monorepo-agents-harness/changelogs
```

## Manual follow-ups for the user

- None. The directory deletion above is the entire change; no user-owned
  config files are affected.

## Release summary

- Install (`INSTALL.md` §4 step 1) and update (`core/skills/harness-update/SKILL.md`
  step 9) now always delete the installed `changelogs/` directory as their
  final step.
- Fixed a doc inconsistency: `core/skills/harness-update/SKILL.md` previously
  implied prompts are read from the installed `changelogs/` directory;
  corrected to point at the freshly downloaded temporary bundle.
- `changelogs/README.md` now documents that prompts released from 0.4.4
  onward should not list their own `changelogs/version-X.Y.Z.md` under
  "Files to copy" — it would just be deleted by the new cleanup step.
