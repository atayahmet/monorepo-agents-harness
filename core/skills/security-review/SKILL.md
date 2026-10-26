---
name: security-review
description: Deep security audit of the task's diff against task artifacts and OWASP Top 10-class issues. Use when asked for a security review, or run via /monorepo-harness-security-review after a build. Produces a report only — no PR posts, no merges. Writes in simple English.
---

# Security Review

Does a deeper security audit than the general `pr-review` pass. It focuses on auth/ownership, injection, secrets, unsafe deserialization, dependency/webhook risks, and OWASP Top 10-class issues. This skill produces a report only. It does not post to any PR platform, tag comments, or merge/approve anything.

**Recommended at the end of a build.** `/monorepo-harness-build` may point to this alongside `/monorepo-harness-review`. The run is opt-in. See `core/skills/agent-workflow/SKILL.md`, "After the build".

**Write in simple English.** Every file and developer message this skill produces follows `../../governance/rules/simple-english.md` — short sentences, common words, active voice.

## Workflow

1. **Load the review policy.** Read `REVIEW.md` at the repo root if it exists. If absent, use these built-in defaults:
   - Passes: bugs/logic errors, security/vulnerabilities, spec compliance (if a task is found).
   - Thresholds: Important = concretely wrong or risky; Nit = everything else worth mentioning.
   - Exclusions: generated files, anything a CI-enforced linter/formatter already checks.

2. **Determine the diff.** Default to `git diff <merge-base-with-default-branch>...HEAD`. If the user names a specific range, branch, or already-open PR, use that instead — this skill only needs a diff, not a specific hosting platform.

3. **Find the originating task, if any.** For each file touched by the diff, check whether it falls under a workspace with `.agents/artifacts/index.md`; grep that index for a task whose summary or linked `1_spec.md` plausibly covers these files. On a match, read that task's `1_spec.md`, `2_plan.md`, the ADRs its spec's `## Architectural decisions` section links, and `4_verify.md` (if present). Pay close attention to access-gate expectations in `1_spec.md` (auth/ownership gates). If no match, skip that pass context and say so explicitly in the report — do not guess at intent.

4. **Apply the security passes** to the diff:
   - **Authn/authz** — auth checks on new routes/endpoints, ownership/tenant checks, privilege escalation, missing gates on sensitive actions. Compare against the task's `1_spec.md` access-gate expectations when a task is found.
   - **Injection** — SQL/NoSQL/OS/LDAP/command/template injection, unsafe string concatenation in queries/exec.
   - **Secrets and config** — secrets/tokens/keys in code/config diffs, logging of sensitive data, weak defaults.
   - **Unsafe deserialization/serialization** — unsafe deserialization, untrusted object parsing, unsafe eval/reflective code paths.
   - **Webhooks/inputs** — webhook signature verification, SSRF, open redirects, file upload validation, untrusted input handling.
   - **Dependency risk** — new dependencies or version changes (note if lockfile changed), known risky patterns.
   - **OWASP Top 10-class issues** — common classes (broken access control, cryptographic failures, injection, insecure design, etc.) as they appear in the diff.

5. **Report**, in this order:
   - One line of context: diff range reviewed, task found (or "no matching task — no task access-gate context"), policy source (`REVIEW.md` or built-in defaults).
   - **Important** findings, each with file:line and a one-sentence concrete failure scenario plus a short fix suggestion.
   - **Nit** findings, small hardenings worth noting.
   - If nothing was found in a category, say so ("Authz: no issues found") rather than omitting it.

## Out of scope

- A live PR-bot service that posts comments automatically.
- Tagging or replying to individual PR comments.
- Automatic merging, approving, or requesting changes on any PR.
- Broad repo-wide penetration testing outside the diff/task scope.

## Edge cases

- **No task found**: still audit the diff; note that access-gate expectations from the task spec were not available.
- **Large diff**: prioritize authz/injection/secrets/webhook paths first; note in the report if scope was too large to review in full and what was prioritized.
- **Empty diff**: report that there is nothing to review — do not fabricate findings.
