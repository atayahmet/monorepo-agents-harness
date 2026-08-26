---
phase: spec
date: 2026-08-26
slug: feedback_loop_verify_gate
---

# Spec: Feedback Loop enforcement — `4_verify.md` artifact + `verifier` subagent

## Scope

**In:** the `4_verify.md` artifact (template + skill documentation), `memory-gate.sh` extension to
require it, the `verifier` Claude Code subagent, cross-adapter parity documentation
(`PORTABILITY.md`, `adapters/AGENTS.md`), governance doc updates, propagating the artifact-quad
change through every doc that enumerates the triad verbatim, and the `0.7.0` version bump
(including folding in the already-pending `changelogs/draft.md` content).

**Out:** Phases 2-4 of the roadmap (CI provider integration, PR review skill, intent-capture stage)
— each gets its own plan/spec cycle later. No change to `opencode`/`codex` adapter *files* beyond
documentation (they get no new subagent file — see Architectural constraints).

## Behavioral contract

- **Input:** a completed implementation whose `2_spec.md` states a non-`N/A` verification plan.
- **Output:** a `4_verify.md` file in the same task directory, containing the actual command(s) run
  and their real output/exit codes, plus a per-acceptance-criterion pass/fail mapping.
- **Side effects:** `memory-gate.sh` (default mode and `--json` Stop-hook mode) now additionally
  blocks/warns when `4_verify.md` is missing and required; a new subagent becomes available in
  Claude Code sessions that have this bundle installed.

## API / contracts

- `core/scripts/memory-gate.sh` CLI surface is unchanged (`--json` flag, exit codes, JSON shape) —
  only the *set of files checked* grows. No new flags.
- `2_spec.md`'s existing "## Test / verification plan" section becomes machine-read (grepped) for
  the literal string `N/A` immediately following the heading — this is a new, narrow contract on
  that section's exact formatting for the escape hatch to work reliably.

## Data model

`4_verify.md` frontmatter/body shape (see template in `1_plan.md`'s Approach section):
- Frontmatter: `phase: verify`, `date: <YYYY-MM-DD>`, `slug: <slug>` (same fields/format as
  `1_plan.md`/`2_spec.md`/`3_memory.md`).
- Body sections: `## Verification run` (verbatim command + output), `## Acceptance criteria
  results` (checklist mirroring `2_spec.md`'s own acceptance criteria), `## Deviations`.

No persisted/transmitted application data model is touched by this task itself (it's a workflow/
tooling change) — the "data model" above describes the new markdown artifact's own shape, listed
here because it's a structural contract other tooling (`memory-gate.sh`, future indexing) depends on.

## Acceptance criteria

- [ ] `agent-workflow` SKILL.md's Phase 4 section documents the `4_verify.md` template and the N/A
      rule, consistent with how Phases 1-3 are documented.
- [ ] `memory-gate.sh` default mode: exits `1` and lists `4_verify.md` among `missing` when a task
      dir has a non-N/A verification plan and no `4_verify.md`; exits `0` when N/A or when present.
- [ ] `memory-gate.sh --json` mode: Claude Code Stop hook emits a `{"decision":"block",...}` when
      `4_verify.md` is missing and required (mirroring the existing `3_memory.md` check); silent
      `exit 0` when N/A, present, or `jq` unavailable (fail-open preserved).
- [ ] `adapters/claude-code/.claude/agents/verifier.md` exists with `name: verifier`, restricted
      `tools:` (Bash/Read/Grep/Glob only — no Edit/Write), and instructions that explicitly say it
      does not fix issues.
- [ ] `PORTABILITY.md` capability matrix has a "Verifier subagent" row with an explicit
      agent-agnostic fallback for opencode/codex (no capability silently dropped, per the Golden
      Rule already stated in that file).
- [ ] Every doc found via `grep -rl "3_memory.md"` that documents the artifact set as an
      instructional/executable reference (not a frozen historical changelog entry) is updated to
      include `4_verify.md` where it would otherwise be misleading (e.g. smoke-test commands whose
      expected exit code would change).
- [ ] `core/VERSION` reads `0.7.0`; `CHANGELOG.md`'s `[Unreleased]` section is either filled or
      removed (no dangling empty section above a released entry), reference-link list includes
      `[0.6.0]` and `[0.7.0]`; `changelogs/version-0.7.0.md` exists per `changelogs/README.md`'s
      standard section format; `changelogs/draft.md` no longer exists.

## Test / verification plan

- **`memory-gate.sh` default mode, missing verify:** in this task's own dir, run
  `bash core/scripts/memory-gate.sh` before `4_verify.md` exists (with `2_spec.md` present, non-N/A
  verification plan) → expect `exit=1`, stderr lists `4_verify.md`.
- **`memory-gate.sh` default mode, N/A escape hatch:** create a scratch task dir with `2_spec.md`
  whose "Test / verification plan" section is `N/A` and no `4_verify.md` → expect `4_verify.md` NOT
  listed as missing (verify this empirically against the script once written).
- **`memory-gate.sh --json` mode:** run with `--json` before `4_verify.md` exists → expect a
  `{"decision":"block",...}` JSON object mentioning `4_verify.md`; after creating it → expect no
  output, `exit 0`.
- **This task's own dogfood run:** once implementation is complete, write this task's own
  `4_verify.md` documenting the above three checks' actual output, then run `memory-gate.sh` (both
  modes) against this very task dir and confirm it now passes.
- **Adapter parity check:** manually diff `PORTABILITY.md`'s new matrix row against
  `adapters/{opencode,codex}/` to confirm no file in those adapters silently references a
  nonexistent subagent capability.

## Architectural constraints

- **Keep adapters thin** (`adapters/AGENTS.md` Hard Rule 1): the `verifier` subagent's *logic*
  (what "done" verification means) stays defined by `agent-workflow` SKILL.md's Phase 4 instructions
  — `verifier.md` is a thin pointer/specialization for Claude Code's subagent mechanism, not a
  reimplementation.
- **No opencode/codex subagent file**: those agents have no native subagent primitive: per the
  Golden Rule, the capability is preserved via the agent-agnostic fallback (main session runs
  verification inline, same skill instructions), not by inventing a workaround file.
- **`memory-gate.sh` stays dependency-free** (`git` + coreutils only, `jq` optional/fail-open for
  `--json` mode) — the N/A-detection grep must not introduce a new hard dependency.
- **Additive only, no artifact-layout break**: existing task dirs without `4_verify.md` are never
  retroactively gated (the gate only ever inspects *today's* task dir, per existing `TODAY` logic).
- **Non-functional:** no performance/security implications (pure bash + markdown); compatibility
  constraint is the one above (additive, backward-compatible with all three adapters).
