# opencode adapter

Installs the agent harness for **opencode** (TUI/CLI). The harness core (`core/`) is
agent-agnostic — this adapter only supplies opencode's *enforcement* wiring: a plugin, a slash
command, and config. Read `../../INSTALL.md` first (core must be installed before any adapter) and
`../../PORTABILITY.md` for the mandatory-parity rule and semantic differences.

## What maps to what

| Harness capability | Core (agent-agnostic) | This adapter |
|---|---|---|
| Rules / instructions | `AGENTS.md` (native to opencode) | — (no extra wiring) |
| Plan/spec/memory + turborepo templates | `core/skills/**/SKILL.md` | referenced via `opencode.jsonc` `instructions` |
| Manual plan/spec build trigger | `core/skills/agent-workflow/SKILL.md` | `.opencode/commands/tah-build.md` → `/tah-build` |
| Memory-gate | `core/scripts/memory-gate.sh` | plugin `session.idle` (soft reminder) **+** core script at git/CI (hard) |
| Update check | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `.opencode/commands/tah-update.md` → `/tah-update` |

## Prerequisites

- The **core already installed** per `../../INSTALL.md` (bundle, `AGENTS.md`, and per-workspace
  `.agents/` dirs incl. `.agents/artifacts/` seeds in place — the plugin and config reuse them).
- opencode installed; `git` available. The plugin runs on opencode's bundled Bun runtime (uses `$`).

## Install steps

1. **Adapter dependencies.** If this adapter ships a `package.json`, install its dependencies
   before copying any files:
   ```bash
   [ -f "turborepo-harness-template/adapters/opencode/package.json" ] && (cd "turborepo-harness-template/adapters/opencode" && npm install)
   ```

2. **Config.** Merge `opencode.jsonc` into the repo-root `opencode.jsonc` (or `opencode.json`). It
   adds the `instructions` entries that feed opencode the same `SKILL.md` templates every adapter
   reuses. `AGENTS.md` is loaded by opencode natively — no extra wiring.

3. **Plugin & commands.** Copy the plugin and harness commands into place:
   ```bash
   mkdir -p .opencode/plugins .opencode/commands
   cp turborepo-harness-template/adapters/opencode/.opencode/plugins/agent-harness.ts .opencode/plugins/
   cp turborepo-harness-template/adapters/opencode/.opencode/commands/tah-update.md \
      turborepo-harness-template/adapters/opencode/.opencode/commands/tah-build.md \
      .opencode/commands/
   ```

4. **Install the universal hard gate** (this is what makes the memory-gate real on opencode — the
   plugin can only remind, not block, at `session.idle`):
   ```bash
   chmod +x turborepo-harness-template/core/scripts/memory-gate.sh
   ln -s ../../turborepo-harness-template/core/scripts/memory-gate.sh .git/hooks/pre-commit   # and/or add to CI
   ```

5. **Type (optional).** For editor types on the plugin:
   `npm i -D @opencode-ai/plugin` (or add it to `~/.config/opencode/package.json`).

## Verify

```bash
# opencode present; config parses (strip // comments first if using a strict JSON parser)
opencode --help >/dev/null 2>&1 && echo "opencode present"

# the update-check command resolves its engine
test -x turborepo-harness-template/core/scripts/harness-update.sh \
  && bash turborepo-harness-template/core/scripts/harness-update.sh current

# the hard gate blocks a task dir missing 3_memory.md, passes once present
bash turborepo-harness-template/core/scripts/memory-gate.sh; echo "exit=$?"

# plugin loads + commands register: start opencode, type `/tah-update` and `/tah-build`
```

## Notes / semantic differences

- **`session.idle` cannot hard-block.** Treat the plugin's idle reminder as a nudge; the git/CI gate
  from step 3 is the real enforcement.
- **Parity checklist:** every harness capability must have a live opencode counterpart —
  instructions ✔ (config), templates ✔ (config), plan/spec build trigger ✔ (command file),
  memory-gate ✔ (plugin reminder + git/CI hard gate), update-check ✔ (command file). Do not
  skip step 4, or the memory-gate is unenforced.
