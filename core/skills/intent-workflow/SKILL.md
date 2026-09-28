---
name: intent-workflow
description: Capture a stakeholder's problem description as an intent file before it becomes a plan-mode task, let a product owner or manager review pending intents and approve or reject them, and dispatch an approved intent into scoped phases with one tracker issue per phase, writing no spec, plan or task directory of its own. Use when the user types /monorepo-harness-intent or /monorepo-harness-intent-dispatch, describes a new feature/problem without being in an active coding task, asks to review pending intents, or asks to turn an approved intent into work.
---

# Intent Capture, Review, and Dispatch

Captures a request **before** it has been scoped into a plan-mode task, gates it behind an explicit
human approval, and — once approved — turns it into phased, tracked work. This is the harness's entry
point for non-engineering stakeholders — a product owner, manager, or any team member can describe a
problem without knowing which workspace or files it touches; `core/skills/agent-workflow/SKILL.md`
picks up the result later, one phase at a time.

Full format and lifecycle rules: `core/governance/intents/AGENTS.md`.

**Write in simple English.** Every file and developer message this skill produces follows
`../../governance/rules/simple-english.md` — short sentences, common words, active voice. This matters
most in **Dispatch**, whose issue titles and bodies are read by people outside the engineering pair.

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

## Workflow — Dispatch

Triggered by `/monorepo-harness-intent-dispatch <intent.md>`, when an **approved** intent needs to
become real work. It records the approval and opens the tasks; it **never implements them** and it
**writes no spec, plan or task directory** — those belong to `/monorepo-harness-spec` and
`/monorepo-harness-plan`, one task at a time. A task here **is** a tracker issue.

**Dispatch writes exactly two files, and only when each is justified: the existing intent file's
status and `## Review` section (step 1) and the confirmed tracker cache (step 6). Nothing else — no
`task_<date>_<slug>/`, no `0_intent.md`, no `1_spec.md`, no `2_plan.md`, no `index.md` row, and never
a new intent file.** Each phase's scope, workspace and verification command live in its issue body,
which is where a phase is tracked from now on. (ADR
`0001-dispatch_creates_issues_not_plan_artifacts.md` — this reverses the 2026-09-25 task's ADR 0001,
whose "one task directory per phase" premise no longer holds.)

1. **Confirm the approval, PR first.** The human decision lives on the intent's PR; the local file is
   the record of it. Read the intent's optional `pr:` field, then run:
   - `pr:` names a GitHub PR →
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md> --pr <ref>`
   - no `pr:`, or it is not a GitHub PR (a non-GitHub tracker has no review state to read) → the same
     command without `--pr`.
   The script names the source it accepted. If it exits non-zero, report the reason and **stop** — do
   not write a file, do not ask about workspaces, do not create an issue. A `pending` intent has not
   been agreed to yet.
   - **Accepted from a PR** (`source: PR …`) while the file still says `pending` → set `status:
     approved` and append the `## Review` section, taking **Reviewer** and **Date** from the script's
     output. Never invent either.
   - **Already `approved` in the file** → change nothing. The section is already there.
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
   `snake_case` slug (3-5 words, `[a-z0-9_]`), unique across the **whole intent**, so two issues never
   describe the same work.
5. **Get the sign-off.** Show the phase table — number, title, workspace, verification — and ask
   **"Start these N phases?"** (yes / edit / fewer). A "fewer" answer means re-split and ask again.
   No issue exists before an explicit yes in the current turn.
