#!/usr/bin/env bash
# forge - read a pull request's state, reviews and open issues from whatever forge this project is
# actually on, and merge the intent PR when - and only when - the harness can prove it is allowed to.
# Agent-agnostic. Reads the developer's existing configuration; installs, prompts for and stores no
# credential.
#
# This is the FORGE axis: where the code and its pull requests live. It is deliberately not the
# TRACKER axis (where work items are filed: GitHub Issues, Jira, Linear), which belongs to
# tracker-issue.sh. A project can file Jira issues and open GitHub pull requests; one "platform"
# answer cannot serve both questions. See ADR 0003.
#
# Subcommands (all read-only except `merge`):
#   resolve [<ref>]      print the forge and how it was decided
#   probe   [<ref>]      report which mechanism could reach it, and whether the harness can use it
#   state   <ref>        print the PR's state, title, mergeability and merge status
#   reviews <ref>        print "<reviewer>\t<state>\t<date>", one row per reviewer's LATEST review
#   issues  [--search t] print the open issues matching the terms (the duplicate check's read path)
#   merge   <ref>        merge the PR with a merge commit, or refuse; --explain to see the plan only
#   paste   <ref>        print the developer-facing manual steps for this forge
#
# Usage (from anywhere inside the target repo):
#   forge.sh resolve [42|owner/name#42|!42|https://host/o/n/pull/42|...]
#   forge.sh state <ref>
#   forge.sh reviews <ref>
#   forge.sh issues --search <text> [--search <text> ...]
#   forge.sh merge <ref> [--explain]
#   forge.sh paste <ref>
#
# Options:
#   <ref>            the intent's `pr:` value, in any spelling. Accepted: 42, #42, owner/name#42,
#                    !42, group/project!42, and the platform URL shapes - GitHub /pull/42, GitLab
#                    /-/merge_requests/42 (incl. nested groups and self-hosted hosts), Bitbucket
#                    /pull-requests/42, Gitea /pulls/42, plus scp-style git@host:o/n. An
#                    unexpanded template value ({{PR_URL}}, <optional PR URL or #number>) is "no
#                    ref", not a malformed one.
#   --forge <name>   force the platform (github, gitlab, bitbucket, gitea)
#   --search <text>  keyword for `issues`; repeatable, results unioned
#   --explain        for `merge`: print what would run and exit 0 without writing anything
#
# How the forge is decided, first hit wins:
#   1. --forge <platform>
#   2. the host inside the PR URL itself (direct evidence about the PR being acted on)
#   3. forge: in <repo-root>/.agents/tracker.md
#   4. the host of this project's own 'origin' remote
#   5. unknown - the caller asks the developer. Never a guess: a wrong platform reads the wrong
#      system, and a second question is cheaper than a wrong merge.
#
# How a forge is reached - the ladder, in order, and every rung is PROBE-VERIFIED with a real read
# before any write is considered:
#   cli   gh / glab / tea - installed AND authenticated. The only rung the script can both read and
#         write on its own.
#   rest  curl + jq + a token the project already exports (GITHUB_TOKEN, GITLAB_TOKEN,
#         BITBUCKET_TOKEN, GITEA_TOKEN). The script never asks for a token, never writes one, and
#         never reads one out of a config file: a project that keeps its token only inside an MCP
#         server's env block is served by the mcp rung instead, where the agent's own credentials do
#         the work.
#   mcp   an MCP server the PROJECT configures (.mcp.json, .cursor/mcp.json, .claude/settings.json,
#         .claude.json, .vscode/mcp.json, opencode.json(c)), matched to the platform by explicit
#         tokens in the server's declared name/command/args/env. A shell script cannot call an MCP
#         tool, so this rung is a HANDOFF: the report names the config file and the server, and the
#         agent makes the call with its own tools. The script never reports a merge it did not make.
#   skill a project-defined skill documenting the team's procedure for this forge. Also a handoff,
#         and it OUTRANKS a generic command when the two disagree - the report says so instead of
#         silently overriding the project.
#   none  exit 3 with paste-ready steps. A missing read path is reported as a missing read path,
#         never as "no approval" and never as "nothing is open".
#
# HARD RULES:
#   - The harness's own repository is never refused here. That guard belongs to issue filing
#     (tracker-issue.sh): a maintainer's intent PR in the harness is an ordinary pull request.
#   - A platform whose read cannot be probe-verified is NOT supported for merging. The merge is
#     refused and handed back. An unverifiable read is never treated as an approval.
#   - Merge commit only. No --admin, no branch deletion, no squash, rebase, fast-forward-only or
#     auto. A platform is refused rather than downgraded to a method nobody agreed to.
#   - Every REST merge pins its method explicitly (merge_method=merge / squash=false), so the method
#     is visible in the recorded request rather than implied by a server default.
#
# Exit codes: 0 = done (resolved / probed / read / listed / merged / already merged), 1 = refused or
#             failed (the reason is on stderr), 2 = usage error, 3 = NOT DONE - the harness cannot
#             reach this forge, or cannot verify what it is about to do. On 3 the caller relays the
#             discovered mechanism or the paste-ready steps and does not claim a merge happened.
# Dependencies: git, awk, sed, curl and jq only for the rest rung (a missing curl or jq makes that
#             rung unusable, which is reported like any other missing mechanism); a platform CLI only
#             for its own rung. Every absence is a supported path.
# Knobs (env): HARNESS_FORGE - platform override, same as --forge.

set -euo pipefail

print_usage() { awk 'NR < 2 { next } /^set -euo pipefail$/ { exit } { print }' "$0"; }
usage() { print_usage; exit 2; }

root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

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

# remote_host <remote-url> - the host, with user@, port and path stripped. Empty when there is no
# remote at all, which is a question for the developer rather than a guess.
remote_host() {
  printf '%s' "$1" \
    | sed -n -e 's#^[a-zA-Z]*://\([^/]*\)/.*$#\1#p' -e 's#^\([^:/]*\):.*$#\1#p' \
    | sed -e 's#^.*@##' -e 's#:[0-9]*$##'
}

# strip_git <slug> - 'o/n.git' and 'o/n/' are the same repository.
strip_git() { printf '%s' "$1" | sed -e 's#\.git$##' -e 's#/*$##'; }

