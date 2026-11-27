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
# `new_fixture root-only` leaves out apps/ and packages/ — the layout issue #22 is about, where the
# repo root is the only workspace there is.
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  mkdir -p "$FIXTURE/.agents/monorepo-agents-harness"
  [ "${1:-}" = "root-only" ] || mkdir -p "$FIXTURE/apps/api/src" "$FIXTURE/apps/web/src"
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
# A task dir at the REPO ROOT — the workspace AGENTS.md allows when neither apps/ nor packages/
# exists, and the one both scripts used to skip (issue #22).
root_task_dir() { printf '%s/.agents/artifacts/task_%s_%s' "$FIXTURE" "$TODAY" "$1"; }
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

# The ordinary first write of a build: a brand-new file in a directory nobody has created yet.
new_fixture; d="$(task_dir arm_newfile)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/feature/new.ts\"}}"
is "a write into a not-yet-existing directory arms its own workspace plan" "$(task_state stage "$d")" "build"

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

# --- a repo-root task dir is a candidate (issue #22) ----------------------------------------------------
# AGENTS.md workspace routing allows the repo root as the workspace; the scan set has to include it
# or a spec, plan and memory exist that no gate ever reads.
new_fixture; d="$(root_task_dir root_build)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
is "repo-root build without memory: default mode exits 1" "$(gate_code </dev/null)" "1"
says "the repo-root task dir is the one reported" "$(gate </dev/null)" "task_${TODAY}_root_build"
says "--json blocks on a repo-root task" "$(stop_hook '{"stop_hook_active":false}')" '"decision": "block"'

new_fixture; d="$(root_task_dir root_done)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
write_memory "$d"; write_verify "$d"; seed_kb "$d"
is "a complete repo-root build passes" "$(gate_code </dev/null)" "0"

# The layout the issue is really about: no apps/ and no packages/ anywhere.
new_fixture root-only; d="$(root_task_dir bare_root)"; write_spec "$d"; write_plan "$d"; arm_build "$d/2_plan.md"
is "a root task in a repo with no workspaces: exits 1" "$(gate_code </dev/null)" "1"
says "and it names the root task dir" "$(gate </dev/null)" "task_${TODAY}_bare_root"

# --- hook-arm-build.sh arms a repo-root plan (issue #22) ------------------------------------------------
new_fixture; d="$(root_task_dir arm_root)"; write_spec "$d"; write_plan "$d"; mkdir -p "$FIXTURE/src"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/src/index.ts\"}}"
is "a write outside .agents arms a repo-root plan" "$(task_state stage "$d")" "build"

new_fixture; d="$(root_task_dir arm_root_artifact)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/.agents/artifacts/task_x/2_plan.md\"}}"
is "an artifact write never arms a repo-root plan" "$(task_state stage "$d")" "plan"

# The first write of a build is usually a brand-new file: its parent directory does not exist yet,
# so it can only be placed by its repo-root-relative path, not by a resolved physical one.
new_fixture; d="$(root_task_dir arm_root_newfile)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/src/components/Button.tsx\"}}"
is "a write into a not-yet-existing directory arms a repo-root plan" "$(task_state stage "$d")" "build"

# Same write, a workspace plan: it must stay unarmed — the root fix may not loosen that rule.
new_fixture; d="$(task_dir arm_ws_rootwrite)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/README.md\"}}"
is "a repo-root write does not arm a workspace plan" "$(task_state stage "$d")" "plan"

new_fixture root-only; d="$(root_task_dir arm_root_bare)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXTURE/README.md\"}}"
is "a repo with no workspaces arms its own root plan" "$(task_state stage "$d")" "build"




# --- issue #50: hook must not arm old plan when build in flight in same workspace ---
new_fixture
today_build="$(task_dir build_in_flight)"
old_date="$(date -d '3 months ago' +%Y_%m_%d 2>/dev/null || date -v-3m +%Y_%m_%d 2>/dev/null || echo 2026_07_24)"
old_plan="$(task_dir_on "$old_date" abandoned_old)"
write_spec "$today_build"; write_plan "$today_build"; arm_build "$today_build/2_plan.md"
write_spec "$old_plan"; write_plan "$old_plan"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "#50 build in flight blocks arming older plan in same workspace" "$(task_state stage "$old_plan")" "plan"
is "#50 todays build remains in build stage" "$(task_state stage "$today_build")" "build"

