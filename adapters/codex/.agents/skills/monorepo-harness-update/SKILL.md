---
name: monorepo-harness-update
description: Compare the installed agent-harness version against upstream and, with consent, upgrade it. Use when the user types /monorepo-harness-update or asks to check/update the harness.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md` exactly:

1. Run `bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check --json`.
2. Report the result (and CHANGELOG highlights when outdated).
3. Ask for explicit consent before any upgrade; on consent clone the new bundle and apply the
   upgrade by following the `changelogs/version-X.Y.Z.md` prompts in the downloaded bundle.
4. Finish the manual follow-ups the prompts list.

Never upgrade without consent.
