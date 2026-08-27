---
version: 0.13.0
from: 0.12.0
date: 2026-08-27
---

# Version 0.13.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.12.0 to 0.13.0.

## Files to copy from the new bundle to the installed bundle

(none — `core/` and `adapters/` are synced wholesale by your already-installed
`core/skills/harness-update/SKILL.md` step 7, unconditionally; see `changelogs/README.md`'s
0.11.0+ note)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none)

## Manual follow-ups for the user

(none)

## Release summary

- The install/update mechanics no longer call `rm -rf` anywhere in the automated flow. Some
  environments run the agent under a permission policy that blocks `rm -rf` outright, which
  previously stalled the wholesale `core`/`adapters` sync and cleanup with no way through (the
  identical command denied on every retry). Every directory that used to be deleted before being
  replaced is now moved into a per-run `.agents/.harness-trash/<timestamp>_<pid>/` first, then
  copied fresh — `mv` never overwrites anything, so it stays unambiguously non-destructive. New
  `core/scripts/cleanup-harness-trash.sh` (`--list` to inspect first) is your own explicit,
  standalone command to actually free the disk space, whenever you choose to — nothing in this
  bundle purges the trash automatically.