6. **Find the tracker, then confirm it with the developer.** The tracker belongs to **this
   consumer project**, never to the harness. In this order:
   a. **If `<repo-root>/.agents/tracker.md` already records a platform, use it.** Do not ask
      again. The developer can still change it on purpose, with `--tracker <platform>`.
   b. **Otherwise infer it, read-only:**
      `bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh --infer` prints
      `platform= target= source= origin=` and exits 0. It reads **this project's** `origin` remote
      only — `github.com` → github, `bitbucket.org` → bitbucket, `gitlab.com` → gitlab, anything
      else → `unknown`. The harness's own repo, `.harness-map.json` and `VERSION` are never a
      source. Show the developer the inferred platform **and** its target.
   c. **Ask, in one question, with three answers:** the inferred one (recommended), **a different
      platform**, or an explicit `--tracker <platform>`. Something like "This project tracks work
      in `<platform>` — is that right, or do you file it somewhere else?" **Never create an issue
      on an unconfirmed guess, and never write the cache before the developer answers in the current
      turn.** A different answer always wins over the inferred one.
   d. **On an answer, write `<repo-root>/.agents/tracker.md`** — frontmatter `tracker:`,
      `target:` (a GitHub `owner/name`, a Jira project key, a Linear team key) and `confirmed:`
      (today's date), plus a line of prose saying the harness reads it and that editing it by hand
      is fine. It is the consumer's own file: not `.harness-map.json`, not a bundle file.
   **If the confirmed platform is not `github`, `jira` or `linear`, ask the developer how their team
   files work in it and what its target is** (a project key, a board, a URL shape, a CLI they
   already run), and record that answer. The harness does not guess at a platform it does not know
   and never falls back to some other repository. For `jira` and `linear` — recognized, but needing
   an MCP server, project skill, or CLI that **the developer** installs — hand off to that tooling;
   if none is available the script prints paste-ready text and the phase records "no issue yet". The
   harness never asks for a credential and never stores one. Only **github** (GitHub Issues through
   the `gh` CLI) is implemented in this version.
7. **Open the issue. Write no file.** For each approved phase, compose the issue title and body from
   the phase row — scope, workspace, verification command, and a link to the intent file — then run
   `core/scripts/tracker-issue.sh --title "<issue title>" --body-file <file> --create` and report the
   returned URL. Open **all** phases' issues before reporting back, not one phase per turn.
   **The body is the phase record now.** Do not create `task_<YYYY_MM_DD>_<phase_slug>/`, do not write
   `0_intent.md`, `1_spec.md` or `2_plan.md`, and do not add a row to `artifacts/index.md`: those are
   `/monorepo-harness-spec` and `/monorepo-harness-plan`'s to write, one task at a time, and an
   `index.md` row indexes a task directory that does not exist here. Delete the throwaway body file
   you passed to `--body-file`.
8. **Hand off and stop.** Report each phase's issue URL and the command that starts the work:
   `/monorepo-harness-spec <intent.md>` — it refuses an unapproved intent, links the intent as
   `0_intent.md`, and writes `1_spec.md`; then `/monorepo-harness-plan` and `/monorepo-harness-build`,
   one phase at a time. There is no `<2_plan.md>` to hand over, because dispatch never writes one. A
   phase's scope is re-derived from its issue plus the intent, so read the issue before scoping it.

**`tracker-issue.sh` exit codes** — 0 created (or dry-run printed), 1 guard failure, 2 usage error,
**3 not created** (`gh` missing or unauthenticated; a confirmed platform the harness recognizes but
does not implement, such as `jira` or `linear`; the paste-ready title and body were printed). On 3,
tell the user how to open the phase by hand or with their own tooling, note it in your report, and
continue with the remaining phases. On 1, report and stop. Never report an issue that does not exist.

**Hard never's for this phase:** no source-file edits, no `task_<date>_<slug>/` directory, no
`0_intent.md` / `1_spec.md` / `2_plan.md` / `3_memory.md` / `4_verify.md`, no `artifacts/index.md`
row, no new or renamed intent file, no implementation of any phase, no issue without an explicit yes,
no token or credential read or write, no push to a branch the user did not name, no re-splitting of an
approved phase list behind the user's back, and — **the harness repo (`monorepo-agents-harness`) is
never an issue target and is never offered as a choice.** It is a template, not a consumer project's
task tracker. `tracker-issue.sh` refuses it as a target on every path; do not offer it in the question
either, however prominent it is in the harness docs or the session history.

## Connection to `agent-workflow`

An approved intent is optional input to plan-mode work, not a requirement — see
`core/governance/intents/AGENTS.md`'s "Relationship to the plan/spec/memory/verify workflow" and
`core/skills/agent-workflow/SKILL.md` Phase 1. **Capture** and **Review** create nothing beyond the
intent file itself, and **Dispatch** adds only the intent's status/`## Review` section and the
tracker cache. Every task artifact — `0_intent.md`, `1_spec.md`, `2_plan.md`, the `index.md` row —
belongs to `/monorepo-harness-spec` and `/monorepo-harness-plan`, which run one task at a time with
their own gates, exactly as they do for an ad-hoc task. Dispatch is the step that decides how many
tasks there are and files each one as an issue; it is not a faster route through the chain. (ADR
`0001-dispatch_creates_issues_not_plan_artifacts.md`.)

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
- **The intent's PR was approved but the local file still says `pending`**: normal, and the reason
  step 1 checks the PR first. Take the reviewer and date from the script's output rather than asking
  again, and report which source the approval came from.
- **The PR carries `CHANGES_REQUESTED` or only comments**: that is not an approval. The script
  refuses it; say what the PR actually says and stop. Never treat a comment or a dismissed review as
  consent.
- **`gh` is missing or the intent's `pr:` is not a GitHub PR**: the script warns on stderr and falls
  back to the file, so the command still works — the approval then has to be in the file.
- **A phase's slug matches an existing task directory**: not a collision any more, since dispatch
  creates no directory. If `/monorepo-harness-spec` later refuses for that reason, propose a
  different slug; never overwrite an existing `1_spec.md` / `2_plan.md`.
- **A task directory already exists for this intent** from an earlier `0.4.0-rc.4` run: leave it.
  Those files are valid work; this version simply stops producing new ones. Say so rather than
  deleting them.
- **No git remote, or a non-GitHub one**: `--infer` reports `platform=unknown` (or `bitbucket` /
  `gitlab`) and step 6 asks the developer where this project's work is tracked. On a non-GitHub
  origin with `tracker: github` the script still needs `--repo <owner/name>`; a repository with no
  remote at all still gets its task directories, and the issue is simply left to the developer.
- **The developer names a tracker the harness does not implement**: ask how they work in it (step
  6d), record the answer, and let their own MCP server, project skill, or CLI create the issue — or
  print the paste-ready text and record "no issue yet". Never substitute a GitHub repository they
  did not ask for.
- **The developer wants the phases built now**: that is `/monorepo-harness-build <2_plan.md>` per
  phase, in the main session. Dispatch does not implement.
