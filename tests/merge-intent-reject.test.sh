#!/usr/bin/env bash
# Tests for `task-state.sh merge-intent-pr --reject` — the reject path's merge gate
# (issue #45): a PR approval is never read; the consent is the intent file's own
# `status: rejected` plus the in-turn `--yes`.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# The fixture copies task-state.sh next to a stub forge.sh (the script resolves the forge relative
# to itself), so every branch of the gate is driven deterministically: OPEN/MERGED/unreadable PR
# state, merge exit codes, and a review board that — in reject mode — must never be consulted (the
# stub fails the test if `reviews` is ever called there).
#
# Run it from anywhere:  bash tests/merge-intent-reject.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-mir-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

TS_SRC="$REPO/core/scripts/task-state.sh"

# Copies task-state.sh beside a stub forge.sh and writes an intent with the given status.
# Env the stub honours:
#   FORGE_STATE        OPEN (default) | MERGED | UNREADABLE
#   FORGE_MERGE_EXIT   exit code of a real (non --explain) merge, default 0
#   FORGE_REVIEWS      rows the `reviews` subcommand prints, default empty
# Every subcommand the stub receives is appended to .forge-log so a test can prove
# which questions were asked — in particular that reject mode never asks for reviews.
new_fixture() {
  local status="${1:-rejected}"
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  cp "$TS_SRC" "$FIXTURE/task-state.sh"
  cat > "$FIXTURE/forge.sh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
log="${FORGE_LOG:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.forge-log}"
printf '%s\n' "$1" >> "$log"
sub="${1:-}"; shift || true
case "$sub" in
  state)
    case "${FORGE_STATE:-OPEN}" in
      UNREADABLE) echo "forge: cannot reach this PR" >&2; exit 3 ;;
      MERGED) echo "state=MERGED" ;;
      *) echo "state=OPEN" ;;
    esac ;;
  reviews)
    printf '%s' "${FORGE_REVIEWS:-}" ;;
  merge)
    for a in "$@"; do
      if [ "$a" = "--explain" ]; then
        echo "merge commit into main"
        exit 0
      fi
    done
    echo "merged"
    exit "${FORGE_MERGE_EXIT:-0}" ;;
  *)
    echo "forge-stub: unexpected subcommand '$sub'" >&2
    exit 99 ;;
esac
STUB
  chmod +x "$FIXTURE/forge.sh"
  printf -- '---\nstatus: %s\n---\n\n# Intent\n\nA test intent.\n' "$status" > "$FIXTURE/intent.md"
  : > "$FIXTURE/.forge-log"
}
merge()      { ( cd "$FIXTURE" && FORGE_LOG="$FIXTURE/.forge-log" bash ./task-state.sh merge-intent-pr intent.md --pr 42 "$@" 2>&1 ); }
merge_code() { ( cd "$FIXTURE" && FORGE_LOG="$FIXTURE/.forge-log" bash ./task-state.sh merge-intent-pr intent.md --pr 42 "$@" >/dev/null 2>&1 ); echo $?; }
forge_asked() { grep -qx "$1" "$FIXTURE/.forge-log"; }

# --- the gate swap: rejected merges with zero reviews, anything else refuses --------------------------
new_fixture rejected
out="$(merge --reject --yes)"
is "reject mode merges a status-rejected intent with no approving review" "$(merge_code --reject --yes)" "0"
says "the merge success names reject mode" "$out" "reject mode"
is "the merge subcommand ran" "$(forge_asked merge && echo yes)" "yes"
is "the review board was never consulted in reject mode" "$(grep -qx reviews "$FIXTURE/.forge-log" && echo yes || echo no)" "no"

new_fixture pending
out="$(merge --reject --yes)"
is "reject mode refuses a status-pending intent" "$(merge_code --reject --yes)" "1"
says "the refusal names the actual status" "$out" "status is 'pending'"
says "the refusal says nothing was merged" "$out" "refusing to merge"

new_fixture approved
is "reject mode refuses a status-approved intent" "$(merge_code --reject --yes)" "1"

new_fixture ""
# An intent file with no status line at all: frontmatter_field prints nothing.
printf -- '---\nslug: no_status\n---\n\n# Intent\n' > "$FIXTURE/intent.md"
out="$(merge --reject --yes)"
is "reject mode refuses an intent with no status" "$(merge_code --reject --yes)" "1"
says "a missing status reads as <none>" "$out" "<none>"

# --- state first: already-merged is a no-op, unreadable is exit 3 -------------------------------------
new_fixture rejected
export FORGE_STATE=MERGED
out="$(merge --reject --yes)"
is "an already-merged PR exits 0 in reject mode" "$(merge_code --reject --yes)" "0"
says "the no-op is reported" "$out" "already merged"
unset FORGE_STATE

new_fixture rejected
export FORGE_STATE=UNREADABLE
out="$(merge --reject --yes)"
is "an unreadable PR exits 3, not 1" "$(merge_code --reject --yes)" "3"
says "exit 3 says nothing was merged" "$out" "nothing merged"
unset FORGE_STATE

# --- --yes is still the in-turn consent; without it nothing merges -------------------------------------
new_fixture rejected
out="$(merge --reject)"
is "reject mode without --yes exits 0 as a dry run" "$(merge_code --reject)" "0"
says "the dry run explains the merge" "$out" "merge commit into main"
says "the dry run names the recorded decision" "$out" "status: rejected"
says "the dry run says nothing merged" "$out" "nothing merged"

# --- merge failures keep their exit semantics ----------------------------------------------------------
new_fixture rejected
export FORGE_MERGE_EXIT=1
out="$(merge --reject --yes)"
is "a forge refusal exits 1 and merges nothing" "$(merge_code --reject --yes)" "1"
says "the refusal is reported" "$out" "nothing merged"
unset FORGE_MERGE_EXIT

new_fixture rejected
export FORGE_MERGE_EXIT=3
is "a forge 'not done' (exit 3) passes through as 3" "$(merge_code --reject --yes)" "3"
unset FORGE_MERGE_EXIT

# --- the option contract: --reject belongs to merge-intent-pr alone ------------------------------------
new_fixture rejected
out="$(cd "$FIXTURE" && bash ./task-state.sh check-intent-approved intent.md --pr 42 --reject 2>&1)"
is "--reject is refused by check-intent-approved (exit 2)" \
  "$(cd "$FIXTURE" && bash ./task-state.sh check-intent-approved intent.md --pr 42 --reject >/dev/null 2>&1; echo $?)" "2"
says "the refusal is an option error" "$out" "not a supported option"

# --- the approve route is untouched: it still reads reviews ---------------------------------------------
new_fixture approved
export FORGE_REVIEWS="$(printf 'alice\tAPPROVED\t2026-10-18T10:00:00Z\n')"
out="$(merge --yes)"
is "the approve route still merges on an approving review" "$(merge_code --yes)" "0"
says "the approve route names the reviewer" "$out" "approved by alice"
unset FORGE_REVIEWS

new_fixture approved
export FORGE_REVIEWS="$(printf 'alice\tCHANGES_REQUESTED\t2026-10-18T10:00:00Z\n')"
out="$(merge --yes)"
is "the approve route still refuses changes-requested" "$(merge_code --yes)" "1"
unset FORGE_REVIEWS

new_fixture approved
out="$(merge --yes)"
is "the approve route still refuses a PR with no reviews" "$(merge_code --yes)" "1"
says "the approve refusal keeps its wording" "$out" "no approving review"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
