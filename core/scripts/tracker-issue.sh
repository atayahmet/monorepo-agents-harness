#!/usr/bin/env bash
# tracker-issue - create one tracker issue per harness task phase, through the developer's own
# already-authenticated tooling. Agent-agnostic; the harness installs and stores no credential.
#
# Four modes:
#   --infer          print the tracker this project's own git config points at, and where that
#                    answer came from. Read-only, always exits 0, never writes.
#   --list-open      print the OPEN work already on the tracker that matches the caller's keywords.
#                    Read-only: the duplicate check dispatch runs before it files anything. Never
#                    writes, never comments, never labels, never closes.
#   (default)        --dry-run: print exactly what would be created.
#   --create         create the issue and print 'created number=<n>' then its URL, URL last.
#
# One epic per multi-phase dispatch: the epic is an ordinary issue created by this same call, and
# every child is created with --parent <epic number>, which is a real parent/child relation on the
# tracker (GitHub sub-issues) rather than a label or a line of prose. There is no separate epic mode:
# one create path, one platform table, one guard.
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
#   tracker-issue.sh --list-open --search <text> [--search <text> ...]
#   tracker-issue.sh --title <text> (--body <text> | --body-file <path>)
#                    [--parent <number-or-url>] [--plan <2_plan.md>] [--tracker <platform>]
#                    [--repo <owner/name>] [--dry-run] [--create]
#
#   --infer          print 'platform=<p> target=<t> source=cache|inferred|none origin=<url>' and
#                    exit 0. No plan, no title, no body needed. Writes nothing.
#   --list-open      read-only open-work check. Needs at least one --search. Resolves the tracker
#                    and the target exactly as --create does, and refuses the harness repo exactly
#                    as --create does, so the check can never become a way to read the wrong board.
#                    Prints 'open-match count=<n> platform=<p> target=<t>' then one
#                    '#<number>\t<title>\t<url>' row per open item, unioned across the --search
#                    terms and de-duplicated by issue number. No matches is NOT a failure: count=0
#                    and exit 0. Nothing is created, changed or closed in this mode.
#   --search <text>  keyword to look for in open items; repeatable, results unioned. The caller
#                    picks 1-2 distinctive words from the intent, not a sentence.
#   --plan <path>    OPTIONAL. The phase's 2_plan.md; supplies 'tracker:' when neither --tracker
#                    nor the project cache does. Dispatch writes no plan (0.4.0-rc.5), so a caller
#                    without one is the normal case, not an error.
#   --title <text>   issue title (one line)
#   --body <text>    issue body (may be multi-line)
#   --body-file <p>  read the body from a file instead (preferred for multi-line bodies)
#   --parent <ref>   OPTIONAL. File this issue as a sub-issue of <ref> (a number or an issue URL) -
#                    the parent phase/epic this one hangs under. This is how an epic groups its
#                    children: the epic is an ordinary issue, and every child passes --parent.
#                    Only read in the create modes. On 'jira'/'linear' the harness creates nothing,
#                    so the link is not applied by it: the note goes to stderr and the paste-ready
#                    block carries a 'parent: <ref>' line for the developer to set by hand. If the
#                    installed 'gh' has no --parent flag (an older CLI), nothing is created: the
#                    script prints the paste-ready text and exits 3, the same floor as no 'gh' at all.
#   --tracker <name> platform override; see the platform table above
#   --repo <o/n>     target repository (default: the cache's target, else the 'origin' remote)
#   --dry-run        print the issue that would be created, create nothing (default)
#   --create         create the issue; prints 'tracker-issue: created number=<n>' and then the URL,
#                    URL last, so a caller that only wants the link keeps working unchanged.
#
# Exit codes: 0 = success (inferred / open work listed / dry-run printed / issue created), 1 = guard
#             failure, 2 = usage error, 3 = NOT DONE, reason printed (gh missing or unauthenticated,
#             an installed gh too old for --parent, or a recognized platform the harness does not
#             implement) - the caller records "no issue yet" and continues. In --list-open, 3 means
#             the check could not be performed at all, which the caller must report rather than treat
#             as "nothing is open".
# Dependencies: git + coreutils; 'gh' only for --create and --list-open, and its absence is a
# supported path.
# Knobs (env): HARNESS_UPSTREAM - upstream git URL of this harness, added to the never-target list.

