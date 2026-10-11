#!/usr/bin/env bash
# Tests for the prior-art (- KB:) advisory added by issue #32: a plan records whether the knowledge
# base was queried, and check-plan/check-chain surface that record as an advisory.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Every case runs against a throwaway fixture laid out like an installed project — the bundle at
# `.agents/monorepo-agents-harness/`. Run it from anywhere:  bash tests/prior-art.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-prior-art.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

# A clean fixture with the bundle installed the way a consumer gets it.
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  mkdir -p "$FIXTURE/.agents/monorepo-agents-harness" "$FIXTURE/apps/api/.agents/artifacts"
  cp -R "$REPO/core" "$FIXTURE/.agents/monorepo-agents-harness/core"
}

S="bash .agents/monorepo-agents-harness/core/scripts"
task_state() { ( cd "$FIXTURE" && $S/task-state.sh "$@" 2>&1 ); }
code()       { ( cd "$FIXTURE" && $S/task-state.sh "$@" >/dev/null 2>&1 ); echo $?; }

DIR="apps/api/.agents/artifacts/task_2026_01_01_prior_art"
PLAN="$DIR/2_plan.md"
SPEC="$DIR/1_spec.md"

# plan <related-prior-work-block-or-empty> — write a valid 2_plan.md (phase: plan). An empty second
# argument omits the `## Related prior work` section entirely.
write_spec() {
  mkdir -p "$FIXTURE/$DIR"
  cat > "$FIXTURE/$SPEC" <<'EOF'
---
phase: spec
date: 2026-01-01
slug: prior_art
---

# Spec: prior art

## Test / verification plan
N/A
EOF
}
write_plan() {
  mkdir -p "$FIXTURE/$DIR"
  {
    printf -- '---\nphase: plan\ndate: 2026-01-01\nslug: prior_art\nstatus: approved\n---\n\n'
    printf '# Plan: prior art\n\n## Approach\nDo the thing.\n\n'
    if [ -n "${1:-}" ]; then printf '%s\n' "$1"; fi
  } > "$FIXTURE/$PLAN"
}

echo "prior-art advisory"

# --- 1/2: a KB: line present (citation or explicit no-hits) is silent ------------------------------
new_fixture; write_spec
write_plan '## Related prior work
- KB: [[concepts/build-pipeline]] (`knowledge/concepts/build-pipeline.md`) — same pipeline touched.'
out="$(task_state check-plan "$PLAN")"; rc="$?"
is "citation: exit 0" "$rc" "0"
saysn "citation: no advisory" "$out" "advisory"

new_fixture; write_spec
write_plan '## Related prior work
- KB: no relevant pages
- none found'
out="$(task_state check-plan "$PLAN")"; rc="$?"
is "no relevant pages: exit 0" "$rc" "0"
saysn "no relevant pages: no advisory" "$out" "advisory"

# --- 3: section missing entirely ------------------------------------------------------------------
new_fixture; write_spec
write_plan ''
out="$(task_state check-plan "$PLAN")"; rc="$?"
is "missing section: exit 0" "$rc" "0"
says "missing section: advisory mentions the section" "$out" "Related prior work"
says "missing section: advisory marked" "$out" "advisory"

# --- 4: section present, no KB: line ---------------------------------------------------------------
new_fixture; write_spec
write_plan '## Related prior work
- [some_task](task_2025_12_01_some_task/1_spec.md) — related.'
out="$(task_state check-plan "$PLAN")"; rc="$?"
is "no KB line: exit 0" "$rc" "0"
says "no KB line: advisory mentions KB" "$out" "KB:"

# --- 5: check-chain also advises, still exit 0 -----------------------------------------------------
new_fixture; write_spec
write_plan '## Approach
- KB: [[x]] but placed where it is not the related-prior-work section'
# Give it a section without a KB line so the advisory fires through check-chain too.
write_plan '## Related prior work
- none found'
out="$(task_state check-chain "$PLAN")"; rc="$?"
is "check-chain: exit 0" "$rc" "0"
says "check-chain: advisory printed" "$out" "advisory"
says "check-chain: still reports valid chain" "$out" "chain valid"

# --- 6: the advisory must not weaken the phase gate ------------------------------------------------
new_fixture; write_spec
mkdir -p "$FIXTURE/$DIR"
printf -- '---\nphase: spec\ndate: 2026-01-01\nslug: prior_art\n---\n' > "$FIXTURE/$PLAN"
rc="$(code check-plan "$PLAN")"
if [ "$rc" != "0" ]; then ok "wrong phase: still hard-fails"; else bad "wrong phase: still hard-fails" "expected non-zero, got 0"; fi

# --- 7: text guards — the contract is documented where a writer/reviewer reads it ------------------
grep -qF -- '- KB:' "$REPO/core/skills/agent-workflow/templates/2_plan.md" \
  && ok "template documents the '- KB:' line" \
  || bad "template documents the '- KB:' line" "no '- KB:' in templates/2_plan.md"
grep -qi 'Prior-art compliance' "$REPO/core/skills/pr-review/SKILL.md" \
  && ok "pr-review documents the prior-art Nit" \
  || bad "pr-review documents the prior-art Nit" "no 'Prior-art compliance' in pr-review/SKILL.md"
grep -qF -- '- KB:' "$REPO/core/skills/knowledge-base/SKILL.md" \
  && ok "knowledge-base skill documents the '- KB:' record" \
  || bad "knowledge-base skill documents the '- KB:' record" "no '- KB:' in knowledge-base/SKILL.md"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
