#!/usr/bin/env bash
# Tests for the per-workspace state files (issue #90): the installer merges the .gitattributes and
# .gitignore fragments (idempotently, keeping the project's own lines), lessons.md merges without a
# conflict under merge=union, and audit-install.sh warns when a project rule ignores a lessons.md.
#
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
# Every case runs in throwaway git repos under mktemp -d, installed from this checkout.
#   bash tests/workspace-state.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-state-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd -P)"
mkdir -p "$TMP/home"
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$(dirname "$TMP")"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

pass=0; fail=0
ok()    { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()   { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "did not expect '$3' in: $2" ;; *) ok "$1" ;; esac; }
check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n" "failed: $*"; fi; }
checkn() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$n" "succeeded: $*"; else ok "$n"; fi; }

# new_consumer <dir> - a git repo laid out like a project: a root package and two workspaces.
new_consumer() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d/apps/web" "$d/apps/api"
  git init -q -b main "$d"
  echo '{"name":"consumer"}' > "$d/package.json"
  echo '{}' > "$d/apps/web/package.json"
  echo '{}' > "$d/apps/api/package.json"
  git -C "$d" add -A && git -C "$d" commit -qm "project"
}
# install_in <dir> - run the installer from this checkout inside <dir>. Sets INST_RC and INST_LOG.
install_in() {
  INST_LOG="$(cd "$1" && bash "$REPO/core/scripts/install-harness.sh" --from "$REPO" --no-git-hook --project-name consumer 2>&1)"
  INST_RC=$?
}
# audit_in <dir> - run the installed audit inside <dir>. Sets AUD_RC and AUD_OUT.
audit_in() {
  AUD_OUT="$(cd "$1" && bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh 2>&1)"
  AUD_RC=$?
}
# count_line <file> <line> - how many lines of <file> equal <line> exactly.
count_line() { grep -cxF -- "$2" "$1" 2>/dev/null || true; }

UNION='**/.agents/lessons.md merge=union'

echo "AC7 — the installer writes the lessons attribute once, keeps the project's own lines"
C1="$TMP/c1"; new_consumer "$C1"
install_in "$C1"
is    "the install exits 0" "$INST_RC" 0
check "the install creates .gitattributes" test -f "$C1/.gitattributes"
is    "the union line is there once" "$(count_line "$C1/.gitattributes" "$UNION")" 1
cp "$C1/.gitattributes" "$TMP/attr.first" 2>/dev/null || true
install_in "$C1"
is    "a second install exits 0" "$INST_RC" 0
check "a second install leaves .gitattributes byte for byte" cmp -s "$C1/.gitattributes" "$TMP/attr.first"
says  "a second install reports the file as already carrying the fragment" "$INST_LOG" ".gitattributes already carries core/gitattributes-fragment.txt"

C2="$TMP/c2"; new_consumer "$C2"
printf '*.png binary\n' > "$C2/.gitattributes"
install_in "$C2"
is    "an existing .gitattributes: the install exits 0" "$INST_RC" 0
is    "an existing .gitattributes keeps its own line" "$(count_line "$C2/.gitattributes" '*.png binary')" 1
is    "an existing .gitattributes gains the union line once" "$(count_line "$C2/.gitattributes" "$UNION")" 1

echo "AC8 — the installer writes the session-log and todo ignore lines once"
G="**/.agents/session-log.md"; T="**/.agents/todo.md"
is    "the session-log ignore line is there once" "$(count_line "$C1/.gitignore" "$G")" 1
is    "the todo ignore line is there once" "$(count_line "$C1/.gitignore" "$T")" 1
is    "the derived-cache line is kept" "$(count_line "$C1/.gitignore" "knowledge/.index.sqlite*")" 1
cp "$C1/.gitignore" "$TMP/ignore.first"
install_in "$C1"
check "a second install leaves .gitignore byte for byte" cmp -s "$C1/.gitignore" "$TMP/ignore.first"

