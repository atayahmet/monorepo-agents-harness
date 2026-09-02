# Changelog

All notable changes to the agent harness are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/), prereleases included (`0.1.0-rc.0` precedes `0.1.0`).

Every release MUST include an **Upgrade Notes** section describing anything an installed copy needs
to do beyond the normal sync (behavior changes, artifact-layout changes, manual merges).

Release procedure (harness maintainers):

1. Update `VERSION` at the repo root (SemVer: MAJOR = workflow/artifact-layout breakers, MINOR = new
   capabilities, PATCH = fixes/docs; `-rc.N` while stabilizing a release).
2. Add a `CHANGELOG.md` section with Upgrade Notes.
3. Add `changelogs/version-X.Y.Z.md` if the release needs anything the manifests cannot express —
   commands to run or manual follow-ups. Files added to the bundle or an adapter need **no** prompt:
   add the manifest row instead (`changelogs/README.md`).
4. Commit and tag the upstream repo as `vX.Y.Z` (`git tag -a vX.Y.Z -m … && git push origin vX.Y.Z`).

## [Unreleased]

### Added

### Changed

### Removed

### Upgrade Notes

## [0.1.0-rc.10] - 2026-09-02

### Added

### Changed

- **`0_intent.md` is now a reference stub, not a copy.** Task directories seeded by an approved
  intent no longer duplicate the intent's content into `0_intent.md`; instead it's a small stub with
  a `source:` frontmatter link pointing back to the real intent file under
  `<workspace>/.agents/intents/`, which stays the single source of truth. `core/scripts/task-state.sh`
  `check-chain` now resolves that `source:` link and checks approval on the **original** intent file
  rather than on the local copy — so an intent rejected after a task was seeded is now caught too.
  Updated in `core/skills/agent-workflow/SKILL.md`, `core/governance/intents/AGENTS.md`,
  `core/scripts/task-state.sh`, the three adapters' `/monorepo-harness-spec` stubs, their READMEs,
  `adapters/AGENTS.md`, `core/governance/artifacts/AGENTS.md`, and the root `README.md`.

### Removed

### Upgrade Notes

- **No manual follow-up required.** Prompt/script change only — no manifest rows, no artifact
  migration (no existing task directory contains a `0_intent.md` yet). Installed projects pick it up
  on the normal harness-update path.

## [0.1.0-rc.9] - 2026-09-02

### Added

### Changed

- **Spec and plan artifacts now explicitly reference the seeding intent.** Intent-seeded tasks must
  include `intent: 0_intent.md` in `1_spec.md` frontmatter and cite the intent in `2_plan.md`'s
  `## Problem` section (e.g. `problem originally captured and approved in [0_intent.md](0_intent.md)`).
  Ad-hoc tasks with no `0_intent.md` omit the frontmatter line and the trailing clause. Updated in
  `core/skills/agent-workflow/SKILL.md` and `core/governance/intents/AGENTS.md`.

### Removed

### Upgrade Notes

- **No manual follow-up required.** Prompt/rule change only — no manifest rows, no gate changes, no
  migration. Installed projects pick it up on the normal harness-update path.

## [0.1.0-rc.8] - 2026-08-28

### Changed

- **Intent capture now asks before creating (and committing to) a dedicated `intent/<slug>` branch.**
  On capture the workflow already asked which workspace the intent goes under; it now also present a
  slug-derived branch name it **recommends** (e.g. `intent/add_login_form`) and asks the author to
  confirm or decline creating it via `git switch -c` / `git checkout -b`. If a branch is created, it
  then asks **separately** whether to commit the `status: pending` intent file to that branch. Both
  are explicit in-turn consent questions — a branch is never created, and a pending intent is never
  committed, without the author's answer. Whether the intent file is actually tracked by git is left
  to the host project, whose `.gitignore` decides it — the harness does not mandate or force it
  (`install-manifest.txt` deliberately ships no `.gitignore`). This is a single-source-of-truth change
  to `core/skills/intent-workflow/SKILL.md` plus the matching rule in
  `core/governance/intents/AGENTS.md`; the three adapters' `/monorepo-harness-intent` stage files were
  updated to reflect the new workspace → branch → commit consent flow, and `PORTABILITY.md` notes that
  the flow now uses native `git` branch/commit alongside the existing consent questions.

