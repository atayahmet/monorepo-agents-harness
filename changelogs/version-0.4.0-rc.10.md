---
version: 0.4.0-rc.10
from: 0.4.0-rc.9
date: 2026-10-03
---

# Version 0.4.0-rc.10 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.9 to 0.4.0-rc.10. Two things change
underneath you: the hook that arms the memory gate now arms only what the gate would enforce, and a
memory's `commits:` list can be repaired after a rebase, a squash or a force-push.

## What changed

**The arming hook no longer arms tasks the gate never reads.** In 0.4.0-rc.9 the gate learned to
enforce a task only after `build_started` appeared on its plan, and a `PreToolUse` hook
(`core/scripts/hook-arm-build.sh`) was added to write that field when an agent starts implementing
without `/monorepo-harness-build`. That hook marked the newest task directory of any date, in any
workspace, ordered by file modification time. So:

- a write anywhere in the repo could stamp `build_started` into a task that already had
  `3_memory.md`, dirtying a finished, committed task directory;
- a write in `apps/docs` could arm the plan of an unrelated `apps/api` task, and the Stop hook then
  blocked that turn for work that was never built;
- an older task directory whose files had just been touched (a `git checkout`, a rebase, a stash pop)
  counted as "newest" and won over the task actually being built.

The hook's candidate list is now the gate's: task directories created **today**, newest first by the
**date in the directory name**, skipping any that already have `3_memory.md`, and arming only when the
written path is inside that plan's own workspace. It asks `task-state.sh stage` whether a plan is at
plan stage instead of parsing frontmatter a second time.

**The task-dir order is shared, not copied.** `harness_task_dirs_newest_first` in
`core/scripts/harness-common.sh` is used by both `hook-arm-build.sh` and `memory-gate.sh`. If that
library is missing, each script keeps its previous behaviour — a shared helper must never be able to
switch a gate off.

**`task-state.sh sync-commits` repairs a memory after a rewritten history.** A `commits:` sha is a name
a commit has on one branch. Rebase, squash or force-push and it points at nothing, while the change
itself is still there under a new sha — so the memory quietly becomes a list of dead references.
The new subcommand remaps them by content: a sha still reachable from the ref is kept, one that is not
is matched by `git patch-id --stable` and replaced by the sha carrying the same change.

```bash
# dry run: prints what it would do, changes nothing
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh sync-commits \
  apps/api/.agents/artifacts/task_2026_10_03_add_auth/3_memory.md

# apply
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh sync-commits \
  apps/api/.agents/artifacts/task_2026_10_03_add_auth/3_memory.md --write

# against a branch that is not origin/HEAD, main or master
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh sync-commits <3_memory.md> \
  --ref release/2026-10 --write
```

It refuses to guess: `--ref` defaults to `origin/HEAD`, then `main`, then `master`, and prints the ref
it used. A sha with no unique match is left exactly as written, named in the report, and the command
exits 1; when no ref resolves at all it exits 3 having compared nothing.

**`patch_ids:` in the memory frontmatter.** The memory template now carries
`patch_ids: [<patch-id>…]` next to `commits:` — the same values as
`git show --format= <sha> | git patch-id --stable`, in the same order. This is the identity of the
change rather than of one branch's history, so it survives a rewrite, and it is the field a tool can
join on. `sync-commits` maintains both fields. The memory-gate does not require `patch_ids:`, so a
memory written before this version stays valid and is never blocked for lacking it.

## Commands to run

- None. `core/install-manifest.txt` copies the whole `core/` directory and no adapter gained or lost a
  file, so there is no new row to add and nothing to copy by hand. Run the normal update
  (`/monorepo-harness-update`, or `core/scripts/install-harness.sh --sync-only`) and refresh the
  adapter (`install-adapter.sh <agent>`).

## Manual follow-ups for the user

- **Expect the arming hook to fire less often.** This is the intended fix, not a regression: it now
  arms only today's plans, in the workspace being written to, without a `3_memory.md`. If arming looks
  too quiet, check that the workspace has a task dir created today:
  `ls -d apps/*/.agents/artifacts/task_$(date +%Y_%m_%d)_*`. `/monorepo-harness-build` is unaffected —
  it writes the marker itself.
- **Optional: repair memories whose commits were already rewritten.** Anything merged by rebase,
  squash or force-push before this version may carry dead shas. Run the dry run per memory and apply
  only where it reports a remap. A memory with no `commits:` list is reported as nothing to sync and
  is not modified.
- **Know what the hook still does not cover.** `4_verify.md` and `index.md` are written outside
  `.agents/artifacts/`, so on a task where `-build` is never run, a stop that writes only those two
  files is not armed. Tracked separately; the arming behaviour for that case is unchanged from
  0.4.0-rc.9.
- **To see the change working**, in a project with today's plan-only task in `apps/api`, write
  `apps/api/src/x.ts`: the hook stamps `build_started` on that plan and the memory-gate starts asking
  for `3_memory.md`. Write `apps/web/src/x.ts` instead: nothing is armed, because the write is not in
  the api workspace.

## Release summary

- The claude-code arming hook now arms only today's plans, in the workspace being written to, skipping
  tasks that already have `3_memory.md`, and orders task directories by the date in their name
  instead of file modification time (issues #19, #20).
- New `task-state.sh sync-commits <3_memory.md> [--ref <branch>] [--write]` repairs a memory's
  `commits:` list after a rebase, squash or force-push, matching by `git patch-id --stable` and
  refusing to guess; the memory template gains `patch_ids:` (issue #21).
- No new bundle or adapter file, no manifest change, no command to run.
