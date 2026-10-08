#!/usr/bin/env bash
# Tests for core/scripts/kb-index.sh — the derived SQLite FTS5 index over knowledge/ (issue #25).
#
# Repo-local on purpose: this file is NOT in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# One section per acceptance criterion of the spec:
#   (a) rebuild twice  -> same rows, same query output (deterministic)
#   (b) an interrupted/failed rebuild never destroys the previous index (kill-safe)
#   (c) a page added after the last build is found with no manual rebuild (staleness self-heal)
#   (d) no sqlite3     -> one warning, exit 1, grep fallback still answers
#   (e) orphan / broken-link lint as one SQL query each
# Run it from anywhere:  bash tests/kb-index.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-kb-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()       { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says()     { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
not_says() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }
silent()   { if [ -z "$2" ]; then ok "$1"; else bad "$1" "expected no output, got: $2"; fi; }

SCRIPT="$REPO/core/scripts/kb-index.sh"
idx()      { ( cd "$FIXTURE" && bash "$SCRIPT" "$@" 2>/dev/null ); }   # results = stdout only
idx_all()  { ( cd "$FIXTURE" && bash "$SCRIPT" "$@" 2>&1 ); }
idx_code() { ( cd "$FIXTURE" && bash "$SCRIPT" "$@" >/dev/null 2>&1 ); echo $?; }
db()       { sqlite3 "$FIXTURE/knowledge/.index.sqlite" "$1"; }

# A throwaway git repo whose knowledge/ holds the page shapes the indexer derives columns from:
# a module page (workspace + wiki-links), a concept, an orphan concept, a sources page (task slug +
# date from "Raw task dir:"), a README seed and the index.md catalog with markdown links.
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  local KB="$FIXTURE/knowledge"
  mkdir -p "$KB/modules" "$KB/concepts" "$KB/sources"
  printf '# Knowledge index\n\n- [api](modules/api.md)\n- [retry](sources/task_2026_01_02_add_retry.md)\n' > "$KB/index.md"
  printf '# Module: api\n\nRetry lives in [[concepts/retry]] and [[concepts/ghost]].\n\nSources: `apps/api/.agents/artifacts/task_2026_01_02_add_retry/3_memory.md`\n' > "$KB/modules/api.md"
  printf '# Concept: retry\n\nThe agent may retry the failing command until it works.\n' > "$KB/concepts/retry.md"
  printf '# Concept: orphan\n\nNobody links to this page.\n' > "$KB/concepts/orphan.md"
  printf '# Source: task_2026_01_02_add_retry\n\nRaw task dir: `apps/api/.agents/artifacts/task_2026_01_02_add_retry`\n' > "$KB/sources/task_2026_01_02_add_retry.md"
  printf '# README seed\n\nDirectional stub.\n' > "$KB/modules/README.md"
}

echo "kb-index — deterministic rebuild"

new_fixture
is "rebuild exits 0" "$(idx_code rebuild)" "0"
rows1="$(db 'SELECT count(*) FROM docs;')"
links1="$(db 'SELECT count(*) FROM links;')"
q1="$(idx query "retry failure")"
idx rebuild
rows2="$(db 'SELECT count(*) FROM docs;')"
links2="$(db 'SELECT count(*) FROM links;')"
q2="$(idx query "retry failure")"
is "six pages indexed" "$rows1" "6"
is "doc rows identical across rebuilds" "$rows1" "$rows2"
is "link edges identical across rebuilds" "$links1" "$links2"
is "query output identical across rebuilds" "$q1" "$q2"
says "ranked hit leads with the retry concept" "$q1" "concepts/retry.md"
not_says "progress lines stay off stdout" "$q1" "kb-index:"
is "derived columns are filled in" "$(db "SELECT workspace || '/' || date FROM docs WHERE path='modules/api.md';")" "api/2026-01-02"
is "a page with no citation gets no workspace" "$(db "SELECT COALESCE(workspace,'NULL') FROM docs WHERE path='concepts/retry.md';")" "NULL"

echo "kb-index — an interrupted rebuild never destroys the previous index"