# --- issue #50: very old plan-only task is not armed with no build in flight ---
new_fixture
old_date2="$(date -d '3 months ago' +%Y_%m_%d 2>/dev/null || date -v-3m +%Y_%m_%d 2>/dev/null || echo 2026_07_24)"
very_old="$(task_dir_on "$old_date2" very_old_plan)"
write_spec "$very_old"; write_plan "$very_old"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/index.ts\"}}"
is "#50 plan from 3 months ago is not armed" "$(task_state stage "$very_old")" "plan"

# --- issue #50: cross-midnight - yesterday's plan armed today without -build ---
new_fixture
yesterday_date="$(date -d yesterday +%Y_%m_%d 2>/dev/null || date -v-1d +%Y_%m_%d 2>/dev/null || echo 2026_10_23)"
yesterday_plan="$(task_dir_on "$yesterday_date" yesterday_plan)"
write_spec "$yesterday_plan"; write_plan "$yesterday_plan"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/apps/api/src/feature.ts\"}}"
is "#50 yesterdays plan is armed today without -build" "$(task_state stage "$yesterday_plan")" "build"

# --- issue #83: a task is enforced wherever it lives ------------------------------------------------------
ws_task_dir() { printf '%s/%s/.agents/artifacts/task_%s_%s' "$FIXTURE" "$1" "$TODAY" "$2"; }
building() { write_spec "$1"; write_plan "$1"; arm_build "$1/2_plan.md"; }

new_fixture root-only; d="$(ws_task_dir crates/core undeclared)"; building "$d"
is "#83 an undeclared crates/core build blocks" "$(gate_code </dev/null)" "1"
says "#83 and it is the one reported" "$(gate </dev/null)" "crates/core/.agents/artifacts/task_${TODAY}_undeclared"
says "#83 --json blocks on it" "$(stop_hook '{"stop_hook_active":false}')" '"decision": "block"'
( cd "$FIXTURE" && git add crates && git commit -qm t )
is "#83 a tracked one blocks" "$(gate_code </dev/null)" "1"
write_memory "$d"; write_verify "$d"; seed_kb "$d"
is "#83 a complete one passes" "$(gate_code </dev/null)" "0"

new_fixture root-only; d="$(ws_task_dir crates/core planned)"; write_spec "$d"; write_plan "$d"
is "#83 a plan-only one never blocks" "$(gate_code </dev/null)" "0"

for ig in '.agents/' '**/.agents/artifacts/' '/crates/core/.agents/artifacts/task_*' '/crates/core/.agents/artifacts/*/2_plan.md'; do
  new_fixture root-only; d="$(ws_task_dir crates/core ignored)"; building "$d"; printf '%s\n' "$ig" > "$FIXTURE/.gitignore"
  is "#83 ignored by '$ig' in an untracked parent: blocks" "$(gate_code </dev/null)" "1"
  echo x > "$FIXTURE/crates/core/a.rs"; ( cd "$FIXTURE" && git add crates/core/a.rs && git commit -qm t )
  is "#83 ignored by '$ig' in a tracked parent: blocks" "$(gate_code </dev/null)" "1"
done
new_fixture root-only; d="$(ws_task_dir 'my crates/ü core' spaced)"; building "$d"
is "#83 spaces and non-ASCII in the path: blocks" "$(gate_code </dev/null)" "1"

for skip in tests/fixtures/app pkg/__fixtures__/a pkg/testdata/a test-fixtures/a vendor/lib web/node_modules/p .agents/monorepo-agents-harness/x .agents/.harness-trash/x; do
  new_fixture root-only; d="$(ws_task_dir "$skip" skipped)"; building "$d"
  is "#83 a task under $skip never blocks" "$(gate_code </dev/null)" "0"
done
new_fixture root-only; d="$(ws_task_dir vendor/lib declared)"; building "$d"; echo 'vendor/*' > "$FIXTURE/.agents/workspaces.txt"
is "#83 a declared workspace is never skipped" "$(gate_code </dev/null)" "1"
new_fixture root-only; d="$(ws_task_dir nested/repo inner)"; building "$d"; ( cd "$FIXTURE/nested" && git init -q . )
is "#83 a task in a nested repo never blocks" "$(gate_code </dev/null)" "0"
new_fixture root-only; d="$(ws_task_dir third/lib ignoredparent)"; building "$d"; echo '/third/' > "$FIXTURE/.gitignore"
is "#83 a git-ignored parent is not scanned" "$(gate_code </dev/null)" "0"
new_fixture; d="$(task_dir no_lib)"; building "$d"; rm "$FIXTURE/.agents/monorepo-agents-harness/core/scripts/harness-common.sh"
is "#83 without the library apps/* is still enforced" "$(gate_code </dev/null)" "1"
new_fixture; d="$(task_dir no_detector)"; building "$d"; rm "$FIXTURE/.agents/monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh"
is "#83 without the detector apps/* is still enforced" "$(gate_code </dev/null)" "1"

