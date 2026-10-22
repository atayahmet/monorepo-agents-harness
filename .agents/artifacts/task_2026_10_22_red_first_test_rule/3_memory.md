---
phase: memory
date: 2026-10-22
slug: red_first_test_rule
commits: [0d13da4, 252ca42]
patch_ids: [8b15f5c0b4b8bbfcee01df10f3618ac9e59abeff, ac93602da7cf3562cfa9a70710e00f9cddd89bce]
---

# Memory: Tiered red-first test rule

## What was done (single paragraph)
Added a `Tier:` line to the spec's test plan, ordered failing-test → implementation pairs to the
plan template, and `## Red evidence` to verify. The agent-workflow skill and all three adapter build
entry points now write and run the failing test before implementation, with an explicit save/revert/
restore fallback when red was missed. `task-state.sh check-red-evidence` follows the established
advisory-in-`task-state.sh` pattern: it warns for a red-first task with missing or empty evidence and
always exits 0; a task without a tier line stays silent. Release `0.4.0-rc.24` ships the templates,
skill, root `AGENTS.md`, README/PORTABILITY and a 88-case repo-local suite; no new installed file
means no manifest row.

## Surprising findings
- The first version of the structural test compared `grep -n 'Run the implementation'` against the
  stub, but that phrase also appears in the YAML `description` on line 2. The test passed the wrong
  anchor; anchoring to `^[0-9][0-9]*\. Run the implementation` fixed the test, not the product.
- The suite's `exit=${PIPESTATUS[0]}` printout is blank under the zsh runner because the command was
  piped to `tail`. The suite still exits correctly; verification records the direct exit code.
- Four copy-the-repo mutations each failed the suite, and the failing assertion matched the mutation
  every time (non-zero exit, out-of-section tier, out-of-section evidence, legacy treated as
  red-first). This is stronger evidence than a green suite alone.
- `check-red-evidence` cannot prove ordering: it reads section presence and content only. That is why
  it must stay advisory — a hard gate would reward pasting any failure, including one produced after
  the implementation.

## If I did it again
Write structural assertions against the body of an installed stub, never against the whole file:
frontmatter is easy to match by accident. For parser contracts, use a real fixture tree and drive
the command end to end, then mutate the implementation in a throwaway copy; this catches both false
negatives and tests that pass for the wrong reason. Keep every advisory fail-open, including missing
directories and malformed specs, so it can never become an accidental gate.

## Related decisions
- **Tier lives in the test section, not plan frontmatter.** It is where a reader looks for "how will
  this be checked", and the same section then carries the commands. First line only, case-insensitive,
  rationale allowed after the value.
- **No tier line = legacy.** Existing task dirs must not acquire a warning they cannot satisfy
  retroactively. Unknown non-empty tiers get an advisory but are never treated as red-first.
- **Advisory, exit 0 on every path.** Issue #46 starts the rule advisory; `memory-gate.sh` remains the
  only blocker. The check is wired into every build stub after verify is written.
- **Changelog prompt included at the maintainer's request** even though this instruction/script-only
  release needs no command or manual follow-up.
