---
version: 0.4.1
from: 0.4.0
date: 2026-08-25
---

# Version 0.4.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0 to 0.4.1.

This release moves the installed harness bundle from the repo root into
`.agents/monorepo-agents-harness/` and removes the separate runtime symlink tree.
The bundle directory itself is now both the source of truth for upgrades and the
runtime directory.

> **Breaking install change.** Existing installs must move the root
> `monorepo-agents-harness/` directory into `.agents/monorepo-agents-harness/`,
> remove any stale runtime symlinks, and update adapter configs to point at the
> new `core/scripts/` and `core/skills/` paths.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`. Directories ending in `/` should be copied
recursively and replace the existing directory entirely.

- `core/VERSION` -> `core/VERSION`
- `VERSION` -> `VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `changelogs/version-0.4.1.md` -> `changelogs/version-0.4.1.md`
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `core/scripts/detect-monorepo-framework.sh` -> `core/scripts/detect-monorepo-framework.sh`
- `core/scripts/harness-update.sh` -> `core/scripts/harness-update.sh`
- `core/scripts/scaffold-workspace-agents.sh` -> `core/scripts/scaffold-workspace-agents.sh`
- `core/scripts/memory-gate.sh` -> `core/scripts/memory-gate.sh`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`
- `core/skills/monorepo/SKILL.md` -> `core/skills/monorepo/SKILL.md`
- `core/skills/agent-workflow/SKILL.md` -> `core/skills/agent-workflow/SKILL.md`
- `INSTALL.md` -> `INSTALL.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `README.md` -> `README.md`
- `adapters/claude-code/` -> `adapters/claude-code/` (recursive directory copy)
- `adapters/opencode/` -> `adapters/opencode/` (recursive directory copy)
- `adapters/codex/` -> `adapters/codex/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

Remove the old runtime symlink directories from the pre-0.4.1 layout. Skip
silently if they are missing.

- `.agents/monorepo-agents-harness/skills/`
- `.agents/monorepo-agents-harness/scripts/`
- `.agents/monorepo-agents-harness/governance`
- `.agents/monorepo-agents-harness/workspace-agents-template`
- `.agents/monorepo-agents-harness/root-AGENTS.md` (if it is a symlink)
- Root `monorepo-agents-harness/` directory after it has been moved into `.agents/`

Do **not** delete adapter-specific files:

- `.claude/commands/tah-build.md`
- `.claude/commands/tah/update.md`
- `.opencode/commands/tah-build.md`
- `.opencode/commands/tah-update.md`
- `.agents/skills/tah-build/`
- `.agents/skills/tah-update/`

## Commands to run

Run these from the target repo root.

```bash
# 1. Move the root bundle into .agents/ (merge if a partial .agents/monorepo-agents-harness/ exists).
mv monorepo-agents-harness .agents/monorepo-agents-harness

# 2. Remove stale runtime symlinks from the old layout.
rm -f .agents/monorepo-agents-harness/skills
rm -f .agents/monorepo-agents-harness/scripts
rm -f .agents/monorepo-agents-harness/governance
rm -f .agents/monorepo-agents-harness/workspace-agents-template
rm -f .agents/monorepo-agents-harness/root-AGENTS.md

# 3. Ensure the version file is at the bundle root.
cp .agents/monorepo-agents-harness/core/VERSION .agents/monorepo-agents-harness/VERSION

# 4. Re-link Claude Code skills to the shared core skills.
mkdir -p .claude/skills
ln -sf ../../.agents/monorepo-agents-harness/core/skills/agent-workflow .claude/skills/agent-workflow
ln -sf ../../.agents/monorepo-agents-harness/core/skills/monorepo .claude/skills/monorepo

# 5. Re-link Codex CLI skills to the shared core skills.
mkdir -p .agents/skills
ln -sf ../.agents/monorepo-agents-harness/core/skills/agent-workflow .agents/skills/agent-workflow
ln -sf ../.agents/monorepo-agents-harness/core/skills/monorepo .agents/skills/monorepo

# 6. Re-point the git pre-commit hook to the core script.
ln -sf ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
```

After running the commands, verify the install:

```bash
ls -l .claude/skills/ 2>/dev/null || true
ls -l .agents/skills/ 2>/dev/null || true
ls -l .git/hooks/pre-commit
[ ! -d "monorepo-agents-harness" ] && echo "root bundle removed"
bash .agents/monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh
bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh current
```

## Manual follow-ups for the user

The following steps touch user-owned configuration files. Present them to the
user after the automated commands complete.

- **Claude Code:** Update `.claude/settings.json` so that the `Stop` hook invokes
  `.agents/monorepo-agents-harness/core/scripts/memory-gate.sh` instead of
  `.agents/monorepo-agents-harness/scripts/memory-gate.sh`. If you used the
  bundled `adapters/claude-code/.claude/settings.json`, re-merge it with your
  current settings.
- **opencode:** Update the `instructions` array in your repo-root
  `opencode.jsonc` (or `opencode.json`) to point at the core skills:
  - `.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md`
  - `.agents/monorepo-agents-harness/core/skills/monorepo/SKILL.md`
  Remove any reference to `.agents/monorepo-agents-harness/skills/...`.
- **Codex CLI:** Update `.codex/hooks.json` so that the `Stop` hook invokes
  `.agents/monorepo-agents-harness/core/scripts/memory-gate.sh` instead of
  `.agents/monorepo-agents-harness/scripts/memory-gate.sh`. Re-merge the bundled
  `adapters/codex/.codex/hooks.json` if you customized yours.
- **CI / custom scripts:** If any of your own scripts or CI steps read
  `.agents/monorepo-agents-harness/scripts/...`, change them to read
  `.agents/monorepo-agents-harness/core/scripts/...`.
- **Root `AGENTS.md`:** Compare your project's root `AGENTS.md` against the
  bundled `core/root-AGENTS.md` template and merge any new rows/rules manually.
  The harness never auto-merges this file to avoid overwriting project-specific
  rules.

## Release summary

- Moved the installed harness bundle from repo-root `monorepo-agents-harness/`
  to `.agents/monorepo-agents-harness/`.
- Removed the separate runtime symlink tree; the bundle directory is now both
  source and runtime.
- Updated `core/scripts/harness-update.sh` default bundle directory to
  `.agents/monorepo-agents-harness` and changed the upgrade workflow to clone
  temporary bundles under `.agents/` instead of the repo root.
- Updated `INSTALL.md`, `README.md`, `PORTABILITY.md`, all adapter configs,
  adapter install guides, and `core/root-AGENTS.md` to reference the new
  `.agents/monorepo-agents-harness/core/scripts/` and
  `.agents/monorepo-agents-harness/core/skills/` paths.
