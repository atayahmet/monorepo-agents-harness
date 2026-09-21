---
version: 0.2.0-rc.7
from: 0.2.0-rc.6
date: 2026-09-21
---

# Version 0.2.0-rc.7 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.6 to 0.2.0-rc.7 (slimmed
`agent-workflow` skill — 371 to 240 lines, templates extracted to files).

## Commands to run

None. This release restructures the installed `agent-workflow` skill's documentation and adds a
`templates/` directory next to it; the normal update sync (`install-harness.sh --sync-only`) ships
both via the `core` manifest row, which already installs the whole skill directory. No adapter entry
point changed, so `install-adapter.sh <agent> --refresh` is not required.

## Manual follow-ups for the user

- None. `core/root-AGENTS.md` was not changed, so there is no `AGENTS.md` reconciliation step.

## Release summary

- `core/skills/agent-workflow/SKILL.md` reduced from 371 to 240 lines with **no capability loss**:
  - The five inline fill-in templates (`0_intent_ref.md`, `1_spec.md`, `2_plan.md`, `3_memory.md`,
    `4_verify.md`) now live in `core/skills/agent-workflow/templates/` — byte-identical to the
    blocks they replace — and every phase points at its template file. Plan/spec/memory/verify
    artifacts produced before and after this release are interchangeable.
  - The two ASCII directory diagrams consolidated into one tree plus a packages note; the duplicated
    research-only explanation collapsed to the Stage-commands paragraph.
  - All normative prose preserved: phase timing, stage-command gates, stop-and-wait, Build-scope
    confinement, edge cases, slug/naming rules, and every script/skill cross-reference.
- No script, manifest, adapter, gate, or artifact-format change — docs/asset move only.