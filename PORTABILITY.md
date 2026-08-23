# Cross-Agent Portability — core + adapters, and how to author a new one

The harness is agent-neutral by construction: **`core/` holds everything every agent shares**
(rules, templates, scripts, docs governance) and **`adapters/<agent>/` holds only the per-agent
enforcement wiring**. The bundle ships two adapters — `claude-code` and `opencode` — as reference
implementations. This guide explains the model and how to add your own agent.

## The golden rule (mandatory parity)

> **For every harness capability, the agent you install MUST have a live equivalent.** Never drop a
> capability because your agent lacks another agent's exact hook. If there is no direct equivalent,
> fall back to the **agent-agnostic row** (an `AGENTS.md` rule and/or the git/CI gate) so the
> capability is *preserved, not lost*.

## The three portability layers

| Layer | Portable? | How |
|---|---|---|
| **Instructions** (rules, workflow mandates) | ✅ Universal | `AGENTS.md` is read natively by Claude Code, opencode, Cursor, Codex, Zed, … Put the *rules* here — and only here (single source of truth). |
| **Templates** (plan/spec/memory, turborepo) | ✅ Universal | `core/skills/**/SKILL.md` files are plain markdown; reference them through the agent's instruction mechanism. |
| **Enforcement** (hooks that remind/block) | ⚠️ Per-agent | `core/scripts/*.sh` implement the logic; each adapter wires them into the agent's hook/plugin API — or falls back to git/CI where the agent can't block. |

**Design principle:** push as much as possible into `core/` (universal), and keep the per-agent
adapter as thin as possible (only the enforcement the instructions can't guarantee).

## Capability matrix

| Harness capability | Core artifact | claude-code adapter | opencode adapter | Agent-agnostic fallback (always available) |
|---|---|---|---|---|
| Project instructions / rules | root `AGENTS.md` | native + root `CLAUDE.md` = `@AGENTS.md` pointer | native | `AGENTS.md` — read by most agents |
| Per-workspace working state (`session-log`/`lessons`/`todo` under `<ws>/.agents/`) | `core/workspace-agents-template/` + `core/scripts/scaffold-workspace-agents.sh` | `AGENTS.md` "Before You Start" mandate | same | `AGENTS.md` mandate (instruction-level → **universal**, no hook needed) |
| Plan/spec/memory templates | `core/skills/agent-workflow/SKILL.md` | copied into `.claude/skills/` (auto-registered skill) | referenced via `opencode.jsonc` `instructions` | reference/copy the templates via your agent's instruction mechanism |
| Turborepo guidance | `core/skills/turborepo/` | same as above | same as above | link from `AGENTS.md` |
| Plan/spec reminder (start of impl.) | `AGENTS.md` gotcha #4 | `PostToolUse[ExitPlanMode]` hook | `AGENTS.md` mandate (+ optional plugin nudge) | `AGENTS.md` mandate |
| **Memory-gate** (no finish without `3_memory.md`) | `core/scripts/memory-gate.sh` | `Stop` hook → script `--json` (**hard block**) | plugin `session.idle` (soft reminder) | **script default mode as git pre-commit / CI — hard block, universal** |
| Update check / upgrade (`/tah:update`) | `core/scripts/harness-update.sh` + `core/skills/harness-update/SKILL.md` | `.claude/commands/tah/update.md` | `.opencode/commands/tah/update.md` | run `harness-update.sh check` directly in a terminal |
| Slash commands | — | `.claude/commands/**/*.md` (subdir = namespace) | `.opencode/commands/**/*.md` (flat filename or subdir = command ID) | n/a (agent-specific convenience) |

### Semantic differences you must not paper over

- **Hard block vs. soft reminder.** claude-code's `Stop` hook can *refuse to let the agent stop*.
  opencode's `session.idle` fires *after* the turn is already idle — it can warn but not hard-block.
  → The **universal hard gate is `core/scripts/memory-gate.sh`** wired as a git pre-commit hook
  and/or CI step. Install it for *every* agent whose stop you cannot block (and it's a good
  belt-and-braces even for claude-code).

## Authoring a new adapter

1. **Read the matrix column for your agent.** For each capability, decide: native mechanism, or
   fallback row?
2. **Instructions:** ensure the agent reads root `AGENTS.md` (native in most). If your agent uses a
   different file (e.g. `.cursor/rules`), make that file a thin pointer to `AGENTS.md` — never a
   copy of its content.
3. **Templates:** reference `core/skills/**/SKILL.md` through the agent's instruction/config
   mechanism. Copy only if the agent requires physical presence (claude-code does, for skill
   auto-registration).
4. **Enforcement:** wire `core/scripts/memory-gate.sh` into the agent's hook/plugin API if it has
   one; otherwise install the git/CI gate. The script is fail-open and dependency-light (`git` +
   coreutils; `--json` output mode for agents needing structured hook output). Ship the update-check
   command too: a thin pointer to `core/skills/harness-update/SKILL.md`.
5. **Package it** as `adapters/<your-agent>/` with a README following the existing two: a
   "what maps to what" table, prerequisites, install steps, verification, and semantic-difference
   notes. Open a PR — new adapters are the intended growth path of this bundle.

## The universal hard gate (every agent, or none)

`core/scripts/memory-gate.sh` fails when today's task dir is missing `2_spec.md` / `3_memory.md`.
It depends only on `git` + coreutils, so it works with any agent — or none.

```bash
# as a git pre-commit hook
ln -s ../../turborepo-harness-template/core/scripts/memory-gate.sh .git/hooks/pre-commit
chmod +x turborepo-harness-template/core/scripts/memory-gate.sh
# …or as a CI step
bash turborepo-harness-template/core/scripts/memory-gate.sh
```

This is what makes the memory-gate real on agents that cannot block their own stop.
