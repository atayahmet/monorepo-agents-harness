---
name: self-improvement-workflow
description: Harvest recurring patterns from a project's agent working state (lessons, task memories, index) and propose durable project-owned rules (.agents/rules/*.md) and project-specific skills (.agents/skills/<new-skill>/SKILL.md). Use when the user runs /monorepo-self-improve or asks to turn repeated corrections and workflows into reusable agent instructions. Never modifies the installed harness bundle.
---

# Self-Improvement Workflow

Turn a project's accumulated agent working state into durable, discoverable instructions.

## Scope

This workflow is **read-analyze-propose-apply**:

- **Read** `<workspace>/.agents/lessons.md`, `<workspace>/.agents/artifacts/index.md`, and recent
  `3_memory.md` files.
- **Analyze** them for recurring themes, repeated corrections, and recurring workflows.
- **Propose** concrete `.agents/rules/*.md` files, `.agents/skills/<new-skill>/SKILL.md` files, and
  root `AGENTS.md` Reference Map updates.
- **Apply** only after explicit user approval in the same turn.

**First-iteration limits (by design):**
- Source code is not scanned.
- Workspace-level `AGENTS.md` files are not updated.
- Triggering is manual via `/monorepo-self-improve`.

## Inputs

Read these files from every workspace (`apps/<name>/`, `packages/<name>/`, and the repo root if it
owns its own `.agents/`):

1. `<workspace>/.agents/lessons.md` — durable corrections.
2. `<workspace>/.agents/artifacts/index.md` — task history and module groupings.
3. The most recent `N` `3_memory.md` files per workspace, default `N = 10`. Resolve them from the
   index rows or by listing `task_<YYYY_MM_DD>_<slug>/3_memory.md`.
4. Existing project-owned instructions:
   - `.agents/rules/*.md`
   - `.agents/skills/*/SKILL.md`
   - root `AGENTS.md` Reference Map

If no lessons, memory, or index entries exist, stop and report: "No agent working state found to
harvest. Complete a few tasks first."

## Pattern detection

Look for themes that appear more than once. Cluster by:

- **Repeated lesson title or bold lead-in** — e.g. "Always validate API inputs" appears in multiple
  lessons.
- **Recurring "If I did it again" / "Related decisions" themes** in `3_memory.md`.
- **Repeated task slugs/modules** in the index — the same module touched many times suggests a
  missing local rule or skill.
- **Repeated user corrections** — e.g. the user has corrected the agent on the same convention twice.

For each cluster, assign a **confidence**:

- **high** — same theme in 3+ sources or 2+ lessons.
- **medium** — same theme in 2 sources.
- **low** — single source but strong signal; list as "possible" only.

## Outputs

### 1. `.agents/rules/<topic>.md`

Use for simple constraints, checklists, or conventions. Follow the template in
`core/governance/rules/rule-template.md` (installed at
`.agents/monorepo-agents-harness/core/governance/rules/rule-template.md`).

A rule file must:
- Have a single, greppable H1 topic.
- Use `## **Bold lead-in**` for each rule item.
- Include a `Learned from:` footer linking the source lessons/memory files.
- Stay under 150 lines.

### 2. `.agents/skills/<new-skill>/SKILL.md`

Use for multi-step workflows that are easier to capture as a reusable skill than as a list of
rules. Example: "How we add a new API endpoint in this repo" or "How we onboard a new workspace."

A project-owned skill must:
- Have YAML frontmatter with `name` and `description`.
- Keep the body under 400 lines.
- Bundle deterministic scripts under `<skill>/scripts/` when useful.
- Never import or modify files under `.agents/monorepo-agents-harness/`.

### 3. Root `AGENTS.md` Reference Map update

Propose adding one row per new rule/skill topic. Do not rewrite the file; use
`core/skills/agents-md-merge/SKILL.md` to produce a consent-gated proposal.

## Approval gate

Before writing anything, present a structured report:

```
Detected N pattern(s):

1. <Pattern title> (confidence: high/medium/low)
   Sources: <list>
   Proposed files:
   - .agents/rules/<topic>.md
   - .agents/skills/<new-skill>/SKILL.md  (if applicable)
   Root AGENTS.md rows to add: <list>

[Show a short snippet of each proposed file.]

Apply these changes? (yes / no / edit)
```

- **yes** — write the files and reconcile root `AGENTS.md`.
- **no** — write nothing. Optionally offer to save the report to `.agents/self-improve-proposals/`.
- **edit** — take the user's instructions, regenerate the proposal, and ask again.

Never change `AGENTS.md` without going through `agents-md-merge`.

## Step-by-step workflow

1. Inventory all workspaces and their `.agents/lessons.md` files.
2. Inventory all workspace artifact indexes.
3. Read recent `3_memory.md` files (default 10 per workspace).
4. Inventory existing `.agents/rules/*.md` and `.agents/skills/*/SKILL.md`.
5. Cluster patterns and score confidence.
6. For each high/medium confidence pattern:
   - Decide: rule file, skill file, or both.
   - Draft the file(s) using the templates.
   - Draft the Reference Map row(s).
7. Present the proposal report.
8. On approval, write files and reconcile root `AGENTS.md`.
9. Confirm what was written and where.

## Hard constraints

- **Never modify `.agents/monorepo-agents-harness/` at runtime.** This includes `core/`, `adapters/`,
  scripts, manifests, and installed skill files.
- **No writes without explicit user approval.** The proposal report must be shown first.
- **Do not overwrite existing project-owned rules/skills silently.** If a file already exists,
  propose an update or a new file with a disambiguating suffix.
- **Keep adapters thin.** This skill contains all logic; the opencode command is only a pointer.

## Edge cases

- **No patterns detected.** Report "No strong patterns found" and suggest running again after more
  tasks or lessons accumulate.
- **Pattern matches an existing rule/skill.** Cite the existing file and propose an update instead of
  a duplicate.
- **No root `AGENTS.md`.** This is unexpected in an installed project. Report it and do not create
  one silently.
- **Root `AGENTS.md` merge declined.** Write the rule/skill files if the user approved those, but do
  not modify `AGENTS.md`. Surface the declined proposal path as a follow-up.
- **Mixed confidence.** Present high/medium items as "Proposed"; low items as "Possible — review
  separately". Do not auto-apply low-confidence items.

## Connection to other skills

- `agent-workflow` produces the `3_memory.md` files this skill consumes.
- `agents-md-merge` reconciles root `AGENTS.md`.
- `adr-workflow` is not triggered here; if a generated skill makes architecture-affecting decisions,
  it should be documented inside that skill's own instructions.
