# Agent Harness for Monorepos

A portable **plan → spec → memory → verify** workflow harness that makes AI coding agents
**auditable and self-documenting**, and wires them into the rest of the software lifecycle —
intent intake, CI, and PR review — in any JavaScript/TypeScript monorepo, with **any agent**:
Claude Code, opencode, Cursor, Codex, and more.

## What you get

- **Auditable tasks** — every non-trivial task produces `1_plan.md`, `2_spec.md`, `3_memory.md`, and
  (when there's something verifiable) `4_verify.md` in a dedicated per-task directory, so you can
  always answer "why was this built this way, and how do we know it works?"
- **Per-workspace working state** — each app/package owns `.agents/{session-log,lessons,todo}.md`;
  agents read them before work and record what they learned after.
- **Enforced follow-through (Feedback Loop)** — the memory-gate blocks the task from ending until
  `3_memory.md` exists, and until `4_verify.md` exists whenever the spec's Test/verification plan
  is not `N/A` (agent stop-hook where supported, git pre-commit / CI everywhere else).
- **Deterministic install and update** — what lands in your repo is data (`core/install-manifest.txt`,
  `adapters/<agent>/manifest.txt`), executed by scripts and verified against those same manifests.
  Nothing depends on an agent correctly following a prose checklist, and an update runs the very
  same installers a fresh install does, so the two can never disagree about what "complete" means.
- **Updatable, reliably** — the bundle carries a version; a `/monorepo-harness:update` command
  compares your install against upstream and, with your consent, re-runs the new release's own
  installer and **self-heals already-installed adapters** — newly added commands/skills reach your
  project automatically, without a manual copy step and without touching your config files.
- **Agent portability** — an agent-neutral `core/` plus thin per-agent `adapters/`; switching or
  mixing agents never loses a capability (mandatory-parity rule).
- **CI integration** — `/monorepo-harness-ci` detects your project's CI provider and wires
  `memory-gate.sh` into it: a new, dedicated workflow file for GitHub Actions (after your consent),
  or a guided snippet + paste location for GitLab/Bitbucket/CircleCI, whose single-pipeline-file
  formats can't be auto-integrated as a separate file.
- **PR review** — `/monorepo-harness-review` checks a diff against `REVIEW.md` policy (or sensible
  defaults) and, when the diff maps to a tracked task, against that task's own
  `1_plan.md`/`2_spec.md`/`4_verify.md` — a ground truth generic review bots don't have. Reports
  Important/Nit findings; never posts to a PR platform or merges anything.
- **Intent capture** — `/monorepo-harness-intent` lets any stakeholder file a problem description
  before it's scoped into a task, and a product owner/manager approve or reject it explicitly. An
  approved intent optionally seeds a later task's plan as `0_intent.md`; rejected ones are kept, not
  deleted, as an audit trail.

## How it works

Every plan-mode task produces artifacts inside the workspace it targets, cataloged by a mandatory
searchable index:

```
<workspace>/.agents/artifacts/
├── index.md                          # searchable task index (entry point)
└── task_<YYYY_MM_DD>_<slug>/
    ├── 0_intent.md                   # optional — copied in if an approved intent seeded this task
    ├── 1_plan.md                     # the "how" (approved plan)
    ├── 2_spec.md                     # the "what" (contract, acceptance criteria)
    ├── 3_memory.md                   # the outcome (findings, decisions, commit SHAs)
    └── 4_verify.md                   # the proof (verification run, per-criterion pass/fail)
```

Requests that haven't been scoped into engineering work yet live one step earlier, in a separate
per-workspace inbox:

```
<workspace>/.agents/intents/
└── intent_<YYYY_MM_DD>_<slug>.md     # status: pending | approved | rejected — never deleted
```

The bundle is split into a shared core and per-agent adapters:

```
.agents/monorepo-agents-harness/
├── core/        # agent-neutral: rules, skill templates, enforcement scripts, docs governance
└── adapters/    # per-agent enforcement wiring — install the ones you use
    ├── claude-code/
    ├── opencode/
    └── codex/
```

## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).

### Scenario 1 — A non-engineer's request becomes a shipped, verified feature

A support lead notices duplicate webhook deliveries and can't write code, but can describe the
problem. They type `/monorepo-harness-intent`.

**Capture** (`core/skills/intent-workflow/SKILL.md`) writes
`apps/api/.agents/intents/intent_2026_08_20_webhook_retry.md`:

```markdown
---
status: pending
author: support-lead
date: 2026-08-20
slug: webhook_retry
---

# Intent: Order webhooks sometimes fire twice

## Problem
Downstream merchants report duplicate order.created webhook deliveries roughly 1 in 200 times,
with no way for their systems to detect or ignore the repeat.

## Proposed outcome
Merchants can safely ignore a duplicate delivery — either it stops happening, or every delivery
carries an idempotency key they can dedupe on.

## Affected users / systems
apps/api webhook dispatcher; every merchant integration consuming order.created.

## Constraints
No breaking change to the existing webhook payload shape.

## Open questions
Is the duplicate coming from a retry-on-timeout in our dispatcher, or from the queue redelivering?
```

A few days later, an engineering lead runs `/monorepo-harness-intent review`. The skill lists every
`pending` intent, shows this one's sections, and asks **"Approve this intent?"** — never inferred,
always an explicit answer in that turn. On "yes" it appends:

```markdown
## Review
- Decision: approved
- Reviewer: eng-lead
- Date: 2026-08-21
- Notes: Confirmed via logs — it's a queue redelivery, not a dispatcher retry. Scope accordingly.
```

A developer picks it up. Entering plan mode, `core/skills/agent-workflow/SKILL.md` Phase 1 runs its
two pre-plan checks: it greps `apps/api/.agents/artifacts/index.md` for prior art (finds
`webhook_signature_verification`, cites it as related), and separately checks
`apps/api/.agents/intents/` for an approved intent matching this task — finds `webhook_retry`, copies
it in as `0_intent.md`, and references it from the plan:

```markdown
---
phase: plan
date: 2026-08-21
slug: webhook_retry
status: approved
---

# Plan: Add idempotency key to order.created webhook deliveries

## Problem
See `0_intent.md` — queue redelivery causes ~1-in-200 duplicate order.created deliveries with no
way for merchants to detect a repeat.

## Approach
Stamp every delivery with a stable `X-Idempotency-Key` header derived from the order+event id, so
a merchant's existing dedupe logic (most already have one, per the intent's Open questions answer)
just works without a payload shape change.

## Related prior work
- [webhook_signature_verification](task_2026_07_02_webhook_signature_verification/2_spec.md) —
  same dispatcher code path, same header-injection point.

## Steps
1. Add `X-Idempotency-Key` header in `apps/api/src/webhooks/dispatch.ts`.
2. Derive the key deterministically from `orderId:eventType`, not a random UUID (must be stable
   across redeliveries of the *same* event).
3. Update the dispatcher's integration test fixture.

## Affected files / modules
- `apps/api/src/webhooks/dispatch.ts`
- `apps/api/test/webhooks/dispatch.test.ts`

## Risks & assumptions
- Assumes merchants dedupe on a header, not the payload body — confirmed acceptable per the intent.

## Definition of done
- [ ] Every order.created delivery carries a stable X-Idempotency-Key
- [ ] Redelivering the same event produces the same key
- [ ] No change to the existing payload body
```

`2_spec.md` follows immediately, before any `Edit`/`Write` call:

```markdown
## Acceptance criteria
- [ ] `X-Idempotency-Key` header present on every order.created delivery
- [ ] Same event redelivered → identical key
- [ ] Different event, same order → different key

## Test / verification plan
`pnpm --filter api test webhooks/dispatch` covers key derivation and header presence; manual
redelivery via the queue's local emulator confirms the key is stable across retries.
```

Implementation happens. At task end, the `verifier` subagent (Claude Code) — or the same
verification commands run inline (other adapters) — executes the plan the way it's written, and
reports pass/fail per criterion. That transcribes directly into `4_verify.md`:

```markdown
## Verification run
`pnpm --filter api test webhooks/dispatch` → 14 passed, 0 failed.
Manual: replayed the same queue message twice via the local emulator — both deliveries carried
`X-Idempotency-Key: order_9F2A:created`.

## Acceptance criteria results
- [x] X-Idempotency-Key present on every delivery — confirmed via test suite + manual replay
- [x] Same event redelivered → identical key — confirmed via manual replay
- [x] Different event, same order → different key — confirmed via test suite (`created` vs `updated`)

## Deviations
None.
```

`3_memory.md` records what future readers actually need — not a restatement of the diff:

```markdown
## What was done (single paragraph)
Added a deterministic X-Idempotency-Key header to order.created webhook deliveries so merchants
can dedupe on redelivery, closing out the support-lead-reported duplicate-delivery intent.

## Surprising findings
The duplicates were 100% queue redelivery, not dispatcher retry-on-timeout as originally suspected
in the intent's Open questions — the dispatcher has no retry logic at all.

## If I did it again
Would check the queue's redelivery semantics first, before writing the plan — would have skipped
one wrong hypothesis.

## Related decisions
Chose a deterministic key over a random UUID specifically so redeliveries of the *same* event
produce the *same* key — a random key would defeat the entire point.
```

The memory-gate now finds both `3_memory.md` and `4_verify.md` (the spec's plan isn't `N/A`) and lets
the task close. The same commit adds an index row:

```
| 08-21 | E | [webhook_retry](task_2026_08_21_webhook_retry/2_spec.md) ◆ | Idempotency key on order.created delivery |
```

**Full chain, one glance:** stakeholder problem → explicit human approval → plan grounded in that
approval → contract with acceptance criteria → real verification evidence → durable memory → a
permanently searchable, auditable trail. Nothing in this chain required the stakeholder to know
what `apps/api/src/webhooks/dispatch.ts` is.

### Scenario 2 — An ad-hoc bugfix reuses prior art automatically

Not every task starts from an intent — most don't. A developer notices a flaky test and just starts
fixing it, no `/monorepo-harness-intent` involved. Entering plan mode still runs the **mandatory**
prior-art search (unlike the intent match, which is best-effort and silent when nothing matches):

```markdown
## Related prior work
- [webhook_retry](task_2026_08_21_webhook_retry/2_spec.md) — touches the same dispatch.ts test
  fixture; this fix adjusts the fixture's timing assumption introduced there.
```

No `0_intent.md` — the intent-match step checked `apps/api/.agents/intents/`, found nothing
plausible, and silently skipped it, exactly as documented (`core/skills/agent-workflow/SKILL.md`
edge cases: "no matching approved intent... nothing warns about this"). The rest of the chain
(spec → implementation → memory → verify) runs the same as Scenario 1. This is the common case: the
intent inbox is an *optional entry point*, not a gate every task must pass through.

### Scenario 3 — Wiring CI enforcement, whichever provider you actually use

The team wants the memory-gate enforced in CI, not just locally. Someone runs `/monorepo-harness-ci`.

`core/scripts/detect-ci-provider.sh --provider` inspects the repo and returns `github-actions`
(found `.github/workflows/`). Because GitHub Actions supports independent workflow files, this path
is **fully automatic**: the skill checks `harness-memory-gate.yml` doesn't already exist, shows the
exact file it's about to write, and asks **"Add this CI workflow file?"** — only on an explicit yes
does it write:

```yaml
name: harness-memory-gate
on: [pull_request, push]
jobs:
  memory-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run agent-workflow memory-gate
        run: bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

If the same repo used **GitLab** instead, the detector would return `gitlab`, and the skill would
switch to *guided-only*: GitLab reads a single `.gitlab-ci.yml`, so a separate file would never run
automatically. The skill shows the job snippet and tells the user exactly where to paste it — it
never calls `Write` or `Edit` on that file itself. Same tiering for Bitbucket Pipelines and
CircleCI. This isn't a missing feature; it's a deliberate boundary, because guessing at how to merge
into someone's single pipeline file is worse than not touching it.

### Scenario 4 — PR review catches scope creep against the task's own spec

A reviewer runs `/monorepo-harness-review` on the `webhook_retry` branch before merging. The skill
loads `REVIEW.md` (or built-in defaults if absent), diffs against the merge-base, and — because the
touched files fall under `apps/api` — greps `apps/api/.agents/artifacts/index.md` and finds the
`webhook_retry` task. It reads that task's own `1_plan.md` and `2_spec.md` as ground truth, not just
generic code-quality heuristics:

```
Diff reviewed: origin/main...webhook_retry (apps/api)
Task found: webhook_retry (2026-08-21) — spec-compliance pass enabled
Policy: REVIEW.md

Important:
- apps/api/src/webhooks/dispatch.ts:142 — this diff also refactors the retry backoff timer,
  which is outside 1_plan.md's "Affected files / modules" (dispatch.ts's header logic only) and
  outside 2_spec.md's acceptance criteria. Likely scope creep — split into its own task or confirm
  intentionally in scope.

