# Agent Task Artifacts — Indexing Rules

Every workspace (`apps/<name>` or `packages/<name>`) owns its task history under
`<workspace>/.agents/artifacts/`: per-task directories produced by the `agent-workflow` skill plus a
mandatory `index.md`. Each workspace keeps its own `index.md`. **The index is the entry point —
read it before scanning task directories, and keep it searchable (rules below).**

## Directory layout (per workspace)

```
<workspace>/
  .agents/
    session-log.md         <- working state (sibling concern, not governed here)
    lessons.md / todo.md
    artifacts/             <- THIS convention
      AGENTS.md            <- pointer to these rules (seeded by the scaffold script)
      index.md             <- task index for the workspace (MANDATORY, seeded empty)
      task_<YYYY_MM_DD>_<slug>/
        1_plan.md          <- optional (research-only tasks skip implementation phases)
        2_spec.md          <- always present
        3_memory.md        <- optional (written at task end)
```

Workspaces are seeded by `turborepo-harness-template/core/scripts/scaffold-workspace-agents.sh`
(creates `artifacts/{AGENTS.md,index.md}`); re-run it after adding a workspace.

## Index format (`<workspace>/.agents/artifacts/index.md`)

Optimized for token-efficient lookup and mechanical search: one line per task, grouped by module,
minimal redundancy, fixed column order.

- **Grouping:** one `##` section per target module (e.g. `release-management`, `project`,
  `plugin-registry`). Small or one-off modules go under `## other modules`. Cross-module work goes
  under `## shared / cross-cutting infra`.
- **Row format (fixed):**
  `| MM-DD | Type | [slug](task_YYYY_MM_DD_slug/2_spec.md) | summary |`
  rows sorted by date within each section. Year is omitted from the date column (it is in the link
  path).
- **Summary:** ≤ 10 words, English, derived from the spec title. **Prefer concrete, greppable
  identifiers** (route path, class name, usecase name) over prose — this is what makes keyword
  search hit.
- **Link target:** always `2_spec.md` — the only file guaranteed to exist.
- **◆ marker:** appended after the link when the task dir contains the full triad (`1_plan.md` +
  `3_memory.md`).
- **Header line:** keeps the total task count and date range — update both when adding rows.

## Search optimization rules (why the format is rigid)

1. **Fixed columns, fixed order** — `grep '\[.*\](task_' index.md` always yields every task row;
   parsers never need heuristics.
2. **Stable slugs** — `snake_case`, `[a-z0-9_]`, decided at creation and **never renamed**. Slugs are
   primary keys: directory names, index links, and memory-file frontmatter must agree exactly.
3. **Concrete summaries** — route paths, endpoint names, class/function identifiers beat generic
   verbs. Searching "webhook" must surface `huawei_webhook_handler` from its summary alone.
4. **Module sections are predictable** — an agent looking for prior art checks
   `## <module>`, then `## shared / cross-cutting infra`, then `## other modules` — always in that
   order of likelihood.
5. **Global discovery recipes** (work across ALL workspaces without opening each one):
   ```bash
   # every index, one screen
   cat apps/*/.agents/artifacts/index.md packages/*/.agents/artifacts/index.md
   # keyword across all artifact trees
   grep -ril "webhook" apps/*/.agents/artifacts packages/*/.agents/artifacts
   # newest task anywhere
   ls -td apps/*/.agents/artifacts/task_* packages/*/.agents/artifacts/task_* | head -1
   ```
6. **English everywhere** — mixed-language rows break keyword search; the whole tree stays English.

### Type legend (single letters, defined once in the index header)

| Code | Meaning |
|---|---|
| `F` | bugfix |
| `R` | readability/refactor |
| `I` | infrastructure/cross-cutting |
| `E` | new endpoint/feature |

## Maintenance rules

> **MANDATORY:** Any add, update, or delete on a task directory MUST be reflected in the SAME
> commit's `index.md` — new dir → new row; changed scope/module → update the row (link, section,
> summary, ◆); deleted dir → remove the row. Also keep the header's task count and date range in
> sync. Never leave the index stale. **An `artifacts/` dir without an `index.md` is invalid state** —
> restore it from `core/governance/artifacts/index-template.md`.

1. **Every new task directory requires an index row** — added in the same commit that creates the
   task dir (or at task end alongside `3_memory.md`).
2. Place the row in the section matching the task's **target module**; verify the module from the
   spec's `modules/<name>` references, not from the slug alone.
3. If the task targets a module with no section yet: 1–2 tasks → `## other modules`; 3+ → create a
   dedicated section.
4. Add `◆` when `3_memory.md` is written; if the task started with only a spec, retrofit the marker
   when plan/memory files appear.
5. Keep the format stable — do not add columns, do not expand summaries, do not duplicate the type
   legend per section. The index must stay cheap to load into agent context and trivially greppable.
6. When a workspace gets its first task dir, its `index.md` already exists (scaffold-seeded);
   extend it — never recreate the format from scratch.
