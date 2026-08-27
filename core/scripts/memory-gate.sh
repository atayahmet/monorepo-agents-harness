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
# Two modes:
#   default (git pre-commit / CI):  exit 1 when today's latest task dir is missing its spec
#                                   (1_spec.md, or legacy 2_spec.md), 3_memory.md, or (when
#                                   required) 4_verify.md. Works with ANY agent — or none.
#   --json (Claude Code Stop hook): print a {"decision":"block",...} JSON object when
#                                   3_memory.md or (when required) 4_verify.md is missing;
#                                   silent exit 0 otherwise.
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
  scan_patterns+=("$parent"/*/.agents/artifacts/task_${TODAY}_*)
done

# Newest task dir created today across all discovered workspaces.
LATEST=""
if [ "${#scan_patterns[@]}" -gt 0 ]; then
  LATEST="$(ls -td "${scan_patterns[@]}" 2>/dev/null | head -1 || true)"
fi
[ -z "$LATEST" ] && exit 0   # no task started today → nothing to enforce
rel="${LATEST#"$ROOT"/}"

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

if [ "$JSON_MODE" -eq 1 ]; then
  # Stop-hook mode: gates on 3_memory.md always, and on 4_verify.md whenever required (spec may
  # legitimately be absent for research-only plans — see the skill's edge cases).
  json_missing=()
  [ -f "$LATEST/3_memory.md" ] || json_missing+=("3_memory.md")
  if verify_required "$LATEST" && [ ! -f "$LATEST/4_verify.md" ]; then
    json_missing+=("4_verify.md")
  fi
  [ "${#json_missing[@]}" -eq 0 ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0   # fail-open without jq
  jq -n --arg dir "$rel" --arg files "${json_missing[*]}" '{"decision":"block","reason":("agent-workflow: Task is ending but " + $dir + " is missing: " + $files + ". Write the missing artifact(s) following the agent-workflow skill templates, then you may stop.")}'
  exit 0
fi

missing=()
MISSING_SPEC="$(basename "$(resolve_spec "$LATEST")")"
[ -f "$(resolve_spec "$LATEST")" ] || missing+=("$MISSING_SPEC")
[ -f "$LATEST/3_memory.md" ] || missing+=("3_memory.md")
if verify_required "$LATEST" && [ ! -f "$LATEST/4_verify.md" ]; then
  missing+=("4_verify.md")
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "agent-workflow gate: $rel is missing: ${missing[*]}" >&2
  echo "Write the missing artifact(s) following the agent-workflow skill templates, then retry." >&2
  exit 1
fi

exit 0
