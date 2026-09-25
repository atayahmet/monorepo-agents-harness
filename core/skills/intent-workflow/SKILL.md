---
name: intent-workflow
description: Capture a stakeholder's problem description as an intent file before it becomes a plan-mode task, let a product owner or manager review pending intents and approve or reject them, and execute an approved intent into scoped phases with one task directory and one tracker issue per phase. Use when the user types /monorepo-harness-intent or /monorepo-harness-intent-execute, describes a new feature/problem without being in an active coding task, asks to review pending intents, or asks to turn an approved intent into work.
---

# Intent Capture, Review, and Execution

Captures a request **before** it has been scoped into a plan-mode task, gates it behind an explicit
human approval, and — once approved — turns it into phased, tracked work. This is the harness's entry
point for non-engineering stakeholders — a product owner, manager, or any team member can describe a
problem without knowing which workspace or files it touches; `core/skills/agent-workflow/SKILL.md`
picks up the result later, one phase at a time.

Full format and lifecycle rules: `core/governance/intents/AGENTS.md`.

**Write in simple English.** Every file and developer message this skill produces follows
`../../governance/rules/simple-english.md` — short sentences, common words, active voice. This matters
most in **Execute**, whose issue titles and bodies are read by people outside the engineering pair.

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
   `core/governance/intents/AGENTS.md`, frontmatter `status: pending`. If a diagram would clarify the
   intent better than text alone, add an optional `## Visual summary` section with a mermaid diagram;
   do not add a diagram if it feels forced.
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

## Workflow — Execute

Triggered by `/monorepo-harness-intent-execute <intent.md>`, when an **approved** intent needs to
become real work. It plans and records the work; it **never implements it** — each phase is built
later through the normal `agent-workflow` chain. Nothing is written before the developer signs off on
the phase list.

1. **Confirm the approval first.** Run
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`.
   If it exits non-zero, report the reason and **stop** — do not write a file, do not ask about
   workspaces, do not create an issue. A `pending` intent has not been agreed to yet.
2. **Hand the approval to the PR, if the intent names one.** An intent may carry an optional `pr:`
   frontmatter field. When it is present, push the commit that carries the approval (the one adding
   its `## Review` section) to that PR's branch with `git push <remote> <sha>:<branch>`, then report
   the remote ref. No `pr:` field → skip this step silently. Never force-push, never guess a branch,
   never push anywhere the user did not name in this turn.
3. **Settle the workspace scope.** Derive the **primary** workspace the way `agent-workflow` does
   (`apps/<name>` or `packages/<name>`), list any **secondary** workspaces the intent touches, and
   ask the user to confirm — present your recommendation first. Write nothing before they answer.
4. **Split into phases: 3 to 5.** Each phase needs a title, its workspace, a 2-4 sentence scope, a
   verification command, and its issue title + body. **A phase is worth its own review.** If it is one
   edit, one file, or something no reviewer would look at separately, it is not a phase — fold it into
   a neighbour. Equally, do not split a phase that only makes sense as a whole. Give every phase a
   `snake_case` slug (3-5 words, `[a-z0-9_]`), unique across the **whole intent**, not just inside one
   workspace; a collision on a directory name is reported, never silently merged.
5. **Get the sign-off.** Show the phase table — number, title, workspace, verification — and ask
   **"Start these N phases?"** (yes / edit / fewer). A "fewer" answer means re-split and ask again.
   No task directory and no issue exists before an explicit yes in the current turn.
6. **Resolve the tracker once.** First hit wins: the `--tracker` argument, then `tracker:` in the
   phase plan's frontmatter, then ask the user and write the answer into that plan. This version
   implements **github** (GitHub Issues through the `gh` CLI) only. Linear or Jira need an MCP server
   or API token that the **developer** installs — the harness never asks for a credential and never
   stores one. If the user names a platform this version does not implement, say so plainly.
