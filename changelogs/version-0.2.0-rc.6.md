---
version: 0.2.0-rc.6
from: 0.2.0-rc.5
date: 2026-09-21
---

# Version 0.2.0-rc.6 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.2.0-rc.5 to 0.2.0-rc.6 (build scope confinement:
`/monorepo-harness-build` implementations must not create apps/packages that the approved spec and
plan do not list).

## Commands to run

Re-apply every installed adapter so the updated `/monorepo-harness-build` entry point files reach
your project. The harness-update workflow's step 7.5 does this already; running it directly is
harmless and idempotent (`--refresh` skips config rows). Run it once per installed adapter
(`claude-code`, `opencode`, and/or `codex`):

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <your-adapter> --refresh
```

## Manual follow-ups for the user

- None. Root `AGENTS.md` reconciliation is handled by the normal harness-update flow via
  `agents-md-merge`.

## Release summary

- `core/skills/agent-workflow/SKILL.md` gains a **Build scope** rule before Phase 3: the
  implementation started by `/monorepo-harness-build` touches only `1_spec.md`'s `## Scope` /
  `## Acceptance criteria` and `2_plan.md`'s `## Affected files / modules`; creating any file, app,
  package, or workspace the plan does not name is forbidden, and scope must grow only through an
  approved spec/plan extension (stop, report, extend, resume).
- `core/root-AGENTS.md` gains Critical Gotcha 5 with the same boundary, so consumer root `AGENTS.md`
  files enforce build-scope confinement.
- All three `/monorepo-harness-build` entry points (claude-code, opencode, codex) tighten step 3 with
  byte-identical text — never create or touch an app, package, or file neither the spec nor the plan
  lists.
- Instruction-only change: no gate script, artifact format, or manifest change.