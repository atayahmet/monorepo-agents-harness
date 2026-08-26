---
version: 0.9.0
from: 0.8.0
date: 2026-08-26
---

# Version 0.9.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.8.0 to 0.9.0.

## Files to copy from the new bundle to the installed bundle

- `core/VERSION` -> `core/VERSION`
- `core/root-REVIEW.md` -> `core/root-REVIEW.md`
- `core/skills/pr-review/` -> `core/skills/pr-review/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none)

## Manual follow-ups for the user

- Copy the new `/monorepo-harness-review` entry point for whichever adapter(s) you use:
  - Claude Code: copy `adapters/claude-code/.claude/commands/monorepo-harness-review.md` into
    `.claude/commands/`.
  - opencode: copy `adapters/opencode/.opencode/commands/monorepo-harness-review.md` into
    `.opencode/commands/`.
  - Codex: copy `adapters/codex/.agents/skills/monorepo-harness-review/` into `.agents/skills/`
    (recursive).
- Optional: copy `core/root-REVIEW.md` to your repo root as `REVIEW.md` and resolve
  `{{PROJECT_NAME}}`/`{{PROJECT_REVIEW_POLICY}}` if you want to customize review passes,
  thresholds, or exclusions. Skip this if the built-in defaults are fine — the skill falls back to
  them automatically when `REVIEW.md` is absent.

## Release summary

- New `/monorepo-harness-review` capability: reviews a diff against `REVIEW.md` policy (or
  built-in defaults) and, when the diff maps to a tracked task, against that task's own
  `1_plan.md`/`2_spec.md`/`4_verify.md`. Produces a report only — never posts to a PR platform,
  tags comments, or merges/approves anything.
