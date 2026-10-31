#!/usr/bin/env bash
# Tests for `tracker-issue.sh --show <ref>` (issue #49): the read-only task lookup that
# `/monorepo-harness-spec <intent.md> <task-issue-url>` (or a phase number resolved to a tracker key) uses to learn which phase a task link names.
#
# A stub `gh` makes the read deterministic: the suite proves the ref and repo reach the CLI, that the
# printed block carries number/state/url/title/body, that the mode writes nothing, and that every
# failure is named: usage (2), harness-repo refusal (1), unimplemented tracker or unreachable gh (3).
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Run it from anywhere:  bash tests/tracker-issue-show.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-show.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE/bin" "$FIXTURE/.agents"
  cp "$REPO/core/scripts/tracker-issue.sh" "$FIXTURE/tracker-issue.sh"
  cp "$REPO/core/scripts/forge.sh" "$FIXTURE/forge.sh"
  ( cd "$FIXTURE" \
      && git init -q . \
      && git config user.email t@example.com \
      && git config user.name test \
      && git remote add origin https://github.com/acme/web.git )
  cat > "$FIXTURE/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GH_LOG:?}"
if [ "${GH_FAIL:-0}" = "1" ]; then
  echo "gh: cannot reach github" >&2
  exit 1
fi
[ "$1 $2" = "issue view" ] || { echo "stub: unexpected $*" >&2; exit 1; }
ref="$3"; repo=""
shift 3
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'tracker-issue: issue number=%s state=OPEN target=%s\n' "$ref" "$repo"
printf 'https://github.com/%s/issues/%s\n' "$repo" "$ref"
printf -- '--- title ---\nAdd login form\n--- body ---\nScope: login form\n'
STUB
  chmod +x "$FIXTURE/bin/gh"
}

# show <args...> - run --show inside the fixture with the stub gh on PATH.
show() { ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --show "$@" 2>&1 ); }
show_code() { ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --show "$@" >/dev/null 2>&1 ); echo $?; }

new_fixture
: > "$FIXTURE/gh.log"

printf '\n--show reads a task issue\n'
out="$(show 42)"; code=$?
is "numeric ref exits 0" "$code" "0"
says "prints the issue number and state" "$out" "number=42 state=OPEN"
says "prints the url" "$out" "https://github.com/acme/web/issues/42"
says "prints the title section" "$out" "--- title ---"
says "prints the body section" "$out" "Scope: login form"
says "passes the resolved repo to gh" "$(cat "$FIXTURE/gh.log")" "--repo acme/web"

: > "$FIXTURE/gh.log"
out="$(show '#42')"; code=$?
is "#-prefixed ref exits 0" "$code" "0"
says "normalizes the # away before reading" "$(cat "$FIXTURE/gh.log")" "issue view 42"

: > "$FIXTURE/gh.log"
show 'https://github.com/acme/web/issues/42' >/dev/null
says "accepts a full issue URL" "$(cat "$FIXTURE/gh.log")" "issues/42"

printf '\n--show is read-only\n'
( cd "$FIXTURE" && git add -A && git commit -qm fixture )
before="$(cd "$FIXTURE" && git status --porcelain)"
show 42 >/dev/null
after="$(cd "$FIXTURE" && git status --porcelain)"
# The test may write gh.log in the fixture tree; that is the stub's debug log (set by PATH),
# not a file created by tracker-issue.sh itself. Ignore untracked logs outside .agents/.
if [ "$after" = "$before" ]; then
  ok "writes no file and changes no tracked file"
else
  after_nolog="$(printf '%s\n' "$after" | grep -v 'gh\.log' || true)"
  before_nolog="$(printf '%s\n' "$before" | grep -v 'gh\.log' || true)"
  is "writes no file and changes no tracked file" "$after_nolog" "$before_nolog"
fi

printf '\n--show failure contracts\n'
is "missing ref is a usage error" "$(show_code)" "2"
is "harness repo is refused" "$(show_code 42 --repo atayahmet/monorepo-agents-harness)" "1"
is "unimplemented tracker exits 3" "$(show_code 42 --tracker jira)" "3"
out="$( ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_FAIL=1 GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --show 42 2>&1 ) )"
is "unreachable gh exits 3" "$( ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_FAIL=1 GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --show 42 >/dev/null 2>&1 ); echo $? )" "3"
says "unreachable gh is reported, not read as empty" "$out" "could not read"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
