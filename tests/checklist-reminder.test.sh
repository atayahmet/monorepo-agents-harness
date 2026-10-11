#!/usr/bin/env bash
# Tests for `checklist-reminder.sh`: the "Before You Start" checklist an agent sees is read live from
# the root AGENTS.md, so it can never drift from the single source of truth (issue #29).
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# The drift guard has two halves: (1) the script emits exactly the template checklist (item count +
# the two items the old hand-copied hook dropped), and (2) nothing re-hardcodes a checklist into the
# hook config or a stage stub. If either stops being true, these fail.
#
# Run it from anywhere:  bash tests/checklist-reminder.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$REPO/core/scripts/checklist-reminder.sh"
TEMPLATE="$REPO/core/root-AGENTS.md"
SETTINGS="$REPO/adapters/claude-code/.claude/settings.json"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-cr-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
cp "$TEMPLATE" "$FIXTURE/AGENTS.md"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
not_says() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

text() { bash "$SCRIPT" --text --file "$FIXTURE/AGENTS.md" 2>&1; }
json() { bash "$SCRIPT" --file "$FIXTURE/AGENTS.md" 2>&1; }

# The expected item count, read from the template independently of the script's own extraction. The
# template's only `- [ ]` lines are the checklist's, so this is the number the reminder must carry.
EXPECTED_ITEMS="$(grep -c '^- \[ \]' "$TEMPLATE")"

# --- the emitted checklist IS the template checklist --------------------------------------------------
out="$(text)"
is "the template has 9 checklist items (fixture sanity)" "$EXPECTED_ITEMS" "9"
is "the reminder carries every template checklist item" "$(printf '%s\n' "$out" | grep -c '^- \[ \]')" "$EXPECTED_ITEMS"
says "the reminder starts at the checklist heading" "$out" "## Before You Start — Mandatory Checklist"
says "the reminder keeps the KB-first item the old hook dropped" "$out" "kb-index.sh query"
says "the reminder keeps the target-workspace item the old hook dropped" "$out" 'Resolve the **target workspace**'
says "the reminder keeps the trailing working-state note" "$out" "Working state is per-workspace"
not_says "the reminder stops at the next section" "$out" "## Core Principles"

# --- runtime read, not a frozen copy ------------------------------------------------------------------
# Add an item right after the heading; it must appear with no code change, because the script reads
# the file at run time.
sed -i.bak '/^## Before You Start — Mandatory Checklist$/a\
- [ ] SENTINEL-ITEM added after the heading.
' "$FIXTURE/AGENTS.md"
says "an item added to AGENTS.md shows up with no code change" "$(text)" "SENTINEL-ITEM"
cp "$TEMPLATE" "$FIXTURE/AGENTS.md"

# --- JSON hook mode -----------------------------------------------------------------------------------
out="$(json)"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
  ok "the hook mode emits valid hookSpecificOutput JSON"
else
  bad "the hook mode emits valid hookSpecificOutput JSON" "got: $out"
fi
says "the JSON additionalContext wraps the checklist in a system-reminder" "$out" "<system-reminder>"
says "the JSON additionalContext carries the KB item" "$out" "kb-index.sh query"

# --- fail-open ----------------------------------------------------------------------------------------
out="$(bash "$SCRIPT" --file "$FIXTURE/does-not-exist.md" 2>&1)"; rc=$?
is "a missing AGENTS.md exits 0" "$rc" "0"
is "a missing AGENTS.md prints nothing" "$out" ""
printf '# No checklist heading here\n\nsome body\n' > "$FIXTURE/empty.md"
out="$(bash "$SCRIPT" --file "$FIXTURE/empty.md" 2>&1)"; rc=$?
is "a file without the heading exits 0" "$rc" "0"
is "a file without the heading prints nothing" "$out" ""
is "an unknown flag is a usage error" "$(bash "$SCRIPT" --nope >/dev/null 2>&1; echo $?)" "2"

# --- reintroduction guard: no second copy of the checklist --------------------------------------------
if grep -q 'checklist-reminder.sh' "$SETTINGS"; then
  ok "the Claude reminder hook calls the script"
else
  bad "the Claude reminder hook calls the script" "settings.json never mentions checklist-reminder.sh"
fi
for prose in 'session-log.md' 'lessons.md' 'Resolve the \*\*target workspace\*\*' 'kb-index.sh query'; do
  if grep -q "$prose" "$SETTINGS"; then
    bad "settings.json no longer embeds checklist prose: $prose" "found '$prose' hand-copied into settings.json"
  else
    ok "settings.json no longer embeds checklist prose: $prose"
  fi
done
for stub in \
  "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-spec.md" \
  "$REPO/adapters/opencode/.opencode/commands/monorepo-harness-spec.md" \
  "$REPO/adapters/codex/.agents/skills/monorepo-harness-spec/SKILL.md"; do
  if grep -q 'checklist-reminder.sh' "$stub"; then
    ok "the -spec stub shows the checklist: ${stub#"$REPO"/}"
  else
    bad "the -spec stub shows the checklist: ${stub#"$REPO"/}" "no checklist-reminder.sh reference"
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
