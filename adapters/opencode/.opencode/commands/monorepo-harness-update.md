---
description: Check the installed harness version against upstream and, with consent, upgrade it
---

Read `.agents/monorepo-agents-harness/core/prompts/harness-update.md` and apply that prompt exactly
as written, then follow `.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md` end to
end: the prompt holds the rules, the skill holds the workflow.

Never upgrade without consent, and never skip either of the two approvals the prompt names (before
the bundle sync, and before writing the root `AGENTS.md`). Never copy a file by hand and never
shorten the workflow — the installers driven by the manifests are the only way to move a file.