### Upgrade Notes

- **No manual follow-up required.** Prompt/rule change only — no manifest rows, no gate changes, no
  migration. Branch/commit only happen when the author consents during capture; whether a project's
  `.gitignore` excludes `<workspace>/.agents/intents/` is that project's own decision, and the harness
  never force-adds an intent against it. Installed projects pick the behavior up on the normal
  harness-update path (the intent skill + rules + stage files ship in the bundle).

## [0.1.0-rc.7] - 2026-08-28

### Changed

- **Intent capture now always confirms the target workspace with the author.** The intent workflow no
  longer files an intent under the workspace most likely to drive the work by default — on capture it
  always asks which workspace the intent goes under and presents its own recommendation as the prompt
  (e.g. "File this intent under `apps/api`? (my recommendation)"). The intent file is written only
  after the author confirms the workspace in the current turn, so the intent lands in the right review
  inbox and correctly routes the later plan-mode task that consumes an approved intent. This is a
  single-source-of-truth change to `core/skills/intent-workflow/SKILL.md` plus the matching rule in
  `core/governance/intents/AGENTS.md`; all three adapters' `/monorepo-harness-intent` stage files
  already defer to the shared skill, so they inherit the behavior unchanged.

### Upgrade Notes

- **No manual follow-up required.** Prompt/rule change only — no manifest rows, no gate changes, no
  migration. Installed projects pick it up on the normal harness-update path (the intent skill and
  rules ship in the core bundle).

## [0.1.0-rc.6] - 2026-08-28

### Changed

- **Implementation is now gated on an approved plan.** Fixed the gap where a helpful agent, right
  after writing the spec (`1_spec.md`), would jump straight into implementation without an approved
  `2_plan.md`. Every `/monorepo-harness-spec` command now ends by telling the agent to **stop and
  wait** for `/monorepo-harness-plan`, and every `/monorepo-harness-plan` command ends by telling it
  to **stop and wait** for `/monorepo-harness-build` — so implementation never begins before a
  user-approved plan exists, preserving the `intent → spec → plan → memory → verify` SDLC order.
- **Shared skill hardened.** `core/skills/agent-workflow/SKILL.md` Phase 1 and Phase 2 each end with
  an explicit wait/stop step, and its description no longer implies automatic plan-mode-exit
  triggering exists on every agent (it is manual on opencode and codex).
- **Parity across adapters.** The identical STOP text was applied to all three adapters' `-spec`
  and `-plan` stage files (opencode commands, claude-code commands, codex skills) and all three
  READMEs' typical-workflow sections were updated to name the stop/wait points.

### Upgrade Notes

- **No manual follow-up required.** This is a prompt/instruction change only — no manifest rows,
  no gate changes, no migration. Existing installed projects pick it up on the normal harness-update
  path (the `-spec`/`-plan` stage files ship inside the adapter bundle and update on `refresh`).
  Agents that previously skipped the plan will now stop and ask for `/monorepo-harness-plan` first.

## [0.1.0-rc.5] - 2026-08-28

### Added

- **ADR (Architecture Decision Record) workflow, automatically triggered.** A new
  `core/skills/adr-workflow/SKILL.md` fires while the spec (`1_spec.md`) or plan (`2_plan.md`) is
  being written whenever a task makes an architecture-affecting decision — new external dependency
  or service integration, persistent data-model change with cross-workspace ripple, cross-workspace
  API/event contract change, delivery-guarantee change (idempotency/retry/ordering),
  auth/security model change, or any choice between alternatives with material, hard-to-reverse
  consequences. Decisions land as `adr/NNNN-<title>.md` files **inside the task directory**
  (`## Context` / `## Decision` / `## Alternatives considered` / `## Consequences` /
  `## Related prior ADRs`), each referenced from the spec's new `## Architectural decisions` section.
  Tasks with no architecture-affecting decision write `N/A` and are done — the record stays
  conditional, never gated.
