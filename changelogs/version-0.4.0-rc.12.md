---
version: 0.4.0-rc.12
from: 0.4.0-rc.11
date: 2026-10-07
---

# Version 0.4.0-rc.12 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.11 to 0.4.0-rc.12. The memory gate and
the arming hook now see a task dir at the repository root, and the hook arms a plan on a write into
a directory that does not exist yet.

## What changed

`memory-gate.sh` and `hook-arm-build.sh` built their scan set from workspace parents only
(`apps/*`, `packages/*`, …), so a task dir at `<repo>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`
— the workspace the root `AGENTS.md` allows for a repo with no `apps/` and no `packages/`, or for a
task that targets the root — was never read. `build_started` was written, nothing enforced it. Both
scripts now add `$ROOT/.agents/artifacts/task_*`, so arming and enforcing share one scan set.

Separately, the hook resolved a written path by `dirname` and only when that parent already
existed. The first write of a build is usually a brand-new file in a directory nobody has created
yet, and if its spelling differed from git's physical root (a doubled slash from `TMPDIR`, a
symlinked checkout) the path matched neither the root nor `PWD`, so the workspace rule failed
closed and the plan stayed unarmed. The hook now walks up to the deepest directory that exists,
resolves that one physically and re-appends the rest.

## Commands to run

- None. No file was added to the bundle or to an adapter, so no manifest row changed: `core/` ships
  whole. Run the normal update (`/monorepo-harness-update`, or
  `core/scripts/install-harness.sh --sync-only`) and refresh adapters as usual.

## Manual follow-ups for the user

- **A repo-root task is now enforced.** If `<repo>/.agents/artifacts/` holds a task whose plan has
  `build_started` and no `3_memory.md`, the gate will block commits and the Stop hook until it (and
  `4_verify.md`, when the spec's verification plan is not N/A) exists. Write them, or leave the task
  at plan stage if it was never actually built.
- **New-file writes now arm.** An agent that starts implementing by creating a new file in a new
  directory gets `build_started` on the newest plan, where before it could be missed entirely.

## Release summary

- Repo-root task dirs are first-class candidates for both scripts (closes #22).
- Arming places a written path whose parent directory does not exist yet.
- 12 new regression cases in `tests/memory-gate.test.sh`; no adapter or manifest changes.
