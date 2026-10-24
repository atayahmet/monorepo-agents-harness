## SDLC scenarios

The sections above describe *what exists*. This section shows *how it plays out*, end to end, using
the harness's actual commands and file formats. All five scenarios continue one running example —
`apps/api`, a workspace that already has a couple of prior tasks in its history — so later scenarios
can show the harness reusing what earlier ones produced (prior-art search, spec-compliance review,
an update months later).



### Scenario 5 — Updating the harness itself, reliably

Months later, upstream ships a new release. Someone types `/monorepo-harness-update` (or, with no
adapter installed, pastes the prompt in
[`core/prompts/harness-update.md`](core/prompts/harness-update.md)), which directs the active agent
to `core/skills/harness-update/SKILL.md`. It checks the installed version against upstream, reports
what changed, and asks **"Upgrade now?"**. On consent:

- The bundle is synced by **the new release's own installer** —
  `install-harness.sh --sync-only`, driven by `core/install-manifest.txt`, the very same code path a
  fresh install uses. No hand-maintained per-release file list (which is what used to let a new
  skill or command silently never reach an installed project) and no hand-copying by the agent.
  Every row is verified; an incomplete sync is reported, not silently accepted.
- Because this project already has the `claude-code` adapter installed, the update runs
  **`install-adapter.sh claude-code --refresh`** against the fresh bundle — any new harness-plumbing
  command added upstream since the last update (say, a future `/monorepo-harness-<something>`) shows
  up in `.claude/commands/` without anyone copying it by hand. `--refresh` deliberately skips the
  config rows, so your `.claude/settings.json` is never rewritten or double-appended.
- Root `AGENTS.md` is reconciled against the new `core/root-AGENTS.md` template via a three-way
  merge, shown as a diff, and written only after a separate explicit approval.
- `.agents/` working state — every intent, every task's plan/spec/memory/verify — is never touched.

The team's own task history, built up across Scenarios 1–4, survives every upgrade untouched;
only the harness's own machinery gets newer.

