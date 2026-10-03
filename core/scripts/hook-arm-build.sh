#!/usr/bin/env bash
# hook-arm-build — arm the memory-gate when implementation actually starts, from a tool hook.
# Agent-agnostic.
#
# The memory-gate only enforces a task that reached the build stage, and the marker that says so
# (`build_started` on the plan) is normally written by /monorepo-harness-build. That leaves one path
# unmarked: an agent that leaves plan mode, writes 1_spec.md + 2_plan.md and starts editing code
# without ever running the build command. This hook covers it by watching the first write that is
# NOT a task artifact — the same boundary the plan-reminder hook already describes in prose.
#
# It arms only what the gate would actually enforce, and the three rules that make that true are one
# list: candidates are the task dirs created TODAY (the gate reads no other date), a dir that already
# has 3_memory.md is skipped (nothing left to arm), and a plan is armed only when the written path is
# inside that plan's own workspace. Marking a task the gate never reads produced a dirty tracked file
# on every unrelated write, and arming a plan-only task blocked the Stop hook for work never built.
#
# Wiring: an agent's PreToolUse hook for Write/Edit/MultiEdit, whose command runs this script. It is
# the arming half of ADR 0001 and depends on nothing but coreutils; the JSON on stdin is read with jq
# when jq is present and with a single-unique-match sed fallback when it is not.
#
#   PreToolUse:  bash .agents/monorepo-agents-harness/core/scripts/hook-arm-build.sh
#
# It edits nothing itself — the write is task-state.sh mark-build — and it always exits 0. A hook
# that cannot answer must never stand between an agent and its edit.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TODAY="$(date +%Y_%m_%d)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
TASK_STATE="${TASK_STATE:-$RUNTIME_DIR/core/scripts/task-state.sh}"
[ -f "$TASK_STATE" ] || TASK_STATE="$BUNDLE_DIR/core/scripts/task-state.sh"
DETECT_SCRIPT="${DETECT_SCRIPT:-$RUNTIME_DIR/core/scripts/detect-monorepo-framework.sh}"
[ -x "$DETECT_SCRIPT" ] || DETECT_SCRIPT="$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh"

# The task-dir order is shared with memory-gate.sh (see harness_task_dirs_newest_first), so the hook
# and the gate cannot disagree about which dir of the day is the newest one. Optional: without it the
# hook keeps the raw glob order below, which is the pre-0.4.0-rc.10 behaviour, not a failure.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/harness-common.sh" ]; then
  . "$SCRIPT_DIR/harness-common.sh"
fi

# --- the path the agent is about to write -------------------------------------------------------
# stdin is the agent's hook JSON. It is only read when it is a pipe, and never for longer than the
# timeout, so a hook that never closes it cannot stall the edit. A run with no readable payload just
# does nothing: the wiring, not this script, decides when it is called.
read_input() {
  input=""
  if [ ! -t 0 ]; then
    while IFS= read -r -t 2 line || [ -n "$line" ]; do
      input="$input$line"
      [ "${#input}" -gt 65536 ] && break
    done
  fi
  :   # the loop's last test is a negative one; a function must not return it under `set -e`
}

edited_path() {
  local raw
  if command -v jq >/dev/null 2>&1 && printf '%s' "$input" | jq -e '.tool_input.file_path // .tool_input.path // empty' >/dev/null 2>&1; then
    raw="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
  else
    # No jq, or the payload is not the shape we know. Fall back to the raw field, but only when it
    # is unambiguous: two candidates mean the guess could be a path from file CONTENT, and arming on
    # that would mark a task nobody is building. Zero or many means no answer, not a guess.
    raw="$(printf '%s' "$input" \
      | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | sed -e 's/.*:[[:space:]]*"//' -e 's/"$//' || true)"
    case "$(printf '%s\n' "$raw" | grep -c . || true)" in
      1) : ;;
      *) return 0 ;;
    esac
  fi
  [ -n "$raw" ] || return 0
  printf '%s' "$raw"
}

read_input
target="$(edited_path || true)"
[ -n "$target" ] || exit 0   # nothing to judge — a hook payload without a file path

