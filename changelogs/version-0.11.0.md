---
version: 0.11.0
from: 0.10.0
date: 2026-08-26
---

# Version 0.11.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.10.0 to 0.11.0.

**Transitional release.** This is the last prompt interpreted by the *old* (pre-0.11.0) itemized
copy model, so it lists `core/` and `adapters/` as recursive directory copies below — the old
model's own "replace the target directory entirely" semantics already give a full sync for this
one release. Every release after this one no longer needs a `Files to copy`/`Files to delete`
section for `core/` or `adapters/` at all: the newly-installed `core/skills/harness-update/SKILL.md`
performs that sync unconditionally (see `changelogs/README.md`'s 0.11.0+ note).

## Files to copy from the new bundle to the installed bundle

- `core/` -> `core/` (recursive directory copy)
- `adapters/` -> `adapters/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none)

## Manual follow-ups for the user

- This upgrade is applied by your *currently installed* (pre-0.11.0) harness-update workflow, which
  does not yet know how to auto-reinstall adapter entry-points (that capability, step 7.5, is part
  of what this release adds). If you want any of `/monorepo-harness-ci`, `/monorepo-harness-review`,
  or `/monorepo-harness-intent` and don't already have them, copy them once by hand per your
  adapter's `INSTALL.md` "Optional harness-plumbing commands" step. From this release onward, future
  new commands install automatically on your next update.

## Release summary

- Fixes the root cause behind "some files don't reach the consumer project during an update, or
  arrive incomplete." `core/` and `adapters/` are now synced wholesale from the fresh clone every
  update (not from a hand-maintained per-release file list), verified deterministically with the
  new `harness-update.sh verify-copy` subcommand. Already-installed adapters have their entry-point
  commands/skills (update-check, build trigger, verifier, and any of `/monorepo-harness-ci`,
  `-review`, `-intent` already present) automatically re-installed from each adapter's own
  `INSTALL.md`, closing the gap where new commands only ever reached a project via a manual,
  frequently-skipped follow-up step. Also backfills three install steps that were confirmed missing
  from all three adapter `INSTALL.md` files (`/monorepo-harness-ci`, `-review`, `-intent`), so a
  fresh install now picks them up too.
