# Draft: 2_spec.md template enrichment (unreleased)

Not yet assigned a version. When this is released, fold the content below into a new
`## [X.Y.Z]` section in `CHANGELOG.md`, bump `core/VERSION`, and rename/rewrite this file as
`changelogs/version-X.Y.Z.md` following the format in `changelogs/README.md`.

## Summary

`2_spec.md` (`core/skills/agent-workflow/SKILL.md` Phase 2 template) gained two sections:

- **`## Data model`** — added after `## API / contracts`. Records fields/types/structure of any
  persisted or transmitted data the task reads or writes (table/column names, JSON payload shape,
  event schema). `N/A` when the task touches no data model.
- **`## Test / verification plan`** — added after `## Acceptance criteria`. States how each
  acceptance criterion is checked (command, test file, manual repro). `N/A` only for research-only
  tasks with no verifiable behavior change.
- **`## Architectural constraints`** wording expanded to explicitly cover non-functional
  requirements (performance, security, compatibility), not just layering/module boundaries.

## Why

`2_spec.md` is the only artifact file guaranteed to exist per task, and (since the artifact-index
search added in v0.6.0) it's what a future agent reads to judge whether prior work is relevant.
Two gaps kept resurfacing: no canonical home for data shape, and acceptance criteria with no tied
verification method. Scope was narrowed from a broader candidate list (which also included
Non-functional requirements and Open questions as standalone sections) to just these two, per
user decision — NFRs got folded into Architectural constraints instead, and Open questions was
judged redundant with plan.md's existing "Risks & assumptions".

## Upgrade notes (draft)

Additive only — existing `2_spec.md` files without these sections remain valid. No artifact-layout
break, no script/hook changes.

## Files touched

- `core/skills/agent-workflow/SKILL.md`
