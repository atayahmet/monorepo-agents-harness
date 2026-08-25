---
version: 0.3.0
from: 0.2.2
date: 2026-08-25
---

# Version 0.3.0 Upgrade Instructions

You are upgrading the turborepo-agent-harness from 0.2.2 to 0.3.0.

This release moves the runtime-facing shared harness files out of the bundle's
`core/` tree and into a single project-owned location under
`.agents/turborepo-agent-harness/`. From there, agent-specific directories receive
**symlinks** to the shared files instead of physical copies. The bundle
(`turborepo-agent-harness/`) remains the source of truth for upgrades, but the
installed project now references `.agents/turborepo-agent-harness/` for runtime
artifacts.

The `core/VERSION` file is also relocated to
`.agents/turborepo-agent-harness/VERSION`; the update engine and adapters read
the version from there from now on.

> **Breaking install change.** Existing installs must migrate their shared skill
> copies and version file. Agent-specific config files (`.claude/settings.json`,
> `opencode.jsonc`, `.codex/hooks.json`) keep their current merge, but their
> internal paths must point to the new shared location.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
the installed `turborepo-agent-harness/` directory. Directories ending in `/`
should be copied recursively and replace the existing directory entirely.

- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `changelogs/version-0.3.0.md` -> `changelogs/version-0.3.0.md`
- `core/root-AGENTS.md` -> `core/root-AGENTS.md`
- `core/scripts/harness-update.sh` -> `core/scripts/harness-update.sh`
- `core/scripts/scaffold-workspace-agents.sh` -> `core/scripts/scaffold-workspace-agents.sh`
- `core/scripts/memory-gate.sh` -> `core/scripts/memory-gate.sh`
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`
- `INSTALL.md` -> `INSTALL.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `adapters/claude-code/` -> `adapters/claude-code/` (recursive directory copy)
- `adapters/opencode/` -> `adapters/opencode/` (recursive directory copy)
- `adapters/codex/` -> `adapters/codex/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

Remove the old physical copies of the shared skills. They will be replaced by
symlinks in the commands below. Skip silently if any of these are missing.

- `.claude/skills/agent-workflow/`
- `.claude/skills/turborepo/`
- `.agents/skills/agent-workflow/` (Codex CLI)
- `.agents/skills/turborepo/` (Codex CLI)

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
# 1. Create the new shared runtime directory.
mkdir -p .agents/turborepo-agent-harness

# 2. Relocate the version file. This is the file the harness update engine reads.
cp turborepo-agent-harness/core/VERSION .agents/turborepo-agent-harness/VERSION

# 3. Symlink shared skills into the runtime directory.
#    The physical source stays inside the bundle; the runtime dir only holds links.
mkdir -p .agents/turborepo-agent-harness/skills
ln -sf ../../../turborepo-agent-harness/core/skills/agent-workflow \
  .agents/turborepo-agent-harness/skills/agent-workflow
ln -sf ../../../turborepo-agent-harness/core/skills/turborepo \
  .agents/turborepo-agent-harness/skills/turborepo
ln -sf ../../../turborepo-agent-harness/core/skills/harness-update \
  .agents/turborepo-agent-harness/skills/harness-update

# 4. Symlink shared scripts into the runtime directory.
mkdir -p .agents/turborepo-agent-harness/scripts
ln -sf ../../../turborepo-agent-harness/core/scripts/memory-gate.sh \
  .agents/turborepo-agent-harness/scripts/memory-gate.sh
ln -sf ../../../turborepo-agent-harness/core/scripts/harness-update.sh \
  .agents/turborepo-agent-harness/scripts/harness-update.sh
ln -sf ../../../turborepo-agent-harness/core/scripts/scaffold-workspace-agents.sh \
  .agents/turborepo-agent-harness/scripts/scaffold-workspace-agents.sh

# 5. Symlink governance docs and workspace template into the runtime directory.
ln -sf ../../turborepo-agent-harness/core/governance \
  .agents/turborepo-agent-harness/governance
ln -sf ../../turborepo-agent-harness/core/workspace-agents-template \
  .agents/turborepo-agent-harness/workspace-agents-template
ln -sf ../../turborepo-agent-harness/core/root-AGENTS.md \
  .agents/turborepo-agent-harness/root-AGENTS.md

# 6. Re-link Claude Code skills to the shared runtime skills.
mkdir -p .claude/skills
ln -sf ../../.agents/turborepo-agent-harness/skills/agent-workflow .claude/skills/agent-workflow
ln -sf ../../.agents/turborepo-agent-harness/skills/turborepo .claude/skills/turborepo

# 7. Re-link Codex CLI skills to the shared runtime skills.
mkdir -p .agents/skills
ln -sf ../turborepo-agent-harness/skills/agent-workflow \
  .agents/skills/agent-workflow
ln -sf ../turborepo-agent-harness/skills/turborepo \
  .agents/skills/turborepo

# 8. Re-point the git pre-commit hook to the shared runtime script.
ln -sf ../../.agents/turborepo-agent-harness/scripts/memory-gate.sh .git/hooks/pre-commit
```

