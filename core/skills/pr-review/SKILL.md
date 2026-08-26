---
name: pr-review
description: Review the current diff against this project's REVIEW.md policy (or built-in defaults) and, when the diff maps to a known task, against that task's 1_plan.md/2_spec.md/4_verify.md. Reports findings tagged Important/Nit. Use when the user types /monorepo-harness-review or asks to review a PR, diff, or set of changes.
---

# PR Review

Reviews a diff the way a careful human reviewer would, but with an advantage generic review bots
don't have: when the diff belongs to a task tracked by the `agent-workflow` skill, this skill reads
that task's own `1_plan.md`/`2_spec.md`/`4_verify.md` and checks the diff against **what it actually
committed to build**, not just generic code-quality heuristics.

This skill produces a report. It does not run as a service, does not post to any PR platform, and
does not merge or approve anything — see "Out of scope" below.

## Workflow

1. **Load the review policy.** Read `REVIEW.md` at the repo root if it exists. If absent, use these
   built-in defaults:
   - Passes: bugs/logic errors, security/vulnerabilities, spec compliance (if a task is found).
   - Thresholds: Important = concretely wrong or risky; Nit = everything else worth mentioning.
   - Nit cap: 5 inline, rest summarized as a count.
   - Exclusions: generated files, anything a CI-enforced linter/formatter already checks.

2. **Determine the diff.** Default to `git diff <merge-base-with-default-branch>...HEAD`. If the
   user names a specific range, branch, or already-open PR, use that instead — this skill only
   needs a diff, not a specific hosting platform.

3. **Find the originating task, if any.** For each file touched by the diff, check whether it falls
   under a workspace with `.agents/artifacts/index.md`; grep that index for a task whose summary or
   linked `2_spec.md` plausibly covers these files. On a match, read that task's `1_plan.md`,
   `2_spec.md`, and `4_verify.md` (if present) as ground truth for the Spec compliance pass. If no
   match, skip that pass and say so explicitly in the report — do not guess at intent.

4. **Apply the passes** from the loaded policy to the diff:
   - **Bugs / logic errors** — read the actual changed code, not just the diff hunks in isolation;
     trace obviously-affected call sites.
   - **Security / vulnerabilities** — injection, auth bypass, secrets committed in the diff, unsafe
     deserialization, other OWASP Top 10-class issues.
   - **Spec compliance** (only if a task was found in step 3) — does the diff satisfy `2_spec.md`'s
     acceptance criteria, and does it stay within the plan's stated scope (`## Affected files /
     modules`)? Flag scope creep as Important, not Nit.

5. **Report**, in this order:
   - One line of context: diff range reviewed, task found (or "no matching task — spec-compliance
     pass skipped"), policy source (`REVIEW.md` or built-in defaults).
   - **Important** findings, each with file:line and a one-sentence concrete failure scenario.
   - **Nit** findings, capped per policy; if more exist, state the count.
   - If nothing was found in a pass, say so ("Security: no issues found") rather than omitting it —
     an omitted pass reads as "not checked," not "checked and clean."

## Out of scope

Deliberately not built into this skill (agent-agnostic by design — these are platform- or
product-specific and the harness does not commit to any one of them):

- A live PR-bot service that posts comments automatically (that's Claude Code's own Code Review
  product, or `claude-code-action`, or an equivalent for other platforms).
- Tagging or replying to individual PR comments (`@claude`-style) — this requires a specific
  platform's comment API.
- Automatic merging, approving, or requesting changes on any PR.

## Edge cases

- **No `REVIEW.md`**: use the built-in defaults; mention this in the report's context line.
- **No matching task found**: skip the spec-compliance pass explicitly; still run bugs/security.
- **Empty diff**: report that there is nothing to review — do not fabricate findings.
- **Very large diff**: prioritize the passes over exhaustive line-by-line coverage; note in the
  report if scope was too large to review in full and what was prioritized.