# One tracked path with an invalid UTF-8 byte must not end the listing for the paths after it.
new_fixture root-only; d="$(ws_task_dir crates/core badbyte)"; building "$d"
( cd "$FIXTURE" && git add crates && b="$(echo x | git hash-object -w --stdin)" \
  && printf "100644 $b\taaa/.agents/artifacts/task_\377\376/2_plan.md\0" | git update-index -z --index-info )
for loc in C en_US.UTF-8; do
  is "#83 an invalid byte in another path does not switch the scan off ($loc)" "$(export LC_ALL=$loc; gate_code </dev/null)" "1"
done

# The installer wires pre-commit as a symlink, so the gate runs under .git/hooks/ and must still find
# its library — the scan lives there.
new_fixture root-only; d="$(ws_task_dir crates/core precommit)"; building "$d"
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh "$FIXTURE/.git/hooks/pre-commit"
out="$( cd "$FIXTURE" && git add -A && git commit -qm t 2>&1; echo "exit=$?" )"
says "#83 the symlinked pre-commit hook blocks an undeclared build" "$out" "exit=1"
says "#83 and names it" "$out" "task_${TODAY}_precommit"

# The hook places a write by walking up from it, so no layout has to be detected.
new_fixture root-only; d="$(ws_task_dir crates/core arm_crate)"; write_spec "$d"; write_plan "$d"; mkdir -p "$FIXTURE/crates/other" "$FIXTURE/crates/core-legacy"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/crates/other/a.rs\"}}"
is "#83 a write in another crate does not arm it" "$(task_state stage "$d")" "plan"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/crates/core-legacy/a.rs\"}}"
is "#83 a sibling with the same prefix does not arm it" "$(task_state stage "$d")" "plan"
hook_arm "{\"tool_input\":{\"file_path\":\"/etc/hosts\"}}"
is "#83 a write outside the repo does not arm it" "$(task_state stage "$d")" "plan"
hook_arm "{\"tool_input\":{\"file_path\":\"crates/core/src/new/lib.rs\"}}"
is "#83 a relative write in the crate arms it" "$(task_state stage "$d")" "build"
new_fixture root-only; d="$(ws_task_dir services/a/b arm_deep)"; write_spec "$d"; write_plan "$d"
hook_arm "{\"tool_input\":{\"file_path\":\"$FIXTURE/services/a/b/main.go\"}}"
is "#83 a deeper workspace is armed" "$(task_state stage "$d")" "build"

# --- issue #91: the gates see the other checkouts of the repository --------------------------------------
# A session in one checkout can edit another one (`--add-dir`). The write hook arms the plan where the
# file is written; the gate warns about another checkout's unfinished build and never blocks for it.
WTS="$(mktemp -d "${TMPDIR:-/tmp}/harness-mg-wt.XXXXXX")"; WTS="$(cd "$WTS" && pwd -P)"
trap 'rm -rf "$FIXTURE" "$WTS" "$NOJQ"' EXIT

# commit_fixture — a worktree needs a commit to check out; it carries the bundle with it.
commit_fixture() { ( cd "$FIXTURE" && git add -A && git commit -qm init ) >/dev/null 2>&1; }
new_worktree_fixture() { # a committed fixture plus one linked worktree, outside it, at $WT
  new_fixture; commit_fixture
  rm -rf "$WTS"; mkdir -p "$WTS"
  ( cd "$FIXTURE" && git worktree add -q -b t1 "$WTS/t1" ) >/dev/null 2>&1
  WT="$WTS/t1"; mkdir -p "$WT/apps/api/src"
  [ -d "$WT/.agents/monorepo-agents-harness" ] || { bad "#91 fixture: worktree with the bundle" "$WT"; exit 1; }
}
wt_task_dir() { printf '%s/apps/api/.agents/artifacts/task_%s_%s' "$WT" "$TODAY" "$1"; }
payload() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }
planned() { write_spec "$1"; write_plan "$1"; }
wt_gate_code() { ( cd "$WT" && $S/memory-gate.sh >/dev/null 2>&1 </dev/null ); echo $?; }
lacks() { case "$2" in *"$3"*) bad "$1" "expected no mention of '$3', got: $2" ;; *) ok "$1" ;; esac; }

