<!--
  TEMPLATE — root REVIEW.md for a monorepo project using the agent harness.
  Read by the `pr-review` skill (core/skills/pr-review/SKILL.md) when a review is requested via
  /monorepo-harness-review. If this file is absent, the skill falls back to the built-in defaults
  documented in that skill — copying this in is optional, but recommended once you want to tune
  thresholds or exclusions for your project.
  Resolve the placeholder before use:
    {{PROJECT_REVIEW_POLICY}} -> project-specific review rules (extra passes, stricter/looser
                                  thresholds, additional exclusions); delete the section if none.
-->

# {{PROJECT_NAME}} — Review Policy

## Passes

What every review checks, in order:

1. **Bugs / logic errors** — incorrect behavior, off-by-one, wrong control flow, unhandled edge
   cases that plausibly occur given the diff.
2. **Security / vulnerabilities** — injection, auth bypass, secrets in diffs, unsafe deserialization,
   OWASP Top 10-class issues.
3. **Spec compliance** — when the diff maps to a task under `<workspace>/.agents/artifacts/task_*/`,
   whether it satisfies that task's `2_spec.md` acceptance criteria and stays within its stated
   scope.

## Thresholds

- **Important** — anything from a pass above that is concretely wrong or risky: a real bug, a
  security issue, a violated acceptance criterion or scope boundary.
- **Nit** — everything else worth mentioning but not blocking: naming, minor style, a missed
  opportunity for simplification.
- **Nit cap**: report at most 5 nits inline; summarize the rest as a count (e.g. "+3 more nits").

## Exclusions

- Generated files (build output, lockfiles, anything under a `generated/`-style directory).
- Anything a CI-enforced linter/formatter already checks — do not re-report what CI already blocks.

<!-- {{PROJECT_REVIEW_POLICY}} — add project-specific passes, thresholds, or exclusions here, or
     delete this section if the defaults above are sufficient. -->
