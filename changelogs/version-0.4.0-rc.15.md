---
version: 0.4.0-rc.15
from: 0.4.0-rc.14
date: 2026-10-11
---

# Version 0.4.0-rc.15 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.14 to 0.4.0-rc.15. This release makes the
spec and plan stages reach the knowledge base, so prior art is queried before a spec or a plan is
written instead of only at build time.

## What changed

`core/skills/agent-workflow/SKILL.md` Phase 1 check 1 only told the agent to grep
`<workspace>/.agents/artifacts/index.md`, so the spec and plan stages never ran the ranked
`kb-index.sh query` the root rule points at — the first query happened at build time. Phase 1 now runs
**four** checks: (1) query the repo-root knowledge base first
(`bash <bundle>/core/scripts/kb-index.sh query "<1–3 keywords>"`, BM25-ranked, grep fallback) and read
the top pages; (2) grep the task indexes for what the knowledge base does not cover. Check 2 also
defines the **new-workspace** case (no index yet → grep every existing workspace index) and the
**cross-cutting** case (also grep sibling workspace indexes); the repo-root index is read when the
project has no `apps/`/`packages/`.

`core/skills/agent-workflow/templates/2_plan.md`'s `## Related prior work` now asks for a `[[page]]`
(`knowledge/…`) line first, then the task-dir line, and keeps `- none found`. `README.md` and
`core/governance/artifacts/AGENTS.md` search-rule 6 were synced to the same wording.

No script, manifest, adapter, or gate file changed. This is a guide-text release.

## Commands to run

- None by hand. There is nothing to install: the change lives in the shared skill, the plan template, a
  governance doc, and the `README.md`, all carried by the normal update.

## Manual follow-ups for the user

- None. Existing specs and plans are untouched, and the four-check Phase 1 takes effect on the next spec
  or plan the agent writes.

## Release summary

- `core/skills/agent-workflow/SKILL.md`: Phase 1 runs the KB query first, then the task-index grep, with
  the new-workspace and cross-cutting cases (closes #27).
- `core/skills/agent-workflow/templates/2_plan.md`: `## Related prior work` asks for a knowledge-base
  citation before the task-dir line.
- `README.md` and `core/governance/artifacts/AGENTS.md`: same wording, no old single-grep behavior.
