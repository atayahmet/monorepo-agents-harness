---
phase: verify
date: 2026-08-26
slug: feedback_loop_verify_gate
---

# Verify: Feedback Loop enforcement — `4_verify.md` artifact + `verifier` subagent

## Verification run

`bash -n core/scripts/memory-gate.sh` → `syntax OK` (checked twice, after each round of edits).

Scratch end-to-end run (fresh `git init`'d scratch dir under this session's scratchpad, fabricated
`apps/web/.agents/artifacts/task_<today>_smoke_test/`, `DETECT_SCRIPT` pointed at this repo's
`core/scripts/detect-monorepo-framework.sh`):

- **Default mode, nothing present** → stderr `agent-workflow gate: ... is missing: 2_spec.md
  3_memory.md`, `exit=1`.
- **Default mode, `2_spec.md` (Test/verification plan = "run smoke test") + `3_memory.md`, no
  `4_verify.md`** → stderr `... is missing: 4_verify.md`, `exit=1`.
- **Default mode, `4_verify.md` added** → `exit=0`.
- **`--json` mode, nothing present** → `{"decision":"block","reason":"...missing: 3_memory.md..."}`,
  script `exit=0` (block conveyed via JSON, not exit code, matching existing convention).
- **`--json` mode, spec+memory present, no verify** → `{"decision":"block","reason":"...missing:
  4_verify.md..."}`.
- **`--json` mode, verify added** → no output, `exit=0`.
- **N/A escape hatch**: `2_spec.md` with `## Test / verification plan\nN/A\n`, `3_memory.md`
  present, no `4_verify.md` → default mode `exit=0` (verify correctly not required).

## Acceptance criteria results

- [x] `agent-workflow` SKILL.md Phase 4 documents the `4_verify.md` template and the N/A rule —
      added, consistent with Phases 1-3's structure.
- [x] `memory-gate.sh` default mode blocks/passes correctly — confirmed above (3 scenarios).
- [x] `memory-gate.sh --json` mode blocks/passes correctly, including the previously-missing
      `4_verify.md` check — confirmed above (3 scenarios).
- [x] `adapters/claude-code/.claude/agents/verifier.md` exists with `name: verifier`, `tools: Bash,
      Read, Grep, Glob` (no Edit/Write), and explicit "does not fix" instructions.
- [x] `PORTABILITY.md` capability matrix has a "Verifier subagent" row with an explicit
      opencode/codex fallback (inline in main session), plus a "semantic differences" bullet.
- [x] Every doc found via the original `grep -rl "3_memory.md"` sweep (19 files) was reviewed;
      historical changelog entries (`changelogs/version-0.2.1.md`, `changelogs/version-0.6.0.md`)
      were deliberately left untouched (frozen historical record); all 17 remaining
      instructional/executable docs were updated (`README.md`, `INSTALL.md`, `AGENTS.md`,
      `core/root-AGENTS.md`, `core/skills/agent-workflow/SKILL.md`, `core/governance/artifacts/
      AGENTS.md`, `core/workspace-agents-template/session-log.md`, `adapters/AGENTS.md`,
      `PORTABILITY.md`, and all six adapter `INSTALL.md`/`README.md` files).
- [x] `core/VERSION` = `0.7.0`; `CHANGELOG.md`'s `[Unreleased]` section is now empty-but-present
      above a filled `[0.7.0]` entry (no dangling gap before `[0.6.0]`); reference-link list
      includes `[0.7.0]` and `[0.6.0]`; `changelogs/version-0.7.0.md` exists following
      `changelogs/README.md`'s standard section format; `changelogs/draft.md` removed.

## Deviations

None of the planned acceptance criteria were skipped. One unplanned finding, handled inline: a
`.gitignore` change (ignoring `**artifacts/`, `lessons.md`, `session-log.md`, `todo.md`) appeared
during this session from tooling outside this task's own edits — reverted immediately, since it
would have silently broken the harness's committed audit trail. See "Surprising findings" in
`3_memory.md`.
