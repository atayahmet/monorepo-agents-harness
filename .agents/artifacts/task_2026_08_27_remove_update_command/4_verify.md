---
phase: verify
date: 2026-08-27
slug: remove_update_command
---

# Verify: Remove per-adapter harness update commands; add a README update prompt

## Verification run

All from repo root unless noted; exit codes shown.

- `for f in core/scripts/*.sh; do bash -n "$f" || echo FAIL; done` → all pass (unchanged scripts,
  sanity).
- Manifests: `grep update adapters/{claude-code,opencode,codex}/manifest.txt` → **no update rows
  remain**.
- Stale-reference sweep: the only remaining mentions of `monorepo-harness:update` /
  `monorepo-harness-update` are **intentional**: the CHANGELOG's Removed/Upgrade-Notes prose, the
  adapter READMEs' "There is no /monorepo-harness…update command in this adapter" pointer notes, and
  the skill header noting the command is gone. Root INSTALL.md §7 no longer lists the slash commands.
- Root `INSTALL.md` = **87 lines** (≤ 100 required; safe by 13).
- Scratch consumer under /tmp/folders/…/opencode (fresh git monorepo, `apps/api`, `package.json`):
  - `install-harness.sh --from <repo> --no-git-hook` → exit 0.
  - `install-adapter.sh` for claude-code, opencode, codex → exit 0 each (fresh).
  - **No update command files installed**: no
    `.claude/commands/monorepo-harness/update.md`, `.claude/commands/monorepo-harness-update.md`,
    `.opencode/commands/monorepo-harness-update.md`, or `.agents/skills/monorepo-harness-update`.
  - Shared resources still in the bundle: `.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md`
    and `.agents/monorepo-agents-harness/core/scripts/harness-update.sh` both present.
  - `audit-install.sh --against <repo>` → **exit 0** ("audit-install: clean — installed state
    matches").
  - Idempotence: `install-adapter.sh <agent> --refresh` for all three → exit 0 each; final
    `audit-install.sh --against <repo>` → exit 0.
- Scratch cleaned up afterward.

## Acceptance criteria results

- [x] Three adapter update files deleted + claude's empty `monorepo-harness/` subdir removed.
- [x] One `update` copy row removed from each of the 3 adapter manifests (grep confirms none remain).
- [x] Shared `core/skills/harness-update/SKILL.md` + `core/scripts/harness-update.sh` kept in bundle
  (verified present in scratch).
- [x] `core/skills/harness-update/SKILL.md` description + intro updated to drop the stale command
  names.
- [x] Adapter READMEs: update bullet + section removed, "Checking for harness updates" pointer note
  added.
- [x] Adapter INSTALL.md "Update check" rows reworded (no slash-command pointer).
- [x] PORTABILITY.md matrix row, codex note, and porting guidance updated.
- [x] Root README.md: feature bullet, Scenario 5, self-update line, adapter-table rows updated; new
  "Or update from the repo" prompt block added after the install prompt.
- [x] Root INSTALL.md §7 points at the README prompt instead of the slash commands.
- [x] `VERSION` = `0.1.0-rc.4`; CHANGELOG `[0.1.0-rc.4]` section (Removed/Changed/Upgrade Notes) +
  Unreleased compare & tag link updated; **no** `changelogs/version-0.1.0-rc.4.md` (manifest-only
  removal).
- [x] `bash -n` clean; scratch fresh + refresh install + audit all pass.

## Deviations

- None. Design choices (keep shared skill; README prompt placement) match the user's confirmation
  captured in this task's spec.
