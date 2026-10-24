#!/usr/bin/env bash
# Tests for `forge.sh approve` — the approval write the `/monorepo-harness-intent --approve` path
# uses to put a real approving review on the intent's PR (issue #51).
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# The fixture is a throwaway git repo with a GitHub `origin` and a fake `gh` on PATH. That is enough
# to drive the cli rung deterministically: the stub logs every argv, flips an "approved" state file
# on `pr review`, and can be told to refuse or to succeed-without-recording.
#
# Run it from anywhere:  bash tests/forge-approve.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-approve-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
not_says() { case "$2" in *"$3"*) bad "$1" "output must not mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

FORGE_SRC="$REPO/core/scripts/forge.sh"

# new_fixture — a git repo with a GitHub origin and a fake gh that behaves like the real CLI for the
# three calls forge.sh makes. State the stub honours:
#   GH_STATE        OPEN (default) | MERGED
#   GH_REVIEWS      TSV rows for `pr view --json reviews`, default empty
#   GH_REVIEW_EXIT  exit code of `pr review`, default 0
#   GH_RECORD       when "0", a successful `pr review` does NOT flip the approved state (an
#                   approval the forge accepted but the harness cannot confirm)
#   GH_APPROVED     the marker file the stub reads/writes
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE/bin" "$FIXTURE/emptybin"
  cp "$FORGE_SRC" "$FIXTURE/forge.sh"
  git -C "$FIXTURE" init -q 2>/dev/null || { mkdir -p "$FIXTURE/.git"; git init -q "$FIXTURE"; }
  git -C "$FIXTURE" remote add origin https://github.com/acme/web.git 2>/dev/null || true
  cat > "$FIXTURE/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
log="${GH_LOG:?}"
printf '%s\n' "$*" >> "$log"
case "${1:-}" in
  auth) exit 0 ;;
  pr)
    shift
    case "${1:-}" in
      view)
        shift; shift || true
        case " $* " in
          *" --json reviews "*)
            if [ -n "${GH_APPROVED:-}" ] && [ -f "$GH_APPROVED" ]; then
              printf 'alice\tAPPROVED\t2026-10-24T10:00:00Z\n'
            elif [ -n "${GH_REVIEWS:-}" ]; then
              printf '%s' "$GH_REVIEWS"
            fi ;;
          *" --json state,"*)
            printf 'state=%s title=Test mergeable=MERGEABLE status=CLEAN\n' "${GH_STATE:-OPEN}" ;;
          *) : ;;
        esac ;;
      review)
        if [ "${GH_REVIEW_EXIT:-0}" -ne 0 ]; then
          echo "gh: cannot approve this pull request" >&2
          exit "${GH_REVIEW_EXIT:-0}"
        fi
        if [ "${GH_RECORD:-1}" = "1" ] && [ -n "${GH_APPROVED:-}" ]; then
          : > "$GH_APPROVED"
        fi ;;
      *) : ;;
    esac ;;
  *) : ;;
esac
exit 0
STUB
  chmod +x "$FIXTURE/bin/gh"
  : > "$FIXTURE/gh.log"
}

# approve <args> — run the script from inside the fixture with the stub gh first on PATH.
approve() {
  (
    cd "$FIXTURE" || exit 99
    env -u GITHUB_TOKEN -u GITLAB_TOKEN -u BITBUCKET_TOKEN -u GITEA_TOKEN -u HARNESS_FORGE \
      PATH="$FIXTURE/bin:$PATH" \
      GH_LOG="$FIXTURE/gh.log" GH_APPROVED="$FIXTURE/approved" \
      bash ./forge.sh approve 42 "$@" 2>&1
  )
}
logged() { grep -q "$1" "$FIXTURE/gh.log"; }
gh_logged() { if logged "$1"; then echo yes; else echo no; fi; }

# --- the happy path: a real write, confirmed by a re-read -----------------------------------------
new_fixture
out="$(approve --yes --body "Approved for dispatch")"; code=$?
is "approve --yes exits 0" "$code" "0"
says "the success names the PR" "$out" "PR 42"
says "the success names the platform" "$out" "github"
is "the PR review command ran" "$(gh_logged 'pr review 42 --approve')" "yes"
is "the --body reached the forge" "$(gh_logged 'Approved for dispatch')" "yes"
not_says "approve never merges" "$out" "merged"
is "approve never calls a merge subcommand" "$(gh_logged 'pr merge')" "no"
is "no merge was attempted" "$(gh_logged ' merge ')" "no"

# --- idempotence: an already-approved PR is a no-op, not a second review ---------------------------
new_fixture
export GH_APPROVED="$FIXTURE/approved"
: > "$GH_APPROVED"
out="$(approve --yes)"; code=$?
is "an already-approved PR exits 0" "$code" "0"
says "the no-op names the existing approver" "$out" "already approved by alice"
is "no second review was submitted" "$(gh_logged 'pr review')" "no"
unset GH_APPROVED

# --- dry run: --yes is the in-turn consent, and --explain is the same ---------------------------------
new_fixture
out="$(approve)"; code=$?
is "approve without --yes exits 0 as a dry run" "$code" "0"
says "the dry run shows what would run" "$out" "would approve"
says "the dry run says nothing was approved" "$out" "nothing approved"
is "the dry run submitted no review" "$(gh_logged 'pr review')" "no"

new_fixture
out="$(approve --explain --yes)"; code=$?
is "--explain exits 0" "$code" "0"
says "--explain shows what would run" "$out" "would approve"
is "--explain submitted no review even with --yes" "$(gh_logged 'pr review')" "no"

# --- a merged PR has nothing to approve ---------------------------------------------------------------
new_fixture
export GH_STATE=MERGED
out="$(approve --yes)"; code=$?
is "a merged PR exits 0" "$code" "0"
says "a merged PR says there is nothing to approve" "$out" "already merged"
is "no review was submitted on a merged PR" "$(gh_logged 'pr review')" "no"
unset GH_STATE

# --- refusals and unconfirmed writes keep their different answers --------------------------------------
new_fixture
export GH_REVIEW_EXIT=1
out="$(approve --yes)"; code=$?
is "a forge refusal exits 1" "$code" "1"
says "the refusal is reported" "$out" "was NOT approved"
says "the refusal is the forge's own reason" "$out" "cannot approve"
unset GH_REVIEW_EXIT

new_fixture
export GH_RECORD=0
out="$(approve --yes)"; code=$?
is "a sent-but-unconfirmed approval exits 1" "$code" "1"
says "the unconfirmed write is reported honestly" "$out" "could not confirm"
export GH_RECORD=1

# --- no mechanism: exit 3, never a false approval ------------------------------------------------------
new_fixture
out="$(
  cd "$FIXTURE" || exit 99
  env -u GITHUB_TOKEN -u HARNESS_FORGE PATH="$FIXTURE/emptybin:/usr/bin:/bin" \
    bash ./forge.sh approve 42 --yes 2>&1
)"; code=$?
is "no mechanism exits 3, not 1" "$code" "3"
says "the handoff says nothing was approved" "$out" "NOT approved"

# --- option contract ----------------------------------------------------------------------------------
new_fixture
out="$(
  cd "$FIXTURE" || exit 99
  bash ./forge.sh state 42 --body "nope" 2>&1
)"; code=$?
is "--body is refused outside approve (exit 2)" "$code" "2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
