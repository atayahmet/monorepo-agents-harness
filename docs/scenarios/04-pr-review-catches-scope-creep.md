## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).



### Scenario 4 — PR review catches scope creep against the task's own spec

A reviewer runs `/monorepo-harness-review` on the `webhook_retry` branch before merging. The skill
loads `REVIEW.md` (or built-in defaults if absent), diffs against the merge-base, and — because the
touched files fall under `apps/api` — greps `apps/api/.agents/artifacts/index.md` and finds the
`webhook_retry` task. It reads that task's own `2_plan.md` and `1_spec.md` as ground truth, not just
generic code-quality heuristics:

```
Diff reviewed: origin/main...webhook_retry (apps/api)
Task found: webhook_retry (2026-08-21) — spec-compliance pass enabled
Policy: REVIEW.md

Important:
- apps/api/src/webhooks/dispatch.ts:142 — this diff also refactors the retry backoff timer,
  which is outside 2_plan.md's "Affected files / modules" (dispatch.ts's header logic only) and
  outside 1_spec.md's acceptance criteria. Likely scope creep — split into its own task or confirm
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