# The harness's own working state is never implementation: 1_spec.md, 2_plan.md, 3_memory.md,
# index.md, lessons.md and every other artifact write happens while the task is still planning or
# recording, and arming on one of them would block a spec-only task from ending — the bug this
# whole mechanism exists to remove.
case "$target" in
  .agents/*|.agents|*/.agents/*) exit 0 ;;
esac

# The written path in the two forms the workspace rule below may need.
#
# `abs_target` is resolved against the repo root, because agents report a path either absolute or
# repo-relative. `canon_target` resolves symlinks on the way, because git reports the repo root as a
# PHYSICAL path while an agent may hand over the logical one — a checkout reached through a symlink, a
# TMPDIR with a doubled slash. Comparing those two spellings directly would silently stop the hook
# from arming on a perfectly ordinary project. `rel_target` is the repo-root-relative form, kept for a
# path whose parent directory does not exist yet and therefore cannot be resolved.
abs_target="$target"
case "$abs_target" in
  /*) : ;;
  ./?*) abs_target="$ROOT/${abs_target#./}" ;;
  *)   abs_target="$ROOT/$abs_target" ;;
esac
canon_dir="$(dirname "$abs_target")"
if [ -d "$canon_dir" ]; then
  canon_target="$(cd "$canon_dir" && pwd -P)/$(basename "$abs_target")"
else
  canon_target="$abs_target"
fi
rel_target=""
for root_prefix in "$ROOT" "$PWD"; do
  case "$abs_target" in
    "$root_prefix"/*) rel_target="${abs_target#"$root_prefix"/}"; break ;;
  esac
done

# Does <path> name something inside <workspace>? A workspace matches exactly or as a prefix followed
# by "/", so `apps/api-legacy` is never treated as `apps/api`.
in_workspace() {
  case "$1" in
    "$2"|"$2"/*) return 0 ;;
  esac
  return 1
}

[ -f "$TASK_STATE" ] || exit 0

# --- the plan to arm ----------------------------------------------------------------------------
# The candidates are exactly the gate's candidates: task dirs created TODAY, newest first by the date
# in the dir name. "Any date counts" was wrong twice over — it marked finished tasks the gate then
# never reads again, and it let an unrelated write arm a plan-only task into a Stop block for work
# that was never built. If the gate does not enforce a dir, this hook has no business marking it.
workspace_parents=()
if [ -x "$DETECT_SCRIPT" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && workspace_parents+=("$p")
  done < <("$DETECT_SCRIPT" --workspaces 2>/dev/null || true)
fi
[ "${#workspace_parents[@]}" -eq 0 ] && workspace_parents=("$ROOT/apps" "$ROOT/packages")

patterns=()
for parent in "${workspace_parents[@]}"; do
  [ -d "$parent" ] || continue
  patterns+=("$parent"/*/.agents/artifacts/task_${TODAY}_*)
done
[ "${#patterns[@]}" -gt 0 ] || exit 0   # no task has been opened today — nothing to arm

candidates=()
while IFS= read -r task_dir; do
  [ -n "$task_dir" ] && candidates+=("$task_dir")
done < <(if declare -F harness_task_dirs_newest_first >/dev/null 2>&1; then
           harness_task_dirs_newest_first "${patterns[@]}"
         else
           ls -td "${patterns[@]}" 2>/dev/null || true
         fi)

for task_dir in "${candidates[@]}"; do
  # A task that already has its memory is recorded; there is nothing left to arm. Marking it would
  # dirty a finished, committed task dir on some later unrelated write.
  [ -f "$task_dir/3_memory.md" ] && continue
  # "Is this a plan, and has its build not started?" is task-state.sh's answer, not a second parser
  # here — the same reader the gate uses, including the legacy plan file name.
  [ "$(bash "$TASK_STATE" stage "$task_dir" 2>/dev/null || true)" = "plan" ] || continue
  # Arm only a plan whose own workspace is being written to: a change in apps/docs says nothing about
  # whether the apps/api task is being built. The workspace is the path in front of the task's own
  # `.agents/artifacts/`, so this needs no lookup table and cannot disagree with where the dir lives.
  # Failing to match arms nothing: a hook that cannot place the write must not guess a task.
  ws_abs="${task_dir%%/.agents/artifacts/*}"
  in_ws=0
  if in_workspace "$canon_target" "$ws_abs"; then
    in_ws=1
  elif [ -n "$rel_target" ] && in_workspace "$rel_target" "${ws_abs#"$ROOT"/}"; then
    in_ws=1
  fi
  [ "$in_ws" -eq 1 ] || continue
  plan="$task_dir/2_plan.md"
  [ -f "$plan" ] || plan="$task_dir/1_plan.md"   # legacy layout, same fallback the stage reader uses
  [ -f "$plan" ] || continue
  # The write is delegated, and it is write-once — a second call is a re-run of the same build and
  # leaves the first timestamp alone.
  bash "$TASK_STATE" mark-build "$plan" >/dev/null 2>&1 || true
  break
done

exit 0
