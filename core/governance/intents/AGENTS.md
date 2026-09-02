# Agent Intent Capture — Rules

Every workspace (`apps/<name>` or `packages/<name>`) owns an **intent inbox** under
`<workspace>/.agents/intents/`, separate from `<workspace>/.agents/artifacts/`. An intent is a
stakeholder's problem description **before** it has been scoped into a plan-mode task — this is
where the harness's plan/spec/memory/verify workflow begins, when a task originates from an intent
rather than an ad-hoc engineering request.

## Directory layout (per workspace)

```
<workspace>/
  .agents/
    intents/                          <- THIS convention
      AGENTS.md                       <- pointer to these rules (seeded by the scaffold script)
      intent_<YYYY_MM_DD>_<slug>.md   <- one file per intent
```

Workspaces are seeded by `.agents/monorepo-agents-harness/core/scripts/scaffold-workspace-agents.sh`
(creates `intents/AGENTS.md`); re-run it after adding a workspace.

**The target inbox is author-confirmed, never assumed.** On capture, the agent always asks which
workspace the intent should be filed under and presents its own recommendation (per
`core/skills/intent-workflow/SKILL.md`); the file is written only after the author confirms that
workspace in the current turn. Filing an intent into the wrong inbox misroutes both the review step
and the later plan-mode task that would consume an approved intent.

**An intent may live on its own branch, by explicit consent.** On capture the agent proposes a
dedicated `intent/<slug>` branch (slug-derived name per `core/skills/intent-workflow/SKILL.md`) and
asks whether to create it, then asks separately whether to commit the `status: pending` file to it.
Both are consent questions answered in the current turn: a branch is created only when approved, and
a `pending` intent is committed only when its own commit question is answered yes. Whether the intent
file is tracked by git is the host project's own decision — the harness does not mandate it.

## Intent file format

```markdown
---
status: pending
author: <name or role>
date: <YYYY-MM-DD>
slug: <slug>
---

# Intent: <short title>

## Problem
<1-3 sentences: what's wrong or missing today>

## Proposed outcome
<What should be true once this is built>

## Affected users / systems
<Who or what this touches>

## Constraints
<Known limits: no new dependencies, must not touch X, deadline, etc.>

## Open questions
<Anything unresolved that the reviewer, or a future plan, should address>
```

**`status`** is the lifecycle field: `pending` (awaiting review) → `approved` or `rejected`. On
review, the reviewer appends a `## Review` section:

```markdown
## Review
- Decision: approved | rejected
- Reviewer: <name or role>
- Date: <YYYY-MM-DD>
- Notes: <optional>
```

**`slug`** follows the same convention as task slugs (`snake_case`, `[a-z0-9_]`, 3-5 words) — an
approved intent's slug is reused as the basis for the resulting task's slug where practical, so the
connection stays traceable.

## Status lifecycle rules

1. **Never delete an intent file**, regardless of decision — `rejected` intents stay as an audit
   trail of what was considered and why it wasn't pursued. This mirrors the harness's existing
   discipline for declined `AGENTS.md` merges (`core/skills/agents-md-merge/SKILL.md`): a decline is
   recorded, not erased.
2. **Never change `status` without an explicit consent question answered in the current turn** —
   `core/skills/intent-workflow/SKILL.md`'s Review flow asks "Approve this intent?" and only writes
   the decision on an explicit affirmative or negative; it never infers a decision.
3. **One file per intent, never renamed after creation** — `slug` and filename must agree, the same
   way task slugs are immutable once a task directory exists
   (`core/governance/artifacts/AGENTS.md`).
4. **English everywhere** — intents are read across the team, same rule as every other artifact.

## Relationship to the plan/spec/memory/verify workflow

An **approved** intent is optional input to `core/skills/agent-workflow/SKILL.md`'s Phase 1: before
writing `1_spec.md`, the agent may find an approved intent in
`<workspace>/.agents/intents/` matching the task at hand. If found, it is copied into the task's own
directory as `0_intent.md`, included in `1_spec.md` frontmatter as `intent: 0_intent.md`, and
cited in `2_plan.md`'s `## Problem` section with an explanatory link such as
`problem originally captured and approved in [0_intent.md](0_intent.md)`. This is a best-effort
match, not a mandatory search like the artifact-index prior-art check
(`core/governance/artifacts/AGENTS.md`) — most ad-hoc engineering tasks have no intent behind them
and omit both the frontmatter line and the trailing clause.
