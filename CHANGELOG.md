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

### Changed

### Removed

### Upgrade Notes

## [0.2.1] - 2026-08-24

### Changed

- opencode adapter no longer ships a plugin. Memory-gate enforcement on opencode is now provided
  solely by the universal hard gate (`core/scripts/memory-gate.sh`) installed as a git pre-commit
  hook or CI step. The `agent-workflow` skill already instructs the agent to write `3_memory.md` at
  task end, so the soft `session.idle` reminder was redundant.
- Updated `adapters/opencode/INSTALL.md`, `adapters/opencode/README.md`, `PORTABILITY.md`, and
  `INSTALL.md` to remove plugin references and clarify hard-gate-only enforcement.

### Removed

- `adapters/opencode/.opencode/plugins/agent-harness.ts`.

### Upgrade Notes

- Delete the old opencode plugin file from your installed copy:
  `.opencode/plugins/agent-harness.ts`.
- Ensure `core/scripts/memory-gate.sh` is wired as a git pre-commit hook or CI step; it is now the
  only enforcement mechanism on opencode.
- Re-apply the opencode config merge (`opencode.jsonc`) and command files
  (`.opencode/commands/tah-update.md`, `.opencode/commands/tah-build.md`) from the new bundle.

## [0.2.0] - 2026-08-24

### Added

- Harness versioning infrastructure: `core/VERSION`, this changelog, and
  `core/scripts/harness-update.sh` (`current` / `latest` / `check`) comparing an
  installed copy against the upstream repo.
- Changelog-driven upgrades: each release ships an upgrade prompt in
  `changelogs/version-X.Y.Z.md`. The active agent reads these markdown prompts and applies the
  described `copy` / `delete` / `run` / `note` operations.
- `/tah:update` slash command for Claude Code and `/tah-update` for opencode, backed by the
  shared `core/skills/harness-update/SKILL.md` instructions.
- `/tah-build` manual plan/spec build trigger for Claude Code, opencode, and Codex CLI, backed by
  the shared `core/skills/agent-workflow/SKILL.md` instructions.
- Codex CLI adapter (`adapters/codex/`) with `.codex/config.toml`, `.codex/hooks.json`,
  and the `/tah-update` skill backed by the same update engine.

### Changed

- Task artifacts moved out of the docs app into each workspace's `.agents/artifacts/` tree with a
  mandatory searchable `index.md`; the memory-gate scans all workspaces automatically.
- The docs-placement guard capability was removed entirely (no docs-app dependency).

### Removed

- `core/scripts/check-docs-placement.sh`, its adapter hooks, and the docs-tree governance files.

### Upgrade Notes

- The harness update command is `/tah:update` for Claude Code and `/tah-update` for opencode
  (and Codex CLI). Remove the old adapter files
  (`.claude/commands/turborepo-harness/update-check.md` and
  `.opencode/commands/turborepo-harness-update-check.md`) and copy the new ones from
  `.claude/commands/tah/update.md` and `.opencode/commands/tah-update.md`.
- The manual plan/spec build trigger is `/tah-build` on all agents. Copy the new adapter files:
  `.claude/commands/tah-build.md`, `.opencode/commands/tah-build.md`, and
  `.agents/skills/tah-build/SKILL.md` (Codex CLI).

## [0.1.0] - 2026-08-23

### Added

- Initial release: plan → spec → memory workflow (`agent-workflow` skill), per-workspace working
  state (`.agents/{session-log,lessons,todo}.md`), memory-gate enforcement, claude-code and opencode
  adapters, Turborepo guidance skill.

[Unreleased]: https://github.com/atayahmet/turborepo-agent-harness/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/atayahmet/turborepo-agent-harness/releases/tag/v0.2.1
[0.2.0]: https://github.com/atayahmet/turborepo-agent-harness/releases/tag/v0.2.0
[0.1.0]: https://github.com/atayahmet/turborepo-agent-harness/releases/tag/v0.1.0
