---
name: monorepo-self-improve
description: Review recent lessons and task memories to propose new project-owned rules and skills. Use when the user types /monorepo-self-improve.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/self-improvement-workflow/SKILL.md` exactly.

1. Collect `<workspace>/.agents/lessons.md`, `<workspace>/.agents/artifacts/index.md`, recent
   `3_memory.md` files from every workspace, and `.agents/.harness-map.json`.
2. Detect recurring patterns and score confidence.
3. Propose `.agents/rules/<topic>.md`, `.agents/skills/<new-skill>/SKILL.md`, agents, commands, and
   root `AGENTS.md` Reference Map updates. Mark each proposal `new` or `update` based on the map.
4. Stop and present the proposal report before writing anything.
5. Ask "Apply these changes?" and wait for an explicit answer in the current turn.
6. On yes: write consumer-owned files, run `core/scripts/update-harness-map.sh` for every component,
   and reconcile root `AGENTS.md` via `core/skills/agents-md-merge/SKILL.md`.
7. On no / deferred / partly applied: offer to save the report as
   `.agents/self-improve-proposals/<YYYY_MM_DD>-<slug>.md` with a `Status:` line, so the finding is
   not lost. Never write it unasked.

Do **not** modify `.agents/monorepo-agents-harness/` or any harness bundle files.
