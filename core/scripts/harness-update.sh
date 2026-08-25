#!/usr/bin/env bash
#
# harness-update.sh - lightweight version engine for the agent harness.
#
# Performs only structural version checks. The actual upgrade is driven by the
# active agent reading the changelog prompts under changelogs/version-X.Y.Z.md.
#
# Usage:
#   harness-update.sh current                    print the installed harness version
#   harness-update.sh latest   [--json]          resolve the newest upstream tag (network)
#   harness-update.sh check    [--json]          compare installed vs latest (exit 0/1/2)
#
# Exit codes (check/latest): 0 = up-to-date/resolved, 1 = update available,
# 2 = unknown/unreachable. Dependencies: git + coreutils only. Fails open.
#
# Knobs (env):
#   HARNESS_UPSTREAM   upstream git URL      default below
#   BUNDLE_DIR         installed bundle dir  default <repo-root>/.agents/monorepo-agents-harness
set -u

DEFAULT_UPSTREAM="https://github.com/atayahmet/monorepo-agents-harness"
UPSTREAM="${HARNESS_UPSTREAM:-$DEFAULT_UPSTREAM}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/.agents/monorepo-agents-harness}"
RUNTIME_DIR="${RUNTIME_DIR:-$BUNDLE_DIR}"
VERSION_FILE="$RUNTIME_DIR/VERSION"
# Fallback to the legacy locations for pre-0.4.1 installs during migration.
LEGACY_VERSION_FILE="$BUNDLE_DIR/core/VERSION"
LEGACY_ROOT_BUNDLE_FILE="$ROOT/monorepo-agents-harness/core/VERSION"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit_json() {
  printf '{"installed":"%s","latest":"%s","status":"%s","upstream":"%s"}\n' \
    "$(json_escape "$2")" "$(json_escape "$3")" "$1" "$(json_escape "$UPSTREAM")"
}

installed_version() {
  if [ -f "$VERSION_FILE" ]; then tr -d '[:space:]' <"$VERSION_FILE"; return 0; fi
  if [ -f "$LEGACY_VERSION_FILE" ]; then tr -d '[:space:]' <"$LEGACY_VERSION_FILE"; return 0; fi
  if [ -f "$LEGACY_ROOT_BUNDLE_FILE" ]; then tr -d '[:space:]' <"$LEGACY_ROOT_BUNDLE_FILE"; return 0; fi
  echo ""
}

semver_is_older() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

cmd_current() {
  local cur; cur="$(installed_version)"
  if [ -n "$cur" ]; then echo "$cur"; return 0; fi
  echo "harness-update: no VERSION found under $RUNTIME_DIR (pre-versioning install)" >&2
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
    else echo "harness-update: no VERSION under $RUNTIME_DIR (pre-versioning install) - latest is $latest" >&2; fi
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

case "${1:-}" in
  current) shift; cmd_current "$@" ;;
  latest) shift; cmd_latest "$@" ;;
  check) shift; cmd_check "$@" ;;
  *) sed -n '3,12p' "$0"; exit 2 ;;
esac
