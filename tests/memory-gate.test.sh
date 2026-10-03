#!/usr/bin/env bash
# Tests for the memory-gate's build-stage scoping and its one-block-per-stop behaviour.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Every case runs against a throwaway git fixture laid out like an installed project — the bundle at
# `.agents/monorepo-agents-harness/` — because the gate resolves its own path from the repo root and
# its scan is dated. Run it from anywhere:  bash tests/memory-gate.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TODAY="$(date +%Y_%m_%d)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-mg-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
silent() { if [ -z "$2" ]; then ok "$1"; else bad "$1" "expected no output, got: $2"; fi; }

# One fixture per case: an empty git repo, one workspace, and the harness installed the way a
# consumer gets it. No path overrides — the scripts must find their own bundle.
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  mkdir -p "$FIXTURE/.agents/monorepo-agents-harness" "$FIXTURE/apps/api/src" "$FIXTURE/apps/web/src"
  cp -R "$REPO/core" "$FIXTURE/.agents/monorepo-agents-harness/core"
}

S="bash .agents/monorepo-agents-harness/core/scripts"
gate()      { ( cd "$FIXTURE" && $S/memory-gate.sh "$@" 2>&1 ); }
gate_code() { ( cd "$FIXTURE" && $S/memory-gate.sh "$@" >/dev/null 2>&1 ); echo $?; }
stop_hook() { # stop_hook <json on stdin> -> stdout, and the exit code on the second line
  ( cd "$FIXTURE" && printf '%s' "$1" | $S/memory-gate.sh --json 2>&1; echo "exit=$?" )
}
task_state() { ( cd "$FIXTURE" && $S/task-state.sh "$@" 2>&1 ); }
arm_build()  { ( cd "$FIXTURE" && $S/task-state.sh mark-build "$1" >/dev/null 2>&1 ); }
hook_arm()   { ( cd "$FIXTURE" && printf '%s' "$1" | $S/hook-arm-build.sh >/dev/null 2>&1 ); }

# A jq that always fails, to exercise the sed fallback of hook-arm-build.sh. It lives outside the
# fixture (every case starts from a clean one) and goes in PATH only for the cases that need it — the
# gate's own --json output needs a working jq. Prepended as an assignment, never exported.
NOJQ="$(mktemp -d "${TMPDIR:-/tmp}/harness-mg-nojq.XXXXXX")"
printf '#!/bin/sh\nexit 127\n' > "$NOJQ/jq"; chmod +x "$NOJQ/jq"

task_dir() { printf '%s/apps/api/.agents/artifacts/task_%s_%s' "$FIXTURE" "$TODAY" "$1"; }
# A task dir for an arbitrary date, in either workspace — the hook's scope and the gate's scope are
# both "created today", so a case that needs a different day has to name it.
task_dir_on() { # task_dir_on <YYYY_MM_DD> <slug> [workspace]
  printf '%s/apps/%s/.agents/artifacts/task_%s_%s' "$FIXTURE" "${3:-api}" "$1" "$2"
}

write_spec() { # write_spec <dir> [verification plan section]
  mkdir -p "$1"
  {
    printf -- '---\nphase: spec\n---\n\n# Spec\n'
    printf -- '\n## Test / verification plan\n%s\n' "${2:-bash -n core/scripts/memory-gate.sh}"
  } > "$1/1_spec.md"
}
write_plan()  { printf -- '---\nphase: plan\nstatus: approved\nslug: demo\n---\n\n# Plan\n' > "$1/2_plan.md"; }
write_memory() { printf -- '---\nphase: memory\ncommits:\n  - abc1234\n---\n\n# Memory\n' > "$1/3_memory.md"; }
write_verify() { printf -- '---\nphase: verify\n---\n\n# Verify\n' > "$1/4_verify.md"; }

# A knowledge base that already covers the task, so check-kb is never what fails a case.
seed_kb() {
  local dir="$1" slug
  slug="$(basename "$dir")"
  mkdir -p "$FIXTURE/knowledge/sources" "$FIXTURE/knowledge/decision-records" "$FIXTURE/knowledge/verified-facts"
  printf -- '# Index\n' > "$FIXTURE/knowledge/index.md"
  printf -- '# Schema\n' > "$FIXTURE/knowledge/schema.md"
  printf -- '# Sources\n- sources/%s.md\n' "$slug" >> "$FIXTURE/knowledge/index.md"
  printf -- '# The task\n' > "$FIXTURE/knowledge/sources/$slug.md"
  if [ -f "$dir/4_verify.md" ]; then
    printf -- '- verified-facts/%s.md\n' "$slug" >> "$FIXTURE/knowledge/index.md"
    printf -- '# Verified\n' > "$FIXTURE/knowledge/verified-facts/$slug.md"
  fi
}

echo "memory-gate — build-stage scoping"

# --- the reported bug: a spec-only task must be allowed to end ------------------------------------
new_fixture; d="$(task_dir spec_only)"; write_spec "$d"
is "spec-only task: --json exits 0" "$(gate_code --json </dev/null)" "0"
silent "spec-only task: --json prints nothing" "$(gate --json </dev/null)"
is "spec-only task: default mode exits 0" "$(gate_code </dev/null)" "0"

