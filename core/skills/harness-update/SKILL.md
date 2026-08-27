---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /monorepo-harness:update (Claude Code) or /monorepo-harness-update (opencode/Codex CLI), or asks to check/update the harness, when a task touches .agents/monorepo-agents-harness/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/monorepo-harness:update` (Claude Code) and `/monorepo-harness-update` (opencode/Codex CLI) commands.

The version engine is `.agents/monorepo-agents-harness/core/scripts/harness-update.sh` (git + coreutils only; exit 0 = current, 1 = update available, 2 = unknown/unreachable). The script only performs version checks; it does **not** execute upgrades.

The actual upgrade is performed by you, the active agent. Since 0.11.0, the bundle's `core/` and
`adapters/` trees are synced **wholesale** from the freshly downloaded clone (step 7) — not from an
itemized per-version file list — because a hand-maintained "Files to copy" list is structurally
prone to omissions (a new skill, script, or adapter command silently missing from a release's
list means it never reaches installed projects). Changelog prompts under
`.agents/.harness-update-v<latest>/changelogs/version-X.Y.Z.md` (see step 2) are still read in
order, but now only for their `Commands to run` and `Manual follow-ups` sections (and any rare
non-bundle `Files to copy`/`Files to delete` entries — see `changelogs/README.md`). The installed
copy's `changelogs/` directory is removed at the end of every install and update (step 10) and
must never be relied on as a prompt source.

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
   - The `core/` and `adapters/` sync itself is NOT built from these prompts — it's a fixed
     wholesale operation, see step 7.
   - From each selected prompt, extract:
     - `Commands to run`
     - `Manual follow-ups for the user`
     - `Release summary`
     - Any `Files to copy`/`Files to delete` entries that name paths **outside** `core/` and
       `adapters/` (rare — flag these explicitly if found, since the wholesale sync in step 7
       does not cover them).
   - Collect manual follow-ups to present at the end.
   - Determine which adapter(s) are already installed in the project (`.claude/` → claude-code,
     `.opencode/` → opencode, `.agents/skills/` → codex) — needed for step 7.5.
   - Determine the root `AGENTS.md` reconciliation mode using
     `core/skills/agents-md-merge/SKILL.md` Step 0 (reads only — do not clone a base tag or build a
     proposal yet). Record it for the report below.

5. **Report** the plan before asking anything:
   - Installed `<installed>` → available `<latest>`.
   - "Full `core/` and `adapters/` sync" (not an itemized count — see step 7), plus any
     out-of-tree `Files to copy`/`Files to delete` entries, and the number of commands to run.
   - Adapter(s) detected as installed (from step 4) that will be re-synced in step 7.5.
   - Root `AGENTS.md`: `<three-way merge from v<base> | adoption merge (no provenance marker) |
     already in sync | will be created>`.
   - Manual follow-ups verbatim.
   - Reference the relevant `CHANGELOG.md` Upgrade Notes if present.

6. **Ask consent**: "Upgrade now?" Consenting here authorizes the bundle sync, adapter re-install,
   and commands in steps 7-7.5. It does **not** authorize writing `AGENTS.md` — that has its own
   approval gate in step 9.

7. **On consent, sync the bundle**:
    - **Compute a per-run trash dir once** and reuse it through step 10 — this update never calls
      `rm -rf` on anything it's replacing; old copies are moved aside instead, so the flow keeps
      working even under a permission policy that blocks destructive commands outright:
      ```bash
      TRASH="$(git rev-parse --show-toplevel)/.agents/.harness-trash/$(date +%Y%m%d_%H%M%S)_$$"
      mkdir -p "$TRASH"
      ```
    - **Wholesale sync of `core/` and `adapters/`** (this is a full replace, not an itemized
      copy — see the skill intro for why):
      ```bash
      mv .agents/monorepo-agents-harness/core "$TRASH/core"
      cp -R .agents/.harness-update-v<latest>/core .agents/monorepo-agents-harness/core
      mv .agents/monorepo-agents-harness/adapters "$TRASH/adapters"
      cp -R .agents/.harness-update-v<latest>/adapters .agents/monorepo-agents-harness/adapters
      ```
    - **Verify** the sync deterministically (do not skip — this is the safety net if a copy is
      interrupted by a disk/permission error):
      ```bash
      bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh verify-copy \
        .agents/.harness-update-v<latest>/core .agents/monorepo-agents-harness/core
      bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh verify-copy \
        .agents/.harness-update-v<latest>/adapters .agents/monorepo-agents-harness/adapters
      ```
      A non-zero exit means the upgrade is incomplete — stop and report which files are missing;
      do not continue to step 7.5 or claim success.
    - **Out-of-tree copy/delete** (rare): apply any paths flagged in step 4 that live outside
      `core/`/`adapters/`.
    - **Run**: execute each `Commands to run` block from `.agents/monorepo-agents-harness/`. Stop
      if any command returns a non-zero exit code and report which command failed.
    - Do **not** execute `Manual follow-ups` automatically.

7.5. **Self-healing adapter re-install.** For every adapter detected as installed in step 4,
    re-apply its own `adapters/<agent>/INSTALL.md` **copy/symlink steps** (skills, update-check
    command, build command, verifier subagent, and every optional harness-plumbing command already
    present in the project — e.g. `monorepo-harness-ci`, `-review`, `-intent`) against the
    freshly-synced bundle from step 7. This is what actually gets newly-added entry-point files
    into an already-adapted project — do not skip it and do not demote it to a manual follow-up.
    - Only re-run steps that copy/symlink a fixed, known file (`cp`, `ln -s`) — these are
      idempotent (overwrite / recreate) and safe to run unconditionally.
    - **Do NOT re-run the `settings.json`/`hooks.json`/`opencode.jsonc` config-merge step** — it
      is not idempotent (re-running a `jq`-based append duplicates hook entries). Only touch that
      file if the adapter's own hook/config definitions changed in this release, and only via the
      normal `Manual follow-ups` list, reviewed by the user before writing.
    - If the project has a harness-plumbing command file the current adapter no longer ships
      (renamed/removed), report it as a follow-up — do not delete it silently.

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

9.5. **Audit before declaring success.** Steps 7, 7.5, and 9 are all agent-executed — do not trust
    that any of them completed just because no error surfaced. Run this *before* step 10 deletes the
    temporary clone it needs:
    ```bash
    bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh \
      --against .agents/.harness-update-v<latest>
    ```
    This independently compares the consumer project against the temporary clone: the bundle sync
    (delegates to `verify-copy`), every installed adapter's entry-point files (missing required
    ones, or present-but-stale ones), root `AGENTS.md`'s provenance freshness, and every workspace's
    scaffold seeds. Running it here (after step 9, not right after step 7.5) means it also confirms
    this update's own `AGENTS.md` reconciliation actually happened — not just pre-existing staleness.
    - **Bundle or entry-point gap**: fix with a plain re-`cp` from the path the audit printed, then
      re-run the audit once.
    - **`AGENTS.md` gap**: do **not** re-copy the file directly — that would destroy the user's
      customizations. Re-run step 9 (`agents-md-merge`) instead; if it was already declined on
      purpose, the `.harness-proposed` sibling makes this a non-issue in the first place.
    - **Workspace scaffold gap**: re-run `core/scripts/scaffold-workspace-agents.sh` (idempotent).
    - If a re-run still reports the same gap, **stop** — do not proceed to step 10 or report the
      upgrade complete.

10. **Clean up** — move aside, using the same `$TRASH` computed in step 7, never `rm -rf`:
    ```bash
    [ -e .agents/.harness-update-v<latest> ] && mv .agents/.harness-update-v<latest> "$TRASH/harness-update-clone"
    [ -e .agents/.harness-agents-md-merge ] && mv .agents/.harness-agents-md-merge "$TRASH/agents-md-merge-scratch"
    [ -e .agents/monorepo-agents-harness/changelogs ] && mv .agents/monorepo-agents-harness/changelogs "$TRASH/changelogs"
    ```
    Always move the installed `changelogs/` directory out too, unconditionally — it is never read
    from the installed copy (prompts always come from a fresh temporary clone, per step 2), so
    leaving it around after every install/update is pure accumulated clutter. Confirm
    `.agents/monorepo-agents-harness/changelogs/` no longer exists before continuing to step 11; if it
    still exists, move it again — do not report the upgrade complete otherwise. Actually purging
    `$TRASH` is the user's own call — see step 11.

11. **Present manual follow-ups** and recommend a commit:
    ```
    chore(harness): upgrade to v<latest>
    ```
    Summarize what step 7.5 re-installed per adapter (new files added, none if already current),
    and confirm step 9.5's audit reported clean.
    If the `AGENTS.md` merge from step 9 was declined, list its proposal path and review command
    (`git diff --no-index AGENTS.md AGENTS.md.harness-proposed`) as the first follow-up.
    Always mention: old copies from this update were moved (not deleted) to `.agents/.harness-trash/`;
    purging it is optional and entirely the user's call —
    `bash .agents/monorepo-agents-harness/core/scripts/cleanup-harness-trash.sh` (add `--list` to
    inspect first). Trash accumulates across runs until the user runs this themselves.

## Edge cases

- **`verify-copy` reports missing files (step 7)**: this means the sync itself failed partway
  (disk full, permission denied, interrupted clone) — it is not expected in normal operation
  since `core/` and `adapters/` are always synced wholesale. Stop, report the exact missing paths
  the command printed, and do not proceed to step 7.5 or update the version file (step 8).
- **No adapter detected in step 4** (`.claude/`, `.opencode/`, and `.agents/skills/` all absent):
  skip step 7.5 entirely — nothing to re-install yet; the user has not run Phase 2 (`INSTALL.md`
  §5) for any agent. `audit-install.sh` (step 9.5) naturally skips the same adapters — it detects
  them the identical way.
- **`audit-install.sh` reports a gap it can't self-explain** (rare — e.g. a genuinely new category
  of drift the script doesn't check for yet): do not guess a fix; report the exact output to the
  user and ask how to proceed, same discipline as an ambiguous changelog prompt below.

- **Pre-versioning install** (no `.agents/monorepo-agents-harness/VERSION` and no legacy `.agents/monorepo-agents-harness/core/VERSION`, exit status outdated with empty installed): treat as "very old install" — recommend following INSTALL.md §4 afresh instead of upgrading.
- **Installed newer than upstream** (dev build): report and stop; offer to downgrade to the published release only on explicit user request.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs when reporting an unreachable upstream.
- **Missing changelog prompt for a version in range**: stop and report that the upgrade cannot continue safely without a prompt for that version.
- **Ambiguous prompt**: if a section is missing or unclear, do not guess — report it to the user and ask how to proceed.
- **`AGENTS.md` has no provenance marker**: always run `agents-md-merge` in adoption mode — never guess which harness version the file might have come from.
- **`agents-md-merge`'s base tag is unreachable**: it falls back to adoption mode on its own and reports the downgrade; this is not an upgrade failure.
- **`AGENTS.md` merge declined**: not an upgrade failure — proceed through steps 10-11 and surface it as a follow-up.
