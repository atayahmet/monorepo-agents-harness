---
version: 0.8.0
from: 0.7.0
date: 2026-08-26
---

# Version 0.8.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.7.0 to 0.8.0.

## Files to copy from the new bundle to the installed bundle

- `core/VERSION` -> `core/VERSION`
- `core/scripts/detect-ci-provider.sh` -> `core/scripts/detect-ci-provider.sh`
- `core/skills/ci-integration/` -> `core/skills/ci-integration/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none)

## Manual follow-ups for the user

- Copy the new `/monorepo-harness-ci` entry point for whichever adapter(s) you use:
  - Claude Code: copy `adapters/claude-code/.claude/commands/monorepo-harness-ci.md` into
    `.claude/commands/`.
  - opencode: copy `adapters/opencode/.opencode/commands/monorepo-harness-ci.md` into
    `.opencode/commands/`.
  - Codex: copy `adapters/codex/.agents/skills/monorepo-harness-ci/` into `.agents/skills/`
    (recursive).
- Optionally run `/monorepo-harness-ci` (or `bash .agents/monorepo-agents-harness/core/scripts/detect-ci-provider.sh --provider`
  directly) to wire `memory-gate.sh` into your project's CI. Entirely opt-in — nothing runs or
  writes automatically.

## Release summary

- New `/monorepo-harness-ci` capability: detects the target project's CI provider and wires
  `memory-gate.sh` into it — full automation (new dedicated workflow file, with consent) for GitHub
  Actions, guided snippets for GitLab/Bitbucket/CircleCI (single-pipeline-file formats that can't be
  safely auto-integrated as a separate file), or an opt-in starter when no provider is detected.
