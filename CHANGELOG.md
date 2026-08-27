# Changelog

All notable changes to the agent harness are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

Every release MUST include an **Upgrade Notes** section describing anything an installed copy needs
to do beyond re-copying the bundle (behavior changes, artifact-layout changes, manual merges).

Release procedure (harness maintainers):

1. Update `core/VERSION` (SemVer: MAJOR = workflow/artifact-layout breakers, MINOR = new
   capabilities, PATCH = fixes/docs).
2. Add a `CHANGELOG.md` section with Upgrade Notes.
3. Commit and tag the upstream repo as `vX.Y.Z` (`git tag vX.Y.Z && git push --tags`).

## [Unreleased]

### Added

### Changed

### Removed

### Upgrade Notes

## [0.12.0] - 2026-08-27

### Added

- **`core/scripts/audit-install.sh`** — post-install/post-update reliability check. Compares the
  consumer project against the bundle source it was just built from (a fresh clone at update time,
  or the original install source): the `core`/`adapters` bundle sync (delegates to `verify-copy`),
  every installed adapter's entry-point files (missing required ones, or present-but-stale ones —
  a fixed short denylist excludes merged/templated config files), root `AGENTS.md`'s provenance
  freshness (skips a legitimately declined-and-tracked merge), and every workspace's scaffold
  seeds. `--json` mode included, matching `harness-update.sh check --json`'s shape. Read-only,
  git+coreutils only.
- New step **9.5** in `core/skills/harness-update/SKILL.md` — runs the audit after step 9's
  `AGENTS.md` reconciliation (so it also confirms *this* update's own reconciliation succeeded, not
  just pre-existing staleness) and before step 10 deletes the temporary clone it needs. Refuses to
  let the update report success while a gap remains; each gap type has its own correct fix (re-`cp`
  for bundle/entry-point files, re-running `agents-md-merge` for `AGENTS.md`, re-running
  `scaffold-workspace-agents.sh` for workspace seeds — never a blind overwrite).
- `INSTALL.md` §5 (Phase 2) now runs the same audit as the final confirmation step once both
  install phases are done.

### Upgrade Notes

- No artifact-layout or workflow-shape change. Purely additive verification — nothing before this
  release is touched or reinterpreted.

## [0.11.1] - 2026-08-27

### Changed

- **Repair release for an incomplete 0.11.0 upgrade.** `changelogs/version-0.11.0.md` — the
  transitional prompt still interpreted by the pre-0.11.0 update workflow — asked the agent to
  translate a "Files to copy" prose entry into an actual `rm -rf`+`cp -R` of `core/`/`adapters/`.
  Confirmed in practice: at least one real upgrade through that prompt applied it incompletely,
  leaving `core/root-REVIEW.md` missing from the installed bundle. `changelogs/version-0.11.1.md`
  replaces that prose entry with a self-locating, fully deterministic `Commands to run` bash block
  (finds its own temp clone directory, no version number for the agent to fill in) — nothing left
  to interpretation. Idempotent: safe to run even if your 0.11.0 install was actually complete.

### Upgrade Notes

- If you upgraded straight to 0.11.0, run `/monorepo-harness:update` once more (or apply
  `changelogs/version-0.11.1.md` directly) to repair any files that prompt's itemized copy step may
  have missed.

## [0.11.0] - 2026-08-26

### Added

- **`harness-update.sh verify-copy <src> <dst>`** — new deterministic subcommand that confirms
  every file under `<src>` exists under `<dst>`, printing any missing paths and exiting 1. Run
  automatically at the end of the bundle sync (see Changed) as a safety net against an
  interrupted `core/`/`adapters/` copy.

### Changed

