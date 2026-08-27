---
phase: spec
date: 2026-08-27
slug: align_artifact_order
---

# Spec: Align artifact order with the AI-Native SDLC playbook

## Scope

- Rename the per-task artifact contract: `1_plan.md`/`2_spec.md` → `1_spec.md`/`2_plan.md`, matching
  the playbook's `intent → spec → plan → memory → verify` order (Design precedes Build).
- Update the *production order* an agent follows: on plan approval write `1_spec.md` first, then
  `2_plan.md`, before any implementation Edit/Write.
- Keep the numbered scheme; renumber only. Do not rename `0_intent.md`, `3_memory.md`, `4_verify.md`.
- Add backcompat: where the new `1_spec.md` is absent, consumers accept the legacy `2_spec.md` as the
  spec, so installed projects with in-flight tasks keep passing the gate.
- Update every consumer of the old names: agent-workflow skill, memory-gate, governance rules, root
  templates, all three adapters (build/review commands, verifier, hooks), README, INSTALL, version
  and changelog.

Not in scope: renaming to non-numbered `spec.md`/`plan.md`; changing the intent/memory/verify files;
altering the index row format; a forced in-place migration of the old names on installed projects.

## Behavioral contract

- Input: an installed or fresh harness project with a plan-mode task.
- Output: on plan approval, the agent creates `<ws>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`
  and writes `1_spec.md` then `2_plan.md`, before implementation.
- Side effects: `memory-gate.sh` treats `1_spec.md` as the required spec file; it also recognizes a
  legacy `2_spec.md` when `1_spec.md` is absent (backcompat). Nothing deletes or renames user files.

## API / contracts

- File names: `1_spec.md` (always present), `2_plan.md` (marker ◆), `3_memory.md`, `4_verify.md`.
- Index link target: `1_spec.md` — the always-present file; legacy rows/lookups accept `2_spec.md`.
- `memory-gate.sh`: spec lookup order `1_spec.md` → (fallback) `2_spec.md`; verify-required check
  reads the spec's "## Test / verification plan" section from whichever spec file resolves.

## Data model

- `memory-gate.sh` `verify_required()`: resolve `spec` as `$1/1_spec.md` else `$1/2_spec.md`, then
  parse its "## Test / verification plan" section; `N/A`/empty → verify not required.
- Missing-file detection (default mode): missing `1_spec.md` (and no legacy `2_spec.md`) → report
  `1_spec.md`; `--json` mode gates on missing `3_memory.md` and `4_verify.md` (when required).

## Acceptance criteria

- [ ] `agent-workflow/SKILL.md` documents spec-before-plan write order and the `1_spec.md`/`2_plan.md` names.
- [ ] `memory-gate.sh` enforces `1_spec.md` presence, and passes legacy dirs that only have `2_spec.md`.
- [ ] Governance (`artifacts/AGENTS.md`, `index-template.md`, `intents/AGENTS.md`) references the new names.
- [ ] Root templates (`root-AGENTS.md`, `root-REVIEW.md`, `workspace-agents-template/session-log.md`) updated.
- [ ] All three adapters' build/review commands, the claude-code verifier, and hook JSON messages updated.
- [ ] `README.md` and `INSTALL.md` reflect the new order with no stale `1_plan.md`/`2_spec.md` order claims.
- [ ] `VERSION` bumped to `0.1.0-rc.1`; `CHANGELOG.md` and a follow-up prompt added.
- [ ] Verification: `bash -n`, `jq`, `audit-install.sh` exit 0, and a `memory-gate.sh` backcompat smoke test.

## Test / verification plan

- `bash -n` on every touched `.sh` file.
- `jq .` on every touched `.json`/`.jsonc` file.
- `bash core/scripts/audit-install.sh` → exit 0.
- Backcompat smoke: create a temp dir with only `2_spec.md` whose Test/verification plan is a real
  command, plus no `1_spec.md`; run `memory-gate.sh` default mode → gate only reports
  `3_memory.md`/`4_verify.md`, not `1_spec.md` (proving legacy spec is accepted).
- Grep sweep: no remaining "write `1_plan.md` then `2_spec.md`" order or stale links in docs/adapters.

## Architectural constraints

- Adapter enforcement must stay thin: the order/backcompat lives in `core/skills`/`core/scripts`; the
  adapters only re-wire the command/hook text that points at the file names.
- Rules stay in `core/`; the `adapters/AGENTS.md` and adapter READMEs only mention the names, never
  redefine the contract.
- English everywhere; stability of slugs and index row format preserved.
