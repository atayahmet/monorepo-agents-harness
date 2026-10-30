#!/usr/bin/env bash
# Parity check for `/monorepo-harness-intent --pr` (issue #60): the shared skill, the three adapter
# entry points and forge.sh must all carry the same capture-and-open-PR contract.
# Repo-local, never installed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to find: $3" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "files differ"; fi; }

SKILL="$REPO/core/skills/intent-workflow/SKILL.md"
FORGE="$REPO/core/scripts/forge.sh"
GOV="$REPO/core/governance/intents/AGENTS.md"
CLAUDE="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-intent.md"
OPENCODE="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-intent.md"
CODEX="$REPO/adapters/codex/.agents/skills/monorepo-harness-intent/SKILL.md"

skill="$(cat "$SKILL")"
says "skill description mentions --pr" "$(grep -m1 '^description:' "$SKILL")" "--pr"
says "skill has the With --pr section" "$skill" 'With `--pr`'
says "skill pushes with -u" "$skill" "git push -u origin intent/<slug>"
says "skill opens the PR through forge.sh create" "$skill" "forge.sh create --head intent/<slug>"
says "skill records pr: in a second commit" "$skill" "chore(intent): record PR link"
says "skill uses the fixed PR body line" "$skill" "No code change. Approving this PR approves the intent."
says "skill reports the approve next step" "$skill" "/monorepo-harness-intent --approve <url>"
says "skill guards an existing branch" "$skill" "intent/<slug>\` already exists"
says "skill never stages more than the intent" "$skill" "Never \`git add -A\`"
says "skill keeps --pr out of the review path" "$skill" "never a review decision"
says "skill refuses --pr with --approve/--reject" "$skill" 'usage error'
says "skill runs one PR per intent" "$skill" "Never put two intents in one commit or one PR"

b1="$(grep -A 5 'If the user passes `--pr' "$CLAUDE")"
b2="$(grep -A 5 'If the user passes `--pr' "$OPENCODE")"
b3="$(grep -A 5 'If the user passes `--pr' "$CODEX")"
[ -n "$b1" ] && ok "claude has the --pr bullet" || bad "claude has the --pr bullet" "missing"
same "claude and opencode --pr bullets identical" "$b1" "$b2"
same "claude and codex --pr bullets identical" "$b1" "$b3"
says "the --pr bullet names forge.sh create" "$b1" "forge.sh create"
says "the --pr bullet is no review decision" "$b1" "no approve, no merge"
says "claude argument-hint lists --pr" "$(grep -m1 '^argument-hint:' "$CLAUDE")" "--pr [--draft]"

says "forge has a create subcommand" "$(grep -n '^  create)' "$FORGE")" "create)"
says "forge create never pushes" "$(grep -c 'git push' "$FORGE")" "0"
says "governance says pr: can be written at capture" "$(cat "$GOV")" "capture"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
