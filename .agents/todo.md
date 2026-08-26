# Todo — monorepo-agents-harness (root)

Working plan for the current task. Overwrite per task.

## CI/CD integration (Phase 2, v0.8.0) — 2026-08-26

- [x] Write `1_plan.md` / `2_spec.md`
- [x] `core/scripts/detect-ci-provider.sh`
- [x] `core/skills/ci-integration/SKILL.md` (GH Actions auto + GitLab/Bitbucket/CircleCI guided)
- [x] Three adapter command/skill files for `/monorepo-harness-ci`
- [x] `PORTABILITY.md`, `adapters/AGENTS.md`, `README.md`, `INSTALL.md` §11
- [x] Bump `core/VERSION` to 0.8.0, `CHANGELOG.md` `[0.8.0]`, `changelogs/version-0.8.0.md`
- [x] Verify (scratch provider detection x5, YAML validation), write `4_verify.md` + `3_memory.md`,
      update `.agents/artifacts/index.md`, commit

Next: Phase 3 (PR review skill) — own plan/spec cycle, not started.
