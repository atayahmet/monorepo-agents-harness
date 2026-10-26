# Upgrade notes for 0.4.0-rc.27

This release adds a dedicated security review at the end of a build (issue #53). No commands to run and no manual migrations are required — the new files ship via the bundle and adapter manifests.

**What changed (for reference):**
- New skill: `core/skills/security-review/SKILL.md`
- New commands: `monorepo-harness-security-review` in Claude Code, Codex, and OpenCode adapters
- Updated: `core/skills/agent-workflow/SKILL.md`, `core/skills/pr-review/SKILL.md`, all three `*-build` adapter stubs, and adapter manifests

If you have an installed copy, run `core/scripts/install-harness.sh --sync-only` and `core/scripts/install-adapter.sh <agent> --refresh` to pick up the new files.
