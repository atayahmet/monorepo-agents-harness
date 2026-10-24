## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).



### Scenario 2 — An ad-hoc bugfix reuses prior art automatically

Not every task starts from an intent — most don't. A developer notices a flaky test and just starts
fixing it, no `/monorepo-harness-intent` involved. Entering plan mode still runs the **mandatory**
knowledge-base query and prior-art search (unlike the intent match, which is best-effort and silent
when nothing matches):

```markdown
## Related prior work
- [webhook_retry](task_2026_08_21_webhook_retry/1_spec.md) — touches the same dispatch.ts test
  fixture; this fix adjusts the fixture's timing assumption introduced there.
```

No `0_intent.md` — the intent-match step checked `apps/api/.agents/intents/`, found nothing
plausible, and silently skipped it, exactly as documented (`core/skills/agent-workflow/SKILL.md`
edge cases: "no matching approved intent... nothing warns about this"). The rest of the chain
(spec → implementation → memory → verify) runs the same as Scenario 1. This is the common case: the
intent inbox is an *optional entry point*, not a gate every task must pass through.