set -euo pipefail

# Print this file's header comment (everything above the 'set -euo pipefail' line) as the usage
# text. A range by line number would silently drift every time the header grows.
print_usage() { awk 'NR < 2 { next } /^set -euo pipefail$/ { exit } { print }' "$0"; }
usage() { print_usage; exit 2; }

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
list_mode=0; searches=""; parent=""

while [ $# -gt 0 ]; do
  case "$1" in
    --infer)      infer_mode=1; shift ;;
    --list-open)  list_mode=1; shift ;;
    --search)     [ -n "${2:-}" ] || usage; searches="$searches $2"; shift 2 ;;
    --plan)       [ -n "${2:-}" ] || usage; plan="$2"; shift 2 ;;
    --title)      [ -n "${2:-}" ] || usage; title="$2"; shift 2 ;;
    --body)       [ -n "${2:-}" ] || usage; body="$2"; shift 2 ;;
    --body-file)  [ -n "${2:-}" ] || usage; body_file="$2"; shift 2 ;;
    --parent)     [ -n "${2:-}" ] || usage; parent="$2"; shift 2 ;;
    --tracker)    tracker="${2:-}"; shift 2 ;;
    --repo)       repo="${2:-}"; shift 2 ;;
    --dry-run)    create_mode=0; shift ;;
    --create)     create_mode=1; shift ;;
    -h|--help)    print_usage; exit 0 ;;
    *) echo "tracker-issue: unknown argument: $1" >&2; usage ;;
  esac
done

fail() { echo "tracker-issue: $1" >&2; exit 1; }

ROOT="$(root)"
CACHE_FILE="$ROOT/.agents/tracker.md"
# The open-work READ lives in forge.sh from 0.4.0-rc.7 on: it is a question about the code
# repository's board, and forge.sh is the harness's answer to "which forge is this, and can
# anything here reach it". Only issue CREATION stays in this script, and only for GitHub.
FORGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/forge.sh"

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
[ -n "$plan" ] && [ ! -f "$plan" ] && fail "plan file '$plan' missing"

# The list mode reads the board; it has nothing to create, so the title/body requirements do not
# apply to it. Every other mode keeps them.
if [ "$list_mode" -eq 0 ]; then
  [ -n "$title" ] || fail "no --title given"

  if [ -n "$body_file" ]; then
    [ -f "$body_file" ] || fail "--body-file '$body_file' missing"
    [ -z "$body" ] || fail "give either --body or --body-file, not both"
    body="$(cat "$body_file")"
  fi
  [ -n "$body" ] || fail "no issue body - pass --body <text> or --body-file <path>"
else
  searches="$(printf '%s' "$searches" | tr -s ' ' | sed -e 's/^ //' -e 's/ $//')"
  [ -n "$searches" ] || usage "--list-open needs at least one --search <text>"
fi

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

# --- --list-open -------------------------------------------------------------------------------
# The duplicate check, AFTER the guard cluster on purpose: the open-work check reads a real board, so
# it resolves the tracker, the target and the harness-repo refusal by exactly the same code as
# --create. Placed earlier it would have been a second, weaker copy of those rules.
if [ "$list_mode" -eq 1 ]; then
  # The tracker is still named here, and it still decides the board. "--tracker jira --list-open"
  # is a question about the Jira board, so reading this repository's GitHub issues in its place
  # would answer a different question - the exact axis confusion ADR 0003 exists to prevent.
  if [ "$tracker" != "github" ]; then
    echo "tracker-issue: cannot check open work on '$tracker' - it is not implemented by this harness, so whether the work is already filed is unknown. Read '$tracker' yourself, then tell the developer what is open" >&2
    exit 3
  fi
  # A GitHub board is read by forge.sh from 0.4.0-rc.7 on, not by a second copy of `gh issue list`
  # here. What that buys is the mechanism ladder: a self-hosted GitHub Enterprise host, or a project
  # whose token is in the environment rather than in a logged-in CLI, is now reachable, and a
  # project that is reachable by nothing still reports UNKNOWN instead of pretending it found zero.
  # --create stays GitHub-only, in this script, unchanged.
  forge_args=(issues --forge github)
  [ -n "$repo" ] && forge_args+=(--repo "$repo")
  for term in $searches; do
    forge_args+=(--search "$term")
  done
  if ! list_out="$(bash "$FORGE" "${forge_args[@]}" 2>&1)"; then
    printf '%s\n' "$list_out" >&2
    echo "tracker-issue: cannot check open work - the read failed. Whether the work is already filed is UNKNOWN, not empty; report it before creating anything" >&2
    exit 3
  fi
  printf 'tracker-issue: %s\n' "$list_out"
  exit 0
