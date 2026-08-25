# claude-code adapter

Installs the agent harness for **Claude Code**. The harness core (`core/`) is agent-agnostic —
this adapter only supplies Claude Code's *enforcement* wiring: two hooks plus skill
registration. Read `../../INSTALL.md` first (core must be installed before any adapter).

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | `AGENTS.md` (native to Claude Code) | root `CLAUDE.md` = thin `@AGENTS.md` pointer |
| Plan/spec/memory + turborepo templates | `core/skills/**/SKILL.md` | copied into `.claude/skills/` (auto-registration) |
| Plan/spec reminder (plan-mode exit) | — | `PostToolUse[ExitPlanMode]` hook (inline reminder) |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` | `.claude/commands/tah-build.md` → `/tah-build` |
| Memory-gate | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (**hard block**) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `.claude/commands/tah/update.md` → `/tah:update` |

## Prerequisites

- Core installed per `../../INSTALL.md` (the bundle, `AGENTS.md`, per-workspace `.agents/` dirs
  incl. `.agents/artifacts/` seeds — all in place).
- Claude Code with hooks enabled (project `.claude/settings.json` is honored).
- `jq` on `PATH` (the hooks shell out to it). Verify: `jq --version`.

## Install steps

Run from the target repo root. `BUNDLE=turborepo-agent-harness` below — adjust if you
vendored the bundle under a different path (and update the two script paths in
`.claude/settings.json` accordingly).

1. **Adapter dependencies.** If this adapter ships a `package.json`, install its dependencies
   before copying any files:
   ```bash
   [ -f "$BUNDLE/adapters/claude-code/package.json" ] && (cd "$BUNDLE/adapters/claude-code" && npm install)
   ```

2. **Skills.** Copy (or symlink) the core skills into `.claude/skills/` so Claude Code
   auto-registers them — frontmatter (`name`, `description`) must stay intact:
   ```bash
   mkdir -p .claude/skills
   cp -R "$BUNDLE/core/skills/agent-workflow" .claude/skills/
   cp -R "$BUNDLE/core/skills/turborepo" .claude/skills/
   # symlink alternative (single physical copy):
   # ln -s "../../$BUNDLE/core/skills/agent-workflow" .claude/skills/agent-workflow
   # ln -s "../../$BUNDLE/core/skills/turborepo" .claude/skills/turborepo
   ```

3. **Hooks.** No `.claude/settings.json` yet → copy `adapters/claude-code/.claude/settings.json`.
   Already have one → merge the two hook blocks in without clobbering existing hooks:
   - under `hooks.PostToolUse`, append the matcher object (`"ExitPlanMode"`);
   - under `hooks.Stop`, append the memory-gate block.

   Programmatic merge with `jq` (writes a merged file you then review):
   ```bash
   jq -s '.[0] as $cur | .[1] as $add
     | $cur
     | .hooks.PostToolUse = (($cur.hooks.PostToolUse // []) + $add.hooks.PostToolUse)
     | .hooks.Stop        = (($cur.hooks.Stop        // []) + $add.hooks.Stop)' \
     .claude/settings.json "$BUNDLE/adapters/claude-code/.claude/settings.json" > /tmp/merged.json
   # review /tmp/merged.json, then move it into place
   ```

4. **Root pointer.** Copy `adapters/claude-code/CLAUDE.md` to the repo root (merge by hand if
   you already have one — keep it a thin `@AGENTS.md` pointer).

5. **Update-check command.** Copy the update-check command (registers as `/tah:update`):
   ```bash
   mkdir -p .claude/commands/tah
   cp "$BUNDLE/adapters/claude-code/.claude/commands/tah/update.md" \
      .claude/commands/tah/
   ```

6. **Manual plan/spec build command.** Copy the build trigger command (registers as `/tah-build`):
   ```bash
   cp "$BUNDLE/adapters/claude-code/.claude/commands/tah-build.md" \
      .claude/commands/
   ```

7. **Placeholders.** Resolve `{{PROJECT_NAME}}` in the root `CLAUDE.md`. The hook commands contain
   no placeholders — task artifacts use the fixed convention `<workspace>/.agents/artifacts/`.

The hooks are independent and fail-open (missing `jq`/git root/bundle → exit 0, never blocks),
so they coexist with other hooks safely.

## Verify

```bash
# a) settings.json is valid JSON
jq . .claude/settings.json >/dev/null && echo "settings.json OK"

# b) skills are discoverable (frontmatter intact)
head -3 .claude/skills/agent-workflow/SKILL.md
head -3 .claude/skills/turborepo/SKILL.md

# c) commands resolve their engines
ls .claude/commands/tah-build.md .claude/commands/tah/update.md
bash turborepo-agent-harness/core/scripts/harness-update.sh current
```

**End-to-end check of the memory-gate** (the core enforcement). Simulate the `Stop` hook
against a fabricated task dir for today:

```bash
BUNDLE="turborepo-agent-harness"
TODAY="$(date +%Y_%m_%d)"
mkdir -p apps/web/.agents/artifacts/task_${TODAY}_smoke_test

bash "$BUNDLE/core/scripts/memory-gate.sh" --json; echo "exit=$?"
#   expect: {"decision":"block", ...} because 3_memory.md is missing

: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/3_memory.md
bash "$BUNDLE/core/scripts/memory-gate.sh" --json; echo "exit=$?"
#   expect: no output, exit=0 (gate satisfied)

rm -rf apps/web/.agents/artifacts/task_${TODAY}_smoke_test
```

If the first run prints a `block` decision and the second exits 0, the adapter is live.
