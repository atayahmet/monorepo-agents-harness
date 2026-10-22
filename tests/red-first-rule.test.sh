#!/usr/bin/env bash
# Tests for the tiered red-first rule (issue #46): the advisory
# `task-state.sh check-red-evidence <task_dir>` subcommand and the workflow text that carries it.
#
# The suite is deliberately behavior-first. It drives the real script through a throwaway installed
# bundle and asserts exit codes, positive output, and — just as important — silence where the rule
# must not fire. Parser cases cover section scoping, CRLF, legacy 2_spec.md, unknown tiers and the
# fallback form, because a warning that fires from the wrong section is worse than no warning.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Run it from anywhere:  bash tests/red-first-rule.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-red-first.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }
silent() { if [ -z "$2" ]; then ok "$1"; else bad "$1" "expected no output, got: $2"; fi; }

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  mkdir -p "$FIXTURE/.agents/monorepo-agents-harness" "$FIXTURE/apps/api/.agents/artifacts"
  cp -R "$REPO/core" "$FIXTURE/.agents/monorepo-agents-harness/core"
}

S="bash .agents/monorepo-agents-harness/core/scripts"
red()      { ( cd "$FIXTURE" && $S/task-state.sh check-red-evidence "$@" 2>&1 ); }
red_code() { ( cd "$FIXTURE" && $S/task-state.sh check-red-evidence "$@" >/dev/null 2>&1 ); echo $?; }
chain()    { ( cd "$FIXTURE" && $S/task-state.sh check-chain "$@" 2>&1 ); }
chain_code() { ( cd "$FIXTURE" && $S/task-state.sh check-chain "$@" >/dev/null 2>&1 ); echo $?; }

DIR_FOR() { printf 'apps/api/.agents/artifacts/task_2026_01_01_%s' "$1"; }

# write_spec <dir> [test-section-content] [legacy]
# The default is a red-first task. An empty second argument writes an empty test section; `legacy`
# writes the old 2_spec.md name instead of 1_spec.md.
write_spec() {
  local dir="$1" section="${2-Tier: red-first}" file="1_spec.md"
  [ "${3:-}" = "legacy" ] && file="2_spec.md"
  mkdir -p "$FIXTURE/$dir"
  {
    printf -- '---\nphase: spec\ndate: 2026-01-01\nslug: demo\n---\n\n# Spec\n\n'
    printf -- '## Acceptance criteria\n- [ ] demo criterion\n\n'
    printf -- '## Test / verification plan\n%s\n' "$section"
  } > "$FIXTURE/$dir/$file"
}

# write_verify <dir> [red-evidence-body] [ABSENT]
# `ABSENT` omits the `## Red evidence` section entirely; an empty body writes an empty section.
write_verify() {
  local dir="$1" body="${2:-}" mode="${3:-}"
  mkdir -p "$FIXTURE/$dir"
  {
    printf -- '---\nphase: verify\ndate: 2026-01-01\nslug: demo\n---\n\n# Verify\n\n'
    printf -- '## Verification run\nbash tests/demo.test.sh\n\n'
    [ "$mode" = "ABSENT" ] || printf -- '## Red evidence\n%s\n\n' "$body"
    printf -- '## Deviations\nNone.\n'
  } > "$FIXTURE/$dir/4_verify.md"
}

write_plan() { # <dir>
  mkdir -p "$FIXTURE/$1"
  {
    printf -- '---\nphase: plan\ndate: 2026-01-01\nslug: demo\nstatus: approved\n---\n\n# Plan\n\n'
    printf -- '## Related prior work\n- KB: no relevant pages\n\n## Steps\n1. demo\n'
  } > "$FIXTURE/$1/2_plan.md"
}

echo "red-first rule — check-red-evidence behavior"

# --- 1. legacy tasks stay silent ---------------------------------------------------------------
new_fixture; d="$(DIR_FOR legacy_no_verify)"; write_spec "$d" "Manual check only."
out="$(red "$d")"; rc="$?"
is "legacy spec, no verify: exit 0" "$rc" "0"
silent "legacy spec, no verify: silent" "$out"

new_fixture; d="$(DIR_FOR legacy_with_verify)"; write_spec "$d" "Manual check only."; write_verify "$d" "not needed"
out="$(red "$d")"; rc="$?"
is "legacy spec, verify without red evidence: exit 0" "$rc" "0"
silent "legacy spec, verify without red evidence: silent" "$out"

