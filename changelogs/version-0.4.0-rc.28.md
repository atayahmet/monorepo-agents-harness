# Upgrade notes for 0.4.0-rc.28

This release adds the team registry (issue #55). No commands to run and no manual migrations are
required — the new files ship via the bundle and adapter manifests.

**What changed (for reference):**
- New: `core/scripts/team-infer.sh`, the `/monorepo-harness-team` command in every adapter.
- Rewritten: `core/scripts/team.sh`; new `tracker-issue.sh --assignee`.
- Updated: `core/root-AGENTS.md` (new rule 8: no hardcoded people or IDs, forward-only departure), the
  intent-workflow and self-improvement skills.

If you have an installed copy, run `core/scripts/install-harness.sh --sync-only` and
`core/scripts/install-adapter.sh <agent> --refresh`. The consent-gated `AGENTS.md` merge in the update
flow offers the new root rule. To start using the registry, run `/monorepo-harness-team`.
