---
version: 0.3.0-rc.0
from: 0.2.0-rc.7
date: 2026-09-22
---

# Version 0.3.0-rc.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.7 to 0.3.0-rc.0 (new
`/monorepo-harness-changeset` capability).

## Commands to run

Re-apply every adapter you have installed so the new `/monorepo-harness-changeset` entry point
reaches it (repeat per adapter; adapters not installed can be skipped):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code --refresh
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh opencode --refresh
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh codex --refresh
```

Then confirm nothing was missed:

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
```

## Manual follow-ups for the user

- **opencode only:** add
  `.agents/monorepo-agents-harness/core/skills/changeset-workflow/SKILL.md` to the `instructions`
  array of your root `opencode.jsonc`, or merge the `opencode.jsonc.harness-proposed` the installer
  left beside it. `audit-install.sh` reports this entry until you do.
- Nothing else — the `core` manifest row already ships the new script + skill, and no `AGENTS.md`
  reconciliation is needed (this release does not touch `core/root-AGENTS.md`).

## Release summary

- `/monorepo-harness-changeset` drafts changesets-compatible `.changeset/*.md` entries from a
  finished task's spec/plan/memory, without adding `@changesets/cli` as a dependency.
- `core/scripts/draft-changeset.sh` generates deterministically named files with a revision-based
  duplicate guard and user-supplied package/bump pairs; `core/skills/changeset-workflow/SKILL.md`
  drives the proposal-then-confirm loop and the one-plan → many-changesets flow (the
  `v…-alpha.0`/`alpha.1` sequencing stays with the project's own `changeset pre` + `version`).
- Ships on all three adapters; docs (`PORTABILITY.md`, READMEs, `INSTALL.md`) updated; version bumped
  to `0.3.0-rc.0`.