Nit:
- apps/api/src/webhooks/dispatch.ts:98 — magic string "order.created" could reuse the existing
  EVENT_TYPES constant already imported two lines up.

Security: no issues found.
```

A generic review bot would see a diff and check style/security. This one additionally knows *what
the diff promised to do* — because it read the plan and spec the harness already produced — and
flags the unrelated backoff-timer change as scope creep instead of quietly approving it. It never
posts this to the PR platform or merges anything; it's a report for the human reviewer.

### Scenario 5 — Updating the harness itself, reliably

Months later, upstream ships a new release. Someone runs `/monorepo-harness:update`
(`core/skills/harness-update/SKILL.md`). It checks the installed version against upstream, reports
what changed, and asks **"Upgrade now?"**. On consent:

- The bundle is synced by **the new release's own installer** —
  `install-harness.sh --sync-only`, driven by `core/install-manifest.txt`, the very same code path a
  fresh install uses. No hand-maintained per-release file list (which is what used to let a new
  skill or command silently never reach an installed project) and no hand-copying by the agent.
  Every row is verified; an incomplete sync is reported, not silently accepted.
- Because this project already has the `claude-code` adapter installed, the update runs
  **`install-adapter.sh claude-code --refresh`** against the fresh bundle — any new harness-plumbing
  command added upstream since the last update (say, a future `/monorepo-harness-<something>`) shows
  up in `.claude/commands/` without anyone copying it by hand. `--refresh` deliberately skips the
  config rows, so your `.claude/settings.json` is never rewritten or double-appended.
- Root `AGENTS.md` is reconciled against the new `core/root-AGENTS.md` template via a three-way
  merge, shown as a diff, and written only after a separate explicit approval.
- `.agents/` working state — every intent, every task's plan/spec/memory/verify — is never touched.

The team's own task history, built up across Scenarios 1–4, survives every upgrade untouched;
only the harness's own machinery gets newer.

## Quickstart

Two commands, from your monorepo root. Both are idempotent, and neither ever deletes anything.

```bash
# 1. core (agent-neutral — identical for everyone)
git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-install
bash .agents/.harness-install/core/scripts/install-harness.sh

