#!/usr/bin/env bash
#
# harness-update.sh - lightweight version engine for the agent harness.
#
# Performs only structural version checks. The upgrade itself is performed by
# core/scripts/install-harness.sh --sync-only + install-adapter.sh --refresh, driven by the
# active agent following core/skills/harness-update/SKILL.md.
#
# Versions are compared with SemVer precedence (prereleases included, e.g. 0.1.0-rc.0 < 0.1.0)
# via harness-common.sh — never with sort -V, which gets prereleases backwards.
#
# Usage:
#   harness-update.sh current                    print the installed harness version
#   harness-update.sh latest   [--json]          resolve the newest upstream tag (network)
#   harness-update.sh check    [--json]          compare installed vs latest (exit 0/1/2)
#   harness-update.sh verify-copy <src> <dst>     confirm every file under <src> exists under <dst>
#   harness-update.sh changelog-range <from> <to> <changelog.md>
#                                                print the CHANGELOG.md section of every version in
#                                                from < V <= to, oldest first (read-only)
#
# Exit codes (check/latest): 0 = up-to-date/resolved, 1 = update available,
# 2 = unknown/unreachable. verify-copy: 0 = every file present, 1 = at least one missing (paths
# printed to stderr), 2 = usage error. changelog-range: 0 = done (also when upstream or the
# changelog is unreadable - it fails open), 2 = usage error. Dependencies: git + coreutils only.
# Fails open.
#
# Knobs (env):
#   HARNESS_UPSTREAM   upstream git URL      default below
#   BUNDLE_DIR         installed bundle dir  default <repo-root>/.agents/monorepo-agents-harness
set -u

DEFAULT_UPSTREAM="https://github.com/atayahmet/monorepo-agents-harness"
UPSTREAM="${HARNESS_UPSTREAM:-$DEFAULT_UPSTREAM}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/harness-common.sh"

ROOT="$(harness_root)"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/.agents/monorepo-agents-harness}"
RUNTIME_DIR="${RUNTIME_DIR:-$BUNDLE_DIR}"
VERSION_FILE="$RUNTIME_DIR/VERSION"

# Release tags, prerelease ones (v0.1.0-rc.0) included.
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit_json() {
  printf '{"installed":"%s","latest":"%s","status":"%s","upstream":"%s"}\n' \
    "$(json_escape "$2")" "$(json_escape "$3")" "$1" "$(json_escape "$UPSTREAM")"
}

installed_version() {
  if [ -f "$VERSION_FILE" ]; then tr -d '[:space:]' <"$VERSION_FILE"; return 0; fi
  echo ""
}

# Prerelease-aware; see harness-common.sh for why sort -V is not usable here.
semver_is_older() { harness_semver_is_older "$1" "$2"; }

cmd_current() {
  local cur; cur="$(installed_version)"
  if [ -n "$cur" ]; then echo "$cur"; return 0; fi
  echo "harness-update: no VERSION found under $RUNTIME_DIR (pre-versioning install)" >&2
  return 2
}

