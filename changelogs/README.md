# Changelog Prompts

Each release that requires more than a verbatim file copy ships a human-readable
upgrade prompt under this directory: `version-X.Y.Z.md`.

These prompts are consumed by the active agent (Claude Code, opencode, Codex,
Cursor, etc.). The agent reads the markdown, interprets the instructions, and
performs the upgrade operations. `core/scripts/harness-update.sh` does **not**
parse these files; it only resolves the installed and latest versions.

## File naming

```
changelogs/version-X.Y.Z.md
```

where `X.Y.Z` is the SemVer version being released.

## Prompt structure

Every `version-X.Y.Z.md` should use the following standard sections so the agent
can interpret it reliably:

```markdown
---
version: 0.2.0
from: 0.1.0
date: 2026-08-24
---

# Version 0.2.0 Upgrade Instructions

You are upgrading the turborepo-agent-harness from 0.1.0 to 0.2.0.

## Files to copy from the new bundle to the installed bundle

- `core/VERSION` -> `core/VERSION`
- `core/scripts/` -> `core/scripts/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

- `.claude/commands/turborepo-harness/update-check.md`

## Commands to run

```bash
bash core/scripts/scaffold-workspace-agents.sh
```

## Manual follow-ups for the user

- Merge any new rows from the fresh `AGENTS.md` template into the repo-root `AGENTS.md`.

## Release summary

- Short human-readable summary of the release changes.
```

### Section reference

| Section | Purpose |
|---|---|
| `Files to copy from the new bundle to the installed bundle` | Copy listed files/directories from the downloaded bundle to the installed bundle. Directories ending in `/` are copied recursively. |
| `Files to delete from the installed bundle` | Remove listed files/directories. If `(only if they exist)` is present, silently skip missing targets. |
| `Commands to run` | Execute each command block from the installed bundle root. Stop on first failure. |
| `Manual follow-ups for the user` | Present these to the user at the end; do not execute automatically. |
| `Release summary` | Human-readable summary used when reporting the upgrade. |

## How the agent selects prompts

When upgrading from version `A` to version `B`, the agent reads every prompt
where:

```
A < prompt.version <= B
```

Prompts are processed in SemVer order.
