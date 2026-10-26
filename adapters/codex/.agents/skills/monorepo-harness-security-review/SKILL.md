---
name: monorepo-harness-security-review
description: Run a deep security review of the current diff using the security-review skill. Use when the user types /monorepo-harness-security-review or asks for a security audit of changes.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/security-review/SKILL.md` exactly:

1. Read `REVIEW.md` at the repo root if it exists; otherwise use the skill's built-in defaults.
2. Determine the diff to review (default: `git diff <merge-base-with-default-branch>...HEAD`).
3. Look for a matching task under `.agents/artifacts/*/index.md`; if found, use its
   `1_spec.md`/`2_plan.md`/`4_verify.md` and note any access-gate expectations.
4. Run a deeper security audit (authn/authz, injection, secrets, unsafe deserialization, webhooks/dependencies, OWASP Top 10-class issues) and report findings as Important/Nit.
5. Produce a report only — never post to any PR platform, tag comments, or merge/approve anything.
