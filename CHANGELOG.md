# Changelog

All notable changes to the agent harness are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

Every release MUST include an **Upgrade Notes** section describing anything an installed copy needs
to do beyond re-copying the bundle (behavior changes, artifact-layout changes, manual merges).

Release procedure (harness maintainers):

1. Update `core/VERSION` (SemVer: MAJOR = workflow/artifact-layout breakers, MINOR = new
   capabilities, PATCH = fixes/docs).
2. Add a `CHANGELOG.md` section with Upgrade Notes.
3. Commit and tag the upstream repo as `vX.Y.Z` (`git tag vX.Y.Z && git push --tags`).

## [Unreleased]

### Added

- Harness versioning infrastructure: `core/VERSION`, this changelog, and
  `core/scripts/harness-update.sh` (`current` / `latest` / `check` / `upgrade`) comparing an
  installed copy against the upstream repo.
- `/tah:update` slash command for Claude Code and opencode, backed by the shared
  `core/skills/harness-update/SKILL.md` instructions.

### Changed

- Task artifacts moved out of the docs app into each workspace's `.agents/artifacts/` tree with a
  mandatory searchable `index.md`; the memory-gate scans all workspaces automatically.
- The docs-placement guard capability was removed entirely (no docs-app dependency).

### Removed

- `core/scripts/check-docs-placement.sh`, its adapter hooks, and the docs-tree governance files.

### Upgrade Notes

- The harness update slash command is now `/tah:update` on both Claude Code and opencode. Remove
  the old adapter files (`.claude/commands/turborepo-harness/update-check.md` and
  `.opencode/commands/turborepo-harness-update-check.md`) and copy the new ones from
  `.claude/commands/tah/update.md` and `.opencode/commands/tah/update.md`.

## [1.0.0] - 2026-08-23

### Added

- Initial release: plan → spec → memory workflow (`agent-workflow` skill), per-workspace working
  state (`.agents/{session-log,lessons,todo}.md`), memory-gate enforcement, claude-code and opencode
  adapters, Turborepo guidance skill.

[Unreleased]: https://github.com/atayahmet/turborepo-agent-harness/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/atayahmet/turborepo-agent-harness/releases/tag/v1.0.0
