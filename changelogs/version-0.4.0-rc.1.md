---
version: 0.4.0-rc.1
from: 0.4.0-rc.0
date: 2026-09-24
---

# Version 0.4.0-rc.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.0 to 0.4.0-rc.1 (a shared "simple
English" writing standard for every generated file and every developer message).

## Commands to run

- None. The rule auto-installs with the regular bundle sync (the `core` install row); no
  command needs to run.

## Manual follow-ups for the user

- None. Your root `AGENTS.md` picks up the new Critical Gotcha and Reference Map row through the
  normal step-9 reconciliation (`core/skills/agents-md-merge/SKILL.md` — consent-gated, nothing to
  write by hand). Skills reference the rule through a bundle-relative path, so no per-adapter
  wiring is needed.

## Release summary

- New `core/governance/rules/simple-english.md` defines the standard: short sentences, common
  words, active voice, lists over paragraphs; technical terms stay exact. Includes bad vs good
  examples (spec, developer question).
- All 11 content-writing skills reference the rule up top via `../../governance/rules/simple-english.md`
  (agent-workflow, adr-workflow, intent-workflow, changeset-workflow, knowledge-base, pr-review,
  self-improvement-workflow, agents-md-merge, harness-update, ci-integration, monorepo).
- `core/root-AGENTS.md` gains Critical Gotcha 6 + a Reference Map row; manifest gains an explicit
  row for the rule.