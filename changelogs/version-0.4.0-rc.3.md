---
version: 0.4.0-rc.3
from: 0.4.0-rc.2
date: 2026-09-25
---

# Version 0.4.0-rc.3 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.2 to 0.4.0-rc.3 (a
`/monorepo-harness-intent-execute` command that turns an approved intent into scoped phases and
tracker issues).

## Commands to run

- None. Everything new is a manifest row: the bundle sync installs the extended
  `core/skills/intent-workflow/SKILL.md`, the new `core/scripts/tracker-issue.sh` and the updated
  `core/governance/intents/AGENTS.md`, and the adapter refresh
  (`install-adapter.sh <your-adapter> --refresh`, run by the update workflow in its own step 7.5)
  places the new entry point — plus the `tracker` subagent if you are on claude-code.

## Manual follow-ups for the user

- **opencode only, and only to check:** you do **not** need to add anything to the `instructions`
  array in your root `opencode.jsonc`. The new command reaches
  `core/skills/intent-workflow/SKILL.md` by path, so that array is unchanged on purpose. Run
  `bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh` after the refresh to confirm
  Check 6 reports no missing entry.
- **Optional, GitHub users:** `/monorepo-harness-intent-execute` creates GitHub issues through the
  `gh` CLI. Nothing to install and no token to configure — it uses the authentication you already
  have. If `gh` is missing or logged out, the command still writes the per-phase task directories
  and prints paste-ready issue text for you to open by hand.
- **Optional, Linear/Jira users:** this version implements GitHub Issues only. The command says so
  plainly and does nothing silently. Linear and Jira need an MCP server or API token that **you**
  install; the harness never asks for a credential and never stores one.
- **Optional, intent authors:** an intent may now carry a `pr:` frontmatter field (a PR URL or `#n`).
  When it is present, `-intent-execute` pushes the commit carrying the approval to that PR's branch
  so the PR shows the decision. An intent without `pr:` is complete and valid — nothing to migrate.

## Release summary

- `core/skills/intent-workflow/SKILL.md` — a third phase, `## Workflow — Execute`: verify the
  approval, push the approval commit if the intent names a `pr:`, confirm the workspace scope,
  propose 3-5 phases, record an explicit sign-off, then write one task directory and one issue per
  phase. Capture and Review are unchanged.
- `core/scripts/tracker-issue.sh` — issue creation through your own authenticated tooling.
  `--dry-run` by default; `--create` prints the issue URL. Exit 3 means "not created, paste-ready
  text printed" (no `gh`); exit 1 is a guard failure. GitHub Issues only in this version.
- `core/governance/intents/AGENTS.md` — documents the optional `pr:` frontmatter field.
- One thin entry point per agent — `.claude/commands/monorepo-harness-intent-execute.md`,
  `.opencode/commands/monorepo-harness-intent-execute.md`,
  `.agents/skills/monorepo-harness-intent-execute/SKILL.md` — all named
  `/monorepo-harness-intent-execute`. Plus a claude-code `.claude/agents/tracker.md` subagent that
  creates the issues; opencode and codex run the same script inline.
- Manifest rows: three `copy` rows for the entry points and one for the subagent.
  `core/install-manifest.txt` is unchanged — the `core` directory row already covers the script.
- Docs updated to match: `PORTABILITY.md`, `adapters/AGENTS.md`, `README.md`, `INSTALL.md`, and every
  adapter `README.md` / `INSTALL.md`.
