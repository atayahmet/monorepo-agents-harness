---
version: 0.1.0-rc.5
from: 0.1.0-rc.4
date: 2026-08-28
---

# Version 0.1.0-rc.5 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.4 to 0.1.0-rc.5 (adds the ADR workflow).

## Commands to run

Re-apply every installed adapter so the new skills reach your project. The harness-update workflow's
step 7.5 does this already; running it here directly is harmless and idempotent (`--refresh` skips
config rows). Run it once per installed adapter (`claude-code`, `opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

For claude-code and codex this symlinks the new `adr-workflow` skill into place. For opencode it does
**not** touch your existing `opencode.jsonc` — it writes `opencode.jsonc.harness-proposed` instead,
so the next step applies to you.

## Manual follow-ups for the user

- **opencode: add the ADR skill to your config.** Add
  `.agents/monorepo-agents-harness/core/skills/adr-workflow/SKILL.md` to the `instructions` array in
  your root `opencode.jsonc`, or merge the proposed `opencode.jsonc.harness-proposed`. Until you do,
  opencode simply will not auto-load the ADR skill — nothing is broken, it is a soft loss (ADRs stay
  optional and are still reachable through the shared `agent-workflow` instructions).

## Release summary

- New auto-triggered ADR (Architecture Decision Record) workflow: `core/skills/adr-workflow/SKILL.md`
  writes `adr/NNNN-<title>.md` files inside each task directory when a spec or plan makes an
  architecture-affecting decision; the `1_spec.md` template gains a `## Architectural decisions`
  section; `task-state.sh check-adr` validates the references; PR review and the root `REVIEW.md`
  template gain an ADR-compliance pass. All three adapters register the skill (opencode needs the
  config merge above).