After running the commands, verify the links resolve:

```bash
ls -l .agents/turborepo-agent-harness/skills/
ls -l .claude/skills/ 2>/dev/null || true
ls -l .agents/skills/ 2>/dev/null || true
ls -l .git/hooks/pre-commit
bash .agents/turborepo-agent-harness/scripts/harness-update.sh current
```

## Manual follow-ups for the user

The following steps touch user-owned configuration files. Present them to the
user after the automated commands complete.

- **Claude Code:** Update `.claude/settings.json` so that the `Stop` hook invokes
  `.agents/turborepo-agent-harness/scripts/memory-gate.sh` instead of
  `turborepo-agent-harness/core/scripts/memory-gate.sh`. If you used the bundled
  `adapters/claude-code/.claude/settings.json`, re-merge it with your current
  settings.
- **opencode:** Update the `instructions` array in your repo-root
  `opencode.jsonc` (or `opencode.json`) to point at the shared runtime skills:
  - `.agents/turborepo-agent-harness/skills/agent-workflow/SKILL.md`
  - `.agents/turborepo-agent-harness/skills/turborepo/SKILL.md`
- **Codex CLI:** Update `.codex/hooks.json` so that the `Stop` hook invokes
  `.agents/turborepo-agent-harness/scripts/memory-gate.sh` instead of
  `turborepo-agent-harness/core/scripts/memory-gate.sh`. Re-merge the bundled
  `adapters/codex/.codex/hooks.json` if you customized yours.
- **CI / custom scripts:** If any of your own scripts or CI steps read
  `turborepo-agent-harness/core/VERSION`, change them to read
  `.agents/turborepo-agent-harness/VERSION`.
- **Root `AGENTS.md`:** Compare your project's root `AGENTS.md` against the
  bundled `core/root-AGENTS.md` template and merge any new rows/rules manually.
  The harness never auto-merges this file to avoid overwriting project-specific
  rules.

## Release summary

- Introduced a shared runtime directory `.agents/turborepo-agent-harness/` that
  holds symlinks to the agent-neutral files inside the bundle.
- Shared skills (`agent-workflow`, `turborepo`, `harness-update`) are now
  symlinked from `.agents/turborepo-agent-harness/skills/` into each agent's
  skill directory instead of being copied.
- Shared scripts (`memory-gate.sh`, `harness-update.sh`,
  `scaffold-workspace-agents.sh`) are symlinked from
  `.agents/turborepo-agent-harness/scripts/`.
- `core/VERSION` is relocated to `.agents/turborepo-agent-harness/VERSION`. The
  update engine, update skill, and adapter configs now read the version from
  there.
- Updated all adapter configs, adapter install guides, root install guide, and
  portability docs to reflect the symlink-based install model.
