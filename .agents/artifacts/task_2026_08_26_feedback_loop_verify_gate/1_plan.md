---
phase: plan
date: 2026-08-26
slug: feedback_loop_verify_gate
status: approved
---

# Plan: Feedback Loop enforcement — `4_verify.md` artifact + `verifier` subagent

## Problem

The harness's plan/spec/memory workflow has no enforced verification step: `2_spec.md`'s
"Test / verification plan" section is narrative only — nothing runs it or checks it before
`3_memory.md` closes the task. This is the harness's single largest gap against the AI-native SDLC
playbook's "Feedback Loop" practice (session self-checks before reporting done).

## Approach

Add a fourth per-task artifact, `4_verify.md`, that records the actual verification run (commands,
output, per-acceptance-criterion pass/fail) as evidence, not narration. Extend
`core/scripts/memory-gate.sh` to require it (both default git/CI mode and the Claude Code `--json`
Stop-hook mode, which today only checks `3_memory.md`), with the same N/A escape hatch already used
for research-only tasks. Add a `verifier` Claude Code subagent whose job is to produce that evidence,
with an explicit agent-agnostic fallback documented in `PORTABILITY.md` for opencode/codex (main
session runs the same verification commands inline — no capability loss per the Golden Rule).

## Related prior work

Grepped `.agents/artifacts/index.md` for `verify`/`feedback`/`memory-gate` — this is the first task
recorded in the root workspace's index (freshly seeded this session). No prior task to cite —
none found.

## Steps

1. `core/skills/agent-workflow/SKILL.md` — add Phase 4 (`4_verify.md`) template, directory-layout
   diagram update, edge cases.
2. `core/scripts/memory-gate.sh` — add `4_verify.md` check to `missing=()` (default mode) and to the
   `--json` block, both gated on `2_spec.md`'s "Test / verification plan" section not being `N/A`.
3. `adapters/claude-code/.claude/agents/verifier.md` — new subagent (Bash/Read/Grep/Glob only,
   read-only judgment, does not fix).
4. `PORTABILITY.md` — new "Verifier subagent" capability-matrix row with the opencode/codex fallback.
5. `adapters/AGENTS.md` — extend Hard Rule 6 (harness-plumbing-only) to cover subagents.
6. `core/governance/artifacts/AGENTS.md` — directory-layout section gains `4_verify.md`.
7. Propagate the artifact-triad → quad change through every doc that documents it verbatim:
   `README.md`, `INSTALL.md`, `adapters/{claude-code,codex,opencode}/{INSTALL,README}.md`,
   `core/root-AGENTS.md` (Gotcha #4), top-level `AGENTS.md` (Gotcha #5),
   `core/workspace-agents-template/session-log.md`.
8. `core/VERSION` → `0.7.0`; fix `CHANGELOG.md`'s stale `[Unreleased]` block and missing
   `[0.6.0]`/`[0.7.0]` reference links; write `changelogs/version-0.7.0.md` folding in both this
   feature and the already-pending `changelogs/draft.md` content (2_spec.md Data model +
   Test/verification plan sections); remove `changelogs/draft.md`.
9. Write `4_verify.md` + `3_memory.md` for this task, update `.agents/artifacts/index.md`, commit.

## Affected files / modules

Core skill/script/governance files (`core/`), the `claude-code` adapter (`adapters/claude-code/`),
cross-adapter docs (`PORTABILITY.md`, `adapters/AGENTS.md`), root-level docs (`README.md`,
`INSTALL.md`, `AGENTS.md`, `core/root-AGENTS.md`), versioning (`core/VERSION`, `CHANGELOG.md`,
`changelogs/`). No `apps/`/`packages/` exist in this repo — this task's own artifacts live at
`.agents/artifacts/` (root workspace, per "Workspace Routing & Execution" in `AGENTS.md`).

## Risks & assumptions

- **Ordering:** `4_verify.md` is written after `3_memory.md` in the numbering scheme (matches the
  user's explicit naming choice), but both are required by the time the Stop hook fires — order of
  authorship between them doesn't matter for gating purposes, only presence does.
- **N/A parsing:** the escape hatch relies on a grep for `N/A` directly under `2_spec.md`'s
  "## Test / verification plan" heading. Simple and consistent with the script's existing flat,
  non-function style — not a general markdown parser, so it only recognizes the exact convention
  the skill template produces.
- **Backward compatibility:** purely additive — existing task dirs without `4_verify.md` are never
  retroactively checked (the gate only inspects **today's** task dir), so no historical task breaks.
- **Scope:** this task does not touch Phases 2-4 of the roadmap (CI integration, PR review, intent
  capture) — those get their own plan/spec cycles per the approved roadmap.

## Definition of done

- [ ] `agent-workflow` SKILL.md documents Phase 4 and the N/A rule.
- [ ] `memory-gate.sh` blocks (both modes) when `4_verify.md` is missing and a verification plan is
      required; passes when N/A or when the file exists.
- [ ] `verifier.md` subagent exists and is referenced from the skill/adapter docs.
- [ ] `PORTABILITY.md` and `adapters/AGENTS.md` reflect the new capability with its fallback.
- [ ] Every doc that enumerated the plan/spec/memory triad now enumerates the quad (or explicitly
      still describes the triad only where accurate, e.g. historical changelog entries — untouched).
- [ ] `core/VERSION` = `0.7.0`; `CHANGELOG.md` and `changelogs/version-0.7.0.md` are consistent and
      `changelogs/draft.md` is gone.
- [ ] This task's own `4_verify.md` demonstrates the new gate against itself.
