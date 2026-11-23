---
version: 0.4.0-rc.39
from: 0.4.0-rc.38
date: 2026-11-23
---

# Version 0.4.0-rc.39 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.38 to 0.4.0-rc.39, which ends
`/monorepo-harness-update` with a plain-language "What's new" summary (issue #81).

## What changed

**`/monorepo-harness-update` now ends with a short "What's new" summary.**
- It covers every version between the one you had and the one you installed, oldest first.
- Each version gets 1–3 short bullets: what you can now do, or what works differently for you.
- A renamed or removed command, a new check that can block a commit, or a config change you must
  apply by hand starts with `Needs attention:`.
- It is written from the new release's `CHANGELOG.md`, so a release with no prompt in this
  directory is still covered. A release tag with no `CHANGELOG.md` section gets one "no entry" line.
- It is the last thing the update prints, after the follow-ups and the commit suggestion.
- No summary when the harness is already current, upstream cannot be reached, or the upgrade is
  declined or fails. A declined `AGENTS.md` merge still shows it.

The new read-only subcommand `harness-update.sh changelog-range <from> <to> <changelog.md>` collects
the release notes. It also prints its whole usage list now when it is run without a subcommand.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step updates
  `core/scripts/harness-update.sh`, `core/skills/harness-update/SKILL.md` and
  `core/prompts/harness-update.md`. No adapter entry point changed.

## Manual follow-ups for the user

- This upgrade does not print the "What's new" summary yet. It runs the update skill you had
  installed before, which has no summary step. Your next upgrade will print it. To see what changed
  this time, read the `CHANGELOG.md` sections for the versions you skipped:
  https://github.com/atayahmet/monorepo-agents-harness/blob/main/CHANGELOG.md

## Release summary

- Added the "What's new" summary as the last step (step 12) of
  `core/skills/harness-update/SKILL.md`. Step 3 collects the release notes and step 4 drafts the
  summary (issue #81).
- Added `harness-update.sh changelog-range`. It fails open (exit 0) and exits 2 only on bad
  arguments.
- `core/prompts/harness-update.md` allows the closing summary.
- Fixed the usage list `harness-update.sh` prints with no subcommand.
- Added the repo-local test `tests/harness-update-whats-new.test.sh`.
- No change to `core/root-AGENTS.md`.
