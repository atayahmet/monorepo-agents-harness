# Changelog Prompts

A release ships a prompt here — `version-X.Y.Z.md` — **only if** it needs something the manifests
cannot express: a command to run, or a manual follow-up for the user. Most releases need neither, and
this directory is legitimately empty apart from this file.

These prompts are consumed by the active agent (Claude Code, opencode, Codex, Cursor, …). The agent
reads the markdown, interprets the instructions, and performs the operations.
`core/scripts/harness-update.sh` does **not** parse these files; it only resolves the installed and
latest versions and verifies a copy (`verify-copy`).

## Prompts never move files

Adding a file to the bundle or to an adapter needs **no prompt entry at all** — add a manifest row
instead:

- `core/install-manifest.txt` — what belongs in `.agents/monorepo-agents-harness/`.
- `adapters/<agent>/manifest.txt` — what an adapter installs into the project.

`core/skills/harness-update/SKILL.md` step 7 runs the new release's own
`core/scripts/install-harness.sh --sync-only` against the first manifest, and step 7.5 runs
`core/scripts/install-adapter.sh <agent> --refresh` against the second. Both are the same scripts a
fresh install runs, so an update and an install cannot disagree about what a complete installation
contains.

This is deliberate: a hand-maintained per-release "files to copy" list is structurally prone to
omission — one forgotten line and a new skill or command silently never reaches installed projects.
Never list a bundle or adapter path in a prompt "just to be safe"; that reintroduces exactly the
list this rule exists to eliminate.

Two more things the prompts must **not** carry, because the workflow already does them:

- **Root `AGENTS.md` reconciliation** — step 9 performs a consent-gated merge via
  `core/skills/agents-md-merge/SKILL.md`. Never write "compare/merge your `AGENTS.md` against the
  fresh template" as a manual follow-up.
- **Adapter entry points** — step 7.5 re-applies every installed adapter's `copy`/`link` rows. Never
  write "copy the new slash command into place" as a manual follow-up.

## File naming

```
changelogs/version-X.Y.Z.md
```

where `X.Y.Z` is the SemVer version being released (prereleases included, e.g.
`version-0.1.0-rc.1.md`).

## Prompt structure

Use these standard sections so the agent can interpret the prompt reliably:

```markdown
---
version: 0.2.0
from: 0.1.0
date: 2026-09-14
---

# Version 0.2.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0 to 0.2.0.

## Commands to run

```bash
bash core/scripts/scaffold-workspace-agents.sh
```

## Manual follow-ups for the user

- Re-apply the opencode config merge (`opencode.jsonc`) — its hook definitions changed this release.

## Release summary

- Short human-readable summary of the release changes.
```

### Section reference

| Section | Purpose |
|---|---|
| `Commands to run` | Execute each command block from the installed bundle root. Stop on first failure. |
| `Manual follow-ups for the user` | Present these to the user at the end; never execute automatically. |
| `Release summary` | Human-readable summary used when reporting the upgrade. |
| `Files to copy from the new bundle to the installed bundle` (rare, opt-in — omit unless needed) | Only for a path covered by **neither** manifest. Directories ending in `/` are copied recursively. |
| `Files to delete from the installed bundle` (rare, opt-in — omit unless needed) | Same scope restriction. If `(only if they exist)` is present, silently skip missing targets. |

## The installed `changelogs/` directory

`changelogs/` is not a `core/install-manifest.txt` row, so an installed bundle never has one. The
agent always reads prompts from a temporary clone of the upstream bundle. Never list a prompt's own
`changelogs/version-X.Y.Z.md` under "Files to copy".

## How the agent selects prompts

When upgrading from version `A` to version `B`, the agent reads every prompt where:

```
A < prompt.version <= B
```

Prompts are processed in SemVer order, prereleases ranking below their release (`0.2.0-rc.1` <
`0.2.0`). A version in that range with **no** prompt file is normal — it simply needed no commands
or follow-ups.
