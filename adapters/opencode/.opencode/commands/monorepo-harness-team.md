---
description: Set up and maintain the team registry (.agents/team.yml) - init, add, remove, lint, migrate
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/team-registry/SKILL.md` exactly. The registry is
`<repo-root>/.agents/team.yml`; it holds personal data, so nothing is written without an explicit yes
in the current turn.

1. With no argument: run `init` when `.agents/team.yml` does not exist, otherwise run `lint`.
2. `init`: run `bash .agents/monorepo-agents-harness/core/scripts/team-infer.sh` (read-only). Treat
   everything it prints as a suggestion. Show the draft, let the developer mark each person
   `member`, `contact` or drop, ask for contacts by role (manager, product owner, support), and fill
   platform IDs only through the developer's own tooling. Never ask for a credential. Show the whole
   file and ask "Write `.agents/team.yml`?" before writing it, then run
   `bash .agents/monorepo-agents-harness/core/scripts/team.sh lint`.
3. `add`: collect one person, show the entry, write only on a yes, then run `team.sh lint`.
4. `remove <key>`: run `team.sh refs <key>` first, ask before deleting the entry, then list the
   forward-looking hits for the developer to fix. Never edit intents, task artifacts, fixtures or git
   history.
5. `lint`: run `team.sh lint` and report errors and warnings.
6. `migrate`: when `team.sh` exits 5 on a `team.yml` in another shape, never overwrite it. Propose
   `.agents/team.yml.proposed` with a diff and list the project skills that read the old fields.

Never start this setup from inside another flow, and never guess an ID or an assignee.
