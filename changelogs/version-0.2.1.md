---
version: 0.2.1
from: 0.2.0
date: 2026-08-24
---

# Version 0.2.1 Upgrade Instructions

You are upgrading the turborepo-agent-harness from 0.2.0 to 0.2.1.

## Files to copy from the new bundle to the installed bundle

Copy the following files and directories from the newly downloaded bundle into
the installed `turborepo-harness-template/` directory. Directories ending in `/`
should be copied recursively and replace the existing directory entirely.

- `changelogs/version-0.2.1.md` -> `changelogs/version-0.2.1.md`
- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `INSTALL.md` -> `INSTALL.md`
- `adapters/opencode/` -> `adapters/opencode/` (recursive directory copy)

## Files to delete from the installed bundle (only if they exist)

The opencode adapter no longer ships a local plugin; memory-gate enforcement is
now provided solely by the universal hard gate (`core/scripts/memory-gate.sh`)
at git/CI. Remove the obsolete plugin file only if it exists; do not fail if it
is missing.

- `.opencode/plugins/agent-harness.ts`

If the `.opencode/plugins/` directory is empty after the deletion, you may
remove it as well.

## Commands to run

Verify that the universal hard gate is still executable and passes/fails as
expected. If you have not yet wired it as a git pre-commit hook or CI step, do
so now — it is the only memory-gate enforcement on opencode.

```bash
# confirm the hard gate is executable
chmod +x core/scripts/memory-gate.sh

# run a smoke test (create today's task dir, expect failure, add memory, expect pass)
TODAY="$(date +%Y_%m_%d)"
mkdir -p apps/web/.agents/artifacts/task_${TODAY}_smoke_test
bash core/scripts/memory-gate.sh; echo "exit=$?"
: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/2_spec.md
: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/3_memory.md
bash core/scripts/memory-gate.sh; echo "exit=$?"
rm -rf apps/web/.agents/artifacts/task_${TODAY}_smoke_test
```

## Manual follow-ups for the user

The following steps are intentionally not automated because they touch
user-owned configuration files. Present them to the user after the upgrade.

- If you previously merged the `opencode.jsonc` plugin comment into your
  repo-root `opencode.jsonc`, remove or update that comment so it no longer
  references `.opencode/plugins/agent-harness.ts`.
- Confirm that `core/scripts/memory-gate.sh` is installed as a git pre-commit
  hook or CI step. The plugin soft reminder is gone; the hard gate is now the
  only enforcement on opencode.
- Re-read `adapters/opencode/INSTALL.md` for the updated install steps (no
  plugin copy, only command files).

## Release summary

- Removed the opencode `agent-harness.ts` plugin.
- Memory-gate enforcement on opencode now relies entirely on the universal hard
  gate (`core/scripts/memory-gate.sh`) at git/CI, plus the existing
  `agent-workflow` skill instruction to write `3_memory.md` at task end.
- Updated `adapters/opencode/INSTALL.md`, `adapters/opencode/README.md`,
  `adapters/opencode/opencode.jsonc`, `PORTABILITY.md`, and `INSTALL.md` to
  reflect hard-gate-only enforcement.
