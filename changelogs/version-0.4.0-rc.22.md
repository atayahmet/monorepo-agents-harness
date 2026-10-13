---
version: 0.4.0-rc.22
from: 0.4.0-rc.21
date: 2026-10-13
---

# Version 0.4.0-rc.22 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.21 to 0.4.0-rc.22. This release adds an
**objectivity rule**: the agent must not flatter the developer, and must not agree without evidence.

## What changed

The harness told the agent how to plan, build, verify and write. It never told the agent how to
**judge** the developer's input. So nothing stopped the agent from agreeing with a weak design,
dropping a correct answer under pushback, opening replies with praise, or hiding a failed test.

This release adds one shared rule file and wires it in like the existing `simple-english` rule:

- **New `core/governance/rules/objectivity.md`** — six checkable behaviours with bad → good examples:
  judge the input, not the person; say "no" with evidence; hold a correct position under pushback; no
  flattery openers; report outcomes as they are; do not over-correct.
- **`core/root-AGENTS.md`** — a new numbered Critical Gotcha (7) that names the rule file, so the
  principle stays in context on every turn, plus a `## Reference Map` row.
- **`core/install-manifest.txt`** — an explicit, audited row for the new rule file.

There is **no hook and no gate**: judgement has no reliable hook. The value is the always-in-context
principle plus the concrete wording. No script, adapter row, or artifact-layout change.

## Commands to run

- None by hand. There is nothing to install: the rule file ships in the bundle sync, and the manifest
  row is part of that sync.

## Manual follow-ups for the user

- None required. The `agents-md-merge` skill carries the new Critical Gotcha into your existing root
  `AGENTS.md` on this upgrade, with your approval. If you decline that merge, the next
  install/upgrade offers it again — a decline never blocks the upgrade.

## Release summary

- `core/governance/rules/objectivity.md` (new): the objectivity / no-sycophancy rule.
- `core/root-AGENTS.md`: Critical Gotcha 7 + Reference Map row.
- `core/install-manifest.txt`: explicit audited row for the new rule file (closes #42).

**Note.** The release itself needs no command or manual follow-up, so `changelogs/README.md` would
normally omit this prompt. It is added at the maintainer's request.
