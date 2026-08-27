---
phase: spec
date: 2026-08-27
slug: install_root_review
status: approved
---

# Spec: Install root REVIEW.md during harness install

## Problem

`core/root-AGENTS.md` is auto-installed to a consumer project's root as `AGENTS.md` (step 3 of
`core/scripts/install-harness.sh`), but `core/root-REVIEW.md` — the template for the PR-review
policy — is only copied into the installed bundle at
`.agents/monorepo-agents-harness/core/root-REVIEW.md`. Nothing places it at the target root as
`REVIEW.md`, so the review policy never reaches its target directory. The `pr-review` skill reads
root `REVIEW.md` if present and otherwise falls back to built-in defaults, so the missing install is
a silent gap that the manifest/script design was meant to prevent.

## Requirements

1. `install-harness.sh` writes the root `REVIEW.md` from `core/root-REVIEW.md` (mirroring the
   `AGENTS.md` step): prepend a provenance marker on line 1
   (`<!-- monorepo-agents-harness: root-REVIEW.md v<version> -->`), resolve `{{PROJECT_NAME}}`, and
   leave the `{{PROJECT_REVIEW_POLICY}}` region to the user. Output a `Needs you:` note reminding the
   user to fill or delete that region.
2. If a root `REVIEW.md` already exists during install, leave it untouched (same rule as
   `AGENTS.md`) and report it.
3. Update the `core/root-REVIEW.md` header comment so it no longer claims copying is a manual
   optional step.
4. `audit-install.sh` gains a `REVIEW.md` provenance check (missing file and stale marker-warning)
   parallel to its existing `AGENTS.md` check.
5. Docs (`INSTALL.md`, `README.md`, `PORTABILITY.md`) reflect that `REVIEW.md` is auto-installed, not
   a manual optional extra.
6. Version consistency: bump `VERSION` to `0.1.0-rc.2` with a `CHANGELOG.md` section and Upgrade
   Note (existing `REVIEW.md` is never overwritten on upgrade).

## Test / verification plan

- `bash -n` on every `core/scripts/*.sh`.
- Smoke install into a temp git repo via `--from <bundle>` (not `--sync-only`): assert a root
  `REVIEW.md` is created with a provenance marker on line 1 and `{{PROJECT_NAME}}` resolved.
- Second smoke run with a pre-existing root `REVIEW.md`: assert the existing file is byte-identical
  after install (untouched) and a note is emitted.
- `audit-install.sh` against a consumer-style target with the REVIEW marker present → exit 0; with
  the marker/version missing → names `REVIEW.md`. (Note: in this template repo itself the audit
  returns exit 2 "no bundle to compare against" — structural, run the check in the temp consumer.)
