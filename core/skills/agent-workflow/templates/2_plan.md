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
<Cite matches from the Phase 1 prior-art grep as
`- [slug](task_YYYY_MM_DD_slug/1_spec.md) — why relevant`, or `- none found`.>

## Steps
1. ...
2. ...

## Affected files / modules
- ...

## Risks & assumptions
- ...

## Definition of done
- [ ] ...
