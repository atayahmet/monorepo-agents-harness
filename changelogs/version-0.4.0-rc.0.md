---
version: 0.4.0-rc.0
from: 0.3.0-rc.1
date: 2026-09-23
---

# Version 0.4.0-rc.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.3.0-rc.1 to 0.4.0-rc.0 (a repo-root knowledge
base — Karpathy "LLM Wiki" pattern — compiled incrementally at task end from each task's
`3_memory.md` / `4_verify.md` / `adr/`).

## Commands to run

Seed the knowledge-base skeleton into your project's root `knowledge/` (idempotent — existing pages
are never overwritten):

```bash
bash .agents/monorepo-agents-harness/core/scripts/scaffold-knowledge.sh
```

Then, if you installed any adapter, re-apply it so the updated `/monorepo-harness-build` entry point
files (step 5: knowledge-base ingest + `check-kb`) reach your project. Run it once per installed
adapter (`claude-code`, `opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

## Manual follow-ups for the user

- None. From now on, every finished task that wrote `3_memory.md` will be ingested into `knowledge/`
  in the same commit by `/monorepo-harness-build` (enforced by the `check-kb` gate wired into the
  memory-gate). Research-only / `N/A` tasks are skipped automatically.
- If your project already has finished tasks with `3_memory.md`, you may optionally backfill them
  into the KB by running `core/scripts/kb-ingest.sh <task_dir>` per task — this is not required by
  the gate (it only gates today's task).

## Release summary

- New `knowledge/` compiled layer at the repo root: agents answer questions against
  `knowledge/index.md` + linked pages (modules/concepts/decision-records/verified-facts/sources)
  instead of re-deriving from per-workspace artifact trees on every query.
- `core/knowledge-template/` seed + `core/scripts/scaffold-knowledge.sh` (idempotent),
  `core/scripts/kb-ingest.sh` (task-end ingest engine), `task-state.sh check-kb` gate,
  `core/skills/knowledge-base/SKILL.md` (ingest/query/lint workflows).
- `core/root-AGENTS.md` gains "Query Knowledge First" (Agent Lifecycle 9), a pre-plan KB hit, a
  Reference Map row, and an Additional Context bullet; `install-harness.sh` step 4c seeds the KB on
  fresh installs; `audit-install.sh` Check 5c and `harness-update` step 9.5 cover the update path.
- All three `-build` entry points gain byte-identical step 5; skill symlinks (`claude-code`, `codex`)
  and an `opencode.jsonc` `instructions` entry wire the skill per adapter.