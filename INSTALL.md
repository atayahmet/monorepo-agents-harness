# Agent Harness — Install Guide

A portable **plan → spec → memory** agent harness for **any coding agent** (Claude Code, opencode,
Cursor, Codex, …), packaged so you can install it into **any Turborepo project**. This directory
(`turborepo-harness-template/`) contains ready-to-copy files; this guide tells you exactly where each
one goes and what to edit.

> **Audience:** an agent (or engineer) installing the harness into a target repo. Read this whole
> file first, then execute the install phases top to bottom.

> **Architecture:** the bundle is split into an agent-neutral **`core/`** (rules, templates,
> scripts, docs governance) and per-agent **`adapters/`** (the thin enforcement wiring each agent
> needs). Phase 1 installs the core — identical for every agent. Phase 2 installs the adapter(s)
> for the agent(s) you actually use.

---

## 1. What this harness is (and how it enforces itself)

The harness makes plan-mode work **auditable and self-documenting**. Every non-trivial task produces
three artifacts in a dedicated directory, and the **memory-gate** enforces the loop:

| Phase | Artifact | Trigger | Enforcement |
|---|---|---|---|
| Plan | `1_plan.md` | after plan approval | adapter hook reminds you to create the task dir + write `1_plan.md` / `2_spec.md` before the first Edit/Write |
| Spec | `2_spec.md` | before implementation | same reminder + `core/scripts/memory-gate.sh` at commit/CI |
| Memory | `3_memory.md` | at task end | adapter stop-hook and/or `core/scripts/memory-gate.sh` **blocks** until today's task dir contains `3_memory.md` |

Artifacts live under the target workspace itself:

```
<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/
    1_plan.md
    2_spec.md
    3_memory.md
```

plus a mandatory searchable index at `<workspace>/.agents/artifacts/index.md`.

`<workspace>` = the app (`apps/<name>`) or package (`packages/<name>`) the task primarily targets.
The skill `core/skills/agent-workflow/` supplies the file templates. Indexing rules live in
`core/governance/artifacts/AGENTS.md` (bundle reference — also seeded as a pointer into each
workspace).

---

## 2. Prerequisites

- A **Turborepo** monorepo using an `apps/*` layout (optionally `packages/*`).
- `git` (scripts locate the repo root via `git rev-parse --show-toplevel`; the update-check also
  uses it to reach the upstream repo).
- **`jq`** on `PATH` if your adapter's hooks/plugin shells out to it (claude-code does).
- Your agent of choice — see Phase 2 for per-agent prerequisites.

---

## 3. Bundle contents

```
turborepo-harness-template/
├── INSTALL.md                                  # this guide (core + adapter phases)
├── PORTABILITY.md                              # capability matrix + authoring new adapters
├── AGENTS.md                                   # TEMPLATE root instructions — single source of truth (placeholders)
├── core/                                       # ★ agent-neutral — identical for every agent
│   ├── skills/
│   │   ├── agent-workflow/SKILL.md             # plan/spec/memory templates (fixed paths, no placeholders)
│   │   └── turborepo/**                        # generic Turborepo skill (verbatim, no edits)
│   ├── scripts/
│   │   ├── memory-gate.sh                      # HARD gate: scans apps/*/.agents/artifacts + packages/*/.agents/artifacts
│   │   ├── harness-update.sh                   # version engine: current/latest/check/upgrade vs upstream
│   │   └── scaffold-workspace-agents.sh        # creates <workspace>/.agents/ + artifacts/{index.md,AGENTS.md} seeds
│   ├── workspace-agents-template/              # PER-WORKSPACE working-state seed
│   │   ├── session-log.md                      # stub → <workspace>/.agents/session-log.md
│   │   ├── lessons.md                          # stub → <workspace>/.agents/lessons.md
│   │   └── todo.md                             # stub → <workspace>/.agents/todo.md
│   └── governance/artifacts/                   # indexing rules + seeds for <workspace>/.agents/artifacts/
│       ├── AGENTS.md                           # indexing rules for every <workspace>/.agents/artifacts/index.md
│       ├── workspace-AGENTS.md                 # pointer seeded into each <workspace>/.agents/artifacts/AGENTS.md
│       └── index-template.md                   # seed for each <workspace>/.agents/artifacts/index.md
└── adapters/                                   # ★ per-agent enforcement — install the ones you use
    ├── claude-code/                            # .claude/settings.json hooks + root CLAUDE.md pointer + README.md
    └── opencode/                               # opencode.jsonc + .opencode/plugins/agent-harness.ts + README.md
```

