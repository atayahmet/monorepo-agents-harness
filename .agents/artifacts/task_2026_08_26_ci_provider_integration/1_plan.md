---
phase: plan
date: 2026-08-26
slug: ci_provider_integration
status: approved
---

# Plan: CI/CD integration — detect-ci-provider.sh + ci-integration skill (Faz 2, v0.8.0)

## Problem

`memory-gate.sh` today must be wired into a target project's CI by hand — INSTALL.md only gives a
generic `bash .../memory-gate.sh` snippet with no guidance on *where* to put it for the CI tool the
project actually uses. There is no detection, no per-provider guidance, no automation.

## Approach

Add `core/scripts/detect-ci-provider.sh` (mirrors `detect-monorepo-framework.sh`'s exact pattern)
and a new `core/skills/ci-integration/SKILL.md` that detects the provider and, tiered by what each
CI format actually supports: for GitHub Actions (native multi-file workflow support), writes a new,
dedicated `.github/workflows/harness-memory-gate.yml` after explicit consent; for GitLab/Bitbucket/
CircleCI (single-pipeline-file formats), shows the exact snippet and where to paste it but does not
write anything itself; for unknown, offers an opt-in GH Actions starter. Wire a `/monorepo-harness-ci`
command/skill into all three adapters using the exact thin-pointer pattern already used by
`monorepo-harness-build`/`monorepo-harness-update`.

## Related prior work

Grepped `.agents/artifacts/index.md` for `ci`/`provider`/`detect` — no matches. `none found`.

## Steps

1. `core/scripts/detect-ci-provider.sh` — new script.
2. `core/skills/ci-integration/SKILL.md` — new skill, GH Actions snippet embedded inline.
3. Three adapter command/skill files (`adapters/claude-code/.claude/commands/monorepo-harness-ci.md`,
   `adapters/opencode/.opencode/commands/monorepo-harness-ci.md`,
   `adapters/codex/.agents/skills/monorepo-harness-ci/SKILL.md`).
4. `PORTABILITY.md` — new capability-matrix row.
5. `adapters/AGENTS.md` — Hard Rule 6 gains the new command.
6. `README.md` — "What you get" bullet + Documentation map row.
7. `INSTALL.md` — new `## 11. CI integration (optional)` section.
8. `core/VERSION` → `0.8.0`; `CHANGELOG.md` `[0.8.0]` entry; `changelogs/version-0.8.0.md`.
9. Verify (scratch provider-detection scenarios + YAML sanity), write `4_verify.md` + `3_memory.md`,
   update `.agents/artifacts/index.md`, commit.

## Affected files / modules

`core/scripts/`, `core/skills/` (new dir), all three `adapters/*/` (new command/skill files),
`PORTABILITY.md`, `adapters/AGENTS.md`, `README.md`, `INSTALL.md`, `core/VERSION`, `CHANGELOG.md`,
`changelogs/`. This repo has no `apps/`/`packages/` — artifacts live at root `.agents/artifacts/`
per the established Faz 1 precedent.

## Risks & assumptions

- **Scope boundary**: GitLab/Bitbucket/CircleCI get detection + guided snippets only, not automatic
  wiring — a deliberate, user-confirmed scope decision (single-pipeline-file CI formats can't be
  safely auto-integrated via a separate file the way GitHub Actions can).
- **No new script dependency**: `detect-ci-provider.sh` stays `git` + coreutils only, matching
  `detect-monorepo-framework.sh`'s dependency profile.
- **Idempotency**: the GH Actions auto-write path must check for an existing
  `harness-memory-gate.yml` before writing and ask, never silently overwrite.
- **Backward compatible**: purely additive — no existing file's behavior changes, no artifact-layout
  change.

## Definition of done

- [ ] `detect-ci-provider.sh` detects all four providers plus `unknown`, matches the existing
      detector script's exact style.
- [ ] `ci-integration` skill's three-tier behavior (auto / guided / unknown) is fully documented and
      the GH Actions consent question never writes without an explicit yes.
- [ ] All three adapters get a working `/monorepo-harness-ci` entry point, thin-pointer only.
- [ ] `PORTABILITY.md`, `adapters/AGENTS.md`, `README.md`, `INSTALL.md` reflect the new capability.
- [ ] `core/VERSION` = `0.8.0`, changelog files consistent.
- [ ] This task's own `4_verify.md` demonstrates the detector against real scratch scenarios.
