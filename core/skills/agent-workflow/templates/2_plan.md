---
phase: plan
date: <YYYY-MM-DD>
slug: <slug>
status: approved
# build_started: <ISO-8601> — written by `task-state.sh mark-build` when the build starts. Never
# fill it in by hand and never remove it: it is how the memory-gate tells a task that is being
# built from one that is still waiting.
---

# Plan: <Task title>

## Problem
<The problem being solved, 1–3 sentences> — problem originally captured and approved in [0_intent.md](0_intent.md).
Omit the trailing clause for ad-hoc tasks with no `0_intent.md`.

## Approach
<High-level strategy, 2–5 sentences>

## Related prior work
<Cite the Phase 1 results. Start with the mandatory knowledge-base line — `- KB:` naming the pages
the query returned, or the explicit no-hits form when it returned none:
- KB: [[<page>]] (`knowledge/<area>/<page>.md`) — why relevant
- KB: no relevant pages
Then the task-dir hits from the index search:
- [<slug>](task_YYYY_MM_DD_slug/1_spec.md) — why relevant
- none found
`task-state.sh check-plan` and `check-chain` print an advisory (never a failure) when the `- KB:`
line is missing.>

## Steps
1. ...
2. ...

## Affected files / modules
- ...

## Risks & assumptions
- ...

## Definition of done
- [ ] ...