fi

# Provenance footer: greppable link back to the artifact this issue came from.
task_rel="${plan#"$ROOT"/}"
case "$task_rel" in "$plan") task_rel="$plan" ;; esac
footer="<!-- monorepo-harness phase: $task_rel -->"

paste_ready() {
  # --parent is a line, not a flag, on this path: the harness creates nothing here, so the developer
  # sets the relationship in their own tool. Naming it here beats dropping it silently.
  if [ -n "$parent" ]; then
    printf '\n--- parent ---\n%s\n' "$parent"
  fi
  printf '\n--- target ---\n%s\n--- title ---\n%s\n--- body ---\n%s\n%s\n' \
    "${repo:-<none recorded>}" "$title" "$body" "$footer"
}

# --- Emit --------------------------------------------------------------------------------------
if [ "$create_mode" -eq 0 ]; then
  printf 'tracker-issue: would create a %s issue in %s (run with --create to create it)\n' \
    "$tracker" "${repo:-<none recorded>}"
  [ -n "$parent" ] && printf 'tracker-issue: as a sub-issue of %s\n' "$parent"
  printf '\n--- title ---\n%s\n--- body ---\n%s\n%s\n' "$title" "$body" "$footer"
  exit 0
fi

# --- Create ------------------------------------------------------------------------------------
# A recognized platform the harness does not implement: nothing is created, the developer gets the
# text to paste into their own tool, and the caller records "no issue yet" and keeps going.
if [ "$tracker" != "github" ]; then
  echo "tracker-issue: '$tracker' is not implemented by this harness - issue NOT created. Use your own MCP server, project skill, or CLI for '$tracker', or paste this by hand:" >&2
  [ -n "$parent" ] && echo "tracker-issue: --parent is not applied on '$tracker' - set the parent relationship yourself from the block below" >&2
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

# --parent needs a gh that knows the flag. Ask the installed one rather than pinning a version: a
# machine with an older gh could still file this issue flat, so it is not made to fail over a link it
# cannot express. Same exit 3 as a missing gh - nothing is created either way.
if [ -n "$parent" ] && ! gh issue create --help 2>/dev/null | grep -q -- '--parent'; then
  echo "tracker-issue: this 'gh' has no '--parent' flag (too old to link a child issue) - issue NOT created; file it without --parent, or open it by hand:" >&2
  paste_ready
  exit 3
fi

# GitHub's create is atomic in its parent field: the child is created AND linked, or nothing is
# created. So there is no "created but unlinked" state to report - a refused link (no triage access
# on the parent, parent not found) is a create failure like any other, and the phase is "no issue yet".
create_args=(--repo "$repo" --title "$title" --body "$body"$'\n'"$footer")
[ -n "$parent" ] && create_args+=(--parent "$parent")

url="$(gh issue create "${create_args[@]}" 2>&1)" || {
  printf 'tracker-issue: gh issue create failed:\n%s\n' "$url" >&2
  exit 1
}

# Machine-readable first, URL last. The URL stays the final line on purpose: the tracker subagent and
# every installed copy of it read "the last stdout line is the URL", and they must keep working.
final_url="$(printf '%s\n' "$url" | tail -n 1)"
issue_number="$(printf '%s\n' "$final_url" | sed -n 's#.*/\([0-9][0-9]*\)$#\1#p')"
if [ -n "$issue_number" ]; then
  printf 'tracker-issue: created number=%s\n' "$issue_number"
fi
printf '%s\n' "$final_url"
