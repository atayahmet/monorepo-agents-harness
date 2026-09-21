---
version: 0.2.0-rc.5
from: 0.2.0-rc.4
date: 2026-09-21
---

# Version 0.2.0-rc.5 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.4 to 0.2.0-rc.5 (docs-only tightening of
the `agent-workflow` skill).

## Commands to run

None. This release changes only the installed skill's documentation
(`core/skills/agent-workflow/SKILL.md`); the normal update sync
(`install-harness.sh --sync-only`) ships it via the `core` manifest row. No adapter entry point
changed, so `install-adapter.sh <agent> --refresh` is not required.

## Manual follow-ups for the user

- None. `core/root-AGENTS.md` was not changed, so there is no `AGENTS.md` reconciliation step.

## Release summary

- `core/skills/agent-workflow/SKILL.md` docs tightened — no behavior or artifact-format change:
  - Frontmatter `description` now counts the four real artifacts (spec, plan, memory, verify), names
    every driving trigger (the stage commands plus the plan-mode approval signal), and no longer
    embeds project-specific example workspace names.
  - The `<workspace>` definition now derives from the project's `apps/*` / `packages/*` directories
    instead of a hardcoded list.
  - The research-only path (hand-written plan, no spec/memory/verify) is documented consistently with
    the `-plan`/`-build` gates that require a spec.