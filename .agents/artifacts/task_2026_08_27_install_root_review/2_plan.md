---
phase: plan
date: 2026-08-27
slug: install_root_review
status: approved
---

# Plan: Install root REVIEW.md during harness install

## Problem

`root-REVIEW.md` is shipped in the bundle but never placed at a consumer's root as `REVIEW.md`;
installing is a manual step documented only in `INSTALL.md` §6. This is the "a file never reached
the consumer project" failure class the script/manifest design exists to prevent.

## Approach

Add a `REVIEW.md` generation block to `install-harness.sh` step 3, immediately after the `AGENTS.md`
block, reusing the same helpers (`harness_resolve_placeholders`, `note`, `fail`). Mirror the
`AGENTS.md` semantics exactly: provenance marker on line 1, `{{PROJECT_NAME}}` resolved,
`{{PROJECT_REVIEW_POLICY}}` left for the user, existing file left untouched with a note. No manifest
change is needed — `core/install-manifest.txt` already ships the whole `core/` dir. Add a parallel
REVIEW provenance check to `audit-install.sh`, update the template's own header comment and the docs,
bump to `0.1.0-rc.2`, and update the review skill docs only if they claim manual install (they
already read root `REVIEW.md` — no change needed there).

## Related prior work

- `task_2026_08_27_align_artifact_order` renumbered artifacts and touched `core/root-REVIEW.md`
  (content only, no install behavior).

## Steps

1. `install-harness.sh`: add `REVIEW.md` block after AGENTS.md (resolve `{{PROJECT_NAME}}`, prepend
   marker `root-REVIEW.md v$VERSION`, `note` to fill `{{PROJECT_REVIEW_POLICY}}`, leave-existing rule).
2. `core/root-REVIEW.md`: reword header comment to describe auto-install.
3. `audit-install.sh`: add `check_review_md()` (missing + stale-marker) parallel to `check_agents_md`
   and call it in the checks list.
4. Docs: `INSTALL.md` §2/§4/§6, `README.md` index row, `PORTABILITY.md:40`.
5. Version: `VERSION` → `0.1.0-rc.2`, `CHANGELOG.md` section + Upgrade Note + link refs,
   `changelogs/version-0.1.0-rc.2.md` (Upgrade Note lives in CHANGELOG; prompt added only if a
   runnable/manual follow-up is genuinely required — likely not, so skip unless needed).
6. Verify (bash -n, smoke install fresh + pre-existing, audit in consumer-style temp).
7. Task artifacts (memory/verify) + workspace state + commit.

## Affected files / modules

- core/scripts/install-harness.sh
- core/root-REVIEW.md
- core/scripts/audit-install.sh
- INSTALL.md, README.md, PORTABILITY.md
- VERSION, CHANGELOG.md, changelogs/version-0.1.0-rc.2.md

## Risks & assumptions

- Assumes auto-installing a default `REVIEW.md` is desired even though the review skill would
  otherwise fall back to identical built-in defaults — confirmed by the user ("AGENTS.md gibi").
- Assumes existing `REVIEW.md` must be left untouched — confirmed by the user.
- Version bump target `0.1.0-rc.2` follows the established `-rc.*` settling policy; flagged for
  user confirmation during implementation.

## Definition of done

- [ ] Fresh install creates root `REVIEW.md` (marker line 1, `{{PROJECT_NAME}}` resolved)
- [ ] Pre-existing `REVIEW.md` left byte-identical and reported
- [ ] Template header + docs no longer describe manual optional install
- [ ] audit-install.sh reports missing/stale REVIEW marker
- [ ] VERSION 0.1.0-rc.2 + CHANGELOG + (if needed) prompt
- [ ] All verification commands pass
