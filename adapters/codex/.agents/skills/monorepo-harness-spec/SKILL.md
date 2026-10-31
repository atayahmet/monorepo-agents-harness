---
name: monorepo-harness-spec
description: Create the spec (1_spec.md) for the current task, gated on an approved intent. Use when the user types /monorepo-harness-spec <intent.md>.
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` exactly (Phase 1), and gate
with `core/scripts/task-state.sh`:

1. Apply the root `AGENTS.md` checklist before anything else: run
   `bash .agents/monorepo-agents-harness/core/scripts/checklist-reminder.sh --text`, then apply every
   reminder it prints (target workspace, session log, lessons, prior-art index, knowledge base, todo,
   plan mode, English, and the root/workspace instructions).
2. Resolve the target workspace (`apps/<name>` or `packages/<name>`).
3. Resolve arguments: `/monorepo-harness-spec [<intent.md>] [<phase-number> | <task-issue-url>]`. An
   intent is a **seed reference**, not a task. A spec always covers **exactly one task** and, when
   seeded by an approved intent, must be linked back via `0_intent.md`.
   - **If a phase number is given** (a positive integer): it is the **1-based position** of a phase in
     the `Phases:` list of the intent's **newest `## Dispatch` block**. A number is only meaningful
     inside one intent, so an intent is required: use the path given; if none was provided, search
     `<workspace>/.agents/intents/` for approved intents that have a `## Dispatch` block, and use the
     one that is the only match — if there are none or several, ask the user which intent — never
     guess. Run
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`
     (refuse if not approved). If the number is outside the list, do **not** write anything; report
     **"Phase N not found — newest Dispatch block lists M phases (1–M)"** and stop. Take the phase's
     slug and tracker key (`#<number>` or URL) from that line. If it has a key, run
     `bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh --show <key>` to read the issue
     title/body. If the line reads `no issue yet (<reason>)`, or the read fails (exit 3), there is no
     scope to read: ask the user what this spec covers — never guess. Then write **one** spec for
     that task only and create `0_intent.md` by running:
     `bash .agents/monorepo-agents-harness/core/scripts/write-intent-ref.sh <task_dir> <intent.md>`
   - **If a task link is given:** run `bash .agents/monorepo-agents-harness/core/scripts/tracker-issue.sh --show <task-issue-url>`
     to read the issue title/body. Find which approved intent contains that issue in its **newest
     `## Dispatch` block** (`#<number>` or URL). If no intent path was provided, search
     `<workspace>/.agents/intents/` for an approved intent whose newest `## Dispatch` block lists the
     issue; if none or multiple match, ask the user which intent/task to use — never guess. Run
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`
     (refuse if not approved). Match the issue to the phase/slug and proceed to write **one** spec for
     that task only. Create `0_intent.md` by running:
     `bash .agents/monorepo-agents-harness/core/scripts/write-intent-ref.sh <task_dir> <intent.md>`
     If the read fails (exit 3), ask the user which task this spec covers and what its scope is —
     never guess.
   - **If an intent path was given (and no phase number or task link):** run
     `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved <intent.md>`.
     If it exits non-zero, do **not** write anything; report the reason and stop. If the intent's
     newest `## Dispatch` block lists **more than one phase/task**, stop and ask
     **"This intent has several tasks — which task should this spec cover?"** (show each phase's
     number, slug and issue link; the user can answer with the number). Do not open multiple task
     directories or write multiple specs in one invocation.
     If it lists exactly one phase or there is no `## Dispatch` block, continue for that task. Then
     create `0_intent.md` by running:
     `bash .agents/monorepo-agents-harness/core/scripts/write-intent-ref.sh <task_dir> <intent.md>`
     This writes the reference stub (`phase: intent-ref`) from SKILL.md Phase 1 — never copy the
     intent content manually.
4. Query the knowledge base first (Phase 1 check 1): run
   `bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<1–3 keywords>"`, read the
   top hits it ranks, and keep them ready to cite in `2_plan.md`'s `## Related prior work`.
5. Create the task directory and write `1_spec.md` (the "what": contract, acceptance criteria) per
   Phase 1.
6. Update `<workspace>/.agents/artifacts/index.md` with a new row for this task.
7. If no intent path was given, proceed as a normal ad-hoc spec (no `0_intent.md`).
8. After writing `1_spec.md` and updating the index, **STOP here**. Do **not** write `2_plan.md`,
   and do **not** start implementation. The user must run `/monorepo-harness-plan <1_spec.md>` next —
   implementation may not begin until an approved plan exists.
