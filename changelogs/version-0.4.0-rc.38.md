---
version: 0.4.0-rc.38
from: 0.4.0-rc.37
date: 2026-11-22
---

# Version 0.4.0-rc.38 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.37 to 0.4.0-rc.38, which adds the opt-in
`--auto-fix` review-fix loop to `/monorepo-harness-review` (issue #77).

## What changed

**`/monorepo-harness-review --auto-fix` fixes Important findings in a bounded, local loop.**
- The loop is: review, fix the Important findings, verify each fix, commit locally, review again.
- It refuses to start when the working tree is not clean.
- It stops after 2 fix rounds by default. `--max-rounds <n>` sets 1 to 5.
- Every finding is reproduced before it is fixed. A finding that does not reproduce is reported as
  disputed and is not fixed.
- It stops and asks you when a fix needs a scope change or a new non-test file, when a fix still fails
  after 2 attempts, or when the reproduction conflicts with the reviewer's evidence.
- Nits stay report-only. `--fix-nits` lets the loop fix them, except nits that contradict a scope
  decision in the spec.
- The security pass runs on the closing review, or earlier when a round touched security-sensitive
  paths.
- `3_memory.md` and `4_verify.md` are updated once, at the end, when the diff belongs to a task.
- It never pushes, comments on a PR, merges or approves. You review the local commits and push.

Without `--auto-fix`, nothing changes: the review is a report only.

The new helper `core/scripts/review-fix-loop.sh` runs the hard checks (`preflight`, `check-fix`,
`security-due`). The three entry points (claude-code, opencode, codex) carry the same text. The
claude-code menu hint is now `[diff-range] [--auto-fix] [--fix-nits] [--max-rounds <n>]`.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step installs
  `core/scripts/review-fix-loop.sh` and updates `core/skills/pr-review/SKILL.md` and
  `core/skills/agent-workflow/SKILL.md`. The `install-adapter.sh <agent> --refresh` step re-copies the
  changed `/monorepo-harness-review` entry points.

## Manual follow-ups for the user

- Optional: after a build, try `/monorepo-harness-review --auto-fix` on a clean tree.

## Release summary

- Added the `--auto-fix`, `--fix-nits` and `--max-rounds <n>` flags to `/monorepo-harness-review` on
  claude-code, opencode and codex, with the loop described once in `core/skills/pr-review/SKILL.md`
  (issue #77).
- Added `core/scripts/review-fix-loop.sh` and its manifest row.
- The `/monorepo-harness-build` "After the build" question also offers the loop.
- Added the repo-local tests `tests/review-fix-loop.test.sh` and `tests/review-auto-fix-parity.test.sh`.
- No change to `core/root-AGENTS.md`.
