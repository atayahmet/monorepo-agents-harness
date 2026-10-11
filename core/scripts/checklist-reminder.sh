#!/usr/bin/env bash
# checklist-reminder — print the "Before You Start — Mandatory Checklist" the agent must apply,
# read live from the installed root AGENTS.md. Agent-agnostic.
#
# The checklist has one source of truth: the `## Before You Start — Mandatory Checklist` section of
# the root AGENTS.md. This script extracts it at run time, so a hook that reminds the agent can never
# drift from it — the failure mode issue #29 is about, where a hand-copied list in
# `.claude/settings.json` silently dropped the workspace and knowledge-base items.
#
# Two callers:
#
#   # 1. Claude Code PostToolUse[ExitPlanMode] reminder hook (JSON for the hook API):
#   bash .agents/monorepo-agents-harness/core/scripts/checklist-reminder.sh
#
#   # 2. The -spec stage stub, at the start of a task (plain markdown):
#   bash .agents/monorepo-agents-harness/core/scripts/checklist-reminder.sh --text
#
# Usage:
#   checklist-reminder.sh [--event claude-posttool] [--text] [--file <path>]
#
#   --event claude-posttool  emit Claude Code hook JSON (default)
#   --text                   emit the checklist section as plain markdown
#   --file <path>            read this file instead of <repo-root>/AGENTS.md (for tests)
#
# Fail-open by design: a missing AGENTS.md, a missing section, or a missing `jq` in JSON mode prints
# nothing and exits 0. A hook that cannot answer must never stand between an agent and its work.
# Exit codes: 0 = ok or nothing to say, 2 = usage error.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENTS_MD="$ROOT/AGENTS.md"
EVENT="claude-posttool"
TEXT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --event) EVENT="${2:-}"; shift 2 ;;
    --text)  TEXT=1; shift ;;
    --file)  AGENTS_MD="${2:-}"; shift 2 ;;
    -h|--help) sed -n '3,26p' "$0"; exit 0 ;;
    *) echo "checklist-reminder: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Extract from the section heading up to (but not including) the next `## ` heading. `### `
# sub-headings do not terminate it. Command substitution drops the trailing blank line(s).
section() {
  awk '
    /^## / {
      if (in_section) exit
      if ($0 ~ /^## Before You Start/) in_section = 1
    }
    in_section { print }
  ' "$1"
}

[ -f "$AGENTS_MD" ] || exit 0
body="$(section "$AGENTS_MD" || true)"
[ -n "$body" ] || exit 0

if [ "$TEXT" -eq 1 ]; then
  printf '%s\n' "$body"
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0

context="<system-reminder>
$body
</system-reminder>"

case "$EVENT" in
  claude-posttool)
    jq -n --arg ctx "$context" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
    ;;
  *)
    echo "checklist-reminder: unknown event: $EVENT" >&2
    exit 2
    ;;
esac

exit 0
