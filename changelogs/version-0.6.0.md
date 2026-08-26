---
version: 0.6.0
from: 0.5.0
date: 2026-08-26
---

# Version 0.6.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.5.0 to 0.6.0.

This release wires the workspace artifact index into the plan workflow itself. Previously,
`<workspace>/.agents/artifacts/index.md` was formatted for keyword grep ("prior art" lookup,
documented in `core/governance/artifacts/AGENTS.md`) but nothing in the actual workflow told an
agent to search it before writing a new plan. From this version, searching the index is a required
step immediately before `1_plan.md` is written, and the plan template gained a `## Related prior
work` section so the search leaves a visible, greppable trace instead of happening silently (or not
at all). This is an instruction-level requirement, not a hard gate — no scripts or hooks changed.

## Files to copy from the new bundle to the installed bundle

Copy the following from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`. Directories ending in `/` are copied
recursively and replace the target directory entirely.

- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `core/skills/agent-workflow/SKILL.md` -> `core/skills/agent-workflow/SKILL.md`
- `core/governance/artifacts/AGENTS.md` -> `core/governance/artifacts/AGENTS.md`

## Files to delete from the installed bundle (only if they exist)

- None.

## Commands to run

None.

## Manual follow-ups for the user

- If the project's root `AGENTS.md` was adopted/merged from `core/root-AGENTS.md` (per the
  `agents-md-merge` workflow introduced in 0.5.0), re-run that merge so the updated "Before You
  Start" checklist item and "Agent Lifecycle" step 1 wording reach the project's own `AGENTS.md`.
- No artifact-layout change: existing `1_plan.md` files without a `## Related prior work` section
  remain valid. Only plans written after this upgrade need the new section.

## Release summary

- `core/skills/agent-workflow/SKILL.md` Phase 1 now requires grepping
  `<workspace>/.agents/artifacts/index.md` for prior art (1–3 keywords derived from the task)
  before `1_plan.md` is written; on a match, the matched task's `2_spec.md` (and `3_memory.md` if
  ◆-marked) is read and summarized.
- The `1_plan.md` template gained a required `## Related prior work` section, placed after
  `## Approach` and before `## Steps`.
- `core/root-AGENTS.md`'s "Before You Start" checklist and "Agent Lifecycle" step 1 now reference
  the workspace artifact index alongside `session-log.md`/`lessons.md`.
- `core/governance/artifacts/AGENTS.md` gained a cross-reference note (new rule 6) pointing at the
  skill for search timing, keeping the index-format doc and the workflow-timing doc in sync.
