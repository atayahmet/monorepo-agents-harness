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
# It arms only what the gate would actually enforce, and the rules that make that true are one
# list: candidates are the task dirs above the written path, a dir that already
# has 3_memory.md is skipped (nothing left to arm), a plan is armed only when the written path is
# inside that plan's own workspace, and the hook will not arm a second task if there is already a
# build in flight in that workspace. Arming is also bounded to today or yesterday to avoid arming
# abandoned plans from months ago (cross-midnight builds still work). A write into another checkout
# of the same repository (a worktree) is judged in that checkout, whatever directory the session is in.
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
YESTERDAY="$(date -d yesterday +%Y_%m_%d 2>/dev/null || date -v-1d +%Y_%m_%d 2>/dev/null || echo "$TODAY")"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
TASK_STATE="${TASK_STATE:-$RUNTIME_DIR/core/scripts/task-state.sh}"
[ -f "$TASK_STATE" ] || TASK_STATE="$BUNDLE_DIR/core/scripts/task-state.sh"

# The task-dir order is shared with memory-gate.sh (see harness_sort_task_dirs), so the hook
# and the gate cannot disagree about which dir is the newest one. Optional: without it the
# hook keeps the order of the walk below, nearest workspace first.
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
# from arming on a perfectly ordinary project. `rel_target` is the repo-root-relative form, kept as a
# fallback for a path that cannot be placed at all.
abs_target="$target"
case "$abs_target" in
  /*) : ;;
  ./?*) abs_target="$ROOT/${abs_target#./}" ;;
  *)   abs_target="$ROOT/$abs_target" ;;
esac
# The parent directory often does not exist — the first write of a build is usually a brand-new file
# in a brand-new directory — and the reported spelling may differ from git's physical root. Walk up
# to the deepest directory that DOES exist, resolve that one physically, and re-append the part below
# it, so `canon_target` is comparable with `ROOT` even for a file nobody has created yet. Resolving
# only the parent (the old rule) left such a write in its raw spelling, which matches neither the
# physical root nor PWD, and a repo-root plan then never armed.
tail=""
probe="$abs_target"
while [ ! -d "$probe" ]; do
  if [ "$probe" = "/" ]; then break; fi
  tail="/$(basename "$probe")$tail"
  probe="$(dirname "$probe")"
done
if [ -d "$probe" ]; then
  canon_target="$(cd "$probe" && pwd -P)$tail"
else
  canon_target="$abs_target"
fi
rel_target=""
for root_prefix in "$ROOT" "$PWD"; do
  case "$abs_target" in
    "$root_prefix"/*) rel_target="${abs_target#"$root_prefix"/}"; break ;;
  esac
done

# --- the checkout the path belongs to ------------------------------------------------------------
# A session in one checkout can edit another checkout of the same repository (`--add-dir`, issue #91).
# The walk below then belongs to THAT checkout: its task dirs are the ones above the write. Only shell
# tests run until a `.git` other than this checkout's is found, so an ordinary write costs no git
# call. A repository that is not a checkout of this one (a submodule, a nested clone) changes nothing.
# TASK_STATE stays the session's own bundle.
if declare -F harness_worktree_roots >/dev/null 2>&1; then
  dir="$canon_target"
  checkouts=""
  while [ "${dir%/*}" != "$dir" ]; do
    dir="${dir%/*}"
    [ -n "$dir" ] && [ -e "$dir/.git" ] || continue
    [ ! "$dir" -ef "$ROOT" ] || break
    [ -n "$checkouts" ] || checkouts="$(harness_worktree_roots "$ROOT")"
    found=0
    while IFS= read -r checkout; do
      if [ -n "$checkout" ] && [ "$checkout" -ef "$dir" ]; then found=1; break; fi
    done <<< "$checkouts"
    if [ "$found" -eq 1 ]; then
      ROOT="$dir"
      rel_target=""   # it was relative to the session's checkout, not to this one
      break
    fi
  done
fi

[ -f "$TASK_STATE" ] || exit 0

# --- the plan to arm ----------------------------------------------------------------------------
# A plan is armed only by a write inside its own workspace, and a task's workspace is the path in front
# of its `.agents/artifacts/`. So the candidates are the task dirs of the written path's ancestors, up to
# the repo root: a walk, not a scan. It needs no workspace detection, it is correct in any layout, and
# it is cheap enough to run before every write. A change in apps/docs never reaches the apps/api plan.
#
# Both spellings are walked (see above). A path outside the checkout has no ancestors here, so a hook
# that cannot place the write arms nothing.
ancestor_task_dirs() { # ancestor_task_dirs <absolute path>
  local dir="$1" d
  case "$dir" in "$ROOT"/*) ;; *) return 0 ;; esac
  while :; do
    for d in "$dir"/.agents/artifacts/task_*; do
      if [ -d "$d" ]; then printf '%s\n' "$d"; fi
    done
    [ "$dir" != "$ROOT" ] || break
    dir="${dir%/*}"
  done
}
list_candidates() {
  ancestor_task_dirs "$canon_target"
  if [ -n "$rel_target" ]; then ancestor_task_dirs "$ROOT/$rel_target"; fi
}

candidates=()
while IFS= read -r task_dir; do
  [ -n "$task_dir" ] && candidates+=("$task_dir")
done < <(if declare -F harness_sort_task_dirs >/dev/null 2>&1; then
           list_candidates | harness_sort_task_dirs
         else
           list_candidates
         fi)
[ "${#candidates[@]}" -gt 0 ] || exit 0   # no task dir above the write — nothing to arm

for task_dir in "${candidates[@]}"; do
  # A task that already has its memory is recorded; there is nothing left to arm. Marking it would
  # dirty a finished, committed task dir on some later unrelated write.
  [ -f "$task_dir/3_memory.md" ] && continue
  # If there is already a build in flight in the same workspace as the write, stop — do not arm
  # a second task. The write belongs to that build.
  stage="$(bash "$TASK_STATE" stage "$task_dir" 2>/dev/null || true)"
  if [ "$stage" = "build" ]; then
    break
  fi
  # "Is this a plan, and has its build not started?" is task-state.sh's answer, not a second parser
  # here — the same reader the gate uses, including the legacy plan file name.
  [ "$stage" = "plan" ] || continue
  # Bound arming to today or yesterday to avoid arming abandoned plans from months ago
  # (a build that spans midnight still needs yesterday's plan to be armable).
  base="$(basename "$task_dir")"
  dt=""
  if command -v grep >/dev/null 2>&1; then
    dt="$(printf '%s
' "$base" | grep -oE '[0-9]{4}[_-][0-9]{2}[_-][0-9]{2}' | head -1 | sed 's/[-]/_/g' || true)"
  fi
  [ -n "$dt" ] || dt="0000_00_00"
  if [ "$dt" != "$TODAY" ] && [ "$dt" != "$YESTERDAY" ]; then
    continue
  fi
  plan="$task_dir/2_plan.md"
  [ -f "$plan" ] || plan="$task_dir/1_plan.md"   # legacy layout, same fallback the stage reader uses
  [ -f "$plan" ] || continue
  # The write is delegated, and it is write-once — a second call is a re-run of the same build and
  # leaves the first timestamp alone.
  bash "$TASK_STATE" mark-build "$plan" >/dev/null 2>&1 || true
  break
done

exit 0
