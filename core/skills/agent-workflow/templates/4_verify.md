---
phase: verify
date: <YYYY-MM-DD>
slug: <slug>
---

# Verify: <Task title>

## Verification run
<Command(s) actually executed, verbatim, plus their real output/exit code — evidence, not narration>

## Red evidence
<Required for a `red-first` task; write "N/A" for an `evidence-only` task. Paste the verbatim test
command and failure output captured BEFORE the implementation. The failure must show the expected
behavior, not an import, compilation or setup error. If red was not captured first, or the test
changed after red was seen, revert only the fix (save your work first), rerun the test, and paste
that failure here — say that this was the after-the-fact negative check.>

## Acceptance criteria results
- [x]/[ ] <criterion copied from 1_spec.md> — <how it was confirmed>

## Deviations
<Any acceptance criterion not met, or verification steps skipped and why>
