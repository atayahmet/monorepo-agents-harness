---
description: Detect the target project's CI provider and wire memory-gate.sh into it
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/ci-integration/SKILL.md` exactly:

1. Run `bash .agents/monorepo-agents-harness/core/scripts/detect-ci-provider.sh --provider`.
2. For `github-actions`: check for an existing `.github/workflows/harness-memory-gate.yml`; if
   absent, show the workflow snippet and ask "Add this CI workflow file?" before writing.
3. For `gitlab`/`bitbucket`/`circleci`: show the matching snippet and where to paste it — do not
   write any file yourself.
4. For `unknown`: report it and offer an opt-in GitHub Actions starter.

Never write a CI file without explicit consent in the current turn.