cmd_latest() {
  local json="${1:-}" tags latest="" tag
  tags="$(git ls-remote --tags "$UPSTREAM" 2>/dev/null \
    | awk -F'/' '/refs\/tags\//{print $NF}' \
    | sed 's/\^{}$//' \
    | grep -E "$TAG_RE" | sort -u || true)"
  # Pick the max by SemVer precedence — sort -V would rank a release below its own prereleases.
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    if [ -z "$latest" ] || [ "$(harness_semver_cmp "${tag#v}" "${latest#v}")" = "1" ]; then
      latest="$tag"
    fi
  done <<<"$tags"
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

cmd_verify_copy() {
  local src="${1:-}" dst="${2:-}" missing=0 rel
  if [ -z "$src" ] || [ -z "$dst" ] || [ ! -d "$src" ]; then
    echo "harness-update: verify-copy needs an existing <src> dir and a <dst> dir" >&2
    return 2
  fi
  while IFS= read -r rel; do
    if [ ! -e "$dst/$rel" ]; then
      echo "harness-update: missing after copy: $rel" >&2
      missing=1
    fi
  done < <(cd "$src" && find . -type f | sed 's#^\./##')
  if [ "$missing" -eq 1 ]; then
    echo "harness-update: verify-copy FAILED — $src -> $dst is incomplete" >&2
    return 1
  fi
  echo "harness-update: verify-copy OK — $src -> $dst"
  return 0
}

# changelog-range <from> <to> <changelog.md> - feeds the "What's new" summary at the end of
# /monorepo-harness-update (issue #81). The version set is the union of the changelog's
# `## [X.Y.Z]` headings and the upstream release tags, so a tag with no section is reported, not
# silently skipped. Only versions in from < V <= to are printed, oldest first, by SemVer precedence.
cmd_changelog_range() {
  if [ "$#" -ne 3 ]; then
    echo "harness-update: changelog-range needs <from> <to> <changelog.md>" >&2
    return 2
  fi
  local from="$1" to="$2" cl="$3" v tags all="" sorted=() i j
  local semver_re="${TAG_RE#^v}"; semver_re="^${semver_re}"
  if ! printf '%s' "$from" | grep -Eq "$semver_re" || ! printf '%s' "$to" | grep -Eq "$semver_re"; then
    echo "harness-update: changelog-range: <from> and <to> must be SemVer versions" >&2
    return 2
  fi
  if [ ! -f "$cl" ]; then
    echo "(CHANGELOG.md not found)"
    return 0
  fi
  if tags="$(git ls-remote --tags --refs "$UPSTREAM" 2>/dev/null)"; then
    tags="$(printf '%s\n' "$tags" | awk -F'/' '/refs\/tags\//{print $NF}' | grep -E "$TAG_RE" | sed 's/^v//')"
  else
    tags=""
    echo "harness-update: changelog-range: tag list unavailable from $UPSTREAM - listing CHANGELOG.md sections only" >&2
  fi
  all="$( { sed -n 's/^## \[\([^]]*\)\].*/\1/p' "$cl"; printf '%s\n' "$tags"; } \
    | grep -E "$semver_re" | sort -u || true)"
  # Keep from < v <= to, then insertion-sort by SemVer precedence (never sort -V).
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    [ "$(harness_semver_cmp "$v" "$from")" = "1" ] || continue
    [ "$(harness_semver_cmp "$v" "$to")" = "1" ] && continue
    i=${#sorted[@]}
    sorted+=("$v")
    while [ "$i" -gt 0 ] && [ "$(harness_semver_cmp "${sorted[$((i-1))]}" "$v")" = "1" ]; do
      sorted[$i]="${sorted[$((i-1))]}"; i=$((i-1))
    done
    sorted[$i]="$v"
  done <<<"$all"
  j=0
  for v in ${sorted[@]+"${sorted[@]}"}; do
    [ "$j" -gt 0 ] && echo
    j=$((j+1))
    if grep -Fq "## [$v]" "$cl"; then
      # The section: its heading up to the line before the next `## ` heading, trailing blanks dropped.
      awk -v h="## [$v]" '
        index($0, h) == 1 { on = 1; print; next }
        on && /^## / { exit }
        on { buf = buf $0 "\n"; if ($0 != "") { printf "%s", buf; buf = "" } }
      ' "$cl"
    else
      printf '## [%s]\n(no CHANGELOG.md section)\n' "$v"
    fi
  done
  return 0
}

case "${1:-}" in
  current) shift; cmd_current "$@" ;;
  latest) shift; cmd_latest "$@" ;;
  check) shift; cmd_check "$@" ;;
  verify-copy) shift; cmd_verify_copy "$@" ;;
  changelog-range) shift; cmd_changelog_range "$@" ;;
  *) sed -n '3,19p' "$0"; exit 2 ;;
esac
