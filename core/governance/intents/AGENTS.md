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
pr: <optional PR URL or #number>
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

## Visual summary (optional)
<If a diagram clarifies the problem or proposed flow better than text alone, add a mermaid diagram
here. Do not add a diagram just for the sake of having one.>
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

**`pr`** is optional and defaults to nothing: an intent without it is complete and valid. Set it when
the intent itself already lives in a pull request (a stakeholder filing it from a branch, a review
comment thread). `/monorepo-harness-intent-dispatch` then pushes the **commit that carries the
approval** — the one adding the `## Review` section — to that PR's branch, so the PR shows the
decision. Only a branch the user names is pushed, never a force-push.

**`## Dispatch`** is the record of what a dispatch actually filed, appended by dispatch and by nothing
else. It is what keeps an approved decision traceable to its work after the PR is merged and the
conversation is gone:

```markdown
## Dispatch — 2026-09-29
- Tracker: github acme/web
- Epic: #412 (https://github.com/acme/web/issues/412)
- Phases:
  - add_login_form: #413 (https://github.com/acme/web/issues/413)
  - login_error_copy: #414 (https://github.com/acme/web/issues/414)
  - verify_email_flow: no issue yet (jira is not implemented by this harness)
```

Its rules:

1. **Append-only, one block per dispatch run, newest last.** Never rewrite or delete an earlier block.
   A re-run appends a new one, which is what lets it find the epic it must reuse.
2. **The `Epic` line is omitted entirely when there is no epic** — a single-phase intent, or a
   developer who answered "no epic". A line reading "no epic" would be indistinguishable from a
   decision that was made and rejected.
3. **One line per phase, with the phase slug**, so a later reader can match it to the phase list. A
   phase that did not get filed reads `no issue yet (<reason>)`; the reason is the script's, never
   yours.
4. **Only what the script printed.** A key is never inferred from a title, carried over from an
   earlier turn, or written for an issue that does not exist. A dispatch that filed two of three
   phases records two keys and one `no issue yet` — a partial run records the partial truth.
5. **The block points at the issues; it never scopes one.** The phase's scope, workspace and
   verification command stay in the issue body, and the task artifacts stay with
   `/monorepo-harness-spec` and `/monorepo-harness-plan`.
6. **The key is the tracker's own.** A GitHub `#413`, a Jira `MOBP-123`, a Linear `ENG-9` — whatever
   the platform uses, copied from what the create actually returned. The harness only creates on
   GitHub today, so on `jira` / `linear` most lines are `no issue yet` until the developer files them
   and the next dispatch records what they report.

**One parent issue groups the phases.** When a dispatch splits an intent into more than one phase, the
developer is asked, in the sign-off step, whether to file the phases **under an epic**. On a "yes" the
harness creates one parent issue and files every phase as its sub-issue — a real parent/child relation
on the tracker, so the board itself shows the grouping rather than a label or a line of prose. A
single-phase intent gets no epic, and "no epic" is always an answer the developer can give. An epic
already recorded in the newest `## Dispatch` block is **reused** on a re-run, so dispatch never files
two. A candidate from the open-work check can become the epic, but only when the developer names it in
that turn.

**A dispatch reads the tracker before it writes to it, and merges only on an explicit answer.** Before
creating anything, the command checks whether the same work is already open
(`tracker-issue.sh --list-open`, read-only — it never comments, labels, assigns or closes) and asks
before filing it anyway; a check that cannot run is reported and the dispatch continues, so a skip is
never silent. The `pr:` field is then read twice: dispatch checks it first to read the approval, and at
the very end asks *"Merge the intent PR (#N) now?"* — after the issues exist,
never before. The merge is performed by `core/scripts/task-state.sh merge-intent-pr`, which re-checks
the approval itself and refuses a PR with no approving review (or one whose reviewer asked for changes
afterwards). **The PR does not have to be on GitHub.** Both reads go through
`core/scripts/forge.sh`, which decides the forge from the `pr:` value's own host, then
`.agents/tracker.md`'s `forge:`, then this repo's `origin` — never by assuming GitHub — and reaches
it with that platform's CLI or REST, using a token the project already exports. If no mechanism can
reach the PR (a project MCP server or skill, or Jira / Linear), the approval is **UNKNOWN** and
nothing is merged: the harness will not read the intent's own `status: approved` in place of a human
decision, and the dispatch says so and stops. Accepted forms: `42`, `#42`, `owner/name#42`, a PR URL
(`https://host/owner/name/pull/42`) or a scp-style PR URL (`git@host:owner/name/pull/42`) — all
normalized to one ref the script can use, and a cross-repository ref keeps its `owner/name` or full
URL so it can never resolve against the wrong project. A bare clone URL or branch name carries no PR
number, so it is refused rather than guessed at. **A `pr:` value that is still the template placeholder is
not a PR**, and the script says so rather than trying to fetch it — `<optional PR URL or #number>`
and an unexpanded `{{PR_URL}}` are both treated as "no PR" (fill it in, or pass `--pr <ref>`).
Quote the value if you like: `pr: "42"`, `pr: 'https://host/owner/name/pull/42'` and
`pr: #42` all work. Deleting the intent's branch after a
merge stays the developer's decision; the harness never deletes a branch.

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
`<workspace>/.agents/intents/` matching the task at hand. If found, a reference stub linking to it
is written into the task's own directory as `0_intent.md` — **never a copy of its content**, so the
intent file itself stays the single source of truth (a later `## Review` addendum or status change
on the original is never shadowed by a stale duplicate). `1_spec.md` frontmatter still gets
`intent: 0_intent.md`, and `2_plan.md`'s `## Problem` section still cites it with an explanatory link
such as `problem originally captured and approved in [0_intent.md](0_intent.md)`. This is a
best-effort match, not a mandatory search like the artifact-index prior-art check
(`core/governance/artifacts/AGENTS.md`) — most ad-hoc engineering tasks have no intent behind them
and omit both the frontmatter line and the trailing clause.

**Who writes what.** `/monorepo-harness-spec <intent.md>` is the **only** writer of `0_intent.md` —
it calls `core/scripts/write-intent-ref.sh`, which refuses an unapproved intent.
`/monorepo-harness-intent-dispatch` writes **no** task artifact: no `0_intent.md`, no `1_spec.md`, no
`2_plan.md`, no `artifacts/index.md` row. It records the approval on the intent file itself (see
`core/skills/intent-workflow/SKILL.md` Dispatch step 1), the **`## Dispatch` block** listing the
issues it filed (step 8, and the only writer of that section), and it opens one tracker issue per
phase under an optional epic; the phase scope lives in the issue body, not on disk. Two writers for
the stub would let it disagree with itself about `source:`, and an `index.md` row for a directory
nobody scoped is an index entry for work that does not exist. One file, one writer.
