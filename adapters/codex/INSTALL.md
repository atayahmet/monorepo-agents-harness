# codex adapter

Installs the agent harness for **Codex CLI**. The harness core (`core/`) is agent-agnostic — this
adapter only supplies Codex's *enforcement* wiring: project config, lifecycle hooks, and a skill.
Read `../../INSTALL.md` first (core must be installed before any adapter) and `../../PORTABILITY.md`
for the mandatory-parity rule and semantic differences.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | root `AGENTS.md` | — (read natively by Codex) |
| Plan/spec/memory + monorepo templates | `.agents/monorepo-agents-harness/core/skills/**/SKILL.md` | symlinked from `.agents/monorepo-agents-harness/core/skills/` into `.agents/skills/` (auto-registration) |
| Plan/spec reminder (start of impl.) | — | `PostToolUse[update_plan]` hook (`systemMessage` reminder) |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` | `.agents/skills/monorepo-harness-build/SKILL.md` → `/monorepo-harness-build` |
| Session-start reminder | — | `SessionStart` hook (`additionalContext` reminder) |
| Memory-gate (incl. `4_verify.md` when required) | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (soft reminder) |
| Verifier | `core/skills/agent-workflow/SKILL.md` Phase 4 | — (no subagent primitive on Codex; run the same verification commands inline in the main session) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `.agents/skills/monorepo-harness-update/SKILL.md` → `/monorepo-harness-update` |

## Prerequisites

- Core installed per `../../INSTALL.md` (the bundle, `AGENTS.md`, per-workspace `.agents/` dirs
  incl. `.agents/artifacts/` seeds — all in place).
- Codex CLI with hooks enabled (project `.codex/config.toml` sets `[features] hooks = true`).
- `jq` on `PATH` (the hooks shell out to it). Verify: `jq --version`.

## Install steps

Run from the target repo root. `BUNDLE=.agents/monorepo-agents-harness` below.

1. **Adapter dependencies.** If this adapter ships a `package.json`, install its dependencies
   before copying any files:
   ```bash
   [ -f "$BUNDLE/adapters/codex/package.json" ] && (cd "$BUNDLE/adapters/codex" && npm install)
   ```

2. **Config.** Merge `adapters/codex/.codex/config.toml` into `.codex/config.toml` to enable hooks:
   ```bash
   mkdir -p .codex
   cp "$BUNDLE/adapters/codex/.codex/config.toml" .codex/config.toml
   # If you already have a config.toml, add [features] hooks = true under the existing content.
   ```

3. **Hooks.** Copy the harness hooks into `.codex/hooks.json`:
   ```bash
   cp "$BUNDLE/adapters/codex/.codex/hooks.json" .codex/hooks.json
   ```
   The first time Codex starts it will ask you to review/trust the non-managed command hooks; run
   `/hooks` in the Codex TUI and trust them (or use `--dangerously-bypass-hook-trust` for one-off
   automation).

4. **Skills.** Symlink the shared runtime skills into `.agents/skills/` so Codex
   auto-registers them — frontmatter (`name`, `description`) must stay intact. Copy
   the adapter-specific skills (`monorepo-harness-build`, `monorepo-harness-update`) because they are not
   shared across agents:
   ```bash
    mkdir -p .agents/skills
    ln -s "../monorepo-agents-harness/core/skills/agent-workflow" .agents/skills/agent-workflow
    ln -s "../monorepo-agents-harness/core/skills/monorepo"       .agents/skills/monorepo
   cp -R "$BUNDLE/adapters/codex/.agents/skills/monorepo-harness-update" .agents/skills/
   cp -R "$BUNDLE/adapters/codex/.agents/skills/monorepo-harness-build"  .agents/skills/
   ```

5. **Install the universal hard gate** (this is what makes the memory-gate real on Codex — the
   `Stop` hook can only remind, not block):
   ```bash
    chmod +x "$ROOT/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"
    ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
    # …and/or add `bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh` to CI.
   ```

The hooks are independent and fail-open (missing `jq`/git root/bundle → exit 0, no block), so they
coexist with other hooks safely.

## Verify

```bash
# a) config parses (Python 3.11+ uses tomllib; otherwise install the `toml` package)
python3 -c "import sys; mod='tomllib' if sys.version_info>=(3,11) else 'toml'; __import__(mod).load(open('.codex/config.toml','rb' if mod=='tomllib' else 'r')); print('config.toml OK')"

# b) hooks.json is valid JSON
jq . .codex/hooks.json >/dev/null && echo "hooks.json OK"

# c) skills are discoverable (frontmatter intact)
head -3 .agents/skills/agent-workflow/SKILL.md
head -3 .agents/skills/monorepo/SKILL.md
head -3 .agents/skills/monorepo-harness-update/SKILL.md
head -3 .agents/skills/monorepo-harness-build/SKILL.md

# d) update-check command resolves its engine
bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh current
```

**End-to-end check of the memory-gate** (the core enforcement). Simulate a fabricated task dir for
today:

```bash
BUNDLE=".agents/monorepo-agents-harness"
ROOT="$(git rev-parse --show-toplevel)"
TODAY="$(date +%Y_%m_%d)"
mkdir -p apps/web/.agents/artifacts/task_${TODAY}_smoke_test

bash "$ROOT/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"; echo "exit=$?"
#   expect: exit=1 — 2_spec.md and 3_memory.md are missing

printf '## Test / verification plan\nrun smoke test\n' \
  > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/2_spec.md
: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/3_memory.md
bash "$ROOT/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"; echo "exit=$?"
#   expect: exit=1 — 4_verify.md is missing (the spec's verification plan is not N/A)

: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/4_verify.md
bash "$ROOT/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"; echo "exit=$?"
#   expect: exit=0 (gate satisfied)

rm -rf apps/web/.agents/artifacts/task_${TODAY}_smoke_test
```

If the first run exits 1, the second also exits 1 (now missing only `4_verify.md`), and the third
exits 0, the hard gate is live.

**Skill registration check:** start Codex and type `/`. You should see `/monorepo-harness-update` and `/monorepo-harness-build` in the slash
command list.

## Notes / semantic differences

- **`Stop` hook cannot hard-block.** Codex CLI ignores `continue: false` from `Stop` hooks when it
  comes to ending the turn; the hook can only surface a `systemMessage` warning. The **universal
  hard gate** (`core/scripts/memory-gate.sh` as a git pre-commit hook and/or CI step) is what
  actually enforces `3_memory.md`. Do not skip step 4.
- **No `ExitPlanMode` tool.** Codex CLI toggles plan mode with the `/plan` slash command; the only
  plan-related local function tool is `update_plan`. The adapter therefore uses
  `PostToolUse[update_plan]` to inject the “create task dir + write 1_plan.md/2_spec.md” reminder.
- **Update check is a skill, not a custom slash command.** Codex CLI does not support user-defined
  slash commands directly, but skills appear in the slash list. The update check ships as
  `.agents/skills/monorepo-harness-update/SKILL.md`, surfaced as `/monorepo-harness-update`.
- **Parity checklist:** every harness capability has a live Codex counterpart — instructions ✔
  (native), templates ✔ (skills), plan reminder ✔ (`PostToolUse[update_plan]` + `SessionStart`),
  manual plan/spec build trigger ✔ (`/monorepo-harness-build` skill), memory-gate ✔ (`Stop` soft reminder +
  git/CI hard gate, now also covering `4_verify.md`), verifier ✔ (no subagent primitive, so the
  same verification instructions run inline in the main session — see `PORTABILITY.md`), update
  check ✔ (`/monorepo-harness-update` skill).
