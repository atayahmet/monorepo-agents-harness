#!/usr/bin/env bash
# team.sh - read-only lookup for the team registry, <repo-root>/.agents/team.yml.
#
# The registry is consumer-owned data (people, roles, platform IDs, workspace -> assignee routing);
# this script only reads it. Format and rules: core/team/AGENTS.md. Nothing here writes a file.
#
# Usage (from anywhere inside the target repo):
#   team.sh whoami [--email <e>] [--json]    the entry whose ids.git matches `git config user.email`
#   team.sh get <key> [<field>|ids.<platform>]   name | role | title | kind | ids.<platform>
#   team.sh find --role <role> [--kind members|contacts] [--json]
#   team.sh resolve <platform> <id> [--json]     reverse lookup; platform may also be `key` or `name`
#   team.sh match ...                            alias of resolve
#   team.sh assignee <workspace> [--json]        member keys for a workspace dir, or `ask`
#   team.sh lint                                 errors exit 1; warnings go to stderr, exit 0
#   team.sh refs <key>                           forward-looking files that mention this person
#
# whoami/resolve print 'key<TAB>name<TAB>kind' (kind = members|contacts).
#
# Exit codes: 0 ok | 1 lint error | 2 usage | 3 not found / undetermined (ask, never guess) |
#             4 no registry (fall back to today's behavior) | 5 registry unreadable (report it).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REG="$ROOT/.agents/team.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "team.sh: $1" >&2; exit "${2:-1}"; }
normalize_path() { local p="$1"; p="${p#./}"; p="${p%/}"; [ -z "$p" ] && p="."; printf '%s\n' "$p"; }

# jesc <text> - escape backslashes and double quotes for a JSON string.
jesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# json_list - read lines on stdin, print a JSON string array.
json_list() { awk 'BEGIN{printf "["} NF{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); printf "%s\"%s\"", (n++?",":""), $0} END{print "]"}'; }

# Shared awk helpers: trim, unquote, glob match. '*' stays inside one path segment, '**' crosses them.
AWK_LIB='
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function val(s,   q, i, c, n, out) {
  s = trim(s); q = substr(s, 1, 1); n = length(s); out = ""
  if (q == "\"") {
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\" && i < n) { i++; c = substr(s, i, 1); if (c != "\"" && c != "\\") c = "\\" c }
      else if (c == "\"") break
      out = out c
    }
    return out
  }
  if (q == "\047") {
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\047") { if (substr(s, i + 1, 1) == "\047") { out = out c; i++ } else break }
      else out = out c
    }
    return out
  }
  sub(/[ \t]+#.*$/, "", s); return trim(s)
}
function ci(p) { p = tolower(p); return p == "git" || p == "github" || p == "gitlab" || p == "bitbucket" }
function norm(p, v) { return ci(p) ? tolower(v) : v }
function segmatch(pat, seg,   re) {
  re = pat
  gsub(/[][\\.+?(){}^$|]/, "\\\\&", re)
  gsub(/\*/, "[^/]*", re)
  return seg ~ ("^" re "$")
}
function gm(P, pn, pi, S, sn, si,   k) {
  if (pi > pn) return si > sn
  if (P[pi] == "**") { for (k = si; k <= sn + 1; k++) if (gm(P, pn, pi + 1, S, sn, k)) return 1; return 0 }
  if (si > sn || !segmatch(P[pi], S[si])) return 0
  return gm(P, pn, pi + 1, S, sn, si + 1)
}
function globmatch(pat, path,   P, S, pn, sn) {
  if (pat == path) return 1
  pn = split(pat, P, "/"); sn = split(path, S, "/")
  return gm(P, pn, 1, S, sn, 1)
}
'

