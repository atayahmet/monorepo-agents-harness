---
phase: verify
date: 2026-08-27
slug: sdlc_commands
---

# Verify: Per-SDLC-stage commands with a gated artifact chain

## Verification run

All commands from repo root unless noted; exit codes shown.

`for f in core/scripts/*.sh; do bash -n "$f" || echo FAIL; done` → all 10 scripts pass (incl. new `task-state.sh`).

`task-state.sh` smoke cases (fixtures created in a temp dir; expected exit shown):
- `check-intent-approved` on approved intent → **0**; on pending → **1** ("not approved (status: 'pending')"); on rejected → **1**; on missing file → **1**.
- `check-spec` on valid spec → **0**; on a plan file → **1** ("not a spec (phase: 'plan')").
- `check-plan` on valid plan → **0**; on missing file → **1**.
- `check-chain` with un-approved `0_intent.md` → **1**; with approved `0_intent.md` → **0** ("chain valid … intent approved"); ad-hoc (no `0_intent.md`) → **0** ("ad-hoc (no intent required)"); missing `1_spec.md` → **1** ("missing 1_spec.md").
- No args / unknown subcommand → **2** (usage error).

Adapted install into a scratch git monorepo (`/var/folders/.../opencode/sdlc-scratch`, `apps/api`, `package.json`):
- `install-harness.sh --from <repo> --no-git-hook` → exit 0; `task-state.sh` present in the installed bundle.
- `install-adapter.sh` for claude-code, opencode, codex → exit 0 (all three).
- Command files present in the scratch: claude-code `.claude/commands/monorepo-harness-{spec,plan,build}.md`; opencode `.opencode/commands/monorepo-harness-{spec,plan,build}.md`; codex `.agents/skills/monorepo-harness-{spec,plan,build}/SKILL.md`.
- Idempotence: `install-adapter.sh <agent> --refresh` re-run for claude-code, opencode, codex → exit 0 each.
- `audit-install.sh --against <repo>` in the scratch → **exit 0** ("audit-install: clean — installed state matches").

Config validity (source templates): `jq . adapters/claude-code/.claude/settings.json` → OK; `jq . adapters/codex/.codex/hooks.json` → OK; `tomllib` parse of `adapters/codex/.codex/config.toml` → OK. (`opencode.jsonc` is unchanged by this task — no new skill registration was needed; my initial inline jsonc-strip test false-failed because it stripped the `//` inside the `https://` URL.)

Note: `audit-install.sh` inside this template repo itself returns exit 2 ("no bundle to compare against") — structural; all adapter checks were proven in the scratch consumer above.

## Acceptance criteria results

- [x] New `core/scripts/task-state.sh` (4 read-only subcommands) — all smoke cases above pass.
- [x] `/monorepo-harness-spec`: refuses to write on a non-approved intent; copies approved intent as `0_intent.md`; ad-hoc without a path (per the stub body + skill Phase 1).
- [x] `/monorepo-harness-plan`: validates spec; asks about plan mode, proceeds without it on "no" (stub body + skill Phase 2).
- [x] `/monorepo-harness-build`: `check-chain` gates implementation; auto-writes memory/verify on completion (stub body + skill Phase 3/4); old "write spec+plan" behavior removed.
- [x] `agent-workflow/SKILL.md` — stage-commands table + gating + per-phase entry points added.
- [x] New `-spec`/`-plan` command files + rewritten `-build` for all 3 adapters; manifests updated (audited clean in scratch).
- [x] Docs updated in the same commit: `PORTABILITY.md`, each adapter `README.md`/`INSTALL.md`, root `README.md`.
- [x] `VERSION` = `0.1.0-rc.3`; CHANGELOG section + Upgrade Notes; `changelogs/version-0.1.0-rc.3.md` prompt written.
- [x] `bash -n` clean on every `core/scripts/*.sh`; scratch install + adapter audit exit 0.

## Deviations

- None. The intent-approval policy is conditional (intent-seeded tasks only), per the user's explicit confirmation; ad-hoc tasks are exempt.