# url_encode <string> - percent-encode a path segment for a REST path. GitLab addresses a project by
# its full path, so 'group/sub/project' has to become group%2Fsub%2Fproject. Byte by byte in bash:
# awk's gsub replacement is a string, not a printf conversion, so '%02X' there would be literal.
url_encode() {
  local s="$1" out="" i c n
  n=${#s}; i=0
  while [ "$i" -lt "$n" ]; do
    c="${s:$i:1}"
    case "$c" in
      [A-Za-z0-9._~-]) out="$out$c" ;;
      *)              out="$out$(printf '%%%02X' "'$c")" ;;
    esac
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# --- ref normalization ---------------------------------------------------------------------------
# normalize_ref <raw> - reduce any accepted spelling to three globals. Return 0 with them set, 1 when
# there is no PR to act on (absent field, template placeholder), 2 when there is a value this cannot
# read. The caller says which, because "no pr: field" and "a pr: field I cannot read" are different
# mistakes and get different advice.
#
# In parameter expansion rather than sed: a '-e' chain that substitutes twice prints two candidates,
# and one '#' inside a replacement closes an s#...#...#p early on BSD sed. Both bit this parser
# before it moved here.
REF_HOST=""; REF_PROJECT=""; REF_ID=""
normalize_ref() {
  local raw base rest num
  raw="$(printf '%s' "$1" | sed -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
  raw="${raw//[<>]/}"
  [ -n "$raw" ] || return 1
  # An unexpanded template value is not a malformed ref, it is no ref at all.
  case "$raw" in
    *optional*|*none*|*PR\ URL*|*"{{"*|*"}}"*) return 1 ;;
  esac

  # scp-style remotes and URLs first: a host in the ref is the strongest evidence there is.
  case "$raw" in
    *://*|git@*|*@*:*)
      base="$raw"
      case "$base" in
        *://*) base="${base#*://}"; REF_HOST="${base%%/*}"; base="${base#*/}" ;;
        *)      base="${base#*@}"; REF_HOST="${base%%:*}"; base="${base#*:}" ;;
      esac
      case "$base" in
        *"/pull/"*|*"/pulls/"*)
          rest="${base%%/pull*}"; rest="${rest%/}"; rest="${rest%/pulls}"; rest="${rest%/pull}"
          # The number is the first path segment after the marker: /pull/42/files is PR 42.
          case "$base" in
            */pulls/*) num="${base#*/pulls/}" ;;
            *)         num="${base#*/pull/}" ;;
          esac
          num="${num%%/*}"; num="${num%%[^0-9]*}"
          REF_PROJECT="$(strip_git "$rest")"; REF_ID="$num" ;;
        *"/merge_requests/"*)
          rest="${base%%/-/merge_requests/*}"; num="${base#*/merge_requests/}"; num="${num#/}"; num="${num%%/*}"; num="${num%%[^0-9]*}"
          REF_PROJECT="$(strip_git "$rest")"; REF_ID="$num" ;;
        *"/pull-requests/"*)
          rest="${base%%/pull-requests/*}"; num="${base#*/pull-requests/}"; num="${num#/}"; num="${num%%/*}"; num="${num%%[^0-9]*}"
          REF_PROJECT="$(strip_git "$rest")"; REF_ID="$num" ;;
        *)
          # A URL with no PR path is a repository, not a pull request: useful for `issues`. It may
          # still carry the ref in a fragment - 'git@host:o/n#5' is a remote someone wrote by hand.
          base="${base#\#*}"
          case "$base" in
            *\#*) REF_ID="${base##*#}"; base="${base%%#*}" ;;
          esac
          REF_PROJECT="$(strip_git "$base")" ;;
      esac
      ;;
    *!*)  REF_PROJECT="${raw%!*}"; REF_ID="${raw##*!}"; REF_ID="${REF_ID#\#}" ;;
    *\#*) REF_PROJECT="${raw%%#*}"; REF_ID="${raw#*#}" ;;
    *)    REF_ID="$raw" ;;
  esac
  # What a platform CLI is actually given. A bare number would be resolved against THIS repository,
  # so a ref that named another project is handed over qualified: 'acme/web#42' on the CLI, and the
  # full URL when the developer pasted one (a URL is unambiguous on every platform's CLI).
  case "$raw" in
    *://*|*@*:*|*#*|*!*) MERGE_REF="$raw" ;;
    *)                  MERGE_REF="$REF_ID" ;;
  esac
  case "$MERGE_REF" in
    *://*|*@*:*) : ;;
    *#*|*!*)     : ;;
    *)            [ -n "$REF_PROJECT" ] && MERGE_REF="$REF_PROJECT#$REF_ID" ;;
  esac

  [ -n "$REF_ID" ] || { [ -n "$REF_PROJECT" ] || return 1; }
  [ -z "$REF_ID" ] || case "$REF_ID" in *[!0-9]*) return 2 ;; esac
  if [ -n "$REF_PROJECT" ]; then
    case "$REF_PROJECT" in *[!0-9A-Za-z_./-]*) return 2 ;; esac
  fi
  return 0
}

# --- platform resolution -------------------------------------------------------------------------
# platform_for_host <host> - match a token, not a whole hostname: gitlab.example.com and
# git.example.com are both GitLab, and refusing to recognize a self-hosted instance would send every
# enterprise user down the "ask the developer" path for a question the URL already answered.
platform_for_host() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *github*)    printf 'github' ;;
    *gitlab*)    printf 'gitlab' ;;
    *bitbucket*) printf 'bitbucket' ;;
    *gitea*|*codeberg*) printf 'gitea' ;;
    *)           printf 'unknown' ;;
  esac
}

# api_base <platform> <host> - the REST root. A self-hosted instance is addressed on its own host;
# the hosted ones have a fixed API root, and a project that runs GitHub Enterprise overrides the
# whole thing with GITHUB_API_URL, which is read from the environment, never prompted for.
api_base() {
  case "$1" in
    github)    printf '%s' "${GITHUB_API_URL:-https://api.github.com}" ;;
    gitlab)    printf 'https://%s/api/v4' "$2" ;;
    bitbucket) printf 'https://api.bitbucket.org/2.0' ;;
    gitea)     printf 'https://%s/api/v1' "$2" ;;
    *)         printf '' ;;
  esac
}

token_var() {
  case "$1" in
    github)    printf 'GITHUB_TOKEN' ;;
    gitlab)    printf 'GITLAB_TOKEN' ;;
    bitbucket) printf 'BITBUCKET_TOKEN' ;;
    gitea)     printf 'GITEA_TOKEN' ;;
    *)         printf '' ;;
  esac
}

