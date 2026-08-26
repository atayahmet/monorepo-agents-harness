---
description: Capture a new intent, or review pending intents and approve/reject them
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/intent-workflow/SKILL.md` exactly:

1. If the user is describing a new problem/feature: resolve the target workspace, write
   `<workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md` with `status: pending`.
2. If the user asks to review: list every `status: pending` intent, present each, and ask "Approve
   this intent?" (yes/no/edit) — never change `status` without an explicit answer in the current
   turn. Approved/rejected intents are never deleted.

This skill only captures and reviews intents — it does not create task directories, plans, or specs.