---

## 4. Phase 1 — Core install (agent-neutral)

Let `ROOT` = target repo root.

1. **Copy the bundle** into the target repo root as `turborepo-harness-template/` (keep the name —
   adapter configs and scripts reference it; if you rename it, adjust those references).
2. **Copy `AGENTS.md`** to `ROOT/AGENTS.md` (merge by hand if one exists — it is the single source
   of truth every agent reads natively).
3. **Scaffold per-workspace state**:
   ```bash
   bash turborepo-harness-template/core/scripts/scaffold-workspace-agents.sh
   ```
   For every app and package it creates `.agents/{session-log,lessons,todo}.md` plus the task tree
   `.agents/artifacts/{index.md,AGENTS.md}` (empty searchable index + rules pointer). The agent
   reads these *before* each task and writes its `todo.md` there (see `AGENTS.md` "Before You
   Start"). Re-run after adding any workspace.
4. **Resolve placeholders** (§6).
5. **Verify** (§8), then **commit** the core install as its own change.

## 5. Phase 2 — Adapter install (pick your agent(s))

Every adapter assumes Phase 1 is done. Install **one adapter per agent you use** — the
mandatory-parity rule (`PORTABILITY.md`) requires every harness capability to have a live
counterpart for each agent.

| Agent | Adapter | Guide |
|---|---|---|
| Claude Code | `adapters/claude-code/` | `adapters/claude-code/README.md` |
| opencode | `adapters/opencode/` | `adapters/opencode/README.md` |
| Codex CLI | `adapters/codex/` | `adapters/codex/README.md` |
| anything else | author your own | `PORTABILITY.md` — capability matrix + fallback rows |

Before copying files from an adapter, check whether it ships a `package.json`; if it does, install
its dependencies first with `npm install` (or `pnpm install` / `yarn install`) in the adapter
directory.

Regardless of adapter, the **universal hard gate** can (and for agents that cannot block their own
stop, MUST) be wired without any agent support:

```bash
# as a git pre-commit hook
ln -s ../../turborepo-harness-template/core/scripts/memory-gate.sh .git/hooks/pre-commit
chmod +x turborepo-harness-template/core/scripts/memory-gate.sh
# …or as a CI step
bash turborepo-harness-template/core/scripts/memory-gate.sh
```

Each adapter also ships a harness update command: `/tah:update` for claude-code,
`/tah:update` for opencode, and `/tah-update` for Codex CLI — copy it during the
adapter install steps; all are thin pointers to the shared
`core/skills/harness-update/SKILL.md` workflow (see §10).

---

## 6. Parameterization (resolve every placeholder)

Replace these tokens across the copied files before use:

| Placeholder | Meaning | Default | Appears in |
|---|---|---|---|
| `{{PROJECT_NAME}}` | Your monorepo's display name | — | `AGENTS.md`, `adapters/claude-code/CLAUDE.md` |
| `{{PROJECT_GOTCHAS}}` | Project-specific rules (layering, boundaries, conventions); delete the example if none | — | `AGENTS.md` |

> Nothing else is parameterized. The plan/spec/memory artifact location is a fixed convention —
> `<workspace>/.agents/artifacts/` for every app and package — and the memory-gate discovers
> workspaces automatically. The harness-update script embeds one upstream URL (see §10) overridable
> via the `HARNESS_UPSTREAM` env var.

Hand-edit `AGENTS.md` to fill `{{PROJECT_NAME}}` and `{{PROJECT_GOTCHAS}}`.

---

## 7. What is intentionally NOT in this bundle (and why)

| Excluded | Reason |
|---|---|
| Agent-specific slash commands beyond the update check (`.claude/commands/*`, `.opencode/commands/*`) | Project-specific workflows, not portable engine. The bundle ships exactly one command pair — the update check (see §10) — because it is harness plumbing, not project logic. Author your own for the rest. |
| `.claude/settings.local.json` | Local machine permissions — never portable. |
| Per-module instruction files (e.g. `apps/api/src/modules/**/AGENTS.md`) | Project content, not harness. Add your own where useful. |
| Populated `<workspace>/.agents/artifacts/task_*` dirs and their `index.md` rows | Task history is repo-specific; you start empty (the scaffold seeds each workspace with `index-template.md`). |
| `.agents/rules/*.md` | The source repo referenced these but did not ship them; the template deliberately references **no** rule file. Add your own and list them in `AGENTS.md`'s Reference Map. |

---

## 8. Verification (core)

Run these from the target repo root after Phase 1:

```bash
BUNDLE="turborepo-harness-template"

# a) core scripts have no syntax errors
for f in "$BUNDLE"/core/scripts/*.sh; do bash -n "$f" && echo "$f OK"; done

# b) no unresolved placeholders remain in the installed copies
! grep -rn '{{PROJECT_NAME}}\|{{PROJECT_GOTCHAS}}' AGENTS.md \
  && echo "no placeholders left"

# c) every workspace got its task-artifact seeds
for d in apps/* packages/*; do
  [ -f "$d/.agents/artifacts/index.md" ] || echo "missing index seed: $d"
done
echo "seed check done"
```

**End-to-end check of the memory-gate** (the core enforcement, agent-free default mode).
Simulate a fabricated task dir for today:

```bash
TODAY="$(date +%Y_%m_%d)"
mkdir -p apps/web/.agents/artifacts/task_${TODAY}_smoke_test

bash turborepo-harness-template/core/scripts/memory-gate.sh; echo "exit=$?"
#   expect: exit=1 — 2_spec.md and 3_memory.md are missing

: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/2_spec.md
: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/3_memory.md
bash turborepo-harness-template/core/scripts/memory-gate.sh; echo "exit=$?"
#   expect: exit=0 (gate satisfied)

rm -rf apps/web/.agents/artifacts/task_${TODAY}_smoke_test
```

If the first run exits 1 and the second exits 0, the core is live. Adapter-specific verification
(skill registration, hook wiring, plugin behavior) is in each adapter's README.

---

## 9. Using the harness day to day

1. Enter plan mode for any non-trivial task; on plan approval the adapter's reminder fires.
2. Apply the **`agent-workflow`** skill templates; create
   `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` and write `1_plan.md` + `2_spec.md`
   before the first Edit/Write.
3. Implement; keep changes scoped to the workspace (see `AGENTS.md`).
4. Commit, then write `3_memory.md` (with commit SHAs) — the memory-gate won't release the task
   until it exists. Update the workspace's searchable index `.agents/artifacts/index.md` in the
   same commit (rules: `core/governance/artifacts/AGENTS.md`).

> **Migrating from an older install** (artifacts previously lived under
> `<docs-app>/agents/<workspace>/`)? Move each `task_*` dir into its workspace
> (`<workspace>/.agents/artifacts/`), fold any old per-workspace index into that workspace's new
> `.agents/artifacts/index.md`, then commit. The memory-gate and the skill only look at the new
> location.

---

## 10. Updating the harness

The bundle is versioned (`core/VERSION`, SemVer; upstream:
`https://github.com/atayahmet/turborepo-agent-harness`, overridable via `HARNESS_UPSTREAM`). Every
release documents behavior changes in `CHANGELOG.md` under **Upgrade Notes**.

**Check** (manual, or via the agent command):

```bash
bash turborepo-harness-template/core/scripts/harness-update.sh check          # exit: 0 current · 1 outdated · 2 unknown
bash turborepo-harness-template/core/scripts/harness-update.sh check --json   # {"installed","latest","status","upstream"}
```

Or ask your agent: `/tah:update` (claude-code) /
`/tah:update` (opencode). The shared workflow lives in
`core/skills/harness-update/SKILL.md`: it reports the diff, asks for consent, then upgrades.

**Upgrade** (consent-gated; refreshes ONLY the verbatim agent-neutral machinery):

```bash
git clone --depth 1 --branch v<latest> https://github.com/atayahmet/turborepo-agent-harness .harness-update-tmp
bash turborepo-harness-template/core/scripts/harness-update.sh upgrade --source .harness-update-tmp
rm -rf .harness-update-tmp
```

The upgrade re-copies `core/{scripts,skills,governance,workspace-agents-template}`, `core/VERSION`,
and `CHANGELOG.md`, then re-runs the idempotent workspace scaffold. It **never touches**: root
`AGENTS.md` (merge manually against the fresh template), `.agents/` working state and task history,
or adapter configs (re-apply merges per your adapter README — see the follow-ups the script prints).

