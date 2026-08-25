#!/usr/bin/env bash
# Scaffold per-workspace agent state.
#
# For every workspace (discovered via detect-monorepo-framework.sh), create:
#   .agents/{session-log,lessons,todo}.md   seeded from core/workspace-agents-template/
#   .agents/artifacts/index.md              task index, seeded from core/governance/artifacts/index-template.md
#   .agents/artifacts/AGENTS.md             rules pointer, seeded from core/governance/artifacts/workspace-AGENTS.md
#
# Existing files are never overwritten. Run once at install time, and re-run after adding a new
# workspace.
#
#   bash .agents/monorepo-agents-harness/scripts/scaffold-workspace-agents.sh   # from the target repo root
#   SEED=path/to/workspace-agents-template INDEX_TEMPLATE=path/to/index-template.md \
#   RULES_TEMPLATE=path/to/workspace-AGENTS.md bash .../scaffold-workspace-agents.sh
#
# The agent reads <target-workspace>/.agents/{session-log,lessons}.md BEFORE starting work, writes
# <target-workspace>/.agents/todo.md (see AGENTS.md "Before You Start" checklist), and creates its
# per-task plan/spec/memory dirs under <target-workspace>/.agents/artifacts/.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/monorepo-agents-harness}"
DETECT_SCRIPT="${DETECT_SCRIPT:-$RUNTIME_DIR/scripts/detect-monorepo-framework.sh}"
[ ! -x "$DETECT_SCRIPT" ] && DETECT_SCRIPT="$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh"

# Prefer the shared runtime directory (0.4.0+). Fall back to the bundle source
# during fresh installs before the runtime symlinks are created.
SEED="${SEED:-$RUNTIME_DIR/workspace-agents-template}"
if [ ! -d "$SEED" ]; then
  SEED="$BUNDLE_DIR/core/workspace-agents-template"
fi
INDEX_TEMPLATE="${INDEX_TEMPLATE:-$RUNTIME_DIR/governance/artifacts/index-template.md}"
if [ ! -f "$INDEX_TEMPLATE" ]; then
  INDEX_TEMPLATE="$BUNDLE_DIR/core/governance/artifacts/index-template.md"
fi
RULES_TEMPLATE="${RULES_TEMPLATE:-$RUNTIME_DIR/governance/artifacts/workspace-AGENTS.md}"
if [ ! -f "$RULES_TEMPLATE" ]; then
  RULES_TEMPLATE="$BUNDLE_DIR/core/governance/artifacts/workspace-AGENTS.md"
fi

if [ ! -d "$SEED" ]; then
  echo "seed dir not found: $SEED (set SEED=... to override)" >&2
  exit 1
fi

created=0

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

for parent in "${workspace_parents[@]}"; do
  [ -d "$parent" ] || continue
  for ws in "$parent"/*/; do
    [ -d "$ws" ] || continue
    dest="${ws%/}/.agents"
    mkdir -p "$dest"
  for f in session-log.md lessons.md todo.md; do
    if [ ! -e "$dest/$f" ]; then
      cp "$SEED/$f" "$dest/$f"
      created=$((created + 1))
      echo "  + ${dest#"$ROOT"/}/$f"
    fi
  done
  # Task-artifact tree: seed the workspace's task index and rules pointer.
  if [ ! -d "$dest/artifacts" ]; then
    mkdir -p "$dest/artifacts"
  fi
  for pair in "$INDEX_TEMPLATE:index.md" "$RULES_TEMPLATE:AGENTS.md"; do
    src="${pair%%:*}"
    out="${pair##*:}"
    if [ -f "$src" ] && [ ! -e "$dest/artifacts/$out" ]; then
      cp "$src" "$dest/artifacts/$out"
      created=$((created + 1))
      echo "  + ${dest#"$ROOT"/}/artifacts/$out"
    fi
  done
done
done

echo "scaffolded $created workspace-agents file(s)."