# resolve_forge [<ref>] - fill PLATFORM/HOST/PROJECT/ID/SOURCE. The PR's own host wins over the
# project cache, which wins over origin: a merge request URL says more about the PR than any setting
# does. Returns 1 when there is no PR and no host evidence at all, so the caller can ask.
PLATFORM=""; HOST=""; PROJECT=""; PRID=""; SOURCE=""
resolve_forge() {
  local cache origin host proj id
  cache="$(frontmatter_field "$(root)/.agents/tracker.md" forge 2>/dev/null || true)"
  origin="$(git -C "$(root)" remote get-url origin 2>/dev/null || true)"
  host="$(remote_host "$origin")"
  proj=""; id=""

  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local st=0
    normalize_ref "$1" || st=$?
    [ "$st" -eq 1 ] || {
      [ -n "$REF_HOST" ] && host="$REF_HOST"
      proj="$REF_PROJECT"; id="$REF_ID"
    }
  fi

  if [ -n "${HARNESS_FORGE:-}" ]; then
    PLATFORM="$(printf '%s' "$HARNESS_FORGE" | tr '[:upper:]' '[:lower:]')"; SOURCE="env"
  elif [ -n "$FORGE_OVERRIDE" ]; then
    PLATFORM="$(printf '%s' "$FORGE_OVERRIDE" | tr '[:upper:]' '[:lower:]')"; SOURCE="argument"
  elif [ -n "$host" ]; then
    PLATFORM="$(platform_for_host "$host")"
    # An unrecognized host contributes no answer, so it also contributes no source label: the cache
    # below then reports itself as the only thing that decided.
    [ "$PLATFORM" = "unknown" ] || SOURCE="ref-url"
  fi
  if [ -z "$PLATFORM" ] || [ "$PLATFORM" = "unknown" ]; then
    if [ -n "${cache// /}" ]; then
      PLATFORM="$(printf '%s' "$cache" | tr '[:upper:]' '[:lower:]')"
      SOURCE="cache"
    fi
  fi
  if [ -z "$PLATFORM" ] || [ "$PLATFORM" = "unknown" ]; then
    PLATFORM="unknown"; SOURCE="none"
  fi

  HOST="$host"
  if [ -n "$repo_override" ] && [ -n "$host" ] && [ -z "$FORGE_OVERRIDE" ] && [ -z "${HARNESS_FORGE:-}" ]; then
    override_platform="$(platform_for_host "$host")"
    [ "$override_platform" = "unknown" ] || { PLATFORM="$override_platform"; SOURCE="argument"; }
  fi
  # A forced platform with a host that belongs to a DIFFERENT one is a contradiction, not a hint:
  # '--forge gitlab' in a repo whose origin is github.com means GitLab at its own address. Following
  # the origin here would build https://github.com/api/v4 and read nothing.
  if [ -n "$PLATFORM" ] && [ "$PLATFORM" != "unknown" ] && [ -n "$HOST" ]; then
    if [ "$(platform_for_host "$HOST")" != "$PLATFORM" ]; then
      case "$PLATFORM" in
        github)    HOST="github.com" ;;
        gitlab)    HOST="gitlab.com" ;;
        bitbucket) HOST="bitbucket.org" ;;
        gitea)     HOST="gitea.com" ;;
      esac
    fi
  fi
  # No project in the ref: the project is this repo's origin, which is the common case and the only
  # one where assuming is safe - it is the repository the command is running in. `issues` arrives
  # here with no PR at all, so this must not wait for an id.
  if [ -z "$proj" ] && [ -n "$origin" ]; then
    case "$origin" in
      *://*) proj="${origin#*://}"; proj="${proj#*/}" ;;
      *:*)
        case "$origin" in *@*) proj="${origin#*@}"; proj="${proj#*:}" ;; *) proj="${origin#*:}" ;; esac ;;
    esac
    proj="$(strip_git "$proj")"
  fi
  # An explicit --repo is the caller's own record of where the board lives, and it outranks the
  # origin: the duplicate check runs from the workspace, not from the repository whose issues it
  # is asking about. A host in it is real evidence about the platform, so it is read as one - a
  # gitlab.com URL decides the platform even when the current repo's origin says otherwise.
  if [ -n "$repo_override" ]; then
    case "$repo_override" in
      *://*|*@*:*)
        override_base="$repo_override"
        case "$override_base" in
          *://*) override_base="${override_base#*://}"; override_host="${override_base%%/*}" ;;
          *)      override_base="${override_base#*@}"; override_host="${override_base%%:*}"; override_base="${override_base#*:}" ;;
        esac
        proj="$(strip_git "$override_base")"
        if [ -n "$override_host" ]; then
          host="$override_host"
          [ -n "$FORGE_OVERRIDE" ] || [ -n "${HARNESS_FORGE:-}" ] || SOURCE="argument"
        fi ;;
      *) proj="$repo_override" ;;
    esac
  fi
  PROJECT="$proj"; PRID="$id"
  [ -n "$PRID" ] || [ -n "$PROJECT" ]
}

# --- the mechanism ladder ------------------------------------------------------------------------
# A rung is usable only after a real read succeeds. Everything here is read-only: discovery never
# writes, comments, labels, assigns or closes anything on the forge.
MECHANISM=""; MECH_DETAIL=""

# mcp_config_files - the places a project declares MCP servers, in the shapes the common agents read.
mcp_config_files() {
  local r; r="$(root)"
  printf '%s\n' \
    "$r/.mcp.json" \
    "$r/.cursor/mcp.json" \
    "$r/.vscode/mcp.json" \
    "$r/.claude/settings.json" \
    "$r/.claude/settings.local.json" \
    "$r/.claude.json" \
    "$r/.opencode/opencode.json" \
    "$r/.opencode/opencode.jsonc" \
    "$r/opencode.json" \
    "$r/opencode.jsonc"
}