# --- plan stage ------------------------------------------------------------------------------------
new_fixture; d="$(task_dir plan_only)"; write_spec "$d"; write_plan "$d"
is "plan-only task: --json exits 0" "$(gate_code --json </dev/null)" "0"
is "plan-only task: default mode exits 0" "$(gate_code </dev/null)" "0"

# --- at most one block per stop ---------------------------------------------------------------------
new_fixture; d="$(task_dir building)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
out="$(stop_hook '{"stop_hook_active":true}')"
says "stop_hook_active:true exits 0" "$out" "exit=0"
case "$out" in *block*) bad "stop_hook_active:true is silent" "$out" ;; *) ok "stop_hook_active:true is silent" ;; esac
says "stop_hook_active:false still blocks" "$(stop_hook '{"stop_hook_active":false}')" '"decision": "block"'
says "a malformed hook input still blocks" "$(stop_hook '{')" '"decision": "block"'
says "an empty hook input still blocks" "$(stop_hook '')" '"decision": "block"'

# A jq that is present but broken must not turn a block into a hook error.
out="$( cd "$FIXTURE" && printf '{"stop_hook_active":false}' | PATH="$NOJQ:$PATH" $S/memory-gate.sh --json >/dev/null 2>&1; echo $? )"
is "a broken jq in --json mode exits 0" "$out" "0"

# --- a build-stage task is still gated ---------------------------------------------------------------
new_fixture; d="$(task_dir needs_memory)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
is "build stage without memory: default mode exits 1" "$(gate_code </dev/null)" "1"
says "default mode names 3_memory.md" "$(gate </dev/null)" "3_memory.md"
says "--json names memory and verify" "$(gate --json </dev/null)" "4_verify.md"

new_fixture; d="$(task_dir needs_verify)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
write_memory "$d"
is "build stage with memory but no verify: exits 1" "$(gate_code </dev/null)" "1"
says "the missing verify is named" "$(gate </dev/null)" "4_verify.md"
write_verify "$d"; seed_kb "$d"
is "complete build stage: default mode exits 0" "$(gate_code </dev/null)" "0"
silent "complete build stage: --json prints nothing" "$(gate --json </dev/null)"

new_fixture; d="$(task_dir na_verify)"; write_spec "$d" "N/A"; write_plan "$d"; arm_build "$d/2_plan.md"
write_memory "$d"; seed_kb "$d"
is "an N/A verification plan: memory alone passes" "$(gate_code </dev/null)" "0"

# --- knowledge-base coverage is unchanged for a build-stage task ---------------------------------------
new_fixture; d="$(task_dir kb_gap)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
write_memory "$d"; write_verify "$d"
says "kb coverage is still gated at build stage" "$(gate </dev/null)" "knowledge-base coverage"
seed_kb "$d"
is "kb seeded: default mode exits 0" "$(gate_code </dev/null)" "0"

# --- which task dir the gate enforces -------------------------------------------------------------------
new_fixture
old="$(task_dir in_flight_build)"; new="$(task_dir fresh_spec)"
write_spec "$old"; write_plan "$old"; arm_build "$old/2_plan.md"
write_spec "$new"; sleep 1; touch "$new"   # the spec-only dir is now the newest of the day
is "a newer spec-only dir does not mask an in-flight build" "$(gate_code </dev/null)" "1"
says "the build is the one reported" "$(gate </dev/null)" "in_flight_build"

new_fixture
is "no task dir today: exits 0" "$(gate_code </dev/null)" "0"

# --- task-state.sh stage -----------------------------------------------------------------------------
new_fixture; empty="$(task_dir stage_none)"; mkdir -p "$empty"
is "stage: a dir with no spec" "$(task_state stage "$empty")" "none"
is "stage: a path that is not a dir" "$(task_state stage "$FIXTURE/apps/api/nope")" "none"
d="$(task_dir stage_spec)"; write_spec "$d"
is "stage: spec only" "$(task_state stage "$d")" "spec"
write_plan "$d"
is "stage: a plan with no build_started" "$(task_state stage "$d")" "plan"
arm_build "$d/2_plan.md"
is "stage: a plan with build_started" "$(task_state stage "$d")" "build"
# A build whose spec later disappeared is still a build — the gate must be able to say so.
rm "$d/1_spec.md"
is "stage: a marked plan whose spec is gone" "$(task_state stage "$d")" "build"

# --- task-state.sh mark-build -------------------------------------------------------------------------
new_fixture; d="$(task_dir mark_once)"; write_spec "$d"; write_plan "$d"
stamp_of() { sed -n 's/.*build_started: \([0-9T:+-]*\)).*/\1/p'; }
first="$(task_state mark-build "$d/2_plan.md" | stamp_of)"
second="$(task_state mark-build "$d/2_plan.md" | stamp_of)"
is "mark-build is write-once" "$second" "$first"
case "$first" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) ok "mark-build stamps an ISO-8601 time ($first)" ;;
  *) bad "mark-build stamps an ISO-8601 time" "$first" ;;
