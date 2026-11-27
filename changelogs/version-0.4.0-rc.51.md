---
version: 0.4.0-rc.51
from: 0.4.0-rc.50
date: 2026-11-28
---

# Version 0.4.0-rc.51 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.50 to 0.4.0-rc.51. This release stops the
shared pre-commit hook from running the committed branch's bundle scripts (issue #103).

## What changed

- `memory-gate.sh` follows its own symlink and loads its helper scripts from the bundle it runs from.
  Through the installed `.git/hooks/pre-commit` symlink, a commit in any worktree now runs the main
  checkout's bundle. Task folders and `knowledge/` are still read from the checkout being committed.
- CI and Stop hooks that call a checkout's own gate still run that checkout's bundle.
- The installer's advice for a project with its own pre-commit hook now names the main checkout's
  gate.

## Commands to run

- None.

## Manual follow-ups for the user

- The fix works once the **main checkout** has this version, because its gate is the one the hook
  runs. Upgrading only a branch or a worktree changes nothing at commit time.
- Look at `.git/hooks/pre-commit`:
  - a **copy** of `memory-gate.sh` still uses the committing checkout's bundle. Replace it with the
    symlink (`PORTABILITY.md`, "The universal hard gate").
  - your **own hook** that calls `bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh`
    still runs the committed branch's gate. Change that line to
    `bash "$(git rev-parse --git-common-dir)/../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"`.
  - hooks in a tracked `core.hooksPath` folder come from the branch by design. Review them with the
    branch.
- If a worktree has no tracked bundle, its commits now get the full gate. A commit that passed before
  can now be blocked by `check-kb`; write the missing knowledge entry.

## Release summary

- The shared pre-commit hook runs one bundle, the main checkout's, instead of mixing it with the
  committed branch's helper scripts (issue #103).
