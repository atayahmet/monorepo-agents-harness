#!/usr/bin/env bash
# Detect the monorepo framework used by the target repo and list its workspaces.
#
# Usage (from the target repo root):
#   detect-monorepo-framework.sh [--framework] [--workspaces] [--workspace-dirs]
#
# Output:
#   --framework       prints one of: turborepo, nx, lerna, pnpm, yarn, npm, unknown
#   --workspace-dirs  prints the existing workspace directories, absolute, one per line. This is what
#                     the harness scripts use. Problems in the declaration file go to stderr.
#   --workspaces      prints the PARENT directories of the workspace globs, one per line (kept for
#                     callers outside the harness; with a declaration, glob lines only)
#   default           prints "framework: <name>" and "workspaces: <path> ..." lines
#
# Where the workspaces come from, first match wins:
#   1. .agents/workspaces.txt  the project's own declaration (any language, any layout). One
#                              repo-relative path or glob per line: crates/*, billing, services/a/b, or
#                              "." for the repo root. "#" starts a comment; "*" matches inside one path
#                              segment. A file with at least one usable line REPLACES detection.
#   2. the framework           see below
#   3. apps/* and packages/*
#
# Framework detection order (most specific first):
#   turbo.json              -> turborepo (list: pnpm-workspace.yaml, else package.json workspaces)
#   nx.json                 -> nx
#   lerna.json              -> lerna
#   pnpm-workspace.yaml     -> pnpm
#   package.json workspaces -> yarn or npm (resolved by packageManager / lockfile)
#
# Depends on git + coreutils. jq is needed only to read workspaces out of package.json / lerna.json.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DECLARATION="$ROOT/.agents/workspaces.txt"

print_framework=0
print_workspaces=0
print_dirs=0
for arg in "$@"; do
  case "$arg" in
    --framework) print_framework=1 ;;
    --workspaces) print_workspaces=1 ;;
    --workspace-dirs) print_dirs=1 ;;
  esac
done

framework="unknown"
globs=()      # repo-relative paths or globs
excludes=()   # the same, from "!" entries of a pnpm / package.json list
declared=0

warn() { [ "$print_dirs" -eq 0 ] || printf 'warning: .agents/workspaces.txt: %s\n' "$1" >&2; }

# add_globs — read one framework entry per line from stdin into globs / excludes. The repo root is a
# workspace only when the project declares it, so a "." entry of a package manager is dropped.
add_globs() {
  local w
  while IFS= read -r w; do
    case "$w" in '!'*) w="${w#!}"; w="${w#./}"; excludes+=("${w%/}"); continue ;; esac
    while [ "${w#./}" != "$w" ]; do w="${w#./}"; done
    w="${w%/}"
    case "$w" in ''|.) continue ;; esac
    globs+=("$w")
  done
}

