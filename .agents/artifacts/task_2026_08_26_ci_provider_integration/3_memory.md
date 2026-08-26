---
phase: memory
date: 2026-08-26
slug: ci_provider_integration
commits: [0719d92f59b18c197b0f5b12459ee6a77b9341ce]
---

# Memory: CI/CD integration — detect-ci-provider.sh + ci-integration skill

## What was done (single paragraph)

Added `core/scripts/detect-ci-provider.sh` and `core/skills/ci-integration/SKILL.md`, wired into
all three adapters as `/monorepo-harness-ci`. GitHub Actions gets full automation (a new, dedicated
`.github/workflows/harness-memory-gate.yml`, written only after explicit consent); GitLab,
Bitbucket, and CircleCI — each of which reads exactly one pipeline file — get provider-matched
snippets and paste-location guidance instead of an automatic edit. Propagated through
`PORTABILITY.md`, `adapters/AGENTS.md`, `README.md`, `INSTALL.md`, and released as v0.8.0.

## Surprising findings

- The original Faz 2 roadmap plan assumed "write a separate dedicated file" would work uniformly
  across CI providers. Closer inspection during this task's own planning showed that's only true
  for GitHub Actions — GitLab, Bitbucket Pipelines, and CircleCI each read a single pipeline file by
  default, so a fully separate file never runs without at least a one-line addition to that file.
  Caught before implementation (via `EnterPlanMode` + an explicit `AskUserQuestion` to the user)
  rather than discovered after shipping something that silently didn't work for 3 of 4 providers.
- Neither `yq` nor PyYAML was available on this machine for YAML validation; Ruby's built-in
  `YAML.safe_load` (present by default on macOS) worked as an equally valid substitute.
- All 4 existing skills in this repo are single-file (`core/skills/<name>/SKILL.md`, no companion
  `templates/` directory) — this shaped the decision to embed the CI snippets directly as fenced
  code blocks in `ci-integration/SKILL.md` rather than creating a new `core/governance/ci-snippets/`
  directory, which the original roadmap draft had proposed before this closer read of the codebase.

## If I did it again

Same approach. The tiered (automatic vs. guided) design is the right level of ambition for a single
release — attempting real GitLab `include:`/Bitbucket/CircleCI auto-wiring in the same pass would
have meant building and testing three more provider-specific merge strategies, each with its own
edge cases, inside one task. Better as a deliberately separate future phase if ever needed.

## Related decisions

- Consent discipline for the GitHub Actions write path mirrors `agents-md-merge`'s "Apply this
  merge to AGENTS.md?" gate exactly (explicit question, no write without an affirmative in the same
  turn, existing-file check before proposing anything) — reusing an established pattern rather than
  inventing a new consent style for this one skill.
- Kept `/monorepo-harness-ci` flat (not namespaced like claude-code's `:update`) across all three
  adapters for naming consistency, since there was no principled reason found in the existing code
  for update's namespacing (it reads as historical, not intentional) and `build` is already flat.