# find_mcp_server <platform> - print "<config>|<server>" when a configured server names the platform
# in its own name, command, args or env keys. Token matching only: a server is claimed for a platform
# on the evidence of its declaration, never on a hunch about what it might do. No token value is ever
# read or printed.
find_mcp_server() {
  local want="$1" f blob name
  command -v jq >/dev/null 2>&1 || return 1
  for f in $(mcp_config_files); do
    [ -f "$f" ] || continue
    blob="$(cat "$f" 2>/dev/null || true)"
    case "$blob" in *"$want"*) ;; *) continue ;; esac
    for name in $(printf '%s' "$blob" | jq -r '
        [ (.mcpServers // {}), (.mcp // {}), (.servers // {}), (.mcp.servers // {}) ]
        | map(keys) | add | unique | .[] ' 2>/dev/null || true); do
      case "$name" in *"$want"*) printf '%s|%s\n' "$f" "$name"; return 0 ;; esac
      # The name may be neutral ("forge") while the command is not: check the declaration itself.
      if printf '%s' "$blob" | jq -e --arg n "$name" --arg w "$want" '
            [ (.mcpServers // {})[$n], (.mcp // {})[$n], (.servers // {})[$n] ]
            | map(select(. != null) | tostring) | join(" ") | test($w; "i") ' >/dev/null 2>&1; then
        printf '%s|%s\n' "$f" "$name"; return 0
      fi
    done
  done
  return 1
}

# find_project_skill <platform> - print the path of a project-defined skill that documents this
# forge. It is a handoff, and it outranks a generic command: the project's own procedure wins, and a
# conflict is reported rather than silently resolved.
find_project_skill() {
  local want="$1" r d p
  r="$(root)"
  for d in "$r/.claude/skills" "$r/.agents/skills" "$r/.opencode/skill" "$r/.opencode/skills" \
           "$r/.codex/skills" "$r/skills"; do
    [ -d "$d" ] || continue
    for p in "$d"/*; do
      [ -e "$p" ] || continue
      case "$(basename "$p")" in
        *"$want"*|*pr*|*pull*|*merge*) printf '%s\n' "$p"; return 0 ;;
      esac
    done
  done
  return 1
}

# probe_cli <platform> <host> - is the platform's own CLI installed and authenticated? A CLI that is
# installed but logged out is not a mechanism, so the auth check is part of the probe rather than a
# later surprise.
probe_cli() {
  local p="$1" host="$2" bin=""
  case "$p" in
    github)    bin="gh" ;;
    gitlab)    bin="glab" ;;
    bitbucket) bin="bb" ;;
    gitea)     bin="tea" ;;
    *)         return 1 ;;
  esac
  command -v "$bin" >/dev/null 2>&1 || return 1
  case "$p" in
    github|gitlab) "$bin" auth status >/dev/null 2>&1 || return 1 ;;
    bitbucket)    "$bin" --version >/dev/null 2>&1 || return 1 ;;
    gitea)        "$bin" login list >/dev/null 2>&1 || return 1 ;;
  esac
  MECH_DETAIL="$bin"
  return 0
}

# probe_rest <platform> <host> - curl + jq + a token the project already exports. The token is read
# from the environment by name and never printed; a project that keeps it only inside an MCP server's
# env block is served by the mcp rung instead.
probe_rest() {
  local p="$1" host="$2" var
  command -v curl >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  var="$(token_var "$p")"
  [ -n "$var" ] || return 1
  eval "[ -n \"\${$var:-}\" ]" 2>/dev/null || return 1
  MECH_DETAIL="$var"
  return 0
}

# probe_read <platform> <host> - the first rung the SCRIPT can both read and write through. Only cli
# and rest qualify: an MCP tool and a project skill are things the agent does, not the shell.
probe_read() {
  if probe_cli "$1" "$2"; then MECHANISM="cli"; return 0; fi
  if probe_rest "$1" "$2"; then MECHANISM="rest"; return 0; fi
  return 1
}

# --- reads ---------------------------------------------------------------------------------------
# rest_get <platform> <host> <path> - one authenticated GET. Prints the body; the caller parses.
rest_get() {
  local p="$1" host="$2" path="$3" var base
  var="$(token_var "$p")"; base="$(api_base "$p" "$host")"
  [ -n "$base" ] || return 1
  eval "curl -sS --max-time 20 -H \"Authorization: Bearer \$$var\" \"$base$path\"" 2>/dev/null
}

# cli_state <platform> <ref> - the PR's state/title/mergeability, normalized to one line format.
cli_state() {
  case "$1" in
    github)
      gh pr view "$2" --json state,title,mergeable,mergeStateStatus \
        -q '"state=" + ((.state // "") | ascii_upcase) + " title=" + (.title // "") + " mergeable=" + (.mergeable // "") + " status=" + (.mergeStateStatus // "")' \
        2>/dev/null ;;
    gitlab)
      glab mr view "$2" 2>/dev/null | awk '
        /^!\[Merged\]/ { s="MERGED" }
        /Status:.*Merged/ { s="MERGED" }
        /Status:.*Open/ { s="OPEN" }
        /Status:.*Closed/ { s="CLOSED" }
        END { if (s != "") print "state=" s }' ;;
    gitea)
      tea pr view "$2" --output json 2>/dev/null \
        | jq -r '"state=" + ((.state // "") | ascii_upcase) + " title=" + (.title // "") + " mergeable=" + (.mergeable // "") + " status=" + ""' 2>/dev/null ;;
    *) return 1 ;;
  esac
}

# cli_reviews <platform> <ref> - the latest review per reviewer, as the same TSV every rung prints.
cli_reviews() {
  case "$1" in
    github)
      gh pr view "$2" --json reviews \
        -q '.reviews[]? | "\(.author.login // "?")\t\(.state // "")\t\(.submittedAt // "")"' 2>/dev/null ;;
    gitlab)
      # GitLab's approvals API has no "requested changes" and no per-review timestamp: an approver
      # appears in approved_by until they remove themselves. That is the whole of what the platform
      # can express, so the change-requested half of the harness rule is vacuous here - documented,
      # not faked.
      glab api "projects/$(url_encode "$3")/merge_requests/$2/approvals" 2>/dev/null \
        | jq -r '.approved_by[]? | "\(.user.username // "?")\tAPPROVED\t-"' 2>/dev/null ;;
    gitea)
      tea pr view "$2" --output json 2>/dev/null \
        | jq -r '.reviews[]? | "\(.user.login // .user.username // "?")\t\(.state // "")\t\(.submitted_at // "-")"' 2>/dev/null ;;
    *) return 1 ;;
  esac
}

# rest_state / rest_reviews - the same two reads over REST. Endpoints for the platforms whose CLI is
# not universal are ATTEMPTED and then judged by the probe: a 404 or an unexpected shape makes the
# rung unusable and the harness says so, which is why a guessed endpoint cannot become a wrong merge.
rest_state() {
  local p="$1" host="$2" id="$3" proj body
  proj="$(url_encode "$4")"
  case "$p" in
    github)
      body="$(rest_get "$p" "$host" "/repos/$4/pulls/$id")" || return 1
      printf '%s' "$body" | jq -r 'if .state == "closed" and .merged then "state=MERGED" else "state=" + ((.state // "") | ascii_upcase) + " title=" + (.title // "") + " mergeable=" + (if .mergeable then "MERGEABLE" else "CONFLICTING" end) + " status=" + "" end' 2>/dev/null ;;
    gitlab)
      body="$(rest_get "$p" "$host" "/projects/$proj/merge_requests/$id")" || return 1
      printf '%s' "$body" | jq -r '"state=" + ((.state // "") | ascii_upcase) + " title=" + (.title // "") + " mergeable=" + (if .has_conflicts then "CONFLICTING" else "MERGEABLE" end) + " status=" + (.detailed_merge_status // .merge_status // "")' 2>/dev/null ;;
    gitea)
      body="$(rest_get "$p" "$host" "/repos/$4/pulls/$id")" || return 1
      printf '%s' "$body" | jq -r 'if .merged then "state=MERGED" else "state=" + ((.state // "") | ascii_upcase) + " title=" + (.title // "") + " mergeable=" + (if .mergeable then "MERGEABLE" else "CONFLICTING" end) + " status=" + "" end' 2>/dev/null ;;
    *) return 1 ;;
  esac
}

rest_reviews() {
  local p="$1" host="$2" id="$3" proj body
  proj="$(url_encode "$4")"
  case "$p" in
    github)
      body="$(rest_get "$p" "$host" "/repos/$4/pulls/$id/reviews?per_page=100")" || return 1
      printf '%s' "$body" | jq -r 'if type == "array" then .[] | "\(.user.login // "?")\t\(.state // "")\t\(.submitted_at // "-")" else empty end' 2>/dev/null ;;
    gitlab)
      body="$(rest_get "$p" "$host" "/projects/$proj/merge_requests/$id/approvals")" || return 1
      printf '%s' "$body" | jq -r 'if (.approved_by | type) == "array" then .approved_by[] | "\(.user.username // "?")\tAPPROVED\t-" else empty end' 2>/dev/null ;;
    gitea)
      body="$(rest_get "$p" "$host" "/repos/$4/pulls/$id/reviews?limit=100")" || return 1
      printf '%s' "$body" | jq -r 'if type == "array" then .[] | "\(.user.login // "?")\t\(.state // "")\t\(.submitted_at // "-")" else empty end' 2>/dev/null ;;
    bitbucket)
      # Bitbucket Cloud exposes required-approvals state on the pull request resource itself rather
      # than a per-reviewer review list: there is no equivalent of an approving REVIEW, only a
      # participants list and an approval count. The harness therefore cannot verify an approving
      # review here, and says so instead of counting participants as consent.
      body="$(rest_get "$p" "$host" "/repositories/$4/pullrequests/$id")" || return 1
      printf '%s' "$body" | jq -r 'if (.participants // [] | map(select(.approved == true)) | length) > 0
        then (.participants[] | select(.approved == true) | "\(.user.nickname // "?")\tAPPROVED\t-") else empty end' 2>/dev/null ;;
    *) return 1 ;;
  esac
}

# validate_reviews <rows> - a read that came back in a shape we do not recognize is a BROKEN read, not
# an empty one. It matters because both look like "no approval" to a caller: dropping the rows would
# make a tool error indistinguishable from a PR nobody reviewed, and the reason the harness refuses
# is supposed to be the reason it reports.
validate_reviews() {
  printf '%s' "$1" | awk -F'\t' '
    NF == 0 { next }
    NF != 3 || $1 == "" || $2 == "" { printf "row %d is not <reviewer>\\t<state>\\t<date>\n", NR; bad = 1; next }
    $2 != "APPROVED" && $2 != "CHANGES_REQUESTED" && $2 != "DISMISSED" && $2 != "COMMENTED" \
      && $2 != "PENDING" { printf "row %d has an unknown state: %s\n", NR, $2; bad = 1 }
    END { exit bad ? 1 : 0 }'
}

# Reduce "<reviewer>\t<state>\t<date>" rows to one row per reviewer: the LATEST one by date. GitHub
# returns reviews newest-first, GitLab has no timestamps at all, and none of that ordering is a
# contract - so the harness picks the newest per reviewer itself rather than trusting position.
# A row whose date is "-" (a platform that does not provide one) is kept: dropping it would turn
# "GitLab cannot say when" into "nobody reviewed", which reads as a refusal to approve.
latest_per_reviewer() {
  awk -F'\t' '
    NF < 3 || $1 == "" { next }
    !($1 in when) { when[$1] = $3; order[++n] = $1; row[$1] = $0; next }
    $3 > when[$1] { when[$1] = $3; row[$1] = $0 }
    END { for (i = 1; i <= n; i++) print row[order[i]] }
  '
}

# --- argv the harness is willing to run ------------------------------------------------------------
# Every merge is a merge commit and nothing else. The prohibition list is the policy, so it is written
# once here and asserted in the tests: a platform that can only squash is refused, not downgraded.
FORBIDDEN_FLAGS="--admin --delete-branch --squash --rebase --ff-only --auto"

cli_merge() {
  case "$1" in
    github) printf 'gh pr merge %s --merge' "$2" ;;
    gitlab) printf 'glab mr merge %s --yes' "$2" ;;
    gitea)  printf 'tea pr merge %s' "$2" ;;
    *) return 1 ;;
  esac
}

# Prints "<method> <path> <json-body>". The three parts are always returned together, and the
# caller splits them once: an earlier shape returned "PUT <path> <body>" and every caller had to
# strip the body back off the path, which is how the body ended up inside the request URL.
rest_merge() {
  local p="$1" host="$2" id="$3" proj
  proj="$(url_encode "$4")"
  case "$p" in
    github)    printf 'PUT /repos/%s/pulls/%s/merge {"merge_method":"merge"}' "$4" "$id" ;;
    gitlab)    printf 'PUT /projects/%s/merge_requests/%s/merge {"squash":false}' "$proj" "$id" ;;
    gitea)     printf 'POST /repos/%s/pulls/%s/merge {"Do":"merge"}' "$4" "$id" ;;
    bitbucket) printf 'POST /repositories/%s/pullrequests/%s/merge {}' "$4" "$id" ;;
    *) return 1 ;;
  esac
}

# --- reports --------------------------------------------------------------------------------------
# A handoff report: what was found, what the agent has to do, and that the harness did not do it.
handoff_report() {
  local platform="$1" ref="$2" host="$3" proj="$4" id="$5" skill=""
  printf 'forge: platform=%s host=%s project=%s id=%s\n' "$platform" "${host:-<none>}" "${proj:-<none>}" "${id:-<none>}"
  if skill="$(find_project_skill "$platform" 2>/dev/null)"; then
    printf 'forge: mechanism=skill detail=%s\n' "$skill"
    printf 'forge: the project defines its own procedure for this forge - follow it, and do not use a\n'
    printf 'forge: generic command instead. If its method conflicts with the harness merge-commit\n'
    printf 'forge: policy, say so and let the developer choose.\n'
  fi
  if probe_rest "$platform" "$host" 2>/dev/null; then
    printf 'forge: mechanism=rest detail=%s (needs a real read to be usable)\n' "$MECH_DETAIL"
  fi
  if probe_cli "$platform" "$host" 2>/dev/null; then
    printf 'forge: mechanism=cli detail=%s (needs a real read to be usable)\n' "$MECH_DETAIL"
  fi
  if m="$(find_mcp_server "$platform" 2>/dev/null)"; then
    printf 'forge: mechanism=mcp config=%s server=%s\n' "${m%%|*}" "${m##*|}"
    printf 'forge: a shell script cannot call an MCP tool. Read this PR'"'"'s state and reviews with that\n'
    printf 'forge: server'"'"'s own tools, apply the same rule (at least one approving review, no\n'
    printf 'forge: reviewer'"'"'s latest review requesting changes), and merge only on an explicit yes.\n'
  fi
  printf 'forge: the harness cannot read this pull request, so it cannot verify an approval and will not merge it.\n'
  printf 'forge: Nothing was merged.\n'
}

paste_report() {
  local platform="$1" ref="$2" host="$3" proj="$4" id="$5" url=""
  case "$platform" in
    github)    url="https://github.com/$proj/pull/$id" ;;
    gitlab)    url="https://$host/$proj/-/merge_requests/$id" ;;
    bitbucket) url="https://$host/$proj/pull-requests/$id" ;;
    gitea)     url="https://$host/$proj/pulls/$id" ;;
    *)         url="$ref" ;;
  esac
  printf '\n--- forge ---\n%s (%s)\n--- pull request ---\n%s\n' "${platform:-unknown}" "${host:-<none>}" "${url:-$ref}"
  printf -- '--- what to check yourself ---\n'
  printf '1. at least one approving review, and no reviewer whose latest review requests changes\n'
  printf '2. the PR is still open and has no conflicts\n'
  printf '3. merge with a MERGE COMMIT (no squash, no rebase)\n'
  printf -- '--- how ---\n'
  if cmd="$(cli_merge "$platform" "$id" 2>/dev/null)"; then
    printf '%s\n' "$cmd"
  else
    printf 'merge it in %s'"'"'s web UI, or with the MCP server / CLI your project already configures\n' "$platform"
  fi
}

# --- argument parsing ------------------------------------------------------------------------------
cmd="${1:-}"
[ -n "$cmd" ] || usage
case "$cmd" in
  resolve|probe|state|reviews|merge|paste) shift ;;
  issues) shift ;;
  -h|--help) print_usage; exit 0 ;;
  *) echo "forge: unknown subcommand: $cmd" >&2; usage ;;
esac

FORGE_OVERRIDE=""; ref_arg=""; explain=0; searches=""; repo_override=""
while [ $# -gt 0 ]; do
  case "$1" in
    --forge)  [ -n "${2:-}" ] || usage; FORGE_OVERRIDE="$2"; shift 2 ;;
    --search) [ -n "${2:-}" ] || usage; searches="$searches$2
"; shift 2 ;;
    # --repo is for `issues`, where the board may be a different repository than the current one.
    # It never overrides the PLATFORM: --repo says which board, --forge says which forge.
    --repo)
      case "$cmd" in
        issues) [ -n "${2:-}" ] || usage; repo_override="$2"; shift 2 ;;
        *) echo "forge: unknown option: $1" >&2; usage ;;
      esac ;;
    --explain) explain=1; shift ;;
    -*) echo "forge: unknown option: $1" >&2; usage ;;
    *) ref_arg="$1"; shift ;;
  esac
done

need_ref() {
  [ -n "$ref_arg" ] || { echo "forge: $cmd needs a PR ref - the intent's 'pr:' value, or a number" >&2; exit 2; }
}

not_done() { echo "forge: $1" >&2; exit 3; }

# --- subcommands -----------------------------------------------------------------------------------
case "$cmd" in
  resolve)
    if [ -n "$ref_arg" ]; then
      st=0; normalize_ref "$ref_arg" || st=$?
      [ "$st" -eq 2 ] && { echo "forge: '$ref_arg' is not a PR ref this harness can read" >&2; exit 2; }
    fi
    resolve_forge "$ref_arg" || true
    printf 'forge: platform=%s host=%s project=%s id=%s source=%s\n' \
      "$PLATFORM" "${HOST:-<none>}" "${PROJECT:-<none>}" "${PRID:-<none>}" "$SOURCE"
    [ "$PLATFORM" = "unknown" ] && exit 3
    exit 0
    ;;

  probe)
    resolve_forge "$ref_arg" || true
    printf 'forge: platform=%s host=%s project=%s id=%s source=%s\n' \
      "$PLATFORM" "${HOST:-<none>}" "${PROJECT:-<none>}" "${PRID:-<none>}" "$SOURCE"
    [ "$PLATFORM" = "unknown" ] && not_done "the forge could not be resolved - pass --forge, or ask the developer which host this project uses"
    if probe_read "$PLATFORM" "$HOST"; then
      printf 'forge: probe result=usable mechanism=%s detail=%s\n' "$MECHANISM" "$MECH_DETAIL"
      exit 0
    fi
    agent_only=""
    if s="$(find_project_skill "$PLATFORM" 2>/dev/null)"; then
      printf 'forge: probe result=agent-only mechanism=skill detail=%s\n' "$s"
      agent_only="skill"
    fi
    if m="$(find_mcp_server "$PLATFORM" 2>/dev/null)"; then
      printf 'forge: probe result=agent-only mechanism=mcp config=%s server=%s\n' "${m%%|*}" "${m##*|}"
      agent_only="mcp"
    fi
    if [ -z "$agent_only" ]; then
      printf 'forge: probe result=none\n'
    else
      # A rung the script cannot drive is still worth reporting, but the caller has to know the
      # difference: it must act itself, and it must not read the harness's silence as a merge.
      printf 'forge: the script cannot reach this pull request, so it cannot verify an approval and will not merge it.\n'
      printf 'forge: read the PR with the mechanism above using your own tools, apply the same rule\n'
      printf 'forge: (at least one approving review, no reviewer latest review requesting changes), and\n'
      printf 'forge: merge only on an explicit answer. Nothing was merged.\n'
    fi
    not_done "no mechanism the script can use to reach $PLATFORM"
    ;;

  state|reviews)
    need_ref
    st=0; normalize_ref "$ref_arg" || st=$?
    [ "$st" -eq 1 ] && { echo "forge: '$ref_arg' names no pull request" >&2; exit 2; }
    [ "$st" -eq 2 ] && { echo "forge: '$ref_arg' is not a PR ref this harness can read" >&2; exit 2; }
    resolve_forge "$ref_arg" || true
    [ "$PLATFORM" = "unknown" ] && not_done "the forge of '$ref_arg' could not be resolved - pass --forge or ask the developer"
    [ -n "$PRID" ] || { echo "forge: '$ref_arg' names a repository, not a pull request - this subcommand needs the PR" >&2; exit 2; }
    [ -n "$PROJECT" ] || not_done "no repository for this pull request - the 'origin' remote is missing, so pass a ref like owner/name#$PRID or the PR URL"
    if ! probe_read "$PLATFORM" "$HOST"; then
      handoff_report "$PLATFORM" "$ref_arg" "$HOST" "$PROJECT" "$PRID"
      not_done "the harness cannot read PR $PRID on $PLATFORM"
    fi
    if [ "$cmd" = "state" ]; then
      line=""
      case "$MECHANISM" in
        cli)  line="$(cli_state "$PLATFORM" "$PRID" "$PROJECT" || true)" ;;
        rest) line="$(rest_state "$PLATFORM" "$HOST" "$PRID" "$PROJECT" || true)" ;;
      esac
      case "$line" in state=*) printf 'forge: %s mechanism=%s\n' "$line" "$MECHANISM" ;;
        *) not_done "PR $PRID on $PLATFORM could not be read through $MECHANISM - the ref or the credentials may be wrong" ;;
      esac
      exit 0
    fi
    rows=""
    case "$MECHANISM" in
      cli)  rows="$(cli_reviews "$PLATFORM" "$PRID" "$PROJECT" || true)" ;;
      rest) rows="$(rest_reviews "$PLATFORM" "$HOST" "$PRID" "$PROJECT" || true)" ;;
    esac
    why=""
    if [ -n "$rows" ]; then
      why="$(validate_reviews "$rows" || true)"
      if [ -n "$why" ]; then
        printf 'forge: %s\n' "$why" >&2
      fi
    fi
    if [ -n "$rows" ] && [ -n "$why" ]; then
      not_done "PR $PRID on $PLATFORM returned a review list this harness cannot read - that is a broken read, not an empty one, so it is not an approval"
    fi
    # Latest per reviewer, by timestamp rather than by position: a platform's ordering is not a
    # contract, and a reviewer who approved on Monday and asked for changes on Tuesday has not
    # approved this PR. Doing it here - once, for every rung - is what keeps the gate and the merge
    # reading the same board.
    printf '%s' "$rows" | latest_per_reviewer
    exit 0
    ;;

  issues)
    resolve_forge "$ref_arg" || true
    [ "$PLATFORM" = "unknown" ] && not_done "the forge could not be resolved - pass --forge, or ask the developer"
    [ -n "$PROJECT" ] || not_done "no repository to read issues from - the 'origin' remote is missing, so pass a repository URL or --forge"
    if ! probe_read "$PLATFORM" "$HOST"; then
      printf 'forge: platform=%s host=%s project=%s\n' "$PLATFORM" "${HOST:-<none>}" "$PROJECT"
      not_done "the harness cannot read issues on $PLATFORM - whether the work is already filed is UNKNOWN, not empty"
    fi
    proj="$(url_encode "$PROJECT")"
    total=0; out=""
    saved_ifs="$IFS"; IFS='
'
    # Intent terms are free text, so they are matched as substrings, not as regexes: a term like
    # "login (v2)" is a title fragment, and jq would treat the parentheses as a group.
    for term in $searches; do
      case "$MECHANISM:$PLATFORM" in
        cli:github)
          rows="$(gh issue list --repo "$PROJECT" --state open --search "$term" --limit 20 \
            -q '.[] | "#\(.number)\t\(.title)\t\(.url)"' 2>/dev/null)" || not_done "gh issue list failed for '$term'" ;;
        rest:github)
          rows="$(rest_get "$PLATFORM" "$HOST" "/repos/$PROJECT/issues?state=open&per_page=20" 2>/dev/null \
            | jq -r --arg t "$term" '.[] | select(((.title // "") | ascii_downcase) | contains($t | ascii_downcase)) | "#\(.number)\t\(.title)\t\(.html_url)"' 2>/dev/null)" \
            || not_done "GitHub issue read failed for '$term'" ;;
        rest:gitlab)
          rows="$(rest_get "$PLATFORM" "$HOST" "/projects/$proj/issues?state=opened&search=$term&per_page=20" 2>/dev/null \
            | jq -r 'if type == "array" then .[] | "#\(.iid)\t\(.title)\t\(.web_url)" else empty end' 2>/dev/null)" \
            || not_done "GitLab issue read failed for '$term'" ;;
        rest:gitea)
          rows="$(rest_get "$PLATFORM" "$HOST" "/repos/$PROJECT/issues?state=open&q=$term&limit=20" 2>/dev/null \
            | jq -r 'if type == "array" then .[] | "#\(.number)\t\(.title)\t\(.html_url)" else empty end' 2>/dev/null)" \
            || not_done "Gitea issue read failed for '$term'" ;;
        rest:bitbucket)
          rows="$(rest_get "$PLATFORM" "$HOST" "/repositories/$PROJECT/issues?limit=20" 2>/dev/null \
            | jq -r --arg t "$term" 'if type == "array" then .[] | select(((.title // "") | ascii_downcase) | contains($t | ascii_downcase)) | "#\(.id)\t\(.title)\t\(.links.self.href)" else empty end' 2>/dev/null)" \
            || not_done "Bitbucket issue read failed for '$term'" ;;
        *) not_done "listing issues on $PLATFORM is not implemented through $MECHANISM" ;;
      esac
      [ -n "$rows" ] && out="$out$rows"$'\n'
    done
    IFS="$saved_ifs"
    out="$(printf '%s' "$out" | grep -v '^[[:space:]]*$' | awk -F'\t' '!seen[$1]++' || true)"
    total="$(printf '%s' "$out" | grep -c . || true)"
    [ -n "$total" ] || total=0
    printf 'forge: open-match count=%s platform=%s target=%s terms=%s\n' \
      "$total" "$PLATFORM" "$PROJECT" "$(printf '%s' "$searches" | tr '\n' ' ' | sed -e 's/ $//')"
    [ "$total" -eq 0 ] || printf '%s\n' "$out"
    exit 0
    ;;

  merge)
    need_ref
    st=0; normalize_ref "$ref_arg" || st=$?
    [ "$st" -eq 1 ] && { echo "forge: '$ref_arg' names no pull request" >&2; exit 2; }
    [ "$st" -eq 2 ] && { echo "forge: '$ref_arg' is not a PR ref this harness can read" >&2; exit 2; }
    resolve_forge "$ref_arg" || true
    [ "$PLATFORM" = "unknown" ] && not_done "the forge of '$ref_arg' could not be resolved - pass --forge or ask the developer"
    [ -n "$PRID" ] || { echo "forge: '$ref_arg' names a repository, not a pull request" >&2; exit 2; }
    [ -n "$PROJECT" ] || not_done "no repository for this pull request - pass a ref like owner/name#$PRID or the PR URL"
    if ! probe_read "$PLATFORM" "$HOST"; then
      handoff_report "$PLATFORM" "$ref_arg" "$HOST" "$PROJECT" "$PRID"
      paste_report "$PLATFORM" "$ref_arg" "$HOST" "$PROJECT" "$PRID"
      not_done "PR $PRID on $PLATFORM was NOT merged - the harness cannot read it, so it cannot verify an approval"
    fi
    # State first, approval second: an already-merged PR is a no-op whatever its reviews say, which is
    # what makes this command safe to repeat.
    line=""
    case "$MECHANISM" in
      cli)  line="$(cli_state "$PLATFORM" "$PRID" "$PROJECT" || true)" ;;
      rest) line="$(rest_state "$PLATFORM" "$HOST" "$PRID" "$PROJECT" || true)" ;;
    esac
    # Upper-case once here, so every rung compares against the same vocabulary no matter how its
    # own API spelled the state ("opened", "OPEN", "open", "OPENED" are one value, not four).
    pr_state="$(printf '%s' "$line" | sed -n 's/.*state=\([A-Za-z_]*\).*/\1/p' | tr '[:lower:]' '[:upper:]')"
    [ -n "$pr_state" ] || not_done "PR $PRID on $PLATFORM could not be read through $MECHANISM - nothing merged"
    if [ "$pr_state" = "MERGED" ]; then
      printf 'forge: PR %s on %s is already merged; nothing to do\n' "$PRID" "$PLATFORM"
      exit 0
    fi
    case "$pr_state" in
      OPEN|OPENED) : ;;
      *) echo "forge: PR $PRID on $PLATFORM is ${pr_state:-<unknown>}, not open; nothing merged" >&2; exit 1 ;;
    esac
    case "$line" in
      *mergeable=CONFLICTING*) echo "forge: PR $PRID on $PLATFORM has conflicts; nothing merged - this command never forces a merge" >&2; exit 1 ;;
    esac
    # Build the request once. Splitting the plan and the request apart let the two drift, which is
    # how a JSON body ended up appended to the URL.
    mreq="$(rest_merge "$PLATFORM" "$HOST" "$PRID" "$PROJECT" || true)"
    plan=""
    case "$MECHANISM" in
      cli)  plan="$(cli_merge "$PLATFORM" "$MERGE_REF" || true)" ;;
      rest)
        [ -n "$mreq" ] || not_done "no merge request is defined for $PLATFORM - nothing merged"
        m_method="${mreq%% *}"; m_rest="${mreq#* }"
        m_path="${m_rest%% *}"; m_body="${m_rest#* }"
        # The body is re-wrapped: rest_merge prints it as JSON so the --explain line can show it.
        m_body="{$m_body}"
        plan="curl -X $m_method <base>$m_path -d $m_body" ;;
    esac
    [ -n "$plan" ] || not_done "no merge command is defined for $PLATFORM - nothing merged"
    if [ "$explain" -eq 1 ]; then
      printf 'forge: would merge PR %s on %s via %s: %s\n' "$PRID" "$PLATFORM" "$MECHANISM" "$plan"
      exit 0
    fi
    case "$MECHANISM" in
      cli)
        # shellcheck disable=SC2086
        out="$(eval "$plan" 2>&1)" || {
          printf 'forge: the merge command failed, PR %s is still open:\n%s\n' "$PRID" "$(printf '%s' "$out" | head -3)" >&2
          exit 1
        } ;;
      rest)
        var="$(token_var "$PLATFORM")"; base="$(api_base "$PLATFORM" "$HOST")"
        out="$(eval "curl -sS --max-time 30 -X $m_method -H \"Authorization: Bearer \$$var\" -H 'Content-Type: application/json' -d '$m_body' \"$base$m_path\"" 2>&1)" || {
          printf 'forge: the merge request failed, PR %s is still open:\n%s\n' "$PRID" "$(printf '%s' "$out" | head -3)" >&2
          exit 1
        }
        # A 2xx is not a merge. The response itself has to say so, or the harness reports the truth:
        # still open, nothing merged.
        case "$out" in
          *'"state":"merged"'*|*'"state": "merged"'*|*'"merged":true'*|*'"merged": true'*|*'"merged_at"'*) : ;;
          *) printf 'forge: %s did not confirm the merge of PR %s; it is still open:\n%s\n' \
               "$PLATFORM" "$PRID" "$(printf '%s' "$out" | head -3)" >&2; exit 1 ;;
        esac ;;
    esac
    printf 'forge: merged PR %s on %s via %s: %s\n' "$PRID" "$PLATFORM" "$MECHANISM" "$plan"
    exit 0
    ;;

  paste)
    need_ref
    normalize_ref "$ref_arg" >/dev/null 2>&1 || true
    resolve_forge "$ref_arg" || true
    paste_report "$PLATFORM" "$ref_arg" "$HOST" "$PROJECT" "$PRID"
    exit 0
    ;;
esac