esac
d="$(task_dir mark_spec)"; write_spec "$d"
out="$(task_state mark-build "$d/1_spec.md")"; code=$?
is "mark-build refuses a file that is not a plan" "$code" "1"
says "the refusal names the reason" "$out" "not a plan"

# --- hook-arm-build.sh ----------------------------------------------------------------------------------
new_fixture; d="$(task_dir arm_hook)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "a write outside .agents arms the gate" "$(task_state stage "$d")" "build"

new_fixture; d="$(task_dir arm_artifact)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/.agents/artifacts/task_x/2_plan.md\"}}"
is "a write inside .agents never arms the gate" "$(task_state stage "$d")" "plan"

new_fixture
is "no task dir to arm: nothing happens" "$( ( cd "$FIXTURE" && $S/hook-arm-build.sh </dev/null >/dev/null 2>&1 ); echo $?)" "0"

new_fixture; d="$(task_dir arm_nojq)"; write_spec "$d"; write_plan "$d"
( cd "$FIXTURE" && printf '{"tool_input":{"file_path":"%s"}}' "$FIXTURE/apps/api/src/a.ts" \
  | PATH="$NOJQ:$PATH" $S/hook-arm-build.sh >/dev/null 2>&1 )
is "without jq, one unambiguous path still arms the gate" "$(task_state stage "$d")" "build"

new_fixture; d="$(task_dir arm_ambiguous)"; write_spec "$d"; write_plan "$d"
( cd "$FIXTURE" && printf '{"tool_input":{"file_path":"%s"},"note":{"file_path":"%s"}}' \
    "$FIXTURE/apps/api/src/a.ts" "$FIXTURE/apps/api/src/b.ts" \
  | PATH="$NOJQ:$PATH" $S/hook-arm-build.sh >/dev/null 2>&1 )
is "without jq, an ambiguous payload arms nothing" "$(task_state stage "$d")" "plan"

# --- the hook arms only what the gate enforces (issues #19, #20) ----------------------------------------
# An older task dir whose file modification time is NEWER must still lose: the date in the dir name is
# the task's age, mtime is only what the filesystem last touched.
new_fixture
yesterday="$(task_dir_on 2026_01_01 opened_yesterday web)"
write_spec "$yesterday"; write_plan "$yesterday"; sleep 1; touch "$yesterday"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "an older plan with a newer mtime is not armed" "$(task_state stage "$yesterday")" "plan"

# A finished task: it has its memory, so there is nothing left to arm, and marking it would dirty a
# committed, finished task dir on somebody else's write.
new_fixture; d="$(task_dir arm_finished)"; write_spec "$d"; write_plan "$d"; write_memory "$d"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "a task that already has 3_memory.md is not armed" "$(task_state stage "$d")" "plan"

# Workspace scoping: a docs edit says nothing about whether the api task is being built.
new_fixture
api="$(task_dir arm_ws_api)"; web="$(task_dir_on "$TODAY" arm_ws_web web)"
write_spec "$api"; write_plan "$api"; write_spec "$web"; write_plan "$web"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/web/src/page.tsx\"}}"
is "a write in another workspace does not arm this plan" "$(task_state stage "$api")" "plan"
is "a write in a workspace arms that workspace's plan" "$(task_state stage "$web")" "build"

# Same date, two plans: mtime breaks the tie, so the most recently touched plan is armed first.
new_fixture
older="$(task_dir_on "$TODAY" tie_older)"; newer="$(task_dir_on "$TODAY" tie_newer web)"
write_spec "$older"; write_plan "$older"; write_spec "$newer"; write_plan "$newer"; sleep 1; touch "$older"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "with two plans of the day the newest mtime wins" "$(task_state stage "$older")" "build"
is "and the older one is left alone" "$(task_state stage "$newer")" "plan"

# The order both scripts share, read directly: newest by the DATE IN THE NAME, mtime only as tie-break.
new_fixture
d1="$(task_dir_on 2026_01_01 order_old)"; d2="$(task_dir_on 2026_02_02 order_mid)"; d3="$(task_dir_on "$TODAY" order_new)"
mkdir -p "$d1" "$d2" "$d3"; touch "$d1"; sleep 1; touch "$d3"; sleep 1; touch "$d2"
rel() { printf '%s' "${1#"$FIXTURE"/}"; }
is "shared task-dir order is by dir-name date, not mtime" \
  "$( ( cd "$FIXTURE" && . .agents/monorepo-agents-harness/core/scripts/harness-common.sh \
       && harness_task_dirs_newest_first "apps/*/.agents/artifacts/task_*" ) | tr '\n' ' ' | sed 's/ *$//' )" \
  "$(rel "$d3") $(rel "$d2") $(rel "$d1")"

# --- the gate fails safe when it cannot read the stage -------------------------------------------------
new_fixture; d="$(task_dir no_reader)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
out="$( cd "$FIXTURE" && TASK_STATE=/nonexistent/task-state.sh $S/memory-gate.sh >/dev/null 2>&1; echo $? )"
is "with no stage reader the gate still enforces" "$out" "1"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
