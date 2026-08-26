---
phase: verify
date: 2026-08-26
slug: ci_provider_integration
---

# Verify: CI/CD integration — detect-ci-provider.sh + ci-integration skill

## Verification run

`bash -n core/scripts/detect-ci-provider.sh` → `syntax OK` (checked after creation and again before
this verification).

Scratch end-to-end run (fresh `git init`'d scratch dir under this session's scratchpad):

```
--- no CI markers ---       → unknown
--- github actions ---      → github-actions   (mkdir -p .github/workflows)
--- gitlab ---               → gitlab           (touch .gitlab-ci.yml)
--- bitbucket ---            → bitbucket        (touch bitbucket-pipelines.yml)
--- circleci ---             → circleci         (mkdir -p .circleci; touch .circleci/config.yml)
--- default (no-arg) ---     → "ci-provider: unknown"
```

YAML validation (Ruby's stdlib `YAML.safe_load`, since neither `yq` nor PyYAML were available on
this machine): extracted all 4 fenced ` ```yaml ` blocks from `core/skills/ci-integration/SKILL.md`
(GitHub Actions, GitLab, Bitbucket, CircleCI snippets) — all 4 parsed without error.

Read back all three new adapter files
(`adapters/claude-code/.claude/commands/monorepo-harness-ci.md`,
`adapters/opencode/.opencode/commands/monorepo-harness-ci.md`,
`adapters/codex/.agents/skills/monorepo-harness-ci/SKILL.md`) — each is a thin pointer to
`core/skills/ci-integration/SKILL.md` with no duplicated logic, matching the exact frontmatter +
numbered-steps shape of the existing `monorepo-harness-build`/`monorepo-harness-update` files read
during planning.

## Acceptance criteria results

- [x] `detect-ci-provider.sh --provider` returns the correct name for all 4 known markers and
      `unknown` when none are present — confirmed above (5 scenarios).
- [x] The `github-actions` path in `ci-integration/SKILL.md` states the existing-file check and the
      explicit "Add this CI workflow file?" consent question before any write instruction.
- [x] The `gitlab`/`bitbucket`/`circleci` sections each contain an explicit "Do not call Write or
      Edit on `<file>` yourself" instruction and no write directive.
- [x] All three adapters expose `/monorepo-harness-ci` as a thin pointer — confirmed by direct
      read-back and structural comparison against the build/update templates.
- [x] `PORTABILITY.md` (new capability row + semantic-differences bullet), `adapters/AGENTS.md`
      (Hard Rule 6), `README.md` (bullet + Documentation map + Adapters table), and `INSTALL.md`
      (new §11) all reference the new capability.
- [x] `core/VERSION` = `0.8.0`; `CHANGELOG.md` has a `[0.8.0]` entry with Added/Changed/Upgrade
      Notes and updated reference-link list; `changelogs/version-0.8.0.md` exists following
      `changelogs/README.md`'s standard section format.

## Deviations

None. One tooling note: neither `yq` nor PyYAML was available on this machine for YAML validation;
substituted Ruby's built-in `YAML.safe_load` (present by default on macOS), which is an equally
valid parser for this purpose — noted here rather than silently swapped without mention.
