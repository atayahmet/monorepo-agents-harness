#!/usr/bin/env bash
# kb-index — derived SQLite FTS5 index over the repo-root knowledge/ layer. Agent-agnostic.
#
# Markdown stays the single source of truth; knowledge/.index.sqlite is a disposable derived cache
# (gitignored, never hand-edited, safe to delete at any time). This script rebuilds it, answers
# ranked queries over it (BM25 + snippet), and lints [[wiki-link]] / markdown link edges in one SQL
# pass. It never modifies a .md file. kb-ingest.sh upserts the pages it writes with `add`, so a
# task's pages are queryable the moment ingest ends. `rebuild` stays the full, safe path: staleness
# self-heals at query time (any .md newer than the DB, or a page-count mismatch, triggers one
# rebuild before the query runs).
#
# USAGE:
#   bash kb-index.sh rebuild [--kb <root>] [--dry-run] [--stats]
#   bash kb-index.sh query "<terms>" [--kb <root>] [--kind <k>] [--workspace <w>] [--limit <n>]
#   bash kb-index.sh links  [--kb <root>] [--orphans|--missing]     (default: both)
#   bash kb-index.sh add <path>... [--kb <root>]
#
#   --kb <root>   knowledge/ root (default: <git toplevel>/knowledge)
#   --dry-run     rebuild: report per-kind counts, write nothing
#   --stats       rebuild: print per-kind counts, link edges, db size, build time
#   --kind        query: filter by kind (module|concept|decision|fact|source|meta)
#   --workspace   query: filter by workspace column
#   --limit       query: max rows (default 25)
#   --orphans     links: pages no other page links to (README seeds excluded)
#   --missing     links: link targets that have no page
#   add <path>... upsert single pages (absolute, cwd-relative or <root>-relative .md files) into the
#                 existing index in one transaction: the old row, FTS entry and link edges of each
#                 page are replaced, never duplicated. No index yet: quiet no-op (the first query
#                 builds it). If any OTHER page changed since the index was written, add falls back
#                 to a full rebuild, so it can never hide an unindexed page behind a fresher mtime.
#
# Link resolution (what counts as an edge / a page):
#   [[concepts/foo]] / [[foo]] / [x](concepts/foo.md) / [x](../concepts/foo.md) all normalize to a
#   target without ".md" (relative "./ ../" paths resolve against the linking page's directory);
#   http(s)/mailto targets are skipped. A target matches a page when it equals the page path minus
#   ".md", or — for a bare target with no "/" — when prefixed with a known section directory.
#
# Exit codes: 0 = ok (including: no hits, dry-run), 1 = index unavailable (no sqlite3 / no FTS5 /
# no knowledge/, or an add that could not be applied) — the caller falls back to grep / rebuild,
# 2 = usage error.
# Output contract: query/links results on stdout; progress, warnings and stats on stderr.

set -euo pipefail
set -f   # never glob-expand user input (query terms, link targets)

GIT_TOP="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
KB="${KB:-$GIT_TOP/knowledge}"
CMD="" TERMS="" ADD_PATHS=() KIND="" WS="" LIMIT=25 DRY_RUN=0 STATS=0 LINKS_MODE="both"

usage() {
  sed -n '2,41p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --kb) KB="${2:-}"; [ -n "$KB" ] || { echo "kb-index: --kb needs a path" >&2; exit 2; }; shift 2 ;;
    --kind) KIND="${2:-}"; shift 2 ;;
    --workspace|--ws) WS="${2:-}"; shift 2 ;;
    --limit) LIMIT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --stats) STATS=1; shift ;;
    --orphans) LINKS_MODE="orphans"; shift ;;
    --missing) LINKS_MODE="missing"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "kb-index: unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$CMD" ]; then CMD="$1"
       elif [ "$CMD" = "query" ]; then TERMS="${TERMS:+$TERMS }$1"
       elif [ "$CMD" = "add" ]; then ADD_PATHS+=("$1")
       else echo "kb-index: unexpected argument: $1" >&2; exit 2
       fi
       shift ;;
  esac
