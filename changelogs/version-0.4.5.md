---
version: 0.4.5
from: 0.4.4
date: 2026-08-26
---

# Version 0.4.5 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.4 to 0.4.5.

0.4.4 introduced deleting the installed `changelogs/` directory at the end of
install and update, but confirmed on a real install that the two-line form
(`cp -R ...` then a separate `rm -rf ... changelogs`) can run partially — the
copy happens but the delete doesn't. This release makes the delete atomic in
both flows and adds a self-healing check to `INSTALL.md` §8 Verification and
an explicit postcondition check to the update workflow. There are no changes
to the plan/spec artifact layout or the update engine itself.

## Files to copy from the new bundle to the installed bundle

Copy the following files from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`:

- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `INSTALL.md` -> `INSTALL.md`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`

## Files to delete from the installed bundle (only if they exist)

- `.agents/monorepo-agents-harness/changelogs/` (the entire directory —
  again, unconditionally. If your install already applied 0.4.4, this
  directory may still be sitting there due to the partial-run gap this
  release fixes; delete it now regardless of what 0.4.4's own steps did.)

## Commands to run

```bash
rm -rf .agents/monorepo-agents-harness/changelogs
```

## Manual follow-ups for the user

- None. The directory deletion above is the entire change; no user-owned
  config files are affected.

## Release summary

- Made the `changelogs/` deletion from 0.4.4 atomic in both install
  (`INSTALL.md` step 1) and update (`core/skills/harness-update/SKILL.md`
  step 9), chaining the copy/clone and delete into a single command instead
  of two separate ones.
- Added a self-healing check to `INSTALL.md` §8 Verification that asserts
  `changelogs/` does not exist in the installed copy and removes it if it
  does.
- `core/skills/harness-update/SKILL.md` step 9 now requires confirming
  `changelogs/` no longer exists before reporting the upgrade complete.
