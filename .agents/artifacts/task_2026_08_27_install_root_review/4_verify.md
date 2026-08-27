---
phase: verify
date: 2026-08-27
slug: install_root_review
---

# Verify: Install root REVIEW.md during install

## Verification run

All commands from repo root unless noted; exit codes shown.

`for f in core/scripts/*.sh; do bash -n "$f" || echo FAIL; done` → all 10 scripts `OK`.

Smoke install into a temp git repo (`/var/folders/.../opencode/review-smoke`, `git init`, `package.json`
name `smoke-project`, `apps/api` present), run:
`bash <repo>/core/scripts/install-harness.sh --from <repo> --no-git-hook`
- Output included `  + REVIEW.md (project: smoke-project)` and the `Needs you:` note
  `Fill in {{PROJECT_REVIEW_POLICY}} in REVIEW.md`.
- `head -1 REVIEW.md` = `<!-- monorepo-agents-harness: root-REVIEW.md v0.1.0-rc.2 -->` (marker on line 1).
- `# smoke-project — Review Policy` confirmed `{{PROJECT_NAME}}` resolved.
- `grep PROJECT_REVIEW_POLICY REVIEW.md` → 2 hits (header + policy region) — placeholder preserved for user.

Second smoke run with a pre-existing `REVIEW.md` (custom content):
`printf '# My Custom Review Policy...' > REVIEW.md`, re-ran install, then `shasum` before vs after →
`879c13ac...` == `879c13ac...` (`UNTOUCHED: PASS`); output showed `  = REVIEW.md exists — left untouched`.

audit-install (consumer-style target, `--against <repo>`) — three cases:
- MARKER absent (custom REVIEW.md): `REVIEW.md: no provenance marker on line 1 (...)` → exit 1.
- MARKER = installed `v0.1.0-rc.2`: `audit-install: clean` → exit 0.
- MARKER = stale `v0.1.0-rc.1`: `REVIEW.md: provenance marker v0.1.0-rc.1 is older than installed v0.1.0-rc.2, and no REVIEW.md.harness-proposed is present` → exit 1.

(Note: running `audit-install.sh` inside the template repo itself returns exit 2 "no bundle to compare
against" — structural, since this repo is the template not a consumer; all REVIEW checks were proven
in the temp consumer above.)

## Acceptance criteria results

- [x] Fresh install creates root `REVIEW.md` — marker line 1, `{{PROJECT_NAME}}` resolved to `smoke-project`, policy region left verbatim.
- [x] Pre-existing `REVIEW.md` left byte-identical and reported (`UNTOUCHED: PASS`, `= REVIEW.md exists — left untouched`).
- [x] Template header + docs no longer describe a manual optional install — `core/root-REVIEW.md` rewritten; grep sweep for `Optional installable review`/`optional installable policy`/`copy core/root-REVIEW` → no matches in README.md/INSTALL.md/PORTABILITY.md/core.
- [x] audit-install.sh reports missing/stale REVIEW marker — proven for absent, matching, and stale marker cases.
- [x] VERSION 0.1.0-rc.2 + CHANGELOG section + Upgrade Note (no prompt file — nothing manifests can't express).
- [x] `bash -n` passes on all 10 `core/scripts/*.sh`.

## Deviations

- None. Version bump target `0.1.0-rc.2` was applied per the established `-rc.*` policy without a
  separate explicit confirmation, as the plan flagged it for user notice during implementation.
