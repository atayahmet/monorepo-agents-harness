#!/usr/bin/env bash
# Scaffold the repo-root knowledge base from the harness's KB template.
#
# Seeds <repo-root>/knowledge/ from core/knowledge-template/ so every consumer starts with the same
# compiled knowledge layer (Karpathy "LLM Wiki": index.md, log.md, overview.md, schema.md + the
# sources/concepts/modules/decision-records/verified-facts subdirectories). Existing files are NEVER
# overwritten; the scaffold only creates what is absent. The KB is consumer content — agents maintain
# it thereafter; the scaffold does not re-seed on updates.
#
#   bash .agents/monorepo-agents-harness/core/scripts/scaffold-knowledge.sh
#   TEMPLATE_DIR=<dir> bash .../scaffold-knowledge.sh
#
# Exit 0 on success (nothing to do, or seeded), 1 if the template dir is missing.
# --sync-only mode: intentionally not invoked (SKILL decides this at the harness-update level).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/.agents/monorepo-agents-harness}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$RUNTIME_DIR/core/knowledge-template}"
if [ ! -d "$TEMPLATE_DIR" ]; then
  BUNDLE_DIR="${BUNDLE_DIR:-$RUNTIME_DIR}"
  TEMPLATE_DIR="$BUNDLE_DIR/core/knowledge-template"
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "scaffold-knowledge: template dir not found: $TEMPLATE_DIR" >&2
  exit 1
fi

DEST="$ROOT/knowledge"
created=0
skipped=0

# Copy every file under the KB template that does not yet exist in <repo-root>/knowledge/. A file in
# the consumer's knowledge/ is authoritative: never overwrite, re-seed only what the consumer deleted.
# The seed's README.md files are directional stubs — re-seed those too when absent (they are part of
# the skeleton, not project content).
while IFS= read -r src; do
  [ -f "$src" ] || continue
  rel="${src#"$TEMPLATE_DIR"/}"
  if [ ! -e "$DEST/$rel" ]; then
    mkdir -p "$(dirname "$DEST/$rel")"
    cp "$src" "$DEST/$rel"
    created=$((created + 1))
    echo "  + knowledge/$rel"
  else
    skipped=$((skipped + 1))
  fi
done < <(find "$TEMPLATE_DIR" -type f -name '*.md' | sort)

echo "scaffolded $created knowledge file(s) under knowledge/ (($skipped) already present, untouched)."