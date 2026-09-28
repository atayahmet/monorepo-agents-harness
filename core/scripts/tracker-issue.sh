#!/usr/bin/env bash
# tracker-issue - create one tracker issue per harness task phase, through the developer's own
# already-authenticated tooling. Agent-agnostic; the harness installs and stores no credential.
#
# Three modes:
#   --infer          print the tracker this project's own git config points at, and where that
#                    answer came from. Read-only, always exits 0, never writes.
#   (default)        --dry-run: print exactly what would be created.
#   --create         create the issue and print its URL.
#
# The tracker belongs to the CONSUMER project, never to the harness. It is resolved in this order,
# first hit wins:
#   1. --tracker <platform>
#   2. the project cache <repo-root>/.agents/tracker.md  (written once, on the developer's answer)
#   3. tracker: in the phase plan's 2_plan.md frontmatter (a per-phase record of what was used)
#   4. refuse, naming --infer
#
# Platforms: github is implemented (GitHub Issues via the 'gh' CLI). jira and linear are recognized
# but not implemented - they need an MCP server or a token the developer installs, so the script
# prints paste-ready text and exits 3. Any other platform is refused: the caller asks the developer
# how their team files work there. The script is platform-dispatched, so a second implemented
# platform is a new branch here, not a rewrite of the callers.
#
# HARD RULE: the harness's own repository is never an issue target. A target matching the harness
# upstream is refused with exit 1, in --dry-run as well as --create.
#
# Usage (from the target repo root):
#   tracker-issue.sh --infer
#   tracker-issue.sh --plan <2_plan.md> --title <text> (--body <text> | --body-file <path>)
#                    [--tracker <platform>] [--repo <owner/name>] [--dry-run] [--create]
#
#   --infer          print 'platform=<p> target=<t> source=cache|inferred|none origin=<url>' and
#                    exit 0. No plan, no title, no body needed. Writes nothing.
#   --plan <path>    the phase's 2_plan.md; supplies 'tracker:' when neither --tracker nor the
#                    project cache does
#   --title <text>   issue title (one line)
#   --body <text>    issue body (may be multi-line)
#   --body-file <p>  read the body from a file instead (preferred for multi-line bodies)
#   --tracker <name> platform override; see the platform table above
#   --repo <o/n>     target repository (default: the cache's target, else the 'origin' remote)
#   --dry-run        print the issue that would be created, create nothing (default)
#   --create         create the issue and print its URL
#
# Exit codes: 0 = success (inferred / dry-run printed / issue created), 1 = guard failure, 2 = usage
#             error, 3 = not created, paste-ready text printed (gh missing or unauthenticated, or a
#             recognized platform the harness does not implement) - the caller records "no issue
#             yet" and continues.
# Dependencies: git + coreutils; 'gh' only for --create, and its absence is a supported path.
# Knobs (env): HARNESS_UPSTREAM - upstream git URL of this harness, added to the never-target list.

set -euo pipefail

usage() { sed -n '3,49p' "$0"; exit 2; }

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

# github_slug <remote-url> - print 'owner/name' for a remote URL, or nothing.
github_slug() {
  local slug
  slug="$(printf '%s' "$1" | sed -n 's#^[a-zA-Z]*://[^/]*/\([^/]*\)/\(.*\)$#\1/\2#p; s#^[^:]*:\([^/]*\)/\(.*\)$#\1/\2#p')"
  printf '%s' "${slug%.git}"
}

# remote_host <remote-url> - print the host (user@, port and trailing path stripped), or nothing.
# Handles both 'https://host/owner/name' and the scp-style 'git@host:owner/name'.
remote_host() {
  printf '%s' "$1" \
    | sed -n -e 's#^[a-zA-Z]*://\([^/]*\)/.*$#\1#p' -e 's#^\([^:/]*\):.*$#\1#p' \
    | sed -e 's#^.*@##' -e 's#:[0-9]*$##'
}

# normalize_repo <repo> - one comparable spelling of a repository, whatever form it arrives in:
# 'https://github.com/o/n.git', 'git@github.com:o/n.git' and 'o/n' all become 'o/n'. Used only to
# compare a target against the harness upstream, so it never rejects an unparseable string - an
# unrecognizable target is simply not the harness repo.
normalize_repo() {
  printf '%s' "$1" \
    | sed -e 's#^[a-zA-Z]*://[^/]*/##' -e 's#^[^:/]*:##' -e 's#^/*##' -e 's#/*$##' -e 's#\.git$##' \
    | tr '[:upper:]' '[:lower:]'
}

