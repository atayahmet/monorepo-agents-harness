#!/usr/bin/env bash
#
# harness-common.sh - shared helpers for the harness install/audit scripts.
#
# SOURCED, never executed:  . "$(dirname "${BASH_SOURCE[0]}")/harness-common.sh"
#
# Exists so install-harness.sh, install-adapter.sh and audit-install.sh cannot drift apart on
# manifest parsing, placeholder substitution, or the move-aside trash convention.
# Dependencies: git + coreutils (jq optional, only as a nicety for package.json).

# Repo root of the *target* project (falls back to CWD outside a git repo).
harness_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# Emit the meaningful rows of a manifest file: full-line comments and blank lines dropped.
harness_manifest_rows() {
  [ -f "$1" ] || return 1
  sed -e 's/^[[:space:]]*#.*$//' "$1" | awk 'NF'
}

# {{PROJECT_NAME}} default: root package.json's .name, else the repo directory name.
harness_project_name() {
  local root="$1" name=""
  if [ -f "$root/package.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      name="$(jq -r '.name // empty' "$root/package.json" 2>/dev/null)"
    fi
    if [ -z "$name" ]; then
      name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/package.json" | head -n1)"
    fi
  fi
  [ -z "$name" ] && name="$(basename "$root")"
  printf '%s\n' "$name"
}

# {{MONOREPO_FRAMEWORK}} default: whatever detect-monorepo-framework.sh reports.
harness_framework() {
  local detect="$1" fw=""
  [ -f "$detect" ] && fw="$(bash "$detect" --framework 2>/dev/null | tr -d '[:space:]')"
  [ -z "$fw" ] && fw="unknown"
  printf '%s\n' "$fw"
}

# Resolve template placeholders on stdout. Substitutes {{PROJECT_NAME}} and {{MONOREPO_FRAMEWORK}}
# ONLY — {{PROJECT_GOTCHAS}} / {{PROJECT_REVIEW_POLICY}} mark project-owned regions, not values.
# Must stay identical to core/skills/agents-md-merge/SKILL.md Step 2's THEIRS normalization, or a
# later AGENTS.md merge will diff against a file the install never could have produced.
harness_resolve_placeholders() {
  sed -e "s|{{PROJECT_NAME}}|$2|g" -e "s|{{MONOREPO_FRAMEWORK}}|$3|g" "$1"
}

# SemVer precedence, prerelease-aware. Echoes -1 (a<b), 0 (a==b) or 1 (a>b).
#
# `sort -V` is NOT usable here: it orders 1.0.0 before 1.0.0-rc.0, the opposite of SemVer §11
# ("a pre-release version has lower precedence than its associated release"). Every version
# comparison in the harness must go through this function.
harness_semver_cmp() {
  local a="$1" b="$2" acore bcore apre bpre i av bv n x y
  acore="${a%%-*}"; bcore="${b%%-*}"
  case "$a" in *-*) apre="${a#*-}" ;; *) apre="" ;; esac
  case "$b" in *-*) bpre="${b#*-}" ;; *) bpre="" ;; esac

  # Nth dot-separated field, or empty when there is no Nth field. `cut -d. -fN` cannot be used:
  # it echoes the whole string back when the input contains no delimiter at all.
  _hsc_field() { printf '%s' "$1" | tr '.' '\n' | sed -n "${2}p"; }

  for i in 1 2 3; do
    av="$(_hsc_field "$acore" "$i")"; av="${av//[!0-9]/}"; av="${av:-0}"
    bv="$(_hsc_field "$bcore" "$i")"; bv="${bv//[!0-9]/}"; bv="${bv:-0}"
    [ "$av" -gt "$bv" ] && { echo 1; return; }
    [ "$av" -lt "$bv" ] && { echo -1; return; }
  done

  # Equal cores: a version with a prerelease tag ranks below the plain release.
  [ -z "$apre" ] && [ -z "$bpre" ] && { echo 0; return; }
  [ -z "$apre" ] && { echo 1; return; }
  [ -z "$bpre" ] && { echo -1; return; }

  # Compare dot-separated prerelease identifiers left to right.
  n=1
  while :; do
    x="$(_hsc_field "$apre" "$n")"
    y="$(_hsc_field "$bpre" "$n")"
    [ -z "$x" ] && [ -z "$y" ] && { echo 0; return; }
    [ -z "$x" ] && { echo -1; return; }   # fewer identifiers ranks lower
    [ -z "$y" ] && { echo 1; return; }
    if [ "$x" != "$y" ]; then
      if [ -z "${x//[0-9]/}" ] && [ -z "${y//[0-9]/}" ]; then
        [ "$x" -lt "$y" ] && echo -1 || echo 1
      elif [ -z "${x//[0-9]/}" ]; then
        echo -1                            # numeric ranks below alphanumeric
      elif [ -z "${y//[0-9]/}" ]; then
        echo 1
      elif [ "$(printf '%s\n%s\n' "$x" "$y" | LC_ALL=C sort | head -n1)" = "$x" ]; then
        echo -1                            # both alphanumeric: ASCII order
      else
        echo 1
      fi
      return
    fi
    n=$((n + 1))
  done
}

harness_semver_is_older() { [ "$(harness_semver_cmp "$1" "$2")" = "-1" ]; }

# Per-run trash dir under the target repo. Nothing in the install/update flow ever deletes: it
# moves aside instead, so the flow survives a permission policy that blocks destructive commands
# (see core/scripts/cleanup-harness-trash.sh for the user-invoked purge).
harness_trash_dir() {
  local t="$1/.agents/.harness-trash/$(date +%Y%m%d_%H%M%S)_$$"
  mkdir -p "$t" || return 1
  printf '%s\n' "$t"
}
