# Session Log — monorepo-agents-harness (repo root)

Working-session history for the harness template itself (repo root, since this repo has no `apps/`
or `packages/` workspace). Append one entry per session (newest last); bump the version each
session. Every entry MUST record the **artifact directory** of that session. **Read this before
starting any task that targets this workspace.**

## v0.1.0-rc.2 — 2026-08-27
- Scope: Install root `REVIEW.md` during install (was only shipped in the bundle, never written to
  the target root as `REVIEW.md`).
- Artifacts: .agents/artifacts/task_2026_08_27_install_root_review/
- Outcome: `install-harness.sh` now writes root `REVIEW.md` (provenance marker + PROJECT_NAME
  resolved, policy region left for the user; existing file untouched); `audit-install.sh` gained a
  REVIEW provenance check; docs updated; v0.1.0-rc.2.

## v0.1.0-rc.1 — 2026-08-27
- Scope: Align the artifact order with the AI-Native SDLC playbook — `intent → spec → plan →
  memory → verify`; renumber `1_plan.md`/`2_spec.md` to `1_spec.md`/`2_plan.md` with backcompat.
- Artifacts: .agents/artifacts/task_2026_08_27_align_artifact_order/
- Outcome: Renamed artifact contract; memory-gate/governance/adapters/docs updated; v0.1.0-rc.1.
