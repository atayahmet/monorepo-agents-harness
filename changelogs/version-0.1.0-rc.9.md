---
version: 0.1.0-rc.9
from: 0.1.0-rc.8
date: 2026-09-02
---

# Version 0.1.0-rc.9 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.8 to 0.1.0-rc.9.

## Commands to run

None.

## Manual follow-ups for the user

None.

## Release summary

- Intent-seeded tasks now explicitly reference the seeding intent in both the spec and plan artifacts.
  `1_spec.md` frontmatter includes `intent: 0_intent.md` when the task was seeded by an approved intent
  (ad-hoc tasks omit the line), and `2_plan.md`'s `## Problem` section cites the intent with an
  explanatory link. Updated in `core/skills/agent-workflow/SKILL.md` and
  `core/governance/intents/AGENTS.md`.
