#!/usr/bin/env bash
# Memory-gate — the HARD enforcement of the plan/spec/memory/verify workflow. Agent-agnostic.
#
# Task artifact convention: <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/ where
# <workspace> is discovered by detect-monorepo-framework.sh (apps/*, packages/*, libs/*, etc.).
#
# Artifact order (per the AI-native SDLC): 1_spec.md (what) -> 2_plan.md (how) -> 3_memory.md ->
# 4_verify.md. The title file is the SPEC, named 1_spec.md. Backcompat: a legacy task directory
# created under the old naming (where the spec was 2_spec.md and the plan was 1_plan.md) exposes its
# spec as 2_spec.md only, so when 1_spec.md is absent the gate falls back to 2_spec.md as the spec.
#
# Two modes, one contract:
#   default (git pre-commit / CI):  exit 1 when a task dir that reached the BUILD stage is missing
#                                   its spec (1_spec.md, or legacy 2_spec.md), 3_memory.md, or
#                                   (when required) 4_verify.md. Works with ANY agent — or none.
#   --json (Claude Code Stop hook): print a {"decision":"block",...} JSON object under those same
#                                   conditions; silent exit 0 otherwise. Reads the hook's own input
#                                   and stands down silently when `stop_hook_active` is true, so a
#                                   block can never repeat itself.
#
# The gate only asks about tasks that REACHED THE BUILD STAGE. `/monorepo-harness-spec` and
# `/monorepo-harness-plan` stop at a stage boundary by design, so a spec-only or plan-only task is
# not "missing memory" — it is not finished being built. The stage is read from one place
# (task-state.sh stage), which answers `build` exactly when the task's plan carries the
# `build_started` field that `/monorepo-harness-build` writes before it implements anything.
#
# 4_verify.md (Feedback Loop enforcement) is only required when the spec's "## Test /
# verification plan" section is not N/A — mirrors the existing research-only exemption for
# tasks with nothing verifiable to check.
#
# Depends only on git + coreutils; --json mode additionally needs jq (fail-open without it).
# This is the universal replacement for agent-specific stop-hooks on agents that cannot block
# their own stop — wire the default mode as a git pre-commit hook and/or CI step.
#
#   git pre-commit:  ln -s ../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
#   CI:              bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh
#   Claude Stop hook: see adapters/claude-code/.claude/settings.json

set -euo pipefail

JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TODAY="$(date +%Y_%m_%d)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
DETECT_SCRIPT="${DETECT_SCRIPT:-$RUNTIME_DIR/core/scripts/detect-monorepo-framework.sh}"
[ ! -x "$DETECT_SCRIPT" ] && DETECT_SCRIPT="$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh"

# The task-dir order is shared with hook-arm-build.sh, so the two scripts cannot disagree about which
# dir of the day is the newest one. Sourced when present and optional on purpose: without it the gate
# keeps the raw glob order below, which changes the ORDER it reports in and nothing else — a library
# that is missing must never be able to switch this gate off.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/harness-common.sh" ]; then
  . "$SCRIPT_DIR/harness-common.sh"
fi

