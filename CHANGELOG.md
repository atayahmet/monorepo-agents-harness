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

## [0.4.3] - 2026-08-26

### Changed

- **Renamed the harness-plumbing command/skill namespace from `/tah-*` to `/monorepo-harness-*`**
  across all three adapters: `/tah-build` → `/monorepo-harness-build`, `/tah:update`
  (claude-code) → `/monorepo-harness:update`, and `/tah-update` (opencode/Codex CLI) →
  `/monorepo-harness-update`. Renamed the backing files accordingly:
  `.claude/commands/tah-build.md` → `.claude/commands/monorepo-harness-build.md`,
  `.claude/commands/tah/update.md` → `.claude/commands/monorepo-harness/update.md`,
  `.opencode/commands/tah-build.md` → `.opencode/commands/monorepo-harness-build.md`,
  `.opencode/commands/tah-update.md` → `.opencode/commands/monorepo-harness-update.md`,
  `.agents/skills/tah-build/` → `.agents/skills/monorepo-harness-build/`, and
  `.agents/skills/tah-update/` → `.agents/skills/monorepo-harness-update/`. Updated
  `README.md`, `INSTALL.md`, `PORTABILITY.md`, every adapter `README.md`/`INSTALL.md`, and
  `core/skills/agent-workflow/SKILL.md` / `core/skills/harness-update/SKILL.md` to match. The old
  `tah-*` prefix was a leftover from the project's pre-0.4.0 name (`turborepo-agent-harness`);
  this finishes aligning the command namespace with the current project name,
  `monorepo-agents-harness`.

### Upgrade Notes

- Follow `changelogs/version-0.4.3.md` to migrate existing installs. Key steps:
  - Delete the old `tah-*` command/skill files and copy the renamed `monorepo-harness-*` ones
    from the new bundle (see the file list in `changelogs/version-0.4.3.md`).
  - Start typing the new command names: `/monorepo-harness-build`, `/monorepo-harness:update`
    (claude-code), `/monorepo-harness-update` (opencode/Codex CLI).

## [0.4.2] - 2026-08-25

### Changed

- Pointed the repository origin remote and all historic release links in `CHANGELOG.md` to the
  renamed `monorepo-agents-harness` GitHub repository (`https://github.com/atayahmet/monorepo-agents-harness`).

### Upgrade Notes

- No action required for installed copies. If you override `HARNESS_UPSTREAM`, ensure it still
  resolves to the correct repository.

## [0.4.1] - 2026-08-25

### Changed

- **Installed harness location is now `.agents/monorepo-agents-harness/` only.** The bundle is no
  longer copied to the repo root as `monorepo-agents-harness/`. The runtime symlink tree under
  `.agents/monorepo-agents-harness/` is removed; the bundle directory itself serves as both source
  and runtime.

### Fixed

- Prevented the installer and upgrader from leaving `monorepo-agents-harness/` or
  `.harness-update-*` directories at the repo root. Temporary upgrade clones now go under `.agents/`.

### Upgrade Notes

- Follow `changelogs/version-0.4.1.md` to migrate existing installs. Key steps:
  - Move the root `monorepo-agents-harness/` directory into `.agents/monorepo-agents-harness/`.
  - Remove any stale runtime symlink tree (e.g. `.agents/monorepo-agents-harness/skills/`,
    `.agents/monorepo-agents-harness/scripts/`, `.agents/monorepo-agents-harness/governance/`,
    `.agents/monorepo-agents-harness/workspace-agents-template/`) — the bundle now lives directly
    under `.agents/monorepo-agents-harness/`.
  - Update adapter configs (`.claude/settings.json`, `opencode.jsonc`, `.codex/hooks.json`) and
    skill/command files to point at `.agents/monorepo-agents-harness/core/scripts/` and
    `.agents/monorepo-agents-harness/core/skills/`.
  - Re-link `.git/hooks/pre-commit` to
    `.agents/monorepo-agents-harness/core/scripts/memory-gate.sh`.

## [0.4.0] - 2026-08-25

### Added

- New `core/scripts/detect-monorepo-framework.sh` that detects the target repo's monorepo
  framework from repo markers (`turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml`,
  `package.json` `workspaces`).
- Generic `core/skills/monorepo/SKILL.md` covering framework-agnostic monorepo principles and
  Turborepo, Nx, Lerna, and npm/yarn/pnpm workspaces.

### Changed

- **Renamed the project from `turborepo-agent-harness` to `monorepo-agents-harness`.** Every
  reference to the bundle directory, runtime directory, upstream URL, docs, scripts, and adapter
  configs now uses the new name.
