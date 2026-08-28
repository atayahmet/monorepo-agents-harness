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

1. **Always ask which workspace the intent should be filed under.** Present the workspace you would
   recommend as the prompt's own suggestion, then let the author confirm or override it. Resolve the
   recommendation the same way `agent-workflow` does (`apps/<name>` or `packages/<name>`) from the
   description; an intent author may not know the codebase, so phrase it as a suggestion, e.g.
   "File this intent under `apps/api`? (my recommendation)". Do **not** write the intent file (or any
   part of it, including the `slug`/frontmatter) until the author gives an explicit workspace in the
   current turn — a wrong workspace misroutes both the review inbox and the later plan-mode task.
2. Then decide a `slug` (`snake_case`, 3-5 words) and today's date.
3. **Ask whether to create a dedicated branch for the intent, with a name you propose.** Offer
   `intent/<slug>` (the slug from step 2), e.g. "Create an `intent/add_login_form` branch for this
   intent? (my recommendation)", and let the author confirm or decline. If they confirm, create it
   **with git** (`git switch -c intent/<slug>` or `git checkout -b intent/<slug>`) *before* writing
   the file, so the intent lives in isolation; if they decline, stay on the current branch and write
   the file there — never create a branch without the explicit in-turn answer, and never leave the
   working tree on a branch the author didn't consent to.
4. **Ask separately whether to commit the intent file to that branch.** Only when step 3 created a
   branch, ask e.g. "Commit `intent_add_login_form.md` to `intent/add_login_form` now?" — a distinct
   consent, not bundled with the branch question. On an explicit yes, commit the `status: pending`
   intent file to the branch; on no or when no branch was created, leave the file in the working tree
   uncommitted. Do not commit an intent unless the author answers this in the current turn — the
   intent is still `pending` and the author decides whether it lives on a dedicated commit or just in
   the working tree.
5. Write `<workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md` following the template in
   `core/governance/intents/AGENTS.md`, frontmatter `status: pending`.
6. Confirm to the author what was recorded (workspace, branch, commit status) and that it now awaits
   review — do not imply it has been approved or that work will start.

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
- **Author doesn't know the workspace**: the capture step still always asks — present your
  recommendation, and if the author genuinely can't decide, note the ambiguity in "Open questions"
  and confirm the most likely target before writing. Never silently file under the most likely
  workspace without the explicit in-turn answer step 1 requires. Same convention as cross-workspace
  plan-mode tasks.
- **Intent file is gitignored (can't commit it)**: `<workspace>/.agents/` may be excluded in the
  host project's `.gitignore` (or a root `/.agents/` exclusion may shadow it). If the author asks to
  commit but the intent file is untracked/ignored, tell them why it can't be committed and leave it
  in the working tree, or ask them to adjust `.gitignore` — never force-add (`git add -f`) an intent
  against the project's ignore rules.
- **Reviewer wants to bulk-approve**: still ask per intent — a single "approve all" answer is fine
  as the consent for the whole batch, but each file's `## Review` section is still written
  individually with its own timestamp.
