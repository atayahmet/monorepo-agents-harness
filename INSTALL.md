# Agent Harness — Install Guide

A portable **plan → spec → memory** agent harness for **any coding agent** (Claude Code, opencode,
Cursor, Codex, …), packaged so you can install it into **any JavaScript/TypeScript monorepo project**. This directory
(`.agents/monorepo-agents-harness/`) contains ready-to-copy files; this guide tells you exactly where each
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
| Plan | `1_plan.md` | after plan approval (or `/monorepo-harness-build` on any agent) | adapter hook reminds you to create the task dir + write `1_plan.md` / `2_spec.md` before the first Edit/Write |
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

- A **JavaScript/TypeScript monorepo** (Turborepo, Nx, Lerna, npm/yarn/pnpm workspaces) using an `apps/*` layout (optionally `packages/*` or `libs/*`).
- `git` (scripts locate the repo root via `git rev-parse --show-toplevel`; the update-check also
  uses it to reach the upstream repo).
- Your agent of choice — see Phase 2 for per-agent prerequisites.

---

## 3. Bundle contents

```
.agents/monorepo-agents-harness/                  # installed harness (bundle + runtime, 0.4.1+)
├── VERSION                                       # installed harness version
├── INSTALL.md                                    # this guide (core + adapter phases)
├── PORTABILITY.md                                # capability matrix + authoring new adapters
├── CHANGELOG.md                                  # release history
├── changelogs/                                   # per-version upgrade prompts
├── core/                                         # ★ agent-neutral — identical for every agent
│   ├── VERSION
│   ├── root-AGENTS.md                            # TEMPLATE root instructions (placeholders)
│   ├── skills/
│   │   ├── agent-workflow/SKILL.md               # plan/spec/memory templates
│   │   ├── agents-md-merge/SKILL.md              # root AGENTS.md reconciliation (install + upgrade)
│   │   ├── harness-update/SKILL.md               # upgrade workflow instructions
│   │   └── monorepo/SKILL.md                     # generic monorepo guidance
│   ├── scripts/
│   │   ├── memory-gate.sh                        # HARD gate
│   │   ├── harness-update.sh                     # version engine
│   │   ├── scaffold-workspace-agents.sh          # workspace seeding
│   │   └── detect-monorepo-framework.sh          # framework detector
│   ├── workspace-agents-template/                # PER-WORKSPACE working-state seed
│   └── governance/artifacts/                     # indexing rules + seeds
└── adapters/                                     # ★ per-agent enforcement wiring
    ├── claude-code/
    ├── codex/
    └── opencode/
```

---

## 4. Phase 1 — Core install (agent-neutral)

Let `ROOT` = target repo root.

1. **Copy the bundle** into `.agents/monorepo-agents-harness/` under the target repo root. This is
   the only installed harness location; nothing stays at the repo root:
   ```bash
   mkdir -p .agents
   cp -R <path-to-bundle>/. .agents/monorepo-agents-harness/ && \
     rm -rf .agents/monorepo-agents-harness/changelogs
   ```
   `changelogs/` only carries upgrade prompts, which are always read from a temporary clone at
   update time (§10) — never from the installed copy — so it is removed immediately after install.
2. **Detect the monorepo framework**. The detector reads repo markers (`turbo.json`, `nx.json`,
   `lerna.json`, `pnpm-workspace.yaml`, `package.json` `workspaces`) and prints both the framework
   name and the workspace directories:
   ```bash
   bash .agents/monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh
   ```
   Record the framework name (e.g. `turborepo`, `nx`, `pnpm`) — you will fill `{{MONOREPO_FRAMEWORK}}`
   in `AGENTS.md` later.
3. **No separate runtime directory is needed.** Because the bundle itself lives under
   `.agents/monorepo-agents-harness/`, adapters and scripts reference files directly there. Older
   installs (pre-0.4.1) used a root `monorepo-agents-harness/` bundle plus a symlink tree under
   `.agents/monorepo-agents-harness/`; if you are migrating, see `changelogs/version-0.4.1.md`.
4. **Install `ROOT/AGENTS.md`** — the single source of truth every agent reads natively.
   - **No `AGENTS.md` at the repo root yet** → copy the template and stamp the provenance marker:
     ```bash
     { printf '<!-- monorepo-agents-harness: root-AGENTS.md v%s -->\n\n' \
         "$(tr -d '[:space:]' < .agents/monorepo-agents-harness/core/VERSION)"
       cat .agents/monorepo-agents-harness/core/root-AGENTS.md; } > AGENTS.md
     ```
   - **An `AGENTS.md` already exists** → do **not** overwrite it, and do **not** leave it unmerged.
     Follow `core/skills/agents-md-merge/SKILL.md`. It keeps 100% of your existing content, weaves in
     only the harness rules you are missing, resolves every conflict itself, then shows you the full
     diff and asks **"Apply this merge to AGENTS.md?"** before writing anything. Declining is fine:
     the proposal is left at `AGENTS.md.harness-proposed` and the install continues.

   Either way the file ends up with a first-line provenance marker
   (`<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->`). That marker records the template
   version your file was last reconciled with, so every future upgrade can perform a real three-way
   merge instead of asking you to diff it by hand (§10).