# AC1 — a write into a worktree arms that worktree's plan.
new_worktree_fixture; d="$(wt_task_dir arm_wt)"; planned "$d"; m="$(task_dir arm_wt_main)"; planned "$m"
hook_arm "$(payload "$WT/apps/api/src/a.ts")"
is "#91 AC1 a write into a worktree arms its plan" "$(task_state stage "$d")" "build"
is "#91 AC1 and leaves this checkout's plan alone" "$(task_state stage "$m")" "plan"
new_worktree_fixture; d="$(wt_task_dir arm_wt_new)"; planned "$d"
hook_arm "$(payload "$WT/apps/api/src/new/dir/b.ts")"
is "#91 AC1 a new file in a new folder arms it too" "$(task_state stage "$d")" "build"
new_worktree_fixture; d="$(wt_task_dir arm_wt_nojq)"; planned "$d"
( cd "$FIXTURE" && payload "$WT/apps/api/src/a.ts" | PATH="$NOJQ:$PATH" $S/hook-arm-build.sh >/dev/null 2>&1 )
is "#91 AC1 without jq a worktree write arms it" "$(task_state stage "$d")" "build"

# AC2 — nothing is armed where nothing should be.
new_worktree_fixture; m="$(task_dir arm_unrelated_main)"; planned "$m"
git init -q "$WTS/other"; o="$WTS/other/apps/api/.agents/artifacts/task_${TODAY}_other"; planned "$o"
hook_arm "$(payload "$WTS/other/apps/api/src/a.ts")"
is "#91 AC2 an unrelated repository is not armed" "$(task_state stage "$o")" "plan"
is "#91 AC2 and this checkout is not armed by it" "$(task_state stage "$m")" "plan"
new_worktree_fixture; d="$(wt_task_dir arm_wt_artifact)"; planned "$d"
hook_arm "$(payload "$d/2_plan.md")"
is "#91 AC2 a worktree artifact write arms nothing" "$(task_state stage "$d")" "plan"
new_worktree_fixture; d="$WT/apps/api/.agents/artifacts/task_2026_01_01_old"; planned "$d"
hook_arm "$(payload "$WT/apps/api/src/a.ts")"
is "#91 AC2 an old worktree plan is not armed" "$(task_state stage "$d")" "plan"

# AC3 — both directions, and a checkout nested in this one.
new_worktree_fixture; m="$(task_dir arm_from_wt)"; planned "$m"
( cd "$WT" && payload "$FIXTURE/apps/api/src/a.ts" | $S/hook-arm-build.sh >/dev/null 2>&1 )
is "#91 AC3 from a worktree, a main-checkout write arms the main plan" "$(task_state stage "$m")" "build"
new_fixture; commit_fixture
( cd "$FIXTURE" && git worktree add -q -b nested "$FIXTURE/.claude/worktrees/n1" ) >/dev/null 2>&1
outer="$(root_task_dir outer_plan)"; planned "$outer"
n="$FIXTURE/.claude/worktrees/n1"; inner="$n/apps/api/.agents/artifacts/task_${TODAY}_inner"; planned "$inner"
hook_arm "$(payload "$n/README.md")"
is "#91 AC3 a nested-checkout write does not arm the outer plan" "$(task_state stage "$outer")" "plan"
hook_arm "$(payload "$n/apps/api/src/a.ts")"
is "#91 AC3 it arms the nested checkout's own plan" "$(task_state stage "$inner")" "build"
new_fixture; m="$(task_dir arm_nested_repo)"; planned "$m"; git init -q "$FIXTURE/apps/api/sub"
hook_arm "$(payload "$FIXTURE/apps/api/sub/a.ts")"
is "#91 AC3 a nested unrelated repository behaves as before" "$(task_state stage "$m")" "build"

