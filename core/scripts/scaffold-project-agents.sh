#!/usr/bin/env bash
# Scaffold project-root agent rules from the harness's starter-rules template.
#
# Seeds <repo-root>/.agents/rules/*.md from core/project-rules-template/ so every consumer starts
# with the same baseline agent rules. Existing files are never overwritten.
#
#   bash .agents/monorepo-agents-harness/core/scripts/scaffold-project-agents.sh
#   TEMPLATE_DIR=<dir> bash .../scaffold-project-agents.sh
#
# Each newly created rule is registered in <repo-root>/.agents/.harness-map.json (via
# update-harness-map.sh) so /monorepo-self-improve inventories it instead of proposing a duplicate.
# Registration is best-effort: a missing jq only skips the map entry, never the file copy.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$RUNTIME_DIR/core/project-rules-template}"
if [ ! -d "$TEMPLATE_DIR" ]; then
  BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
  TEMPLATE_DIR="$BUNDLE_DIR/core/project-rules-template"
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "scaffold-project-agents: template dir not found: $TEMPLATE_DIR" >&2
  exit 1
fi

DEST="$ROOT/.agents/rules"
created=0

while IFS= read -r src; do
  [ -f "$src" ] || continue
  base="$(basename "$src")"
  case "$base" in
    *.md) ;;
    *) continue ;;
  esac
  if [ ! -e "$DEST/$base" ]; then
    mkdir -p "$DEST"
    cp "$src" "$DEST/$base"
    created=$((created + 1))
    echo "  + .agents/rules/$base"
    if command -v jq >/dev/null 2>&1; then
      bash "$RUNTIME_DIR/core/scripts/update-harness-map.sh" add \
        --name "${base%.md}" \
        --type rule \
        --path ".agents/rules/$base" \
        --description "Starter rule seeded by the monorepo-agents-harness installer" \
        --source "${RUNTIME_DIR#"$ROOT"/}/core/project-rules-template/$base" >/dev/null 2>&1 || true
    fi
  fi
done < <(find "$TEMPLATE_DIR" -maxdepth 1 -type f -name '*.md' | sort)

echo "scaffolded $created project rule(s) under .agents/rules/ ."