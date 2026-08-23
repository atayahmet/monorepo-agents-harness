# Agent Guidelines — `adapters/`

Per-agent enforcement wiring for the harness. **`core/` holds everything every agent shares;
`adapters/<agent>/` holds only what the agent's own hook/plugin/command API requires.** The rules
below apply whenever you create or edit anything under this directory.

## Golden Rule — mandatory parity

> For every harness capability, each installed agent MUST have a live equivalent. If the agent has
> no direct mechanism, fall back to the agent-agnostic row (an `AGENTS.md` rule and/or the git/CI
> gate) so the capability is **preserved, not lost**.

Before changing any capability, check the matrix in `../PORTABILITY.md` and update its column(s)
in the same change.

## Hard Rules

1. **Keep adapters thin.** Logic lives in `core/scripts/*.sh`, templates in `core/skills/**`.
   Adapters only *wire* those artifacts into the agent's API (hooks, plugins, commands, config).
   Never reimplement gate/update logic inside an adapter.
2. **Never copy instruction content.** Agent-specific instruction files (e.g. root `CLAUDE.md`)
   must be thin pointers (`@AGENTS.md`) to the single source of truth — never a copy of it.
3. **Fail-open hooks.** Hook/plugin wiring must degrade gracefully: missing `jq`/git/bundle →
   exit 0 with no block, so they coexist safely with other hooks.
4. **One README per adapter, fixed structure:** "What maps to what" table, Prerequisites,
   Install steps, Verify, Notes / semantic differences. Follow the existing two verbatim in shape.
5. **Update the docs in the same commit** when you add/change an adapter or capability:
   - `../PORTABILITY.md` — capability matrix + semantic-difference notes;
   - `../INSTALL.md` — Phase 2 table (Agent / Adapter / Guide) if a new adapter ships.
6. **Slash commands ship only for harness plumbing** (the update check). Project-specific commands
   do not belong here (see `../INSTALL.md` §7).
7. **Shipped dependencies.** If an adapter ships a `package.json` (e.g., a plugin that needs
   `node_modules`), the adapter README install steps MUST include installing those dependencies
   (`npm install`, `pnpm install`, or equivalent) before copying files into the target repo. Never
   assume `node_modules` is already present.
8. **English everywhere** — all files under this tree are English-only.
9. **Commits are mandatory at the end of any file-changing task** unless the user explicitly opts out.

## What the `agent-workflow` skill expects from every adapter

`core/skills/agent-workflow/SKILL.md` defines the plan → spec → memory loop. Each adapter's
enforcement layer must support exactly these expectations (native mechanism or fallback):

1. **Task directory convention** — one dir per task:
   `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` containing `1_plan.md`, `2_spec.md`,
   `3_memory.md`. `<slug>` is `snake_case`, `[a-z0-9_]`, 3–5 words, decided in the plan phase and
   never renamed; dashes in the date become `_` (`2026-06-03` → `task_2026_06_03_<slug>`).
   The gate discovers tasks by scanning `apps/*/.agents/artifacts/` +
   `packages/*/.agents/artifacts/` — placement is load-bearing, do not invent other locations.
2. **Plan/spec reminder at plan-mode exit** — when the agent exits plan mode, *before the first
   implementation Edit/Write*, it must be nudged to create the task dir and write `1_plan.md`
   (frontmatter `phase: plan`, `status: approved`) then `2_spec.md` (`phase: spec`) in the same
   directory. Templates come from the SKILL.md — never redefined per adapter.
3. **Memory-gate at task end** — a task may not close until today's task dir contains
   `3_memory.md` (`phase: memory`, `commits:` listing SHAs written *after* committing). Wire
   `core/scripts/memory-gate.sh`; hard-block if the agent API allows blocking, otherwise install
   the git pre-commit/CI gate (see Golden Rule).
4. **Index sync** — any task-dir change must land with an updated
   `<workspace>/.agents/artifacts/index.md` row in the same commit (rules:
   `core/governance/artifacts/AGENTS.md`). Adapters must not duplicate or bypass indexing rules.
5. **Workspace selection** — artifacts go to the workspace whose paths the task touches
   (`apps/<name>` or `packages/<name>`); cross-workspace work uses the primary workspace and notes
   the secondary in the plan. Adapters must not change this rule.
6. **Edge cases to preserve** — research-only tasks (plan without implementation) may skip
   spec/memory; updating a task appends a `revisions:` log to `1_plan.md` instead of opening a new
   dir; no task dir → hooks stay silent (implementation without plan mode is out of scope).

When authoring or reviewing an adapter, verify each row above against the "what maps to what"
table in its README.

## Adding a new adapter

1. Read `../PORTABILITY.md` ("Authoring a new adapter") and walk the capability matrix column by
   column: native mechanism or fallback row for each capability.
2. Create `adapters/<agent>/` with: config/hooks/plugin wiring + `README.md` (rule 4) + any thin
   pointer/instruction file the agent needs. If the adapter has a `package.json`, document
   `npm install` (or equivalent) in the install steps.
3. Register it: `../PORTABILITY.md` matrix columns, `../INSTALL.md` §5 table, `../README.md`
   mentions if present.

## Verification before done

```bash
# shell syntax of anything script-shaped you touched
bash -n <changed-script-or-hook>

# JSON configs stay valid
jq . <changed-config>.json >/dev/null && echo OK

# memory-gate still passes end-to-end (per ../INSTALL.md §8 smoke test)
```

Adapter-specific checks (skill registration, hook firing, plugin load) are documented in each
adapter's README — run those too.
