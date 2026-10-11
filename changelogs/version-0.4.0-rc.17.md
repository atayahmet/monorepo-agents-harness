---
version: 0.4.0-rc.17
from: 0.4.0-rc.16
date: 2026-10-11
---

# Version 0.4.0-rc.17 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.16 to 0.4.0-rc.17. The "Before You Start"
checklist reminder is no longer a hand-copied list: it is read live from your root `AGENTS.md`, so it
can never drift from that file again (issue #29).

## What changed

The Claude Code `PostToolUse[ExitPlanMode]` reminder embedded its own 7-item checklist, which had
drifted from the template's 9 items — the **target workspace** item and the **query the knowledge base
first** item were missing. A new agent-neutral script `core/scripts/checklist-reminder.sh` extracts the
`## Before You Start — Mandatory Checklist` section of the installed root `AGENTS.md` at run time and
emits it (Claude hook JSON by default, plain markdown with `--text`). The `ExitPlanMode` hook now calls
the script, and every adapter's `-spec` stub runs it before writing `1_spec.md` — so the checklist is
shown on the plan-mode path and the command-driven path, on claude-code, opencode, and codex. Edit your
root `AGENTS.md` checklist and the reminder follows, with no code change.

## Commands to run

- None by hand. The new script is carried by the existing `core/` install row and the `-spec` stubs are
  `copy` rows, so the normal update (`/monorepo-harness-update`, which runs
  `install-harness.sh --sync-only` and then `install-adapter.sh <agent> --refresh`) brings both.

## Manual follow-ups for the user

- **Claude Code — merge the proposed `settings.json`.** `.claude/settings.json` is a `merge` row, so the
  new hook command is staged as `.claude/settings.json.harness-proposed`, never applied for you. Review
  it and keep the `PostToolUse[ExitPlanMode]` entry whose command runs
  `core/scripts/checklist-reminder.sh` (it replaces the old inline `jq` checklist):

  ```bash
  git diff --no-index .claude/settings.json .claude/settings.json.harness-proposed
  ```

  Without the merge nothing breaks — the `/monorepo-harness-spec` command still prints the checklist.
- **Nothing to merge on codex or opencode.** Their `-spec` stubs are `copy` rows and update
  automatically; their existing hook/prose reminders are unchanged.

## Release summary

- New `core/scripts/checklist-reminder.sh`: reads the root `AGENTS.md` checklist at run time, emits
  Claude hook JSON or plain markdown, fail-open (missing file/section/`jq` → exit 0).
- Claude `ExitPlanMode` reminder hook and all three `-spec` stubs now use it; no second copy to drift.
- Repo-local `tests/checklist-reminder.test.sh` locks the reminder to the template checklist and blocks
  a hand-copied list from returning.
- Docs updated: claude-code `INSTALL.md`/`README.md`, `adapters/AGENTS.md`, `PORTABILITY.md`, `README.md`.
