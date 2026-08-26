---
description: Review the current diff against REVIEW.md policy and, when possible, this task's plan/spec/verify artifacts
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/pr-review/SKILL.md` exactly:

1. Read `REVIEW.md` at the repo root if it exists; otherwise use the skill's built-in defaults.
2. Determine the diff to review (default: `git diff <merge-base-with-default-branch>...HEAD`).
3. Look for a matching task under `.agents/artifacts/*/index.md`; if found, use its
   `1_plan.md`/`2_spec.md`/`4_verify.md` as ground truth for a spec-compliance pass.
4. Apply the bugs/security/spec-compliance passes and report findings as Important/Nit, capped per
   policy.

Never post to any PR platform, tag comments, or merge/approve anything — this produces a report only.