new_fixture; d="$(DIR_FOR empty_tier)"; write_spec "$d" "Tier:"; write_verify "$d" ""
out="$(red "$d")"; rc="$?"
is "empty tier value: exit 0" "$rc" "0"
silent "empty tier value: treated as legacy, silent" "$out"

# --- 2. evidence-only never asks for red --------------------------------------------------------
new_fixture; d="$(DIR_FOR evidence_only_missing)"; write_spec "$d" "Tier: evidence-only";
out="$(red "$d")"; rc="$?"
is "evidence-only, no verify: exit 0" "$rc" "0"
silent "evidence-only, no verify: silent" "$out"

new_fixture; d="$(DIR_FOR evidence_only_empty)"; write_spec "$d" "Tier: evidence-only"; write_verify "$d" ""
out="$(red "$d")"; rc="$?"
is "evidence-only, empty red section: exit 0" "$rc" "0"
silent "evidence-only, empty red section: silent" "$out"

# --- 3. red-first asks for evidence only when it is missing -------------------------------------
new_fixture; d="$(DIR_FOR red_filled)"; write_spec "$d"; write_verify "$d" \
  'bash tests/demo.test.sh -> FAIL (expected 200, got 500)'
out="$(red "$d")"; rc="$?"
is "red-first with evidence: exit 0" "$rc" "0"
says "red-first with evidence: confirms the evidence" "$out" "evidence"
saysn "red-first with evidence: no advisory" "$out" "advisory"

new_fixture; d="$(DIR_FOR red_missing_verify)"; write_spec "$d"
out="$(red "$d")"; rc="$?"
is "red-first without verify: exit 0" "$rc" "0"
says "red-first without verify: advisory" "$out" "advisory"
says "red-first without verify: names 4_verify.md" "$out" "4_verify.md"
says "red-first without verify: names Red evidence" "$out" "Red evidence"

new_fixture; d="$(DIR_FOR red_missing_section)"; write_spec "$d"; write_verify "$d" "" ABSENT
out="$(red "$d")"; rc="$?"
is "red-first without Red evidence section: exit 0" "$rc" "0"
says "red-first without section: advisory" "$out" "advisory"
says "red-first without section: names the section" "$out" "## Red evidence"

new_fixture; d="$(DIR_FOR red_whitespace)"; write_spec "$d"; write_verify "$d" $'   \n\t'
out="$(red "$d")"; rc="$?"
is "red-first with whitespace-only evidence: exit 0" "$rc" "0"
says "whitespace-only evidence: advisory" "$out" "advisory"

new_fixture; d="$(DIR_FOR red_na)"; write_spec "$d"; write_verify "$d" "N/A"
out="$(red "$d")"; rc="$?"
is "red-first with N/A evidence: exit 0" "$rc" "0"
says "N/A evidence: advisory" "$out" "advisory"

new_fixture; d="$(DIR_FOR red_na_rationale)"; write_spec "$d"; write_verify "$d" "N/A — could not reproduce before the fix"
out="$(red "$d")"; rc="$?"
is "red-first with N/A plus rationale: exit 0" "$rc" "0"
says "N/A plus rationale: advisory" "$out" "advisory"

# --- 4. unknown tier is surfaced but is not red-first -------------------------------------------
new_fixture; d="$(DIR_FOR unknown_tier)"; write_spec "$d" "Tier: tdd";
out="$(red "$d")"; rc="$?"
is "unknown tier: exit 0" "$rc" "0"
says "unknown tier: advisory" "$out" "advisory"
says "unknown tier: names the problem" "$out" "unknown tier"

# --- 5. a missing path is fail-open too ---------------------------------------------------------
new_fixture
out="$(red "apps/api/.agents/artifacts/task_2026_01_01_nope")"; rc="$?"
is "missing task dir: exit 0" "$rc" "0"
silent "missing task dir: silent" "$out"

touch "$FIXTURE/not-a-dir"
out="$(red "not-a-dir")"; rc="$?"
is "path is a file: exit 0" "$rc" "0"
silent "path is a file: silent" "$out"

# --- 6. parser scoping: the tier must come from the test section --------------------------------
new_fixture; d="$(DIR_FOR tier_wrong_section)"; mkdir -p "$FIXTURE/$d"
cat > "$FIXTURE/$d/1_spec.md" <<'EOF'
---
phase: spec
date: 2026-01-01
slug: demo
---

# Spec

## Acceptance criteria
Tier: red-first

## Test / verification plan
Manual check only.
EOF
out="$(red "$d")"; rc="$?"
is "tier in another section: exit 0" "$rc" "0"
silent "tier in another section: must not fire" "$out"

