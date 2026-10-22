---
description: Run the implementation for the task, gated on a valid spec/plan/intent chain, then write memory and verify
---

Follow the shared instructions in
`.agents/monorepo-agents-harness/core/skills/agent-workflow/SKILL.md` exactly, and gate with
`core/scripts/task-state.sh`:

1. Resolve the plan path the user typed after the command: `/monorepo-harness-build <2_plan.md>`.
2. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-chain <2_plan.md>`. If
   it exits non-zero, do **not** start; report the reason and stop.
3. Arm the memory-gate before touching any implementation file: run
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh mark-build <2_plan.md>`. It
   records `build_started` on the plan, which is the gate's signal that this task is being built and
   is therefore owed `3_memory.md` / `4_verify.md`. It is write-once, so a re-run is harmless.
4. Read the tier from `1_spec.md`'s `## Test / verification plan`. For a `red-first` task, **before
   touching any implementation file**, write the failing test(s) for the acceptance criteria (inside
   the scope `2_plan.md` already lists), run them, and capture the verbatim failure. It must show the
   expected behavior, not an import, compilation or setup error. Fallback: if red was not captured
   first, or the test changed after red was seen, save your work (diff or stash), revert **only** the
   fix, rerun the test, record that failure as the after-the-fact negative check, and restore your
   work.
   For an `evidence-only` task, skip the red step.
5. Run the implementation for the task following the plan/spec, **confined to `## Scope` /
   `## Acceptance criteria` in `1_spec.md` and `## Affected files / modules` in `2_plan.md`** — never
   create or touch an app, package, or file neither lists. If the scope must grow, stop and get the
   spec/plan extended and approved first.
6. On completion, write `3_memory.md` (frontmatter `phase: memory`, with `commits:` filled after the
   implementation commits and the matching `patch_ids:`) and `4_verify.md` (whenever the spec's "Test /
   verification plan" is not `N/A`) per Phase 3/4, including `## Red evidence` for a `red-first`
   task, and update `<workspace>/.agents/artifacts/index.md`. Commit the work.
7. Run `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-red-evidence <task_dir>`
   and follow its output. It is advisory and always exits 0; never treat a warning as a build
   failure. Then ingest this task into the repo-root knowledge base (Karpathy "LLM Wiki" pattern)
   **in the same commit**: run
   `bash .agents/monorepo-agents-harness/core/scripts/kb-ingest.sh <task_dir>` (skip quietly when the
   task is research-only / `N/A` and wrote no `3_memory.md`), then verify coverage with
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-kb <task_dir>` — see
   `core/skills/knowledge-base/SKILL.md`. Do not finish the task while `check-kb` exits non-zero.
8. When the build is finished, suggest a review. Run
   `bash .agents/monorepo-agents-harness/core/scripts/build-review-tier.sh <task_dir>` and read its
   first line. If it is `simple`, add one informational line to the closing report — the developer may
   run `/monorepo-harness-review`. If it is `comprehensive`, ask the developer whether to run
   `/monorepo-harness-review` now; on yes, run the `pr-review` skill inline and report its findings.
   This step is advisory — it never blocks the task.

Do **not** write `1_spec.md` or `2_plan.md` here — those belong to `/monorepo-harness-spec` and
`/monorepo-harness-plan`.