# AC4 — another checkout's unfinished build is a warning.
new_worktree_fixture; d="$(wt_task_dir wt_owed)"; building "$d"
is "#91 AC4 default mode exits 0" "$(gate_code </dev/null)" "0"
out="$(gate </dev/null)"
says "#91 AC4 it is a warning" "$out" "warning"
says "#91 AC4 it names the checkout" "$out" "$WT"
says "#91 AC4 it names the task" "$out" "apps/api/.agents/artifacts/task_${TODAY}_wt_owed"
says "#91 AC4 it names the missing files" "$out" "3_memory.md 4_verify.md"
j="$(gate --json </dev/null)"
is "#91 AC4 --json exits 0" "$(gate_code --json </dev/null)" "0"
says "#91 AC4 --json carries a systemMessage" "$(printf '%s' "$j" | jq -r '.systemMessage // empty' 2>/dev/null)" "task_${TODAY}_wt_owed"
is "#91 AC4 --json has no decision" "$(printf '%s' "$j" | jq -r 'has("decision")' 2>/dev/null)" "false"
write_memory "$d"
says "#91 AC4 a missing verify alone is named" "$(gate </dev/null)" "missing: 4_verify.md"

# AC5 — the holding checkout still blocks.
new_worktree_fixture; d="$(wt_task_dir wt_owed)"; building "$d"
is "#91 AC5 the worktree's own gate blocks" "$(wt_gate_code)" "1"
m="$(task_dir main_owed)"; building "$m"
is "#91 AC5 this checkout still blocks beside a warning" "$(gate_code </dev/null)" "1"
out="$(gate </dev/null)"
says "#91 AC5 the block is reported" "$out" "task_${TODAY}_main_owed"
says "#91 AC5 and the warning" "$out" "task_${TODAY}_wt_owed"
j="$(gate --json </dev/null)"
is "#91 AC5 --json blocks" "$(printf '%s' "$j" | jq -r '.decision // empty' 2>/dev/null)" "block"
lacks "#91 AC5 the block reason names only this checkout" "$(printf '%s' "$j" | jq -r '.reason // empty' 2>/dev/null)" "wt_owed"
says "#91 AC5 the warning rides beside it" "$(printf '%s' "$j" | jq -r '.systemMessage // empty' 2>/dev/null)" "wt_owed"

# AC6 — no noise.
new_worktree_fixture; d="$(wt_task_dir done_task)"; building "$d"; write_memory "$d"; write_verify "$d"
silent "#91 AC6 a finished task is silent" "$(gate </dev/null)"
silent "#91 AC6 and silent in --json" "$(gate --json </dev/null)"
new_worktree_fixture; d="$(wt_task_dir waiting)"; planned "$d"
silent "#91 AC6 a plan-stage task is silent" "$(gate </dev/null)"
new_worktree_fixture; d="$(wt_task_dir merged)"; building "$d"
m="$(task_dir merged)"; building "$m"; write_memory "$m"; write_verify "$m"; seed_kb "$m"
silent "#91 AC6 a stale copy of a recorded task is silent" "$(gate </dev/null)"
new_worktree_fixture; d="$(wt_task_dir both)"; building "$d"; building "$(task_dir both)"
lacks "#91 AC6 a task already blocked here is not warned about" "$(gate </dev/null)" "warning"
new_worktree_fixture; d="$(wt_task_dir gone)"; building "$d"; rm -rf "$WT"
silent "#91 AC6 a deleted worktree folder is silent" "$(gate </dev/null)"
is "#91 AC6 and does not fail the gate" "$(gate_code </dev/null)" "0"
new_worktree_fixture; d="$(wt_task_dir retry)"; building "$d"
silent "#91 AC6 a stop retry is silent" "$(printf '{"stop_hook_active":true}' | gate --json)"

# AC7 — a real commit in a linked worktree: git sets GIT_DIR and GIT_INDEX_FILE for the hook.
new_worktree_fixture
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh "$FIXTURE/.git/hooks/pre-commit"
m="$(task_dir main_owed)"; building "$m"
out="$( cd "$WT" && echo x > apps/api/src/a.ts && git add apps/api/src/a.ts && git commit -qm t 2>&1; echo "exit=$?" )"
says "#91 AC7 a worktree commit is not blocked by the main checkout" "$out" "exit=0"
says "#91 AC7 and warns about it" "$out" "task_${TODAY}_main_owed"
new_worktree_fixture
ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh "$FIXTURE/.git/hooks/pre-commit"
d="$(wt_task_dir wt_owed)"; building "$d"
out="$( cd "$FIXTURE" && echo x > apps/api/src/a.ts && git add apps/api/src/a.ts && git commit -qm t 2>&1; echo "exit=$?" )"
says "#91 AC7 a main commit is not blocked by a worktree" "$out" "exit=0"
says "#91 AC7 and warns about the worktree" "$out" "task_${TODAY}_wt_owed"

