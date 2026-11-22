#!/usr/bin/env bash
# Contract test for `/monorepo-harness-plan --no-plan-mode` (issue #76).
#
# Structural on purpose: plan-mode detection is the model's self-report, so the contract lives in
# the stub text. The test proves every adapter documents the same flag semantics, that the step-3
# branch is byte-identical across adapters, and that the plan-approval STOP survived.
#
# Repo-local: not listed in core/install-manifest.txt, so it never reaches a consumer bundle.
#
# Run it from anywhere:  bash tests/no-plan-mode-flag.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected text to mention '$3'" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "blocks differ"; fi; }

STUBS=(
  "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-plan.md"
  "$REPO/adapters/opencode/.opencode/commands/monorepo-harness-plan.md"
  "$REPO/adapters/codex/.agents/skills/monorepo-harness-plan/SKILL.md"
)
SKILL="$REPO/core/skills/agent-workflow/SKILL.md"

# step3 <file> - the numbered step 3 through the line before step 4.
step3() { awk '/^3\. /{on=1} /^4\. /{on=0} on' "$1"; }
# step1 <file> - the numbered step 1 through the line before step 2.
step1() { awk '/^1\. /{on=1} /^2\. /{on=0} on' "$1"; }

printf '\nplan stubs document --no-plan-mode\n'
for f in "${STUBS[@]}"; do
  rel="${f#"$REPO"/}"
  text="$(cat "$f")"
  says "$rel step 1 parses the flag" "$(step1 "$f")" '--no-plan-mode'
  says "$rel step 1 accepts the flag in any position" "$(step1 "$f")" 'any position'
  says "$rel step 3 skips the question with the flag" "$(step3 "$f")" 'do **not** ask'
  says "$rel step 3 no-op note when already in plan mode" "$(step3 "$f")" '`--no-plan-mode` ignored'
  says "$rel step 3 keeps the default question" "$(step3 "$f")" '"Enable plan mode?"'
  says "$rel still stops after the plan" "$text" 'STOP here'
done

printf '\nstep 1 and step 3 are byte-identical across adapters\n'
s1="$(step1 "${STUBS[0]}")"; s3="$(step3 "${STUBS[0]}")"
for f in "${STUBS[@]:1}"; do
  rel="${f#"$REPO"/}"
  same "$rel step 1 matches claude-code" "$(step1 "$f")" "$s1"
  same "$rel step 3 matches claude-code" "$(step3 "$f")" "$s3"
done

printf '\nshared skill documents the flag\n'
phase2="$(awk '/^## Phase 2/{on=1; next} /^## /{on=0} on' "$SKILL")"
says "agent-workflow Phase 2 names the flag" "$phase2" '--no-plan-mode'
says "agent-workflow Phase 2 keeps the approval gate" "$phase2" 'never skips the plan approval'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
