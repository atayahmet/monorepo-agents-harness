---
name: intent-workflow
description: Capture a stakeholder's problem description as an intent file before it becomes a plan-mode task, let a product owner or manager review pending intents and approve or reject them, and dispatch an approved intent into scoped phases with one tracker issue per phase - asking first whether the work is already open and whether the intent's PR should be merged - writing no spec, plan or task directory of its own. Use when the user types /monorepo-harness-intent or /monorepo-harness-intent-dispatch, describes a new feature/problem without being in an active coding task, asks to review pending intents, or asks to turn an approved intent into work.
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
a new intent file. The two consent steps in between (7 and 8) write nothing either.** Each phase's
scope, workspace and verification command live in its issue body, which is where a phase is tracked
from now on. (ADR
`0001-dispatch_creates_issues_not_plan_artifacts.md` — this reverses the 2026-09-25 task's ADR 0001,
whose "one task directory per phase" premise no longer holds. The duplicate check and the merge
question are in ADR `0002-dispatch_gates_open_work_and_consents_pr_merge.md`.)

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
7. **Check whether the work is already open, then ask.** Read-only, and **before the first issue
   exists** — a duplicate is cheap to prevent here and expensive to notice a week later:
   `bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh --list-open --search <word> [--search <word>] --tracker <platform>`
   Pick **1-2 distinctive words** from the intent's *proposed outcome* and the phase titles — nouns a
   search will actually match, not a sentence. It prints `open-match count=<n>`, then one
   `#<number>\t<title>\t<url>` row per open item.
   - **count=0** → nothing to ask. Go to step 8.
   - **count>0** → show **every** row and ask **"This work may already be open — create these phases
     anyway?"** (create anyway / stop / re-split). Nothing is created without an explicit yes in the
     current turn. "stop" and "re-split" both end the dispatch here: leave the intent approved, file
     no issues, and say what is already open so the developer can merge the phase list into it.
   - **exit 3** (`gh` missing or unauthenticated, or a platform the harness recognizes but does not
     implement) → the check could **not** be performed. Say so in those words — "I could not check
     whether this is already open" — name the reason, and continue. The check is advisory, and issue
     creation on that same path fails immediately anyway. Record it in the final report, so a skip is
     never silent.
   - **exit 1** (guard failure — e.g. the harness repo itself as the target) → report and stop.
   - **exit 2** (usage error, e.g. no `--search`) → that is a bug in the call, not a board state.
     Fix the call and retry once; if it still fails, report it and continue.
   This step **writes nothing**: no comment, no label, no assignment, no close, no edit on what it
   finds. It reads the board so the same work is not filed twice. (ADR
   `0002-dispatch_gates_open_work_and_consents_pr_merge.md`.)
8. **Open the issue. Write no file.** For each approved phase, compose the issue title and body from
   the phase row — scope, workspace, verification command, and a link to the intent file — then run
   `core/scripts/tracker-issue.sh --title "<issue title>" --body-file <file> --create` and report the
   returned URL. Open **all** phases' issues before reporting back, not one phase per turn.
   **The body is the phase record now.** Do not create `task_<YYYY_MM_DD>_<phase_slug>/`, do not write
   `0_intent.md`, `1_spec.md` or `2_plan.md`, and do not add a row to `artifacts/index.md`: those are
   `/monorepo-harness-spec` and `/monorepo-harness-plan`'s to write, one task at a time, and an
   `index.md` row indexes a task directory that does not exist here. Delete the throwaway body file
   you passed to `--body-file`.