7. **Per phase, write the artifacts and open the issue.** For each approved phase, in the phase's own
   workspace: create `task_<YYYY_MM_DD>_<phase_slug>/` with `0_intent.md` (a reference stub with
   `phase: intent-ref` and `source: <intent path>` — never a copy), `1_spec.md` (the phase scope and
   acceptance criteria, seeded from the intent), and `2_plan.md` (`phase: plan`, `status: approved`,
   `tracker: <platform>`, a `## Tracker` section, and a `## Sign-off` block naming who approved the
   phase list and when). Add one row per phase to that workspace's `artifacts/index.md`. Then run
   `core/scripts/tracker-issue.sh --plan <2_plan.md> --title "<issue title>" --body-file <file>
   --create` and write the returned URL into the plan's `## Tracker` section. Do the index update for
   **all** phases before reporting back, not one phase per turn.
8. **Hand off and stop.** Report the per-phase task directory, its issue URL, and the command that
   starts the work: `/monorepo-harness-build <2_plan.md>`, one phase at a time. A phase can be
   re-planned first with `/monorepo-harness-spec` + `/monorepo-harness-plan` (which appends a
   `revisions:` entry to that phase's own `2_plan.md`).

**`tracker-issue.sh` exit codes** — 0 created (or dry-run printed), 1 guard failure, 2 usage error,
**3 not created** (`gh` missing or unauthenticated; the paste-ready title and body were printed). On 3,
keep the task directory, write "no issue yet" in the plan's `## Tracker` section, tell the user to
open it by hand, and continue with the remaining phases. On 1, report and stop. Never report an issue
that does not exist.

**Hard never's for this phase:** no source-file edits, no `3_memory.md` / `4_verify.md` (there is no
finished task yet), no implementation of any phase, no issue without an explicit yes, no token or
credential read or write, no push to a branch the user did not name, and no re-splitting of an
existing phase's plan behind the user's back.

## Connection to `agent-workflow`

An approved intent is optional input to plan-mode work, not a requirement — see
`core/governance/intents/AGENTS.md`'s "Relationship to the plan/spec/memory/verify workflow" and
`core/skills/agent-workflow/SKILL.md` Phase 1. **Capture** and **Review** create nothing beyond the
intent file itself. **Execute** is the one phase that writes task directories: it writes only
`0_intent.md`, `1_spec.md` and `2_plan.md` per phase, and hands the implementation to
`/monorepo-harness-build` — so the spec/plan/memory/verify loop still runs one task at a time, with
its own gates, exactly as it does for an ad-hoc task.

## Edge cases

- **No `<workspace>/.agents/intents/` yet**: run
  `core/scripts/scaffold-workspace-agents.sh` first (it seeds `intents/AGENTS.md` for every
  discovered workspace), or create the directory manually before writing the first intent.
- **Author doesn't know the workspace**: the capture step still always asks — present your
  recommendation, and if the author genuinely can't decide, note the ambiguity in "Open questions"
  and confirm the most likely target before writing. Never silently file under the most likely
  workspace without the explicit in-turn answer step 1 requires. Same convention as cross-workspace
  plan-mode tasks.
- **Reviewer wants to bulk-approve**: still ask per intent — a single "approve all" answer is fine
  as the consent for the whole batch, but each file's `## Review` section is still written
  individually with its own timestamp.
- **The intent is too big for 3-5 phases**: say so and propose a different split rather than padding
  the list or running two rounds. A follow-up intent is a valid answer when the work is genuinely two
  projects.
- **The intent is too small to be a phase list**: one phase is allowed. Do not invent extra phases to
  reach three.
- **A phase's slug already exists** as a task directory: reuse it and say which one, or propose a
  different slug — never overwrite an existing `1_spec.md` / `2_plan.md`.
- **No git remote, or a non-GitHub one, with `tracker: github`**: the script refuses and asks for
  `--repo <owner/name>`. A repository with no remote at all still gets its task directories; the
  issue is simply left to the developer.
- **The developer wants the phases built now**: that is `/monorepo-harness-build <2_plan.md>` per
  phase, in the main session. Execute does not implement.
