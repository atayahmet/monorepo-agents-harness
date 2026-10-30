#!/usr/bin/env bash
# team-infer.sh - read-only draft for `/monorepo-harness-team init`. Prints what the repo itself can
# say about the team. EVERYTHING IT PRINTS IS A SUGGESTION: git history lists people who left and
# misses people who never commit (a manager, a product owner), so the developer decides who is a
# member, a contact, or neither. It writes no file and never creates .agents/team.yml.
#
# Usage (from anywhere inside the target repo):
#   team-infer.sh [--since <git date>] [--stale-days <n>]
#
#   --since <d>       how far back to read commit authors (default "6 months ago"; any date git accepts)
#   --stale-days <n>  flag a person whose last commit is older than n days (default 60)
#
# Output, tab-separated, one record per line:
#   workspace<TAB><path from the repo root>
#   person<TAB><email><TAB><names, |-joined><TAB><commits><TAB><last commit YYYY-MM-DD><TAB><flags>
#   owners<TAB><workspace path><TAB><@owner,@owner>          (from CODEOWNERS, directories only)
# flags (comma-separated, may be empty): bot | stale | github=<login> (from a noreply email)
# People are grouped by lower-cased email, so one email under two names is one person.
#
# Exit codes: 0 done (also when there is nothing to read) | 2 usage error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2; exit 2; }

since="6 months ago"; stale_days=60
while [ $# -gt 0 ]; do
  case "$1" in
    --since)      [ -n "${2:-}" ] || usage; since="$2"; shift 2 ;;
    --stale-days) [ -n "${2:-}" ] || usage; stale_days="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *)            echo "team-infer: unknown argument: $1" >&2; usage ;;
  esac
done
case "$stale_days" in ''|*[!0-9]*) echo "team-infer: --stale-days needs a number" >&2; usage ;; esac

# --- workspaces: the framework detector's parent dirs, one level down -------------------------------
workspaces() {
  local parent p d
  shopt -s nullglob
  while IFS= read -r parent; do
    [ -n "$parent" ] || continue
    for p in $parent; do
      [ -d "$p" ] || continue
      for d in "$p"/*/; do
        d="${d%/}"; d="${d#"$ROOT"/}"
        case "$d" in */node_modules|node_modules|.*|*/.*) continue ;; esac
        printf '%s\n' "$d"
      done
    done
  done < <(cd "$ROOT" && bash "$SCRIPT_DIR/detect-monorepo-framework.sh" --workspaces 2>/dev/null || true)
}
ws_list="$(workspaces | sort -u)"
[ -z "$ws_list" ] || printf '%s\n' "$ws_list" | sed 's/^/workspace\t/'

# --- people: commit authors in the window -------------------------------------------------------------
now_epoch="$(date +%s)"
git -C "$ROOT" log --since="$since" --format='%aE%x09%aN%x09%at' 2>/dev/null \
  | awk -F'\t' -v now="$now_epoch" -v stale="$stale_days" '
      function flags(email, name,   f, l) {
        f = ""
        if (name ~ /\[bot\]/ || email ~ /\[bot\]/ || tolower(name) ~ /(dependabot|renovate|github-actions)/ || email ~ /(^|[^a-z])bot@/) f = "bot"
        if ((now - last[email]) > stale * 86400) f = f (f == "" ? "" : ",") "stale"
        if (email ~ /@users\.noreply\.github\.com$/) {
          l = email; sub(/@users\.noreply\.github\.com$/, "", l); sub(/^[0-9]+\+/, "", l)
          if (l !~ /\[bot\]/) f = f (f == "" ? "" : ",") "github=" l
        }
        return f
      }
      {
        e = tolower($1)
        if (!(e in cnt)) { order[++n] = e; names[e] = "" }
        cnt[e]++
        if ($3 > last[e]) last[e] = $3
        if (index("|" names[e] "|", "|" $2 "|") == 0) names[e] = names[e] (names[e] == "" ? "" : "|") $2
      }
      END {
        for (i = 1; i <= n; i++) {
          e = order[i]
          d = strftime_day(last[e])
          printf "person\t%s\t%s\t%d\t%s\t%s\n", e, names[e], cnt[e], d, flags(e, names[e])
        }
      }
      function strftime_day(t,   cmd, out) {
        cmd = "date -u -r " t " +%Y-%m-%d 2>/dev/null || date -u -d @" t " +%Y-%m-%d"
        cmd | getline out; close(cmd); return out
      }
    ' \
  | sort -t$'\t' -k4,4nr -k2,2

# --- CODEOWNERS: directory ownership seeds ----------------------------------------------------------
for f in CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS; do
  [ -f "$ROOT/$f" ] || continue
  tr -d '\r' < "$ROOT/$f" | awk '
      /^[ \t]*(#|$)/ { next }
      { pat = $1; owners = ""; for (i = 2; i <= NF; i++) { if ($i ~ /^#/) break; owners = owners (owners == "" ? "" : ",") $i }
        sub(/^\//, "", pat); sub(/\/(\*\*|\*)?$/, "", pat)
        if (pat == "" || pat ~ /[*?\[]/ || owners == "") next
        print pat "\t" owners }
    ' | while IFS=$'\t' read -r path owners; do
      if [ -d "$ROOT/$path" ]; then printf 'owners\t%s\t%s\n' "$path" "$owners"; fi
    done
  break
done
exit 0
