---
name: adr-workflow
description: Captures architecture-affecting decisions as Architecture Decision Records
  (adr/NNNN-<title>.md) inside the active task directory. Trigger automatically during the
  agent-workflow Phase 1 (spec, when the spec's "## Architectural decisions" section lists one or
  more decisions) or Phase 2 (plan, when the plan surfaces a decision not yet recorded): a new
  external dependency or service integration, a persistent data-model change, a cross-workspace
  API/event contract change, a delivery-guarantee change (idempotency, retry, ordering), an
  auth/security model change, or any choice between alternatives with material, hard-to-reverse
  consequences. Also triggered when a review flags an architecture-affecting diff with no ADR.
  Write the ADR before moving on to the plan — do not wait for task end.
---

# ADR Workflow — Architecture Decision Records inside the Task Directory

When a task makes an **architecture-affecting decision**, the reason it chose one option over the
others deserves a record that survives the session — the full chain becomes readable in git:
"this need (`0_intent.md`) ↦ this decision (ADR) ↦ this plan (`2_plan.md`)".
This skill writes that record.

ADRs are **conditional by design**: tasks with no architecture-affecting decision write `N/A` and
are done — no empty `adr/` directory, no gate. The `3_memory.md` `## Related decisions` section stays
the *session-level* summary; the ADR is the *durable, linked* record of the decision itself. Do not
duplicate: put the full context/alternatives record in the ADR and only a one-line pointer in memory.

## When to write an ADR (triggers)

Write at least one ADR when the task makes a decision that:

1. **Adds an external dependency or service** — a new package, vendor, SDK, queue/topic, database,
   or third-party API the code must now integrate with and could later have to migrate away from.
2. **Changes the persistent data model** with a long-lived or cross-workspace ripple — new fields a
   consumer must read, a table/collection rename, a denormalization, a new event schema.
3. **Changes a cross-workspace contract** — an `apps/*` ↔ `apps/*` (or package) API/event surface
   other workspaces build against.
4. **Changes delivery guarantees** — idempotency, retry/backoff semantics, ordering, at-most-once →
   at-least-once → exactly-once, queue redelivery behavior.
5. **Changes the auth/security/permission model** — new auth provider, token lifetime/scope change,
   RBAC shape, a security tradeoff (e.g. short-lived vs. long-lived credentials).
6. **Is any choice between alternatives with material, hard-to-reverse consequences** — caching
   strategy, monolith vs. service split, sync vs. async boundary, library X vs. Y when switching
   later is expensive. This is the default catch-all: when in doubt, record it.

Also write/amend an ADR when the decision **supersedes** an earlier one — set `supersedes:` to the
older ADR's path so git history shows the decision churn, not just the latest state.

## When NOT to write an ADR

- The change is fully reversible and cheap to change (a private function's shape, a local
  implementation detail, cosmetic refactoring with no contract or behavior change).
- The decision was already mandated by an existing spec/ADR/root rule — record a pointer, not a new
  decision.
- The task is research-only with no decision to lock in yet.

If the threshold is not met, write `N/A` under the spec's `## Architectural decisions` and create no
`adr/` directory. The review pass (`pr-review` skill) will only complain about *missing referenced*
ADRs and `N/A` where the change looks architecture-affecting — a Nit, not a block.

## Where ADRs live

Inside the **task directory** that produced them, so the decision travels with the artifacts that
made it:

```
<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/
├── 1_spec.md          # links each decision from its "## Architectural decisions" section
├── 2_plan.md
├── adr/
│   ├── 0001-<title>.md
│   └── 0002-<title>.md   # sequence restarts per task directory
└── ...
```

- **File name:** `NNNN-<kebab-case-title>.md` — zero-padded 4-digit sequence starting at `0001`,
  plus a short `kebab-case` title, e.g. `0001-deterministic-idempotency-key.md`.
- **Sequence semantics:** one sequence per task directory; order by decision *time*, not by
  importance. Renumbering is forbidden once committed (the numbers are referenced from the spec).
- **Reference from the spec:** each decision gets one bullet under the spec's
  `## Architectural decisions` section, linked task-relative:
  `- [0001 - <Title>](adr/0001-<title>.md) — <one-line rationale>`.
- **Never** create a task for an ADR on its own — decisions are recorded in the task that made them.

## The ADR template

```markdown
---
phase: adr
date: <YYYY-MM-DD>
slug: <task-slug>
adr: <NNNN>
status: accepted
supersedes: <task-relative path of the ADR this decision replaces, or omit>
---

# ADR NNNN — <Title>

## Context
<The problem and the forces at play: what triggered this decision, the constraints, the "why now".
Reference 0_intent.md / spec.md sections by name where they supplied the forces.>

## Decision
<The choice made, 1–3 unambiguous sentences. State what was chosen — not what is true forever.>

## Alternatives considered
- <Option A> — <why considered, why rejected or kept on the table>
- <Option B> — <why considered, why rejected or kept on the table>
<Explicitly capture the alternatives that were rejected — this is what makes the record audit-proof.>

## Consequences
<What becomes easier, what becomes harder; follow-ups this decision forces (migrations, rewrites,
monitoring, docs).>

## Related prior ADRs
<Prior-art grep of <workspace>/.agents/artifacts/index.md (same as agent-workflow Phase 1) — cite
earlier tasks whose decisions feed or constrain this one, or "- none found".>
```

Do not invent numbers or paths; the names must round-trip with `task-state.sh check-adr` (see below).

## Workflow

1. **During Phase 1 (spec):** while writing `1_spec.md`, when the spec's
   `## Architectural decisions` section lists a decision, immediately apply this skill and write the
   corresponding `adr/NNNN-<title>.md` file(s) **in the same pass** — before moving on to the plan.
   The spec is the entry point; the ADR is written alongside it, not deferred to task end.
2. **During Phase 2 (plan):** when `2_plan.md` surfaces a decision the spec did not record (or the
   `## Approach` contradicts the spec's decisions), write/amend the ADR then, and reference it from
   the plan's `## Approach`.
3. **Before committing:** run the read-only validation
   `bash <bundle>/core/scripts/task-state.sh check-adr <task>/1_spec.md` — it fails when a
   referenced ADR is missing or lacks `phase: adr`. Treat a failing check as a reason to fix the
   spec bullets or the ADR, not to skip the check.
4. **At review time:** the `pr-review` skill runs the same `check-adr` and reports missing ADRs as
   Important, `N/A` on an architecture-affecting diff as (at most) a Nit.

## Edge cases

- **Multiple decisions in one task** — write one ADR file each; reference all of them from the
  spec section.
- **A decision changes mid-task** — amend the existing ADR (add a `## Revisions` note), keep the
  number; a *different* future task superseding it gets a new ADR with `supersedes:`.
- **Backcompat** — a pre-existing spec without the `## Architectural decisions` section is treated
  as "no ADRs declared"; `check-adr` fails open, so in-flight tasks are never blocked.
- **No prior art** — `## Related prior ADRs` states `- none found`; do not invent citations.