# AC8 — Codex's Stop filter shows the warning.
filter="$(jq -r '.hooks.Stop[0].hooks[0].command' "$REPO/adapters/codex/.codex/hooks.json" | sed -n "s/.*| jq '\(.*\)'\$/\1/p")"
codex() { printf '%s' "$1" | jq -c "$filter" 2>&1; }
is "#91 AC8 a warning-only message passes" "$(codex '{"systemMessage":"w"}')" '{"systemMessage":"w"}'
is "#91 AC8 a block reason is still shown" "$(codex '{"decision":"block","reason":"r"}')" '{"systemMessage":"r"}'
is "#91 AC8 a block and a warning are both shown" "$(codex '{"decision":"block","reason":"r","systemMessage":"w"}')" '{"systemMessage":"r\nw"}'
silent "#91 AC8 no gate output stays silent" "$(codex '')"

# Review of 14ce8a4: the other-checkout report runs at every stop and commit, so its cost per task dir
# matters. Shims record the arguments `stat` and `awk` get: no sorting (a `stat` per dir) of another
# checkout's dirs, and no spec read for a task that is not in the build stage.
new_worktree_fixture; planned "$(wt_task_dir cost_waiting)"
d="$(wt_task_dir cost_done)"; building "$d"; write_memory "$d"; write_verify "$d"
building "$(wt_task_dir cost_owed)"
SHIM="$WTS/shim"; mkdir -p "$SHIM"
for tool in stat awk; do
  printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "%s/%s.log"\nexec "%s" "$@"\n' "$WTS" "$tool" "$(command -v "$tool")" > "$SHIM/$tool"
  chmod +x "$SHIM/$tool"
done
out="$( cd "$FIXTURE" && PATH="$SHIM:$PATH" $S/memory-gate.sh 2>&1 </dev/null )"
says  "#91 cost: the warning is still there" "$out" "task_${TODAY}_cost_owed"
lacks "#91 cost: another checkout's dirs are not sorted" "$(cat "$WTS/stat.log" 2>/dev/null)" "$WT/"
lacks "#91 cost: a waiting task's spec is not read" "$(cat "$WTS/awk.log" 2>/dev/null)" "cost_waiting/1_spec.md"

# --- issue #103: the git hook runs one bundle, the one the running gate lives in -------------------------
# Every script of a marked bundle writes "<tag>:<script>" to $RAN when it runs or is sourced. A file, not
# stderr: the gate discards its helpers' stderr.
cd /   # a stray git command in the cases below must not reach the repository the suite runs from
mark() { # mark <bundle root> <tag>
  local f script
  for f in memory-gate harness-common task-state detect-monorepo-framework; do
    script="$1/core/scripts/$f.sh"
    [ -f "$script" ] || continue
    { head -n1 "$script"; printf 'printf "%%s\\n" "%s:%s" >> "%s"\n' "$2" "$f" "$RAN"; sed 1d "$script"; } > "$WTS/marked"
    cat "$WTS/marked" > "$script"   # keeps the file mode
  done
}
# A worktree fixture whose two bundles report themselves: "main" in this checkout, "branch" in $WT.
marked_fixture() {
  new_worktree_fixture
  RAN="$WTS/ran"
  mark "$FIXTURE/.agents/monorepo-agents-harness" main
  mark "$WT/.agents/monorepo-agents-harness" branch
}
GATE_LINK=../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh
wire_hook() { ln -s "${1:-$GATE_LINK}" "$FIXTURE/.git/hooks/pre-commit"; }
commit_in() { # commit_in <checkout> -> the commit's output, and its exit code on the last line
  : > "$RAN"
  ( cd "${1:?}" && mkdir -p apps/api/src && echo x >> apps/api/src/a.ts && git add apps/api/src/a.ts \
    && git commit -qm t 2>&1; echo "exit=$?" )
}
ran() { cat "$RAN" 2>/dev/null; }

# AC1, AC2 — a commit in a worktree runs none of that branch's code, and is still gated on its own tasks.
marked_fixture; wire_hook
d="$(wt_task_dir owed103)"; building "$d"
d="$(wt_task_dir kb103)"; building "$d"; write_memory "$d"; write_verify "$d"   # makes the gate run check-kb too
out="$(commit_in "$WT")"
lacks "#103 AC1 a worktree commit runs none of the branch's scripts" "$(ran)" "branch:"
for f in memory-gate harness-common task-state detect-monorepo-framework; do
  says "#103 AC1 it runs the main checkout's $f.sh" "$(ran)" "main:$f"
