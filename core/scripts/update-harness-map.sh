#!/usr/bin/env bash
#
# update-harness-map.sh - deterministic updater for .agents/.harness-map.json
#
# Every component produced by the self-improvement workflow (rule, skill, agent, command) is
# recorded in the consumer project's <repo-root>/.agents/.harness-map.json. This script is the
# single way the map should be mutated; hand-edits are discouraged because they risk duplicates or
# invalid JSON.
#
# Usage (run from the target repo root):
#   bash .agents/monorepo-agents-harness/core/scripts/update-harness-map.sh add \
#     --name <kebab-case-name> \
#     --type <rule|skill|agent|command> \
#     --path <repo-root-relative-path> \
#     [--description <text>] \
#     [--source <path-to-memory-or-lesson>]
#
# Behavior:
#   - Creates .agents/.harness-map.json with an empty schema if it does not exist.
#   - Uses name + type as the unique key.
#   - Updates an existing entry (preserving createdAt) rather than duplicating.
#   - Refreshes updatedAt and lastUpdated on every call.
#   - Backs up corrupt JSON to .harness-map.json.broken.<timestamp> and starts fresh.
#
# Exit codes: 0 = ok, 1 = runtime error, 2 = usage error.
# Dependency: jq.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MAP_FILE="$ROOT/.agents/.harness-map.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "update-harness-map: jq is required to maintain .agents/.harness-map.json" >&2
  exit 1
fi

# --- Parse arguments -----------------------------------------------------------
NAME=""
TYPE=""
PATH_VAL=""
DESCRIPTION=""
SOURCE=""

[ $# -eq 0 ] && { echo "update-harness-map: no command given" >&2; exit 2; }

case "${1:-}" in
  add|--add) shift ;;
  -h|--help) sed -n '3,23p' "$0"; exit 0 ;;
  *) echo "update-harness-map: unknown command: $1" >&2; exit 2 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --name)        NAME="${2:-}"; shift 2 ;;
    --type)        TYPE="${2:-}"; shift 2 ;;
    --path)        PATH_VAL="${2:-}"; shift 2 ;;
    --description) DESCRIPTION="${2:-}"; shift 2 ;;
    --source)      SOURCE="${2:-}"; shift 2 ;;
    *) echo "update-harness-map: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$NAME" ] || { echo "update-harness-map: --name is required" >&2; exit 2; }
[ -n "$TYPE" ] || { echo "update-harness-map: --type is required" >&2; exit 2; }
[ -n "$PATH_VAL" ] || { echo "update-harness-map: --path is required" >&2; exit 2; }

case "$TYPE" in
  rule|skill|agent|command) ;;
  *) echo "update-harness-map: invalid type '$TYPE' (expected rule, skill, agent, command)" >&2; exit 2 ;;
esac

# --- Read or initialize the map ------------------------------------------------
mkdir -p "$(dirname "$MAP_FILE")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -f "$MAP_FILE" ]; then
  if ! jq empty "$MAP_FILE" 2>/dev/null; then
    BACKUP="$MAP_FILE.broken.$(date -u +%Y%m%d%H%M%S)"
    mv "$MAP_FILE" "$BACKUP"
    echo "update-harness-map: existing map was invalid JSON; moved to $BACKUP" >&2
    MAP='{"version":"1","lastUpdated":"'"$NOW"'","components":[]}'
  else
    MAP="$(cat "$MAP_FILE")"
  fi
else
  MAP='{"version":"1","lastUpdated":"'"$NOW"'","components":[]}'
fi

# --- Build the new or merged component entry -----------------------------------
EXISTING_ENTRY="$(echo "$MAP" | jq --arg n "$NAME" --arg t "$TYPE" '[.components[] | select(.name == $n and .type == $t)] | first // empty')"

if [ -n "$EXISTING_ENTRY" ] && [ "$EXISTING_ENTRY" != "null" ]; then
  CREATED_AT="$(echo "$EXISTING_ENTRY" | jq -r '.createdAt // ""')"
  [ -n "$CREATED_AT" ] || CREATED_AT="$NOW"

  NEW_ENTRY="$(echo "$EXISTING_ENTRY" | jq \
    --arg name "$NAME" \
    --arg type "$TYPE" \
    --arg path "$PATH_VAL" \
    --arg description "$DESCRIPTION" \
    --arg source "$SOURCE" \
    --arg createdAt "$CREATED_AT" \
    --arg updatedAt "$NOW" \
    '{
      name: $name,
      type: $type,
      path: (if $path != "" then $path else .path end),
      description: (if $description != "" then $description else .description end),
      source: (if $source != "" then $source else .source end),
      createdAt: (if $createdAt != "" then $createdAt else .createdAt end),
      updatedAt: $updatedAt
    } | with_entries(select(.value != null and .value != ""))'
  )"
  ACTION="updated"
else
  NEW_ENTRY="$(jq -n \
    --arg name "$NAME" \
    --arg type "$TYPE" \
    --arg path "$PATH_VAL" \
    --arg description "$DESCRIPTION" \
    --arg source "$SOURCE" \
    --arg createdAt "$NOW" \
    --arg updatedAt "$NOW" \
    '{
      name: $name,
      type: $type,
      path: $path,
      description: $description,
      source: $source,
      createdAt: $createdAt,
      updatedAt: $updatedAt
    } | with_entries(select(.value != null and .value != ""))'
  )"
  ACTION="added"
fi

# --- Write the updated map atomically -----------------------------------------
UPDATED_MAP="$(echo "$MAP" | jq \
  --argjson entry "$NEW_ENTRY" \
  --arg n "$NAME" \
  --arg t "$TYPE" \
  --arg now "$NOW" \
  '{
    version: (.version // "1"),
    lastUpdated: $now,
    components: ([.components[] | select(.name != $n or .type != $t)] + [$entry])
  }'
)"

TMP_MAP="$MAP_FILE.tmp.$$"
echo "$UPDATED_MAP" | jq . > "$TMP_MAP"
mv "$TMP_MAP" "$MAP_FILE"

echo "update-harness-map: $ACTION $TYPE '$NAME' -> $MAP_FILE"
