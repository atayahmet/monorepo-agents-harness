---
version: 0.11.1
from: 0.11.0
date: 2026-08-27
---

# Version 0.11.1 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.11.0 to 0.11.1.

**Repair release.** `changelogs/version-0.11.0.md` asked the *old* (pre-0.11.0) update workflow to
translate a "Files to copy" prose entry (`core/` -> `core/` (recursive directory copy)) into an
actual `rm -rf`+`cp -R`. At least one real upgrade through that prompt applied it incompletely —
e.g. `core/root-REVIEW.md` never reached the installed bundle. This release carries no new
capability; it exists purely to make the `core/`/`adapters/` sync self-executing instead of
agent-interpreted, so the transitional risk is closed for anyone still upgrading through it, and to
repair anyone already sitting on an incomplete 0.11.0 install.

## Files to copy from the new bundle to the installed bundle

(none — see Commands to run below; this release deliberately avoids the itemized-list mechanism
that caused the problem it fixes)

## Files to delete from the installed bundle (only if they exist)

(none)

## Commands to run

Run this exactly as written — do not paraphrase or partially apply it. It locates the temporary
clone made in step 2 of the update workflow itself (no version number to fill in), replaces `core/`
and `adapters/` wholesale, and verifies the result before continuing:

```bash
ROOT="$(git rev-parse --show-toplevel)"
BUNDLE="$ROOT/.agents/monorepo-agents-harness"
CLONE="$(find "$ROOT/.agents" -maxdepth 1 -type d -name '.harness-update-v*' 2>/dev/null | head -n1)"
if [ -z "$CLONE" ]; then
  echo "harness-update: no .agents/.harness-update-v* clone directory found — cannot repair core/adapters sync" >&2
  exit 1
fi
rm -rf "$BUNDLE/core"
cp -R "$CLONE/core" "$BUNDLE/core"
rm -rf "$BUNDLE/adapters"
cp -R "$CLONE/adapters" "$BUNDLE/adapters"
bash "$BUNDLE/core/scripts/harness-update.sh" verify-copy "$CLONE/core" "$BUNDLE/core"
bash "$BUNDLE/core/scripts/harness-update.sh" verify-copy "$CLONE/adapters" "$BUNDLE/adapters"
```

If either `verify-copy` line reports missing files or exits non-zero, stop and report it — do not
continue to the version-file update or report the upgrade complete.

## Manual follow-ups for the user

(none)

## Release summary

- Repairs an incomplete `core/`/`adapters/` sync that could occur when upgrading *through* the
  transitional `version-0.11.0.md` prompt (interpreted by the pre-0.11.0 update workflow, which
  translates prose "Files to copy" entries rather than executing fixed commands) — confirmed in
  practice: `core/root-REVIEW.md` failed to reach at least one installed bundle this way. This
  release's own prompt uses a self-locating, fully deterministic `Commands to run` block instead, so
  nothing is left to interpretation. Safe to apply even if your 0.11.0 install was actually complete
  — the commands are idempotent.
