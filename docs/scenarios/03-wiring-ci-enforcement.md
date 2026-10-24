## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).



### Scenario 3 — Wiring CI enforcement, whichever provider you actually use

The team wants the memory-gate enforced in CI, not just locally. Someone runs `/monorepo-harness-ci`.

`core/scripts/detect-ci-provider.sh --provider` inspects the repo and returns `github-actions`
(found `.github/workflows/`). Because GitHub Actions supports independent workflow files, this path
is **fully automatic**: the skill checks `harness-memory-gate.yml` doesn't already exist, shows the
exact file it's about to write, and asks **"Add this CI workflow file?"** — only on an explicit yes
does it write:

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

If the same repo used **GitLab** instead, the detector would return `gitlab`, and the skill would
switch to *guided-only*: GitLab reads a single `.gitlab-ci.yml`, so a separate file would never run
automatically. The skill shows the job snippet and tells the user exactly where to paste it — it
never calls `Write` or `Edit` on that file itself. Same tiering for Bitbucket Pipelines and
CircleCI. This isn't a missing feature; it's a deliberate boundary, because guessing at how to merge
into someone's single pipeline file is worse than not touching it.

