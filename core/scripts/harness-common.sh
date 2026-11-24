#!/usr/bin/env bash
#
# harness-common.sh - shared helpers for the harness scripts.
#
# SOURCED, never executed:  . "$(dirname "${BASH_SOURCE[0]}")/harness-common.sh"
#
# Exists so install-harness.sh, install-adapter.sh and audit-install.sh cannot drift apart on
# manifest parsing, placeholder substitution, or the move-aside trash convention — and so the two
# gate scripts cannot drift apart on which task dir is "the newest one" (see
# harness_task_dirs_newest_first below).
#
# Every consumer must keep working when this file is missing: it is a library of shared answers,
# never a dependency. A caller that cannot source it keeps its own behaviour and says nothing.
#
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

# SHA-256 of a file, hex only. sha256sum (GNU coreutils) first, shasum (macOS, perl) as the fallback;
# prints nothing when neither exists, so a caller comparing hashes never matches by accident.
harness_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Per-run trash dir under the target repo. Nothing in the install/update flow ever deletes: it
# moves aside instead, so the flow survives a permission policy that blocks destructive commands
# (see core/scripts/cleanup-harness-trash.sh for the user-invoked purge).
harness_trash_dir() {
  local t="$1/.agents/.harness-trash/$(date +%Y%m%d_%H%M%S)_$$"
  mkdir -p "$t" || return 1
  printf '%s\n' "$t"
}

# Task dirs, NEWEST FIRST — the one order both gate scripts use (core/scripts/memory-gate.sh and
# core/scripts/hook-arm-build.sh).
#
# Usage:  harness_task_dirs_newest_first <glob> [<glob> ...]     (globs, not literal paths)
# Prints one existing directory per line, nothing else, exit 0 even when nothing matches.
#
# The order is the DATE IN THE DIRECTORY NAME (task_<YYYY_MM_DD>_<slug>), newest first, descending.
# Zero-padded, so a plain lexicographic compare is chronological; dashes are accepted because the
# name is the only place a task carries a date.
#
# Modification time is a TIE-BREAK inside one date and nothing else. It is not the task's age: a
# `git checkout`, a rebase, a stash pop or a one-line fix to an old memory all rewrite it. Sorting by
# mtime is how hook-arm-build.sh came to arm a task nobody was building and how the gate came to
# report the wrong dir of the day.
#
# A name with no parseable date sorts last. It is never the newest task, which is the safe direction:
# a dir that cannot say when it was opened must not be armed ahead of one that can.
harness_task_dirs_newest_first() {
  local pattern
  # compgen -G expands one glob as a single word, so a path containing a space survives; the usual
  # `for x in $pattern` would split it into two words and arm nothing.
  for pattern in "$@"; do
    compgen -G "$pattern" 2>/dev/null || true
  done | harness_sort_task_dirs
}

# The same order for LITERAL paths, one per line on stdin. Use this one when the paths are already
# known: a repo path that contains a glob character is not a pattern here. Duplicates are dropped.
harness_sort_task_dirs() {
  local d base dt mt
  local -x LC_ALL=C   # paths are bytes: in a UTF-8 locale the BSD tools stop at an invalid one
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    base="$(basename "$d")"
    dt="$(printf '%s\n' "$base" | grep -oE '[0-9]{4}[_-][0-9]{2}[_-][0-9]{2}' | head -1 | sed 's/[-]/_/g' || true)"
    [ -n "$dt" ] || dt="0000_00_00"
    # `stat -c` is GNU, `stat -f %m` is BSD/macOS; a dir we cannot stat just sorts by its date.
    mt="$(stat -c %Y "$d" 2>/dev/null || stat -f %m "$d" 2>/dev/null || echo 0)"
    printf '%s\t%s\t%s\n' "$dt" "${mt:-0}" "$d"
  done | LC_ALL=C sort -t$'\t' -k1,1r -k2,2nr | cut -f3- | awk '!seen[$0]++'
}

# harness_scan_task_dirs <root> — every task dir git can see under <root>, absolute, one per line, no
# order. It does not need to know the workspaces, so a task is found wherever it lives.
#
#   - tracked and untracked files: a plain listing under .agents/artifacts/task_*/
#   - ignored ones: many projects ignore `.agents/` itself. `--directory` makes git print an ignored
#     directory instead of walking it, so node_modules and build output cost nothing. A task under an
#     ignored PARENT directory stays invisible: that directory is vendored or generated.
#   - git never enters a nested repo, a worktree or a submodule here
#
# Skipped: the bundle, the harness's own .agents/.harness-* dirs, and vendored or fixture trees. A
# workspace the project declared is not found through this scan, so it is never skipped by this list.
harness_scan_task_dirs() {
  local root="$1"
  ( export LC_ALL=C   # one path with an invalid byte must not end the listing for the rest
    cd "$root" 2>/dev/null || exit 0
    { git ls-files -z -co --exclude-standard -- ':(glob)**/.agents/artifacts/task_*/**' 2>/dev/null || true
      git ls-files -z -o -i --exclude-standard --directory 2>/dev/null || true
    } | tr '\0' '\n' | awk '
      function found(p) { if (!(p in seen)) { seen[p] = 1; print p } }
      { p = "/" $0 }
      p ~ /\/(node_modules|vendor|fixtures|__fixtures__|testdata|test-fixtures)\// { next }
      p ~ /\/\.agents\/(monorepo-agents-harness|\.harness-[^\/]*)\// { next }
      match(p, /\/\.agents\/artifacts\/task_[^\/]+\//) { found("D " substr(p, 2, RSTART + RLENGTH - 3)); next }
      p ~ /\/\.agents\/$/           { found("A " substr(p, 2) "artifacts") ; next }
      p ~ /\/\.agents\/artifacts\/$/ { found("A " substr(p, 2, length(p) - 2)) }
    ' | while IFS= read -r hit; do
      case "$hit" in
        D\ *) [ -d "${hit#D }" ] && printf '%s\n' "$root/${hit#D }" ;;
        A\ *) for d in "${hit#A }"/task_*; do
                [ -d "$d" ] && printf '%s\n' "$root/$d"
              done ;;
      esac
    done
    true )
}