- **`core/scripts/task-state.sh check-adr <spec.md>`** — read-only validator (fail-open backcompat:
  a pre-existing spec without the section passes) used by the `agent-workflow` Phase 1 and the PR
  review pass.
- **ADR-compliance pass in review.** `core/skills/pr-review/SKILL.md` and the root `REVIEW.md`
  template (`core/root-REVIEW.md`) now check that every ADR a task's spec references exists with
  `phase: adr` (failing = Important); an architecture-affecting diff with no ADR declared is at most
  a Nit.
- **Spec template integration.** `core/skills/agent-workflow/SKILL.md` gains the
  `## Architectural decisions` section in the `1_spec.md` template, an `adr/` row in its layout
  trees, and Phase 1/2 trigger steps for the new skill.
- **Adapter registration.** The skill ships for all three agents: new `link` rows in
  `adapters/claude-code/manifest.txt` and `adapters/codex/manifest.txt` (auto-registered skill), and
  a new `instructions` entry in `adapters/opencode/opencode.jsonc`. No slash command — triggering is
  automatic (codex auto-registers it in the slash list anyway, same as the other shared skills).
- Docs updated: `PORTABILITY.md` capability matrix + semantic note, `README.md` (feature bullet,
  artifact tree, Scenario 1 ADR example, docs map), the three adapter READMEs, and the installable
  templates (`core/root-AGENTS.md`, `core/governance/artifacts/AGENTS.md`).

### Upgrade Notes

- **New files reach installed projects via the normal update path.** The `adr-workflow` skill
  (bundle, inside `core/`) and the new claude-code/codex `link` rows are applied automatically by
  the harness-update workflow (`install-harness.sh --sync-only` + `install-adapter.sh --refresh`).
- **opencode needs one manual merge.** The new skill reference lives inside `opencode.jsonc`, which
  installs as a `merge` row — the update flow proposes `opencode.jsonc.harness-proposed` but never
  touches your existing file. Add
  `.agents/monorepo-agents-harness/core/skills/adr-workflow/SKILL.md` to the `instructions` array
  (or accept the proposed version); until then opencode just won't auto-load the ADR skill — a soft
  loss, no hard gate (see `changelogs/version-0.1.0-rc.5.md`).
- **Task directories may optionally contain `adr/`.** No migration, nothing renamed: existing tasks
  without the `## Architectural decisions` section are treated as "no ADRs declared" by `check-adr`.

## [0.1.0-rc.4] - 2026-08-27

### Removed

- **Per-adapter harness update commands.** The `/monorepo-harness:update` (claude-code) and
  `/monorepo-harness-update` (opencode, codex) entry points are removed. Updating is now driven by a
  paste-in **"Or update from the repo"** prompt in the project README that points the active agent at
  the (now-versionless) `core/skills/harness-update/SKILL.md` workflow — the same check, consent
  gates, installer re-run, self-healing adapter `--refresh`, AGENTS.md reconciliation, and audit as
  before, just no longer via a registered slash command. The shared skill and
  `core/scripts/harness-update.sh` remain in the bundle.

### Changed

- Adapter install manifests drop the removed update-command rows; the capability matrix
  (`PORTABILITY.md`), the README feature bullets, Scenario 5, the adapter tables, and each adapter's
  README/INSTALL now describe the README-prompt-driven update instead.

### Upgrade Notes

- **No manual follow-up is required.** The removal is manifest-only: an existing installed adapter
  keeps a stale `/monorepo-harness:update` command/skill until you re-run
  `install-adapter.sh <agent> --refresh` (or run the README update prompt, which does this
  automatically). Re-running it is optional — the stale entry point is harmless and still points at
  the valid shared skill — but re-running it matches the new layout. Any consumer using
  `audit-install.sh` against this release will flag a stale update command file as an extra file to
  remove (or re-install), which is expected.

## [0.1.0-rc.3] - 2026-08-27

### Added

