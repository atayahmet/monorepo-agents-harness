---
name: monorepo-harness-intent
description: Capture a new intent, or review pending intents and approve/reject them. Use when the user types /monorepo-harness-intent, describes a new feature/problem without being in an active coding task, or asks to review pending intents.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/intent-workflow/SKILL.md` exactly:

1. When capturing: ask the author to confirm the target workspace (present your recommendation)
   and agree a `slug`. Then query the knowledge base — run
   `bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<1-3 keywords>"` over the
   repo-root `knowledge/` (BM25-ranked; grep fallback without `sqlite3`/FTS5) — and keep the top pages
   for the intent's `## Prior art` section (`- KB: [[<page>]] (knowledge/…)`, or
   `- KB: no relevant pages` when there are none). Then ask whether to create an `intent/<slug>`
   branch (offer the name) and — if a branch is created — ask separately whether to commit the
   `status: pending` intent file to it. Only then write
   `<workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md` including that `## Prior art` section.
2. If the user asks to review: query the knowledge base per pending intent with its own keywords, list
   every `status: pending` intent with the hits it returned, present each, and ask "Approve
   this intent?" (yes/no/edit) — never change `status` without an explicit answer in the current
   turn. Approved/rejected intents are never deleted.

This skill only captures and reviews intents — it does not create task directories, plans, or specs.