# platform_for_host <host> - the platform a host implies. Anything not recognized is 'unknown': a
# self-hosted GitLab is not github.com, and a wrong guess is worse than one more question.
platform_for_host() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    github.com)         printf 'github' ;;
    bitbucket.org)       printf 'bitbucket' ;;
    gitlab.com)          printf 'gitlab' ;;
    *)                   printf 'unknown' ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
[ $# -ge 1 ] || usage

plan=""; title=""; body=""; body_file=""; tracker=""; repo=""; create_mode=0; infer_mode=0

while [ $# -gt 0 ]; do
  case "$1" in
    --infer)      infer_mode=1; shift ;;
    --plan)      [ -n "${2:-}" ] || usage; plan="$2"; shift 2 ;;
    --title)     [ -n "${2:-}" ] || usage; title="$2"; shift 2 ;;
    --body)      [ -n "${2:-}" ] || usage; body="$2"; shift 2 ;;
    --body-file) [ -n "${2:-}" ] || usage; body_file="$2"; shift 2 ;;
    --tracker)   tracker="${2:-}"; shift 2 ;;
    --repo)      [ -n "${2:-}" ] || usage; repo="$2"; shift 2 ;;
    --dry-run)   create_mode=0; shift ;;
    --create)    create_mode=1; shift ;;
    -h|--help)   sed -n '3,49p' "$0"; exit 0 ;;
    *) echo "tracker-issue: unknown argument: $1" >&2; usage ;;
  esac
done

fail() { echo "tracker-issue: $1" >&2; exit 1; }

ROOT="$(root)"
CACHE_FILE="$ROOT/.agents/tracker.md"

cache_field() { frontmatter_field "$CACHE_FILE" "${1:-}" 2>/dev/null || true; }

origin_url() { git -C "$ROOT" remote get-url origin 2>/dev/null || true; }

# harness_slugs - every 'owner/name' that identifies the harness itself, one per line. Sources:
# $HARNESS_UPSTREAM when set, the upstream this harness ships with, and the bundle's own origin - but
# only when the bundle directory is itself a git worktree root. The INSTALLED bundle is a copy, so a
# plain 'git -C <bundle>' resolves the consumer's repository and would refuse every real install.
harness_slugs() {
  local top real_top
  printf '%s\n' "https://github.com/atayahmet/monorepo-agents-harness"
  [ -n "${HARNESS_UPSTREAM:-}" ] && printf '%s\n' "$HARNESS_UPSTREAM"
  top="$(git -C "$BUNDLE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ]; then
    real_top="$(cd "$top" && pwd -P)"
    if [ "$real_top" = "$BUNDLE_DIR" ]; then
      git -C "$BUNDLE_DIR" remote get-url origin 2>/dev/null || true
    fi
  fi
  printf '\n'
}

# is_harness_repo <repo> - true when the target is the harness's own repository, in any spelling.
is_harness_repo() {
  local needle url slug
  needle="$(normalize_repo "$1")"
  [ -n "$needle" ] || return 1
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    slug="$(normalize_repo "$url")"
    if [ -n "$slug" ] && [ "$slug" = "$needle" ]; then
      return 0
    fi
  done <<EOF
$(harness_slugs)
EOF
  return 1
}

# refuse_harness_repo <owner/name> - the hard rule. Exits 1 before anything is printed or created.
refuse_harness_repo() {
  is_harness_repo "$1" && fail "'$1' is the harness's own repository, not this project's task tracker - it is never an issue target. Pass --repo <owner/name> for this project, or record the tracker's target in $CACHE_FILE"
  return 0
}

