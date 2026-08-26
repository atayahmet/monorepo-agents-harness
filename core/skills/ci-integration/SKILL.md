---
name: ci-integration
description: Detect the target project's CI provider and help wire core/scripts/memory-gate.sh into it — full automation for GitHub Actions (writes a new, dedicated workflow file with consent), guided snippets for GitLab/Bitbucket/CircleCI (single-pipeline-file formats that cannot be safely auto-integrated via a separate file), or an opt-in GitHub Actions starter when no provider is detected. Use when the user types /monorepo-harness-ci, or asks to set up or check CI enforcement for the harness.
---

# CI Integration

Wires `core/scripts/memory-gate.sh` into whichever CI provider the target project actually uses,
instead of leaving it to a generic "add this to your CI" instruction. The engine is
`core/scripts/detect-ci-provider.sh` (detection only — it never writes anything); this skill decides
what to do with the result.

**Tiered by what each CI format actually supports**: GitHub Actions natively supports multiple
independent workflow files, so a new file just works — full automation. GitLab, Bitbucket Pipelines,
and CircleCI each read exactly **one** pipeline file, so a separate file would never run
automatically without at least a one-line addition to that file — for those, this skill detects and
guides, but does not write anything itself. This is a deliberate scope boundary, not an oversight.

## Workflow

1. **Detect**:
   ```bash
   bash .agents/monorepo-agents-harness/core/scripts/detect-ci-provider.sh --provider
   ```

2. **Branch on the result**:

### `github-actions` — automatic (with consent)

- Check whether `.github/workflows/harness-memory-gate.yml` already exists. If it does, report that
  and stop — do not overwrite it; suggest the user reviews/edits it manually if they want changes.
- Otherwise, show the snippet below and ask: **"Add this CI workflow file?"** Never write without an
  explicit affirmative in the current turn — same discipline as `agents-md-merge`'s "Apply this
  merge to AGENTS.md?" gate.
- On yes, write it verbatim to `.github/workflows/harness-memory-gate.yml`. On no, write nothing.

```yaml
name: harness-memory-gate
on: [pull_request, push]
jobs:
  memory-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run agent-workflow memory-gate
        run: bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

### `gitlab` — guided only

GitLab reads a single `.gitlab-ci.yml` by default. Show this job and tell the user to paste it under
their existing `stages:`/jobs (adjusting `stage:` to match their pipeline), or — if they already use
`include:` — save it as its own file and add an `include: - local: '<path>'` line themselves. **Do
not** call Write or Edit on `.gitlab-ci.yml` yourself.

```yaml
memory-gate:
  stage: test
  script:
    - bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

### `bitbucket` — guided only

Bitbucket Pipelines reads a single `bitbucket-pipelines.yml`. Show this step and tell the user to
add it to the relevant pipeline section (e.g. under `pipelines: default:` or a specific branch
pipeline). **Do not** call Write or Edit on `bitbucket-pipelines.yml` yourself.

```yaml
- step:
    name: Harness memory-gate
    script:
      - bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

### `circleci` — guided only

CircleCI reads a single `.circleci/config.yml`. Show this job + workflow entry and tell the user to
merge the `memory-gate` job into their existing `jobs:` map and reference it from a `workflows:`
entry (merge with existing workflows, don't replace them). **Do not** call Write or Edit on
`.circleci/config.yml` yourself.

```yaml
jobs:
  memory-gate:
    docker:
      - image: cimg/base:current
    steps:
      - checkout
      - run:
          name: Run agent-workflow memory-gate
          command: bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
workflows:
  harness:
    jobs:
      - memory-gate
```

### `unknown` — opt-in starter

Report that no CI provider was detected (looked for `.github/workflows/`, `.gitlab-ci.yml`,
`bitbucket-pipelines.yml`, `.circleci/config.yml`). Ask whether to scaffold a starter GitHub Actions
workflow. On yes, write the same snippet as the `github-actions` case above, to the same path. On
no, stop — do not write anything.

## Consent and safety

- Only the `github-actions` path (auto or opt-in-starter) ever writes a file, and only after an
  explicit "yes" in the current turn.
- Always check for an existing `harness-memory-gate.yml` before writing; never silently overwrite.
- The `gitlab`/`bitbucket`/`circleci` paths never call Write or Edit — guidance only.

## Edge cases

- **Multiple provider markers present** (e.g. both `.gitlab-ci.yml` and `.circleci/config.yml`):
  the detector returns the first match in its fixed order (github-actions > gitlab > bitbucket >
  circleci). If this seems surprising given the repo's actual setup, say so explicitly and mention
  the other marker(s) found.
- **Harness not yet installed**: nothing to detect against — this skill is inactive until Phase 1 of
  `INSTALL.md` is complete.
