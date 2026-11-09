#!/usr/bin/env bash
# agents-tree.sh - mechanics for a workspace's AGENTS.md tree (skill: core/skills/agents-init/SKILL.md).
#
# Canonical form: AGENTS.md is the file; CLAUDE.md and GEMINI.md next to it are symlinks to it.
# The agent writes the content; this script surveys, ranks, links and lints. Only `link` writes.
#
# Usage (from anywhere inside the target repo; <ws> is a path such as apps/web, or . for the root):
#   agents-tree.sh survey [--workspace <ws>]   every AGENTS.md / CLAUDE.md / GEMINI.md, then drift
#   agents-tree.sh candidates <ws> [--limit N] directories ranked for a nested AGENTS.md (default 20)
#   agents-tree.sh link <ws>                   create missing CLAUDE.md/GEMINI.md symlinks (never
#                                              replaces a plain file)
#   agents-tree.sh lint <ws> [--root-max N] [--nested-max N]
#                                              read-only checks; budgets default to 80 / 150 lines
#
# survey prints TSV `path lines claude gemini headings`, then a `drift:` block (`path reason`).
#   claude/gemini: symlink | file | missing | -> <target> (a symlink to something else) | - (no AGENTS.md)
# candidates prints TSV `score dir files index tests importers hint`, best first. importers counts
#   files outside the directory whose import/require specifier contains the directory's name.
# lint prints `FAIL <file>: <reason>` for: over budget, a missing or wrong symlink, a backticked path
#   that does not exist (a token with a `/` whose last part has a file extension or whose first part
#   is an existing dir; resolved from the file's dir, then <ws>, then the repo root), a nested file
#   its nearest parent AGENTS.md does not mention, 5+ consecutive lines copied from the root AGENTS.md
#   or .agents/rules/*.md. Fenced code, URLs, globs, <placeholders>, bare file names, /commands and
#   lines carrying `agents-tree:ignore` are not path-checked. Plain CLAUDE.md/GEMINI.md drift prints as WARN.
#
# Exit codes: 0 ok | 1 lint failure | 2 usage.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ROOT="$(cd "$ROOT" && pwd -P)"
PRUNE='.git node_modules .agents dist build out .next .turbo coverage vendor target .venv'
SRC_EXT='sh ts tsx js jsx mjs cjs vue svelte py go rs rb java kt swift php cs'
FILE_EXT='md ts tsx js jsx mjs cjs json jsonc yml yaml toml sh py go rs rb java kt swift php cs css scss vue svelte html sql prisma graphql lock txt env'
HINT_RE='^(store|stores|routes|router|pages|app|config|locales|i18n|services|contexts|hooks|generated|api|db|migrations|schemas?)$'

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "agents-tree: $1" >&2; exit "${2:-2}"; }