new_fixture; d="$(DIR_FOR tier_after_section)"; mkdir -p "$FIXTURE/$d"
cat > "$FIXTURE/$d/1_spec.md" <<'EOF'
---
phase: spec
date: 2026-01-01
slug: demo
---

# Spec

## Test / verification plan
Manual check only.

## Architectural constraints
Tier: red-first
EOF
out="$(red "$d")"; rc="$?"
is "tier after the test section: exit 0" "$rc" "0"
silent "tier after the test section: must not fire" "$out"

new_fixture; d="$(DIR_FOR tier_lowercase)"; write_spec "$d" "  tier: RED-FIRST"
out="$(red "$d")"; rc="$?"
is "lowercase/indented tier: exit 0" "$rc" "0"
says "lowercase/indented tier: detected" "$out" "advisory"

new_fixture; d="$(DIR_FOR tier_rationale)"; write_spec "$d" "Tier: red-first — this is a bug fix"
out="$(red "$d")"; rc="$?"
is "tier with rationale: exit 0" "$rc" "0"
says "tier with rationale: detected" "$out" "advisory"

new_fixture; d="$(DIR_FOR heading_spaces)"; write_spec "$d"
perl -0pi -e 's/## Test \/ verification plan/## Test \/ verification plan   /' "$FIXTURE/$d/1_spec.md"
out="$(red "$d")"; rc="$?"
is "trailing spaces on the heading: exit 0" "$rc" "0"
says "trailing spaces on the heading: still detected" "$out" "advisory"

new_fixture; d="$(DIR_FOR crlf)"; mkdir -p "$FIXTURE/$d"
printf -- '---\r\nphase: spec\r\ndate: 2026-01-01\r\nslug: demo\r\n---\r\n\r\n# Spec\r\n\r\n## Test / verification plan\r\n\r\nTier: red-first\r\n' \
  > "$FIXTURE/$d/1_spec.md"
out="$(red "$d")"; rc="$?"
is "CRLF spec: exit 0" "$rc" "0"
says "CRLF spec: tier detected" "$out" "advisory"

new_fixture; d="$(DIR_FOR legacy_spec_name)"; write_spec "$d" "Tier: red-first" legacy
out="$(red "$d")"; rc="$?"
is "legacy 2_spec.md: exit 0" "$rc" "0"
says "legacy 2_spec.md: tier detected" "$out" "advisory"

# --- 7. parser scoping: evidence must come from its own section ---------------------------------
new_fixture; d="$(DIR_FOR evidence_wrong_section)"; write_spec "$d"
mkdir -p "$FIXTURE/$d"
cat > "$FIXTURE/$d/4_verify.md" <<'EOF'
---
phase: verify
date: 2026-01-01
slug: demo
---

# Verify

## Verification run
bash tests/demo.test.sh

## Red evidence

## Deviations
Before the fix the test failed with: expected 200, got 500.
EOF
out="$(red "$d")"; rc="$?"
is "red text in Deviations only: exit 0" "$rc" "0"
says "red text in Deviations only: still advisory" "$out" "advisory"

new_fixture; d="$(DIR_FOR evidence_multiple)"; write_spec "$d"
mkdir -p "$FIXTURE/$d"
cat > "$FIXTURE/$d/4_verify.md" <<'EOF'
---
phase: verify
date: 2026-01-01
slug: demo
---

# Verify

## Red evidence

## Red evidence
bash tests/demo.test.sh -> FAIL (expected 200, got 500)
EOF
out="$(red "$d")"; rc="$?"
is "second Red evidence section filled: exit 0" "$rc" "0"
saysn "second Red evidence section filled: no advisory" "$out" "advisory"

# --- 8. no side effects and no coupling to the chain gate ---------------------------------------
new_fixture; d="$(DIR_FOR no_writes)"; write_spec "$d"; write_verify "$d" \
  'bash tests/demo.test.sh -> FAIL (expected 200, got 500)'
snapshot() { ( cd "$FIXTURE" && find . -type f ! -path './.git/*' -print0 | sort -z | xargs -0 shasum ); }
before="$(snapshot)"
out="$(red "$d")"; rc="$?"
after="$(snapshot)"
is "read-only check: exit 0" "$rc" "0"
is "read-only check: no file changed" "$after" "$before"

new_fixture; d="$(DIR_FOR chain_unaffected)"; write_spec "$d"; write_plan "$d"
out="$(chain "$d/2_plan.md")"; rc="$?"
is "check-chain stays green with red-first and no verify" "$rc" "0"
says "check-chain still reports a valid chain" "$out" "chain valid"
saysn "check-chain does not grow a red-first advisory" "$out" "Red evidence"

