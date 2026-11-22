---
description: Review the current diff against REVIEW.md policy and, when possible, this task's plan/spec/verify artifacts; --auto-fix runs a bounded local fix loop
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/pr-review/SKILL.md` exactly:

1. Resolve the arguments the user typed after the command:
   `/monorepo-harness-review [diff-range] [--auto-fix] [--fix-nits] [--max-rounds <n>]`. Accept the
   flags in any position after the command name; the non-flag argument is the diff range. Without
   `--auto-fix` the run is report-only: if `--fix-nits` or `--max-rounds` was passed, print one short
   note ("`--fix-nits`/`--max-rounds` ignored without `--auto-fix`") and continue.
2. Read `REVIEW.md` at the repo root if it exists; otherwise use the skill's built-in defaults.
3. Determine the diff to review: the diff range from step 1, or by default
   `git diff <merge-base-with-default-branch>...HEAD`.
4. Look for a matching task under `.agents/artifacts/*/index.md`; if found, use its
   `2_plan.md`/`1_spec.md`/`4_verify.md` as ground truth for a spec-compliance pass.
5. Apply the bugs/security/spec-compliance passes and report findings as Important/Nit, capped per
   policy.
6. With `--auto-fix`, run the skill's `## Review-fix loop (--auto-fix)` section instead of stopping at
   the report. Start with
   `bash .agents/monorepo-agents-harness/core/scripts/review-fix-loop.sh preflight [--max-rounds <n>]`
   and do **not** start the loop if it exits non-zero (dirty working tree or bad `--max-rounds`):
   report the reason and stop. The loop fixes Important findings (nits only with `--fix-nits`),
   reproduces and verifies every fix, reports unreproducible findings as disputed, stops and asks on
   any scope question, commits locally once per round, and stops at the round limit (default 2).

Never push, post to any PR platform, tag comments, or merge/approve anything.
Without `--auto-fix` this produces a report only; with it, the only writes are local commits on the
current branch.
