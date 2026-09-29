---
version: 0.4.0-rc.9
from: 0.4.0-rc.8
date: 2026-09-29
---

# Version 0.4.0-rc.9 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.8 to 0.4.0-rc.9, which **stops the memory
gate from blocking a task that has not started building**, and gives the gate a way to arm itself when
implementation does start.

## What changed

**A spec-only or plan-only task is never blocked.** `/monorepo-harness-spec` and
`/monorepo-harness-plan` are supposed to end at a stage boundary. The old gate asked every task
directory created that day for `3_memory.md`, so ending a spec turn was reported as an unfinished
task — and on claude-code the Stop hook could keep reporting it, because it only ever saw "this task
is missing its artifacts". The gate now asks one question, read from one place: **has this task
reached the build stage?**

**The marker is one field, written once.** `build_started: <ISO-8601>` in `2_plan.md` frontmatter,
written by `task-state.sh mark-build <2_plan.md>`. No new file, nothing to add to the artifact index,
and a re-run never restamps it. `task-state.sh stage <task_dir>` is the single stage reader: it
answers `none`, `spec`, `plan` or `build`, and both the gate and the new hook read the same answer.

**A newer task dir no longer masks an in-flight build.** The gate scans every task dir created today
and keeps the ones at build stage, newest first, instead of enforcing whichever directory happened to
be newest. Opening a fresh spec while yesterday's build is still open no longer hides that build.

**Both modes agree.** The `--json` mode (Claude Stop hook) and the default mode (git pre-commit / CI)
are scoped the same way, so CI can no longer reject a commit your local hook allowed. At build stage
the gate is unchanged, including `4_verify.md` when the spec's verification plan is not `N/A` and the
knowledge-base coverage check.

**The block cannot repeat.** The gate reads its own hook input and stands down silently when
`stop_hook_active` is true. Anything unreadable — absent, `false`, or malformed — still enforces: a fix
for a blocking loop must never double as a way to turn the gate off.

**The gate arms itself on the first real edit.** A new `PreToolUse` hook,
`core/scripts/hook-arm-build.sh`, watches the first write that is **not** a task artifact and marks the
newest plan. That covers the one path the marker cannot: an agent that leaves plan mode, writes
`1_spec.md` + `2_plan.md` and edits code without ever running `/monorepo-harness-build`. It edits
nothing itself, needs only coreutils, and always exits 0.

## Commands to run

- None. `core/install-manifest.txt` already copies the whole `core/` directory, so
  `core/scripts/hook-arm-build.sh` arrives with the normal sync, and no adapter gained or lost a file.
  Run the normal update (`/monorepo-harness-update`, or
  `core/scripts/install-harness.sh --sync-only`) and then the adapter refresh.

## Manual follow-ups

- **claude-code — accept the new arming hook.** `.claude/settings.json` is a `merge` row and it
  gained a `PreToolUse` entry, so an installed copy stages the change as `.harness-proposed` instead of
  applying it. Open the diff and keep the block that runs
  `core/scripts/hook-arm-build.sh` for `Write|Edit|MultiEdit|NotebookEdit`; the `Stop` entry is
  unchanged. Without it, nothing breaks — the gate just relies on `/monorepo-harness-build` writing the
  marker, exactly as before.
- **codex — accept the reworded `update_plan` reminder.** `.codex/hooks.json` is also a `merge` row.
  The reminder now names `task-state.sh mark-build <2_plan.md>` as the step to run at the end of plan
  mode. Codex has no equivalent file-write hook whose matcher could be verified, so the prose path is
  the mechanism there — the gate itself is identical on every agent. This is the one documented
  adapter divergence (`PORTABILITY.md`).
- **opencode needs nothing manual** — the gate is the same script and there is no settings merge.
- **Nothing to migrate, and an in-flight task is not retro-blocked.** Plans written before this
  version have no `build_started`, so they read as `plan` and the gate stays quiet until the first
  write outside `.agents/` or the first `/monorepo-harness-build` marks them. A build already finished
  under 0.4.0-rc.8 keeps its own `3_memory.md` and `4_verify.md` and needs no marker at all.
- **Expect CI and pre-commit to allow spec-only and plan-only commits now.** That is the intended
  effect, not a regression. If you expected a build-stage task to be blocked and it is not, check that
  its plan carries a `build_started` line:
  `grep -l build_started <workspace>/.agents/artifacts/*/2_plan.md`.
- **To see the change working**, run `bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh`
  in a project with a spec-only task dir: it now exits 0 and prints nothing. Same command with a build
  task dir whose memory is missing: it exits 1 and names `3_memory.md`.