done

case "$CMD" in
  rebuild) ;;
  query) [ -n "$TERMS" ] || { echo "kb-index: usage: kb-index.sh query \"<terms>\" [--kind K] [--workspace W] [--limit N]" >&2; exit 2; } ;;
  links) ;;
  add) [ "${#ADD_PATHS[@]}" -gt 0 ] || { echo "kb-index: usage: kb-index.sh add <path>... [--kb <root>]" >&2; exit 2; } ;;
  "") echo "kb-index: usage: kb-index.sh <rebuild|query|links|add> [...]" >&2; exit 2 ;;
  *) echo "kb-index: unknown subcommand: $CMD (expected rebuild|query|links|add)" >&2; exit 2 ;;
esac

# --- capability gate: one warning, exit 1, the caller greps instead ------------------------------
command -v sqlite3 >/dev/null 2>&1 \
  || { echo "kb-index: sqlite3 not found — KB index unavailable, fall back to grep" >&2; exit 1; }
if ! sqlite3 :memory: "CREATE VIRTUAL TABLE probe USING fts5(x);" 2>/dev/null; then
  echo "kb-index: sqlite3 built without FTS5 — KB index unavailable, fall back to grep" >&2
  exit 1
fi
[ -d "$KB" ] || { echo "kb-index: no knowledge/ at $KB — seed it first (scaffold-knowledge.sh)" >&2; exit 1; }

DB="$KB/.index.sqlite"
SQL_TMP="$KB/.index.sqlite.sql.$$"
DB_TMP="$KB/.index.sqlite.tmp.$$"
trap 'rm -f "$SQL_TMP" "$DB_TMP"' EXIT

# --- helpers ---------------------------------------------------------------------------------------
esc()      { printf '%s' "$1" | sed "s/'/''/g"; }                    # SQL string-literal body
mtime_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

