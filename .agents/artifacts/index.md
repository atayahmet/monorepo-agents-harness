# monorepo-agents-harness Agent Tasks Index

Task index for this workspace (`.agents/artifacts/`). Each `task_<YYYY_MM_DD>_<slug>/`
dir contains `1_spec.md`; dirs marked ◆ also contain `2_plan.md` + `3_memory.md`. Links point to
the spec. 31 tasks, 2026-09-03 — 2026-10-22.

**Type legend:** `F` bugfix · `R` readability/refactor · `I` infrastructure/cross-cutting · `E` new endpoint/feature
<!-- Extend the legend with your own single-letter codes as needed. -->

## shared / cross-cutting infra

| Date  | Type | Task | Summary |
| ----- | ---- | ---- | ------- |
| 09-03 | I | [harness_map](task_2026_09_03_harness_map/1_spec.md) ◆ | Track self-improve components in harness map |
| 09-21 | R | [agent_workflow_skill_fixes](task_2026_09_21_agent_workflow_skill_fixes/1_spec.md) ◆ | Fix agent-workflow skill docs (counts, workspace, research path) |
| 09-21 | R | [build_scope_confinement](task_2026_09_21_build_scope_confinement/1_spec.md) ◆ | Confine -build implementation to approved spec/plan scope |
| 09-21 | R | [agent_workflow_skill_trim](task_2026_09_21_agent_workflow_skill_trim/1_spec.md) ◆ | Slim agent-workflow SKILL.md to ~220 lines (templates to files) |
| 09-22 | E | [changeset_draft_command](task_2026_09_22_changeset_draft_command/1_spec.md) ◆ | Draft changesets-compatible release entries from task artifacts |
| 09-22 | I | [project_rules_seed](task_2026_09_22_project_rules_seed/1_spec.md) ◆ | Seed starter .agents/rules/ rule for AGENTS.md upkeep in workspace dirs (nested inclusive) |
| 09-23 | I | [knowledge_base_ingest](task_2026_09_23_knowledge_base_ingest/1_spec.md) ◆ | Task-end incremental root knowledge/ KB compiled from 3_memory/adr/4_verify |
| 09-24 | R | [simple_english](task_2026_09_24_simple_english/1_spec.md) ◆ | Ship shared simple-English rule for all generated content and developer messages |
| 09-25 | E | [update_command_prompt](task_2026_09_25_update_command_prompt/1_spec.md) ◆ | Ship /monorepo-harness-update per adapter with the README update prompt in core/prompts/ |
| 09-25 | E | [intent_execute_command](task_2026_09_25_intent_execute_command/1_spec.md) ◆ | Execute an approved intent into 3-5 phases, one task dir + tracker issue per phase |
| 09-28 | I | [dispatch_dedup_and_pr_merge](task_2026_09_28_dispatch_dedup_and_pr_merge/1_spec.md) ◆ | Check the tracker for already-open work before filing, then ask before merging the intent PR |
| 09-28 | I | [dispatch_issues_only](task_2026_09_28_dispatch_issues_only/1_spec.md) ◆ | Dispatch opens one issue per phase and writes no spec/plan; PR approval checked before the file |
| 09-28 | I | [tracker_infer_confirm_cache](task_2026_09_28_tracker_infer_confirm_cache/1_spec.md) ◆ | Infer tracker from consumer git config, confirm + cache it in .agents/tracker.md, refuse the harness repo |
| 09-28 | I | [platform_dispatched_pr_merge](task_2026_09_28_platform_dispatched_pr_merge/1_spec.md) ◆ | Merge intent PRs on any forge: resolve the host, discover the project's MCP/skill/CLI, never infer approval from an unreadable review |
| 09-29 | E | [dispatch_epic_and_task_keys](task_2026_09_29_dispatch_epic_and_task_keys/1_spec.md) ◆ | Ask at N>=2 whether to group phases under one parent epic, link every phase as its sub-issue via `tracker-issue.sh --parent`, and record the epic + every phase key in the intent's append-only `## Dispatch` block (v0.4.0-rc.8, closes #7 + #8) |
| 09-29 | F | [memory_gate_stage_scope](task_2026_09_29_memory_gate_stage_scope/1_spec.md) ◆ | memory-gate enforces only after `build_started` on the plan, and honours `stop_hook_active` (v0.4.0-rc.9, closes #17) |
| 10-03 | F | [hook_arm_scope_and_commits](task_2026_10_03_hook_arm_scope_and_commits/1_spec.md) | hook-arm-build scoped to today + own workspace, task dirs ordered by dir-name date, `sync-commits` maps rebased shas by patch-id (v0.4.0-rc.10, closes #19 + #20 + #21) |
| 10-07 | F | [repo_root_task_scan](task_2026_10_07_repo_root_task_scan/1_spec.md) ◆ | memory-gate + hook-arm-build scan `$ROOT/.agents/artifacts/task_*`, hook resolves a new-file path (v0.4.0-rc.12, closes #22) |
| 10-07 | E | [kb_fts5_index](task_2026_10_07_kb_fts5_index/1_spec.md) ◆ | `kb-index.sh` ranks knowledge/ queries via derived SQLite FTS5 cache, gitignore fragment, `/monorepo-harness-kb-index` (closes #25) |
| 10-11 | F | [kb_query_first](task_2026_10_11_kb_query_first/1_spec.md) ◆ | root-AGENTS KB-first names `kb-index.sh query`; knowledge-base skill triggers at spec/plan start (v0.4.0-rc.14, closes #30) |
| 10-11 | R | [spec_kb_prior_art](task_2026_10_11_spec_kb_prior_art/1_spec.md) ◆ | agent-workflow Phase 1 runs `kb-index.sh query` before the index grep; plan template asks KB citations (v0.4.0-rc.15, closes #27) |
| 10-11 | R | [stage_stub_kb_query](task_2026_10_11_stage_stub_kb_query/1_spec.md) ◆ | all six `-spec`/`-plan` adapter stubs run `kb-index.sh query` (Phase 1 check 1) before their artifact; PORTABILITY/INSTALL sync (v0.4.0-rc.16, closes #28) |
| 10-11 | F | [checklist_reminder_single_source](task_2026_10_11_checklist_reminder_single_source/1_spec.md) ◆ | `checklist-reminder.sh` reads the root `AGENTS.md` checklist at run time; claude `ExitPlanMode` hook + all three `-spec` stubs use it; drift test (v0.4.0-rc.17, closes #29) |
| 10-11 | R | [prior_art_trace](task_2026_10_11_prior_art_trace/1_spec.md) ◆ | plan's `## Related prior work` records the KB query as a `- KB:` line; `check-plan`/`check-chain` advise (fail-open), pr-review Nit (v0.4.0-rc.18, closes #32) |
| 10-11 | F | [claude_md_import_guard](task_2026_10_11_claude_md_import_guard/1_spec.md) ◆ | `audit-install.sh` + `install-adapter.sh` detect a template pointer file missing its `@AGENTS.md` import (template-driven, non-destructive) (v0.4.0-rc.19, closes #31) |
| 10-12 | R | [intent_kb_prior_art](task_2026_10_12_intent_kb_prior_art/1_spec.md) ◆ | intent Capture/Review run `kb-index.sh query` over `knowledge/` and record the result in the intent's `## Prior art` (v0.4.0-rc.20, closes #39) |
| 10-13 | E | [build_review_suggestion](task_2026_10_13_build_review_suggestion/1_spec.md) ◆ | a finished build suggests `/monorepo-harness-review` via `build-review-tier.sh` (simple one-liner vs comprehensive question, advisory) (v0.4.0-rc.21, closes #41) |
| 10-13 | I | [objectivity_rule](task_2026_10_13_objectivity_rule/1_spec.md) ◆ | ship an objectivity rule (`objectivity.md`) so the agent never flatters or agrees without evidence: gotcha + Reference Map row + manifest row, no gate (v0.4.0-rc.22, closes #42) |
| 10-18 | E | [intent_reject_flag](task_2026_10_18_intent_reject_flag/1_spec.md) ◆ | `/monorepo-harness-intent --reject <PR-url>...` records `status: rejected` + `## Review` on the PR branch and merges via `merge-intent-pr --reject` (gate = the in-turn decision, not a PR approval; ADR 0001) (v0.4.0-rc.23, closes #45) |
| 10-22 | I | [red_first_test_rule](task_2026_10_22_red_first_test_rule/1_spec.md) ◆ | Tiered red-first test rule: spec tier, `## Red evidence`, advisory `check-red-evidence`, build stubs (v0.4.0-rc.24, closes #46) |

<!--
  MANDATORY (see core/governance/artifacts/AGENTS.md in the harness bundle): every add/update/delete
  on a task directory updates this index in the same commit. Group rows by target module
  (## <module>); keep the header task count + date range in sync; append ◆ once 3_memory.md exists.
  Keep rows greppable: fixed columns, stable slugs, concrete identifiers in summaries.
-->
