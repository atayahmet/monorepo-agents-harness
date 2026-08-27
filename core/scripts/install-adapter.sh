#!/usr/bin/env bash
#
# install-adapter.sh - Phase 2 (per-agent) install of the agent harness, deterministically.
#
# Executes adapters/<agent>/manifest.txt instead of asking an agent to interpret prose copy,
# symlink and jq-merge steps. Idempotent: safe to re-run.
#
# Usage (run from the TARGET repo root, after install-harness.sh):
#   bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code
#
#   install-adapter.sh <claude-code|codex|opencode> [--refresh] [--project-name <name>]
#
#   --refresh           run only the copy/link rows; never touch config files (merge/tmpl rows).
#                       This is the mode a harness UPDATE uses: re-running a config merge would
#                       duplicate hook entries, re-running a copy/symlink cannot.
#   --project-name <n>  value for {{PROJECT_NAME}} (default: package.json .name, else repo dir name)
#
# An existing config file is NEVER modified: the adapter's version is written next to it as
# <file>.harness-proposed and reported, so you (or your agent) merge it deliberately.
#
# Exit codes: 0 = every copy/link row satisfied, 1 = at least one did not land, 2 = usage error.
# Dependencies: git + coreutils.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/harness-common.sh"

BUNDLE="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
AGENT=""
REFRESH=0
PROJECT_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --refresh)      REFRESH=1; shift ;;
    --project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    -h|--help)      sed -n '3,21p' "$0"; exit 0 ;;
    -*) echo "install-adapter: unknown argument: $1" >&2; exit 2 ;;
    *)  [ -z "$AGENT" ] || { echo "install-adapter: only one agent per run" >&2; exit 2; }
        AGENT="$1"; shift ;;
  esac
done

ROOT="$(harness_root)"
ADAPTER="$BUNDLE/adapters/$AGENT"
MANIFEST="$ADAPTER/manifest.txt"

if [ -z "$AGENT" ]; then
  echo "install-adapter: which agent? one of: $(ls "$BUNDLE/adapters" 2>/dev/null | tr '\n' ' ')" >&2
  exit 2
fi
[ -f "$BUNDLE/VERSION" ] || { echo "install-adapter: core not installed — run install-harness.sh first" >&2; exit 2; }
[ -f "$MANIFEST" ] || { echo "install-adapter: no manifest for '$AGENT' at $MANIFEST" >&2; exit 2; }

TRASH=""
followups=()
problems=0
applied=0

ensure_trash() { [ -n "$TRASH" ] || TRASH="$(harness_trash_dir "$ROOT")"; }
note() { followups+=("$1"); }
fail() { echo "install-adapter: $1" >&2; problems=$((problems + 1)); }

# ../-prefix that walks from <project-path>'s own directory back to the repo root.
rel_prefix() {
  local dir; dir="$(dirname "$1")"
  [ "$dir" = "." ] && return 0
  printf '%s' "$dir" | awk -F/ '{for (i = 1; i <= NF; i++) printf "../"}'
}

[ -f "$ADAPTER/package.json" ] && \
  note "This adapter ships a package.json — run 'npm install' in ${ADAPTER#"$ROOT"/} before first use."

while read -r verb path target; do
  [ -n "${verb:-}" ] || continue
  case "$verb" in
    copy)
      src="$ADAPTER/$path"
      if [ ! -f "$src" ]; then fail "manifest row missing from the adapter: $path"; continue; fi
      if [ -f "$ROOT/$path" ] && cmp -s "$src" "$ROOT/$path"; then
        echo "  = $path"
      else
        mkdir -p "$(dirname "$ROOT/$path")"
        cp "$src" "$ROOT/$path" && { echo "  + $path"; applied=$((applied + 1)); } \
          || fail "could not copy: $path"
      fi
      ;;
    link)
      if [ -z "${target:-}" ]; then fail "link row without a bundle path: $path"; continue; fi
      if [ ! -e "$BUNDLE/$target" ]; then fail "link target missing from the bundle: $target"; continue; fi
      link_to="$(rel_prefix "$path").agents/monorepo-agents-harness/$target"
      if [ -L "$ROOT/$path" ] && [ "$(readlink "$ROOT/$path")" = "$link_to" ] && [ -e "$ROOT/$path" ]; then
        echo "  = $path"
        continue
      fi
      if [ -e "$ROOT/$path" ] && [ ! -L "$ROOT/$path" ]; then
        ensure_trash
        mv "$ROOT/$path" "$TRASH/${path//\//_}" \
          || { fail "a real file/dir is in the way and could not be moved aside: $path"; continue; }
        note "A real path was in the way at $path — the previous copy is in the trash dir below."
      fi
      mkdir -p "$(dirname "$ROOT/$path")"
      ln -sfn "$link_to" "$ROOT/$path" || { fail "could not symlink: $path"; continue; }
      if [ -e "$ROOT/$path" ]; then echo "  + $path -> $link_to"; applied=$((applied + 1))
      else fail "symlink does not resolve: $path -> $link_to"; fi
      ;;
    merge|tmpl)
      [ "$REFRESH" -eq 1 ] && { echo "  . $path (config row, skipped in --refresh)"; continue; }
      src="$ADAPTER/$path"
      if [ ! -f "$src" ]; then fail "manifest row missing from the adapter: $path"; continue; fi
      if [ "$verb" = "tmpl" ]; then
        [ -n "$PROJECT_NAME" ] || PROJECT_NAME="$(harness_project_name "$ROOT")"
        [ -n "${FRAMEWORK:-}" ] || FRAMEWORK="$(harness_framework "$BUNDLE/core/scripts/detect-monorepo-framework.sh")"
        rendered="$(harness_resolve_placeholders "$src" "$PROJECT_NAME" "$FRAMEWORK")"
      else
        rendered="$(cat "$src")"
      fi
      mkdir -p "$(dirname "$ROOT/$path")"
      if [ ! -e "$ROOT/$path" ]; then
        printf '%s\n' "$rendered" >"$ROOT/$path" && { echo "  + $path"; applied=$((applied + 1)); } \
          || fail "could not write: $path"
      elif printf '%s\n' "$rendered" | cmp -s - "$ROOT/$path"; then
        echo "  = $path"
      else
        printf '%s\n' "$rendered" >"$ROOT/$path.harness-proposed" \
          && { echo "  ~ $path (left untouched; proposal written)"
               note "Merge $path yourself — review with: git diff --no-index $path $path.harness-proposed"; } \
          || fail "could not write the proposal for: $path"
      fi
      ;;
    *) fail "unknown manifest verb '$verb' in $MANIFEST" ;;
  esac
done < <(harness_manifest_rows "$MANIFEST")

if [ ! -e "$ROOT/.git/hooks/pre-commit" ]; then
  note "The universal hard gate is not wired: symlink core/scripts/memory-gate.sh as .git/hooks/pre-commit, or run it in CI."
fi

echo
if [ "$problems" -ne 0 ]; then
  echo "install-adapter: $AGENT INCOMPLETE — $problems problem(s) above" >&2
else
  echo "install-adapter: $AGENT ready ($applied file(s) written/updated)."
  echo "install-adapter: confirm with -> bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh"
fi
if [ "${#followups[@]}" -gt 0 ]; then
  echo
  echo "Needs you:"
  for f in "${followups[@]}"; do echo "  - $f"; done
fi
if [ -n "$TRASH" ]; then
  echo
  echo "Displaced copies were moved (never deleted) to ${TRASH#"$ROOT"/}"
fi

[ "$problems" -eq 0 ]
