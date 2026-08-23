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
7. **English everywhere** — all files under this tree are English-only.
8. **Commits are mandatory at the end of any file-changing task** unless the user explicitly opts out.

## Adding a new adapter

1. Read `../PORTABILITY.md` ("Authoring a new adapter") and walk the capability matrix column by
   column: native mechanism or fallback row for each capability.
2. Create `adapters/<agent>/` with: config/hooks/plugin wiring + `README.md` (rule 4) + any thin
   pointer/instruction file the agent needs.
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
