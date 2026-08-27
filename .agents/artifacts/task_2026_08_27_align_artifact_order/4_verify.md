---
phase: verify
date: 2026-08-27
slug: align_artifact_order
---

# Verify: Align artifact order with the AI-Native SDLC playbook

## Verification run

All commands run from repo root; exit codes shown.

`for f in core/scripts/*.sh; do bash -n "$f" || echo FAIL; done` → all 11 scripts `OK` (bash -n clean)

`jq . adapters/claude-code/.claude/settings.json` → valid (exit 0)
`jq . adapters/codex/.codex/hooks.json` → valid (exit 0)

`bash core/scripts/audit-install.sh; echo $?` → `audit-install: no bundle to compare against ... exit 2`
(non-zero is expected/structural — this repo is the template, not an installed consumer; the script
has no bundle at `.agents/monorepo-agents-harness` to audit. Manifest rows were unchanged because
only file contents were edited, no files added/removed to the bundle.)

Backcompat smoke test (temp git repo, `apps/api/.agents/artifacts/task_2026_08_27_legacy/` with only
`2_spec.md` whose Test/verification plan = `make test`, no `1_spec.md`):
- `memory-gate.sh` default mode → exit 1, output `missing: 3_memory.md 4_verify.md` and NO
  `1_spec.md` mention → legacy spec accepted. PASS
- Added full new-style dir (1_spec+2_plan+3_memory+4_verify) → `memory-gate.sh` exit 0. PASS
- `memory-gate.sh --json` on legacy dir with memory present → `decision:"block"` on `4_verify.md`,
  no `1_spec.md` mention → `verify_required` used legacy spec. PASS

Grep sweep: `grep -rn "1_plan\|2_spec" core adapters README.md INSTALL.md PORTABILITY.md` → only
intentional backcompat notes in `memory-gate.sh`, `core/skills/pr-review/SKILL.md`, and
`PORTABILITY.md:102`. No stale order claims remain.

## Acceptance criteria results

- [x] `agent-workflow/SKILL.md` documents spec-before-plan write order and `1_spec.md`/`2_plan.md` names — Phase 1 = spec, Phase 2 = plan, write order explicitly spec-first.
- [x] `memory-gate.sh` enforces `1_spec.md` presence and passes legacy dirs that only have `2_spec.md` — verified by backcompat smoke test.
- [x] Governance (`artifacts/AGENTS.md`, `index-template.md`, `intents/AGENTS.md`) references the new names.
- [x] Root templates (`root-AGENTS.md`, `root-REVIEW.md`, `workspace-agents-template/session-log.md`) updated.
- [x] All three adapters' build/review commands, claude-code verifier, and hook JSON messages updated — settings.json and hooks.json jq-valid.
- [x] `README.md` and `INSTALL.md` reflect the new order with no stale `1_plan.md`/`2_spec.md` order claims — grep sweep clean.
- [x] `VERSION` bumped to `0.2.0`; `CHANGELOG.md` section and `changelogs/version-0.2.0.md` follow-up added.
- [x] Verification: `bash -n`, `jq`, backcompat smoke passed; `audit-install.sh` exit 2 expected (no bundle in template repo).

## Deviations

- `audit-install.sh` could not be driven to exit 0 because this repo is the template and has no
  installed bundle to audit; its role as a consumer-side check is unchanged and its manifest rows
  required no edits. This is the only acceptance criterion not literally satisfied — a structural,
  expected deviation, not a defect.