# Discover workspace directories using the framework detector.
workspace_parents=()
if [ -x "$DETECT_SCRIPT" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && workspace_parents+=("$p")
  done < <("$DETECT_SCRIPT" --workspaces 2>/dev/null || true)
fi
# Fallback for unknown frameworks or missing detector.
if [ "${#workspace_parents[@]}" -eq 0 ]; then
  workspace_parents=("$ROOT/apps" "$ROOT/packages")
fi

# Build the list of workspace artifact glob patterns to scan.
scan_patterns=()
for parent in "${workspace_parents[@]}"; do
  [ -d "$parent" ] || continue
  scan_patterns+=("$parent"/*/.agents/artifacts/task_*)
done
# Also scan repo root if present
if [ -d "$ROOT/.agents/artifacts" ]; then
  scan_patterns+=("$ROOT/.agents/artifacts/task_*")
fi

# All task dirs across discovered workspaces across all discovered workspaces, newest first BY THE DATE IN ITS
# NAME (see harness_task_dirs_newest_first — not by file mtime, which a checkout or a rebase moves).
# TODAY is the gate's scope, and hook-arm-build.sh arms nothing outside it: what the hook marks and
# what the gate reads can never be two different sets of task dirs.
CANDIDATE_DIRS=()
if [ "${#scan_patterns[@]}" -gt 0 ]; then
  while IFS= read -r d; do
    [ -n "$d" ] && CANDIDATE_DIRS+=("$d")
  done < <(if declare -F harness_task_dirs_newest_first >/dev/null 2>&1; then
             harness_task_dirs_newest_first "${scan_patterns[@]}"
           else
             ls -td "${scan_patterns[@]}" 2>/dev/null || true
           fi)
fi
[ "${#CANDIDATE_DIRS[@]}" -eq 0 ] && exit 0   # no task dirs → nothing to enforce

# The stage reader is task-state.sh, and it is the only implementation of "which stage is this
# task in" — the gate asks, it never re-reads the plan itself.
TASK_STATE="${TASK_STATE:-$RUNTIME_DIR/core/scripts/task-state.sh}"
[ -f "$TASK_STATE" ] || TASK_STATE="$BUNDLE_DIR/core/scripts/task-state.sh"

# The task dirs worth enforcing, newest first: the ones that reached the build stage. Picking the
# newest *build* dir rather than the newest dir of the day is what stops a spec written minutes
# later from moving the gate's attention off a build that is still owed memory.
build_dirs=()
stage_readable=1
for d in "${CANDIDATE_DIRS[@]}"; do
  s=""
  if [ -f "$TASK_STATE" ]; then
    s="$(bash "$TASK_STATE" stage "$d" 2>/dev/null || true)"
  fi
  case "$s" in
    build) build_dirs+=("$d") ;;
    none|spec|plan) : ;;
    *) stage_readable=0; break ;;   # the reader is missing or unusable
  esac
done
if [ "$stage_readable" -eq 0 ]; then
  # No reader means no way to tell a waiting task from a running one. Enforcing the newest dir is
  # what this gate did before and is the safe direction: a gate that cannot read its own stage
  # must not decide there is nothing to enforce.
  build_dirs=("${CANDIDATE_DIRS[@]:0:1}")
fi
# No build in flight today → the day is a spec, a plan or a research task, and there is nothing
# to enforce. This is the case issue #17 is about: a spec-only task must be allowed to end.
[ "${#build_dirs[@]}" -eq 0 ] && exit 0

# 4_verify.md is only required when the spec's "## Test / verification plan" section (resolved from
# 1_spec.md, or legacy 2_spec.md via resolve_spec) says something other than N/A. No spec → nothing
# to require verify against (not this function's job to also flag the missing spec; the callers
# already check that separately).
# Resolve the spec file for a task dir: the canonical 1_spec.md, else the legacy 2_spec.md
# (backcompat so pre-rename task dirs keep passing). Falls back to printing the canonical name so
# callers can flag it as missing when neither exists.
resolve_spec() {
  local dir="$1"
  [ -f "$dir/1_spec.md" ] && { printf '%s\n' "$dir/1_spec.md"; return; }
  [ -f "$dir/2_spec.md" ] && { printf '%s\n' "$dir/2_spec.md"; return; }
  printf '%s\n' "$dir/1_spec.md"
}

verify_required() {
  local dir="$1" spec section
  spec="$(resolve_spec "$dir")"
  [ -f "$spec" ] || return 1
  section="$(awk '/^## Test \/ verification plan/{f=1; next} /^## /{f=0} f' "$spec" 2>/dev/null || true)"
  case "$section" in
    *N/A*) return 1 ;;
    "") return 1 ;;
    *) return 0 ;;
  esac
}

# stop_hook_active — ask the agent's hook input whether this stop is the retry after a block this
# gate already issued. The harness sends the flag; ignoring it is what turned one interruption into
# an unbounded loop. Anything unreadable answers "not a retry": a fix for a blocking loop must never
# double as a way to switch the gate off. stdin is only read when it is a pipe (a hook), never when
# it is a terminal, and never for longer than the timeout below.
stop_hook_active() {
  [ -t 0 ] && return 1
  command -v jq >/dev/null 2>&1 || return 1
  input=""
  while IFS= read -r -t 2 line || [ -n "$line" ]; do
    input="$input$line"
    [ "${#input}" -gt 65536 ] && break
  done
  :   # the loop's last test is a negative one; a function must not return it under `set -e`
  printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1
}

if [ "$JSON_MODE" -eq 1 ]; then
  # The agent has already been told to finish the task once. Say nothing and let it stop.
  if stop_hook_active; then
    exit 0
  fi
  # Stop-hook mode: gates on 3_memory.md, and on 4_verify.md whenever required (the spec itself is
  # not re-checked here — a build-stage dir always has one, and default mode reports a missing one).
  for dir in "${build_dirs[@]}"; do
    json_missing=()
    [ -f "$dir/3_memory.md" ] || json_missing+=("3_memory.md")
    if verify_required "$dir" && [ ! -f "$dir/4_verify.md" ]; then
      json_missing+=("4_verify.md")
    fi
    [ "${#json_missing[@]}" -eq 0 ] && continue
    command -v jq >/dev/null 2>&1 || exit 0   # fail-open without jq
    # `|| exit 0` covers a jq that is present but unusable: a Stop hook must never exit non-zero
    # from here, or the agent reports a hook failure instead of a missing artifact.
    jq -n --arg dir "${dir#"$ROOT"/}" --arg files "${json_missing[*]}" '{"decision":"block","reason":("agent-workflow: Task is ending but " + $dir + " is missing: " + $files + ". Write the missing artifact(s) following the agent-workflow skill templates, then you may stop.")}' || exit 0
    exit 0
  done
  exit 0
fi

# Default mode, same stage check, same requirements — an agent that cannot block its own stop gets
# the same answer at pre-commit and in CI.
for dir in "${build_dirs[@]}"; do
  rel="${dir#"$ROOT"/}"
  missing=()
  MISSING_SPEC="$(basename "$(resolve_spec "$dir")")"
  [ -f "$(resolve_spec "$dir")" ] || missing+=("$MISSING_SPEC")
  [ -f "$dir/3_memory.md" ] || missing+=("3_memory.md")
  if verify_required "$dir" && [ ! -f "$dir/4_verify.md" ]; then
    missing+=("4_verify.md")
  fi

  # Knowledge-base coverage gate: once memory exists, the compiled knowledge/ must be current too
  # (kb-ingest.sh is driven by /monorepo-harness-build; task-state.sh check-kb validates the result).
  if [ -f "$dir/3_memory.md" ] && [ -f "$TASK_STATE" ]; then
    if ! bash "$TASK_STATE" check-kb "$dir" >/dev/null 2>&1; then
      missing+=("knowledge-base coverage (check-kb)")
    fi
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "agent-workflow gate: $rel is missing: ${missing[*]}" >&2
    echo "Write the missing artifact(s) following the agent-workflow skill templates, then retry." >&2
    exit 1
  fi
done

exit 0