# 2. your agent's adapter — run once per agent you use
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code   # or codex, opencode

# 3. confirm nothing was missed
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
```

Step 1 installs the bundle, writes your root `AGENTS.md` (or leaves an existing one alone and tells
you to run the merge skill), scaffolds per-workspace `.agents/` state, and wires the universal hard
gate as `.git/hooks/pre-commit`. Step 2 installs your agent's hooks, commands and skills without
ever overwriting a config file you already have. Both print a short `Needs you:` list covering the
only decisions a script can't make.

There is no prose checklist to follow: what gets installed is data —
[`core/install-manifest.txt`](core/install-manifest.txt) and
[`adapters/<agent>/manifest.txt`](adapters/claude-code/manifest.txt) — and those same manifests are
what `audit-install.sh` verifies against, so a partial install cannot pass as a complete one.

Details, flags and the three human follow-ups: **[INSTALL.md](INSTALL.md)** ·
per-agent notes: [claude-code](adapters/claude-code/INSTALL.md) ·
[opencode](adapters/opencode/INSTALL.md) · [codex](adapters/codex/INSTALL.md) ·
another agent: [PORTABILITY.md](PORTABILITY.md).

Then, as needed: `/monorepo-harness-ci` to wire CI (Scenario 3), `/monorepo-harness-intent` to open
the intent inbox (Scenario 1), `/monorepo-harness-review` before merging a PR (Scenario 4).

### Or hand it to your agent

Paste this into Claude Code, opencode, Codex CLI — any agent — from your monorepo root:

```text
Install the monorepo-agents-harness into this repository.

