---
version: 0.1.0-rc.1
from: 0.1.0-rc.0
date: 2026-08-27
---

# Version 0.1.0-rc.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.1.0-rc.0 to 0.1.0-rc.1.

This release renames the per-task artifacts to match the AI-native SDLC order
(`intent → spec → plan → memory → verify`): `1_plan.md` → `2_plan.md` (the "how") and
`2_spec.md` → `1_spec.md` (the "what"). The installer and audit already handle the renamed files (a
manifest concern, not a prompt), and your root `AGENTS.md` is reconciled via the normal
`agents-md-merge` step.

## Manual follow-ups for the user

- **No action is required for a clean upgrade.** New tasks you start will use `1_spec.md` /
  `2_plan.md`.
- **Existing task directories are left untouched and keep passing the gate via backcompat** — the
  gate and the review skill accept a legacy `2_spec.md` as the spec when no `1_spec.md` exists. If
  you prefer a uniform layout, you may rename an in-flight task dir's spec/plan files
  (`2_spec.md` → `1_spec.md`, `1_plan.md` → `2_plan.md`) and fix the linked path in
  `.agents/artifacts/index.md` — this is optional and never enforced.

## Release summary

- Artifact order aligned with the AI-native SDLC playbook: spec (`1_spec.md`) is now written before
  the plan (`2_plan.md`); all skills, the memory-gate, the task-index format, governance rules, root
  templates, PR review, and the adapters' build/review commands and hooks were updated to the new
  names, with backcompat so legacy task dirs keep passing.
