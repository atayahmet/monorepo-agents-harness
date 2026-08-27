# Changelog

All notable changes to the agent harness are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/), prereleases included (`0.1.0-rc.0` precedes `0.1.0`).

Every release MUST include an **Upgrade Notes** section describing anything an installed copy needs
to do beyond the normal sync (behavior changes, artifact-layout changes, manual merges).

Release procedure (harness maintainers):

1. Update `VERSION` at the repo root (SemVer: MAJOR = workflow/artifact-layout breakers, MINOR = new
   capabilities, PATCH = fixes/docs; `-rc.N` while stabilizing a release).
2. Add a `CHANGELOG.md` section with Upgrade Notes.
3. Add `changelogs/version-X.Y.Z.md` if the release needs anything the manifests cannot express —
   commands to run or manual follow-ups. Files added to the bundle or an adapter need **no** prompt:
   add the manifest row instead (`changelogs/README.md`).
4. Commit and tag the upstream repo as `vX.Y.Z` (`git tag -a vX.Y.Z -m … && git push origin vX.Y.Z`).

## [Unreleased]

### Added

### Changed

### Removed

### Upgrade Notes

## [0.1.0-rc.0] - 2026-08-27

First release candidate. Versioning starts here.

### Added

- **Plan → spec → memory → verify artifact workflow.** Every non-trivial task produces
  `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` containing `1_plan.md`, `2_spec.md`,
  `3_memory.md` and `4_verify.md` (the last required unless the spec's verification plan is `N/A`),
  indexed in that workspace's searchable `.agents/artifacts/index.md`.
- **A hard memory-gate.** `core/scripts/memory-gate.sh` scans every workspace and blocks until
  today's task directory is complete — as an agent stop-hook where the agent can block its own stop,
  and as a git `pre-commit` hook / CI step everywhere else. Fail-open on missing dependencies.
- **Manifest-driven install.** What lands in a consumer project is data, not prose:
  `core/install-manifest.txt` (the bundle whitelist) and `adapters/<agent>/manifest.txt` (one row
  per installed file; verbs `copy`, `link`, `merge`, `tmpl`). Executed by
  `core/scripts/install-harness.sh` (Phase 1) and `core/scripts/install-adapter.sh` (Phase 2),
  verified against those same manifests by `core/scripts/audit-install.sh`.
- **Never-destructive install/update.** Nothing is deleted: replaced content is moved to
  `.agents/.harness-trash/<timestamp>_<pid>/`, and purging it is the user's own explicit call via
  `core/scripts/cleanup-harness-trash.sh`. An existing config file is never modified — the adapter's
  version arrives as `<file>.harness-proposed` for a deliberate merge.
- **Root `AGENTS.md` reconciliation.** `core/root-AGENTS.md` is installed as the project's
  `AGENTS.md` with a provenance marker recording the template version, so
  `core/skills/agents-md-merge/SKILL.md` can three-way merge on later upgrades — presented as a
  diff and written only after explicit approval.
- **Consent-gated upgrades.** `core/scripts/harness-update.sh` resolves installed vs. upstream
  version (SemVer precedence, prereleases included); `core/skills/harness-update/SKILL.md` reports
  the diff, asks once, then re-runs the installers and audits the result before claiming success.
- **Adapters for claude-code, opencode and Codex CLI**, under a mandatory-parity rule
  (`PORTABILITY.md`): every harness capability has a live counterpart per agent, or an explicit
  agent-agnostic fallback. Each ships the harness-plumbing commands `/monorepo-harness-build`,
  `-update`, `-ci`, `-review`, `-intent`, plus a `verifier` subagent where the agent supports one.
- **Supporting skills:** `agent-workflow` (artifact templates), `monorepo` (framework-agnostic
  guidance), `ci-integration` (detects the CI provider and wires the gate in), `pr-review` (reviews a
  diff against `REVIEW.md` and the task's own artifacts), `intent-workflow` (stakeholder intent
  capture with an approve/reject gate).
- **Workspace scaffolding.** `core/scripts/scaffold-workspace-agents.sh` seeds every app and package
  with `.agents/{session-log,lessons,todo}.md`, the artifact tree and the intent inbox; it never
  overwrites an existing file and is safe to re-run after adding a workspace.

### Upgrade Notes

- Nothing to upgrade from — this is the first tagged release. Install with `INSTALL.md`.
- While on `-rc.*`, treat the artifact layout and the manifest format as still settling: a breaking
  change may land in a later `rc` without a MAJOR bump.

[Unreleased]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.1.0-rc.0...HEAD
[0.1.0-rc.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.0
