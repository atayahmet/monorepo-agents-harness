#!/usr/bin/env bash
# Scaffold per-workspace agent state.
#
# For every workspace (discovered via detect-monorepo-framework.sh), create:
#   .agents/{session-log,lessons,todo}.md   seeded from core/workspace-agents-template/
#   .agents/artifacts/index.md              task index, seeded from core/governance/artifacts/index-template.md
#   .agents/artifacts/AGENTS.md             rules pointer, seeded from core/governance/artifacts/workspace-AGENTS.md
#   .agents/intents/AGENTS.md               rules pointer, seeded from core/governance/intents/workspace-AGENTS.md
#
# Existing files are never overwritten. Run once at install time, and re-run after adding a new
# workspace. Workspaces without their own AGENTS.md are named in a closing `next:` hint that points
# to /monorepo-harness-init (core/skills/agents-init/SKILL.md).
#
#   bash .agents/monorepo-agents-harness/core/scripts/scaffold-workspace-agents.sh   # from the target repo root
#   SEED=path/to/workspace-agents-template INDEX_TEMPLATE=path/to/index-template.md \
#   RULES_TEMPLATE=path/to/workspace-AGENTS.md INTENTS_RULES_TEMPLATE=path/to/intents/workspace-AGENTS.md \
#   bash .../scaffold-workspace-agents.sh
#
# The agent reads <target-workspace>/.agents/{session-log,lessons}.md BEFORE starting work, writes
# <target-workspace>/.agents/todo.md (see AGENTS.md "Before You Start" checklist), creates its
# per-task plan/spec/memory/verify dirs under <target-workspace>/.agents/artifacts/, and may draw on
# approved requests under <target-workspace>/.agents/intents/ (see core/governance/intents/AGENTS.md).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
DETECT_SCRIPT="${DETECT_SCRIPT:-$RUNTIME_DIR/core/scripts/detect-monorepo-framework.sh}"
[ -f "$DETECT_SCRIPT" ] || DETECT_SCRIPT="$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh"

# The bundle itself lives under .agents/monorepo-agents-harness/.
SEED="${SEED:-$RUNTIME_DIR/core/workspace-agents-template}"
if [ ! -d "$SEED" ]; then
  SEED="$BUNDLE_DIR/core/workspace-agents-template"
fi
INDEX_TEMPLATE="${INDEX_TEMPLATE:-$RUNTIME_DIR/core/governance/artifacts/index-template.md}"
if [ ! -f "$INDEX_TEMPLATE" ]; then
  INDEX_TEMPLATE="$BUNDLE_DIR/core/governance/artifacts/index-template.md"
fi
RULES_TEMPLATE="${RULES_TEMPLATE:-$RUNTIME_DIR/core/governance/artifacts/workspace-AGENTS.md}"
if [ ! -f "$RULES_TEMPLATE" ]; then
  RULES_TEMPLATE="$BUNDLE_DIR/core/governance/artifacts/workspace-AGENTS.md"
fi
INTENTS_RULES_TEMPLATE="${INTENTS_RULES_TEMPLATE:-$RUNTIME_DIR/core/governance/intents/workspace-AGENTS.md}"
if [ ! -f "$INTENTS_RULES_TEMPLATE" ]; then
  INTENTS_RULES_TEMPLATE="$BUNDLE_DIR/core/governance/intents/workspace-AGENTS.md"
fi

if [ ! -d "$SEED" ]; then
  echo "seed dir not found: $SEED (set SEED=... to override)" >&2
  exit 1
fi

created=0
undocumented=""

# The workspaces: the project's .agents/workspaces.txt, else the detected framework, else apps/* and
# packages/*. Warnings about the declaration file reach the user on stderr.
workspaces=()
while IFS= read -r ws; do
  [ -n "$ws" ] && workspaces+=("$ws")
done < <(bash "$DETECT_SCRIPT" --workspace-dirs || true)

for ws in ${workspaces[@]+"${workspaces[@]}"}; do
  dest="$ws/.agents"
  mkdir -p "$dest"
  [ -f "$ws/AGENTS.md" ] || undocumented="$undocumented $ws"
  for f in session-log.md lessons.md todo.md; do
    if [ ! -e "$dest/$f" ]; then
      cp "$SEED/$f" "$dest/$f"
      created=$((created + 1))
      echo "  + ${dest#"$ROOT"/}/$f"
    fi
  done
  # Task-artifact tree: seed the workspace's task index and rules pointer.
  mkdir -p "$dest/artifacts"
  for pair in "$INDEX_TEMPLATE:index.md" "$RULES_TEMPLATE:AGENTS.md"; do
    src="${pair%:*}"
    out="${pair##*:}"
    if [ -f "$src" ] && [ ! -e "$dest/artifacts/$out" ]; then
      cp "$src" "$dest/artifacts/$out"
      created=$((created + 1))
      echo "  + ${dest#"$ROOT"/}/artifacts/$out"
    fi
  done
  # Intent inbox: seed the workspace's rules pointer (no index — see core/governance/intents/AGENTS.md).
  mkdir -p "$dest/intents"
  if [ -f "$INTENTS_RULES_TEMPLATE" ] && [ ! -e "$dest/intents/AGENTS.md" ]; then
    cp "$INTENTS_RULES_TEMPLATE" "$dest/intents/AGENTS.md"
    created=$((created + 1))
    echo "  + ${dest#"$ROOT"/}/intents/AGENTS.md"
  fi
done

echo "scaffolded $created workspace-agents file(s)."
if [ "${#workspaces[@]}" -eq 0 ]; then
  echo "warning: no workspace found — list yours in .agents/workspaces.txt (one path or glob per line, e.g. crates/*, or . for a single-package repo) and re-run this script" >&2
fi
# One-line hint (issue #71): workspaces with no AGENTS.md of their own.
if [ -n "$undocumented" ]; then
  echo "next: no AGENTS.md in:${undocumented//"$ROOT"\//} — run /monorepo-harness-init <workspace> to build one"
fi
