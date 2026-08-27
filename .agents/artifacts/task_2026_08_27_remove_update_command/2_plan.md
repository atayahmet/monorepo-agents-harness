---
phase: plan
date: 2026-08-27
slug: remove_update_command
status: approved
---

# Plan: Remove per-adapter harness update commands; add a README update prompt

## Step 0 — Delete adapter entry points
Delete `adapters/claude-code/.claude/commands/monorepo-harness/update.md` (+ empty
`monorepo-harness/` dir), `adapters/opencode/.opencode/commands/monorepo-harness-update.md`,
`adapters/codex/.agents/skills/monorepo-harness-update/SKILL.md` (+ dir).

## Step 1 — Manifests
Remove one `copy` row each from `adapters/{claude-code,opencode,codex}/manifest.txt`.

## Step 2 — Shared skill wording
Update `core/skills/harness-update/SKILL.md` frontmatter `description` and the opening "backing every
adapter's … commands" line to say the commands are gone and the workflow is run from the README
prompt / directly.

## Step 3 — Adapter docs
In each adapter `README.md`: drop the update bullet and the "### /monorepo-harness…-update — Check
for harness updates" section; add a short "Checking for harness updates" note pointing at the README
prompt / shared skill. In each adapter `INSTALL.md`: reword the "Update check" table row to drop the
slash-command pointer.

## Step 4 — PORTABILITY.md
Update the update-check/upgrade matrix row (no adapter command → "no adapter command — follow the
README prompt"), the codex slash-commands note, and the "Ship the update-check command too" guidance.

## Step 5 — Root README.md
- Feature bullet: replace "a `/monorepo-harness:update` command" with "a README Update prompt".
- Scenario 5: replace "runs `/monorepo-harness:update`" with pasting the README prompt.
- After the install prompt block: add a new "### Or update from the repo" paste-in prompt mirroring
  the install one (check → follow `core/skills/harness-update/SKILL.md` end to end → consent gates →
  audit → no commit without asking).
- Replace the "can update itself later with `/monorepo-harness:update`…" line.
- Adapter table rows 423-425: drop the update-command tokens.
- Root `INSTALL.md` §7: point at the README prompt instead of the commands.

## Step 6 — Version + CHANGELOG
`VERSION` → `0.1.0-rc.4`; CHANGELOG: `[0.1.0-rc.4]` section (Removed + Changed + Upgrade Notes) and
update Unreleased compare + add the rc.4 tag link. No changelogs prompt file (manifest-only removal).

## Step 7 — Verify
`bash -n` all `core/scripts/*.sh`; grep for stale refs; scratch consumer fresh + `--refresh` install
of all 3 adapters + `audit-install.sh --against <repo>` = 0, no update files land, shared
skill/script present; INSTALL.md ≤ 100 lines.

## Step 8 — State + commit
Write task artifacts (1_spec, 2_plan, 3_memory, 4_verify) + index; update session-log/lessons/todo.
Commit code first, then memory/verify, per prior convention.