9. **Ask whether to merge the intent PR — and merge only on a yes.** The intent's PR is where the
   approval is visible to other people, and leaving it open forever is the one piece of unfinished
   business this command creates. So it is the **last** step, and it is a question:
   - **No `pr:` field on the intent** → skip this step silently; there is nothing to merge.
   - Otherwise first show what *would* happen, read-only and with nothing merged:
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr <intent.md> [--pr <ref>]`
     It prints the ref, the title, who approved it and when, and the merge state. Then ask
     **"Merge the intent PR (#N) now?"** (yes / no / later).
   - On **yes**, re-run the same command **with `--yes`**. That flag is the developer's in-turn answer
     and the script refuses to merge without it. On **no** or **later**, skip it and name the PR URL in
     the report so it is not forgotten.
   - The script re-checks the approval itself and will not be talked out of it: a PR with no
     approving review — or one whose reviewer asked for changes *after* approving — is never merged.
     It merges with a merge commit and nothing else: **no `--admin`** (bypassing branch protection is
     the developer's decision, not the harness's), **no `--delete-branch`** (never asked for), no
     squash, rebase or auto. A repository that forbids merge commits makes it exit 1 with the PR
     still open — report that and stop, do not try another method.
   - An **already-merged** PR is a no-op whatever its reviews say: the script reads the PR's state
     before the gate, prints "already merged" and exits 0. A re-run therefore never fails on a PR that
     is already done, which is what makes the step safe to repeat.
   - **exit 3** (`gh` missing or unauthenticated) → nothing was merged. Give the developer the PR URL
     and say they can merge it themselves.
   Merging last is deliberate: if a phase fails to file, or the duplicate check stopped the run, the
   approval is still sitting on an open PR where a human can pick it up — rather than merged as work
   that was never dispatched.
10. **Hand off and stop.** Report each phase's issue URL, whether the open-work check could be run,
    and what happened to the intent PR (merged, left open with its URL, or no `pr:` field), then the
    command that starts the work:
    `/monorepo-harness-spec <intent.md>` — it refuses an unapproved intent, links the intent as
    `0_intent.md`, and writes `1_spec.md`; then `/monorepo-harness-plan` and `/monorepo-harness-build`,
    one phase at a time. There is no `<2_plan.md>` to hand over, because dispatch never writes one. A
    phase's scope is re-derived from its issue plus the intent, so read the issue before scoping it.

**`tracker-issue.sh` exit codes** — 0 done (tracker inferred, open work listed, dry-run printed, or
the issue created), 1 guard failure, 2 usage error, **3 not done** (`gh` missing or unauthenticated; a
confirmed platform the harness recognizes but does not implement, such as `jira` or `linear`). On 3
from step 8, tell the user how to open the phase by hand or with their own tooling, note it in your
report, and continue with the remaining phases; on 3 from step 7, say the duplicate check could not
run. On 1, report and stop. Never report an issue that does not exist, and never report a merge that
did not happen.

**`merge-intent-pr` exit codes** — 0 the PR is merged, or already was, or (without `--yes`) nothing
was merged and the summary was printed; 1 refused, with the reason (no approving review, not open,
conflicts, or the repository refused the merge — the PR is still open in every one of those cases); 3
`gh` missing or unauthenticated, nothing merged.

**Hard never's for this phase:** no source-file edits, no `task_<date>_<slug>/` directory, no
`0_intent.md` / `1_spec.md` / `2_plan.md` / `3_memory.md` / `4_verify.md`, no `artifacts/index.md`
row, no new or renamed intent file, no implementation of any phase, no issue without an explicit yes,
**no automatic duplicate matching** (show the candidates, let the developer decide — never skip, merge
or silently retitle a phase because an issue looks similar), **no comment, label, assignment, close or
edit on any issue the open-work check finds**, **no PR merge without an explicit yes in this turn**,
**no `--admin`**, no branch deletion, no token or credential read or write, no push to a branch the
user did not name, no re-splitting of an approved phase list behind the user's back, and — **the
harness repo (`monorepo-agents-harness`) is never an issue target and is never offered as a choice.**
It is a template, not a consumer project's task tracker. `tracker-issue.sh` refuses it as a target on
every path, `--list-open` included; do not offer it in the question either, however prominent it is in
the harness docs or the session history.

## Connection to `agent-workflow`

An approved intent is optional input to plan-mode work, not a requirement — see
`core/governance/intents/AGENTS.md`'s "Relationship to the plan/spec/memory/verify workflow" and
`core/skills/agent-workflow/SKILL.md` Phase 1. **Capture** and **Review** create nothing beyond the
intent file itself, and **Dispatch** adds only the intent's status/`## Review` section and the
tracker cache. Every task artifact — `0_intent.md`, `1_spec.md`, `2_plan.md`, the `index.md` row —
belongs to `/monorepo-harness-spec` and `/monorepo-harness-plan`, which run one task at a time with
their own gates, exactly as they do for an ad-hoc task. Dispatch is the step that decides how many
tasks there are and files each one as an issue; it is not a faster route through the chain. (ADR
`0001-dispatch_creates_issues_not_plan_artifacts.md`.) It also asks two questions the rest of the chain
never has to: **is this work already open on the tracker** (step 7) and **should the intent's PR be
merged now** (step 9). Each one ends in a write to a shared system that cannot be undone by re-reading
the conversation, which is why each is a question first and a script second. (ADR
`0002-dispatch_gates_open_work_and_consents_pr_merge.md`.)

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
- **The open-work check finds something that looks like the same work**: show it and let the
  developer decide — usually the answer is one phase merged into an existing issue, which you cannot
  do (dispatch never edits an issue it did not create). Offer the honest options: stop and let them
  do it, re-split, or create the phase anyway. Never decide that two titles are "the same work".
- **The search finds nothing but you expected it to**: the keyword was too generic. Try once more
  with a word from the proposed outcome, then move on. Do not keep searching until something turns
  up — a check that hunts for a match will find one.
- **The intent's PR was already merged**: report it and skip the merge question. The script exits 0
  for that case, so re-running dispatch on a merged intent is harmless.
- **The developer answers "later" to the merge**: the PR stays open and the report names its URL. That
  is a complete outcome, not a pending step — do not offer to merge it again later in the same run.
- **The intent has no `pr:` field**: step 9 does not exist. Do not invent a PR to merge and do not
  offer to open one.
