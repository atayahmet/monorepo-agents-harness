# Session Log — monorepo-agents-harness (repo root)

Working-session history for the harness template itself (repo root, since this repo has no `apps/`
or `packages/` workspace). Append one entry per session (newest last); bump the version each
session. Every entry MUST record the **artifact directory** of that session. **Read this before
starting any task that targets this workspace.**

## v0.1.0 — 2026-08-27
- Scope: Align the artifact order with the AI-Native SDLC playbook — `intent → spec → plan →
  memory → verify`; renumber `1_plan.md`/`2_spec.md` to `1_spec.md`/`2_plan.md` with backcompat.
- Artifacts: .agents/artifacts/task_2026_08_27_align_artifact_order/
- Outcome: Renamed artifact contract; memory-gate/governance/adapters/docs updated; v0.2.0.
