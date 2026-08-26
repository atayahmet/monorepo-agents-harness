---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /monorepo-harness:update (Claude Code) or /monorepo-harness-update (opencode/Codex CLI), or asks to check/update the harness, when a task touches .agents/monorepo-agents-harness/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/monorepo-harness:update` (Claude Code) and `/monorepo-harness-update` (opencode/Codex CLI) commands.

The version engine is `.agents/monorepo-agents-harness/core/scripts/harness-update.sh` (git + coreutils only; exit 0 = current, 1 = update available, 2 = unknown/unreachable). The script only performs version checks; it does **not** execute upgrades.

The actual upgrade is performed by you, the active agent, by reading the changelog prompts from the freshly downloaded bundle at `.agents/.harness-update-v<latest>/changelogs/version-X.Y.Z.md` (see step 2). The installed copy's `changelogs/` directory is removed at the end of every install and update (step 10) and must never be relied on as a prompt source.

Since 0.5.0 the upgrade also reconciles the project's root `AGENTS.md` against the new `core/root-AGENTS.md` (step 9) instead of leaving it as a recurring manual follow-up. That step has its own consent gate, separate from the "Upgrade now?" consent in step 6.

> **Installed layout (0.4.1+).** The bundle itself lives under `.agents/monorepo-agents-harness/`
> and is both the source of truth for upgrades and the runtime-facing directory. There is no
> separate root bundle or symlink tree. The version file is at
> `.agents/monorepo-agents-harness/VERSION`.

## Workflow

1. **Check** (from the repo root):
   ```bash
   bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check --json
   ```
   Parse `status`:
   - `current` → report "harness vX.Y.Z is up to date" and stop.
   - `unknown` (exit 2) → report network/upstream problem with the script's stderr message; suggest `git ls-remote --tags <upstream>` to diagnose; do not retry more than once.
   - `outdated` → continue below.

2. **Download the new bundle** into a temporary directory under `.agents/` (default):
   ```bash
   git clone --depth 1 --branch v<latest> https://github.com/atayahmet/monorepo-agents-harness \
     .agents/.harness-update-v<latest>
   ```
   (or use a directory the user already downloaded.)

3. **Select the changelog prompts** to apply.
    - Read `.agents/monorepo-agents-harness/VERSION` from the installed project to determine the current version (`installed`).
    - Read `.agents/.harness-update-v<latest>/core/VERSION` from the downloaded bundle to determine the target version (`latest`).
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
   - Determine the root `AGENTS.md` reconciliation mode using
     `core/skills/agents-md-merge/SKILL.md` Step 0 (reads only — do not clone a base tag or build a
     proposal yet). Record it for the report below.

5. **Report** the plan before asking anything:
   - Installed `<installed>` → available `<latest>`.
   - Number of files to copy, delete, and commands to run.
   - Root `AGENTS.md`: `<three-way merge from v<base> | adoption merge (no provenance marker) |
     already in sync | will be created>`.
   - Manual follow-ups verbatim.
   - Reference the relevant `CHANGELOG.md` Upgrade Notes if present.

6. **Ask consent**: "Upgrade now?" Consenting here authorizes the file copies, deletions, and
   commands in steps 7-8. It does **not** authorize writing `AGENTS.md` — that has its own approval
   gate in step 9.

7. **On consent, execute the plan**:
    - **Copy**: For each listed path, copy from `.agents/.harness-update-v<latest>/...` to `.agents/monorepo-agents-harness/...`. Directories ending in `/` are copied recursively and replace the target directory entirely.
    - **Delete**: Remove each listed path from `.agents/monorepo-agents-harness/...`. If the prompt says "(only if they exist)", skip silently when missing; otherwise treat a missing target as an error.
    - **Run**: Execute each command block from `.agents/monorepo-agents-harness/`. Stop if any command returns a non-zero exit code and report which command failed.
    - Do **not** execute `Manual follow-ups` automatically.

8. **Update the installed version file**:
    ```bash
    mkdir -p .agents/monorepo-agents-harness
    cp .agents/.harness-update-v<latest>/core/VERSION .agents/monorepo-agents-harness/VERSION
    ```

9. **Reconcile the root `AGENTS.md`.** Follow `core/skills/agents-md-merge/SKILL.md` end to end,
   with `NEW=.agents/.harness-update-v<latest>`.
   - Run it **before** step 10 — it reads the new template from the temporary clone, which step 10
     deletes. Never read the template from the installed
     `.agents/monorepo-agents-harness/core/root-AGENTS.md`: that copy has had its placeholders
     substituted at install time and is not a valid merge input.
   - The skill produces a fully resolved proposal and asks for approval on its own. Never write
     `AGENTS.md` without that approval. If the user declines, leave the file untouched, keep the
     proposal at `AGENTS.md.harness-proposed`, and carry it into step 11 as a follow-up — a decline
     does not fail the upgrade.
   - This step supersedes every historical "compare your `AGENTS.md` against the fresh
     `core/root-AGENTS.md` template and merge any new rows/rules manually" follow-up carried by the
     pre-0.5.0 changelog prompts (0.2.0, 0.2.2, 0.3.0, 0.4.0, 0.4.1). Collapse those into this one
     reconciliation and do not repeat them in the step 11 follow-up list.

10. **Clean up**:
    ```bash
    rm -rf .agents/.harness-update-v<latest> .agents/.harness-agents-md-merge \
           .agents/monorepo-agents-harness/changelogs
    ```
    Always remove the installed `changelogs/` directory too, unconditionally — it is never read from
    the installed copy (prompts always come from a fresh temporary clone, per step 2), so leaving it
    around after every install/update is pure accumulated clutter. Confirm
    `.agents/monorepo-agents-harness/changelogs/` no longer exists before continuing to step 11; if it
    still exists, delete it again — do not report the upgrade complete otherwise.

11. **Present manual follow-ups** and recommend a commit:
    ```
    chore(harness): upgrade to v<latest>
    ```
    If the `AGENTS.md` merge from step 9 was declined, list its proposal path and review command
    (`git diff --no-index AGENTS.md AGENTS.md.harness-proposed`) as the first follow-up.

## Edge cases

- **Pre-versioning install** (no `.agents/monorepo-agents-harness/VERSION` and no legacy `.agents/monorepo-agents-harness/core/VERSION`, exit status outdated with empty installed): treat as "very old install" — recommend following INSTALL.md §4 afresh instead of upgrading.
- **Installed newer than upstream** (dev build): report and stop; offer to downgrade to the published release only on explicit user request.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs when reporting an unreachable upstream.
- **Missing changelog prompt for a version in range**: stop and report that the upgrade cannot continue safely without a prompt for that version.
- **Ambiguous prompt**: if a section is missing or unclear, do not guess — report it to the user and ask how to proceed.
- **`AGENTS.md` has no provenance marker**: always run `agents-md-merge` in adoption mode — never guess which harness version the file might have come from.
- **`agents-md-merge`'s base tag is unreachable**: it falls back to adoption mode on its own and reports the downgrade; this is not an upgrade failure.
- **`AGENTS.md` merge declined**: not an upgrade failure — proceed through steps 10-11 and surface it as a follow-up.
