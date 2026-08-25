---
version: 0.4.2
from: 0.4.1
date: 2026-08-25
---

# Version 0.4.2 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.1 to 0.4.2.

This release updates the upstream repository references to the renamed
`monorepo-agents-harness` GitHub repository. There are no behavior changes to
the harness itself.

## Files to copy from the new bundle to the installed bundle

Copy the following files from the newly downloaded bundle into
`.agents/monorepo-agents-harness/`:

- `core/VERSION` -> `core/VERSION`
- `VERSION` -> `VERSION`
- `CHANGELOG.md` -> `CHANGELOG.md`
- `changelogs/version-0.4.2.md` -> `changelogs/version-0.4.2.md`

## Files to delete from the installed bundle (only if they exist)

- None.

## Commands to run

Run these from the target repo root.

```bash
# Ensure the version file at the bundle root is up to date.
cp .agents/monorepo-agents-harness/core/VERSION .agents/monorepo-agents-harness/VERSION
```

## Manual follow-ups for the user

- If you override the upstream repository via the `HARNESS_UPSTREAM` environment
  variable or a custom `BUNDLE_DIR`, confirm the URL still resolves to the
  correct repository (`https://github.com/atayahmet/monorepo-agents-harness`).
- No other action is required for installed copies.

## Release summary

- Pointed the repository origin and all historic release links to the renamed
  `monorepo-agents-harness` GitHub repository.
- No functional changes to the harness bundle, scripts, or adapter wiring.
