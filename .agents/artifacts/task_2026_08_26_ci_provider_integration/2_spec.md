---
phase: spec
date: 2026-08-26
slug: ci_provider_integration
---

# Spec: CI/CD integration — detect-ci-provider.sh + ci-integration skill

## Scope

**In:** `detect-ci-provider.sh`, `ci-integration` skill (GH Actions auto-write + guided snippets for
GitLab/Bitbucket/CircleCI + unknown fallback), three adapter command/skill files, doc updates,
`0.8.0` version bump.

**Out:** automatic GitLab `include:` wiring, automatic Bitbucket/CircleCI job insertion into the
existing single pipeline file (deliberately out of scope, see Faz 2 plan's "Kapsam dışı"); Faz 3
(PR review) and Faz 4 (intent capture).

## Behavioral contract

- **Input:** a target repo's root, inspected for `.github/workflows/`, `.gitlab-ci.yml`,
  `bitbucket-pipelines.yml`, `.circleci/config.yml`.
- **Output:** `detect-ci-provider.sh --provider` prints one of `github-actions`, `gitlab`,
  `bitbucket`, `circleci`, `unknown`. The `ci-integration` skill, invoked via `/monorepo-harness-ci`
  on any adapter, either (a) writes a new `.github/workflows/harness-memory-gate.yml` after explicit
  consent (github-actions only), or (b) prints the relevant snippet + paste location (gitlab/
  bitbucket/circleci), or (c) reports "unknown" and offers an opt-in GH Actions starter.
- **Side effects:** at most one new file (`.github/workflows/harness-memory-gate.yml`), and only
  with explicit consent in the same turn; no other provider path writes anything.

## API / contracts

- `detect-ci-provider.sh [--provider]` — no-arg mode prints `ci-provider: <name>`; `--provider`
  prints just the bare name. Exit `0` always (detection never "fails," `unknown` is a valid result).
- No change to any existing script's CLI.

## Data model

N/A — no persisted/transmitted application data model touched; this is tooling/workflow.

## Acceptance criteria

- [ ] `detect-ci-provider.sh --provider` returns the correct name for all 4 known markers and
      `unknown` when none are present.
- [ ] `ci-integration` skill's GH Actions path never writes `.github/workflows/harness-memory-gate.yml`
      without an explicit affirmative in the same turn, and refuses to silently overwrite an existing
      file of that name.
- [ ] `ci-integration` skill's GitLab/Bitbucket/CircleCI paths write nothing to disk — verified by
      inspecting the skill's own instructions for any Write/Edit directive under those branches
      (there must be none).
- [ ] All three adapters expose `/monorepo-harness-ci` as a thin pointer to
      `core/skills/ci-integration/SKILL.md` (no duplicated logic), matching the exact structural
      pattern of the existing `monorepo-harness-build`/`monorepo-harness-update` files.
- [ ] `PORTABILITY.md`'s new capability row, `adapters/AGENTS.md` Hard Rule 6, `README.md`, and
      `INSTALL.md` all reference the new capability consistently.
- [ ] `core/VERSION` = `0.8.0`; `CHANGELOG.md` has a `[0.8.0]` entry with Upgrade Notes;
      `changelogs/version-0.8.0.md` exists following `changelogs/README.md`'s format.

## Test / verification plan

- `bash -n core/scripts/detect-ci-provider.sh` — syntax check.
- Scratch git-init'd directory (session scratchpad, same pattern as Faz 1): create each of the four
  provider markers one at a time (`.github/workflows/`, `.gitlab-ci.yml`, `bitbucket-pipelines.yml`,
  `.circleci/config.yml`), run `detect-ci-provider.sh --provider` after each, confirm the expected
  name; run once with none present, confirm `unknown`.
- Extract the embedded GH Actions YAML from `ci-integration` SKILL.md and validate it parses as YAML
  (`python3 -c "import yaml; yaml.safe_load(open(...))"` or equivalent).
- Read back all three new adapter command/skill files and confirm each matches the exact frontmatter
  + numbered-steps structure of the existing build/update files (diff-by-eye against the templates
  read during planning).
- Dogfood: write this task's own `4_verify.md` recording the above, then `3_memory.md` referencing
  the commit SHA, matching the Faz 1 precedent exactly.

## Architectural constraints

- **Keep adapters thin** (`adapters/AGENTS.md` Hard Rule 1): all three new adapter files are pointer
  files; the actual detection/consent/write logic lives only in `core/scripts/detect-ci-provider.sh`
  and `core/skills/ci-integration/SKILL.md`.
- **Skill-template convention**: per the established single-file-skill pattern (all 4 existing
  skills), the GH Actions/GitLab/Bitbucket/CircleCI snippets live as fenced code blocks embedded
  directly in `ci-integration/SKILL.md` — no separate `templates/` or `ci-snippets/` directory.
- **No new hard dependency**: `detect-ci-provider.sh` uses only `git` + coreutils, matching every
  other `core/scripts/*.sh`.
- **Fail-safe, not fail-open, for writes**: unlike hooks (which fail open on missing deps), this
  skill's *write* path must never proceed without explicit consent — consistent with
  `agents-md-merge`'s consent discipline, not with the hooks' fail-open discipline (those are
  different concerns: a hook not firing is safe-by-default; a skill silently writing a file is not).
- **Non-functional:** no performance/security implications (static detection + markdown skill); the
  only compatibility constraint is CI-format correctness (valid YAML for the GH Actions snippet).