# --- --infer -----------------------------------------------------------------------------------
# The confirmation question the dispatch skill asks needs a suggestion with a source label. A wrong
# suggestion is a question, not a failure, so this path always exits 0 and writes nothing.
if [ "$infer_mode" -eq 1 ]; then
  cached="$(cache_field tracker)"
  origin="$(origin_url)"
  host="$(remote_host "$origin")"
  if [ -n "${cached// /}" ]; then
    platform="$cached"
    source="cache"
    target="$(cache_field target)"
  else
    platform="$(platform_for_host "$host")"
    source="inferred"
    [ "$platform" = "unknown" ] && source="none"
    target=""
    if [ "$platform" = "github" ]; then
      target="$(github_slug "$origin" || true)"
    fi
  fi
  printf 'tracker-issue: platform=%s target=%s source=%s origin=%s\n' \
    "$platform" "$target" "$source" "$origin"
  exit 0
fi

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

# Tracker resolution: argument, then the project cache, then the phase plan's record, then refuse.
# The cache is the developer's confirmed answer, so it outranks a stale per-phase record. The plan
# line stays as the audit trail of what this phase used. See ADR 0001 in the task artifacts.
tracker_source="argument"
if [ -z "$tracker" ]; then
  tracker="$(cache_field tracker)"
  [ -n "${tracker// /}" ] && tracker_source="cache"
fi
if [ -z "$tracker" ]; then
  tracker="$(frontmatter_field "$plan" tracker || true)"
  tracker_source="plan"
fi
[ -n "${tracker// /}" ] || fail "no tracker resolved - run --infer and confirm the platform with the developer, or pass --tracker <platform>"

case "$(printf '%s' "$tracker" | tr '[:upper:]' '[:lower:]')" in
  github|gh)      tracker="github" ;;
  jira)           tracker="jira" ;;
  linear)         tracker="linear" ;;
  *) fail "platform '${tracker}' is not one the harness knows (github, jira, linear) and nothing was created. Ask the developer how their team files work in '${tracker}' and what its target is, record it in $CACHE_FILE (tracker:, target:), then re-run" ;;
esac

# Target resolution: --repo, then the cache's target - but only when the cache is also the source of
# the platform, since a Jira project key is not a GitHub repository - then the origin remote.
if [ -z "$repo" ] && [ "$tracker_source" = "cache" ]; then
  repo="$(cache_field target)"
fi
if [ -z "$repo" ] && [ "$tracker" = "github" ]; then
  repo="$(github_slug "$(origin_url)" || true)"
fi

if [ "$tracker" = "github" ]; then
  [ -n "$repo" ] || fail "no target repository - the 'origin' remote is missing or is not a GitHub URL and $CACHE_FILE has no target, so pass --repo <owner/name>"
  refuse_harness_repo "$repo"
fi

# Provenance footer: greppable link back to the artifact this issue came from.
task_rel="${plan#"$ROOT"/}"
case "$task_rel" in "$plan") task_rel="$plan" ;; esac
footer="<!-- monorepo-harness phase: $task_rel -->"

paste_ready() {
  printf '\n--- target ---\n%s\n--- title ---\n%s\n--- body ---\n%s\n%s\n' \
    "${repo:-<none recorded>}" "$title" "$body" "$footer"
}

# --- Emit --------------------------------------------------------------------------------------
if [ "$create_mode" -eq 0 ]; then
  printf 'tracker-issue: would create a %s issue in %s (run with --create to create it)\n' \
    "$tracker" "${repo:-<none recorded>}"
  printf '\n--- title ---\n%s\n--- body ---\n%s\n%s\n' "$title" "$body" "$footer"
  exit 0
fi

# --- Create ------------------------------------------------------------------------------------
# A recognized platform the harness does not implement: nothing is created, the developer gets the
# text to paste into their own tool, and the caller records "no issue yet" and keeps going.
if [ "$tracker" != "github" ]; then
  echo "tracker-issue: '$tracker' is not implemented by this harness - issue NOT created. Use your own MCP server, project skill, or CLI for '$tracker', or paste this by hand:" >&2
  paste_ready
  exit 3
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "tracker-issue: 'gh' not found - issue NOT created; open it by hand:" >&2
  paste_ready
  exit 3
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "tracker-issue: 'gh auth status' failed - issue NOT created; open it by hand:" >&2
  paste_ready
  exit 3
fi

url="$(gh issue create --repo "$repo" --title "$title" --body "$body"$'\n'"$footer" 2>&1)" || {
  printf 'tracker-issue: gh issue create failed:\n%s\n' "$url" >&2
  exit 1
}
printf '%s\n' "$url" | tail -n 1
