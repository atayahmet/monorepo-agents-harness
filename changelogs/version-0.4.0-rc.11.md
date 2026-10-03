---
version: 0.4.0-rc.11
from: 0.4.0-rc.10
date: 2026-10-03
---

# Version 0.4.0-rc.11 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.10 to 0.4.0-rc.11. The memory gate and
arming hook now enforce and arm build-stage tasks across **all dates**, not just today.

## What changed

In 0.4.0-rc.10 the arming hook was narrowed to match the gate's today-only scope to prevent arming
tasks the gate would never read. That fixed the original bug but left a gap: a build that starts
before midnight and continues after midnight is never enforced on day two.

Both `core/scripts/memory-gate.sh` and `core/scripts/hook-arm-build.sh` now scan **all** task
directories (`task_*`) across discovered workspaces. Candidates are filtered by lifecycle:
- A task is enforceable by the gate only if it is at **build stage** (per `task-state.sh stage`) and
  has **no `3_memory.md`** (finished tasks are never re-enforced).
- The hook arms a plan only if it is at **plan stage** (no `build_started`), has no `3_memory.md`, and
  the written path is inside that plan's own workspace.

Task directories are still ordered by the date in their name, newest first, with modification time
used only as a tie-break inside the same date. Both scripts share `harness_task_dirs_newest_first()`
and fall back safely if the helper is absent.

## Commands to run

- None. This is a behavioral change to core scripts only; no new files were added to the bundle or
  adapters, so no manifest rows changed. Run the normal update (`/monorepo-harness-update` or
  `core/scripts/install-harness.sh --sync-only`) and refresh adapters as usual.

## Manual follow-ups for the user

- **Cross-midnight builds are now enforced.** If a plan was approved yesterday and implementation
  started (`build_started` present), any write today in that workspace will cause the gate to
  enforce that task (demanding `3_memory.md` and `4_verify.md` as required). This is the intended fix
  for issue #23.
- **Hook arms cross-midnight plans.** If a plan was approved yesterday but never got `build_started`,
  the first relevant write today in its workspace will arm it (write `build_started` to that plan).
- **Finished tasks are never re-enforced.** Tasks that already have `3_memory.md` are ignored by both
  scripts regardless of date.

## Release summary

- `memory-gate.sh` and `hook-arm-build.sh` now consider build-stage/plan-stage task dirs across all
  dates, while still excluding finished tasks (closes #23).
- No adapter or manifest changes.
