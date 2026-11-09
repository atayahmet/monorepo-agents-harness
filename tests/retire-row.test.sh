#!/usr/bin/env bash
# Tests for the `retire` adapter-manifest verb (issue #73): `install-adapter.sh` moves a retired file
# to the harness trash only when its content is a shipped version (sha256 in the row), keeps an
# edited one and says so, and does nothing when it is absent. `audit-install.sh` reports a retired
# file that is still present.
#
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
# Run it from anywhere:  bash tests/retire-row.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-retire-row.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

OLD_CLAUDE=".claude/commands/monorepo-harness-agents-init.md"
OLD_CODEX=".agents/skills/monorepo-harness-agents-init/SKILL.md"
RC34=v0.4.0-rc.34   # the only release that shipped the old entry points

new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  local b="$FIXTURE/.agents/monorepo-agents-harness"
  mkdir -p "$b"
  cp -R "$REPO/core" "$b/core"
  cp -R "$REPO/adapters" "$b/adapters"
  cp "$REPO/VERSION" "$b/VERSION"
}
plant() { # <adapter> <project path>: the file exactly as rc.34 shipped it
  mkdir -p "$FIXTURE/$(dirname "$2")"
  git -C "$REPO" show "$RC34:adapters/$1/$2" > "$FIXTURE/$2"
}
refresh() { ( cd "$FIXTURE" && bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh "$1" --refresh 2>&1 ); }
audit()   { ( cd "$FIXTURE" && bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh 2>&1 ); }
trashed() { find "$FIXTURE/.agents/.harness-trash" -type f 2>/dev/null | grep -c "monorepo-harness-agents-init" ; }

echo "retire manifest verb"

# --- 1: unedited rc.34 file -> moved to the trash, new command present, audit clean ---------------
new_fixture; plant claude-code "$OLD_CLAUDE"
out="$(refresh claude-code)"; rc=$?
[ "$rc" -eq 0 ] && ok "unedited: refresh exits 0" || bad "unedited: refresh exits 0" "rc=$rc: $out"
[ -e "$FIXTURE/$OLD_CLAUDE" ] && bad "unedited: old command removed" "still present" || ok "unedited: old command removed"
[ "$(trashed)" -ge 1 ] && ok "unedited: old command is in the trash, not deleted" || bad "unedited: old command is in the trash" "$out"
[ -f "$FIXTURE/.claude/commands/monorepo-harness-init.md" ] && ok "unedited: new command installed" || bad "unedited: new command installed" "$out"
out="$(audit)"
saysn "unedited: audit reports no retired file" "$out" "retired"

# --- 2: codex: the emptied skill dir goes too ------------------------------------------------------
new_fixture; plant codex "$OLD_CODEX"
out="$(refresh codex)"
[ -e "$FIXTURE/$(dirname "$OLD_CODEX")" ] && bad "codex: emptied skill dir removed" "still present" || ok "codex: emptied skill dir removed"
[ -f "$FIXTURE/.agents/skills/monorepo-harness-init/SKILL.md" ] && ok "codex: new skill installed" || bad "codex: new skill installed" "$out"

# --- 3: edited file -> kept, Needs you, audit gap --------------------------------------------------
new_fixture; plant claude-code "$OLD_CLAUDE"
printf '\nmy local note\n' >> "$FIXTURE/$OLD_CLAUDE"
out="$(refresh claude-code)"
[ -f "$FIXTURE/$OLD_CLAUDE" ] && ok "edited: file kept" || bad "edited: file kept" "it was moved"
says "edited: Needs you names the file" "$out" "$OLD_CLAUDE"
says "edited: Needs you says local edits" "$out" "local edits"
out="$(audit)"; rc=$?
[ "$rc" -eq 1 ] && ok "edited: audit exits 1" || bad "edited: audit exits 1" "rc=$rc"
says "edited: audit names the retired file" "$out" "retired entrypoint still present (claude-code): $OLD_CLAUDE"

# --- 4: absent -> no-op; a second run changes nothing ----------------------------------------------
new_fixture
mkdir -p "$FIXTURE/.claude/commands"
cp "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-build.md" "$FIXTURE/.claude/commands/"
out="$(refresh claude-code)"; rc=$?
[ "$rc" -eq 0 ] && ok "absent: refresh exits 0" || bad "absent: refresh exits 0" "rc=$rc: $out"
saysn "absent: nothing about retire in Needs you" "$out" "local edits"
out="$(refresh claude-code)"
saysn "rerun: nothing written" "$out" "  + "
[ -d "$FIXTURE/.agents/.harness-trash" ] && bad "rerun: no trash dir created" "a trash dir exists" || ok "rerun: no trash dir created"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
