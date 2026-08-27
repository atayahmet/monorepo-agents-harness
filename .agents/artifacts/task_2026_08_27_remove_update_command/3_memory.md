---
phase: memory
date: 2026-08-27
slug: remove_update_command
commits: [ee98ad14d7ae45742ecaf444335d589250f7fa57]
---

# Memory: Remove per-adapter harness update commands; add a README update prompt

## What was done (single paragraph)

Removed the per-adapter harness update entry points — `/monorepo-harness:update` on claude-code,
`/monorepo-harness-update` on opencode and codex — deleting three adapter files (and their manifest
`copy` rows, plus claude-code's now-empty `monorepo-harness/` subdirectory). Kept the shared
`core/skills/harness-update/SKILL.md` and `core/scripts/harness-update.sh` in the bundle (they ship
via the existing `core` manifest row). Added an **"Or update from the repo"** paste-in prompt to the
project README, right after the existing "Or hand it to your agent" install prompt, that drives the
same check → consent-gated upgrade → AGENTS.md reconciliation → audit workflow by pointing the agent
at the shared skill. Updated the skill's description/intro, adapter READMEs + INSTALL "Update check"
rows, PORTABILITY matrix row / codex note / porting guidance, root README (feature bullet, Scenario
5, self-update line, adapter table) and INSTALL.md §7. Bumped VERSION → `0.1.0-rc.4` with a CHANGELOG
Removed/Changed/Upgrade-Notes section.

## Surprising findings

- **Removing an entry point is manifest-only and asymmetric with adding one.** An adapter `--refresh`
  re-applies the rows the manifest still lists (idempotent) but never deletes files the new manifest
  no longer lists. So an existing consumer keeps a stale `/monorepo-harness:update` until it runs
  refresh or an update. It's harmless (it only points at the still-valid shared skill) — the CHANGELOG
  Upgrade Note must say this, and `audit-install.sh --against <new release>` will flag the stale file
  as an extra, which is expected, not a regression.
- **The update workflow never needed an adapter at all.** It's `git ls-remote` + running the
  installed installers; the per-adapter files were pure indirection to the shared skill. A paste-in
  README prompt (agent-neutral, like the install prompt already is) gives the same result from any
  agent with strictly less surface to maintain.
- **`opencode.jsonc` and the codex hooks needed no change.** Nothing registered the update entry
  points there — opencode's commands come from `.opencode/commands/`, codex's slash commands from
  auto-registered `.agents/skills/`; deleting the files and manifest rows removes them from the slash
  list automatically.

## If I did it again

- Check root `INSTALL.md` §7 "Updating" in the same sweep as the README feature list — it had a
  second, easy-to-miss live reference to both command names that a targeted grep caught only later.
  When removing a named feature, grep the whole tree (not just the obvious docs) before committing.

## Related decisions

- **Keep the shared skill/script (user-confirmed)** — the README prompt delegates to the installed
  `.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md`, preserving the full
  consent + reconcile + audit workflow rather than replacing it with ad-hoc clones.
- **Place the new prompt as a paste-any-agent block (user-confirmed)** right after the existing
  install prompt, mirroring its structure (agent-neutral check, then "follow the skill, don't
  hand-copy", two consent gates, no commit without asking).
- **`0.1.0-rc.4`, no changelogs prompt file.** Removal is manifest-only per AGENTS.md rule 2 — a
  prompt file would have been redundant; the CHANGELOG Upgrade Note covers the refresh semantics.
