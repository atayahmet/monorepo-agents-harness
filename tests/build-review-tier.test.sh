#!/usr/bin/env bash
# Tests for build-review-tier.sh — the deterministic helper that decides how strongly a finished
# build should suggest `/monorepo-harness-review` (issue #41).
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Every case runs against a throwaway git fixture so the memory-commits path has real shas. Run it
# from anywhere:  bash tests/build-review-tier.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-tier-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
}

HELPER="$REPO/core/scripts/build-review-tier.sh"
tier() { bash "$HELPER" "$1" 2>/dev/null | head -n1; }
run()  { bash "$HELPER" "$1" 2>&1; }
code() { bash "$HELPER" "$1" >/dev/null 2>&1; echo $?; }

# A task dir at the repo root (the only workspace in these fixtures).
task_dir() { printf '%s/.agents/artifacts/task_2026_01_01_%s' "$FIXTURE" "$1"; }

# Commit <n> files under src/ and echo the commit sha (the memory-commits signal).
seed_src_commit() {
  local prefix="$1" n="$2" i
  mkdir -p "$FIXTURE/src"
  i=1; while [ "$i" -le "$n" ]; do printf 'x\n' > "$FIXTURE/src/${prefix}_${i}.txt"; i=$((i+1)); done
  ( cd "$FIXTURE" && git add -A -- src >/dev/null 2>&1 && git commit -qm "$prefix" >/dev/null 2>&1 \
    && git rev-parse HEAD )
}

write_spec_plain() { # no architectural signal
  mkdir -p "$1"
  { printf -- '---\nphase: spec\n---\n\n# Spec\n'
    printf -- '\n## Architectural decisions\nN/A\n'; } > "$1/1_spec.md"
}
write_spec_signal() { # `## Data model` is not N/A
  mkdir -p "$1"
  { printf -- '---\nphase: spec\n---\n\n# Spec\n'
    printf -- '\n## Data model\nA new `orders` table with an id.\n'
    printf -- '\n## Architectural decisions\nN/A\n'; } > "$1/1_spec.md"
}
write_plan_n() { # <dir> <affected-file count>
  mkdir -p "$1"
  { printf -- '---\nphase: plan\nstatus: approved\n---\n\n# Plan\n'
    printf -- '\n## Affected files / modules\n'
    i=1; while [ "$i" -le "$2" ]; do printf -- '- src/f%s.ts\n' "$i"; i=$((i+1)); done; } > "$1/2_plan.md"
}
write_memory_inline() { printf -- '---\nphase: memory\ncommits: [%s]\n---\n\n# Memory\n' "$2" > "$1/3_memory.md"; }

echo "build-review-tier — scope/criticality decision"

# --- plan fallback (no memory yet) ------------------------------------------------------------------
new_fixture; d="$(task_dir plan_simple)"; write_spec_plain "$d"; write_plan_n "$d" 2
is "2 plan files, no signal -> simple" "$(tier "$d")" "simple"

new_fixture; d="$(task_dir plan_big)"; write_spec_plain "$d"; write_plan_n "$d" 4
is "4 plan files -> comprehensive" "$(tier "$d")" "comprehensive"

# --- architectural signals --------------------------------------------------------------------------
new_fixture; d="$(task_dir adr)"; write_spec_plain "$d"; write_plan_n "$d" 1; mkdir -p "$d/adr"
printf -- '---\nphase: adr\n---\n\n# ADR\n' > "$d/adr/0001-choice.md"
is "an adr/ file -> comprehensive" "$(tier "$d")" "comprehensive"

new_fixture; d="$(task_dir spec_signal)"; write_spec_signal "$d"; write_plan_n "$d" 1
is "a non-N/A spec section -> comprehensive" "$(tier "$d")" "comprehensive"
says "the reason names the spec section" "$(run "$d")" "spec 'Data model' is not N/A"

# --- memory-commits signal (the real path after a build) ---------------------------------------------
new_fixture; sha="$(seed_src_commit mem_simple 2)"; d="$(task_dir mem_simple)"
write_spec_plain "$d"; write_plan_n "$d" 2; write_memory_inline "$d" "$sha"
is "2 files in the memory commit -> simple" "$(tier "$d")" "simple"
says "the source is the memory commits" "$(run "$d")" "memory commits"

new_fixture; sha="$(seed_src_commit mem_big 4)"; d="$(task_dir mem_big)"
write_spec_plain "$d"; write_plan_n "$d" 4; write_memory_inline "$d" "$sha"
is "4 files in the memory commit -> comprehensive" "$(tier "$d")" "comprehensive"

# The YAML list form of `commits:` is accepted too.
new_fixture; sha="$(seed_src_commit mem_list 2)"; d="$(task_dir mem_list)"
write_spec_plain "$d"; write_plan_n "$d" 2
printf -- '---\nphase: memory\ncommits:\n  - %s\n---\n\n# Memory\n' "$sha" > "$d/3_memory.md"
is "a list-form commits block is parsed" "$(tier "$d")" "simple"

# --- advisory and usage contract ---------------------------------------------------------------------
new_fixture; d="$(task_dir always_zero)"; write_spec_plain "$d"; write_plan_n "$d" 9
is "the helper exits 0 even for comprehensive" "$(code "$d")" "0"

new_fixture; d="$(task_dir empty)"; mkdir -p "$d"
is "an empty task dir still exits 0" "$(code "$d")" "0"
is "an empty task dir with no signals -> simple" "$(tier "$d")" "simple"

out="$(bash "$HELPER" 2>&1)"; c=$?
is "no argument -> exit 2" "$c" "2"
says "no argument prints usage" "$out" "Usage:"

bash "$HELPER" "$FIXTURE/does-not-exist" >/dev/null 2>&1
is "a non-directory argument -> exit 2" "$?" "2"

# --- the first line is exactly the tier (an agent can branch on it) ----------------------------------
new_fixture; d="$(task_dir firstline)"; write_spec_plain "$d"; write_plan_n "$d" 1
is "line 1 is the bare tier token" "$(run "$d" | sed -n 1p)" "simple"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
