---
phase: memory
date: 2026-08-27
slug: install_root_review
commits: [73904842a9cd5bb96f1f87ace513daca5ea39a3a]
---

# Memory: Install root REVIEW.md during install

## What was done (single paragraph)

`core/root-REVIEW.md` was previously only shipped inside the installed bundle and never written to a
consumer project's root, so `/monorepo-harness-review` silently fell back to built-in defaults for
everyone. Added a step-3 block to `install-harness.sh` that writes root `REVIEW.md` from the template
(provenance marker on line 1, `{{PROJECT_NAME}}` resolved, `{{PROJECT_REVIEW_POLICY}}` left for the
user), leaving an existing `REVIEW.md` untouched — the exact semantics of the `AGENTS.md` step it
mirrors. Added a parallel `check_review_md()` to `audit-install.sh` (missing file, missing marker,
stale marker vs installed `VERSION`), rewrote the template header and the docs, and bumped `VERSION`
to `0.1.0-rc.2`.

## Surprising findings

- The `--sync-only` update path deliberately **does not** write root files (AGENTS.md includes). So a
  fresh `REVIEW.md` only appears on a full install, not on an update — the Upgrade Note must say
  "full install", not "update flow"; I caught this while verifying against `harness-update/SKILL.md`.
- The placeholder resolver only substitutes `{{PROJECT_NAME}}` and `{{MONOREPO_FRAMEWORK}}`;
  `{{PROJECT_REVIEW_POLICY}}` is intentionally a project-owned region left verbatim, exactly like
  `{{PROJECT_GOTCHAS}}`. No resolver change was needed — reusing `harness_resolve_placeholders`
  already gives the right behavior for REVIEW.md.

## If I did it again

- Reach for a temp git repo + `--from <bundle>` smoke test earlier; the install script refuses to run
  inside the template repo itself ("refusing to install from the installed bundle"), so an isolated
  consumer clone is the only fast way to prove fresh + pre-existing paths end to end.

## Related decisions

- **Auto-install (user-confirmed)**: even though the review skill would otherwise fall back to
  identical built-in defaults, shipping a real root `REVIEW.md` removes the silent gap and gives every
  project a visible, editable policy file.
- **Never overwrite an existing `REVIEW.md` (user-confirmed)**: mirrors the `AGENTS.md` contract, so
  a project that tuned its policy keeps it across re-installs.
- **`0.1.0-rc.2`**: mid-`-rc.*` settling of a shared template — a prerelease bump matches the
  existing policy (breaking changes in later `rc`s don't need a MAJOR).
- **No `changelogs/version-0.1.0-rc.2.md` prompt**: the change is fully handled by the install/update
  scripts themselves; per `changelogs/README.md` a prompt exists only for commands/follow-ups the
  manifests can't express, and none exists here.