done
says "#103 AC2 the worktree's unfinished work still blocks" "$out" "exit=1"
says "#103 AC2 and the worktree's task is the one named" "$out" "103 is missing"

# AC3 — a helper the hook's bundle does not have is not borrowed from the branch.
for f in harness-common task-state detect-monorepo-framework; do
  marked_fixture; wire_hook; building "$(wt_task_dir gap103)"
  rm "$FIXTURE/.agents/monorepo-agents-harness/core/scripts/$f.sh"
  out="$(commit_in "$WT")"
  lacks "#103 AC3 without main's $f.sh nothing comes from the branch" "$(ran)" "branch:"
  says "#103 AC3 and the unfinished build still blocks without $f.sh" "$out" "exit=1"
done

# AC4 — a worktree that has no bundle gets the same gate as any other.
untracked_bundle_fixture() {
  new_fixture; printf '.agents/monorepo-agents-harness/\n' > "$FIXTURE/.gitignore"; commit_fixture
  rm -rf "$WTS"; mkdir -p "$WTS"; RAN="$WTS/ran"
  ( cd "$FIXTURE" && git worktree add -q -b t1 "$WTS/t1" ) >/dev/null 2>&1
  WT="$WTS/t1"
  [ -d "$WT" ] && [ ! -e "$WT/.agents/monorepo-agents-harness" ] || { bad "#103 fixture: worktree without a bundle" "$WT"; exit 1; }
  wire_hook
}
untracked_bundle_fixture; write_spec "$(wt_task_dir spec103)"
says "#103 AC4 no bundle in the worktree: a spec-only commit passes" "$(commit_in "$WT")" "exit=0"
untracked_bundle_fixture; building "$(wt_task_dir owed103)"
out="$(commit_in "$WT")"
says "#103 AC4 no bundle in the worktree: an unfinished build blocks" "$out" "exit=1"
says "#103 AC4 and is named" "$out" "task_${TODAY}_owed103 is missing"
untracked_bundle_fixture; d="$(wt_task_dir kb103)"; building "$d"; write_memory "$d"; write_verify "$d"
says "#103 AC4 no bundle in the worktree: check-kb runs too" "$(commit_in "$WT")" "knowledge-base coverage"

# AC5 — however the link is written.
marked_fixture; wire_hook "$FIXTURE/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"
planned "$(wt_task_dir abs103)"; out="$(commit_in "$WT")"
lacks "#103 AC5 an absolute link: nothing from the branch" "$(ran)" "branch:"
says "#103 AC5 an absolute link: main's stage reader" "$(ran)" "main:task-state"
# pre-commit -> .git/harness-gate -> the gate; both links relative to their own folder
marked_fixture; ln -s ../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh "$FIXTURE/.git/harness-gate"
wire_hook ../harness-gate
planned "$(wt_task_dir chain103)"; out="$(commit_in "$WT")"
lacks "#103 AC5 a two-step link: nothing from the branch" "$(ran)" "branch:"
says "#103 AC5 a two-step link: main's stage reader" "$(ran)" "main:task-state"

# A commit in the main checkout gives the hook a relative path, which an exported CDPATH can redirect.
# The linked bundle sits outside .agents/, so a wrong folder cannot hide behind the checkout's bundle.
marked_fixture; mkdir -p "$FIXTURE/vendor/h"; cp -R "$REPO/core" "$FIXTURE/vendor/h/core"; mark "$FIXTURE/vendor/h" vendor
wire_hook ../../vendor/h/core/scripts/memory-gate.sh; planned "$(task_dir cdpath103)"
mkdir -p "$WTS/cdp/.git/hooks" "$WTS/cdp/vendor/h/core/scripts"   # the same relative path there
out="$(export CDPATH="$WTS/cdp"; commit_in "$FIXTURE")"
says "#103 AC5 with CDPATH exported: the linked bundle's stage reader" "$(ran)" "vendor:task-state"

# Folders are compared, not path text: on a disk that ignores letter case the link may be spelled
# another way, and the bundle it points into is the same one.
marked_fixture
if [ -d "$FIXTURE/.agents/monorepo-agents-harness/Core" ]; then
  wire_hook ../../.agents/monorepo-agents-harness/Core/Scripts/memory-gate.sh
  planned "$(wt_task_dir case103)"; out="$(commit_in "$WT")"
  lacks "#103 AC5 a link in another letter case: nothing from the branch" "$(ran)" "branch:"
  says "#103 AC5 a link in another letter case: main's stage reader" "$(ran)" "main:task-state"
