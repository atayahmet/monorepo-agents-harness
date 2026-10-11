---
version: 0.4.0-rc.18
from: 0.4.0-rc.17
date: 2026-10-11
---

# Version 0.4.0-rc.18 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.17 to 0.4.0-rc.18. This release makes a
plan record that the knowledge base was queried, and has the gate surface a missing record — as an
advisory that never blocks.

## What changed

Even with the Phase 1 instructions fixed (#27), nothing showed whether the KB was actually queried
before a spec or a plan: `check-spec`/`check-plan` verified `phase:` and `check-adr` verified the ADR
section, so a skipped prior-art step left no trace. `2_plan.md`'s existing `## Related prior work`
section now carries a `- KB:` line — `- KB: [[<page>]] (knowledge/…)` naming the pages the query
returned, or the explicit `- KB: no relevant pages` for none.

New advisory in `core/scripts/task-state.sh check-plan` and `check-chain` (run by `-build`): when the
`KB:` line is missing it prints a `— advisory: …` line and **still exits 0**, the same fail-open
contract as `check-adr`, so an in-flight plan written before the convention is never blocked. The
`pr-review` skill adds a Prior-art pass that raises a **Nit** when a matched task's plan has no KB
citation.

Files: `core/scripts/task-state.sh` (new `prior_art_warning` helper + two call sites + usage header);
`core/skills/agent-workflow/templates/2_plan.md` (`- KB:` line contract);
`core/skills/agent-workflow/SKILL.md` (Phase 1/2 wording + edge case);
`core/skills/knowledge-base/SKILL.md` (query fast-path record step); `core/skills/pr-review/SKILL.md`
(Prior-art pass + Nit); `PORTABILITY.md` (KB row + semantic note). No adapter change and no new manifest
row — the rule lives in the shared template, script and skill.

## Commands to run

- None by hand. There is nothing to install: the script, template and skills ship inside `core/`, which
  is carried whole by the existing install row.

## Manual follow-ups for the user

- None. The check is advisory, so a plan written before this convention still passes — it only gets the
  advisory line. You may add the `- KB:` line to an in-flight plan when convenient, but nothing requires
  it.

## Release summary

- `core/scripts/task-state.sh`: new `prior_art_warning` advisory on `check-plan`/`check-chain` (exit 0)
  (closes #32).
- `core/skills/agent-workflow/templates/2_plan.md`: `## Related prior work` requires a `- KB:` line.
- `core/skills/agent-workflow/SKILL.md` and `core/skills/knowledge-base/SKILL.md`: record the KB query.
- `core/skills/pr-review/SKILL.md`: Prior-art pass raises a Nit for a missing KB citation.
- `tests/prior-art.test.sh`: repo-local test for the advisory contract.
- `PORTABILITY.md`: KB row + semantic note updated.
