---
phase: memory
date: 2026-08-27
slug: sdlc_commands
commits: [e0598ebe7954e0b03028d4b42a0fe6821fb6dc71]
---

# Memory: Per-SDLC-stage commands with a gated artifact chain

## What was done (single paragraph)

Replaced the single `/monorepo-harness-build` (which wrote spec+plan together with no intent gate)
with three composable SDLC stage commands — `-spec`, `-plan`, `-build` — each validating its input
via a new read-only `core/scripts/task-state.sh` (`check-intent-approved`, `check-spec`,
`check-plan`, `check-chain`) before acting. `-spec <intent.md?>` writes `1_spec.md` and only accepts
an approved intent (copying it as `0_intent.md`); `-plan <spec.md>` writes `2_plan.md` after
validating the spec and asking about plan mode; `-build <2_plan.md>` validates the whole chain then
runs the implementation and auto-writes `3_memory.md` + `4_verify.md`. Adapters stay thin (delegate
to the script + shared skill; only plan-mode detection is per-agent), manifests gain the new command
rows, and docs/PORTABILITY are updated. Version → `0.1.0-rc.3`.

## Surprising findings

- **A conditional intend gate, not a universal one, was the pivotal decision.** Making intent
  approval mandatory only for intent-seeded tasks (a `0_intent.md` exists) preserved the ad-hoc fast
  path; a universal gate would have made `-build` reject tasks that `-spec` legitimately allowed
  (ad-hoc ones), breaking valid workflows at the last gate. The chain validator therefore treats the
  *absence* of `0_intent.md` as valid, not as a failure.
- **Plan-mode detection is not scriptable** — each command stub relies on the model's own knowledge
  of its active mode (opencode has no hook/plugin for this), then asks the user. This is a real, if
  small, cross-agent semantic diff; documented in PORTABILITY.md.
- **`opencode.jsonc` needed no change.** The new command stubs reference the already-registered
  `agent-workflow` skill and shell out to `task-state.sh` at runtime; no new skill symlink or
  `instructions` entry was required. My initial worry about skill registration was unfounded.
- **`-build` auto-writing memory must still respect the "after commit" ordering** so `commits:` is
  populated — the Phase 3 rule carries over unchanged when build takes over the write.

## If I did it again

- Validate the `frontmatter_field` extraction (awk-based, regex-anchored to the first `---` block)
  against a broad set of real files earlier — my first sed one-liner failed on standard files and I
  caught it in smoke tests. The awk approach mirrors `memory-gate.sh` and is robust.

## Related decisions

- **Shared script (user-confirmed)** over prose-in-skills: runtime validation belongs in
  `core/scripts/` like `memory-gate.sh`.
- **Intent-only-when-given (user-confirmed)** for `-spec`; build's intent requirement conditional
  (user-confirmed) for consistency with that.
- **No separate `-memory`/`-verify` commands (user-confirmed)** — `-build` auto-generates them on
  completion, keeping the command surface small.
- **`-plan` asks about plan mode and proceeds without it on "no" (user-confirmed).**
- **`-build` = gate then implement (user-confirmed).**
- **`0.1.0-rc.3`** mid-`-rc.*` settling of a shared template; a `changelogs/version-0.1.0-rc.3.md`
  prompt IS warranted here (changed `-build` semantics + re-run-installer follow-up the manifests
  can't express).