- **Per-SDLC-stage slash commands.** The single `/monorepo-harness-build` that wrote spec+plan in
  one step is split into three gated stages, plus a new read-only validator
  `core/scripts/task-state.sh`:
  - `/monorepo-harness-spec <intent.md?>` — writes `1_spec.md`; when an intent path is given it
    refuses (via `check-intent-approved`) unless that intent is `approved`, and copies it as
    `0_intent.md`. Without a path it makes a normal ad-hoc spec.
  - `/monorepo-harness-plan <spec.md>` — writes `2_plan.md`; validates the spec (`check-spec`) and
    asks about plan mode first (proceeding without it if the user declines).
  - `/monorepo-harness-build <2_plan.md>` — runs the implementation gated on the whole chain
    (`check-chain`: spec+plan present; intent approved if the task is intent-seeded), then
    **automatically** writes `3_memory.md` + `4_verify.md` (unless the spec's Test/verification plan
    is `N/A`) and updates the index.
- `task-state.sh` ships inside the bundle automatically (part of the existing `core/` row).
- All three adapters gain the new `-spec`/`-plan` commands and a rewritten `-build` (manifest rows
  added); docs (`PORTABILITY.md`, each adapter `README.md`/`INSTALL.md`, root `README.md`) updated.

### Upgrade Notes

- `/monorepo-harness-build` **no longer writes `1_spec.md`/`2_plan.md`.** If your workflow relied on
  it to create plan/spec artifacts, use `/monorepo-harness-spec` then `/monorepo-harness-plan`
  instead. `-build` now starts implementation (gated) and writes memory/verify on completion.
- The intent-approval requirement is **conditional, not universal**: it is enforced only when a task
  is seeded by an intent (a `0_intent.md` exists). Ad-hoc tasks (no intent) are unaffected — they
  skip the intent gate entirely, preserving the existing lightweight path.
- An existing installed adapter does not get the new commands until you re-run its installer
  (`install-adapter.sh <agent> --refresh`) or upgrade the harness — see
  `changelogs/version-0.1.0-rc.3.md`.

## [0.1.0-rc.2] - 2026-08-27

### Added

- **Root `REVIEW.md` is now installed automatically.** `core/scripts/install-harness.sh` writes the
  review-policy file at the project root from `core/root-REVIEW.md` (provenance marker on line 1,
  `{{PROJECT_NAME}}` resolved), exactly like the existing `AGENTS.md` step. It is no longer a manual
  "copy it yourself" step. `core/scripts/audit-install.sh` now reports a missing or stale
  `REVIEW.md` alongside the existing `AGENTS.md` check.

### Upgrade Notes

