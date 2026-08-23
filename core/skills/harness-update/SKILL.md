---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /tah:update (or asks to check/update the harness), when a task touches turborepo-harness-template/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/tah:update` command. The engine is
`turborepo-harness-template/core/scripts/harness-update.sh` (git + coreutils only; exit 0 = current,
1 = update available, 2 = unknown/unreachable). Report first; never upgrade without explicit consent.

## Workflow

1. **Check** (from the repo root):
   ```bash
   bash turborepo-harness-template/core/scripts/harness-update.sh check --json
   ```
   Parse `status`: `current` → report "harness vX.Y.Z is up to date" and stop.
   `unknown` (exit 2) → report network/upstream problem with the script's stderr message; suggest
   `git ls-remote --tags <upstream>` to diagnose; do not retry more than once.
   `outdated` → continue below.

2. **Report** what changed before asking anything:
   - Installed `<installed>` → available `<latest>`.
   - Read the installed bundle's `CHANGELOG.md` and summarize the sections between the two versions
     in ≤5 bullets, quoting the **Upgrade Notes** verbatim if present.

3. **Ask consent**: "Upgrade now?" — also confirm how to obtain the new bundle:
   - Clone from upstream at the new tag into a sibling directory (default):
     ```bash
     git clone --depth 1 --branch v<latest> https://github.com/atayahmet/turborepo-agent-harness \
       .harness-update-v<latest>
     ```
     (or the URL printed by the check's `upstream` field)
   - Or use a directory the user already downloaded.

4. **On consent, upgrade**:
   ```bash
   bash turborepo-harness-template/core/scripts/harness-update.sh upgrade --source .harness-update-v<latest>
   ```
   The command refreshes only the agent-neutral machinery (`core/scripts`, `core/skills`,
   `core/governance`, `core/workspace-agents-template`, `core/VERSION`, `CHANGELOG.md`) and re-runs
   the idempotent workspace scaffold. It never touches root `AGENTS.md`, `.agents/` working state,
   or adapter configs.

5. **Finish the follow-ups the script prints**:
   - Merge any new rows from the fresh `AGENTS.md` template into the repo-root `AGENTS.md`
     (user-owned file — manual merge, keep resolved values).
   - Adapter configs: claude-code → re-merge hook blocks per `adapters/claude-code/README.md`;
     opencode → re-copy the plugin file (verbatim) and merge `opencode.jsonc`.
   - Remove the temporary clone (`rm -rf .harness-update-v<latest>`).
   - Commit the upgrade as its own change (message like `chore(harness): upgrade to v<latest>`).

## Edge cases

- **Pre-versioning install** (no `core/VERSION`, exit status outdated with empty installed):
  treat as "very old install" — recommend following INSTALL.md §4 afresh instead of upgrading.
- **Installed newer than upstream** (dev build): report and stop; offer `upgrade --force` only on
  explicit request to downgrade to the published release.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or
  stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs
  when reporting an unreachable upstream.
