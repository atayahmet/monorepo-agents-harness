# Agent Harness — Install Guide

Two commands install the harness into any JavaScript/TypeScript monorepo. Every file-level step runs from a
manifest-driven script (`core/install-manifest.txt`, `adapters/<agent>/manifest.txt`), so nothing depends on
prose being read correctly. What the harness *is*: [`README.md`](README.md).

## 1. Prerequisites

- A JS/TS monorepo (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) with an `apps/*` layout (optionally
  `packages/*` or `libs/*`); `git`, `bash`, coreutils, symlink support; `jq` only if your hooks need it.

## 2. Phase 1 — core (identical for every agent)

From your repo root:

```bash
git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-install
bash .agents/.harness-install/core/scripts/install-harness.sh
```

That copies every manifest row into `.agents/monorepo-agents-harness/` and verifies each one landed,
writes your root `AGENTS.md` and `REVIEW.md` (unless they exist), seeds a starter rule, scaffolds
`.agents/` state for every workspace, seeds the repo-root `knowledge/` base, wires `memory-gate.sh` as
`.git/hooks/pre-commit` if that slot is free, then moves the clone away.

Useful flags: `--project-name <name>`, `--no-git-hook`, `--from <dir>` (install from a bundle already
on disk), `--sync-only` (bundle files only — the mode updates use).

Re-running it is safe. **Nothing is ever deleted** — anything replaced is moved to
`.agents/.harness-trash/<timestamp>_<pid>/`; purge it with
`core/scripts/cleanup-harness-trash.sh` (`--list` first) if you want.

## 3. Phase 2 — your agent's adapter

Once per agent you use:

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
`.codex/hooks.json`, `opencode.jsonc`, `.codex/config.toml` or a root `CLAUDE.md`, the adapter's version
is written beside it as `<file>.harness-proposed`, for you to merge deliberately.

## 4. What still needs a human

Both scripts end with a `Needs you:` list. Only four things ever appear there:

1. **`{{PROJECT_GOTCHAS}}` in `AGENTS.md`** — your own rules. Fill in or delete the example item.
2. **`{{PROJECT_REVIEW_POLICY}}` in `REVIEW.md`** — your review passes / thresholds for
   `/monorepo-harness-review`. Fill in or delete; the defaults are reasonable.
3. **`AGENTS.md` already existed** — left untouched. Run `core/skills/agents-md-merge/SKILL.md`: it
   keeps 100% of your content, weaves in only the missing harness rules, shows the full diff, and
   writes nothing until you approve.
4. **A `<file>.harness-proposed`** — merge with `git diff --no-index <file> <file>.harness-proposed`.

## 5. Confirm nothing was missed

```bash
bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh          # add --json for machine output
```

Compares your project against the installed manifests: every bundle row, every adapter entry point
(missing or stale), your `AGENTS.md` provenance marker, and every workspace's scaffold seeds. Exit 0
means complete; anything else names the exact paths. Then commit the install.

To prove the hard gate is live, add a throwaway `apps/<n>/.agents/artifacts/task_<date>_smoke/` and run
`memory-gate.sh` as you add `1_spec.md`, `3_memory.md`, `4_verify.md`: exit 1 until all exist, then 0.

## 6. Optional extras

- **CI** — `/monorepo-harness-ci` detects the provider and wires `memory-gate.sh` in.
- **Intent inbox** — `/monorepo-harness-intent` (`core/governance/intents/AGENTS.md`).
- **Intent execution** — `/monorepo-harness-intent-execute <intent.md>` turns an approved intent into
  3-5 phases, one task directory and one GitHub issue per phase
  (`core/skills/intent-workflow/SKILL.md`, "Workflow — Execute"). Issues go through the `gh` CLI you
  already authenticated (`core/scripts/tracker-issue.sh`): nothing to install, no token ever stored.
  Without `gh` the task directories are still written and the issue text is printed to paste. Other
  trackers (Linear, Jira) need an MCP server or token that **you** install — the harness ships none.
- **Self-improvement** — `/monorepo-self-improve` proposes project-owned rules and skills; declined
  proposals are kept under `.agents/self-improve-proposals/`, yours to track or ignore in git.
- **Changeset release entries** — `/monorepo-harness-changeset` drafts a changesets-compatible
  `.changeset/*.md` entry without adding `@changesets/cli`; bumps are user-confirmed policy.
- **Knowledge base** — every finished task is ingested into the repo-root `knowledge/` compiled layer,
  so agents answer against indexed markdown instead of re-scanning artifact trees per query.

## 7. Updating

`/monorepo-harness-update`, in the agent you installed the adapter for. With no adapter, paste the
prompt from `core/prompts/harness-update.md` or run `core/scripts/harness-update.sh check`. The upgrade
is consent-gated and re-uses the same installer scripts, so it can never disagree with an install
about what "complete" means.