# parse_registry - print the registry as TSV records, one per line:
#   VERSION n | ITEM id kind key | NAME id v | ROLE id v | TITLE id v | ID id platform v
#   ASGN workspace comma-keys | ERR lineno message
# Supported YAML subset: top-level version/members/contacts/assignee_by_workspace, `- key:` entries,
# scalar fields, `ids:` as a block map (values: scalar, [a, b], or a `- item` block list) or a one-line
# { a: b } map, and assignee values as [a, b] / [] / a scalar / a `- key` block list. Anything else
# inside those sections is an ERR (exit 5), never a guess.
parse_registry() {
  awk "$AWK_LIB"'
    function err(m) { printf "ERR\t%d\t%s\n", NR, m }
    function indent(s) { match(s, /^[ \t]*/); return RLENGTH }
    function emit_id(p, v) { v = val(v); if (v != "") printf "ID\t%d\t%s\t%s\n", id, p, v }
    function emit_list(p, s,   n, a, i) {
      n = split(s, a, ",")
      for (i = 1; i <= n; i++) emit_id(p, a[i])
    }
    function normws(w) { w = trim(w); while (w ~ /^\.\//) sub(/^\.\//, "", w); sub(/\/+$/, "", w); return w == "" ? "." : w }
    function asgn_add(w, s,   n, a, i, v) {
      if (!(w in aseen)) { aseen[w] = 1; aorder[++an] = w; alist[w] = "" }
      n = split(s, a, ",")
      for (i = 1; i <= n; i++) { v = val(a[i]); if (v != "") alist[w] = alist[w] (alist[w] == "" ? "" : ",") v }
    }
    BEGIN { sec = ""; id = 0; seen = 0; ids_ind = -1; plat = ""; cur_ws = "" }
    { sub(/\r$/, "") }
    /^---[ \t]*$/ { if (seen) exit; next }
    /^[ \t]*(#.*)?$/ { next }
    { seen = 1 }
    /^[A-Za-z_]/ {
      k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[ \t]*/, "", v); v = val(v)
      sec = ""; ids_ind = -1; plat = ""; cur_ws = ""
      if (k == "version") { printf "VERSION\t%s\n", v; sec = "version" }
      else if (k == "members" || k == "contacts") { sec = k; if (v != "" && v != "[]") err("unsupported value for " k) }
      else if (k == "assignee_by_workspace") { sec = "assignee"; if (v != "" && v != "{}") err("unsupported value for " k) }
      else { printf "TOP\t%s\n", k; sec = "ignore" }
      next
    }
    sec == "members" || sec == "contacts" {
      ind = indent($0); line = $0; sub(/^[ \t]+/, "", line)
      if (ids_ind >= 0 && ind <= ids_ind && line !~ /^-[ \t]+/) { ids_ind = -1; plat = "" }
      if (ids_ind >= 0 && ind > ids_ind) {
        if (line ~ /^-[ \t]+/) {
          if (plat == "") { err("list item outside an ids platform"); next }
          s = line; sub(/^-[ \t]+/, "", s); emit_id(plat, s); next
        }
        if (line ~ /^[A-Za-z0-9_.-]+:/) {
          p = line; sub(/:.*/, "", p); v = line; sub(/^[^:]*:[ \t]*/, "", v); v = trim(v); plat = p
          if (v == "") next
          if (v ~ /^\[/) { sub(/^\[/, "", v); sub(/\].*$/, "", v); emit_list(p, v) } else emit_id(p, v)
          next
        }
        err("unsupported syntax under ids"); next
      }
      if (line ~ /^-[ \t]+key:/) {
        id++; s = line; sub(/^-[ \t]+key:[ \t]*/, "", s); printf "ITEM\t%d\t%s\t%s\n", id, sec, val(s)
        ids_ind = -1; plat = ""; next
      }
      if (line ~ /^-/) { err("entry must start with `- key:`"); next }
      if (id == 0) { err("field before the first `- key:`"); next }
      if (line ~ /^name:/)  { s = line; sub(/^name:[ \t]*/, "", s);  printf "NAME\t%d\t%s\n", id, val(s); next }
      if (line ~ /^role:/)  { s = line; sub(/^role:[ \t]*/, "", s);  printf "ROLE\t%d\t%s\n", id, val(s); next }
      if (line ~ /^title:/) { s = line; sub(/^title:[ \t]*/, "", s); printf "TITLE\t%d\t%s\n", id, val(s); next }
      if (line ~ /^ids:/) {
        s = line; sub(/^ids:[ \t]*/, "", s); s = trim(s)
        if (s == "") { ids_ind = ind; plat = ""; next }
        if (s ~ /^\{.*\}/) {
          sub(/^\{/, "", s); sub(/\}.*$/, "", s); n = split(s, pairs, ",")
          for (i = 1; i <= n; i++) {
            if (trim(pairs[i]) == "") continue
            p = pairs[i]; sub(/:.*/, "", p); v = pairs[i]; sub(/^[^:]*:[ \t]*/, "", v)
            emit_id(trim(p), v)
          }
          next
        }
        err("ids must be a block map or a one-line { } map"); next
      }
      err("unsupported syntax: " line); next
    }
    sec == "assignee" {
      line = $0; sub(/^[ \t]+/, "", line)
      if (line ~ /^-[ \t]+/ && cur_ws != "") { s = line; sub(/^-[ \t]+/, "", s); if (val(s) !~ /^[A-Za-z0-9_.-]+$/) { err("assignee list items must be member keys: " line); next } asgn_add(cur_ws, s); next }
      if (line !~ /:/) { err("unsupported syntax: " line); next }
      w = line; if (w ~ /^["\047]/) { q = substr(w, 1, 1); w = substr(w, 2); w = substr(w, 1, index(w, q) - 1); rest = line; sub(/^["\047][^"\047]*["\047]:?[ \t]*/, "", rest) }
      else { w = line; sub(/:[ \t].*$|:$/, "", w); rest = line; sub(/^[^:]*:[ \t]*/, "", rest) }
      w = normws(w); rest = trim(rest); cur_ws = w
      if (rest == "") { asgn_add(w, ""); next }
      if (rest ~ /^\[/) { sub(/^\[/, "", rest); sub(/\].*$/, "", rest); asgn_add(w, rest); next }
      if (rest ~ /^[A-Za-z0-9_.-]+([ \t]+#.*)?$/) { asgn_add(w, rest); next }
      err("assignee values must be [a, b], [] or a block list: " line); next
    }
    sec == "ignore" { next }
    sec == "version" { err("unsupported syntax: " $0); next }
    sec == "" { err("unsupported syntax before a known section: " $0); next }
    END { for (i = 1; i <= an; i++) printf "ASGN\t%s\t%s\n", aorder[i], alist[aorder[i]] }
  ' "$REG"
}

DATA=""
# load - read the registry once. Exit 4 if absent, 5 if it is not a v1 registry.
load() {
  [ -f "$REG" ] || die "no registry at .agents/team.yml - fall back to current behavior (set it up with /monorepo-harness-team)" 4
  DATA="$(parse_registry)"
  local errs ver tops
  errs="$(awk -F'\t' '$1=="ERR"{printf "  line %s: %s\n",$2,$3}' <<< "$DATA")"
  [ -z "$errs" ] || die "cannot read .agents/team.yml (unsupported syntax):
$errs" 5
  ver="$(awk -F'\t' '$1=="VERSION"{print $2; exit}' <<< "$DATA")"
  if [ -z "$ver" ]; then
    tops="$(awk -F'\t' '$1=="TOP"{printf "%s ",$2}' <<< "$DATA")"
    die "cannot read .agents/team.yml: no 'version: 1' (another shape? top-level keys: ${tops:-none}). Do not overwrite it - run /monorepo-harness-team migrate" 5
  fi
  [ "$ver" = "1" ] || die "cannot read .agents/team.yml: unsupported version '$ver'" 5
}

cmd_whoami() {
  local email="" json=0
  while [ $# -gt 0 ]; do case "$1" in --email) [ $# -ge 2 ] || usage; email="$2"; shift 2;; --json) json=1; shift;; *) usage;; esac; done
  load
  [ -n "$email" ] || email="$(git -C "$ROOT" config user.email 2>/dev/null || true)"
  [ -n "$email" ] || die "no git user.email configured - ask the developer who they are" 3
  emit_match git "$email" "$json"
}

# emit_match <platform> <id> <json> - print the first matching entry or exit 3. The platform may
# also be `key` or `name`, so a free-text intent author can be mapped back to a registry key.
emit_match() {
  local plat="$1" want="$2" json="$3" rk rn rkind
  rk="$(awk -F'\t' -v p="$plat" -v w="$want" "$AWK_LIB"'
    BEGIN { pl = tolower(p); lw = tolower(w) }
    $1=="ITEM" { id = $2; k = $4 }
    pl=="key"  && $1=="ITEM" && tolower($4)==lw { print k; exit }
    pl=="name" && $1=="NAME" && tolower($3)==lw { print k; exit }
    $1=="ID" && $2==id && tolower($3)==pl && norm(pl, $4)==norm(pl, w) { print k; exit }
  ' <<< "$DATA")"
  [ -n "$rk" ] || exit 3
  rn="$(awk -F'\t' -v k="$rk" '$1=="ITEM"{on=($4==k)} on && $1=="NAME"{print $3; exit}' <<< "$DATA")"
  rkind="$(awk -F'\t' -v k="$rk" '$1=="ITEM" && $4==k{print $3; exit}' <<< "$DATA")"
  if [ "$json" -eq 1 ]; then
    printf '{"key":"%s","name":"%s","kind":"%s"}\n' "$(jesc "$rk")" "$(jesc "$rn")" "$(jesc "$rkind")"
  else
    printf '%s\t%s\t%s\n' "$rk" "$rn" "$rkind"
  fi
}

cmd_resolve() {
  [ $# -ge 2 ] || usage
  local plat="$1" id="$2" json=0; shift 2
  while [ $# -gt 0 ]; do case "$1" in --json) json=1; shift;; *) usage;; esac; done
  load
  emit_match "$plat" "$id" "$json"
}

cmd_find() {
  local role="" kind="" json=0
  while [ $# -gt 0 ]; do case "$1" in --role) [ $# -ge 2 ] || usage; role="$2"; shift 2;; --kind) [ $# -ge 2 ] || usage; kind="$2"; shift 2;; --json) json=1; shift;; *) usage;; esac; done
  [ -n "$role" ] || usage
  load
  local res
  res="$(awk -F'\t' -v r="$role" -v kd="$kind" '
    $1=="ITEM"{ id=$2; k=$4; ik=$3 }
    $1=="ROLE" && $2==id && tolower($3)==tolower(r) && (kd=="" || ik==kd) { print k }
  ' <<< "$DATA")"
  [ -n "$res" ] || exit 3
  if [ "$json" -eq 1 ]; then printf '%s\n' "$res" | json_list; else printf '%s\n' "$res"; fi
}

cmd_get() {
  [ $# -ge 1 ] || usage
  local key="$1" field="${2:-}" res
  load
  res="$(awk -F'\t' -v k="$key" -v f="$field" '
    $1=="ITEM" { on = ($4==k); if (on) { found = 1; if (f=="") { print "key: " k; print "kind: " $3 } else if (f=="kind") print $3 } next }
    !on { next }
    $1=="NAME"  && (f=="" || f=="name")  { print (f=="" ? "name: "  : "") $3 }
    $1=="ROLE"  && (f=="" || f=="role")  { print (f=="" ? "role: "  : "") $3 }
    $1=="TITLE" && (f=="" || f=="title") { print (f=="" ? "title: " : "") $3 }
    $1=="ID" && f=="" { print "ids." $3 ": " $4 }
    $1=="ID" && f ~ /^ids\./ && tolower($3)==tolower(substr(f, 5)) { print $4 }
    END { if (!found) exit 9 }
  ' <<< "$DATA")" || exit 3
  [ -n "$res" ] || exit 3
  printf '%s\n' "$res"
}

# matching_assignees <workspace> - the raw comma list for the best entry, or nothing.
# Exact path first, then the most specific matching glob (most literal characters, then fewer `**`).
matching_assignees() {
  awk -F'\t' -v ws="$1" "$AWK_LIB"'
    $1=="ASGN" {
      if ($2 == ws) { exact = 1; ex = $3 }
      else if ($2 ~ /[*]/ && globmatch($2, ws)) {
        t = $2; ds = gsub(/\*\*/, "", t); st = gsub(/\*/, "", t); lit = length(t)
        # most specific wins: more literal characters, then fewer "**", then fewer "*"
        if (!has || lit > bl || (lit == bl && (ds < bd || (ds == bd && st < bs)))) { bl = lit; bd = ds; bs = st; best = $3; has = 1 }
      }
    }
    END { if (exact) print ex; else if (has) print best }
  ' <<< "$DATA"
}

cmd_assignee() {
  local ws="" json=0
  while [ $# -gt 0 ]; do case "$1" in --json) json=1; shift;; -*) usage;; *) [ -z "$ws" ] || usage; ws="$(normalize_path "$1")"; shift;; esac; done
  [ -n "$ws" ] || usage
  load
  local raw keys
  raw="$(matching_assignees "$ws")"
  # Only keys that are still members: a departed person is never proposed (forward-only rule).
  keys="$(awk -F'\t' -v raw="$raw" '
    $1=="ITEM" && $3=="members" { m[$4]=1 }
    END { n = split(raw, a, ","); for (i = 1; i <= n; i++) if (a[i] in m) print a[i] }
  ' <<< "$DATA")"
  if [ -z "$keys" ]; then
    if [ "$json" -eq 1 ]; then echo '"ask"'; else echo ask; fi
    return 0
  fi
  if [ "$json" -eq 1 ]; then printf '%s\n' "$keys" | json_list; else printf '%s\n' "$keys"; fi
}

# workspace_dirs - every directory under the repo (depth <= 6), relative, without vendor and build-output
# dirs (a workspace is never one of those).
workspace_dirs() {
  ( cd "$ROOT" && find . -maxdepth 6 -type d \( -name node_modules -o -name .git -o -name .harness-trash -o -name dist -o -name build -o -name .next -o -name .turbo -o -name target -o -name vendor -o -name coverage -o -name .cache -o -name .venv -o -name __pycache__ \) -prune -o -type d -print 2>/dev/null \
      | sed -e 's#^\./##' -e '/^\.$/d' )
}

cmd_lint() {
  load
  local errs warns
  errs="$(awk -F'\t' "$AWK_LIB"'
    $1=="ITEM" { id=$2; k=$4; kind[k]=$3; cnt[k]++; hasname[id]=0; keyof[id]=k }
    $1=="NAME" && $3 != "" { hasname[$2]=1 }
    $1=="ID" { x = tolower($3) "\t" norm($3, $4); seen[x] = seen[x] " " keyof[$2]; c[x]++; disp[x] = $3 ": " $4 }
    $1=="ASGN" { n = split($3, a, ","); for (i = 1; i <= n; i++) if (a[i] != "") { ws[++wn] = $2; wk[wn] = a[i] } }
    END {
      for (k in cnt) if (cnt[k] > 1) printf "duplicate key: %s\n", k
      for (i in keyof) if (!hasname[i]) printf "missing name for %s\n", keyof[i]
      for (x in c) if (c[x] > 1) printf "duplicate id %s (used by:%s)\n", disp[x], seen[x]
      for (i = 1; i <= wn; i++) {
        if (!(wk[i] in kind)) printf "assignee_by_workspace %s: %s is not in members\n", ws[i], wk[i]
        else if (kind[wk[i]] == "contacts") printf "assignee_by_workspace %s: %s is a contact, not a member - contacts cannot be assignees\n", ws[i], wk[i]
      }
    }
  ' <<< "$DATA" | sort)"

  warns="$(
    awk -F'\t' '$1=="TOP"{printf "warning: unknown top-level key %s ignored\n", $2}' <<< "$DATA"
    dirs="$(workspace_dirs)"
    detected=""
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      if [ "$l" = "$ROOT" ]; then l="."; else l="${l#"$ROOT"/}"; fi
      detected="$detected$l"$'\n'
    done < <(cd "$ROOT" && bash "$SCRIPT_DIR/detect-monorepo-framework.sh" --workspaces 2>/dev/null || true)
    awk -F'\t' '$1=="ASGN"{print $2}' <<< "$DATA" | while IFS= read -r w; do
      [ "$w" = "." ] && continue
      hits="$(printf '%s\n' "$dirs" | awk "$AWK_LIB"'{ if (globmatch(w, $0)) print }' w="$w")"
      if [ -z "$hits" ]; then
        printf 'warning: assignee_by_workspace %s matches no directory (renamed or moved workspace?)\n' "$w"
      elif [ -n "$detected" ]; then
        printf '%s\n' "$hits" | awk "$AWK_LIB"'
          NR==FNR { if ($0 != "") d[++dn] = $0; next }
          { for (i = 1; i <= dn; i++) if (d[i] == "." || $0 == d[i] || index($0, d[i] "/") == 1 || globmatch(d[i] "/**", $0)) { ok = 1 } }
          END { exit ok ? 0 : 1 }' <(printf '%s' "$detected") - \
          || printf 'warning: assignee_by_workspace %s is not under a workspace detect-monorepo-framework.sh finds\n' "$w"
      fi
    done
  )"
  [ -z "$warns" ] || printf '%s\n' "$warns" >&2
  if [ -n "$errs" ]; then printf '%s\n' "$errs" | sed 's/^/team.sh: /' >&2; exit 1; fi
  exit 0
}

# refs <key> - files that drive future work and still mention this person. Never edits anything.
# Skipped on purpose (the forward-only rule): intents, task artifacts, session logs, fixtures,
# changelogs, the compiled knowledge base, the vendored bundle, lockfiles and the registry itself.
cmd_refs() {
  [ $# -ge 1 ] || usage
  local key="$1" pats
  load
  pats="$(awk -F'\t' -v k="$key" '
    $1=="ITEM"{ on = ($4==k); if (on) found=1; next }
    on && ($1=="NAME" || $1=="ID") { v = ($1=="NAME" ? $3 : $4); if (length(v) >= 4) print v }
    END { if (!found) exit 9 }
  ' <<< "$DATA")" || exit 3
  [ -n "$pats" ] || { echo "refs: nothing searchable for $key"; return 0; }
  local pf files hits
  files="$( cd "$ROOT" && { git ls-files -co --exclude-standard 2>/dev/null || find . -type f -not -path './.git/*' | sed 's#^\./##'; } \
    | awk '
      /(^|\/)\.agents\/intents\// || /(^|\/)\.agents\/artifacts\// || /(^|\/)\.agents\/session-log\.md$/ { next }
      /(^|\/)\.agents\/team\.yml/ || /^\.agents\/monorepo-agents-harness\// || /(^|\/)\.harness-trash\// { next }
      /(^|\/)(fixtures|__fixtures__|testdata|test-fixtures|node_modules|dist|build|\.next)\// { next }
      /^knowledge\// || /^CHANGELOG\.md$/ || /^changelogs\// { next }
      /(^|\/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?)$/ { next }
      { print }' )"
  [ -n "$files" ] || { echo "refs: none"; return 0; }
  pf="$(mktemp)"
  printf '%s\n' "$pats" | sort -u > "$pf"
  hits="$( cd "$ROOT" && printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -InHF -f "$pf" 2>/dev/null || true )"
  rm -f "$pf"
  if [ -z "$hits" ]; then echo "refs: none"; else printf '%s\n' "$hits"; fi
}

case "${1:-}" in
  whoami)         shift; cmd_whoami "$@" ;;
  get)            shift; cmd_get "$@" ;;
  find)           shift; cmd_find "$@" ;;
  resolve|match)  shift; cmd_resolve "$@" ;;
  assignee)       shift; cmd_assignee "$@" ;;
  lint)           shift; cmd_lint "$@" ;;
  refs)           shift; cmd_refs "$@" ;;
  *)              usage ;;
esac
