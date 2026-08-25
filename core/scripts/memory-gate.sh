#!/usr/bin/env bash
# Memory-gate — the HARD enforcement of the plan/spec/memory workflow. Agent-agnostic.
#
# Task artifact convention: <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/ where
# <workspace> is any apps/* or packages/* directory.
#
# Two modes:
#   default (git pre-commit / CI):  exit 1 when today's latest task dir is missing 2_spec.md
#                                   or 3_memory.md. Works with ANY agent — or none.
#   --json (Claude Code Stop hook): print a {"decision":"block",...} JSON object when
#                                   3_memory.md is missing; silent exit 0 otherwise.
#
# Depends only on git + coreutils; --json mode additionally needs jq (fail-open without it).
# This is the universal replacement for agent-specific stop-hooks on agents that cannot block
# their own stop — wire the default mode as a git pre-commit hook and/or CI step.
#
#   git pre-commit:  ln -s ../../turborepo-agent-harness/core/scripts/memory-gate.sh .git/hooks/pre-commit
#   CI:              bash turborepo-agent-harness/core/scripts/memory-gate.sh
#   Claude Stop hook: see adapters/claude-code/.claude/settings.json

set -euo pipefail

JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TODAY="$(date +%Y_%m_%d)"

# Newest task dir created today across all workspaces (apps and packages).
LATEST="$(ls -td "$ROOT"/apps/*/.agents/artifacts/task_${TODAY}_* \
               "$ROOT"/packages/*/.agents/artifacts/task_${TODAY}_* 2>/dev/null | head -1 || true)"
[ -z "$LATEST" ] && exit 0   # no task started today → nothing to enforce
rel="${LATEST#"$ROOT"/}"

if [ "$JSON_MODE" -eq 1 ]; then
  # Stop-hook mode: only the memory file gates the stop (spec may legitimately be absent
  # for research-only plans — see the skill's edge cases).
  [ -f "$LATEST/3_memory.md" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0   # fail-open without jq
  jq -n --arg dir "$rel" '{"decision":"block","reason":("agent-workflow: Task is ending but " + $dir + "/3_memory.md is missing. Write it following the agent-workflow skill template, then you may stop.")}'
  exit 0
fi

missing=()
[ -f "$LATEST/2_spec.md" ]   || missing+=("2_spec.md")
[ -f "$LATEST/3_memory.md" ] || missing+=("3_memory.md")

if [ "${#missing[@]}" -gt 0 ]; then
  echo "agent-workflow gate: $rel is missing: ${missing[*]}" >&2
  echo "Write the missing artifact(s) following the agent-workflow skill templates, then retry." >&2
  exit 1
fi

exit 0
