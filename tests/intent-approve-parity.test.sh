#!/usr/bin/env bash
# Parity check for `/monorepo-harness-intent --approve` (issue #51).
# Repo-local, never installed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected '$3' in $2" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "files differ"; fi; }

SKILL="$REPO/core/skills/intent-workflow/SKILL.md"
TS="$REPO/core/scripts/task-state.sh"
FORGE="$REPO/core/scripts/forge.sh"
CLAUDE="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-intent.md"
OPENCODE="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-intent.md"
CODEX="$REPO/adapters/codex/.agents/skills/monorepo-harness-intent/SKILL.md"
ARG="$REPO/tests/argument-hint.test.sh"
HINT="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-intent.md"

says "skill has Workflow — Approve" "$(grep -n '^## Workflow — Approve' "$SKILL")" "Workflow — Approve"
says "skill description mentions approve" "$(grep -n 'description:' "$SKILL" | head -1)" "approve"

c1="$(grep -n '^[0-9]\+\. If the user passes \`--approve' "$CLAUDE")"
c2="$(grep -n '^[0-9]\+\. If the user passes \`--approve' "$OPENCODE")"
c3="$(grep -n '^[0-9]\+\. If the user passes \`--approve' "$CODEX")"
[ -n "$c1" ] && ok "claude has --approve bullet" || bad "claude has --approve bullet" "missing"
[ -n "$c2" ] && ok "opencode has --approve bullet" || bad "opencode has --approve bullet" "missing"
[ -n "$c3" ] && ok "codex has --approve bullet" || bad "codex has --approve bullet" "missing"

# The three bullets should be byte-identical to the text pattern
b1="$(grep -A 4 'If the user passes `--approve' "$CLAUDE")"
b2="$(grep -A 4 'If the user passes `--approve' "$OPENCODE")"
b3="$(grep -A 4 'If the user passes `--approve' "$CODEX")"
same "claude and opencode approve bullets identical" "$b1" "$b2"
same "claude and codex approve bullets identical" "$b1" "$b3"

says "merge-intent-pr has no approve mode" "$(grep -n 'approve_mode' "$TS")" ""
says "merge-intent-pr still reads reviews" "$(grep -n 'approval_from_pr' "$TS")" "approval_from_pr"
says "forge has approve subcommand" "$(grep -n '^  approve)' "$FORGE")" "approve)"
says "forge approve never calls merge" "$(grep -n 'merge-intent-pr' "$FORGE" | head -1)" ""

# hint
h="$(grep -n "monorepo-harness-intent)" "$ARG" | head -1)"
says "argument-hint lists approve and reject" "$h" "--approve"
says "argument-hint lists reject" "$h" "--reject"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