kind_of() { # <path relative to knowledge/>
  case "$1" in
    modules/*) echo module ;;
    concepts/*) echo concept ;;
    decision-records/*) echo decision ;;
    verified-facts/*) echo fact ;;
    sources/*) echo source ;;
    *) echo meta ;;
  esac
}

norm_path() { # collapse "." and ".." segments of a /-separated path (string based)
  local out="" seg
  while IFS= read -r seg; do
    case "$seg" in
      ''|.) ;;
      ..) case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done < <(printf '%s' "$1" | tr '/' '\n')
  printf '%s' "$out"
}

targets_of() { # <rel path> → normalized link targets, one per line, sorted unique
  local f="$KB/$1" dir raw t
  dir="$(dirname "$1")"; [ "$dir" = "." ] && dir=""
  {
    grep -ohE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed -e 's/^\[\[//' -e 's/\]\]$//' || true
    grep -ohE '\]\([^)]*\)' "$f" 2>/dev/null | sed -e 's/^\](//' -e 's/)$//' || true
  } | while IFS= read -r raw; do
    t="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    t="${t%%#*}"     # drop #anchor
    t="${t%%\"*}"    # drop "title"
    t="${t%% *}"     # drop trailing title without quotes
    case "$t" in ''|http://*|https://*|mailto:*|//*) continue ;; esac
    case "$t" in ./*|../*) t="$(norm_path "${dir:+$dir/}$t")" ;; esac
    t="${t%.md}"
    [ -n "$t" ] && printf '%s\n' "$t"
  done | sort -u
}

stale() { # [<rel>...] true when the index is missing, older than any .md, or the page count differs;
          # the optional paths are left out of both checks (add: they are about to be rewritten)
  [ -f "$DB" ] || return 0
  local f rel x skip want have notin="" n_ex=0
  for x in "$@"; do notin="${notin:+$notin,}'$(esc "$x")'"; n_ex=$((n_ex + 1)); done
  while IFS= read -r f; do
    rel="${f#"$KB"/}"; skip=0
    for x in "$@"; do [ "$x" = "$rel" ] && { skip=1; break; }; done
    [ "$skip" -eq 1 ] || return 0
  done < <(find "$KB" -type f -name '*.md' -newer "$DB" -print 2>/dev/null)
  want="$(find "$KB" -type f -name '*.md' | wc -l | tr -d ' ')"; want=$((want - n_ex))
  have="$(sqlite3 "$DB" "SELECT count(*) FROM docs${notin:+ WHERE path NOT IN ($notin)};" 2>/dev/null || echo 0)"
  [ "$want" = "$have" ] || return 0
  return 1
}

# page_sql <rel> — the INSERTs for one page (its docs row and its link edges). Shared by rebuild and
# add so an index grown page by page is the index a full rebuild would have produced.
page_sql() {
  local rel="$1" f="$KB/$1" kind title ws slug date mt body target
  kind="$(kind_of "$rel")"

  title="$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)"
  [ -n "$title" ] || title="$(basename "$rel" .md)"

  # workspace: module page name, else first cited apps|packages|libs/<ws> path, else "project"
  # when the page points at a raw task dir, else NULL.
  ws=""
  if [ "$kind" = module ]; then
    [ "$(basename "$rel")" = "README.md" ] || ws="$(basename "$rel" .md)"
  else
    ws="$(grep -ohE '(apps|packages|libs)/[A-Za-z0-9_.-]+' "$f" 2>/dev/null | head -1 | cut -d/ -f2 || true)"
    if [ -z "$ws" ] && grep -qE '^(Raw task dir|Compiled from):' "$f" 2>/dev/null; then
      ws="project"
    fi
  fi

  # task slug: page named after a task dir, else first task_<date>_<slug> token cited in the page.
  slug="$(basename "$rel" .md)"
  case "$slug" in
    task_[0-9][0-9][0-9][0-9]_[0-9][0-9]_[0-9][0-9]_*) ;;
    *) slug="$(grep -ohE 'task_[0-9]{4}_[0-9]{2}_[0-9]{2}_[A-Za-z0-9_-]+' "$f" 2>/dev/null | head -1 || true)" ;;
  esac

  date=""
  case "$slug" in
    task_????_??_??_*) date="$(printf '%s' "$slug" | cut -d_ -f2-4 | tr _ -)" ;;
  esac

  mt="$(mtime_of "$f")"
  body="$(cat "$f")"

  printf "INSERT INTO docs(path,kind,workspace,task_slug,date,title,body,mtime) VALUES('%s','%s',%s,%s,%s,'%s','%s',%s);\n" \
    "$(esc "$rel")" "$kind" \
    "$( [ -n "$ws" ] && printf "'%s'" "$(esc "$ws")" || printf 'NULL' )" \
    "$( [ -n "$slug" ] && printf "'%s'" "$(esc "$slug")" || printf 'NULL' )" \
    "$( [ -n "$date" ] && printf "'%s'" "$date" || printf 'NULL' )" \
    "$(esc "$title")" "$(esc "$body")" "$mt"

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    printf "INSERT INTO links(from_path,target) VALUES('%s','%s');\n" "$(esc "$rel")" "$(esc "$target")"
  done < <(targets_of "$rel")
}

# --- rebuild ---------------------------------------------------------------------------------------
cmd_rebuild() {
  local t0 n=0
  t0="$(date +%s)"

  local rel

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "kb-index: dry-run — would index:" >&2
    while IFS= read -r f; do
      rel="${f#"$KB"/}"
      printf 'kb-index:   %-8s %s\n' "$(kind_of "$rel")" "$rel" >&2
      n=$((n + 1))
    done < <(find "$KB" -type f -name '*.md' | LC_ALL=C sort)
    echo "kb-index: dry-run — $n page(s), nothing written" >&2
    return 0
  fi

  {
    echo "CREATE TABLE docs(id INTEGER PRIMARY KEY, path TEXT UNIQUE NOT NULL, kind TEXT NOT NULL, workspace TEXT, task_slug TEXT, date TEXT, title TEXT NOT NULL, body TEXT NOT NULL, mtime INTEGER NOT NULL);"
    echo "CREATE VIRTUAL TABLE docs_fts USING fts5(title, body, content='docs', content_rowid='id', tokenize='unicode61');"
    echo "CREATE TABLE links(from_path TEXT NOT NULL, target TEXT NOT NULL);"
    echo "CREATE INDEX docs_kind_idx ON docs(kind);"
    echo "CREATE INDEX docs_ws_idx ON docs(workspace);"
    echo "CREATE INDEX docs_date_idx ON docs(date);"
    echo "CREATE INDEX links_from_idx ON links(from_path);"
    echo "CREATE INDEX links_target_idx ON links(target);"
  } > "$SQL_TMP"

  while IFS= read -r f; do
    page_sql "${f#"$KB"/}" >> "$SQL_TMP"
    n=$((n + 1))
  done < <(find "$KB" -type f -name '*.md' | LC_ALL=C sort)

  echo "INSERT INTO docs_fts(rowid,title,body) SELECT id,title,body FROM docs;" >> "$SQL_TMP"

  sqlite3 "$DB_TMP" < "$SQL_TMP" >&2 \
    || { echo "kb-index: rebuild failed — previous index left untouched" >&2; exit 1; }
  mv -f "$DB_TMP" "$DB"

  local elapsed=$(( $(date +%s) - t0 ))
  echo "kb-index: indexed $n page(s) → ${DB#"$GIT_TOP"/} in ${elapsed}s" >&2

  if [ "$STATS" -eq 1 ]; then
    sqlite3 -header -column "$DB" \
      "SELECT kind, count(*) AS pages FROM docs GROUP BY kind ORDER BY kind;
       SELECT count(*) AS link_edges FROM links;" >&2
    echo "kb-index: db size: $(wc -c < "$DB" | tr -d ' ') bytes, build: ${elapsed}s" >&2
  fi
  return 0
}

# --- add -------------------------------------------------------------------------------------------
cmd_add() {
  local kbc p abs rel x dup
  local rels=()
  kbc="$(cd "$KB" && pwd -P)"

  for p in "${ADD_PATHS[@]}"; do
    if [ -f "$KB/$p" ]; then abs="$(cd "$(dirname "$KB/$p")" && pwd -P)/$(basename "$p")"
    elif [ -f "$p" ]; then abs="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
    else echo "kb-index: add: no such page: $p" >&2; exit 2
    fi
    case "$abs" in
      "$kbc"/*.md) rel="$(norm_path "${abs#"$kbc"/}")" ;;
      *) echo "kb-index: add: not a .md page under $KB: $p" >&2; exit 2 ;;
    esac
    dup=0
    for x in ${rels[@]+"${rels[@]}"}; do [ "$x" = "$rel" ] && dup=1; done
    [ "$dup" -eq 1 ] || rels+=("$rel")
  done

  # No index yet: nothing to update. The first query builds the whole thing.
  [ -f "$DB" ] || return 0

  # Writing bumps the DB mtime, which stale() trusts. If anything else changed since the index was
  # written, upserting only these pages would hide it from the next query — rebuild in full instead.
  if stale "${rels[@]}"; then
    DRY_RUN=0 STATS=0 cmd_rebuild
    return 0
  fi

  {
    echo "BEGIN;"
    for rel in "${rels[@]}"; do
      q="'$(esc "$rel")'"
      echo "INSERT INTO docs_fts(docs_fts,rowid,title,body) SELECT 'delete',id,title,body FROM docs WHERE path=$q;"
      echo "DELETE FROM links WHERE from_path=$q;"
      echo "DELETE FROM docs WHERE path=$q;"
      page_sql "$rel"
      echo "INSERT INTO docs_fts(rowid,title,body) SELECT id,title,body FROM docs WHERE path=$q;"
    done
    echo "COMMIT;"
  } > "$SQL_TMP"

  # -bail stops at the first error; the open transaction then rolls back with the connection.
  sqlite3 -bail -cmd ".timeout 5000" "$DB" < "$SQL_TMP" >&2 \
    || { echo "kb-index: add failed — index left as it was, run 'kb-index.sh rebuild'" >&2; exit 1; }
  echo "kb-index: updated ${#rels[@]} page(s) in ${DB#"$GIT_TOP"/}" >&2
  return 0
}

ensure_fresh() { if stale; then DRY_RUN=0 STATS=0 cmd_rebuild; fi; }

# --- query -----------------------------------------------------------------------------------------
cmd_query() {
  case "$LIMIT" in ''|*[!0-9]*) echo "kb-index: --limit must be a number" >&2; exit 2 ;; esac
  ensure_fresh

  local expr="" tok
  for tok in $TERMS; do
    tok="$(printf '%s' "$tok" | tr -d '"')"
    [ -n "$tok" ] || continue
    expr="${expr:+$expr OR }\"$tok\""
  done
  [ -n "$expr" ] || { echo "kb-index: empty query" >&2; exit 2; }
  expr="$(esc "$expr")"

  local filters=""
  [ -n "$KIND" ] && filters="$filters AND d.kind = '$(esc "$KIND")'"
  [ -n "$WS" ]   && filters="$filters AND d.workspace = '$(esc "$WS")'"

  local sql
  sql="SELECT d.path || char(9) || d.kind || char(9) || COALESCE(d.workspace,'-') || char(9) ||
              COALESCE(d.date,'-') || char(9) ||
              replace(replace(replace(snippet(docs_fts, 1, char(91), char(93), char(8230), 10),
                      char(10), ' '), char(9), ' '), char(13), '')
       FROM docs_fts JOIN docs d ON d.id = docs_fts.rowid
       WHERE docs_fts MATCH '$expr'$filters
       ORDER BY bm25(docs_fts)
       LIMIT $LIMIT;"

  sqlite3 -noheader "$DB" "$sql"
}

# --- links --------------------------------------------------------------------------------------------
cmd_links() {
  ensure_fresh
  local ran=0 resolution

  # How a stored target (no ".md") resolves to a page, shared by both lints.
  resolution="d.path = l.target || '.md'
       OR (l.target NOT LIKE '%/%' AND d.path IN (
             'modules/' || l.target || '.md', 'concepts/' || l.target || '.md',
             'decision-records/' || l.target || '.md', 'verified-facts/' || l.target || '.md',
             'sources/' || l.target || '.md'))"

  if [ "$LINKS_MODE" = orphans ] || [ "$LINKS_MODE" = both ]; then
    ran=1
    sqlite3 -noheader "$DB" "
      SELECT 'orphan: ' || p.path
      FROM docs p
      WHERE p.path LIKE '%/%' AND p.path NOT LIKE '%/README.md'
        AND NOT EXISTS (
          SELECT 1 FROM links l
          WHERE l.from_path <> p.path
            AND (l.target = substr(p.path, 1, length(p.path) - 3)
                 OR (l.target NOT LIKE '%/%' AND p.path IN (
                       'modules/' || l.target || '.md', 'concepts/' || l.target || '.md',
                       'decision-records/' || l.target || '.md',
                       'verified-facts/' || l.target || '.md',
                       'sources/' || l.target || '.md'))))
      ORDER BY p.path;"
  fi
  if [ "$LINKS_MODE" = missing ] || [ "$LINKS_MODE" = both ]; then
    ran=1
    sqlite3 -noheader "$DB" "
      SELECT DISTINCT 'missing: ' || l.target || ' (from ' || l.from_path || ')'
      FROM links l
      WHERE NOT EXISTS (SELECT 1 FROM docs d WHERE $resolution)
      ORDER BY 1;"
  fi

  [ "$ran" -eq 1 ] || { echo "kb-index: usage: kb-index.sh links [--orphans|--missing]" >&2; exit 2; }
  return 0
}

case "$CMD" in
  rebuild) cmd_rebuild ;;
  query)   cmd_query ;;
  links)   cmd_links ;;
  add)     cmd_add ;;
esac
exit 0