new_fixture
idx rebuild
before="$(idx query "retry")"
# (b1) the temp build cannot even start: the knowledge dir is not writable, so the previous
# database must survive untouched (no empty/half-written .index.sqlite).
chmod -w "$FIXTURE/knowledge"
rc="$(idx_code rebuild)"
chmod +w "$FIXTURE/knowledge"
if [ "$rc" -ne 0 ]; then ok "a rebuild that cannot write fails non-zero"; else bad "a rebuild that cannot write fails non-zero" "exit 0"; fi
is "previous index still answers" "$(idx query "retry")" "$before"
# (b2) a SIGKILL in the middle of a rebuild: the old database still answers afterwards, and no
# half-written file is ever swapped in. The children (find, grep, sqlite3) are killed too — killing
# only the script would let an in-flight `sqlite3` finish the write on its own.
( cd "$FIXTURE" && exec bash "$SCRIPT" rebuild >/dev/null 2>&1 ) &
killer=$!
sleep 0.05
pkill -9 -P "$killer" 2>/dev/null
kill -9 "$killer" 2>/dev/null
wait "$killer" 2>/dev/null
says "index still answers after a kill" "$(idx query "retry")" "concepts/retry.md"
is "the database is still queryable" "$(db 'SELECT count(*) FROM docs;')" "6"
# (b3) the publish window, deterministically: a `mv` shim marks the moment the new database is
# finished and stalls before the rename. While the build is in flight — and after it is killed
# there — every reader must still see the OLD index. A rebuild that writes straight to the final
# path never produces that moment, so this case is what proves the temp-file + rename mechanism.
mkdir -p "$FIXTURE/bin"
cat > "$FIXTURE/bin/mv" <<'SH'
#!/usr/bin/env bash
: > "$MV_MARK"
sleep 30
exec /bin/mv "$@"
SH
chmod +x "$FIXTURE/bin/mv"
MV_MARK="$FIXTURE/publishing"
export MV_MARK
rm -f "$MV_MARK"
( cd "$FIXTURE" && exec env PATH="$FIXTURE/bin:$PATH" bash "$SCRIPT" rebuild >/dev/null 2>&1 ) &
publisher=$!
reached=1
for _ in $(seq 1 100); do [ -f "$MV_MARK" ] && { reached=0; break; }; sleep 0.1; done
if [ "$reached" -eq 0 ]; then ok "the build reaches the publish step"; else bad "the build reaches the publish step" "temp file + rename never happened (marker missing after 10s)"; fi
is "the old index still answers while the new one is being published" "$(db 'SELECT count(*) FROM docs;')" "6"
pkill -9 -P "$publisher" 2>/dev/null
kill -9 "$publisher" 2>/dev/null
wait "$publisher" 2>/dev/null
says "the index still answers after a kill in the publish window" "$(idx query "retry")" "concepts/retry.md"
is "the database is still queryable after that kill" "$(db 'SELECT count(*) FROM docs;')" "6"

echo "kb-index — staleness self-heals at query time"

new_fixture
idx rebuild
printf '# Concept: fallback\n\nWithout sqlite3 the skill falls back to grep.\n' > "$FIXTURE/knowledge/concepts/fallback.md"
says "a new page is found with no manual rebuild" "$(idx query "fallback grep")" "concepts/fallback.md"
is "the index rebuilt itself on demand" "$(db 'SELECT count(*) FROM docs;')" "7"
rm -f "$FIXTURE/knowledge/concepts/fallback.md"
silent "a deleted page stops matching" "$(idx query "fallback grep")"

echo "kb-index — no sqlite3 degrades to grep"

new_fixture
idx rebuild
# An empty PATH reaches the capability gate and nothing else: the script must warn once and stop.
err="$( cd "$FIXTURE" && PATH=/nonexistent /bin/bash "$SCRIPT" query "retry" 2>&1 )"
rc=$?
is "exit 1 without sqlite3" "$rc" "1"
says "one warning names the cause" "$err" "sqlite3 not found"
is "exactly one warning line" "$(printf '%s\n' "$err" | grep -c .)" "1"
# The skill's documented fallback for the same question still returns the page.
hits="$(grep -rl "retry the failing command" "$FIXTURE/knowledge" 2>/dev/null || true)"
says "grep fallback still answers" "$hits" "concepts/retry.md"

echo "kb-index — link lint"

new_fixture
idx rebuild
orph="$(idx links --orphans)"
says "an unlinked page is an orphan" "$orph" "orphan: concepts/orphan.md"
not_says "README seeds are never orphans" "$orph" "README"
not_says "the root index is never an orphan" "$orph" "index.md"
not_says "a wiki-linked concept is not an orphan" "$orph" "concepts/retry.md"
not_says "a catalog-linked source is not an orphan" "$orph" "sources/task_2026_01_02_add_retry.md"
miss="$(idx links --missing)"
says "a broken wiki-link is reported" "$miss" "missing: concepts/ghost"
not_says "an existing target is not missing" "$miss" "concepts/retry"
both="$(idx links)"
says "links with no flag runs both lints" "$both" "orphan: concepts/orphan.md"
says "links with no flag runs both lints" "$both" "missing: concepts/ghost"

echo "kb-index — usage and dry-run"

new_fixture
is "no subcommand is a usage error" "$(idx_code)" "2"
is "query without terms is a usage error" "$(idx_code query)" "2"
is "an unknown subcommand is a usage error" "$(idx_code bogus)" "2"
is "a non-numeric --limit is rejected" "$(idx_code query retry --limit x)" "2"
idx rebuild --dry-run >/dev/null
if [ -f "$FIXTURE/knowledge/.index.sqlite" ]; then bad "dry-run writes nothing" ".index.sqlite exists"; else ok "dry-run writes nothing"; fi

echo
echo "kb-index: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