- Existing projects that never created a root `REVIEW.md` will get one on their next **full**
  install (a re-run of `install-harness.sh` without `--sync-only`), exactly like `AGENTS.md` — the
  `--sync-only` update path deliberately does not touch root files. A `REVIEW.md` that already exists
  is **never overwritten** — it is left untouched, like `AGENTS.md`. The `{{PROJECT_REVIEW_POLICY}}`
  region is yours to fill in or delete; leaving the defaults in place preserves the current review
  behavior (the skill's built-in defaults match the generated file).

## [0.1.0-rc.1] - 2026-08-27

### Changed

- **Artifact order now matches the AI-native SDLC playbook** (`intent → spec → plan → memory →
  verify`): the per-task files are renamed so the spec is written first. What was `1_plan.md` is now
  `2_plan.md` (the "how") and what was `2_spec.md` is now `1_spec.md` (the "what"). Plan-mode
  approval now produces `1_spec.md` then `2_plan.md` before implementation, matching Design-before-
  Build (`claude.com/blog/the-ai-native-sdlc-playbook`).
- **Propagated the rename everywhere it is read by name:** the `agent-workflow` skill (Phase 1 =
  spec, Phase 2 = plan), `core/scripts/memory-gate.sh`, the task-index format (link target now
  `1_spec.md`; ◆ = `2_plan.md` + `3_memory.md`), the governance rules (`artifacts`, `intents`), the
  root templates (`root-AGENTS.md`, `root-REVIEW.md`, workspace seed), the PR-review skill, and all
  three adapters' build/review commands, the claude-code `verifier` subagent, and the hook messages.
- **Backcompat for legacy task dirs.** `memory-gate.sh` and the review skill accept a pre-rename
  task dir whose spec is still `2_spec.md` when no `1_spec.md` exists, so installed projects with
  in-flight tasks keep passing the gate on upgrade. No forced migration, nothing renamed on disk.

### Upgrade Notes

- New task directories use `1_spec.md` / `2_plan.md`. Existing task dirs are left untouched and keep
  passing the gate via backcompat — you may rename them at leisure; there is no release prompt that
  forces a migration.
- If you grep installed projects for the old `2_spec.md`/`1_plan.md` names you will still match
  legacy dirs — that is expected until they are closed out.

## [0.1.0-rc.0] - 2026-08-27

First release candidate. Versioning starts here.

### Added

- **Plan → spec → memory → verify artifact workflow.** Every non-trivial task produces
  `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` containing `1_plan.md`, `2_spec.md`,
  `3_memory.md` and `4_verify.md` (the last required unless the spec's verification plan is `N/A`),
  indexed in that workspace's searchable `.agents/artifacts/index.md`.
- **A hard memory-gate.** `core/scripts/memory-gate.sh` scans every workspace and blocks until
  today's task directory is complete — as an agent stop-hook where the agent can block its own stop,
  and as a git `pre-commit` hook / CI step everywhere else. Fail-open on missing dependencies.
- **Manifest-driven install.** What lands in a consumer project is data, not prose:
  `core/install-manifest.txt` (the bundle whitelist) and `adapters/<agent>/manifest.txt` (one row
  per installed file; verbs `copy`, `link`, `merge`, `tmpl`). Executed by
  `core/scripts/install-harness.sh` (Phase 1) and `core/scripts/install-adapter.sh` (Phase 2),
  verified against those same manifests by `core/scripts/audit-install.sh`.
- **Never-destructive install/update.** Nothing is deleted: replaced content is moved to
  `.agents/.harness-trash/<timestamp>_<pid>/`, and purging it is the user's own explicit call via
  `core/scripts/cleanup-harness-trash.sh`. An existing config file is never modified — the adapter's
  version arrives as `<file>.harness-proposed` for a deliberate merge.
- **Root `AGENTS.md` reconciliation.** `core/root-AGENTS.md` is installed as the project's
  `AGENTS.md` with a provenance marker recording the template version, so
  `core/skills/agents-md-merge/SKILL.md` can three-way merge on later upgrades — presented as a
  diff and written only after explicit approval.
- **Consent-gated upgrades.** `core/scripts/harness-update.sh` resolves installed vs. upstream
  version (SemVer precedence, prereleases included); `core/skills/harness-update/SKILL.md` reports
  the diff, asks once, then re-runs the installers and audits the result before claiming success.
- **Adapters for claude-code, opencode and Codex CLI**, under a mandatory-parity rule
  (`PORTABILITY.md`): every harness capability has a live counterpart per agent, or an explicit
  agent-agnostic fallback. Each ships the harness-plumbing commands `/monorepo-harness-build`,
  `-update`, `-ci`, `-review`, `-intent`, plus a `verifier` subagent where the agent supports one.
- **Supporting skills:** `agent-workflow` (artifact templates), `monorepo` (framework-agnostic
  guidance), `ci-integration` (detects the CI provider and wires the gate in), `pr-review` (reviews a
  diff against `REVIEW.md` and the task's own artifacts), `intent-workflow` (stakeholder intent
  capture with an approve/reject gate).
- **Workspace scaffolding.** `core/scripts/scaffold-workspace-agents.sh` seeds every app and package
  with `.agents/{session-log,lessons,todo}.md`, the artifact tree and the intent inbox; it never
  overwrites an existing file and is safe to re-run after adding a workspace.

### Upgrade Notes

- Nothing to upgrade from — this is the first tagged release. Install with `INSTALL.md`.
- While on `-rc.*`, treat the artifact layout and the manifest format as still settling: a breaking
  change may land in a later `rc` without a MAJOR bump.

[Unreleased]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.1.0-rc.8...HEAD
[0.1.0-rc.8]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.8
[0.1.0-rc.7]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.7
[0.1.0-rc.6]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.6
[0.1.0-rc.5]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.5
[0.1.0-rc.4]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.4
[0.1.0-rc.3]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.3
[0.1.0-rc.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.2
[0.1.0-rc.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.1
[0.1.0-rc.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.0
