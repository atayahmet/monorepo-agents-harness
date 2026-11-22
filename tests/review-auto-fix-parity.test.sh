#!/usr/bin/env bash
# Contract test for `/monorepo-harness-review --auto-fix` (issue #77).
#
# Structural on purpose: the loop control is model-followed prose, so the contract lives in the stub
# and skill text. The test proves every adapter documents the same flags, that the stub bodies are
# byte-identical, that report-only stays the default, and that the shared skill states the loop
# rules once (disputed findings, stop-and-ask, artifacts once at the end, no push).
#
# Repo-local: not listed in core/install-manifest.txt, so it never reaches a consumer bundle.
#
# Run it from anywhere:  bash tests/review-auto-fix-parity.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected text to mention '$3'" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "bodies differ"; fi; }

STUBS=(
  "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-review.md"
  "$REPO/adapters/opencode/.opencode/commands/monorepo-harness-review.md"
  "$REPO/adapters/codex/.agents/skills/monorepo-harness-review/SKILL.md"
)
PR_SKILL="$REPO/core/skills/pr-review/SKILL.md"
WF_SKILL="$REPO/core/skills/agent-workflow/SKILL.md"

# body <file> - everything after the closing frontmatter delimiter.
body() {
  awk '
    BEGIN { fm=0; done=0 }
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm && !done && /^---[[:space:]]*$/ { done=1; next }
    done || !fm { print }
  ' "$1"
}
# step1 <file> - the numbered step 1 through the line before step 2.
step1() { awk '/^1\. /{on=1} /^2\. /{on=0} on' "$1"; }

printf '\nreview stubs document --auto-fix\n'
for f in "${STUBS[@]}"; do
  rel="${f#"$REPO"/}"
  text="$(body "$f")"
  says "$rel step 1 names --auto-fix" "$(step1 "$f")" '--auto-fix'
  says "$rel step 1 names --fix-nits" "$(step1 "$f")" '--fix-nits'
  says "$rel step 1 names --max-rounds" "$(step1 "$f")" '--max-rounds <n>'
  says "$rel step 1 accepts flags in any position" "$(step1 "$f")" 'any position'
  says "$rel step 1 notes flags ignored without --auto-fix" "$(step1 "$f")" 'ignored without `--auto-fix`'
  says "$rel runs the preflight" "$text" 'review-fix-loop.sh preflight'
  says "$rel points at the skill loop section" "$text" '## Review-fix loop (--auto-fix)'
  says "$rel keeps report-only as the default" "$text" 'Without `--auto-fix` this produces a report only'
  says "$rel never pushes" "$text" 'Never push'
done

printf '\nstub bodies are byte-identical across adapters\n'
b0="$(body "${STUBS[0]}")"
for f in "${STUBS[@]:1}"; do
  same "${f#"$REPO"/} body matches claude-code" "$(body "$f")" "$b0"
done

printf '\npr-review skill states the loop once\n'
loop="$(awk '/^## Review-fix loop \(--auto-fix\)/{on=1; next} /^## /{on=0} on' "$PR_SKILL")"
says "loop section exists" "$loop" 'review-fix-loop.sh preflight'
says "loop default round limit" "$loop" 'default 2'
says "loop nits need --fix-nits" "$loop" '--fix-nits'
says "loop marks unreproducible findings disputed" "$loop" 'disputed'
says "loop stops and asks" "$loop" 'stop and ask'
says "loop checks new files" "$loop" 'review-fix-loop.sh check-fix'
says "loop security trigger" "$loop" 'review-fix-loop.sh security-due'
says "loop writes artifacts once at the end" "$loop" 'once, at the end'
says "loop syncs commits once" "$loop" 'sync-commits'
says "loop never pushes" "$loop" 'never push'
says "loop round commit message" "$loop" 'fix(review): round'
outscope="$(awk '/^## Out of scope/{on=1; next} /^## /{on=0} on' "$PR_SKILL")"
says "out of scope notes local commits only with --auto-fix" "$outscope" '--auto-fix'

printf '\nbuild flow offers the loop\n'
after="$(awk '/^## After the build/{on=1; next} /^## /{on=0} on' "$WF_SKILL")"
says "After the build offers --auto-fix" "$after" '/monorepo-harness-review --auto-fix'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
