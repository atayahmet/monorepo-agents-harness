# Local AGENTS.md upkeep in workspace directories

## **Add or update AGENTS.md wherever the current directory's context needs documenting**

When working in **any directory inside a workspace** — the workspace root itself (`apps/<name>/`,
`packages/<name>/`) or any nested subdirectory at any depth (e.g. `apps/<name>/src/components/**`,
`packages/<name>/lib/**`) — if that directory's current state needs instructions for agents —
non-obvious conventions, build or run quirks, module boundaries, gotchas, or anything an agent
would otherwise have to rediscover — you MUST create an `AGENTS.md` file in that directory, or
update the one that already exists.

- Create `AGENTS.md` when the directory has no agent instructions yet and there is something an
  agent must know before editing it.
- Update it whenever a documented rule, convention, or context changes — new build steps, renamed
  scripts, added constraints, removed behavior.
- Keep each file scoped to its directory. Do not duplicate rules that already live in the root
  `AGENTS.md` or in `.agents/rules/*.md`; reference them instead.
- A directory that fully follows the root guidelines needs no `AGENTS.md` — do not add empty
  placeholder files.
- Never leave stale instructions behind: when a documented behavior stops holding, fix the file in
  the same change that alters the behavior.

---

Seeded by the monorepo-agents-harness installer from
`.agents/monorepo-agents-harness/core/project-rules-template/` and registered in
`.agents/.harness-map.json`; edit or delete this file if your project does not need the rule.