# pnpm_packages <file> — the entries of the top-level `packages:` list, block or inline.
pnpm_packages() {
  awk '
    function emit(v,   q, i) {
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      q = substr(v, 1, 1)
      if (q == "\"" || q == "\047") {
        v = substr(v, 2); i = index(v, q); if (i) v = substr(v, 1, i - 1)
      } else { sub(/[ \t]+#.*$/, "", v); sub(/^#.*$/, "", v); gsub(/[ \t]+$/, "", v) }
      if (v != "") print v
    }
    function inline(s,   n, a, i, end) {
      sub(/[ \t]#.*$/, "", s)
      end = index(s, "]"); if (end) s = substr(s, 1, end - 1)
      n = split(s, a, ","); for (i = 1; i <= n; i++) emit(a[i])
      if (end) { on = 0; flow = 0 }
    }
    { sub(/\r$/, "") }
    /^["\047]?packages["\047]?[ \t]*:/ {
      on = 1; s = $0; sub(/^[^:]*:[ \t]*/, "", s)
      if (substr(s, 1, 1) == "[") { flow = 1; inline(substr(s, 2)) }
      next
    }
    !on { next }
    flow { inline($0); next }
    /^[ \t]*(#|$)/ { next }
    /^[ \t]*-[ \t]/ { s = $0; sub(/^[ \t]*-[ \t]+/, "", s); emit(s); next }
    { on = 0 }
  ' "$1" 2>/dev/null || true
}

# package_json_workspaces — the array form and the { "packages": [] } form.
package_json_workspaces() {
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '(.workspaces // empty) | if type == "object" then (.packages // []) else . end | .[]?' \
    "$ROOT/package.json" 2>/dev/null || true
}

if [ -f "$ROOT/turbo.json" ]; then
  framework="turborepo"
  [ ! -f "$ROOT/pnpm-workspace.yaml" ] || add_globs < <(pnpm_packages "$ROOT/pnpm-workspace.yaml")
  if [ "${#globs[@]}" -eq 0 ] && [ -f "$ROOT/package.json" ]; then
    add_globs < <(package_json_workspaces)
  fi
  [ "${#globs[@]}" -gt 0 ] || globs=("apps/*" "packages/*")

elif [ -f "$ROOT/nx.json" ]; then
  framework="nx"
  globs=("apps/*" "libs/*" "packages/*")

elif [ -f "$ROOT/lerna.json" ]; then
  framework="lerna"
  if command -v jq >/dev/null 2>&1; then
    add_globs < <(jq -r '.packages[]? // empty' "$ROOT/lerna.json" 2>/dev/null || true)
  fi
  # Default fallback if jq is missing or lerna.json has no packages array.
  [ "${#globs[@]}" -gt 0 ] || globs=("packages/*")

elif [ -f "$ROOT/pnpm-workspace.yaml" ]; then
  framework="pnpm"
  add_globs < <(pnpm_packages "$ROOT/pnpm-workspace.yaml")
  [ "${#globs[@]}" -gt 0 ] || globs=("apps/*" "packages/*")

elif [ -f "$ROOT/package.json" ]; then
  add_globs < <(package_json_workspaces)

  if [ "${#globs[@]}" -gt 0 ]; then
    package_manager="$(jq -r '.packageManager // empty' "$ROOT/package.json" 2>/dev/null || true)"

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

# The project's own declaration replaces whatever the framework said.
if [ -f "$DECLARATION" ]; then
  lines=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in '#'*) continue ;; esac
    line="${line%%[[:blank:]]#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in
      /*) warn "skipped '$line' (paths are relative to the repo root)"; continue ;;
      ..|../*|*/..|*/../*) warn "skipped '$line' (a path may not leave the repo)"; continue ;;
    esac
    case "$line" in
      '**'|*/'**') warn "'$line' is read as '${line%\*}' (one level)"; line="${line%\*}" ;;
    esac
    while [ "${line#./}" != "$line" ]; do line="${line#./}"; done
    line="${line%/}"
    lines+=("${line:-.}")
  done < "$DECLARATION"
  if [ "${#lines[@]}" -gt 0 ]; then
    declared=1
    globs=("${lines[@]}")
    excludes=()
  fi
fi

if [ "$print_workspaces" -eq 1 ]; then
  # Safe iteration even when the array is empty under `set -u`.
  for w in ${globs[@]+"${globs[@]}"}; do
    if [ "$declared" -eq 1 ]; then
      case "$w" in *'*'*) ;; *) continue ;; esac
    fi
    # Strip the trailing wildcard/glob segment so callers get parent dirs.
    w="$ROOT/$w"
    printf '%s\n' "${w%/*}"
  done
  exit 0
fi

# excluded <dir> — does a "!" entry match this repo-relative directory? Without "**" a pattern only
# matches at its own depth, because a shell pattern's "*" would also cross "/".
excluded() {
  local d="$1" x ds xs
  ds="${d//[!\/]/}"
  for x in ${excludes[@]+"${excludes[@]}"}; do
    xs="${x//[!\/]/}"
    case "$x" in *'**'*) ;; *) [ "$ds" = "$xs" ] || continue ;; esac
    # shellcheck disable=SC2254
    case "$d" in $x) return 0 ;; esac
    # shellcheck disable=SC2254
    case "$d/" in $x) return 0 ;; esac
  done
  return 1
}

# The existing directories behind the globs. Expanded from inside the repo, so a repo path that itself
# contains spaces or glob characters is never part of the pattern.
if [ "$print_dirs" -eq 1 ]; then
  [ "${#globs[@]}" -gt 0 ] || globs=("apps/*" "packages/*")
  cd "$ROOT"
  for g in "${globs[@]}"; do
    hits=0
    while IFS= read -r d; do
      [ -n "$d" ] && [ -d "$d" ] || continue
      case "/$d/" in */node_modules/*) continue ;; esac
      excluded "$d" && continue
      hits=$((hits + 1))
      if [ "$d" = . ]; then printf '%s\n' "$ROOT"; else printf '%s\n' "$ROOT/$d"; fi
    done < <(compgen -G "$g" 2>/dev/null | LC_ALL=C sort || true)
    if [ "$declared" -eq 1 ] && [ "$hits" -eq 0 ]; then warn "'$g' matches no directory"; fi
  done | awk '!seen[$0]++'
  exit 0
fi

echo "framework: $framework"
if [ "${#globs[@]}" -gt 0 ]; then
  echo "workspaces: $(for w in "${globs[@]}"; do printf '%s ' "$ROOT/$w"; done | sed 's/ $//')"
else
  echo "workspaces:"
fi
