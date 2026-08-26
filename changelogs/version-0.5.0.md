---
version: 0.5.0
from: 0.4.5
date: 2026-08-26
---

# Version 0.5.0 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.5 to 0.5.0.

This release retires the "the harness never auto-merges root `AGENTS.md` —
compare and merge it by hand" convention that has been repeated as a manual
follow-up in every prompt since 0.2.0. Install and update now plan a merge of
the project's root `AGENTS.md` against `core/root-AGENTS.md` and ask for
explicit approval before writing it. The new shared workflow is
`core/skills/agents-md-merge/SKILL.md`. There are no changes to
`core/root-AGENTS.md` itself, to the plan/spec artifact layout, or to the
update engine.

## Files to copy from the new bundle to the installed bundle

Copy the following from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`. Directories ending in `/` are copied
recursively and replace the target directory entirely.

- `core/VERSION` -> `core/VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `README.md` -> `README.md`
- `INSTALL.md` -> `INSTALL.md`
- `PORTABILITY.md` -> `PORTABILITY.md`
- `core/skills/agents-md-merge/` -> `core/skills/agents-md-merge/` (new directory)
- `core/skills/harness-update/SKILL.md` -> `core/skills/harness-update/SKILL.md`

## Files to delete from the installed bundle (only if they exist)

- None.

## Commands to run

None as a scripted block — but one **one-time step** is required before the
usual cleanup, and it will not happen on its own:

You began this upgrade under the pre-0.5.0 `harness-update` workflow, which
has no `AGENTS.md` reconciliation step. After copying the files above, read
`.agents/monorepo-agents-harness/core/skills/agents-md-merge/SKILL.md` and run
it once against this project's root `AGENTS.md`, using the temporary clone you
already have as the source of the new template
(`NEW=.agents/.harness-update-v0.5.0`).

Your `AGENTS.md` has no provenance marker yet, so this first run is an
**adoption merge**: additive only — nothing in your file is deleted, reordered
or reworded. Present the resolved proposal and the unified diff and ask
"Apply this merge to AGENTS.md?" before writing. If the user declines, leave
`AGENTS.md` untouched, keep the proposal at `AGENTS.md.harness-proposed`, and
report it as a follow-up — a decline is not an upgrade failure.

From the next upgrade onward this runs automatically as step 9 of
`core/skills/harness-update/SKILL.md`.

## Manual follow-ups for the user

- Approve or decline the `AGENTS.md` merge described above. Nothing is written
  without approval.
- This release **retires** the "compare your project's `AGENTS.md` against the
  fresh `core/root-AGENTS.md` and merge any new rows/rules manually" follow-up
  that earlier prompts (0.2.0, 0.2.2, 0.3.0, 0.4.0, 0.4.1) carried. If you are
  upgrading across those versions, do not repeat it — the reconciliation above
  replaces all of them.

## Release summary

- Added `core/skills/agents-md-merge/SKILL.md`: an additive adoption merge (no
  provenance marker) or a real three-way merge via `git merge-file --diff3`
  (with a provenance marker), always ending in a fully resolved proposal, a
  unified diff, and an explicit consent gate before `AGENTS.md` is written.
- Added a first-line provenance marker
  `<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->` recording the
  template version the file was last reconciled with.
- `INSTALL.md` §4 step 4, §6, §8, and §10 rewritten around the new flow;
  `core/skills/harness-update/SKILL.md` gained step 9 and renumbered its
  cleanup/follow-up steps.
- `core/root-AGENTS.md` content is unchanged.
