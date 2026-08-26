# opencode adapter

Installs the agent harness for **opencode** (TUI/CLI). The harness core (`core/`) is
agent-agnostic — this adapter only supplies opencode's *enforcement* wiring: slash commands and
config. Read `../../INSTALL.md` first (core must be installed before any adapter) and
`../../PORTABILITY.md` for the mandatory-parity rule and semantic differences.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | `AGENTS.md` (native to opencode) | — (no extra wiring) |
| Plan/spec/memory + monorepo templates | `.agents/monorepo-agents-harness/skills/**/SKILL.md` | referenced via `opencode.jsonc` `instructions` |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` | `.opencode/commands/monorepo-harness-build.md` → `/monorepo-harness-build` |
| Memory-gate | `core/scripts/memory-gate.sh` | core script at git/CI (hard) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `.opencode/commands/monorepo-harness-update.md` → `/monorepo-harness-update` |

## Prerequisites

- The **core already installed** per `../../INSTALL.md` (bundle, `AGENTS.md`, and per-workspace
  `.agents/` dirs incl. `.agents/artifacts/` seeds in place — the plugin and config reuse them).
- opencode installed; `git` available. The plugin runs on opencode's bundled Bun runtime (uses `$`).

## Install steps

1. **Adapter dependencies.** If this adapter ships a `package.json`, install its dependencies
   before copying any files:
   ```bash
   [ -f ".agents/monorepo-agents-harness/adapters/opencode/package.json" ] && (cd ".agents/monorepo-agents-harness/adapters/opencode" && npm install)
   ```

2. **Config.** Merge `opencode.jsonc` into the repo-root `opencode.jsonc` (or `opencode.json`). It
   adds the `instructions` entries that feed opencode the same `SKILL.md` templates every adapter
   reuses. `AGENTS.md` is loaded by opencode natively — no extra wiring.

3. **Commands.** Copy the harness commands into place:
   ```bash
   mkdir -p .opencode/commands
   cp .agents/monorepo-agents-harness/adapters/opencode/.opencode/commands/monorepo-harness-update.md \
      .agents/monorepo-agents-harness/adapters/opencode/.opencode/commands/monorepo-harness-build.md \
      .opencode/commands/
   ```

4. **Install the universal hard gate** (this is what makes the memory-gate real on opencode;
   opencode cannot block its own stop, so the git/CI gate is the only enforcement):
   ```bash
    chmod +x .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
    ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit   # and/or add to CI
   ```

## Verify

```bash
# opencode present; config parses (strip // comments first if using a strict JSON parser)
opencode --help >/dev/null 2>&1 && echo "opencode present"

# the update-check command resolves its engine
test -x .agents/monorepo-agents-harness/core/scripts/harness-update.sh \
  && bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh current

# the hard gate blocks a task dir missing 3_memory.md, passes once present
bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh; echo "exit=$?"

# commands register: start opencode, type `/monorepo-harness-update` and `/monorepo-harness-build`
```

## Notes / semantic differences

- **Memory-gate enforcement is the universal hard gate.** opencode cannot block its own stop, so
  the real enforcement is `core/scripts/memory-gate.sh` installed as a git pre-commit hook or CI
  step.
- **Parity checklist:** every harness capability must have a live opencode counterpart —
  instructions ✔ (config), templates ✔ (config), plan/spec build trigger ✔ (command file),
  memory-gate ✔ (git/CI hard gate), update-check ✔ (command file). Do not skip step 4, or the
  memory-gate is unenforced.
