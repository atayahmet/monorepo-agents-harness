---
version: 0.12.0
from: 0.11.1
date: 2026-08-27
---

# Version 0.12.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.11.1 to 0.12.0.

## Files to copy from the new bundle to the installed bundle

(none — `core/` and `adapters/` are synced wholesale by your already-installed
`core/skills/harness-update/SKILL.md` step 7, unconditionally; see `changelogs/README.md`'s
0.11.0+ note)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none)

## Manual follow-ups for the user

(none — the new audit step is fully automatic, part of the update workflow itself)

## Release summary

- New reliability layer: `core/scripts/audit-install.sh` and a new step 9.5 in
  `core/skills/harness-update/SKILL.md` (also wired into `INSTALL.md`'s Phase 2 for fresh
  installs). After every install/update, it independently compares the consumer project against
  the bundle source it was just built from — bundle sync, every installed adapter's entry-point
  files (missing required ones, or present-but-stale ones), root `AGENTS.md` provenance freshness,
  and every workspace's scaffold seeds — and refuses to let the operation report success while a
  gap remains. Closes the class of bug behind `v0.11.0`'s missing adapter commands and `v0.11.1`'s
  missing `core/root-REVIEW.md`: instead of trusting that every prior copy step actually completed,
  the harness now checks.
