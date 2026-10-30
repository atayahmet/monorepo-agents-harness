#!/usr/bin/env bash
# Tests for kb-ingest.sh -> kb-index.sh add (issue #63): a task's pages are in the derived SQLite
# index the moment ingest ends, with no query-time rebuild, and a second ingest adds nothing.
#
# Repo-local on purpose: not in core/install-manifest.txt, so it never reaches a consumer bundle.
# Run it from anywhere:  bash tests/kb-ingest-index.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-kb-ingest-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

INGEST="$REPO/core/scripts/kb-ingest.sh"
INDEX="$REPO/core/scripts/kb-index.sh"
SLUG="task_2026_10_30_zebra_cache"
TASK="apps/api/.agents/artifacts/$SLUG"
KB="$FIXTURE/knowledge"
db()     { sqlite3 "$KB/.index.sqlite" "$1"; }
ingest() { ( cd "$FIXTURE" && bash "$INGEST" "$TASK" 2>&1 ); }
query()  { ( cd "$FIXTURE" && bash "$INDEX" query "$1" 2>/dev/null ); }
dump()   { db "SELECT path,kind,COALESCE(workspace,''),COALESCE(task_slug,''),title,body FROM docs ORDER BY path; SELECT from_path,target FROM links ORDER BY 1,2;"; }

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  mkdir -p "$KB/modules" "$KB/concepts" "$KB/sources" "$KB/decision-records" "$KB/verified-facts" "$FIXTURE/$TASK/adr"
  printf '# Knowledge schema\n' > "$KB/schema.md"
  printf '# Knowledge index\n\n### Sources (per-task synopses)\n\n### Decision records (compiled from adr/)\n\n### Verified facts (from 4_verify.md)\n\n(end of catalog)\n' > "$KB/index.md"
  printf '# Log\n\n| Date | Op | Task | Pages |\n| ---- | -- | ---- | ----- |\n' > "$KB/log.md"
  printf '# Concept: older\n\nAn earlier page about retries.\n' > "$KB/concepts/older.md"
  printf '# Memory\n\nThe zebra cache keeps hot rows.\n' > "$FIXTURE/$TASK/3_memory.md"
  printf '# Verify\n\nzebra cache hit rate measured.\n' > "$FIXTURE/$TASK/4_verify.md"
  printf '# 0001 Use a zebra cache\n\nDecision text.\n' > "$FIXTURE/$TASK/adr/0001-zebra.md"
}

echo "kb-ingest — pages reach the index without a rebuild"

new_fixture
( cd "$FIXTURE" && bash "$INDEX" rebuild 2>/dev/null )
before="$(db 'SELECT count(*) FROM docs;')"
out="$(ingest)"
says "ingest reports the index update" "$out" "index updated"
want="$(find "$KB" -type f -name '*.md' | wc -l | tr -d ' ')"
is "docs holds every page on disk right after ingest" "$(db 'SELECT count(*) FROM docs;')" "$want"
is "ingest added pages" "$([ "$want" -gt "$before" ] && echo yes || echo no)" "yes"
for p in "sources/$SLUG.md" "verified-facts/$SLUG.md" "decision-records/0001-zebra.md" "modules/api.md" "log.md" "index.md"; do
  is "indexed: $p" "$(db "SELECT count(*) FROM docs WHERE path='$p';")" "1"
done
is "the index is not stale after ingest" "$( ( cd "$FIXTURE" && find "$KB" -name '*.md' -newer "$KB/.index.sqlite" | wc -l | tr -d ' ' ) )" "0"
says "the task keyword is found" "$(query "zebra")" "decision-records/0001-zebra.md"
first_dump="$(dump)"
first_log="$(db "SELECT count(*) FROM docs;")"

echo "kb-ingest — a second run duplicates nothing"

ingest >/dev/null
is "docs row count unchanged" "$(db 'SELECT count(*) FROM docs;')" "$first_log"
is "docs and links unchanged" "$(dump)" "$first_dump"
is "docs_fts passes the integrity check" "$(db "INSERT INTO docs_fts(docs_fts,rank) VALUES('integrity-check',1); SELECT 'ok';")" "ok"
is "one FTS hit per page for the task keyword" "$(db "SELECT count(*) FROM docs_fts WHERE docs_fts MATCH 'zebra';")" "$(db "SELECT count(*) FROM docs WHERE body LIKE '%zebra%';")"

echo "kb-ingest — incremental equals a full rebuild"

rm -f "$KB/.index.sqlite"
( cd "$FIXTURE" && bash "$INDEX" rebuild 2>/dev/null )
is "full rebuild dump equals the ingested index" "$(dump)" "$first_dump"

echo "kb-ingest — degraded modes never fail the ingest"

new_fixture
# A PATH holding every tool the scripts use except sqlite3.
NOSQL="$(mktemp -d "${TMPDIR:-/tmp}/harness-nosql.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$NOSQL"' EXIT
for t in bash git dirname basename find sed grep awk date wc tr cat head mv cp mkdir sort cut stat touch rm printf; do
  src="$(command -v "$t" 2>/dev/null || true)"; [ -n "$src" ] && ln -sf "$src" "$NOSQL/$t"
done
out="$( cd "$FIXTURE" && PATH="$NOSQL" "$NOSQL/bash" "$INGEST" "$TASK" 2>&1 )"; rc=$?
says "no sqlite3: the fallback is reported, not fatal" "$out" "index not updated"
is "no sqlite3: ingest still exits 0" "$rc" "0"
is "no sqlite3: no database is created" "$([ -f "$KB/.index.sqlite" ] && echo yes || echo no)" "no"
new_fixture
out="$(ingest)"
is "no index yet: ingest exits 0 and builds none" "$([ -f "$KB/.index.sqlite" ] && echo yes || echo no)" "no"
out="$( cd "$FIXTURE" && bash "$INGEST" "$TASK" --dry-run 2>&1 )"
says "dry-run names the pages it would index" "$out" "would update the index"

echo
echo "kb-ingest-index: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
