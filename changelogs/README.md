# Changelog Prompts

Each release that needs commands run, manual follow-ups, or a release summary ships a
human-readable upgrade prompt under this directory: `version-X.Y.Z.md`.

These prompts are consumed by the active agent (Claude Code, opencode, Codex,
Cursor, etc.). The agent reads the markdown, interprets the instructions, and
performs the upgrade operations. `core/scripts/harness-update.sh` does **not**
parse these files; it only resolves the installed and latest versions (and, since
0.11.0, verifies the bundle sync — see `verify-copy` below).

**Since 0.11.0, prompts no longer drive file copying.** `core/` and `adapters/` are synced
wholesale from the fresh clone every update (`core/skills/harness-update/SKILL.md` step 7) —
nothing is enumerated, so nothing can be silently left out of a release's list. Prompts now exist
only for `Commands to run`, `Manual follow-ups for the user`, and `Release summary`.

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
version: 0.11.0
from: 0.10.0
date: 2026-08-26
---

# Version 0.11.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.10.0 to 0.11.0.

## Commands to run

```bash
bash core/scripts/scaffold-workspace-agents.sh
```

## Manual follow-ups for the user

- Re-apply the opencode config merge (`opencode.jsonc`) if it was changed upstream.

## Release summary

- Short human-readable summary of the release changes.
```

### Section reference

| Section | Purpose |
|---|---|
| `Commands to run` | Execute each command block from the installed bundle root. Stop on first failure. |
| `Manual follow-ups for the user` | Present these to the user at the end; do not execute automatically. |
| `Release summary` | Human-readable summary used when reporting the upgrade. |
| `Files to copy from the new bundle to the installed bundle` (rare, opt-in — omit unless needed) | Only for paths **outside** `core/` and `adapters/`, which are always synced wholesale (see the 0.11.0+ note below). Directories ending in `/` are copied recursively. |
| `Files to delete from the installed bundle` (rare, opt-in — omit unless needed) | Same scope restriction as above. If `(only if they exist)` is present, silently skip missing targets. |

### `core/` and `adapters/` sync wholesale, not by itemized list (0.11.0+)

Before 0.11.0, every release's "Files to copy" list had to enumerate each new/changed file under
`core/` — a hand-maintained list that could (and did) silently omit files, leaving installed
projects with a stale or incomplete bundle. From 0.11.0 on, `core/skills/harness-update/SKILL.md`
step 7 replaces `core/` and `adapters/` wholesale from the fresh clone every time, then verifies
the result with `harness-update.sh verify-copy`. **Do not** list `core/...` or `adapters/...`
paths under "Files to copy"/"Files to delete" in prompts released from 0.11.0 onward — reserve
those sections for the rare path that lives outside both trees. (Prompts released before 0.11.0
still list `core/...` paths; historical artifact, harmless since the wholesale sync already
covers them — left as-is.) Adapter entry-point files (new slash commands/skills) are also no
longer a manual follow-up: `core/skills/harness-update/SKILL.md` step 7.5 re-applies each
installed adapter's own `INSTALL.md` copy steps automatically.

### Installed `changelogs/` is ephemeral (0.4.4+)

Every install and update ends by deleting the installed
`.agents/monorepo-agents-harness/changelogs/` directory entirely (see
`INSTALL.md` §4 step 1 and `core/skills/harness-update/SKILL.md` step 9). The
agent always reads prompts from a temporary clone of the upstream bundle, never
from the installed copy, so nothing is lost. **Do not** list a prompt's own
`changelogs/version-X.Y.Z.md` under "Files to copy from the new bundle to the
installed bundle" going forward — it would just be deleted moments later by
the final cleanup step. (Prompts released before 0.4.4 still list their own
self-copy line; that is a historical artifact, left as-is.)

### Root `AGENTS.md` reconciliation is automatic (0.5.0+)

`core/skills/harness-update/SKILL.md` step 9 now reconciles the project's root
`AGENTS.md` against the fresh `core/root-AGENTS.md` itself — a consent-gated
merge via `core/skills/agents-md-merge/SKILL.md` — instead of leaving it to
the user. **Do not** list "compare/merge your `AGENTS.md` against the fresh
`core/root-AGENTS.md` template" as a manual follow-up in prompts released from
0.5.0 onward; the update workflow performs it. (Prompts released before 0.5.0
still carry that follow-up; historical artifact, left as-is.)

## How the agent selects prompts

When upgrading from version `A` to version `B`, the agent reads every prompt
where:

```
A < prompt.version <= B
```

Prompts are processed in SemVer order.