5. **Scaffold per-workspace state**:
   ```bash
   bash .agents/monorepo-agents-harness/core/scripts/scaffold-workspace-agents.sh
   ```
   For every app and package it creates `.agents/{session-log,lessons,todo}.md` plus the task tree
   `.agents/artifacts/{index.md,AGENTS.md}` (empty searchable index + rules pointer). The agent
   reads these *before* each task and writes its `todo.md` there (see `AGENTS.md` "Before You
   Start"). Re-run after adding any workspace.
6. **Resolve placeholders** (§6).
7. **Verify** (§8), then **commit** the core install as its own change.

## 5. Phase 2 — Adapter install (pick your agent(s))

Every adapter assumes Phase 1 is done. Install **one adapter per agent you use** — the
mandatory-parity rule (`PORTABILITY.md`) requires every harness capability to have a live
counterpart for each agent.

| Agent | Adapter | Guide |
|---|---|---|
| Claude Code | `adapters/claude-code/` | `adapters/claude-code/INSTALL.md` |
| opencode | `adapters/opencode/` | `adapters/opencode/INSTALL.md` |
| Codex CLI | `adapters/codex/` | `adapters/codex/INSTALL.md` |
| anything else | author your own | `PORTABILITY.md` — capability matrix + fallback rows |

Before copying files from an adapter, check whether it ships a `package.json`; if it does, install
its dependencies first with `npm install` (or `pnpm install` / `yarn install`) in the adapter
directory.

Regardless of adapter, the **universal hard gate** can (and for agents that cannot block their own
stop, MUST) be wired without any agent support:

```bash
# as a git pre-commit hook
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
chmod +x .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
# …or as a CI step
bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
```

Each adapter also ships a harness update command: `/monorepo-harness:update` for claude-code,
`/monorepo-harness-update` for opencode, and `/monorepo-harness-update` for Codex CLI — copy it during the
adapter install steps; all are thin pointers to the shared
`core/skills/harness-update/SKILL.md` workflow (see §10).

---

## 6. Parameterization (resolve every placeholder)

Replace these tokens across the copied files before use:

| Placeholder | Meaning | Default | Appears in |
|---|---|---|---|
| `{{PROJECT_NAME}}` | Your monorepo's display name | — | `core/root-AGENTS.md`, `adapters/claude-code/CLAUDE.md` |
| `{{MONOREPO_FRAMEWORK}}` | Detected monorepo framework (`turborepo`, `nx`, `lerna`, `pnpm`, `yarn`, `npm`) | — | `core/root-AGENTS.md` |
| `{{PROJECT_GOTCHAS}}` | Project-specific rules (layering, boundaries, conventions); delete the example if none | — | `core/root-AGENTS.md` |

> Nothing else is parameterized. The plan/spec/memory artifact location is a fixed convention —
> `<workspace>/.agents/artifacts/` for every app and package — and the memory-gate discovers
> workspaces automatically. The harness-update script embeds one upstream URL (see §10) overridable
> via the `HARNESS_UPSTREAM` env var.

Hand-edit `ROOT/AGENTS.md` (copied from `core/root-AGENTS.md`) to fill `{{PROJECT_NAME}}`,
`{{MONOREPO_FRAMEWORK}}`, and `{{PROJECT_GOTCHAS}}`.

> When `core/skills/agents-md-merge/SKILL.md` writes `ROOT/AGENTS.md` (either mode from §4 step 4),
> it already resolves `{{PROJECT_NAME}}` and `{{MONOREPO_FRAMEWORK}}` from your existing file and the
> framework detector. `{{PROJECT_GOTCHAS}}` is always a human decision — fill it in or delete the
> example item.

---

## 7. What is intentionally NOT in this bundle (and why)

| Excluded | Reason |
|---|---|
| Agent-specific slash commands beyond the harness plumbing (`.claude/commands/*`, `.opencode/commands/*`, `.agents/skills/*`) | Project-specific workflows, not portable engine. The bundle ships two harness-plumbing command families — the update check (see §10) and the plan/spec build trigger `/monorepo-harness-build` — because they are harness plumbing, not project logic. Author your own for the rest. |
| `.claude/settings.local.json` | Local machine permissions — never portable. |
| Per-module instruction files (e.g. `apps/api/src/modules/**/AGENTS.md`) | Project content, not harness. Add your own where useful. |
| Populated `<workspace>/.agents/artifacts/task_*` dirs and their `index.md` rows | Task history is repo-specific; you start empty (the scaffold seeds each workspace with `index-template.md`). |
| `.agents/rules/*.md` | The source repo referenced these but did not ship them; the template deliberately references **no** rule file. Add your own and list them in `AGENTS.md`'s Reference Map (in the `core/root-AGENTS.md` template). |

---

## 8. Verification (core)

Run these from the target repo root after Phase 1:

```bash
RUNTIME=".agents/monorepo-agents-harness"

# a) core scripts have no syntax errors
for f in "$RUNTIME"/core/scripts/*.sh; do bash -n "$f" && echo "$f OK"; done

# b) no unresolved placeholders remain in the installed copies
! grep -rn '{{PROJECT_NAME}}\|{{MONOREPO_FRAMEWORK}}\|{{PROJECT_GOTCHAS}}' AGENTS.md \
  "$RUNTIME"/core/root-AGENTS.md \
  && echo "no placeholders left"

# c) every workspace got its task-artifact seeds
for parent in $(bash "$RUNTIME/core/scripts/detect-monorepo-framework.sh" --workspaces 2>/dev/null); do
  [ -d "$parent" ] || continue
  for d in "$parent"/*/; do
    [ -f "$d/.agents/artifacts/index.md" ] || echo "missing index seed: ${d%/}"
  done
done
echo "seed check done"

# d) key runtime files exist
ls -l "$RUNTIME"/core/scripts/ "$RUNTIME"/core/skills/

# e) changelogs/ must not exist in the installed copy — self-heal if it does
# (it is never a prompt source; prompts are always read from a temporary clone at update time)
if [ -d "$RUNTIME/changelogs" ]; then
  echo "changelogs/ should have been removed during install — removing now"
  rm -rf "$RUNTIME/changelogs"
fi
echo "changelogs/ absent: OK"

# f) root AGENTS.md is reconciled and clean
grep -q '^<!-- monorepo-agents-harness: root-AGENTS\.md v' AGENTS.md \
  && echo "AGENTS.md provenance marker OK" \
  || echo "AGENTS.md has no provenance marker — run core/skills/agents-md-merge/SKILL.md"
! grep -n '^<<<<<<< \|^>>>>>>> \|^||||||| ' AGENTS.md && echo "no conflict markers in AGENTS.md"
```

**End-to-end check of the memory-gate** (the core enforcement, agent-free default mode).
Simulate a fabricated task dir for today:

```bash
TODAY="$(date +%Y_%m_%d)"
mkdir -p apps/web/.agents/artifacts/task_${TODAY}_smoke_test

bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh; echo "exit=$?"
#   expect: exit=1 — 2_spec.md and 3_memory.md are missing

: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/2_spec.md
: > apps/web/.agents/artifacts/task_${TODAY}_smoke_test/3_memory.md
bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh; echo "exit=$?"
#   expect: exit=0 (gate satisfied)

rm -rf apps/web/.agents/artifacts/task_${TODAY}_smoke_test
```

If the first run exits 1 and the second exits 0, the core is live. Adapter-specific verification
(skill registration, hook wiring, plugin behavior) is in each adapter's README.

---

## 9. Using the harness day to day

1. Enter plan mode for any non-trivial task; on plan approval the adapter's reminder fires. If the
   reminder is missed or your agent has no automatic hook, type `/monorepo-harness-build` to trigger the same
   plan/spec build step.
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

The harness is versioned at `.agents/monorepo-agents-harness/VERSION` (SemVer; upstream:
`https://github.com/atayahmet/monorepo-agents-harness`, overridable via `HARNESS_UPSTREAM`). The
bundle (`.agents/monorepo-agents-harness/core/VERSION`) is the source of truth during upgrades; the
active agent copies the new version file into `.agents/monorepo-agents-harness/VERSION`. Every
release documents behavior changes in `CHANGELOG.md` under **Upgrade Notes**, and the actual upgrade
steps are described in `changelogs/version-X.Y.Z.md` prompts for the active agent to read and apply.

**Check** (manual, or via the agent command):

```bash
bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check          # exit: 0 current · 1 outdated · 2 unknown
bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check --json   # {"installed","latest","status","upstream"}
```

Or ask your agent: `/monorepo-harness:update` (claude-code) /
`/monorepo-harness-update` (opencode). The shared workflow lives in
`core/skills/harness-update/SKILL.md`: it reports the diff, asks for consent, then reads and applies
the changelog prompts.

**Upgrade** (consent-gated; driven by `changelogs/version-X.Y.Z.md` prompts):

```bash
git clone --depth 1 --branch v<latest> https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-update-tmp
```

Then let your agent apply the upgrade by following the prompts in
`.agents/.harness-update-tmp/changelogs/version-<latest>.md` (and any intermediate version prompts).
The agent copies files, deletes obsolete files, runs commands, and presents manual follow-ups. As its
final steps the agent reconciles your root `AGENTS.md` against the new `core/root-AGENTS.md`
(`core/skills/harness-update/SKILL.md` step 9, backed by `core/skills/agents-md-merge/SKILL.md`) and
removes the installed `.agents/monorepo-agents-harness/changelogs/` directory (step 10) — that
directory is never a prompt source, prompts are always read from the temporary clone. The `AGENTS.md`
reconciliation is a three-way merge against the template version recorded in your file's provenance
marker (or an additive adoption merge if the file has no marker yet), presented as a clean diff and
**written only after you approve it** — declining leaves the file untouched. The upgrade still
**never touches**: `.agents/` working state and task history, or adapter configs (re-apply merges per
your adapter README — see the follow-ups the agent prints).

