#!/usr/bin/env bash
# Phase A tests for team.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEAM="$REPO/core/scripts/team.sh"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says(){ case "$2" in *"$3"*) ok "$1";; *) bad "$1" "expected '$3' in output";; esac; }
is(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q && git config user.email a@example.com && git config user.name A

# missing
out="$("$TEAM" whoami 2>&1)"; ec=$?; is "missing exits 4" "$ec" "4"

mkdir -p .agents
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: alice
    name: Alice Example
    role: developer
    ids:
      git:
        - a@example.com
        - alice@users.noreply.github.com
      github: alice-example
contacts:
  - key: bob
    name: Bob Example
    role: product_owner
    ids:
      slack: U111
assignee_by_workspace:
  .: [alice]
  apps/api: [alice, carol]
  apps/web: []
YAML

# whoami
out="$("$TEAM" whoami 2>&1)"; ec=$?; is "whoami ok" "$ec" "0"; says "whoami returns key" "$out" "alice"
out="$("$TEAM" match github alice-example 2>&1)"; ec=$?; is "match github" "$ec" "0"; says "match returns alice" "$out" "alice"
out="$("$TEAM" assignee apps/web 2>&1)"; ec=$?; is "assignee empty -> ask" "$out" "ask"
out="$("$TEAM" assignee . 2>&1)"; ec=$?; says "assignee root" "$out" "alice"
out="$("$TEAM" assignee apps/api 2>&1)"; ec=$?; says "assignee api" "$out" "alice"
out="$("$TEAM" lint 2>&1)"; ec=$?; is "lint ok" "$ec" "0"
out="$("$TEAM" find --role developer 2>&1)"; ec=$?; says "find dev" "$out" "alice"
out="$("$TEAM" find --role product_owner 2>&1)"; ec=$?; says "find po" "$out" "bob"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
