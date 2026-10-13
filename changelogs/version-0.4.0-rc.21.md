---
version: 0.4.0-rc.21
from: 0.4.0-rc.20
date: 2026-10-13
---

# Version 0.4.0-rc.21 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.20 to 0.4.0-rc.21. This release makes
`/monorepo-harness-build` end by suggesting a review, so a finished build is no longer silent about
`/monorepo-harness-review`.

## What changed

A build used to end without connecting itself to the review step, so nothing reminded the developer
that a review existed. Now a finished build points at it, and the **strength** of that point is not the
model's free judgement — a new deterministic helper decides it.

**New `core/scripts/build-review-tier.sh <task_dir>`** (agent-neutral, advisory). It prints `simple`
or `comprehensive` as its first line, followed by reasons, from two signals:

- **changed files** — the union of the `3_memory.md` `commits:` (via `git show --name-only`), falling
  back to the count of `2_plan.md` `## Affected files / modules` entries;
- **architectural signal** — an `adr/*.md` file, or a non-`N/A` `## Architectural decisions` /
  `## API / contracts` / `## Data model` section in `1_spec.md`.

`simple` means ≤3 changed files **and** no architectural signal; `comprehensive` is everything else.

- `core/skills/agent-workflow/SKILL.md` gains an "After the build" subsection and a `-build` row note:
  it runs the helper and follows its first line.
- The three build stubs — `monorepo-harness-build` for claude-code, opencode and codex — gain a final
  step: on `simple`, add one informational line; on `comprehensive`, ask the developer whether to run
  the review now and, on yes, run the `pr-review` skill inline.
- `core/skills/pr-review/SKILL.md` notes it is the review recommended at the end of a build.
- `README.md` and `PORTABILITY.md` were synced; `tests/build-review-tier.test.sh` adds repo-local
  behavioural guards.

This step is **advisory**: it never blocks a task from closing, never writes a file, and never runs a
review without the developer's choice. No existing manifest row, adapter row, hook, or gate changed:
`build-review-tier.sh` ships through the `core` directory row, and the three build stubs are existing
`copy` rows.

## Commands to run

- None by hand. There is nothing to install: the helper and the skill ship in the bundle sync, and the
  three build stubs are existing `copy` rows that reach the project on the normal adapter refresh.

## Manual follow-ups for the user

- None. The new suggestion takes effect on the next `/monorepo-harness-build` run.

## Release summary

- `core/scripts/build-review-tier.sh` (new): prints `simple`/`comprehensive` from the task's changed
  files and its spec's architectural signals; advisory (always exit 0, exit 2 on usage).
- `core/skills/agent-workflow/SKILL.md`: "After the build" subsection + `-build` row note.
- `core/skills/pr-review/SKILL.md`: end-of-build note.
- The three build stubs (claude-code, opencode, codex): final step names the helper and the two tiers.
- `README.md`, `PORTABILITY.md`: docs synced to the end-of-build review suggestion.
- `tests/build-review-tier.test.sh` (new): 16 behavioural cases (closes #41).

**Deviation from the issue.** #41 asked for an automatic, blocking review before a unit-test phase.
The harness has no separate unit-test phase — tests are part of the implementation and `4_verify.md`
records their run — so the review is a conditional, non-blocking suggestion at the end of the build.
