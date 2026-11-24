---
version: 0.4.0-rc.40
from: 0.4.0-rc.39
date: 2026-11-24
---

# Version 0.4.0-rc.40 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.39 to 0.4.0-rc.40, which makes workspace
discovery language-agnostic (issue #83).

## What changed

- `.agents/workspaces.txt` (optional, project-owned) declares the workspaces, one path or glob per line.
  It replaces detection.
- The memory-gate finds a task dir anywhere git can see one, not only under the detected workspaces.
- Turborepo and pnpm projects: the real workspace list is read.
- `core/root-AGENTS.md` describes the declaration file.

## Commands to run

- Run the gate once, after the sync:
  `bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh`.
  It reports one task at a time. Report each one to the user; do not write its artifacts on your own.
- Run `bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh` and report its warnings. If
  it says that no workspace was found, propose a `.agents/workspaces.txt` for this repo and write it
  only when the user agrees. Then run
  `bash .agents/monorepo-agents-harness/core/scripts/scaffold-workspace-agents.sh`.

## Manual follow-ups for the user

- **Needs attention: old tasks can block now.** For each task the gate reports, finish it, or record in
  its `3_memory.md` (and `4_verify.md`, when it is named) that it was abandoned.
- Task dirs that are test data belong under a `fixtures/` or `testdata/` directory, where the gate skips
  them.
- A workspace listed by exact path (`tools/cli`) no longer scaffolds its siblings. If you relied on
  that, list them too.

## Release summary

- Any language and layout can be declared; no task is skipped because of where it lives (closes #83).
- No adapter or manifest change.
