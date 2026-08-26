---
version: 0.7.0
from: 0.6.0
date: 2026-08-26
---

# Version 0.7.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.6.0 to 0.7.0.

## Files to copy from the new bundle to the installed bundle

- `core/VERSION` -> `core/VERSION`
- `core/skills/` -> `core/skills/` (recursive directory copy)
- `core/scripts/` -> `core/scripts/` (recursive directory copy)
- `core/governance/` -> `core/governance/` (recursive directory copy)
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `core/workspace-agents-template/` -> `core/workspace-agents-template/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

(none — `4_verify.md` is a new per-task artifact, not something that needs scaffolding)

## Manual follow-ups for the user

- **Claude Code installs only**: copy the new `adapters/claude-code/.claude/agents/verifier.md`
  subagent into `.claude/agents/verifier.md` (see `adapters/claude-code/INSTALL.md` step 7). If you
  installed only opencode or Codex, skip this — those adapters have no subagent primitive and need
  no new files; the same verification instructions already apply inline via `agent-workflow`
  SKILL.md Phase 4.
- Re-read `adapters/<your-agent>/INSTALL.md` and `adapters/<your-agent>/README.md` for the updated
  "What maps to what" table and day-to-day workflow steps (Feedback Loop verification step added
  before commit).

## Release summary

- New `4_verify.md` artifact enforces the AI-native SDLC "Feedback Loop" practice: whenever a
  task's `2_spec.md` states a real (non-`N/A`) verification plan, `core/scripts/memory-gate.sh` now
  blocks task completion until that verification actually ran and its evidence was recorded — in
  both the default git/CI gate and the Claude Code `--json` Stop-hook mode (previously the Stop
  hook only checked `3_memory.md`).
- New `verifier` subagent for Claude Code produces that evidence in an isolated, read-only context.
  opencode/codex have no subagent primitive; per the harness's mandatory-parity rule they run the
  same verification instructions inline in the main session instead — documented as a new
  capability-matrix row and semantic-difference note in `PORTABILITY.md`.
- Also formally releases the previously-implemented `2_spec.md` "Data model" and
  "Test / verification plan" sections (was sitting unversioned in `changelogs/draft.md`).
