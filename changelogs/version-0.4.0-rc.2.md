---
version: 0.4.0-rc.2
from: 0.4.0-rc.1
date: 2026-09-25
---

# Version 0.4.0-rc.2 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.1 to 0.4.0-rc.2 (a
`/monorepo-harness-update` command again, with the update prompt shipped in the bundle).

## Commands to run

- None. The prompt file arrives with the regular bundle sync (the `core` install row), and the new
  command arrives with the adapter refresh the update workflow already runs in its own step 7.5
  (`install-adapter.sh <your-adapter> --refresh`). No command needs to run.

## Manual follow-ups for the user

- None. After this update, type `/monorepo-harness-update` in the agent you installed the adapter
  for, instead of copying the update prompt out of a README. The command applies that same prompt —
  it now lives in `.agents/monorepo-agents-harness/core/prompts/harness-update.md` and is the only
  copy of it in the harness.
- Optional, only if you installed the adapter before `0.1.0-rc.4`: you may still have an old
  `/monorepo-harness:update` file in `.claude/commands/monorepo-harness/`. It is harmless and
  nothing depends on it; `audit-install.sh` reports it as an extra file. Delete it if you want.

## Release summary

- `core/prompts/harness-update.md` — the paste-in update prompt, now a bundle file and the single
  source of the procedure (versionless: the version engine is `harness-update.sh`, the file list is
  `core/install-manifest.txt`).
- `core/skills/harness-update/SKILL.md` — the workflow, unchanged. It now says the entry point
  exists again.
- One thin command per agent — `.claude/commands/monorepo-harness-update.md` (claude-code),
  `.opencode/commands/monorepo-harness-update.md` (opencode),
  `.agents/skills/monorepo-harness-update/SKILL.md` (codex) — all named `/monorepo-harness-update`.
  Each applies the prompt and defers to the skill; none of them repeats the workflow.
- Manifest rows: the three commands (`copy` per adapter) and the prompt file (`core` row plus an
  explicit row). Nothing to copy by hand.
- Docs updated to match: `PORTABILITY.md`, `README.md`, `INSTALL.md`, and every adapter
  `README.md` / `INSTALL.md`.
