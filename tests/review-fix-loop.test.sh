#!/usr/bin/env bash
# Tests for review-fix-loop.sh — the deterministic helper behind `/monorepo-harness-review --auto-fix`
# (issue #77): the clean-tree preflight, the new-file check and the security-pass trigger.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Every case runs against a throwaway git fixture. Run it from anywhere:
#   bash tests/review-fix-loop.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-review-loop-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }

HELPER="$REPO/core/scripts/review-fix-loop.sh"
# Run the helper inside the fixture. Output and exit code are captured separately.
run()  { ( cd "$FIXTURE" && bash "$HELPER" "$@" 2>&1 ); }
code() { ( cd "$FIXTURE" && bash "$HELPER" "$@" >/dev/null 2>&1 ); echo $?; }
first() { run "$@" | head -n1; }

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com \
    && git config user.name test && printf 'seed\n' > README.md && git add -A \
    && git commit -qm seed )
}
# commit_file <path> - create the file (with parent dirs) and commit it.
commit_file() {
  mkdir -p "$FIXTURE/$(dirname "$1")"; printf 'x\n' > "$FIXTURE/$1"
  ( cd "$FIXTURE" && git add -A && git commit -qm "add $1" )
}
head_sha() { ( cd "$FIXTURE" && git rev-parse HEAD ); }

echo "review-fix-loop — preflight"

new_fixture
is   "clean tree passes" "$(code preflight)" "0"
says "clean tree prints the base sha" "$(run preflight)" "base: $(head_sha)"
says "default round limit is 2" "$(run preflight)" "max-rounds: 2"
is   "--max-rounds 3 passes" "$(code preflight --max-rounds 3)" "0"
says "--max-rounds 3 is echoed" "$(run preflight --max-rounds 3)" "max-rounds: 3"
is   "--max-rounds 5 passes (upper bound)" "$(code preflight --max-rounds 5)" "0"
is   "--max-rounds 0 is a usage error" "$(code preflight --max-rounds 0)" "2"
is   "--max-rounds 6 is a usage error" "$(code preflight --max-rounds 6)" "2"
is   "--max-rounds x is a usage error" "$(code preflight --max-rounds x)" "2"
is   "--max-rounds without a value is a usage error" "$(code preflight --max-rounds)" "2"

printf 'changed\n' > "$FIXTURE/README.md"
is   "modified tracked file refuses" "$(code preflight)" "1"
says "refusal names the dirty file" "$(run preflight)" "README.md"

new_fixture
printf 'new\n' > "$FIXTURE/scratch.txt"
is   "untracked file refuses" "$(code preflight)" "1"
says "refusal names the untracked file" "$(run preflight)" "scratch.txt"

new_fixture
printf 'staged\n' > "$FIXTURE/staged.txt"; ( cd "$FIXTURE" && git add staged.txt )
is   "staged file refuses" "$(code preflight)" "1"

echo "review-fix-loop — check-fix"

new_fixture; base="$(head_sha)"
is   "no change since base passes" "$(code check-fix "$base")" "0"
commit_file src/foo.ts
is   "committed new non-test file refuses" "$(code check-fix "$base")" "1"
says "refusal names the new file" "$(run check-fix "$base")" "src/foo.ts"

new_fixture; base="$(head_sha)"
commit_file src/foo.test.ts
commit_file tests/x.sh
commit_file pkg/__tests__/a.js
commit_file lib/thing_test.go
commit_file app/test_utils.py
commit_file web/button.spec.tsx
is   "new test files pass" "$(code check-fix "$base")" "0"

new_fixture; base="$(head_sha)"
printf 'x\n' > "$FIXTURE/README.md"; ( cd "$FIXTURE" && git commit -qam edit )
is   "edit of an existing file passes" "$(code check-fix "$base")" "0"

new_fixture; base="$(head_sha)"
mkdir -p "$FIXTURE/src"; printf 'x\n' > "$FIXTURE/src/new.ts"
is   "untracked new non-test file refuses" "$(code check-fix "$base")" "1"
( cd "$FIXTURE" && git add src/new.ts )
is   "staged new non-test file refuses" "$(code check-fix "$base")" "1"

new_fixture
is   "check-fix without a base is a usage error" "$(code check-fix)" "2"
is   "check-fix with a bad ref is a usage error" "$(code check-fix no-such-ref)" "2"

echo "review-fix-loop — security-due"

new_fixture; base="$(head_sha)"
commit_file src/auth/login.ts
is   "auth path is security-sensitive" "$(first security-due "$base")" "yes"

new_fixture; base="$(head_sha)"
commit_file pnpm-lock.yaml
is   "lockfile is security-sensitive" "$(first security-due "$base")" "yes"

new_fixture; base="$(head_sha)"
commit_file .env.local
is   ".env file is security-sensitive" "$(first security-due "$base")" "yes"

new_fixture; base="$(head_sha)"
commit_file api/webhooks/stripe.ts
is   "webhook path is security-sensitive" "$(first security-due "$base")" "yes"

new_fixture; base="$(head_sha)"
printf 'x\n' > "$FIXTURE/README.md"; ( cd "$FIXTURE" && git commit -qam docs )
commit_file src/utils/format.ts
is   "plain paths are not security-sensitive" "$(first security-due "$base")" "no"
is   "security-due exits 0 when it decides" "$(code security-due "$base")" "0"

new_fixture; base="$(head_sha)"
is   "no change is not security-sensitive" "$(first security-due "$base")" "no"
is   "security-due without a ref is a usage error" "$(code security-due)" "2"

echo "review-fix-loop — usage"
is   "unknown subcommand is a usage error" "$(code frobnicate)" "2"
is   "no subcommand is a usage error" "$(code)" "2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
