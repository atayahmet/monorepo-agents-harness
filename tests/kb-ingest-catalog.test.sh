#!/usr/bin/env bash
# Tests for kb-ingest.sh's index.md catalog rows (issue #75): one table header per section, the ADR
# overview comes from the ADR's title (not its frontmatter fence), and a re-run never duplicates a
# row whose overview the agent has since edited. Also check-kb's lint for repeated headers / keys.
#
# Repo-local on purpose: not in core/install-manifest.txt, so it never reaches a consumer bundle.
# Run it from anywhere:  bash tests/kb-ingest-catalog.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-kb-catalog-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

INGEST="$REPO/core/scripts/kb-ingest.sh"
STATE="$REPO/core/scripts/task-state.sh"
SLUG="task_2026_11_22_example"
TASK="apps/api/.agents/artifacts/$SLUG"
KB="$FIXTURE/knowledge"
IDX="$KB/index.md"
ingest()  { ( cd "$FIXTURE" && bash "$INGEST" "$TASK" 2>&1 ); }
checkkb() { ( cd "$FIXTURE" && bash "$STATE" check-kb "$TASK" 2>&1 ); }
# count <fixed string> — lines of index.md that contain it
count()   { grep -cF -- "$1" "$IDX" || true; }
# section <title> — the lines of one `### <title>` section
section() { awk -v s="### $1" '$0 == s { f=1; next } f && /^##/ { exit } f' "$IDX"; }

adr() { # <file> <title>
  printf -- '---\nstatus: accepted\ndate: 2026-11-22\n---\n\n# %s\n\nDecision text.\n' "$2" > "$FIXTURE/$TASK/adr/$1"
}

new_fixture() { # <index style: template|bare>
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . )
  mkdir -p "$KB/modules" "$KB/sources" "$KB/decision-records" "$KB/verified-facts" "$FIXTURE/$TASK/adr"
  printf '# Knowledge schema\n' > "$KB/schema.md"
  printf '# Log\n\n| Date | Op | Task | Pages |\n| ---- | -- | ---- | ----- |\n' > "$KB/log.md"
  if [ "$1" = template ]; then
    sed 's/{{PROJECT_NAME}}/fixture/' "$REPO/core/knowledge-template/index.md" > "$IDX"
  else
    printf '# Knowledge index\n\n### Sources (per-task synopses)\n\n### Decision records (compiled from adr/)\n\n### Verified facts (from 4_verify.md)\n\n(end of catalog)\n' > "$IDX"
  fi
  printf '# Memory\n\nFacts.\n' > "$FIXTURE/$TASK/3_memory.md"
  printf '# Verify\n\nClaims.\n' > "$FIXTURE/$TASK/4_verify.md"
  adr 0001-example.md "ADR 0001 — Use X"
  adr 0002-example.md "ADR 0002 — Pipe | in title"
}

for style in template bare; do
  echo "kb-ingest catalog ($style index) — first ingest"
  new_fixture "$style"
  out="$(ingest)"; rc=$?
  is "[$style] ingest exits 0" "$rc" "0"
  for s in "Sources (per-task synopses)" "Decision records (compiled from adr/)" "Verified facts (from 4_verify.md)"; do
    is "[$s] exactly one header separator" "$(section "$s" | grep -cE '^\| *-+ *\|' || true)" "1"
  done
  is "[$style] ADR overview is the title, not '---'" "$(count '| 0001-example.md | ADR 0001 — Use X — [decision-records/0001-example.md](decision-records/0001-example.md) |')" "1"
  is "[$style] no '---' overview" "$(count '| --- —')" "0"
  is "[$style] a '|' in the title is escaped" "$(count 'Pipe \| in title')" "1"
  is "[$style] rows land in ADR order" "$(section 'Decision records (compiled from adr/)' | grep -oE '^\| 000[12]' | tr -d '| ' | tr '\n' ' ')" "0001 0002 "
  if [ "$style" = template ]; then
    is "[$style] new rows follow the existing table" "$(section 'Sources (per-task synopses)' | sed -n '2,3p' | head -1)" "| Page | Task |"
  fi
  says "[$style] check-kb passes" "$(checkkb)" "coverage complete"

  echo "kb-ingest catalog ($style index) — re-run after the agent edits the overviews"
  sed -i.bak 's/^\(| 0001-example\.md | \).* — \[/\1We use X because Y — [/' "$IDX" && rm -f "$IDX.bak"
  is "[$style] the overview edit applied" "$(count 'We use X because Y')" "1"
  printf -- '\nMore decision text.\n' >> "$FIXTURE/$TASK/adr/0001-example.md"
  snapshot="$(cat "$IDX")"
  out="$(ingest)"; rc=$?
  is "[$style] re-run exits 0" "$rc" "0"
  is "[$style] re-run leaves index.md byte-identical" "$(cat "$IDX")" "$snapshot"
  is "[$style] one row per ADR key" "$(count '(decision-records/0001-example.md)')" "1"
  says "[$style] re-run reports the row as present" "$out" "already has"
done

echo "check-kb — lints a damaged catalog"
new_fixture bare
ingest >/dev/null
printf '| Page | Overview |\n| ---- | -------- |\n' > "$FIXTURE/hdr"
awk -v f="$FIXTURE/hdr" '{ print } /^\| 0001-example.md/ { while ((getline l < f) > 0) print l }' "$IDX" > "$IDX.tmp" && mv "$IDX.tmp" "$IDX"
out="$(checkkb)"; rc=$?
is "repeated header: check-kb exits 1" "$rc" "1"
says "repeated header: named" "$out" "repeated table header"
new_fixture bare
ingest >/dev/null
awk '{ print } /^\| 0001-example.md/ { print "| 0001-example.md | again — [x](decision-records/0001-example.md) |" }' "$IDX" > "$IDX.tmp" && mv "$IDX.tmp" "$IDX"
out="$(checkkb)"; rc=$?
is "duplicate key: check-kb exits 1" "$rc" "1"
says "duplicate key: named" "$out" "decision-records/0001-example.md"
new_fixture template
ingest >/dev/null
is "seeded template index passes the lint" "$(checkkb >/dev/null; echo $?)" "0"

echo
echo "kb-ingest-catalog: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
