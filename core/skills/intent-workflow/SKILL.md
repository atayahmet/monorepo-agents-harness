---
name: intent-workflow
description: Capture a stakeholder's problem description as an intent file before it becomes a plan-mode task, and let a product owner or manager review pending intents and approve or reject them. Use when the user types /monorepo-harness-intent, describes a new feature/problem without being in an active coding task, or asks to review pending intents.
---

# Intent Capture and Review

Captures a request **before** it has been scoped into a plan-mode task, and gates it behind an
explicit human approval before it can become one. This is the harness's entry point for
non-engineering stakeholders — a product owner, manager, or any team member can describe a problem
without knowing which workspace or files it touches; `core/skills/agent-workflow/SKILL.md` picks up
an **approved** intent later, once someone actually starts the engineering work.

Full format and lifecycle rules: `core/governance/intents/AGENTS.md`.

## Workflow — Capture

Triggered when a stakeholder describes a new problem or feature idea, or explicitly asks to file an
intent.

1. Resolve the target workspace the same way `agent-workflow` does (`apps/<name>` or
   `packages/<name>`) — ask if it's unclear from the description; unlike a plan-mode task, an intent
   author may not know the codebase, so guess conservatively and confirm.
2. Decide a `slug` (`snake_case`, 3-5 words) and today's date.
3. Write `<workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md` following the template in
   `core/governance/intents/AGENTS.md`, frontmatter `status: pending`.
4. Confirm to the author what was recorded and that it now awaits review — do not imply it has been
   approved or that work will start.

## Workflow — Review

Triggered when a product owner/manager asks to review pending intents, or via
`/monorepo-harness-intent review`.

1. List every `<workspace>/.agents/intents/intent_*.md` with `status: pending` (grep the
   frontmatter across all workspaces, or the one named by the reviewer).
2. For each, present its Problem/Proposed outcome/Affected users/Constraints/Open questions.
3. Ask, per intent: **"Approve this intent?"** (yes / no / edit). Never change `status` without an
   explicit answer in the current turn — same discipline as
   `core/skills/agents-md-merge/SKILL.md`'s "Apply this merge to AGENTS.md?" gate.
   - **Yes** → set `status: approved`, append a `## Review` section (Decision, Reviewer, Date,
     optional Notes).
   - **No** → set `status: rejected`, append the same `## Review` section with a reason if given.
     The file is **never deleted**.
   - **Edit** → apply the requested changes to the intent's content, leave `status: pending`, and
     return to step 3 for the same intent.

## Connection to `agent-workflow`

An approved intent is optional input to plan-mode work, not a requirement — see
`core/governance/intents/AGENTS.md`'s "Relationship to the plan/spec/memory/verify workflow" and
`core/skills/agent-workflow/SKILL.md` Phase 1. This skill does not create task directories, plans,
or specs itself.

## Edge cases

- **No `<workspace>/.agents/intents/` yet**: run
  `core/scripts/scaffold-workspace-agents.sh` first (it seeds `intents/AGENTS.md` for every
  discovered workspace), or create the directory manually before writing the first intent.
- **Author doesn't know the workspace**: ask; if genuinely cross-cutting, file it under the
  workspace most likely to drive the eventual work and note the ambiguity in "Open questions."
  Same convention as cross-workspace plan-mode tasks.
- **Reviewer wants to bulk-approve**: still ask per intent — a single "approve all" answer is fine
  as the consent for the whole batch, but each file's `## Review` section is still written
  individually with its own timestamp.