new_fixture; d="$(DIR_FOR option_contract)"; write_spec "$d"
out="$(red "$d" --write 2>&1)"; rc="$(red_code "$d" --write)"
is "unsupported option is refused (exit 2)" "$rc" "2"
says "the refusal is an option error" "$out" "not a supported option"

# --- 9. the text the writers and builders read --------------------------------------------------
tpl="$REPO/core/skills/agent-workflow/templates"
grep -qF 'Tier: red-first' "$tpl/1_spec.md" \
  && ok "1_spec template carries the red-first tier" \
  || bad "1_spec template carries the red-first tier" "no 'Tier: red-first'"
grep -qF 'Tier: evidence-only' "$tpl/1_spec.md" \
  && ok "1_spec template carries the evidence-only tier" \
  || bad "1_spec template carries the evidence-only tier" "no 'Tier: evidence-only'"
grep -qiE 'failing test.*implementation|implementation.*failing test' "$tpl/2_plan.md" \
  && ok "2_plan template orders test before implementation" \
  || bad "2_plan template orders test before implementation" "no ordered pair wording"
grep -qF '## Red evidence' "$tpl/4_verify.md" \
  && ok "4_verify template carries '## Red evidence'" \
  || bad "4_verify template carries '## Red evidence'" "no section"

skill="$REPO/core/skills/agent-workflow/SKILL.md"
for needle in 'red-first' 'evidence-only' 'check-red-evidence' 'Red evidence' 'fallback'; do
  grep -qF "$needle" "$skill" \
    && ok "SKILL documents '$needle'" \
    || bad "SKILL documents '$needle'" "missing '$needle'"
done

grep -qF 'red-first' "$REPO/core/root-AGENTS.md" \
  && ok "root AGENTS carries the red-first rule" \
  || bad "root AGENTS carries the red-first rule" "missing 'red-first'"
grep -qF 'Red evidence' "$REPO/core/root-AGENTS.md" \
  && ok "root AGENTS names Red evidence" \
  || bad "root AGENTS names Red evidence" "missing 'Red evidence'"

grep -qF 'red-first' "$REPO/README.md" \
  && ok "README documents red-first" \
  || bad "README documents red-first" "missing 'red-first'"
grep -qF 'red-first' "$REPO/PORTABILITY.md" \
  && ok "PORTABILITY documents red-first" \
  || bad "PORTABILITY documents red-first" "missing 'red-first'"

stub_claude="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-build.md"
stub_opencode="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-build.md"
stub_codex="$REPO/adapters/codex/.agents/skills/monorepo-harness-build/SKILL.md"
for stub in "$stub_claude" "$stub_opencode" "$stub_codex"; do
  rel="${stub#"$REPO"}"
  grep -qF 'red-first' "$stub" \
    && ok "build stub names red-first: $rel" \
    || bad "build stub names red-first: $rel" "missing 'red-first'"
  grep -qF 'Red evidence' "$stub" \
    && ok "build stub names Red evidence: $rel" \
    || bad "build stub names Red evidence: $rel" "missing 'Red evidence'"
  grep -qi 'fallback' "$stub" \
    && ok "build stub describes the fallback: $rel" \
    || bad "build stub describes the fallback: $rel" "missing 'fallback'"
  grep -qF 'check-red-evidence' "$stub" \
    && ok "build stub runs the advisory check: $rel" \
    || bad "build stub runs the advisory check: $rel" "missing 'check-red-evidence'"
  red_line="$(grep -n -m1 'red-first' "$stub" | cut -d: -f1)"
  impl_line="$(grep -n -m1 '^[0-9][0-9]*\. Run the implementation' "$stub" | cut -d: -f1)"
  if [ -n "$red_line" ] && [ -n "$impl_line" ] && [ "$red_line" -lt "$impl_line" ]; then
    ok "red-first step precedes implementation: $rel"
  else
    bad "red-first step precedes implementation: $rel" "red line '$red_line', implementation line '$impl_line'"
  fi
done

body() { awk 'NR==1 && /^---[[:space:]]*$/ { fm=1; next } fm && /^---[[:space:]]*$/ { fm=0; next } !fm' "$1"; }
body_claude="$(body "$stub_claude")"
body_opencode="$(body "$stub_opencode")"
body_codex="$(body "$stub_codex")"
is "adapter build bodies are identical (claude = opencode)" "$body_claude" "$body_opencode"
is "adapter build bodies are identical (claude = codex)" "$body_claude" "$body_codex"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
