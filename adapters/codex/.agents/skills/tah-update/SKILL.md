---
name: tah-update
description: Compare the installed agent-harness version against upstream and, with consent, upgrade it. Use when the user types /tah-update or asks to check/update the harness.
---

Follow the shared instructions in
`turborepo-harness-template/core/skills/harness-update/SKILL.md` exactly:

1. Run `bash turborepo-harness-template/core/scripts/harness-update.sh check --json`.
2. Report the result (and CHANGELOG highlights when outdated).
3. Ask for explicit consent before any upgrade; on consent run
   `harness-update.sh upgrade --source <new-bundle-dir>` and finish the printed follow-ups.

Never upgrade without consent.
