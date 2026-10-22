---
phase: spec
date: <YYYY-MM-DD>
slug: <slug>
intent: 0_intent.md   # only when task is seeded by an approved intent; omit for ad-hoc tasks
---

# Spec: <Task title>

## Scope
<The boundaries of this change — what is included, what is excluded>

## Behavioral contract
- Input: ...
- Output: ...
- Side effects: ...

## API / contracts
<Endpoints, function signatures, event payloads — changing contracts>

## Data model
<Fields/types/structure of any persisted or transmitted data this task reads or writes —
table/column names, JSON payload shape, event schema. Write "N/A" if no data model is touched.>

## Acceptance criteria
- [ ] ...

## Test / verification plan
Tier: <red-first | evidence-only>
<Pick the tier by the kind of work, then say how each acceptance criterion is checked — command,
test file, or manual repro steps:
- `Tier: red-first` — a bug fix, or new behavior with a clear contract (API, domain logic, CLI).
  Write the failing test first, watch it fail for the expected reason, then implement.
- `Tier: evidence-only` — UI, config, glue or exploration. Manual or browser evidence is enough.
Write "N/A" only for research-only tasks with no verifiable behavior change. A spec with no tier line
is treated as a legacy task: no red-first advisory fires for it.>

## Architectural constraints
<Layer rules, module boundaries, and non-functional requirements (performance, security,
compatibility) — consistent with root AGENTS.md gotchas>

## Architectural decisions
<Architecture-affecting decisions this task makes — one bullet per decision, linking the record the
`adr-workflow` skill writes into this task's `adr/` directory (Phase 1, below):
- [0001 - <Title>](adr/0001-<title>.md) — <one-line rationale>
Write "N/A" when the task makes no architecture-affecting decision (see
`core/skills/adr-workflow/SKILL.md` for the threshold).>
