---
phase: spec
date: 2026-08-27
slug: remove_update_command
status: approved
---

# Spec: Remove per-adapter harness update commands; add a README update prompt

## Why

The per-adapter `/monorepo-harness:update` (claude-code) and `/monorepo-harness-update` (opencode,
codex) entry points duplicate surface that belongs on the shared skill. Updating is an
agent-neutral operation the user can now trigger by pasting a prompt from the project README, which
also keeps the update entry point portable across any future agent without adding an adapter file.
Removing the slash commands de-clutters the command surface while keeping the full workflow intact.

## What

- Delete the three adapter update entry files:
  - `adapters/claude-code/.claude/commands/monorepo-harness/update.md` (and the now-empty
    `monorepo-harness/` subdir)
  - `adapters/opencode/.opencode/commands/monorepo-harness-update.md`
  - `adapters/codex/.agents/skills/monorepo-harness-update/SKILL.md` (and its dir)
- Remove the corresponding `copy` rows (one each) from the three `adapters/<agent>/manifest.txt`.
- Keep the shared `core/skills/harness-update/SKILL.md` + `core/scripts/harness-update.sh` in the
  bundle (they ship via the existing `core` manifest row) — the README prompt directs the agent at
  the skill.
- Update every reference so the removal is coherent:
  - `core/skills/harness-update/SKILL.md` frontmatter description + intro (drop the stale slash
    command names).
  - Adapter READMEs (remove the update bullet + feature section; add a short "Checking for harness
    updates" note pointing at the README prompt / skill).
  - Adapter INSTALL.md "Update check" table rows.
  - `PORTABILITY.md` capability-matrix row, the codex slash-commands note, and the "ship the
    update-check command too" guidance.
  - Root `README.md`: feature bullet, Scenario 5, the "can update itself later" line, the Adapter
    table rows, and **add a new "Or update from the repo" paste-in prompt** right after the existing
    "Or hand it to your agent" install prompt.
  - Root `INSTALL.md` §7 "Updating".
- Bump `VERSION` → `0.1.0-rc.4`, add a CHANGELOG section (Removed + Changed + Upgrade Notes). No
  `changelogs/version-X.Y.Z.md` prompt file: the removal is manifest-only.

## Non-goals

- No change to `core/skills/harness-update/SKILL.md`'s workflow steps themselves — only the
  description/intro wording.
- No change to `opencode.jsonc`, `.codex/*`, or any hook wiring (nothing registered the removed
  entry points there).
- No change to how memory-gate or CI works.

## Test / verification plan

1. `bash -n` all `core/scripts/*.sh`.
2. Grep the repo: no stale update-command references remain outside intentional/historical text
   (CHANGELOG describing the removal; the "There is no X command" notes; the skill header noting the
   removal).
3. Scratch consumer: `install-harness.sh` + all 3 `install-adapter.sh` (fresh and `--refresh`) →
   exit 0; `audit-install.sh --against <repo>` → exit 0; confirm **no** update command files land;
   confirm the shared skill/script still present in the bundle.
4. `INSTALL.md` stays ≤ 100 lines.
