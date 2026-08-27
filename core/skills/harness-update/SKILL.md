---
name: harness-update
description: Check whether the installed agent harness is up to date and, with user consent, upgrade it. Use when the user invokes /monorepo-harness:update (Claude Code) or /monorepo-harness-update (opencode/Codex CLI), or asks to check/update the harness, when a task touches .agents/monorepo-agents-harness/** and a version mismatch matters, or before starting work after a known harness release.
---

# Harness Update Check

Shared instructions backing every adapter's `/monorepo-harness:update` (Claude Code) and `/monorepo-harness-update` (opencode/Codex CLI) commands.

The version engine is `.agents/monorepo-agents-harness/core/scripts/harness-update.sh` (git + coreutils only; exit 0 = current, 1 = update available, 2 = unknown/unreachable). The script only performs version checks; it does **not** execute upgrades.

The actual upgrade is performed by you, the active agent — but **you never copy files by hand**. You
run the same installer scripts a fresh install runs (`core/scripts/install-harness.sh --sync-only`
in step 7 and `core/scripts/install-adapter.sh --refresh` in step 7.5), driven by
`core/install-manifest.txt` and `adapters/<agent>/manifest.txt`. An update therefore cannot disagree
with an install about what a complete installation contains, and a hand-maintained per-release
"files to copy" list — structurally prone to omitting a new skill, script or adapter command — never
enters the picture. Changelog prompts under
`.agents/.harness-update-v<latest>/changelogs/version-X.Y.Z.md` (see step 2) are read in order for
their `Commands to run` and `Manual follow-ups` sections (and any rare `Files to copy`/`Files to
delete` entry naming a path neither manifest covers — see `changelogs/README.md`). Most releases ship
no prompt at all; that is normal, not a problem. Prompts are always read from the temporary clone —
an installed bundle has no `changelogs/` directory.

The upgrade also reconciles the project's root `AGENTS.md` against the new `core/root-AGENTS.md`
(step 9). That step has its own consent gate, separate from the "Upgrade now?" consent in step 6.

> **Installed layout.** The bundle lives under `.agents/monorepo-agents-harness/` and is both the
> source of truth for upgrades and the runtime-facing directory. The version file is at
> `.agents/monorepo-agents-harness/VERSION`. Versions follow SemVer precedence including
> prereleases, so `0.2.0-rc.1` is older than `0.2.0` — always compare via `harness-update.sh`, never
> with `sort -V`.

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
    - Read `.agents/.harness-update-v<latest>/VERSION` from the downloaded bundle to determine the target version (`latest`).
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
   - Determine which adapter(s) are already installed — an adapter counts as installed once any of
     its `adapters/<agent>/manifest.txt` `copy` rows exists in the project (the same test
     `audit-install.sh` applies). Needed for step 7.5.
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

7. **On consent, sync the bundle** by running the new bundle's own installer in sync mode. Do not
    hand-copy anything: this executes `core/install-manifest.txt`, moves every replaced path aside
    instead of deleting it, and verifies each row landed.
    ```bash
    bash .agents/.harness-update-v<latest>/core/scripts/install-harness.sh \
      --sync-only --from .agents/.harness-update-v<latest>
    ```
    - Run the script **from the new clone**, not from the installed bundle — it is the newer
      installer, and it is about to replace the older copy of itself.
    - A non-zero exit means the upgrade is incomplete: the script prints exactly which rows failed.
      Stop, report them, and do not continue to step 7.5 or claim success.
    - The installed `VERSION` is a manifest row, so this step also advances it — there is no
      separate version-stamping step any more.
    - **Out-of-tree copy/delete** (rare): apply any paths flagged in step 4 that the manifest does
      not cover.
    - **Run**: execute each `Commands to run` block from `.agents/monorepo-agents-harness/`. Stop
      if any command returns a non-zero exit code and report which command failed.
    - Do **not** execute `Manual follow-ups` automatically.

7.5. **Self-healing adapter re-install.** For every adapter detected as installed in step 4:
    ```bash
    bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <agent> --refresh
    ```
    This is what actually gets newly-added entry-point files (a new command, skill or subagent) into
    an already-adapted project — do not skip it and do not demote it to a manual follow-up.
    - `--refresh` re-applies only the manifest's `copy`/`link` rows, which are idempotent, and
      **skips every `merge`/`tmpl` config row** — re-running a config merge would duplicate hook
      entries. If a release actually changed an adapter's hook/config definitions, say so in the
      step 11 follow-ups and let the user apply it; never write their config file for them here.
    - A non-zero exit names the rows that could not be satisfied. Report them; do not claim success.
    - If the project has a harness-plumbing file the current adapter no longer ships
      (renamed/removed), report it as a follow-up — do not delete it silently.

8. **Confirm the installed version advanced** (step 7 already copied it as a manifest row):
    ```bash
    bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh current   # expect <latest>
    ```

9. **Reconcile the root `AGENTS.md`.** Follow `core/skills/agents-md-merge/SKILL.md` end to end,
   with `NEW=.agents/.harness-update-v<latest>`.
   - Run it **before** step 10 — it reads the new template from the temporary clone, which step 10
     moves aside. Never read the template from the installed
     `.agents/monorepo-agents-harness/core/root-AGENTS.md`: that is the *old* template, not the one
     you are upgrading to.
   - The skill produces a fully resolved proposal and asks for approval on its own. Never write
     `AGENTS.md` without that approval. If the user declines, leave the file untouched, keep the
     proposal at `AGENTS.md.harness-proposed`, and carry it into step 11 as a follow-up — a decline
     does not fail the upgrade.
   - This step *is* the `AGENTS.md` reconciliation. If a changelog prompt asks the user to "compare
     your `AGENTS.md` against the fresh template and merge manually", drop that follow-up — it is
     already done here, and repeating it in step 11 is noise.

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
    - **Bundle or entry-point gap**: re-run the owning installer (step 7's `--sync-only` for a
      bundle row, step 7.5's `--refresh` for an adapter row) rather than hand-copying, then re-run
      the audit once.
    - **`AGENTS.md` gap**: do **not** re-copy the file directly — that would destroy the user's
      customizations. Re-run step 9 (`agents-md-merge`) instead; if it was already declined on
      purpose, the `.harness-proposed` sibling makes this a non-issue in the first place.
    - **Workspace scaffold gap**: re-run `core/scripts/scaffold-workspace-agents.sh` (idempotent).
    - If a re-run still reports the same gap, **stop** — do not proceed to step 10 or report the
      upgrade complete.

10. **Clean up** — move aside, never `rm -rf`, so the flow keeps working under a permission policy
    that blocks destructive commands outright:
    ```bash
    TRASH="$(git rev-parse --show-toplevel)/.agents/.harness-trash/$(date +%Y%m%d_%H%M%S)_$$"
    mkdir -p "$TRASH"
    [ -e .agents/.harness-update-v<latest> ] && mv .agents/.harness-update-v<latest> "$TRASH/harness-update-clone"
    [ -e .agents/.harness-agents-md-merge ] && mv .agents/.harness-agents-md-merge "$TRASH/agents-md-merge-scratch"
    [ -e .agents/monorepo-agents-harness/changelogs ] && mv .agents/monorepo-agents-harness/changelogs "$TRASH/changelogs"
    ```
    `changelogs/` is not a `core/install-manifest.txt` row, so a current install has none — the
    third line only cleans up a directory an older install left behind. Prompts always come from a
    fresh temporary clone (step 2), never from the installed copy. Confirm
    `.agents/monorepo-agents-harness/changelogs/` no longer exists before continuing to step 11.
    Actually purging the trash is the user's own call — see step 11.

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

- **`install-harness.sh --sync-only` exits non-zero (step 7)**: the sync failed partway (disk full,
  permission denied, interrupted clone) — not expected in normal operation, since the whole bundle
  is synced from a manifest. Stop, report the exact rows the script printed, and do not proceed to
  step 7.5 or claim the version advanced.
- **The new bundle has no `core/scripts/install-harness.sh`**: it is not a bundle this workflow can
  install. Stop and report it; do not improvise a sync by hand.
- **No adapter detected in step 4** (no adapter's `copy` rows are present in the project): skip
  step 7.5 entirely — nothing to re-install yet; the user has not run Phase 2 (`INSTALL.md` §3) for
  any agent. `audit-install.sh` (step 9.5) skips the same adapters — it applies the identical test.
- **`audit-install.sh` reports a gap it can't self-explain** (rare — e.g. a genuinely new category
  of drift the script doesn't check for yet): do not guess a fix; report the exact output to the
  user and ask how to proceed, same discipline as an ambiguous changelog prompt below.

- **No `.agents/monorepo-agents-harness/VERSION`** (status outdated with an empty installed version): the install predates versioning or is damaged — recommend running `INSTALL.md` §2 afresh instead of upgrading (the installer is idempotent and moves the old bundle aside).
- **Installed newer than upstream** (dev build): report and stop; offer to downgrade to the published release only on explicit user request. Note that a prerelease ranks *below* its release, so an install at `0.2.0-rc.3` is correctly reported as outdated once `0.2.0` ships.
- **Dirty git tree**: warn that the upgrade will modify tracked files and suggest committing or stashing first, but proceed on confirmation.
- **Custom BUNDLE_DIR/HARNESS_UPSTREAM**: honor them if set in the environment; mention both knobs when reporting an unreachable upstream.
- **No changelog prompt for a version in range**: normal — that release needed no commands or follow-ups. Continue; the bundle sync is manifest-driven and does not depend on prompts.
- **Ambiguous prompt**: if a section is missing or unclear, do not guess — report it to the user and ask how to proceed.
- **`AGENTS.md` has no provenance marker**: always run `agents-md-merge` in adoption mode — never guess which harness version the file might have come from.
- **`agents-md-merge`'s base tag is unreachable**: it falls back to adoption mode on its own and reports the downgrade; this is not an upgrade failure.
- **`AGENTS.md` merge declined**: not an upgrade failure — proceed through steps 10-11 and surface it as a follow-up.
