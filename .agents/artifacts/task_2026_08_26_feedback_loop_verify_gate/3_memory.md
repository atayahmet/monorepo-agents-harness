---
phase: memory
date: 2026-08-26
slug: feedback_loop_verify_gate
commits: [3801e0a31bd8c7d68745f235511bd12ce735b851]
---

# Memory: Feedback Loop enforcement — `4_verify.md` artifact + `verifier` subagent

## What was done (single paragraph)

Added a fourth per-task artifact, `4_verify.md`, required whenever a task's `2_spec.md` states a
non-`N/A` verification plan; extended `memory-gate.sh` to enforce it in both its default (git/CI)
and `--json` (Claude Code Stop hook) modes; added a `verifier` Claude Code subagent to produce the
evidence, with an explicit agent-agnostic fallback for opencode/codex documented in
`PORTABILITY.md`; propagated the artifact-quad change through every doc that previously documented
the triad verbatim; and released the change as v0.7.0, also folding in the already-implemented but
unversioned `2_spec.md` Data model / Test/verification plan sections.

## Surprising findings

- A `.gitignore` change (ignoring `**artifacts/`, `lessons.md`, `session-log.md`, `todo.md`)
  appeared mid-session from tooling outside this task's own edits — not something this task
  requested. Left uncorrected it would have silently disabled the harness's entire committed audit
  trail (the exact files the harness exists to track). Caught by noticing an unexplained `M
  .gitignore` in `git status` and reverted before committing.
- The existing default-mode `--json` Stop-hook block conveys its "block" decision entirely through
  the JSON payload's `decision` field, never through the process exit code (the script always
  `exit 0`s in `--json` mode) — easy to miss when reasoning about the gate's behavior from exit
  codes alone; verified this by direct observation during the scratch smoke tests rather than
  assuming it from reading the script.
- This repo has no `apps/`/`packages/` workspaces of its own (it's the harness template, not a
  consumer project), so this task's own artifacts had to be manually seeded at the repo root
  (`.agents/`) rather than via `scaffold-workspace-agents.sh`, which only targets discovered
  workspace parents. No harness bug — just a first-time root-workspace instantiation.

## If I did it again

Same approach. The N/A escape hatch (grepping `2_spec.md`'s "Test / verification plan" section for
a literal `N/A`) is deliberately narrow and format-dependent rather than a general markdown parser
— matches the script's existing flat, dependency-free style, and the format is entirely
harness-controlled (the skill's own template), so the narrowness is a feature, not a risk.

## Related decisions

- Kept the `◆` index marker's meaning unchanged ("plan + memory both present") rather than
  redefining it to also require verify — avoids widening an already-stable, documented format for a
  single release; a future need for a distinct verify marker can be added later without breaking
  this one.
- `4_verify.md` is required by both `memory-gate.sh` modes rather than gating the Stop hook to a
  softer "check" — the whole point of the Feedback Loop practice is that verification happens
  *before* a session reports done, not as an afterthought caught only at commit time.
- Chose a scratch git-init'd directory under this session's own scratchpad (not this repo) for the
  end-to-end smoke tests, to avoid polluting this repo's own working tree with fabricated task dirs.
