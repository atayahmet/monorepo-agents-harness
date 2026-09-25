#!/usr/bin/env bash
# tracker-issue - create one tracker issue per harness task phase, through the developer's own
# already-authenticated tooling. Agent-agnostic; the harness installs and stores no credential.
#
# Reads a phase's 2_plan.md for the resolved 'tracker:' value, then creates the issue to stdout as a
# bare URL (--create) or prints exactly what would be created (default, --dry-run). Only GitHub
# Issues is implemented in this version, through the 'gh' CLI; the script is platform-dispatched so
# a second platform is a new branch here, not a rewrite of the callers.
#
# Nothing is created before --create, and nothing is claimed to exist unless it does: when 'gh' is
# missing or unauthenticated the script prints the paste-ready title and body and exits 3, so the
# caller records "no issue yet" and the developer opens it by hand.
#
# Usage (from the target repo root):
#   tracker-issue.sh --plan <2_plan.md> --title <text> (--body <text> | --body-file <path>)
#                    [--tracker <platform>] [--repo <owner/name>] [--dry-run] [--create]
#
#   --plan <path>     the phase's 2_plan.md; supplies 'tracker:' when --tracker is absent
#   --title <text>    issue title (one line)
#   --body <text>     issue body (may be multi-line)
#   --body-file <p>   read the body from a file instead (preferred for multi-line bodies)
#   --tracker <name>  platform override; this version supports 'github' only
#   --repo <o/n>      target repository (default: parsed from the 'origin' git remote)
#   --dry-run         print the issue that would be created, create nothing (default)
#   --create          create the issue and print its URL
#
# Exit codes: 0 = success (dry-run printed / issue created), 1 = guard failure, 2 = usage error,
#             3 = not created, paste-ready text printed (gh missing or unauthenticated) - the caller
#             records "no issue yet" and continues.
# Dependencies: git + coreutils; 'gh' only for --create, and its absence is a supported path.

set -euo pipefail

usage() { sed -n '3,30p' "$0"; exit 2; }

root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# frontmatter_field <file> <key> - print the value of a top-level frontmatter key ('key: value'),
# or nothing if the file or key is absent. Same contract as task-state.sh / draft-changeset.sh.
frontmatter_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v k="$key" '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR==1 { in_fm=1; next }
    in_fm && $0 ~ /^---[[:space:]]*$/ { exit }
    in_fm && match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*") {
      print substr($0, RSTART+RLENGTH); exit
    }
  ' "$file"
}

# github_slug <remote-url> - print 'owner/name' for a GitHub remote, or nothing.
github_slug() {
  local slug
  slug="$(printf '%s' "$1" | sed -n 's#^[a-zA-Z]*://[^/]*/\([^/]*\)/\(.*\)$#\1/\2#p; s#^[^:]*:\([^/]*\)/\(.*\)$#\1/\2#p')"
  printf '%s' "${slug%.git}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ $# -ge 1 ] || usage

plan=""; title=""; body=""; body_file=""; tracker=""; repo=""; create_mode=0

while [ $# -gt 0 ]; do
  case "$1" in
    --plan)      [ -n "${2:-}" ] || usage; plan="$2"; shift 2 ;;
    --title)     [ -n "${2:-}" ] || usage; title="$2"; shift 2 ;;
    --body)      [ -n "${2:-}" ] || usage; body="$2"; shift 2 ;;
    --body-file) [ -n "${2:-}" ] || usage; body_file="$2"; shift 2 ;;
    --tracker)   tracker="${2:-}"; shift 2 ;;
    --repo)      [ -n "${2:-}" ] || usage; repo="$2"; shift 2 ;;
    --dry-run)   create_mode=0; shift ;;
    --create)    create_mode=1; shift ;;
    -h|--help)   sed -n '3,30p' "$0"; exit 0 ;;
    *) echo "tracker-issue: unknown argument: $1" >&2; usage ;;
  esac
done

fail() { echo "tracker-issue: $1" >&2; exit 1; }

# --- Guard cluster -----------------------------------------------------------------------------
[ -n "$plan" ] || fail "no --plan <2_plan.md> given"
[ -f "$plan" ] || fail "plan file '$plan' missing"
[ -n "$title" ] || fail "no --title given"

if [ -n "$body_file" ]; then
  [ -f "$body_file" ] || fail "--body-file '$body_file' missing"
  [ -z "$body" ] || fail "give either --body or --body-file, not both"
  body="$(cat "$body_file")"
fi
[ -n "$body" ] || fail "no issue body - pass --body <text> or --body-file <path>"

ROOT="$(root)"

# Tracker resolution: argument, then the plan's frontmatter, then refuse (the caller asks the user
# and retries with --tracker). See ADR 0002 in the task artifacts for why the plan is the cache.
[ -n "$tracker" ] || tracker="$(frontmatter_field "$plan" tracker || true)"
[ -n "${tracker// /}" ] || fail "no tracker resolved - pass --tracker <platform> (this version supports: github) or record 'tracker:' in $plan"
case "$tracker" in
  github|GitHub|gh) tracker="github" ;;
  *) fail "unsupported tracker '$tracker' - this version implements github (GitHub Issues via the gh CLI) only" ;;
esac

if [ -z "$repo" ]; then
  remote="$(git remote get-url origin 2>/dev/null || true)"
  repo="$(github_slug "$remote" || true)"
  [ -n "$repo" ] || fail "no target repository - the 'origin' remote is missing or is not a GitHub URL, so pass --repo <owner/name>"
fi

# Provenance footer: greppable link back to the artifact this issue came from.
task_rel="${plan#"$ROOT"/}"
case "$task_rel" in "$plan") task_rel="$plan" ;; esac
footer="<!-- monorepo-harness phase: $task_rel -->"

# --- Emit --------------------------------------------------------------------------------------
if [ "$create_mode" -eq 0 ]; then
  printf 'tracker-issue: would create a github issue in %s (run with --create to create it)\n' "$repo"
  printf '\n--- title ---\n%s\n--- body ---\n%s\n%s\n' "$title" "$body" "$footer"
  exit 0
fi

# --- Create ------------------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "tracker-issue: 'gh' not found - issue NOT created; open it by hand:" >&2
  printf '\n--- repo ---\n%s\n--- title ---\n%s\n--- body ---\n%s\n%s\n' "$repo" "$title" "$body" "$footer"
  exit 3
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "tracker-issue: 'gh auth status' failed - issue NOT created; open it by hand:" >&2
  printf '\n--- repo ---\n%s\n--- title ---\n%s\n--- body ---\n%s\n%s\n' "$repo" "$title" "$body" "$footer"
  exit 3
fi

url="$(gh issue create --repo "$repo" --title "$title" --body "$body"$'\n'"$footer" 2>&1)" || {
  printf 'tracker-issue: gh issue create failed:\n%s\n' "$url" >&2
  exit 1
}
printf '%s\n' "$url" | tail -n 1