echo "AC9 — lessons.md merges without a conflict under the installed attribute"
# Two branches each add a lesson in apps/web. With the installed .gitattributes the merge is clean;
# without it (the control) the same two edits conflict.
M="$TMP/merge"; mkdir -p "$M/apps/web/.agents"; git init -q -b main "$M"
printf '# Lessons\n\n- **old**: keep it. (learned 2026-11-01)\n' > "$M/apps/web/.agents/lessons.md"
cp "$C1/.gitattributes" "$M/.gitattributes" 2>/dev/null || true
git -C "$M" add -A && git -C "$M" commit -qm base
git -C "$M" checkout -q -b lesson-a
printf -- '- **A**: first lesson. (learned 2026-11-27)\n' >> "$M/apps/web/.agents/lessons.md"
git -C "$M" commit -qam "lesson a"
git -C "$M" checkout -q main && git -C "$M" checkout -q -b lesson-b
printf -- '- **B**: second lesson. (learned 2026-11-27)\n' >> "$M/apps/web/.agents/lessons.md"
git -C "$M" commit -qam "lesson b"
git -C "$M" checkout -q main && git -C "$M" merge -q --no-edit lesson-a
out="$(git -C "$M" merge --no-edit lesson-b 2>&1)"; rc=$?
is    "the second lesson merges with exit 0" "$rc" 0
check "both lessons are in the merged file" test "$(count_line "$M/apps/web/.agents/lessons.md" '- **A**: first lesson. (learned 2026-11-27)')" = 1
checkn "no conflict markers in the merged lessons.md" grep -q '^<<<<<<<' "$M/apps/web/.agents/lessons.md"

# The control: the same edits without the attribute conflict, so the attribute is what makes the merge clean.
N="$TMP/merge-control"; mkdir -p "$N/apps/web/.agents"; git init -q -b main "$N"
printf '# Lessons\n\n- **old**: keep it. (learned 2026-11-01)\n' > "$N/apps/web/.agents/lessons.md"
git -C "$N" add -A && git -C "$N" commit -qm base
git -C "$N" checkout -q -b lesson-a
printf -- '- **A**: first lesson. (learned 2026-11-27)\n' >> "$N/apps/web/.agents/lessons.md"
git -C "$N" commit -qam "lesson a"
git -C "$N" checkout -q main && git -C "$N" checkout -q -b lesson-b
printf -- '- **B**: second lesson. (learned 2026-11-27)\n' >> "$N/apps/web/.agents/lessons.md"
git -C "$N" commit -qam "lesson b"
git -C "$N" checkout -q main && git -C "$N" merge -q --no-edit lesson-a
git -C "$N" merge -q --no-edit lesson-b >/dev/null 2>&1; rc=$?
check "control: without the attribute the same merge conflicts" test "$rc" -ne 0
git -C "$N" merge --abort 2>/dev/null || true

echo "AC10 — audit-install warns about a lessons.md that a project rule ignores"
C3="$TMP/c3"; new_consumer "$C3"
install_in "$C3"
printf '**/.agents/lessons.md\n' >> "$C3/.gitignore"
check "the workspace lessons.md exists (seeded by the scaffold)" test -f "$C3/apps/web/.agents/lessons.md"
audit_in "$C3"
says  "audit warns about the ignored web lessons.md" "$AUD_OUT" "apps/web/.agents/lessons.md is git-ignored"
says  "audit warns about the ignored api lessons.md" "$AUD_OUT" "apps/api/.agents/lessons.md is git-ignored"
is    "a warning is not a gap: audit exits 0" "$AUD_RC" 0
# Tracked wins: a lessons.md that git tracks does not warn, even when a rule also matches it.
git -C "$C3" add -f apps/web/.agents/lessons.md && git -C "$C3" commit -qm "track web lessons"
audit_in "$C3"
saysn "a tracked lessons.md does not warn" "$AUD_OUT" "apps/web/.agents/lessons.md is git-ignored"
says  "the untracked api lessons.md still warns" "$AUD_OUT" "apps/api/.agents/lessons.md is git-ignored"

C4="$TMP/c4"; new_consumer "$C4"
install_in "$C4"
audit_in "$C4"
saysn "control: no project ignore rule, no lessons warning" "$AUD_OUT" "is git-ignored"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
