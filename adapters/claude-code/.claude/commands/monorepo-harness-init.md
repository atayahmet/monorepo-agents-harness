---
description: Build or audit the nested AGENTS.md tree for one workspace (not the harness install) - survey, candidate map, approval, write, symlink, lint
argument-hint: "<workspace> [--audit]"
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agents-init/SKILL.md` exactly. The mechanics script is
`bash .agents/monorepo-agents-harness/core/scripts/agents-tree.sh` (`survey`, `candidates`, `link`,
`lint`). The canonical form is `AGENTS.md` plus `CLAUDE.md`/`GEMINI.md` symlinks to it.

1. `<workspace>`: resolve it (path, package name or alias; ask when ambiguous). Read the root
   `AGENTS.md` and `.agents/rules/*.md`, then run `agents-tree.sh survey` and summarize the
   convention and the drift.
2. Run `agents-tree.sh candidates <workspace>`, read the code of the top directories, and show the
   directory map (directory, what it covers, new or update). Write nothing until the developer
   explicitly says yes.
3. Write a short workspace-root `AGENTS.md` (scope, commands, gotchas, a routing table to every
   nested file) and the nested files (boundaries, patterns, traps, files to read first). Link rules
   from the root `AGENTS.md` and `.agents/rules/*.md`; never copy them. Update an existing
   `AGENTS.md` only through a shown diff and a yes.
4. Run `agents-tree.sh link <workspace>`, then `agents-tree.sh lint <workspace>`, and fix until the
   lint exits 0.
5. `--audit`: run `agents-tree.sh survey --workspace <workspace>` and `agents-tree.sh lint
   <workspace>`, report stale or drifting files, and write nothing.

Plain `CLAUDE.md` files found by the survey are reported as drift, never moved here.
