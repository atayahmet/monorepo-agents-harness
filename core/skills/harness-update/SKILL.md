---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /tah:update (Claude Code) or /tah-update (opencode/Codex CLI), or asks to check/update the harness, when a task touches turborepo-harness-template/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/tah:update` (Claude Code) and `/tah-update` (opencode/Codex CLI) commands.

The version engine is `turborepo-harness-template/core/scripts/harness-update.sh` (git + coreutils only; exit 0 = current, 1 = update available, 2 = unknown/unreachable). The script only performs version checks; it does **not** execute upgrades.

The actual upgrade is performed by you, the active agent, by reading the changelog prompts in `turborepo-harness-template/changelogs/version-X.Y.Z.md`.

## Workflow

1. **Check** (from the repo root):
   ```bash
   bash turborepo-harness-template/core/scripts/harness-update.sh check --json
   ```
   Parse `status`:
   - `current` → report "harness vX.Y.Z is up to date" and stop.
   - `unknown` (exit 2) → report network/upstream problem with the script's stderr message; suggest `git ls-remote --tags <upstream>` to diagnose; do not retry more than once.
   - `outdated` → continue below.

2. **Download the new bundle** into a sibling directory (default):
   ```bash
   git clone --depth 1 --branch v<latest> https://github.com/atayahmet/turborepo-agent-harness \
     .harness-update-v<latest>
   ```
   (or use a directory the user already downloaded.)

3. **Select the changelog prompts** to apply.
   - Read `core/VERSION` from the installed bundle to determine the current version (`installed`).
   - Read `core/VERSION` from the downloaded bundle to determine the target version (`latest`).
   - In the downloaded bundle, find every `changelogs/version-X.Y.Z.md` where `installed < X.Y.Z ≤ latest`.
   - Sort the selected prompts by version and read them in order.

4. **Build an upgrade plan** from the selected prompts.
   - Extract each prompt's standard sections:
     - `Files to copy from the new bundle to the installed bundle`
     - `Files to delete from the installed bundle`
     - `Commands to run`
     - `Manual follow-ups for the user`
     - `Release summary`
   - Translate copy/delete/run sections into concrete operations.
   - Collect manual follow-ups to present at the end.

5. **Report** the plan before asking anything:
   - Installed `<installed>` → available `<latest>`.
   - Number of files to copy, delete, and commands to run.
   - Manual follow-ups verbatim.
   - Reference the relevant `CHANGELOG.md` Upgrade Notes if present.

6. **Ask consent**: "Upgrade now?"

7. **On consent, execute the plan**:
   - **Copy**: For each listed path, copy from `.harness-update-v<latest>/...` to `turborepo-harness-template/...`. Directories ending in `/` are copied recursively and replace the target directory entirely.
   - **Delete**: Remove each listed path from `turborepo-harness-template/...`. If the prompt says "(only if they exist)", skip silently when missing; otherwise treat a missing target as an error.
   - **Run**: Execute each command block from the installed bundle root. Stop if any command returns a non-zero exit code and report which command failed.
   - Do **not** execute `Manual follow-ups` automatically.

8. **Update the installed version file**:
   ```bash
   cp .harness-update-v<latest>/core/VERSION turborepo-harness-template/core/VERSION
   ```

9. **Clean up** the temporary clone:
   ```bash
   rm -rf .harness-update-v<latest>
   ```

10. **Present manual follow-ups** and recommend a commit:
    ```
    chore(harness): upgrade to v<latest>
    ```

## Edge cases

- **Pre-versioning install** (no `core/VERSION`, exit status outdated with empty installed): treat as "very old install" — recommend following INSTALL.md §4 afresh instead of upgrading.
- **Installed newer than upstream** (dev build): report and stop; offer to downgrade to the published release only on explicit user request.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs when reporting an unreachable upstream.
- **Missing changelog prompt for a version in range**: stop and report that the upgrade cannot continue safely without a prompt for that version.
- **Ambiguous prompt**: if a section is missing or unclear, do not guess — report it to the user and ask how to proceed.
