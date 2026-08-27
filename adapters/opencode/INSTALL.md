# opencode adapter

Installs the agent harness for **opencode** (TUI/CLI). The harness core (`core/`) is agent-agnostic
— this adapter only supplies opencode's *enforcement* wiring: slash commands and config. Read
`../../INSTALL.md` first (core before any adapter) and `../../PORTABILITY.md` for the
mandatory-parity rule and semantic differences.

## Prerequisites

- Core installed (`../../INSTALL.md` Phase 1) — bundle, `AGENTS.md`, per-workspace `.agents/` dirs.
- opencode installed; `git` available.

## Install

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh opencode
```

That executes every row of [`manifest.txt`](manifest.txt) — the single source of truth for what this
adapter installs. Adding a file to this adapter means adding a manifest row, never a step here.
Re-running is safe and idempotent.

The script prints one line per row: `+` written, `=` already current, `~` left alone with a
proposal beside it, `.` skipped (`--refresh` mode). It ends with a `Needs you:` list if anything
requires your judgement.

**`opencode.jsonc` is never overwritten.** If you already have one (or an `opencode.json`), the
adapter's version is written as `opencode.jsonc.harness-proposed` and reported. The merge is the
`instructions` entries, which feed opencode the same `SKILL.md` templates every adapter reuses:

```bash
git diff --no-index opencode.jsonc opencode.jsonc.harness-proposed
```

`AGENTS.md` is loaded by opencode natively — no extra wiring for rules.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | `AGENTS.md` (native to opencode) | — (no extra wiring) |
| Plan/spec/memory + monorepo templates | `core/skills/**/SKILL.md` | referenced via `opencode.jsonc` `instructions` |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` + `core/scripts/task-state.sh` | `/monorepo-harness-spec` · `/monorepo-harness-plan` · `/monorepo-harness-build` |
| Memory-gate (incl. `4_verify.md` when required) | `core/scripts/memory-gate.sh` | the universal git/CI gate (hard) — the only enforcement here |
| Verifier | `core/skills/agent-workflow/SKILL.md` Phase 4 | — (no subagent primitive; run the same verification inline) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | follow the README "Update from the repo" prompt, or run the skill directly (no command) |
| CI wiring · PR review · intent capture | `core/skills/{ci-integration,pr-review,intent-workflow}/SKILL.md` | `/monorepo-harness-ci` · `/monorepo-harness-review` · `/monorepo-harness-intent` |

## Verify

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
opencode --help >/dev/null 2>&1 && echo "opencode present"
```

The audit reports every missing or stale command file by exact path (it reads the same
`manifest.txt`), so it is the authoritative check. Then start opencode and type
`/monorepo-harness-spec` — the harness commands must register.

For the end-to-end memory-gate smoke test see `../../INSTALL.md` §5.

## Notes / semantic differences

- **The memory-gate is enforced only by the universal hard gate.** opencode cannot block its own
  stop, so `memory-gate.sh` as `.git/hooks/pre-commit` and/or a CI step (wired by
  `install-harness.sh`) *is* the enforcement. If that slot was already taken, the installer says so
  in its `Needs you:` list — act on it, or the gate is unenforced.
- **No skill symlinks.** opencode reads the shared `SKILL.md` files through `opencode.jsonc`
  `instructions`, so there is nothing to link into a skills directory.
- **`--refresh`** re-applies only the copy rows and never touches `opencode.jsonc` — the mode a
  harness update runs (`core/skills/harness-update/SKILL.md` step 7.5).
