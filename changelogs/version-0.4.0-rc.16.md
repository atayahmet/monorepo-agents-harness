---
version: 0.4.0-rc.16
from: 0.4.0-rc.15
date: 2026-10-11
---

# Version 0.4.0-rc.16 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.15 to 0.4.0-rc.16. This release makes the
stage command stubs name the knowledge-base query, so the read step reaches the agent on every `-spec`
and `-plan` run, not only in the shared skill.

## What changed

The stage command stubs are what the agent reads on every stage run, but none named the KB: only
`-build` touched it, and only to write (`kb-ingest.sh` / `check-kb`), so from the stubs' point of view
the KB was write-only. Each of the six stubs now has a step — **before** writing `1_spec.md` /
`2_plan.md` — that runs
`bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<1–3 keywords>"` and points at
`core/skills/agent-workflow/SKILL.md` Phase 1 check 1 (the single source of the check, per
`0.4.0-rc.15`): `-spec` keeps the top hits ready to cite; `-plan` cites the `knowledge/…` pages under
`## Related prior work`. Files:
`adapters/claude-code/.claude/commands/monorepo-harness-{spec,plan}.md`,
`adapters/opencode/.opencode/commands/monorepo-harness-{spec,plan}.md`,
`adapters/codex/.agents/skills/monorepo-harness-{spec,plan}/SKILL.md`. All six are existing `copy`
rows — no manifest change.

`PORTABILITY.md` (Knowledge-base row and its semantic-difference note) and the `INSTALL.md` §6
Knowledge-base bullet no longer imply the KB is build-only; both now name the `-spec`/`-plan` read
step. The Knowledge-base row's `-build` ingest step number was corrected to 6.

No script, manifest, adapter row, hook, or gate changed. Instruction-only.

## Commands to run

- None by hand. There is nothing to install: the six stage stubs are existing `copy` rows and reach the
  project on the normal adapter refresh, and the two docs ship in the bundle sync.

## Manual follow-ups for the user

- None. Existing specs and plans are untouched; the new stub step takes effect on the next `-spec` or
  `-plan` run.

## Release summary

- The six `-spec`/`-plan` stubs (claude-code, opencode, codex) name `kb-index.sh query` before writing
  the artifact (closes #28).
- `PORTABILITY.md` and `INSTALL.md` §6: KB is no longer described as build-only; the `-build` ingest
  step number is corrected to 6.
