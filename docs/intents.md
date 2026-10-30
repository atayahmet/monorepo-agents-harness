# Intents

Intents capture stakeholder requests before they're scoped into engineering work. The full workflow — capture, review/approval, rejection, dispatch, and PR handling — is documented in the intent workflow skill.

`/monorepo-harness-intent --pr [--draft] <description>` carries a capture through to an open pull request: it creates `intent/<slug>` from the default branch, commits only the intent file, pushes with `git push -u`, opens the PR on your forge through `core/scripts/forge.sh create`, and records `pr: <url>` in a second commit. Then run `/monorepo-harness-intent --approve <url>`.

- [Intent workflow skill](../core/skills/intent-workflow/SKILL.md)
- [Intent governance](../core/governance/intents/AGENTS.md)