- **Bundle updates are now wholesale, not itemized.** `core/skills/harness-update/SKILL.md` step 7
  replaces the installed `core/` and `adapters/` directories entirely from the freshly downloaded
  clone, instead of copying only the files a changelog prompt's "Files to copy" section happened
  to list. A hand-maintained per-release file list is structurally prone to omissions — this
  session's own `INSTALL.md` §3 bundle-contents tree went stale for two releases before being
  caught, and the equivalent gap in the actual copy list is exactly what caused new skills and
  adapter commands to silently never reach installed projects. `changelogs/version-X.Y.Z.md`
  prompts no longer need `Files to copy`/`Files to delete` sections for anything under `core/` or
  `adapters/`; those sections are now reserved for the rare path outside both trees (see
  `changelogs/README.md`'s 0.11.0+ note).
- **New adapter entry-point commands/skills are now installed automatically during an update.**
  `core/skills/harness-update/SKILL.md` step 7.5 detects which adapter(s) are already installed
  (`.claude/`, `.opencode/`, `.agents/skills/`) and re-applies that adapter's own `INSTALL.md`
  copy/symlink steps against the freshly-synced bundle. Previously these files (e.g. a new
  `/monorepo-harness-review` command) were only ever listed as a "Manual follow-up," which the
  update workflow explicitly never executes — this was the direct, confirmed cause of "new
  commands didn't get installed" reports. The one exception is each adapter's config-merge step
  (`.claude/settings.json`, `.codex/hooks.json`, `opencode.jsonc`), which is not idempotent and
  stays a manual follow-up.
- Filled in three previously-missing install steps: `adapters/{claude-code,opencode,codex}/INSTALL.md`
  now each list a copy step for `/monorepo-harness-ci`, `/monorepo-harness-review`, and
  `/monorepo-harness-intent` — confirmed absent from all three files before this release, meaning
  even a fresh install never picked them up.

### Upgrade Notes

- No artifact-layout or workflow-shape change. Existing `.agents/artifacts/` and `.agents/intents/`
  content is untouched.
- After this update, re-run your adapter's `INSTALL.md` "Optional harness-plumbing commands" step
  once by hand if you want any of `/monorepo-harness-ci`, `/monorepo-harness-review`, or
  `/monorepo-harness-intent` that you don't already have — from 0.11.0 onward, future releases of
  these will install automatically per the Changed section above.

## [0.10.0] - 2026-08-26

### Added

- **`/monorepo-harness-intent` — intent capture and review.** New per-workspace inbox
  `<workspace>/.agents/intents/` (`intent_<YYYY_MM_DD>_<slug>.md`, `status:
  pending|approved|rejected`) lets any stakeholder file a problem description before it's scoped
  into engineering work. New `core/skills/intent-workflow/SKILL.md` handles both Capture and
  Review; Review gates every status change behind an explicit **"Approve this intent?"** question,
  answered in the current turn — the same consent discipline as `agents-md-merge`'s "Apply this
  merge to AGENTS.md?" gate. Approved and rejected intents are both kept, never deleted.
- New governance templates `core/governance/intents/AGENTS.md` (full format + lifecycle rules) and
  `core/governance/intents/workspace-AGENTS.md` (per-workspace pointer, seeded by
  `scaffold-workspace-agents.sh`, which now also creates `<workspace>/.agents/intents/`).
- `core/skills/agent-workflow/SKILL.md` Phase 1 gained an optional, best-effort step: before
  writing `1_plan.md`, check for an approved intent matching the task; if found, copy it into the
  task directory as `0_intent.md` and reference it from the plan's `## Problem` section. This is
  *not* a mandatory search like the existing prior-art index check — most ad-hoc tasks have no
  intent behind them and skip it silently.
- New `/monorepo-harness-intent` entry point on all three adapters, following the same thin-pointer
  pattern as the other harness-plumbing commands.

### Changed

- `core/governance/artifacts/AGENTS.md`'s directory layout gains the optional `0_intent.md` line.
- `PORTABILITY.md` capability matrix gains an intent-capture row; `adapters/AGENTS.md` Hard Rule 6
  and its `agent-workflow` expectations section both reference the new optional artifact.

### Upgrade Notes

- Purely additive: no existing artifact, script, or hook changes behavior. Existing task
  directories without `0_intent.md` are unaffected — the field is optional and never retroactively
  required.
- Installs should re-run `core/scripts/scaffold-workspace-agents.sh` to seed
  `<workspace>/.agents/intents/AGENTS.md` for existing workspaces, and copy the new
  `monorepo-harness-intent` command/skill file for whichever adapter(s) they use (see the relevant
  `adapters/<agent>/INSTALL.md`).

## [0.9.0] - 2026-08-26

### Added

- **`/monorepo-harness-review` — PR review skill.** New `core/skills/pr-review/SKILL.md` reviews a
  diff (default `git diff <merge-base>...HEAD`) against `REVIEW.md` policy (or built-in defaults:
  bugs/security/spec-compliance passes, Important/Nit thresholds, 5-nit cap), and — when the diff
  maps to a task tracked under `.agents/artifacts/` — against that task's own
  `1_plan.md`/`2_spec.md`/`4_verify.md`, catching scope creep and unmet acceptance criteria that a
  generic review bot has no way to know about.
- New optional installable template `core/root-REVIEW.md` (copied to a target repo's root as
  `REVIEW.md`, same model as `core/root-AGENTS.md`), with a new `{{PROJECT_REVIEW_POLICY}}`
  placeholder.
- New `/monorepo-harness-review` entry point on all three adapters, following the same thin-pointer
  pattern as `/monorepo-harness-build`/`-update`/`-ci`.

### Changed

- `PORTABILITY.md` capability matrix gains a PR-review row and a semantic-differences note: this
  skill only ever produces a report, on every agent — it never posts to a PR platform, tags
  comments, or merges/approves anything (deliberately out of scope, see the skill's own "Out of
  scope" section).
- `adapters/AGENTS.md` Hard Rule 6 now lists the PR review trigger among harness-plumbing commands.

### Upgrade Notes

- Purely additive: no existing script, hook, or artifact changes behavior.
  `/monorepo-harness-review` never writes any file — it only reads and reports.
- Installs should copy the new `core/root-REVIEW.md` (optional), `core/skills/pr-review/SKILL.md`,
  and each adapter's new `monorepo-harness-review` command/skill file (see the relevant
  `adapters/<agent>/INSTALL.md`).

## [0.8.0] - 2026-08-26

### Added

- **`/monorepo-harness-ci` — CI provider detection + integration.** New
  `core/scripts/detect-ci-provider.sh` detects GitHub Actions, GitLab, Bitbucket Pipelines, or
  CircleCI (or reports `unknown`). New `core/skills/ci-integration/SKILL.md` wires
  `core/scripts/memory-gate.sh` into it, tiered by what each format actually supports: GitHub
  Actions gets a new, dedicated `.github/workflows/harness-memory-gate.yml` written after explicit
  consent (never overwriting an existing one); GitLab/Bitbucket/CircleCI — which each read exactly
  one pipeline file — get a matching snippet and paste-location guidance instead of an automatic
  edit to that file; an undetected provider gets an opt-in GitHub Actions starter offer.
- New `/monorepo-harness-ci` entry point on all three adapters (`.claude/commands/`,
  `.opencode/commands/`, and a Codex skill), following the exact thin-pointer pattern already used
  by `/monorepo-harness-build` and the update-check commands.

### Changed

- `PORTABILITY.md` capability matrix gains a CI-integration row and a "semantic differences" note
  explaining the GitHub-Actions-vs-others tiering (a CI-format constraint, not an agent difference).
- `adapters/AGENTS.md` Hard Rule 6 now lists the CI integration trigger among harness-plumbing
  commands.

### Upgrade Notes

- Purely additive: no existing script, hook, or artifact changes behavior. `/monorepo-harness-ci`
  only ever writes a file on the GitHub Actions path, and only after explicit consent in the same
  turn — running it is always safe to try.
- Installs should copy the new `core/scripts/detect-ci-provider.sh`,
  `core/skills/ci-integration/SKILL.md`, and each adapter's new `monorepo-harness-ci` command/skill
  file (see the relevant `adapters/<agent>/INSTALL.md`).

## [0.7.0] - 2026-08-26

### Added

- **`4_verify.md` — Feedback Loop enforcement.** `core/skills/agent-workflow/SKILL.md` gained
  Phase 4: after implementation, whenever `2_spec.md`'s "Test / verification plan" section is not
  `N/A`, the task directory must also contain `4_verify.md` — the actual verification run (commands
  executed, real output, per-acceptance-criterion pass/fail), not a narrative claim.
  `core/scripts/memory-gate.sh` now enforces this in both modes: default (git pre-commit/CI) and
  `--json` (Claude Code `Stop` hook), the latter previously only checking `3_memory.md`.
- **`verifier` subagent (Claude Code).** `adapters/claude-code/.claude/agents/verifier.md` — a
  read-only subagent that runs a task's verification commands and reports pass/fail evidence,
  without editing any files. opencode/codex have no subagent primitive; per the mandatory-parity
  rule, they run the same verification instructions inline in the main session instead (documented
  in `PORTABILITY.md`'s new capability-matrix row and "semantic differences" section) — no
  capability is lost, only the isolated-context delivery mechanism differs.
- **`2_spec.md` gained `## Data model` and `## Test / verification plan` sections** (implemented
  previously, formally released here): Data model records fields/types/structure of any persisted
  or transmitted data the task reads or writes (`N/A` if none); Test / verification plan states how
  each acceptance criterion is checked. `## Architectural constraints` wording was also expanded to
  explicitly cover non-functional requirements (performance, security, compatibility).

### Changed

- `core/governance/artifacts/AGENTS.md`, `core/root-AGENTS.md`, top-level `AGENTS.md`, and every
  adapter's `INSTALL.md`/`README.md` now document the plan/spec/memory/**verify** quad instead of
  the plan/spec/memory triad, including updated smoke-test commands.

### Upgrade Notes

- Purely additive: existing task directories without `4_verify.md` are never retroactively gated —
  the memory-gate only ever inspects **today's** task dir. New tasks whose spec has a non-`N/A`
  verification plan need `4_verify.md` going forward.
- Claude Code installs should copy the new `adapters/claude-code/.claude/agents/verifier.md` file
  into `.claude/agents/` (see `adapters/claude-code/INSTALL.md` step 7). opencode/codex need no new
  files for this release.
- No breaking change to `memory-gate.sh`'s CLI (flags, exit codes, JSON shape) — only the set of
  files it checks grew.

## [0.6.0] - 2026-08-26

### Added

- **Mandatory pre-plan artifact-index search.** `core/skills/agent-workflow/SKILL.md` Phase 1 now
  requires grepping the target workspace's `<workspace>/.agents/artifacts/index.md` for prior art
  (1–3 keywords derived from the task) before `1_plan.md` is written, reading the matched
  `2_spec.md` (and `3_memory.md` if ◆-marked) when a hit is found. The `1_plan.md` template gained a
  required `## Related prior work` section (cite a match, or state `- none found`) so the search is
  visible and greppable rather than silent.
- `core/root-AGENTS.md`'s "Before You Start" checklist and "Agent Lifecycle" step 1 ("Load
  Context") now reference the workspace artifact index alongside `session-log.md`/`lessons.md`.
- `core/governance/artifacts/AGENTS.md` cross-references the new mandatory search timing, so the
  index-format doc and the workflow-timing doc stay in sync.

### Upgrade Notes

- Purely additive to instructions/templates — no artifact-layout change, no script/hook change.
  Existing `1_plan.md` files without a `## Related prior work` section remain valid; only new plans
  written after upgrading need the section.

## [0.5.0] - 2026-08-26

### Added

- **`core/skills/agents-md-merge/SKILL.md`** — a shared, agent-executed workflow that reconciles a
  project's root `AGENTS.md` with the harness template `core/root-AGENTS.md`. Two modes: an additive
  **adoption merge** for files with no provenance marker (keeps 100% of existing content, weaves in
  only the missing harness rules, surfaces genuine section-level conflicts instead of overwriting),
  and a real **three-way merge** via `git merge-file --diff3` against the template version recorded
  in the file's provenance marker. Both modes end with a fully resolved, conflict-marker-free
  proposal, a unified diff, and an explicit `Apply this merge to AGENTS.md?` consent gate.
- **Provenance marker on the installed `AGENTS.md`** —
  `<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->` as the file's first line, written
  whenever the harness creates or merges the file. It records the template version the file was last
  reconciled with, which becomes the three-way-merge base for the next upgrade. Invisible in
  rendered Markdown; a file with no marker always takes the safe adoption-merge path.

### Changed

- **`INSTALL.md` §4 step 4 no longer says "merge by hand if one exists".** Install now branches: no
  root `AGENTS.md` → copy the template and stamp the marker; an existing root `AGENTS.md` → run the
  new `agents-md-merge` skill, which proposes an additive merge and asks for approval before writing
  anything.
- **`core/skills/harness-update/SKILL.md` gained step 9, "Reconcile the root `AGENTS.md`"** (old
  steps 9 and 10 become 10 and 11). The upgrade now proposes an `AGENTS.md` merge with its own
  consent gate, separate from the "Upgrade now?" gate. Step 4 detects the reconciliation mode, step 5
  reports it, step 10 cleans up the merge temp dir, and step 11 reports a declined merge as a
  follow-up. Step 9 explicitly **supersedes** the recurring "compare your `AGENTS.md` against the
  fresh template and merge manually" follow-up carried by the 0.2.0–0.4.1 changelog prompts, which
  are left unmodified as historical record.
- `INSTALL.md` §10 no longer lists root `AGENTS.md` under what the upgrade "never touches"; it now
  documents the consent-gated three-way merge. §8 Verification asserts the provenance marker exists
  and that no conflict markers were left in `AGENTS.md`. §3's bundle tree lists the new skill.
- `changelogs/README.md` documents that prompts from 0.5.0 onward should not restate the `AGENTS.md`
  merge as a manual follow-up, since the update workflow now performs it itself.

### Upgrade Notes

- Follow `changelogs/version-0.5.0.md`. Key step: after copying the new files, run the new
  `core/skills/agents-md-merge/SKILL.md` once, explicitly — because you started this upgrade under
  the pre-0.5.0 workflow, its new step 9 does not fire on its own for this one upgrade.
- Your first reconciliation runs in **adoption mode** (additive only) because no install created
  before 0.5.0 has a provenance marker. Approving it stamps the marker; every later upgrade then
  uses a real three-way merge.
- Declining writes nothing: the proposal is left at `AGENTS.md.harness-proposed`, the marker is not
  advanced, and the next upgrade re-offers the merge from the same base.
- `core/root-AGENTS.md`'s content is unchanged in this release, so for an install already at 0.4.5
  the merge should be a no-op beyond the marker line.

## [0.4.5] - 2026-08-26

### Changed

- **Made the 0.4.4 `changelogs/` deletion atomic and self-healing.** Confirmed on a real install
  that the previous two-line form (`cp -R ...` then a separate `rm -rf ... changelogs`) could run
  partially — the copy happened but the delete did not — leaving the installed `changelogs/`
  directory in place. `INSTALL.md` step 1 now chains both commands with `&&` so they run as one
  unit, and `core/skills/harness-update/SKILL.md` step 9 now passes both cleanup paths to a single
  `rm -rf` call.
- Added a self-healing check to `INSTALL.md` §8 Verification: it now asserts the installed
  `changelogs/` directory does not exist and removes it if it does, so anyone following the
  mandatory verify step catches and fixes a partial install before committing.
- `core/skills/harness-update/SKILL.md` step 9 now states explicitly that the agent must confirm
  `changelogs/` no longer exists before reporting the upgrade complete, rather than treating the
  `rm -rf` as fire-and-forget.

### Upgrade Notes

- Follow `changelogs/version-0.4.5.md` to migrate existing installs. Key step: delete the installed
  `changelogs/` directory again — if your install already applied 0.4.4, the directory may still be
  sitting there due to the partial-run gap this release fixes.

## [0.4.4] - 2026-08-26

### Changed

- **Install and update now always delete the installed `changelogs/` directory as their final
  step.** `.agents/monorepo-agents-harness/changelogs/` was never actually read from the installed
  copy — every upgrade prompt is sourced from a freshly cloned temporary bundle — so the directory
  was pure accumulated clutter that grew by one file per applied release. `INSTALL.md` §4 step 1 now
  runs `rm -rf .agents/monorepo-agents-harness/changelogs` right after the initial bundle copy, and
  `core/skills/harness-update/SKILL.md` step 9 now removes it unconditionally alongside the
  temporary clone at the end of every update.
- Fixed a doc inconsistency in `core/skills/harness-update/SKILL.md`: the intro previously implied
  prompts are read from the *installed* `changelogs/` directory; corrected it to point at the
  freshly downloaded temporary bundle, matching the actual selection logic in step 3.
- Documented in `changelogs/README.md` that prompts released from 0.4.4 onward should not list
  their own `changelogs/version-X.Y.Z.md` under "Files to copy" — it would just be deleted by the
  new cleanup step. Prompts released before 0.4.4 keep their existing self-copy line as historical
  record.

### Upgrade Notes

- Follow `changelogs/version-0.4.4.md` to migrate existing installs. Key step: delete the
  accumulated `.agents/monorepo-agents-harness/changelogs/` directory (it may hold several
  historical prompt files by now) — this is the actual behavior change, applied retroactively.

## [0.4.3] - 2026-08-26

### Changed

- **Renamed the harness-plumbing command/skill namespace from `/tah-*` to `/monorepo-harness-*`**
  across all three adapters: `/tah-build` → `/monorepo-harness-build`, `/tah:update`
  (claude-code) → `/monorepo-harness:update`, and `/tah-update` (opencode/Codex CLI) →
  `/monorepo-harness-update`. Renamed the backing files accordingly:
  `.claude/commands/tah-build.md` → `.claude/commands/monorepo-harness-build.md`,
  `.claude/commands/tah/update.md` → `.claude/commands/monorepo-harness/update.md`,
  `.opencode/commands/tah-build.md` → `.opencode/commands/monorepo-harness-build.md`,
  `.opencode/commands/tah-update.md` → `.opencode/commands/monorepo-harness-update.md`,
  `.agents/skills/tah-build/` → `.agents/skills/monorepo-harness-build/`, and
  `.agents/skills/tah-update/` → `.agents/skills/monorepo-harness-update/`. Updated
  `README.md`, `INSTALL.md`, `PORTABILITY.md`, every adapter `README.md`/`INSTALL.md`, and
  `core/skills/agent-workflow/SKILL.md` / `core/skills/harness-update/SKILL.md` to match. The old
  `tah-*` prefix was a leftover from the project's pre-0.4.0 name (`turborepo-agent-harness`);
  this finishes aligning the command namespace with the current project name,
  `monorepo-agents-harness`.

### Upgrade Notes

- Follow `changelogs/version-0.4.3.md` to migrate existing installs. Key steps:
  - Delete the old `tah-*` command/skill files and copy the renamed `monorepo-harness-*` ones
    from the new bundle (see the file list in `changelogs/version-0.4.3.md`).
  - Start typing the new command names: `/monorepo-harness-build`, `/monorepo-harness:update`
    (claude-code), `/monorepo-harness-update` (opencode/Codex CLI).

## [0.4.2] - 2026-08-25

### Changed

- Pointed the repository origin remote and all historic release links in `CHANGELOG.md` to the
  renamed `monorepo-agents-harness` GitHub repository (`https://github.com/atayahmet/monorepo-agents-harness`).

### Upgrade Notes

- No action required for installed copies. If you override `HARNESS_UPSTREAM`, ensure it still
  resolves to the correct repository.

## [0.4.1] - 2026-08-25

### Changed

- **Installed harness location is now `.agents/monorepo-agents-harness/` only.** The bundle is no
  longer copied to the repo root as `monorepo-agents-harness/`. The runtime symlink tree under
  `.agents/monorepo-agents-harness/` is removed; the bundle directory itself serves as both source
  and runtime.

### Fixed

- Prevented the installer and upgrader from leaving `monorepo-agents-harness/` or
  `.harness-update-*` directories at the repo root. Temporary upgrade clones now go under `.agents/`.

### Upgrade Notes

- Follow `changelogs/version-0.4.1.md` to migrate existing installs. Key steps:
  - Move the root `monorepo-agents-harness/` directory into `.agents/monorepo-agents-harness/`.
  - Remove any stale runtime symlink tree (e.g. `.agents/monorepo-agents-harness/skills/`,
    `.agents/monorepo-agents-harness/scripts/`, `.agents/monorepo-agents-harness/governance/`,
    `.agents/monorepo-agents-harness/workspace-agents-template/`) — the bundle now lives directly
    under `.agents/monorepo-agents-harness/`.
  - Update adapter configs (`.claude/settings.json`, `opencode.jsonc`, `.codex/hooks.json`) and
    skill/command files to point at `.agents/monorepo-agents-harness/core/scripts/` and
    `.agents/monorepo-agents-harness/core/skills/`.
  - Re-link `.git/hooks/pre-commit` to
    `.agents/monorepo-agents-harness/core/scripts/memory-gate.sh`.

## [0.4.0] - 2026-08-25

### Added

- New `core/scripts/detect-monorepo-framework.sh` that detects the target repo's monorepo
  framework from repo markers (`turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml`,
  `package.json` `workspaces`).
- Generic `core/skills/monorepo/SKILL.md` covering framework-agnostic monorepo principles and
  Turborepo, Nx, Lerna, and npm/yarn/pnpm workspaces.

### Changed

- **Renamed the project from `turborepo-agent-harness` to `monorepo-agents-harness`.** Every
  reference to the bundle directory, runtime directory, upstream URL, docs, scripts, and adapter
  configs now uses the new name.
- **Replaced the Turborepo-specific skill with a generic monorepo skill.** The old
  `core/skills/turborepo/` directory is removed; its guidance is folded into
  `core/skills/monorepo/SKILL.md`.
- `core/scripts/scaffold-workspace-agents.sh` and `core/scripts/memory-gate.sh` now use the
  framework detector to discover workspace directories (`apps/`, `packages/`, `libs/`, or custom
  workspace globs from `lerna.json` / `pnpm-workspace.yaml` / `package.json`).
- `core/root-AGENTS.md` is now framework-agnostic and includes a `{{MONOREPO_FRAMEWORK}}`
  placeholder that is filled at install time from the detector output.

### Removed

- `core/skills/turborepo/` and all its reference files.

### Upgrade Notes

- Follow `changelogs/version-0.4.0.md` to migrate existing installs. Key steps:
  - Rename the installed bundle directory from `turborepo-agent-harness/` to
    `monorepo-agents-harness/`.
  - Update `.agents/turborepo-agent-harness/` to `.agents/monorepo-agents-harness/` and re-create
    the runtime symlinks (including the new `monorepo` skill and
    `detect-monorepo-framework.sh`).
  - Update `.claude/settings.json`, `opencode.jsonc`, and `.codex/hooks.json` to point at the new
    `.agents/monorepo-agents-harness/` paths.
  - Replace `.claude/skills/turborepo` and `.agents/skills/turborepo` symlinks with `monorepo`.
  - Fill `{{MONOREPO_FRAMEWORK}}` in your project's root `AGENTS.md`.
  - Re-link `.git/hooks/pre-commit` to `.agents/monorepo-agents-harness/scripts/memory-gate.sh`.

## [0.3.0] - 2026-08-25

### Changed

- Relocated the installed harness runtime from inside the bundle's `core/` tree to a shared
  project-owned directory at `.agents/turborepo-agent-harness/`. The shared skills
  (`agent-workflow`, `turborepo`, `harness-update`) and scripts (`memory-gate.sh`,
  `harness-update.sh`, `scaffold-workspace-agents.sh`) now live there as symlinks to the bundle
  source, so multiple agents no longer need separate physical copies.
- Moved `core/VERSION` to `.agents/turborepo-agent-harness/VERSION`. The update engine and all
  adapter configs now read the installed version from this new location.
- Updated every adapter install guide to create symlinks instead of copying shared skills, and
  updated adapter configs to reference the shared runtime paths.

### Upgrade Notes

- Follow `changelogs/version-0.3.0.md` to migrate existing installs. Key steps:
  - Create `.agents/turborepo-agent-harness/` and move the version file there.
  - Replace physical copies of shared skills with symlinks into the new runtime directory.
  - Update `.claude/settings.json`, `opencode.jsonc`, and `.codex/hooks.json` to point at the new
    `.agents/turborepo-agent-harness/` paths.
  - Re-link `.git/hooks/pre-commit` to `.agents/turborepo-agent-harness/scripts/memory-gate.sh`.

## [0.2.2] - 2026-08-25

### Changed

- Moved the installable root agent-guidelines template from repo-root `AGENTS.md` to
  `core/root-AGENTS.md`. The repo-root `AGENTS.md` is now independent and contains only
  harness-template-specific rules. This prevents naming collisions when the harness bundle is
  installed into a project that already has its own `AGENTS.md`.
- Updated `INSTALL.md`, `README.md`, `changelogs/README.md`, and `changelogs/version-0.2.0.md` to
  reference `core/root-AGENTS.md` as the source of the installable template.
- Renamed the installed bundle directory from `turborepo-harness-template/` to
  `turborepo-agent-harness/` everywhere (docs, scripts, adapter configs). This aligns the bundle
  name with the upstream repo and the `/tah-*` command namespace.

### Upgrade Notes

- Copy the new `core/root-AGENTS.md` file into your installed `turborepo-agent-harness/` directory.
- Compare your project's root `AGENTS.md` against the fresh `core/root-AGENTS.md` template and merge
  any new rows/rules manually. The harness never auto-merges this file.
- If you have an existing install under `turborepo-harness-template/`, rename it to
  `turborepo-agent-harness/` and update any hard-coded paths in your git hooks, CI, or adapter
  configs.

## [0.2.1] - 2026-08-24

### Changed

- opencode adapter no longer ships a plugin. Memory-gate enforcement on opencode is now provided
  solely by the universal hard gate (`core/scripts/memory-gate.sh`) installed as a git pre-commit
  hook or CI step. The `agent-workflow` skill already instructs the agent to write `3_memory.md` at
  task end, so the soft `session.idle` reminder was redundant.
- Updated `adapters/opencode/INSTALL.md`, `adapters/opencode/README.md`, `PORTABILITY.md`, and
  `INSTALL.md` to remove plugin references and clarify hard-gate-only enforcement.

### Removed

- `adapters/opencode/.opencode/plugins/agent-harness.ts`.

### Upgrade Notes

- Delete the old opencode plugin file from your installed copy:
  `.opencode/plugins/agent-harness.ts`.
- Ensure `core/scripts/memory-gate.sh` is wired as a git pre-commit hook or CI step; it is now the
  only enforcement mechanism on opencode.
- Re-apply the opencode config merge (`opencode.jsonc`) and command files
  (`.opencode/commands/tah-update.md`, `.opencode/commands/tah-build.md`) from the new bundle.

## [0.2.0] - 2026-08-24

### Added

- Harness versioning infrastructure: `core/VERSION`, this changelog, and
  `core/scripts/harness-update.sh` (`current` / `latest` / `check`) comparing an
  installed copy against the upstream repo.
- Changelog-driven upgrades: each release ships an upgrade prompt in
  `changelogs/version-X.Y.Z.md`. The active agent reads these markdown prompts and applies the
  described `copy` / `delete` / `run` / `note` operations.
- `/tah:update` slash command for Claude Code and `/tah-update` for opencode, backed by the
  shared `core/skills/harness-update/SKILL.md` instructions.
- `/tah-build` manual plan/spec build trigger for Claude Code, opencode, and Codex CLI, backed by
  the shared `core/skills/agent-workflow/SKILL.md` instructions.
- Codex CLI adapter (`adapters/codex/`) with `.codex/config.toml`, `.codex/hooks.json`,
  and the `/tah-update` skill backed by the same update engine.

### Changed

- Task artifacts moved out of the docs app into each workspace's `.agents/artifacts/` tree with a
  mandatory searchable `index.md`; the memory-gate scans all workspaces automatically.
- The docs-placement guard capability was removed entirely (no docs-app dependency).

### Removed

- `core/scripts/check-docs-placement.sh`, its adapter hooks, and the docs-tree governance files.

### Upgrade Notes

- The harness update command is `/tah:update` for Claude Code and `/tah-update` for opencode
  (and Codex CLI). Remove the old adapter files
  (`.claude/commands/turborepo-harness/update-check.md` and
  `.opencode/commands/turborepo-harness-update-check.md`) and copy the new ones from
  `.claude/commands/tah/update.md` and `.opencode/commands/tah-update.md`.
- The manual plan/spec build trigger is `/tah-build` on all agents. Copy the new adapter files:
  `.claude/commands/tah-build.md`, `.opencode/commands/tah-build.md`, and
  `.agents/skills/tah-build/SKILL.md` (Codex CLI).

## [0.1.0] - 2026-08-23

### Added

- Initial release: plan → spec → memory workflow (`agent-workflow` skill), per-workspace working
  state (`.agents/{session-log,lessons,todo}.md`), memory-gate enforcement, claude-code and opencode
  adapters, Turborepo guidance skill.

[Unreleased]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.12.0...HEAD
[0.12.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.12.0
[0.11.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.11.1
[0.11.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.11.0
[0.10.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.10.0
[0.9.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.9.0
[0.8.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.8.0
[0.7.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.7.0
[0.6.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.6.0
[0.5.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.5.0
[0.4.5]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.5
[0.4.4]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.4
[0.4.3]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.3
[0.4.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.2
[0.4.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.1
[0.4.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.4.0
[0.3.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.3.0
[0.2.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.2
[0.2.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.1
[0.2.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0
[0.1.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0
