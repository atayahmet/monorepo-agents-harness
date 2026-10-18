---
version: 0.4.0-rc.23
from: 0.4.0-rc.22
date: 2026-10-18
---

# Version 0.4.0-rc.23 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.22 to 0.4.0-rc.23. This release adds a
**reject path for intents that travel as pull requests**: `/monorepo-harness-intent --reject`.

## What changed

Intent dispatch could approve an intent's PR and merge it. A rejected intent had no route at all:
its PR was either merged with a decision nobody could see, or left open forever. This release closes
that asymmetry.

- **`core/skills/intent-workflow/SKILL.md`** — a new `## Workflow — Reject` section: resolve the
  PR's head, guard (a reviewed intent is refused — one `## Review` section ever; already `rejected`
  is a no-op; an already-merged PR is skipped by name), one batch consent plus an optional reason,
  write `status: rejected` and the `## Review` section on the PR's own branch, commit and push it,
  then a **separate** batch merge question.
- **`core/scripts/task-state.sh`** — `merge-intent-pr` gains `--reject`. In this mode the approving
  review gate is replaced by the intent file's own `status: rejected` plus your in-turn `--yes`; a
  PR approval is expected to be absent and is never read. Everything else is unchanged: state is
  read first (already merged = harmless no-op), merge commit only, never `--admin`, never
  `--delete-branch`, and the exit codes stay 0 / 1 / 3 (done / refused / could not read).
- **The three adapter entry points** (claude-code, opencode, codex) — one identical bullet pointing
  at the Reject workflow.
- **`core/governance/intents/AGENTS.md`** — the PR-based reject path and the one-`## Review`-section
  invariant.
- Docs sync in `README.md`, `INSTALL.md`, `PORTABILITY.md`. No new file, no new manifest row, no
  gate, no artifact-layout change.

## Commands to run

- None by hand. The release is instruction/script-only: the normal upgrade's bundle re-sync
  (`install-harness.sh --sync-only`) carries `task-state.sh` and the skill, and the adapter refresh
  (`install-adapter.sh <agent> --refresh`) re-applies the three entry points.

## Manual follow-ups for the user

- None required. Your root `AGENTS.md` and `REVIEW.md` are untouched by this release.
- If you use the intent flow on a PR-based project: after this upgrade you can decline an intent
  with `/monorepo-harness-intent --reject <PR-url>` instead of leaving the PR open. The workflow
  asks twice — once to record the rejection, once to merge — and never merges on a single yes.

## Release summary

- `core/scripts/task-state.sh`: `--reject` option + the gate swap in `merge-intent-pr` (closes #45).
- `core/skills/intent-workflow/SKILL.md`: `## Workflow — Reject`, description triggers, edge cases.
- Adapter intent entry points: one `--reject` bullet each (byte-identical).
- `core/governance/intents/AGENTS.md`: reject-path paragraph.

**Note.** The release itself needs no command or manual follow-up, so `changelogs/README.md` would
normally omit this prompt. It is added at the maintainer's request.
