#!/usr/bin/env bash
# Detect the monorepo framework used by the target repo and list its workspaces.
#
# Usage (from the target repo root):
#   detect-monorepo-framework.sh [--framework] [--workspaces]
#
# Output:
#   --framework   prints one of: turborepo, nx, lerna, pnpm, yarn, npm, unknown
#   --workspaces  prints discovered workspace directory globs/paths, one per line
#   default       prints "framework: <name>" and "workspaces: <path> ..." lines
#
# Detection order (most specific first):
#   turbo.json              -> turborepo
#   nx.json                 -> nx
#   lerna.json              -> lerna
#   pnpm-workspace.yaml     -> pnpm
#   package.json workspaces -> yarn or npm (resolved by packageManager / lockfile)

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

print_framework=0
print_workspaces=0
for arg in "$@"; do
  case "$arg" in
    --framework) print_framework=1 ;;
    --workspaces) print_workspaces=1 ;;
  esac
done

framework="unknown"
workspaces=()

if [ -f "$ROOT/turbo.json" ]; then
  framework="turborepo"
  workspaces=("$ROOT/apps/*" "$ROOT/packages/*")

elif [ -f "$ROOT/nx.json" ]; then
  framework="nx"
  workspaces=("$ROOT/apps/*" "$ROOT/libs/*" "$ROOT/packages/*")

elif [ -f "$ROOT/lerna.json" ]; then
  framework="lerna"
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r w; do
      [ -n "$w" ] && workspaces+=("$ROOT/${w%/}")
    done < <(jq -r '.packages[]? // empty' "$ROOT/lerna.json" 2>/dev/null || true)
  fi
  # Default fallback if jq is missing or lerna.json has no packages array.
  [ "${#workspaces[@]}" -eq 0 ] && workspaces=("$ROOT/packages/*")

elif [ -f "$ROOT/pnpm-workspace.yaml" ]; then
  framework="pnpm"
  if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r w; do
      [ -n "$w" ] && workspaces+=("$ROOT/${w%/}")
    done < <(python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); print('\n'.join(d.get('packages',[])))" "$ROOT/pnpm-workspace.yaml" 2>/dev/null || true)
  fi
  [ "${#workspaces[@]}" -eq 0 ] && workspaces=("$ROOT/apps/*" "$ROOT/packages/*")

elif [ -f "$ROOT/package.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r w; do
      [ -n "$w" ] && workspaces+=("$ROOT/${w%/}")
    done < <(jq -r '.workspaces[]? // empty' "$ROOT/package.json" 2>/dev/null || true)
  fi

  if [ "${#workspaces[@]}" -gt 0 ]; then
    package_manager=""
    if command -v jq >/dev/null 2>&1; then
      package_manager="$(jq -r '.packageManager // empty' "$ROOT/package.json" 2>/dev/null || true)"
    fi

    if [ -z "$package_manager" ]; then
      [ -f "$ROOT/yarn.lock" ] && package_manager="yarn"
      [ -f "$ROOT/package-lock.json" ] && package_manager="npm"
    fi

    case "$package_manager" in
      yarn*) framework="yarn" ;;
      *)     framework="npm" ;;
    esac
  fi
fi

if [ "$print_framework" -eq 1 ]; then
  echo "$framework"
  exit 0
fi

if [ "$print_workspaces" -eq 1 ]; then
  # Safe iteration even when the array is empty under `set -u`.
  for w in ${workspaces[@]+"${workspaces[@]}"}; do
    # Strip the trailing wildcard/glob segment so callers get parent dirs.
    printf '%s\n' "${w%/*}"
  done
  exit 0
fi

echo "framework: $framework"
if [ "${#workspaces[@]}" -gt 0 ]; then
  echo "workspaces: ${workspaces[*]}"
else
  echo "workspaces:"
fi
