---
version: 0.4.0
from: 0.3.0
date: 2026-08-25
---

# Version 0.4.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.3.0 to 0.4.0.

This release renames the project from `turborepo-agent-harness` to
`monorepo-agents-harness`, replaces the Turborepo-specific skill with a generic
`monorepo` skill, and adds framework detection so the harness works with
Turborepo, Nx, Lerna, and npm/yarn/pnpm workspaces.

> **Breaking install change.** Existing installs must rename the bundle directory,
> recreate the shared runtime directory under the new name, and swap the
> `turborepo` skill symlink for the new `monorepo` skill symlink.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
the installed `monorepo-agents-harness/` directory. Directories ending in `/`
should be copied recursively and replace the existing directory entirely.

- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `changelogs/version-0.4.0.md` -> `changelogs/version-0.4.0.md`
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `core/scripts/detect-monorepo-framework.sh` -> `core/scripts/detect-monorepo-framework.sh`
- `core/scripts/harness-update.sh` -> `core/scripts/harness-update.sh`
- `core/scripts/scaffold-workspace-agents.sh` -> `core/scripts/scaffold-workspace-agents.sh`
- `core/scripts/memory-gate.sh` -> `core/scripts/memory-gate.sh`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`
- `core/skills/monorepo/SKILL.md` -> `core/skills/monorepo/SKILL.md`
- `INSTALL.md` -> `INSTALL.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `README.md` -> `README.md`
- `adapters/claude-code/` -> `adapters/claude-code/` (recursive directory copy)
- `adapters/opencode/` -> `adapters/opencode/` (recursive directory copy)
- `adapters/codex/` -> `adapters/codex/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

Remove the old Turborepo-specific skill directory from the bundle. Skip silently
if it is missing.

- `core/skills/turborepo/`

Do **not** delete adapter-specific files:

- `.claude/commands/tah-build.md`
- `.claude/commands/tah/update.md`
- `.opencode/commands/tah-build.md`
- `.opencode/commands/tah-update.md`
- `.codex/.agents/skills/tah-build/`
- `.codex/.agents/skills/tah-update/`

## Commands to run

Run these from the target repo root.

```bash
# 1. Rename the installed bundle directory.
mv turborepo-agent-harness monorepo-agents-harness

# 2. Create the new shared runtime directory.
mkdir -p .agents/monorepo-agents-harness

# 3. Relocate the version file.
cp monorepo-agents-harness/core/VERSION .agents/monorepo-agents-harness/VERSION

# 4. Symlink shared skills into the runtime directory.
mkdir -p .agents/monorepo-agents-harness/skills
ln -sf ../../../monorepo-agents-harness/core/skills/agent-workflow \
  .agents/monorepo-agents-harness/skills/agent-workflow
ln -sf ../../../monorepo-agents-harness/core/skills/harness-update \
  .agents/monorepo-agents-harness/skills/harness-update
ln -sf ../../../monorepo-agents-harness/core/skills/monorepo \
  .agents/monorepo-agents-harness/skills/monorepo

# 5. Symlink shared scripts into the runtime directory.
mkdir -p .agents/monorepo-agents-harness/scripts
ln -sf ../../../monorepo-agents-harness/core/scripts/memory-gate.sh \
  .agents/monorepo-agents-harness/scripts/memory-gate.sh
ln -sf ../../../monorepo-agents-harness/core/scripts/harness-update.sh \
  .agents/monorepo-agents-harness/scripts/harness-update.sh
ln -sf ../../../monorepo-agents-harness/core/scripts/scaffold-workspace-agents.sh \
  .agents/monorepo-agents-harness/scripts/scaffold-workspace-agents.sh
ln -sf ../../../monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh \
  .agents/monorepo-agents-harness/scripts/detect-monorepo-framework.sh

# 6. Symlink governance docs and workspace template into the runtime directory.
ln -sf ../../monorepo-agents-harness/core/governance \
  .agents/monorepo-agents-harness/governance
ln -sf ../../monorepo-agents-harness/core/workspace-agents-template \
  .agents/monorepo-agents-harness/workspace-agents-template
