---
description: Capture a new intent, review pending intents and approve/reject them, or reject an intent from its PR link
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
3. If the user passes `--reject <PR-url> [<PR-url> ...]`: follow the skill's "Workflow — Reject" —
   record `status: rejected` plus a `## Review` section on each PR's own branch and merge via
   `task-state.sh merge-intent-pr <intent.md> --pr <ref> --reject --yes` (the merge is a separate
   consent question; a PR approval is never read or required).

This skill captures, reviews, and rejects intents — it does not create task directories, plans, or specs.
