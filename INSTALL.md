# Agent Harness — Install Guide

Two commands install the harness into any JavaScript/TypeScript monorepo. Every file-level step is
executed by a script driven by a manifest — `core/install-manifest.txt` for the bundle,
`adapters/<agent>/manifest.txt` for each agent — so nothing depends on an agent (or a human)
correctly interpreting prose. What the harness *is* and how it feels day to day: [`README.md`](README.md).

## 1. Prerequisites

- A JS/TS monorepo (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) with an `apps/*` layout
  (optionally `packages/*` or `libs/*`).
- `git`, `bash`, coreutils, and symlink support (adapters register shared skills by symlink).
- `jq` only if your agent's hooks need it — claude-code and codex do.

## 2. Phase 1 — core (identical for every agent)

From your repo root:

```bash
git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-install
bash .agents/.harness-install/core/scripts/install-harness.sh
```

That copies every `core/install-manifest.txt` row into `.agents/monorepo-agents-harness/`, verifies
each one landed, writes your root `AGENTS.md` (with the provenance marker, project name and
monorepo framework filled in) unless you already have one, scaffolds `.agents/` state for every
workspace, wires `memory-gate.sh` as `.git/hooks/pre-commit` if that slot is free, and moves the
clone away when it's done.

Useful flags: `--project-name <name>`, `--no-git-hook`, `--from <dir>` (install from a bundle you
already have on disk instead of cloning), `--sync-only` (bundle files only — the mode updates use).

Re-running it is safe. **Nothing is ever deleted**: anything replaced is moved to
`.agents/.harness-trash/<timestamp>_<pid>/`, and purging that is your own call —
`bash .agents/monorepo-agents-harness/core/scripts/cleanup-harness-trash.sh` (`--list` to look first).

## 3. Phase 2 — your agent's adapter

Once per agent you actually use:

```bash
bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code   # or codex, opencode
```

| Agent | Adapter notes |
|---|---|
| Claude Code | [`adapters/claude-code/INSTALL.md`](adapters/claude-code/INSTALL.md) |
| opencode | [`adapters/opencode/INSTALL.md`](adapters/opencode/INSTALL.md) |
| Codex CLI | [`adapters/codex/INSTALL.md`](adapters/codex/INSTALL.md) |
| anything else | author one: [`PORTABILITY.md`](PORTABILITY.md) |

An existing config file is **never** modified. If you already have `.claude/settings.json`,
`.codex/hooks.json`, `opencode.jsonc`, `.codex/config.toml` or a root `CLAUDE.md`, the adapter's
version is written beside it as `<file>.harness-proposed` and reported, for you to merge
deliberately.

## 4. What still needs a human

Both scripts end with a `Needs you:` list. Only three things ever appear there:

1. **`{{PROJECT_GOTCHAS}}` in `AGENTS.md`** — your project's own rules (layering, boundaries,
   conventions). Fill it in or delete the example item; no script can guess this.
2. **`AGENTS.md` already existed** — it is left untouched. Run
   `core/skills/agents-md-merge/SKILL.md`: it keeps 100% of your content, weaves in only the
   harness rules you're missing, shows you the full diff, and writes nothing until you approve.
3. **A `<file>.harness-proposed`** — review and merge with
   `git diff --no-index <file> <file>.harness-proposed`.

## 5. Confirm nothing was missed

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh          # add --json for machine output
```

Compares your project against the installed bundle's manifests: every bundle row, every adapter
entry point (missing or stale), your `AGENTS.md` provenance marker, and every workspace's scaffold
seeds. Exit 0 means complete; anything else names the exact paths. Then commit the install.

To prove the hard gate itself is live, create a throwaway
`apps/<name>/.agents/artifacts/task_<YYYY_MM_DD>_smoke/` and run
`bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh` as you add `2_spec.md`,
`3_memory.md` and `4_verify.md`: it must exit 1 until all of them exist, then 0. Delete the
throwaway dir afterwards.

## 6. Optional extras

- **CI** — ask your agent `/monorepo-harness-ci`; it detects the provider and wires
  `memory-gate.sh` in (`core/skills/ci-integration/SKILL.md`).
- **Review policy** — copy `core/root-REVIEW.md` to `REVIEW.md` and resolve
  `{{PROJECT_NAME}}`/`{{PROJECT_REVIEW_POLICY}}` to customize `/monorepo-harness-review`.
- **Intent inbox** — `/monorepo-harness-intent` (`core/governance/intents/AGENTS.md`).

## 7. Updating

`bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check`, or ask your agent
(`/monorepo-harness:update` on claude-code, `/monorepo-harness-update` elsewhere). The upgrade is
consent-gated and re-uses the very same installer scripts, so an update can never disagree with an
install about what "complete" means. Full workflow: `core/skills/harness-update/SKILL.md`.
