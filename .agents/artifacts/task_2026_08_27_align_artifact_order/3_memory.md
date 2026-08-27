---
phase: memory
date: 2026-08-27
slug: align_artifact_order
commits: [00d90134a5e79652e3ceb90214ca0fb29fdefc55]
---

# Memory: Align artifact order with the AI-Native SDLC playbook

## What was done (single paragraph)

Renumbered the per-task artifact contract to the AI-native SDLC order (`intent → spec → plan →
memory → verify`): the spec is now `1_spec.md` (the "what"/contract) written first on plan approval,
and the plan is now `2_plan.md` (the "how"). Propagated the rename across every consumer of the old
names — the agent-workflow skill, memory-gate script, task-index format, governance rules, root
templates, PR-review skill, and all three adapters' build/review commands, the claude-code verifier,
and hook messages — and bumped VERSION to 0.2.0 with CHANGELOG plus a follow-up prompt.

## Surprising findings

- The rename had far more consumers than the plan's file list suggested: the PR-review skill, the
  `verifier` subagent, the `PORTABILITY.md` provenance notes, and `adapters/AGENTS.md` step-2 names
  all hard-coded the old order and needed a consistent pass, not just the skill/gate.
- `memory-gate.sh` originally special-cased the names `1_plan`/`2_spec` in both comments and the
  `verify_required` resolve logic; folding backcompat into a single `resolve_spec()` (new `1_spec.md`
  else legacy `2_spec.md`) kept the gate readable instead of scattering `||` checks.

## If I did it again

- Verify JSON/JSONC with the exact parser an editor would use (jq does not accept comments/trailing
  commas), and only touch files that actually reference the old names. `opencode.jsonc` was already
  non-strict-JSON before this task and needed no change.
- Write the grep sweep (a single command listing every remaining old-order reference and confirming
  each is an intentional backcompat note) earlier, so the "did I get them all" check is one shot.

## Related decisions

- **Backcompat, not forced migration**: accept legacy `2_spec.md` as the spec when `1_spec.md` is
  absent, so installed projects with in-flight tasks keep passing the gate on upgrade (user-confirmed).
- **Keep the numbered scheme** (user-confirmed): `1_spec.md`/`2_plan.md`/`3_memory.md`/`4_verify.md`
  rather than non-numbered names, preserving the phase-order semantics and index-row stability.
- **0.2.0 MINOR**: backcompat means no consumer breaks, but the approachable default (and thus the
  guidance/docs) changed, so a named MINOR bump with an upgrade note is the right signal.
