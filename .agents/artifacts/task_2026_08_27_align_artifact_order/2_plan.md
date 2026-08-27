---
phase: plan
date: 2026-08-27
slug: align_artifact_order
status: approved
---

# Plan: Align artifact order with the AI-Native SDLC playbook

## Problem

The harness produces task artifacts in `plan → spec` order (`1_plan.md`, then `2_spec.md`), but the
reference playbook (`claude.com/blog/the-ai-native-sdlc-playbook`) specifies `intent → spec → plan`
— Design (spec: "what") precedes Build (plan: "how"). The current order mislabels which artifact is
the contract and which is the implementation sketch.

## Approach

Flip the numbered prefix and the write order so the agent produces `1_spec.md` (what/contract) then
`2_plan.md` (how), preserving the numbered scheme and `0_intent.md` / `3_memory.md` / `4_verify.md`.
Add backcompat so legacy installed dirs that only have `2_spec.md` still pass the gate. Propagate the
rename across every consumer of the old names in a single commit and bump to `0.1.0-rc.1`.

## Related prior work

- none found (first dogfooding task in this repo root).

## Steps

1. Update `core/skills/agent-workflow/SKILL.md`: Phase 1 → `1_spec.md`, Phase 2 → `2_plan.md`,
   reorder to spec-before-plan, update description/layout/edge-cases.
2. Update `core/scripts/memory-gate.sh`: spec lookup `1_spec.md` else `2_spec.md`; update comments.
3. Update governance: `core/governance/artifacts/AGENTS.md`, `artifacts/index-template.md`,
   `intents/AGENTS.md`.
4. Update root templates: `core/root-AGENTS.md`, `core/root-REVIEW.md`,
   `core/workspace-agents-template/session-log.md`.
5. Update adapters: claude-code (build command, settings.json hook, verifier, review command, README),
   opencode (build+review commands, README), codex (build skill, review skill, hooks.json, README),
   and `adapters/AGENTS.md`.
6. Update docs: `README.md` scenarios/layout, `INSTALL.md`.
7. Version: `VERSION` → `0.1.0-rc.1`, `CHANGELOG.md` section, `changelogs/version-0.1.0-rc.1.md` follow-up.
8. Verify (bash -n, jq, audit-install.sh, backcompat smoke, grep sweep).

## Affected files / modules

- core/skills/agent-workflow/SKILL.md
- core/scripts/memory-gate.sh
- core/governance/{artifacts,index-template,intents}
- core/root-AGENTS.md, core/root-REVIEW.md, core/workspace-agents-template/session-log.md
- adapters/{AGENTS.md, claude-code, opencode, codex} (commands, skills, hooks, verifier, READMEs)
- README.md, INSTALL.md, VERSION, CHANGELOG.md, changelogs/version-0.1.0-rc.1.md

## Risks & assumptions

- Assumes backcompat (accepting legacy `2_spec.md` as spec) is preferable to a forced migration
  prompt — confirmed by the user.
- Assumes keeping the numbered scheme is correct — confirmed by the user.
- Risk: a stale reference to the old order slips through → mitigated by final grep sweep.

## Definition of done

- [ ] Spec-before-plan write order documented and enforced in skill + adapters
- [ ] memory-gate requires `1_spec.md` and accepts legacy `2_spec.md`
- [ ] Governée / root / adapters / docs all reference the new names consistently
- [ ] VERSION 0.1.0-rc.1 + CHANGELOG + follow-up prompt
- [ ] All verification commands pass
