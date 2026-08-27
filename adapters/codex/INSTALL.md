# codex adapter

Installs the agent harness for **Codex CLI**. The harness core (`core/`) is agent-agnostic — this
adapter only supplies Codex's *enforcement* wiring: project config, lifecycle hooks, and skills.
Read `../../INSTALL.md` first (core before any adapter) and `../../PORTABILITY.md` for the
mandatory-parity rule and semantic differences.

## Prerequisites

- Core installed (`../../INSTALL.md` Phase 1) — bundle, `AGENTS.md`, per-workspace `.agents/` dirs.
- Codex CLI with hooks enabled (project `.codex/config.toml` sets `[features] hooks = true`).
- `jq` on `PATH` — the hooks shell out to it. Verify: `jq --version`.

## Install

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh codex
```

That executes every row of [`manifest.txt`](manifest.txt) — the single source of truth for what this
adapter installs. Adding a file to this adapter means adding a manifest row, never a step here.
Re-running is safe and idempotent.

The script prints one line per row: `+` written, `=` already current, `~` left alone with a
proposal beside it, `.` skipped (`--refresh` mode). It ends with a `Needs you:` list if anything
requires your judgement.

**`.codex/config.toml` and `.codex/hooks.json` are never overwritten.** If you already have either,
the adapter's version is written as `<file>.harness-proposed` and reported:

```bash
git diff --no-index .codex/config.toml .codex/config.toml.harness-proposed
```

For `config.toml` the merge is one line — `hooks = true` under `[features]`. The first time Codex
starts it asks you to review/trust the non-managed command hooks: run `/hooks` in the Codex TUI and
trust them (or use `--dangerously-bypass-hook-trust` for one-off automation).

The hooks are independent and fail-open (missing `jq`, git root or bundle → exit 0, no block), so
they coexist with your existing hooks safely.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | root `AGENTS.md` | — (read natively by Codex) |
| Plan/spec/memory + monorepo templates | `core/skills/**/SKILL.md` | symlinked into `.agents/skills/` (auto-registration) |
| Plan/spec reminder (start of impl.) | — | `PostToolUse[update_plan]` hook (`systemMessage` reminder) |
| Session-start reminder | — | `SessionStart` hook (`additionalContext` reminder) |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` | `/monorepo-harness-build` skill |
| Memory-gate (incl. `4_verify.md` when required) | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (soft reminder) + the universal git/CI gate (hard) |
| Verifier | `core/skills/agent-workflow/SKILL.md` Phase 4 | — (no subagent primitive; run the same verification inline) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `/monorepo-harness-update` skill |
| CI wiring · PR review · intent capture | `core/skills/{ci-integration,pr-review,intent-workflow}/SKILL.md` | `/monorepo-harness-ci` · `/monorepo-harness-review` · `/monorepo-harness-intent` skills |

## Verify

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
jq . .codex/hooks.json >/dev/null && echo "hooks.json OK"
python3 -c "import sys; m='tomllib' if sys.version_info>=(3,11) else 'toml'; __import__(m).load(open('.codex/config.toml','rb' if m=='tomllib' else 'r')); print('config.toml OK')"
```

The audit reports every missing or stale entry point by exact path (it reads the same
`manifest.txt`), so it is the authoritative check; the other two only confirm your merged config
files still parse. Then start Codex and type `/` — the harness skills must appear in the list.

For the end-to-end memory-gate smoke test see `../../INSTALL.md` §5.

## Notes / semantic differences

- **The `Stop` hook cannot hard-block.** Codex CLI ignores `continue: false` from `Stop` hooks when
  ending a turn; the hook can only surface a `systemMessage`. The **universal hard gate**
  (`memory-gate.sh` as `.git/hooks/pre-commit` and/or a CI step, wired by `install-harness.sh`) is
  what actually enforces `3_memory.md`/`4_verify.md`. Do not skip it.
- **No `ExitPlanMode` tool.** Codex toggles plan mode via `/plan`; the only plan-related local tool
  is `update_plan`, so the adapter hooks `PostToolUse[update_plan]` instead.
- **Commands ship as skills.** Codex has no user-defined slash commands, but skills appear in the
  slash list — hence `.agents/skills/monorepo-harness-*/SKILL.md`.
- **`--refresh`** re-applies only the copy/symlink rows and never touches config files — the mode a
  harness update runs (`core/skills/harness-update/SKILL.md` step 7.5).
