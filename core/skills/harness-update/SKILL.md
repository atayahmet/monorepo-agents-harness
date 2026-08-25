---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /tah:update (Claude Code) or /tah-update (opencode/Codex CLI), or asks to check/update the harness, when a task touches turborepo-agent-harness/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/tah:update` (Claude Code) and `/tah-update` (opencode/Codex CLI) commands.

The version engine is `.agents/turborepo-agent-harness/scripts/harness-update.sh` (git + coreutils only; exit 0 = current, 1 = update available, 2 = unknown/unreachable). The script only performs version checks; it does **not** execute upgrades.

The actual upgrade is performed by you, the active agent, by reading the changelog prompts in `turborepo-agent-harness/changelogs/version-X.Y.Z.md`.

> **Installed layout (0.3.0+).** The bundle (`turborepo-agent-harness/`) remains the source of
> truth for upgrades, but the runtime-facing shared files (skills, scripts, governance docs) live
> under `.agents/turborepo-agent-harness/` as symlinks into the bundle. The version file is at
> `.agents/turborepo-agent-harness/VERSION`.

## Workflow

1. **Check** (from the repo root):
   ```bash
   bash .agents/turborepo-agent-harness/scripts/harness-update.sh check --json
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
    - Read `.agents/turborepo-agent-harness/VERSION` from the installed project to determine the current version (`installed`).
    - Read `turborepo-agent-harness/core/VERSION` from the downloaded bundle to determine the target version (`latest`).
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
    - **Copy**: For each listed path, copy from `.harness-update-v<latest>/...` to `turborepo-agent-harness/...`. Directories ending in `/` are copied recursively and replace the target directory entirely.
    - **Delete**: Remove each listed path from `turborepo-agent-harness/...`. If the prompt says "(only if they exist)", skip silently when missing; otherwise treat a missing target as an error.
    - **Run**: Execute each command block from the installed bundle root. Stop if any command returns a non-zero exit code and report which command failed.
    - Do **not** execute `Manual follow-ups` automatically.

8. **Keep the shared runtime directory in sync** (0.3.0+). After copying files into the bundle, any prompt that creates or updates shared skills, scripts, governance docs, or the version file must also be reflected under `.agents/turborepo-agent-harness/`. Prefer updating the symlinks there rather than copying files; if a prompt asks you to copy a shared file, recreate the corresponding symlink so the runtime directory continues to point at the bundle source. The runtime directory should contain only symlinks, not physical copies of shared artifacts.

9. **Update the installed version file**:
    ```bash
    mkdir -p .agents/turborepo-agent-harness
    cp .harness-update-v<latest>/core/VERSION .agents/turborepo-agent-harness/VERSION
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

- **Pre-versioning install** (no `.agents/turborepo-agent-harness/VERSION` and no legacy `turborepo-agent-harness/core/VERSION`, exit status outdated with empty installed): treat as "very old install" — recommend following INSTALL.md §4 afresh instead of upgrading.
- **Installed newer than upstream** (dev build): report and stop; offer to downgrade to the published release only on explicit user request.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs when reporting an unreachable upstream.
- **Missing changelog prompt for a version in range**: stop and report that the upgrade cannot continue safely without a prompt for that version.
- **Ambiguous prompt**: if a section is missing or unclear, do not guess — report it to the user and ask how to proceed.
