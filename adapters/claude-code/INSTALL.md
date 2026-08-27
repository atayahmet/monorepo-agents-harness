# claude-code adapter

Installs the agent harness for **Claude Code**. The harness core (`core/`) is agent-agnostic — this
adapter only supplies Claude Code's *enforcement* wiring: two hooks, skill registration, the
harness commands and the verifier subagent. Read `../../INSTALL.md` first; the core must be
installed before any adapter.

## Prerequisites

- Core installed (`../../INSTALL.md` Phase 1) — bundle, `AGENTS.md`, per-workspace `.agents/` dirs.
- Claude Code with hooks enabled (a project `.claude/settings.json` is honored).
- `jq` on `PATH` — the hooks shell out to it. Verify: `jq --version`.

## Install

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code
```

That executes every row of [`manifest.txt`](manifest.txt) — the single source of truth for what this
adapter installs. Adding a file to this adapter means adding a manifest row, never a step here.
Re-running is safe and idempotent.

The script prints one line per row: `+` written, `=` already current, `~` left alone with a
proposal beside it, `.` skipped (`--refresh` mode). It ends with a `Needs you:` list if anything
requires your judgement.

**`.claude/settings.json` and the root `CLAUDE.md` are never overwritten.** If you already have
either, the adapter's version is written as `<file>.harness-proposed` and reported. For
`settings.json` the merge is two additions — append the `"ExitPlanMode"` matcher object under
`hooks.PostToolUse`, and the memory-gate block under `hooks.Stop`:

```bash
git diff --no-index .claude/settings.json .claude/settings.json.harness-proposed
```

Both hooks are independent and fail-open (missing `jq`, git root or bundle → exit 0, never blocks),
so they coexist with your existing hooks safely.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | `AGENTS.md` (native to Claude Code) | root `CLAUDE.md` = thin `@AGENTS.md` pointer |
| Plan/spec/memory + monorepo templates | `core/skills/**/SKILL.md` | symlinked into `.claude/skills/` (auto-registration) |
| Plan/spec reminder (plan-mode exit) | — | `PostToolUse[ExitPlanMode]` hook (inline reminder) |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` + `core/scripts/task-state.sh` | `/monorepo-harness-spec` · `/monorepo-harness-plan` · `/monorepo-harness-build` |
| Memory-gate (incl. `4_verify.md` when required) | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (**hard block**) |
| Verifier subagent | `core/skills/agent-workflow/SKILL.md` Phase 4 | `.claude/agents/verifier.md` (isolated, read-only) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `/monorepo-harness:update` |
| CI wiring · PR review · intent capture | `core/skills/{ci-integration,pr-review,intent-workflow}/SKILL.md` | `/monorepo-harness-ci` · `/monorepo-harness-review` · `/monorepo-harness-intent` |

## Verify

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh
jq . .claude/settings.json >/dev/null && echo "settings.json OK"
```

The audit reports every missing or stale entry point by exact path (it reads the same
`manifest.txt`), so it is the authoritative check. `jq` only confirms your merged settings file is
still valid JSON. Then start Claude Code and type `/` — the harness commands must appear.

For the end-to-end memory-gate smoke test (the core enforcement, identical for every adapter) see
`../../INSTALL.md` §5.

## Notes

- **Skills are symlinks, not copies.** `.claude/skills/agent-workflow` and `.claude/skills/monorepo`
  point into `.agents/monorepo-agents-harness/core/skills/`, so a harness update refreshes them with
  no re-copy. Frontmatter (`name`, `description`) must stay intact for auto-registration.
- **`--refresh`** re-applies only the copy/symlink rows and never touches config files. That is what
  a harness update runs (`core/skills/harness-update/SKILL.md` step 7.5) — re-running a config merge
  would duplicate hook entries; re-running a copy cannot.
