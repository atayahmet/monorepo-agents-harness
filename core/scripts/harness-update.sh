#!/usr/bin/env bash
#
# harness-update.sh - versioning engine for the agent harness.
#
# Compares the INSTALLED harness copy against the UPSTREAM repo and upgrades the
# agent-neutral core in place from a local new-bundle directory.
#
# Usage:
#   harness-update.sh current                    print the installed harness version
#   harness-update.sh latest   [--json]          resolve the newest upstream tag (network)
#   harness-update.sh check    [--json]          compare installed vs latest (exit 0/1/2)
#   harness-update.sh upgrade --source <dir>     refresh core from a downloaded new bundle
#
# Exit codes (check/latest): 0 = up-to-date/resolved, 1 = update available,
# 2 = unknown/unreachable. Dependencies: git + coreutils only. Fails open.
#
# Knobs (env):
#   HARNESS_UPSTREAM   upstream git URL      default below
#   BUNDLE_DIR         installed bundle dir  default <repo-root>/turborepo-harness-template
set -u

DEFAULT_UPSTREAM="https://github.com/atayahmet/turborepo-agent-harness"
UPSTREAM="${HARNESS_UPSTREAM:-$DEFAULT_UPSTREAM}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/turborepo-harness-template}"
VERSION_FILE="$BUNDLE_DIR/core/VERSION"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit_json() {
  printf '{"installed":"%s","latest":"%s","status":"%s","upstream":"%s"}\n' \
    "$(json_escape "$2")" "$(json_escape "$3")" "$1" "$(json_escape "$UPSTREAM")"
}

installed_version() {
  if [ -f "$VERSION_FILE" ]; then tr -d '[:space:]' <"$VERSION_FILE"; else echo ""; fi
}

semver_is_older() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

cmd_current() {
  local cur; cur="$(installed_version)"
  if [ -n "$cur" ]; then echo "$cur"; return 0; fi
  echo "harness-update: no core/VERSION found under $BUNDLE_DIR (pre-versioning install)" >&2
  return 2
}

cmd_latest() {
  local json="${1:-}" tags latest
  tags="$(git ls-remote --tags "$UPSTREAM" 2>/dev/null \
    | awk -F'/' '/refs\/tags\//{print $NF}' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
  latest="$(printf '%s\n' "$tags" | grep -v '^$' | sort -V | tail -n1)"
  if [ -z "$latest" ]; then
    if [ "$json" = "--json" ]; then emit_json "unknown" "$(installed_version)" ""
    else echo "harness-update: could not resolve the latest version from $UPSTREAM" >&2; fi
    return 2
  fi
  if [ "$json" = "--json" ]; then emit_json "resolved" "" "${latest#v}"
  else echo "${latest#v}"; fi
  return 0
}

cmd_check() {
  local json="${1:-}" cur latest code=0
  cur="$(installed_version)"
  latest="$(cmd_latest 2>/dev/null)" || code=$?
  if [ "$code" -ne 0 ] || [ -z "$latest" ]; then
    [ "$json" = "--json" ] && emit_json "unknown" "$cur" ""
    return 2
  fi
  if [ -z "$cur" ]; then
    if [ "$json" = "--json" ]; then emit_json "outdated" "" "$latest"
    else echo "harness-update: no core/VERSION (pre-versioning install) - latest is $latest" >&2; fi
    return 1
  fi
  if [ "$cur" = "$latest" ]; then
    [ "$json" = "--json" ] && emit_json "current" "$cur" "$latest" \
      || echo "harness-update: up to date ($cur)"
    return 0
  fi
  if semver_is_older "$cur" "$latest"; then
    if [ "$json" = "--json" ]; then emit_json "outdated" "$cur" "$latest"
    else echo "harness-update: installed $cur -> available $latest (see CHANGELOG.md Upgrade Notes)" >&2; fi
    return 1
  fi
  [ "$json" = "--json" ] && emit_json "current" "$cur" "$latest" \
    || echo "harness-update: installed $cur is newer than upstream ($latest) - nothing to do"
  return 0
}

cmd_upgrade() {
  local src="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --source) src="${2:-}"; shift 2 ;;
      --force) force="1"; shift ;;
      *) echo "usage: harness-update.sh upgrade --source <new-bundle-dir> [--force]" >&2; return 2 ;;
    esac
  done
  [ -n "$src" ] || { echo "error: --source <new-bundle-dir> is required" >&2; return 2; }
  [ -d "$src" ] || { echo "error: source bundle not found: $src" >&2; return 2; }

  local dst="$BUNDLE_DIR" sver dver item
  sver="$(tr -d '[:space:]' <"$src/core/VERSION" 2>/dev/null || true)"
  [ -n "$sver" ] || { echo "error: source bundle has no core/VERSION - not a harness bundle?" >&2; return 2; }
  dver="$(installed_version)"

  if [ -z "$force" ] && [ -n "$dver" ] && ! semver_is_older "$dver" "$sver"; then
    echo "error: installed version ($dver) is not older than source ($sver). Use --force." >&2
    return 1
  fi

  # Refresh ONLY the agent-neutral machinery: verbatim copies targets never edit.
  for item in scripts skills governance workspace-agents-template; do
    [ -d "$src/core/$item" ] || { echo "error: source missing core/$item" >&2; return 2; }
    rm -rf "$dst/core/$item"
    cp -R "$src/core/$item" "$dst/core/$item"
    echo "  refreshed core/$item"
  done
  cp "$src/core/VERSION" "$VERSION_FILE"
  echo "  refreshed core/VERSION ($dver -> $sver)"
  if [ -f "$src/CHANGELOG.md" ]; then
    cp "$src/CHANGELOG.md" "$dst/CHANGELOG.md"
    echo "  refreshed CHANGELOG.md"
  fi

  # Re-seed per-workspace state (idempotent: existing files are never overwritten).
  bash "$dst/core/scripts/scaffold-workspace-agents.sh"

  cat >&2 <<EOF

Upgrade applied: $sver. Follow-ups (NOT touched by this command):
- AGENTS.md (repo root): merge rows you want from the template; your resolved copy is user-owned.
- Adapter configs: re-apply hook/config merges per your adapter README (settings.json / plugin).
- Read CHANGELOG.md "Upgrade Notes" for behavior changes in this release.
EOF
  return 0
}

case "${1:-}" in
  current) shift; cmd_current "$@" ;;
  latest) shift; cmd_latest "$@" ;;
  check) shift; cmd_check "$@" ;;
  upgrade) shift; cmd_upgrade "$@" ;;
  *) sed -n '3,13p' "$0"; exit 2 ;;
esac
