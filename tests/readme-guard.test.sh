#!/usr/bin/env bash
# Guard to keep README.md as a navigable landing page.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
README="$REPO/README.md"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }

lines=$(wc -l < "$README" | tr -d ' ')
if [ "$lines" -le 200 ]; then
  ok "README <= 200 lines ($lines)"
else
  bad "README <= 200 lines" "got $lines lines"
fi

# Quickstart should be reachable within first ~60 lines
# Look for "## Quickstart" in first 60 lines
if head -n 60 "$README" | grep -q "^## Quickstart"; then
  ok "Quickstart within first 60 lines"
else
  bad "Quickstart within first 60 lines" "not found in first 60"
fi

# Must have Start here table
if grep -q "Start here" "$README"; then
  ok "has Start here routing"
else
  bad "has Start here routing" "missing"
fi

# Must have command cheat sheet
if grep -q "Command cheat sheet" "$README"; then
  ok "has command cheat sheet"
else
  bad "has command cheat sheet" "missing"
fi

# Must reference scenarios docs
for i in 1 2 3 4 5; do
  if grep -q "docs/scenarios/0${i}" "$README"; then
    ok "references scenario 0$i"
  else
    bad "references scenario 0$i" "missing link"
  fi
done

# Must reference docs/intents or intent-workflow SKILL
if grep -q "docs/intents\|intent-workflow/SKILL" "$README"; then
  ok "references intents details"
else
  bad "references intents details" "missing"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