ln -sf ../../monorepo-agents-harness/core/root-AGENTS.md \
  .agents/monorepo-agents-harness/root-AGENTS.md

# 7. Re-link Claude Code skills to the shared runtime skills.
mkdir -p .claude/skills
rm -f .claude/skills/turborepo
ln -sf ../../.agents/monorepo-agents-harness/skills/agent-workflow .claude/skills/agent-workflow
ln -sf ../../.agents/monorepo-agents-harness/skills/monorepo .claude/skills/monorepo

# 8. Re-link Codex CLI skills to the shared runtime skills.
mkdir -p .agents/skills
rm -f .agents/skills/turborepo
ln -sf ../monorepo-agents-harness/skills/agent-workflow \
  .agents/skills/agent-workflow
ln -sf ../monorepo-agents-harness/skills/monorepo \
  .agents/skills/monorepo

# 9. Re-point the git pre-commit hook to the shared runtime script.
ln -sf ../../.agents/monorepo-agents-harness/scripts/memory-gate.sh .git/hooks/pre-commit
```

After running the commands, verify the links resolve:

```bash
ls -l .agents/monorepo-agents-harness/skills/
ls -l .claude/skills/ 2>/dev/null || true
ls -l .agents/skills/ 2>/dev/null || true
ls -l .git/hooks/pre-commit
bash .agents/monorepo-agents-harness/scripts/detect-monorepo-framework.sh
bash .agents/monorepo-agents-harness/scripts/harness-update.sh current
```

## Manual follow-ups for the user

The following steps touch user-owned configuration files. Present them to the
user after the automated commands complete.

- **Claude Code:** Update `.claude/settings.json` so that the `Stop` hook invokes
  `.agents/monorepo-agents-harness/scripts/memory-gate.sh` instead of
  `.agents/turborepo-agent-harness/scripts/memory-gate.sh`. If you used the bundled
  `adapters/claude-code/.claude/settings.json`, re-merge it with your current
  settings.
- **opencode:** Update the `instructions` array in your repo-root
  `opencode.jsonc` (or `opencode.json`) to point at the shared runtime skills:
  - `.agents/monorepo-agents-harness/skills/agent-workflow/SKILL.md`
  - `.agents/monorepo-agents-harness/skills/monorepo/SKILL.md`
  Remove any reference to `.agents/turborepo-agent-harness/skills/turborepo/SKILL.md`.
- **Codex CLI:** Update `.codex/hooks.json` so that the `Stop` hook invokes
  `.agents/monorepo-agents-harness/scripts/memory-gate.sh` instead of
  `.agents/turborepo-agent-harness/scripts/memory-gate.sh`. Re-merge the bundled
  `adapters/codex/.codex/hooks.json` if you customized yours.
- **CI / custom scripts:** If any of your own scripts or CI steps read
  `.agents/turborepo-agent-harness/VERSION` or `turborepo-agent-harness/core/VERSION`,
  change them to read `.agents/monorepo-agents-harness/VERSION`.
- **Root `AGENTS.md`:** Compare your project's root `AGENTS.md` against the
  bundled `core/root-AGENTS.md` template and merge any new rows/rules manually.
  In particular, fill the new `{{MONOREPO_FRAMEWORK}}` placeholder with the
  output of `detect-monorepo-framework.sh --framework`. The harness never
  auto-merges this file to avoid overwriting project-specific rules.

## Release summary

- Renamed the project and bundle directory from `turborepo-agent-harness` to
  `monorepo-agents-harness`.
- Introduced `core/scripts/detect-monorepo-framework.sh` to detect Turborepo,
  Nx, Lerna, and npm/yarn/pnpm workspaces.
- Replaced the `turborepo` skill with a generic `monorepo` skill that covers
  all supported frameworks.
- Updated `core/scripts/scaffold-workspace-agents.sh` and
  `core/scripts/memory-gate.sh` to discover workspaces based on the detected
  framework.
- Updated `core/root-AGENTS.md` to be framework-agnostic and include a
  `{{MONOREPO_FRAMEWORK}}` placeholder.
- Updated all adapter configs, adapter install guides, root install guide, and
  portability docs to reflect the new project name and the `monorepo` skill.
