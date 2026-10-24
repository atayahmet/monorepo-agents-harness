## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).



### Scenario 1 — A non-engineer's request becomes a shipped, verified feature

A support lead notices duplicate webhook deliveries and can't write code, but can describe the
problem. They type `/monorepo-harness-intent`.

**Capture** (`core/skills/intent-workflow/SKILL.md`) first queries the repo-root knowledge base
(`kb-index.sh query` over `knowledge/`) and records the result, then writes
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

## Prior art
- KB: no relevant pages
```

A few days later, an engineering lead runs `/monorepo-harness-intent review`. The skill lists every
`pending` intent, queries the knowledge base with each intent's own keywords, shows this one's sections
plus the ranked hits, and asks **"Approve this intent?"** — never inferred,
always an explicit answer in that turn. On "yes" it appends:

```markdown
## Review
- Decision: approved
- Reviewer: eng-lead
- Date: 2026-08-21
- Notes: Confirmed via logs — it's a queue redelivery, not a dispatcher retry. Scope accordingly.
```

A developer picks it up. Entering plan mode, `core/skills/agent-workflow/SKILL.md` Phase 1 runs its
pre-plan checks: it queries the repo-root knowledge base first (`kb-index.sh query` over
`knowledge/`, reads the top pages), then greps `apps/api/.agents/artifacts/index.md` for prior art
(finds `webhook_signature_verification`, cites it as related — kept ready for the plan's `## Related
prior work`), and separately checks `apps/api/.agents/intents/` for an approved intent matching this
task — finds `webhook_retry`, links it in as `0_intent.md` (a reference stub, not a copy). Then, matching the playbook's
`intent → spec → plan` order, it writes the **spec first** — the "what" (`1_spec.md`):

```markdown
## Acceptance criteria
- [ ] `X-Idempotency-Key` header present on every order.created delivery
- [ ] Same event redelivered → identical key
- [ ] Different event, same order → different key

## Test / verification plan
Tier: red-first
`pnpm --filter api test webhooks/dispatch` covers key derivation and header presence; manual
redelivery via the queue's local emulator confirms the key is stable across retries.
```

Then `2_plan.md` — the "how" — is written against that spec, before any `Edit`/`Write` call:

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
- [[webhook-dispatch]] (`knowledge/modules/api.md`) — how the dispatcher injects headers today.
- [webhook_signature_verification](task_2026_07_02_webhook_signature_verification/1_spec.md) —
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

The key-derivation choice is architecture-affecting — it changes a contract every merchant
integration consumes — so Phase 1 fires the `adr-workflow` skill and writes the decision next to the
spec, recording the rejected alternative that later engineers would otherwise have to re-derive:

```markdown
---
phase: adr
date: 2026-08-21
slug: webhook_retry
adr: 0001
status: accepted
---

# ADR 0001 — Deterministic X-Idempotency-Key derivation

## Context
Queue redelivery produces duplicate order.created deliveries (see `0_intent.md`). Merchants need a
stable way to detect a repeat without a payload-shape change.

## Decision
Derive `X-Idempotency-Key` from `orderId:eventType`, deterministically, rather than from a random UUID.

## Alternatives considered
- Random UUID per delivery — rejected: every delivery would look unique, defeating the purpose.
- ULID carrying an order-instance id — rejected: over-engineered for the current redelivery scope.

## Consequences
Easier: merchants dedupe on a simple stable header; replaying the same event reproduces the same key.
Harder: key space is tied to `orderId:eventType` — a future redelivery-with-modification must revisit this.
```

The spec's `## Architectural decisions` section links `adr/0001-deterministic-idempotency-key.md`,
and `/monorepo-harness-review` (Scenario 4) verifies the record exists before merge.

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

Once the build has started, the memory-gate finds both `3_memory.md` and `4_verify.md` (the spec's
plan isn't `N/A`) and lets the task close. The same commit adds an index row:

```
| 08-21 | E | [webhook_retry](task_2026_08_21_webhook_retry/1_spec.md) ◆ | Idempotency key on order.created delivery |
```

When the build finishes, `/monorepo-harness-build` points the developer at `/monorepo-harness-review`
without forcing it: `core/scripts/build-review-tier.sh` reads the task's changed-file count and the
spec's architectural signals, and a **simple** change (≤3 files, no signal) gets a one-line suggestion
while a **comprehensive** one gets a direct question to run the review now. The step is advisory — it
never blocks the task from closing.

**Full chain, one glance:** stakeholder problem → explicit human approval → plan grounded in that
approval → contract with acceptance criteria → real verification evidence → durable memory → a
permanently searchable, auditable trail. Nothing in this chain required the stakeholder to know
what `apps/api/src/webhooks/dispatch.ts` is.