# resolve_ws <ws> - print the absolute workspace dir, or die.
resolve_ws() {
  local w="${1%/}" abs
  [ -n "$w" ] || w="."
  case "$w" in /*) abs="$w" ;; *) abs="$ROOT/$w" ;; esac
  [ -d "$abs" ] || die "not a directory: $1 (pass the workspace path, e.g. apps/web)"
  abs="$(cd "$abs" && pwd -P)"
  case "$abs/" in "$ROOT"/*) ;; *) die "outside the repo: $1" ;; esac
  printf '%s\n' "$abs"
}
rel() { local p="$1" base="$2"; if [ "$p" = "$base" ]; then echo .; else printf '%s\n' "${p#"$base"/}"; fi; }

# find_pruned <dir> <find-expr...> - find, skipping vendored, built and harness dirs.
find_pruned() {
  local d="$1"; shift
  local args=() n
  for n in $PRUNE; do args+=(-name "$n" -o); done
  unset 'args[${#args[@]}-1]'
  find "$d" \( -type d \( "${args[@]}" \) \) -prune -o "$@" -print 2>/dev/null
}

# link_state <dir> <name> - symlink | file | missing | -> <target>
link_state() {
  local f="$1/$2" t
  if [ -L "$f" ]; then
    t="$(readlink "$f")"
    case "$t" in AGENTS.md|./AGENTS.md) echo symlink ;; *) echo "-> $t" ;; esac
  elif [ -e "$f" ]; then echo file
  else echo missing; fi
}
headings() { awk '/^```/{f=!f; next} !f && /^## /{sub(/^## +/, ""); printf "%s%s", (n++?";":""), $0}' "$1"; }
lines_of() { wc -l < "$1" | tr -d ' '; }

cmd_survey() {
  local base="$ROOT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --workspace) [ $# -ge 2 ] || usage; base="$(resolve_ws "$2")"; shift 2 ;;
      *) die "survey: unknown option: $1" ;;
    esac
  done
  local dirs d f n s drift="" na=0 np=0
  dirs="$(find_pruned "$base" \( -name AGENTS.md -o -name CLAUDE.md -o -name GEMINI.md \) | while IFS= read -r f; do dirname "$f"; done | LC_ALL=C sort -u)"
  printf 'path\tlines\tclaude\tgemini\theadings\n'
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    local r; r="$(rel "$d" "$ROOT")"; [ "$r" = . ] && r="" || r="$r/"
    if [ -f "$d/AGENTS.md" ] && [ ! -L "$d/AGENTS.md" ]; then
      na=$((na+1))
      local c g; c="$(link_state "$d" CLAUDE.md)"; g="$(link_state "$d" GEMINI.md)"
      printf '%sAGENTS.md\t%s\t%s\t%s\t%s\n' "$r" "$(lines_of "$d/AGENTS.md")" "$c" "$g" "$(headings "$d/AGENTS.md")"
      for n in CLAUDE.md GEMINI.md; do
        s="$(link_state "$d" "$n")"
        case "$s" in
          symlink) ;;
          missing) drift="$drift${r}AGENTS.md	$n missing"$'\n' ;;
          file)    drift="$drift${r}$n	plain $n next to AGENTS.md (should be a symlink)"$'\n' ;;
          *)       drift="$drift${r}$n	symlink $s, not to AGENTS.md"$'\n' ;;
        esac
      done
    else
      for n in CLAUDE.md GEMINI.md; do
        [ -e "$d/$n" ] || continue
        np=$((np+1))
        printf '%s%s\t%s\t-\t-\t%s\n' "$r" "$n" "$(lines_of "$d/$n")" "$(headings "$d/$n")"
        drift="$drift${r}$n	plain $n without AGENTS.md (other agents do not see it)"$'\n'
      done
    fi
  done <<< "$dirs"
  printf 'drift:\n%s' "$drift"
  printf 'summary: %d AGENTS.md, %d plain CLAUDE.md/GEMINI.md without AGENTS.md, %d drift item(s)\n' \
    "$na" "$np" "$(printf '%s' "$drift" | grep -c . || true)"
}

cmd_candidates() {
  [ $# -ge 1 ] || usage
  local ws limit=20; ws="$(resolve_ws "$1")"; shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit) [ $# -ge 2 ] || usage; limit="$2"; shift 2 ;;
      *) die "candidates: unknown option: $1" ;;
    esac
  done
  case "$limit" in ''|*[!0-9]*) die "candidates: --limit takes a number" ;; esac
  local expr=() e
  for e in $SRC_EXT; do expr+=(-name "*.$e" -o); done
  unset 'expr[${#expr[@]}-1]'
  local files; files="$(find_pruned "$ws" -type f \( "${expr[@]}" \) | LC_ALL=C sort)"
  [ -n "$files" ] || { printf 'score\tdir\tfiles\tindex\ttests\timporters\thint\n'; return 0; }
  # Import specifiers, one `file<TAB>spec` per line (workspace-relative file).
  local specs
  specs="$(while IFS= read -r f; do
      grep -oE "(from|require\(|import\()[[:space:]]*['\"][^'\"]+['\"]" "$f" 2>/dev/null \
        | sed -E "s/^[^'\"]*['\"]//; s/['\"]$//" | sed "s|^|${f#"$ws"/}	|" || true
    done <<< "$files")"
  { printf '%s\n' "$files" | sed "s|^$ws/|F	|"; printf '%s\n' "$specs" | sed '/^$/d; s/^/S	/'; } \
  | awk -F'\t' -v hint="$HINT_RE" -v limit="$limit" '
    $1 == "F" {
      p = $2; nf++; fl[nf] = p
      k = split(p, seg, "/"); base = seg[k]
      d = ""
      for (i = 1; i < k; i++) {
        d = (i == 1 ? seg[1] : d "/" seg[i]); cnt[d]++
        if (base ~ /\.(test|spec)\./ || seg[i+1] == "__tests__") tests[d] = 1
        if (i == k - 1 && base ~ /^(index\.[a-z]+|mod\.rs|__init__\.py)$/) idx[d] = 1
      }
      next
    }
    $1 == "S" { ns++; sf[ns] = $2; sp[ns] = $3 }
    END {
      for (d in cnt) { k = split(d, seg, "/"); byname[seg[k]] = byname[seg[k]] SUBSEP d }
      for (s = 1; s <= ns; s++) {
        m = split(sp[s], parts, "/")
        for (j = 1; j <= m; j++) {
          if (parts[j] == "." || parts[j] == ".." || !(parts[j] in byname)) continue
          c = split(byname[parts[j]], ds, SUBSEP)
          for (q = 2; q <= c; q++) {
            d = ds[q]
            if (index(sf[s], d "/") == 1) continue
            if (!((d, sf[s]) in seen)) { seen[d, sf[s]] = 1; imp[d]++ }
          }
        }
      }
      for (d in cnt) {
        if (cnt[d] < 2 && !(d in imp)) continue
        k = split(d, seg, "/"); h = (seg[k] ~ hint) ? seg[k] : "-"
        score = cnt[d] + (d in idx ? 5 : 0) + (d in tests ? 3 : 0) + 2 * imp[d] + (h != "-" ? 3 : 0)
        printf "%d\t%s\t%d\t%s\t%s\t%d\t%s\n", score, d, cnt[d], (d in idx ? "yes" : "no"), (d in tests ? "yes" : "no"), imp[d], h
      }
    }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1nr -k2,2 | awk -v n="$limit" 'NR <= n' \
  | { printf 'score\tdir\tfiles\tindex\ttests\timporters\thint\n'; cat; }
}

cmd_link() {
  [ $# -eq 1 ] || usage
  local ws f d n s created=0; ws="$(resolve_ws "$1")"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d="$(dirname "$f")"
    for n in CLAUDE.md GEMINI.md; do
      s="$(link_state "$d" "$n")"
      case "$s" in
        symlink) ;;
        missing) ( cd "$d" && ln -s AGENTS.md "$n" ); created=$((created+1)); echo "  + $(rel "$d/$n" "$ROOT")" ;;
        file)    echo "  ! $(rel "$d/$n" "$ROOT") is a plain file; left alone (fold it into AGENTS.md, then re-run)" ;;
        *)       echo "  ! $(rel "$d/$n" "$ROOT") is a symlink $s; left alone" ;;
      esac
    done
  done < <(find_pruned "$ws" -name AGENTS.md -type f)
  echo "linked $created symlink(s)."
}

# copied_blocks <file> <ref>... - print `<line> <ref>` for 5-line runs of <file> found verbatim in a ref.
copied_blocks() {
  local f="$1"; shift
  awk -v target="$f" '
    function norm(s) { gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s }
    FNR == 1 { rn = 0; tn = 0 }
    FILENAME != target {
      l = norm($0)
      if (l == "") { rn = 0; next }
      rb[++rn] = l
      if (rn >= 5) { k = rb[rn-4] "\n" rb[rn-3] "\n" rb[rn-2] "\n" rb[rn-1] "\n" rb[rn]; if (!(k in ref)) ref[k] = FILENAME }
      next
    }
    {
      l = norm($0)
      if (l == "") { tn = 0; next }
      tb[++tn] = l; tl[tn] = FNR
      if (tn >= 5) {
        k = tb[tn-4] "\n" tb[tn-3] "\n" tb[tn-2] "\n" tb[tn-1] "\n" tb[tn]
        if ((k in ref) && tl[tn-4] > last) { print tl[tn-4] "\t" ref[k]; last = FNR }
      }
    }' "$@" "$f"
}

# path_refs <file> - print `<line>\t<token>` for backticked tokens that look like file paths.
path_refs() {
  awk -v exts="$FILE_EXT" '
    BEGIN { n = split(exts, e, " "); for (i = 1; i <= n; i++) ext[e[i]] = 1 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence || /agents-tree:ignore/ { next }
    {
      s = $0
      while (match(s, /`[^`]+`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
        if (t ~ /[[:space:]*?<>{}$|()=,;"\047\\]/ || t ~ /:\/\// || t ~ /^[-@~#]/) continue
        sub(/:[0-9]+(-[0-9]+)?$/, "", t); sub(/\/$/, "", t)
        if (t !~ /\// || t ~ /^\//) continue
        x = t; sub(/^.*\//, "", x); first = t; sub(/\/.*$/, "", first)
        isext = 0; if (match(x, /\.[A-Za-z][A-Za-z0-9]*$/)) isext = (substr(x, RSTART + 1) in ext)
        print FNR "\t" t "\t" isext "\t" first
      }
    }' "$1"
}

cmd_lint() {
  [ $# -ge 1 ] || usage
  local ws rmax=80 nmax=150; ws="$(resolve_ws "$1")"; shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --root-max)   [ $# -ge 2 ] || usage; rmax="$2"; shift 2 ;;
      --nested-max) [ $# -ge 2 ] || usage; nmax="$2"; shift 2 ;;
      *) die "lint: unknown option: $1" ;;
    esac
  done
  case "$rmax$nmax" in *[!0-9]*) die "lint: budgets take a number" ;; esac
  local refs=() r
  [ "$ws" != "$ROOT" ] && [ -f "$ROOT/AGENTS.md" ] && refs+=("$ROOT/AGENTS.md")
  for r in "$ROOT"/.agents/rules/*.md; do [ -f "$r" ] && refs+=("$r"); done
  local fails=0 nfiles=0 f d rf n s max lines line tok isext first up rp hit src
  fail() { fails=$((fails+1)); echo "FAIL $1"; }
  # Plain CLAUDE.md/GEMINI.md without an AGENTS.md: report, never fail (moving them is opt-in).
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d="$(dirname "$f")"; [ -f "$d/AGENTS.md" ] || echo "WARN $(rel "$f" "$ws"): plain $(basename "$f") without AGENTS.md (drift, not fixed here)"
  done < <(find_pruned "$ws" \( -name CLAUDE.md -o -name GEMINI.md \) | LC_ALL=C sort)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    nfiles=$((nfiles+1)); d="$(dirname "$f")"; rf="$(rel "$f" "$ws")"
    max=$nmax; [ "$d" = "$ws" ] && max=$rmax
    lines="$(lines_of "$f")"
    [ "$lines" -le "$max" ] || fail "$rf: $lines lines > $max"
    for n in CLAUDE.md GEMINI.md; do
      s="$(link_state "$d" "$n")"
      case "$s" in
        symlink) ;;
        missing) fail "$rf: $n missing (run agents-tree.sh link)" ;;
        file)    fail "$rf: $n is a plain file, not a symlink to AGENTS.md" ;;
        *)       fail "$rf: $n is a symlink $s, not to AGENTS.md" ;;
      esac
    done
    while IFS=$'\t' read -r line tok isext first; do
      [ -n "$tok" ] || continue
      if [ "$isext" != 1 ] && [ ! -d "$d/$first" ] && [ ! -d "$ws/$first" ] && [ ! -d "$ROOT/$first" ]; then
        continue  # neither a file name nor rooted in an existing dir: not a path (N/A, feat/x)
      fi
      if [ -e "$d/$tok" ] || [ -e "$ws/$tok" ] || [ -e "$ROOT/$tok" ]; then continue; fi
      fail "$rf:$line: broken path $tok"
    done < <(path_refs "$f")
    if [ "$d" != "$ws" ]; then
      up="$(dirname "$d")"
      while [ "$up" != "$ws" ] && [ ! -f "$up/AGENTS.md" ]; do up="$(dirname "$up")"; done
      rp="$(rel "$d" "$up")"; hit=0
      if [ -f "$up/AGENTS.md" ]; then
        grep -qF -e "$rp/AGENTS.md" -e "\`$rp\`" -e "\`$rp/\`" "$up/AGENTS.md" && hit=1
      fi
      [ "$hit" = 1 ] || fail "$rf: not linked from $(rel "$up/AGENTS.md" "$ws") (add $rp/AGENTS.md to its routing table)"
    fi
    if [ "${#refs[@]}" -gt 0 ]; then
      while IFS=$'\t' read -r line src; do
        [ -n "$line" ] && fail "$rf:$line: 5+ lines copied from $(rel "$src" "$ROOT"); link it instead"
      done < <(copied_blocks "$f" "${refs[@]}")
    fi
  done < <(find_pruned "$ws" -name AGENTS.md -type f | LC_ALL=C sort)
  [ "$nfiles" -gt 0 ] || fail "$(rel "$ws" "$ROOT"): no AGENTS.md (run /monorepo-harness-agents-init $(rel "$ws" "$ROOT"))"
  echo "agents-tree: lint — $nfiles file(s), $fails failure(s)"
  [ "$fails" -eq 0 ] || return 1
}

case "${1:-}" in
  survey)     shift; cmd_survey "$@" ;;
  candidates) shift; cmd_candidates "$@" ;;
  link)       shift; cmd_link "$@" ;;
  lint)       shift; cmd_lint "$@" ;;
  -h|--help|"") usage ;;
  *) die "unknown subcommand: $1" ;;
esac
