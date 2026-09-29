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
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
TASK_STATE="${TASK_STATE:-$RUNTIME_DIR/core/scripts/task-state.sh}"
[ -f "$TASK_STATE" ] || TASK_STATE="$BUNDLE_DIR/core/scripts/task-state.sh"
DETECT_SCRIPT="${DETECT_SCRIPT:-$RUNTIME_DIR/core/scripts/detect-monorepo-framework.sh}"
[ -x "$DETECT_SCRIPT" ] || DETECT_SCRIPT="$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh"

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

[ -f "$TASK_STATE" ] || exit 0

# --- the plan to arm ----------------------------------------------------------------------------
# The newest task dir whose plan is a plan and is not already marked. Every workspace the framework
# detector knows about is scanned, and any date counts: a build that continues a task opened
# yesterday is still a build.
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
  patterns+=("$parent"/*/.agents/artifacts/task_*)
done
[ "${#patterns[@]}" -gt 0 ] || exit 0   # no task has ever been opened — nothing to arm

for task_dir in $(ls -td "${patterns[@]}" 2>/dev/null || true); do
  plan="$task_dir/2_plan.md"
  [ -f "$plan" ] || plan="$task_dir/1_plan.md"
  [ -f "$plan" ] || continue
  phase="$(awk -v f="$plan" '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR==1 { in_fm=1; next }
    in_fm && $0 ~ /^---[[:space:]]*$/ { exit }
    in_fm && match($0, "^[[:space:]]*phase[[:space:]]*:[[:space:]]*") {
      print substr($0, RSTART+RLENGTH); exit
    }
  ' "$plan" 2>/dev/null || true)"
  [ "$phase" = "plan" ] || continue
  # The write is delegated, and it is write-once — a second call is a re-run of the same build and
  # leaves the first timestamp alone.
  bash "$TASK_STATE" mark-build "$plan" >/dev/null 2>&1 || true
  break
done

exit 0
