---
version: 0.2.0-rc.0
from: 0.1.0-rc.9
date: 2026-09-02
---

# Version 0.2.0-rc.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.9 to 0.2.0-rc.0 (adds the
`/monorepo-self-improve` self-improvement workflow).

## Commands to run

Re-apply every installed adapter so the new command/skill files reach your project. The
harness-update workflow's step 7.5 does this already; running it here directly is harmless and
idempotent (`--refresh` skips config rows). Run it once per installed adapter (`claude-code`,
`opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

For `claude-code` and `codex` this copies the new `/monorepo-self-improve` entry point and symlinks
the new `self-improvement-workflow` skill. For `opencode` it copies the new command but does **not**
touch your existing `opencode.jsonc` — see the manual follow-up below.

## Manual follow-ups for the user

- **opencode: add the self-improvement skill to your config.** Add
  `.agents/monorepo-agents-harness/core/skills/self-improvement-workflow/SKILL.md` to the
  `instructions` array in your root `opencode.jsonc`, or merge the proposed
  `opencode.jsonc.harness-proposed`. Until you do, the `/monorepo-self-improve` command still works
  (it points directly at the skill), but opencode will not auto-load the skill for pattern-related
  prompts — a soft loss, not a hard block.

## Release summary

- New `/monorepo-self-improve` self-improvement workflow:
  `core/skills/self-improvement-workflow/SKILL.md` reads lessons, task memories, and the workspace
  index to detect recurring patterns, then proposes durable project-owned rules
  (`.agents/rules/*.md`) and project-specific skills (`.agents/skills/<new-skill>/SKILL.md`). All
  writes require explicit user approval and never modify the installed harness bundle.
- The workflow is wired for all three adapters: claude-code command + skill symlink, opencode
  command + `instructions` entry, codex skill + symlink.