else
  printf '  skip #103 AC5 letter case: this disk keeps letter case\n'
fi

# AC6 — called by path in a worktree (CI, the Stop hooks), the gate still runs that checkout's bundle.
marked_fixture; planned "$(wt_task_dir path103)"
for mode in "" --json; do
  : > "$RAN"; ( cd "$WT" && $S/memory-gate.sh $mode >/dev/null 2>&1 </dev/null )
  for f in harness-common task-state detect-monorepo-framework; do
    says "#103 AC6 by path${mode:+ $mode}: the worktree's $f.sh" "$(ran)" "branch:$f"
  done
  lacks "#103 AC6 by path${mode:+ $mode}: nothing from the main checkout" "$(ran)" "main:"
done

# AC7 — a copy of the gate is not inside a bundle, so it keeps using the checkout's.
new_worktree_fixture; RAN="$WTS/ran"
cp "$FIXTURE/.agents/monorepo-agents-harness/core/scripts/memory-gate.sh" "$FIXTURE/.git/hooks/pre-commit"
mark "$FIXTURE/.agents/monorepo-agents-harness" main; mark "$WT/.agents/monorepo-agents-harness" branch
building "$(wt_task_dir copy103)"; out="$(commit_in "$WT")"
says "#103 AC7 a copied gate uses the committing checkout's bundle" "$(ran)" "branch:task-state"
lacks "#103 AC7 and nothing from the main checkout" "$(ran)" "main:"
says "#103 AC7 and still blocks" "$out" "exit=1"

# AC8 — a caller's RUNTIME_DIR wins.
marked_fixture; wire_hook; planned "$(wt_task_dir override103)"
mkdir -p "$WTS/alt"; cp -R "$REPO/core" "$WTS/alt/core"; mark "$WTS/alt" alt
out="$(export RUNTIME_DIR="$WTS/alt"; commit_in "$WT")"
says "#103 AC8 RUNTIME_DIR names the stage reader" "$(ran)" "alt:task-state"
lacks "#103 AC8 and not the branch's" "$(ran)" "branch:"
lacks "#103 AC8 and not main's" "$(ran)" "main:task-state"

# AC9 — a project with its own pre-commit hook adds the line the installer prints.
new_fixture; rm -rf "$FIXTURE/.agents"; rm -rf "$WTS"; mkdir -p "$WTS"; RAN="$WTS/ran"
printf '#!/bin/sh\n' > "$FIXTURE/.git/hooks/pre-commit"; chmod +x "$FIXTURE/.git/hooks/pre-commit"
log="$( cd "$FIXTURE" && bash "$REPO/core/scripts/install-harness.sh" --from "$REPO" --project-name consumer 2>&1 )"
line="$(printf '%s\n' "$log" | grep 'pre-commit already exists' | grep -o 'bash .*memory-gate\.sh"\{0,1\}')"
if [ -n "$line" ]; then ok "#103 AC9 the installer prints a line to add"; else bad "#103 AC9 the installer prints a line to add" "$log"; fi
printf '%s\n' "$line" >> "$FIXTURE/.git/hooks/pre-commit"
( cd "$FIXTURE" && git add -A && git commit -q --no-verify -m init ) >/dev/null 2>&1
( cd "$FIXTURE" && git worktree add -q -b t1 "$WTS/t1" ) >/dev/null 2>&1; WT="$WTS/t1"
[ -d "$WT/.agents/monorepo-agents-harness" ] || { bad "#103 fixture: installed worktree with the bundle" "$log"; exit 1; }
mark "$FIXTURE/.agents/monorepo-agents-harness" main; mark "$WT/.agents/monorepo-agents-harness" branch
planned "$(root_task_dir main103)"; planned "$WT/.agents/artifacts/task_${TODAY}_wt103"
for co in "$FIXTURE" "$WT"; do
  where=main; [ "$co" = "$WT" ] && where=worktree
  out="$(commit_in "$co")"
  says "#103 AC9 from the $where: the commit passes" "$out" "exit=0"
  says "#103 AC9 from the $where: main's gate runs" "$(ran)" "main:memory-gate"
  says "#103 AC9 from the $where: main's stage reader runs" "$(ran)" "main:task-state"
  lacks "#103 AC9 from the $where: nothing from the branch" "$(ran)" "branch:"
done
building "$WT/.agents/artifacts/task_${TODAY}_owed103"
says "#103 AC9 and the line's exit code blocks the commit" "$(commit_in "$WT")" "exit=1"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