1. Clone it and run its own installer — do NOT copy any files by hand, and do not
   follow install prose step by step. The scripts are the install:

     git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness \
       .agents/.harness-install
     bash .agents/.harness-install/core/scripts/install-harness.sh

2. Then install the adapter for the agent you are:

     bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <claude-code|codex|opencode>

3. Then verify and show me the result:

     bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh

Rules while you do this:
- Never overwrite a config file I already have. If a script writes a
  <file>.harness-proposed, leave the original alone and show me the diff.
- If I already have a root AGENTS.md, do not touch it. Report that the merge skill
  (core/skills/agents-md-merge/SKILL.md) needs to run, and ask me before running it.
- If any script exits non-zero, stop and show me its output verbatim. Do not improvise
  a fix or hand-copy the missing files.
- Report the "Needs you:" list from both scripts, and the audit result, before doing
  anything else. Do not commit without asking me.
```

The prompt names no version on purpose — it always installs the current one. Whatever it installs
can update itself later with `/monorepo-harness:update` (claude-code) or `/monorepo-harness-update`
(opencode, Codex CLI).

## Adapters

| Adapter       | Enforcement provided                                                                                                                                                               |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude-code` | `PostToolUse[ExitPlanMode]` hook (plan reminder), `/monorepo-harness-build` manual plan/spec trigger, `Stop` hook memory-gate (**hard block**), skill auto-registration, `/monorepo-harness:update` command, `/monorepo-harness-ci` CI integration, `/monorepo-harness-review` PR review, `/monorepo-harness-intent` intent capture, `verifier` subagent  |
| `opencode`    | Universal git/CI gate (hard), `/monorepo-harness-update` command, `/monorepo-harness-build` manual plan/spec trigger, `/monorepo-harness-ci` CI integration, `/monorepo-harness-review` PR review, `/monorepo-harness-intent` intent capture                                                        |
| `codex`       | `PostToolUse[update_plan]` hook (plan reminder), `Stop` hook memory reminder (soft) + universal git/CI gate (hard), skill auto-registration, `/monorepo-harness-update`, `/monorepo-harness-build`, `/monorepo-harness-ci`, `/monorepo-harness-review`, and `/monorepo-harness-intent` skills |
| yours         | Follow the capability matrix in [PORTABILITY.md](PORTABILITY.md) — new adapters are the intended growth path                                                                       |

