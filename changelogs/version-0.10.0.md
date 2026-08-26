---
version: 0.10.0
from: 0.9.0
date: 2026-08-26
---

# Version 0.10.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.9.0 to 0.10.0.

## Files to copy from the new bundle to the installed bundle

- `core/VERSION` -> `core/VERSION`
- `core/skills/agent-workflow/SKILL.md` -> `core/skills/agent-workflow/SKILL.md`
- `core/skills/intent-workflow/` -> `core/skills/intent-workflow/` (recursive directory copy)
- `core/governance/` -> `core/governance/` (recursive directory copy)
- `core/scripts/scaffold-workspace-agents.sh` -> `core/scripts/scaffold-workspace-agents.sh`

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

```bash
bash core/scripts/scaffold-workspace-agents.sh
```

This seeds `<workspace>/.agents/intents/AGENTS.md` for every existing workspace (idempotent — never
overwrites files already present).

## Manual follow-ups for the user

- Copy the new `/monorepo-harness-intent` entry point for whichever adapter(s) you use:
  - Claude Code: copy `adapters/claude-code/.claude/commands/monorepo-harness-intent.md` into
    `.claude/commands/`.
  - opencode: copy `adapters/opencode/.opencode/commands/monorepo-harness-intent.md` into
    `.opencode/commands/`.
  - Codex: copy `adapters/codex/.agents/skills/monorepo-harness-intent/` into `.agents/skills/`
    (recursive).
- Entirely opt-in: no existing task, plan, or spec is affected until someone files and gets an
  intent approved.

## Release summary

- New `/monorepo-harness-intent` capability: any stakeholder can file a problem description as an
  intent before it's scoped into engineering work; a product owner/manager reviews pending intents
  and explicitly approves or rejects each one (never deleted, either way). An approved intent
  optionally seeds a later task's `1_plan.md` as `0_intent.md` via `agent-workflow` SKILL.md's
  Phase 1 — a best-effort, non-mandatory match.