- **Replaced the Turborepo-specific skill with a generic monorepo skill.** The old
  `core/skills/turborepo/` directory is removed; its guidance is folded into
  `core/skills/monorepo/SKILL.md`.
- `core/scripts/scaffold-workspace-agents.sh` and `core/scripts/memory-gate.sh` now use the
  framework detector to discover workspace directories (`apps/`, `packages/`, `libs/`, or custom
  workspace globs from `lerna.json` / `pnpm-workspace.yaml` / `package.json`).
- `core/root-AGENTS.md` is now framework-agnostic and includes a `{{MONOREPO_FRAMEWORK}}`
  placeholder that is filled at install time from the detector output.

### Removed

- `core/skills/turborepo/` and all its reference files.

### Upgrade Notes

- Follow `changelogs/version-0.4.0.md` to migrate existing installs. Key steps:
  - Rename the installed bundle directory from `turborepo-agent-harness/` to
    `monorepo-agents-harness/`.
  - Update `.agents/turborepo-agent-harness/` to `.agents/monorepo-agents-harness/` and re-create
    the runtime symlinks (including the new `monorepo` skill and
    `detect-monorepo-framework.sh`).
  - Update `.claude/settings.json`, `opencode.jsonc`, and `.codex/hooks.json` to point at the new
    `.agents/monorepo-agents-harness/` paths.
  - Replace `.claude/skills/turborepo` and `.agents/skills/turborepo` symlinks with `monorepo`.
  - Fill `{{MONOREPO_FRAMEWORK}}` in your project's root `AGENTS.md`.
  - Re-link `.git/hooks/pre-commit` to `.agents/monorepo-agents-harness/scripts/memory-gate.sh`.

## [0.3.0] - 2026-08-25

### Changed

- Relocated the installed harness runtime from inside the bundle's `core/` tree to a shared
  project-owned directory at `.agents/turborepo-agent-harness/`. The shared skills
  (`agent-workflow`, `turborepo`, `harness-update`) and scripts (`memory-gate.sh`,
  `harness-update.sh`, `scaffold-workspace-agents.sh`) now live there as symlinks to the bundle
  source, so multiple agents no longer need separate physical copies.
- Moved `core/VERSION` to `.agents/turborepo-agent-harness/VERSION`. The update engine and all
  adapter configs now read the installed version from this new location.
- Updated every adapter install guide to create symlinks instead of copying shared skills, and
  updated adapter configs to reference the shared runtime paths.

### Upgrade Notes

- Follow `changelogs/version-0.3.0.md` to migrate existing installs. Key steps:
  - Create `.agents/turborepo-agent-harness/` and move the version file there.
  - Replace physical copies of shared skills with symlinks into the new runtime directory.
  - Update `.claude/settings.json`, `opencode.jsonc`, and `.codex/hooks.json` to point at the new
    `.agents/turborepo-agent-harness/` paths.
  - Re-link `.git/hooks/pre-commit` to `.agents/turborepo-agent-harness/scripts/memory-gate.sh`.

## [0.2.2] - 2026-08-25

### Changed

- Moved the installable root agent-guidelines template from repo-root `AGENTS.md` to
  `core/root-AGENTS.md`. The repo-root `AGENTS.md` is now independent and contains only
  harness-template-specific rules. This prevents naming collisions when the harness bundle is
  installed into a project that already has its own `AGENTS.md`.
- Updated `INSTALL.md`, `README.md`, `changelogs/README.md`, and `changelogs/version-0.2.0.md` to
  reference `core/root-AGENTS.md` as the source of the installable template.
- Renamed the installed bundle directory from `turborepo-harness-template/` to
  `turborepo-agent-harness/` everywhere (docs, scripts, adapter configs). This aligns the bundle
  name with the upstream repo and the `/tah-*` command namespace.

### Upgrade Notes

- Copy the new `core/root-AGENTS.md` file into your installed `turborepo-agent-harness/` directory.
- Compare your project's root `AGENTS.md` against the fresh `core/root-AGENTS.md` template and merge
  any new rows/rules manually. The harness never auto-merges this file.
- If you have an existing install under `turborepo-harness-template/`, rename it to
  `turborepo-agent-harness/` and update any hard-coded paths in your git hooks, CI, or adapter
  configs.

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

[Unreleased]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.2
[0.4.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.1
[0.4.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.0
[0.3.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.3.0
[0.2.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.2
[0.2.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.1
[0.2.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0
[0.1.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0