## Documentation map

| File                                                                       | What it covers                                                                             |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [INSTALL.md](INSTALL.md)                                                   | Install: the two script commands, the human-only follow-ups, verification                   |
| [core/install-manifest.txt](core/install-manifest.txt)                     | The whitelist of what an install puts in `.agents/monorepo-agents-harness/`                 |
| [adapters/claude-code/manifest.txt](adapters/claude-code/manifest.txt)     | Per-adapter install rules (one per agent) — executed by `install-adapter.sh`, audited by `audit-install.sh` |
| [PORTABILITY.md](PORTABILITY.md)                                           | Cross-agent capability matrix; how to author a new adapter                                 |
| [core/root-AGENTS.md](core/root-AGENTS.md)                                 | Template root instructions — the single source of truth copied into target repos as `AGENTS.md` |
| [core/skills/agent-workflow/SKILL.md](core/skills/agent-workflow/SKILL.md) | Plan/spec/memory/verify file templates (Scenarios 1–2)                                     |
| [core/skills/agents-md-merge/SKILL.md](core/skills/agents-md-merge/SKILL.md) | Reconciles a project's root `AGENTS.md` with the harness template on install/upgrade       |
| [core/skills/harness-update/SKILL.md](core/skills/harness-update/SKILL.md) | Update-check / upgrade workflow — re-runs the installers, self-heals adapters (Scenario 5) |
| [core/skills/monorepo/SKILL.md](core/skills/monorepo/SKILL.md)             | Monorepo guidance (framework-agnostic + Turborepo/Nx/Lerna/workspaces)                     |
| [core/skills/ci-integration/SKILL.md](core/skills/ci-integration/SKILL.md) | Detects the target project's CI provider and wires `memory-gate.sh` into it (Scenario 3)   |
| [core/skills/pr-review/SKILL.md](core/skills/pr-review/SKILL.md)           | Reviews a diff against `REVIEW.md` policy and a task's plan/spec/verify artifacts (Scenario 4) |
| [core/root-REVIEW.md](core/root-REVIEW.md) | Optional installable review-policy template — copied into target repos as `REVIEW.md` |
| [core/skills/intent-workflow/SKILL.md](core/skills/intent-workflow/SKILL.md) | Captures stakeholder intents and lets a product owner approve/reject them (Scenario 1)     |
| [core/governance/intents/AGENTS.md](core/governance/intents/AGENTS.md) | Intent file format and status-lifecycle rules for every `<workspace>/.agents/intents/` |
| [core/governance/artifacts/AGENTS.md](core/governance/artifacts/AGENTS.md) | Task-index format & searchability rules for every `<workspace>/.agents/artifacts/index.md` |
| [changelogs/README.md](changelogs/README.md)                              | Format of the per-release upgrade prompts the update workflow reads                        |

## Requirements

- A **JavaScript/TypeScript monorepo** (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) with an `apps/*` layout (optionally `packages/*` or `libs/*`)
- `git`; `jq` only if your adapter needs it (claude-code and codex do)
