#!/usr/bin/env bash
# Tests for the AGENTS.md-import guard added by issue #31: an existing adapter pointer file that does
# not import AGENTS.md (claude-code's root CLAUDE.md) must be reported by audit-install.sh and named
# with its one-line fix by install-adapter.sh — never rewritten.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Every case runs against a throwaway fixture laid out like an installed project — the bundle at
# `.agents/monorepo-agents-harness/`. Run it from anywhere:  bash tests/audit-import.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-audit-import.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

# A clean fixture with the bundle installed the way a consumer gets it, plus the claude-code adapter
# marked as installed (one of its `copy` manifest rows is present).
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name test )
  local b="$FIXTURE/.agents/monorepo-agents-harness"
  mkdir -p "$b"
  cp -R "$REPO/core" "$b/core"
  cp -R "$REPO/adapters" "$b/adapters"
  cp "$REPO/VERSION" "$b/VERSION"
  mkdir -p "$FIXTURE/.claude/commands"
  cp "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-build.md" \
     "$FIXTURE/.claude/commands/monorepo-harness-build.md"
}

audit()   { ( cd "$FIXTURE" && bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh 2>&1 ); }
install() { ( cd "$FIXTURE" && bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh claude-code 2>&1 ); }

echo "audit-import guard"

# --- 1: the import present -> no gap --------------------------------------------------------------
new_fixture
printf '# My repo\n\n@AGENTS.md\n' > "$FIXTURE/CLAUDE.md"
out="$(audit)"
saysn "import present: no import gap" "$out" "does not import"

# --- 2: the import absent -> gap names the token --------------------------------------------------
new_fixture
printf '# My repo\n\nFor details, see AGENTS.md.\n' > "$FIXTURE/CLAUDE.md"
out="$(audit)"
says  "import absent: gap reported" "$out" "does not import"
says  "import absent: names the token" "$out" "@AGENTS.md"

# --- 3: the file missing -> Check 2 only, no duplicate import gap ---------------------------------
new_fixture
rm -f "$FIXTURE/CLAUDE.md"
out="$(audit)"
says  "missing file: Check 2 reports config missing" "$out" "config missing (claude-code): CLAUDE.md"
saysn "missing file: no import gap" "$out" "does not import"

# --- 4: installer warns with the fix, proposes, and never edits the file --------------------------
new_fixture
printf '# My repo\n\nSee AGENTS.md for the details.\n' > "$FIXTURE/CLAUDE.md"
cp "$FIXTURE/CLAUDE.md" "$FIXTURE/claude.orig"
out="$(install)"
says "install: Needs you names the token" "$out" "@AGENTS.md"
if [ -f "$FIXTURE/CLAUDE.md.harness-proposed" ]; then ok "install: proposal written"; else bad "install: proposal written" "no CLAUDE.md.harness-proposed"; fi
if cmp -s "$FIXTURE/claude.orig" "$FIXTURE/CLAUDE.md"; then ok "install: original untouched"; else bad "install: original untouched" "CLAUDE.md changed"; fi

# --- 5: installer is quiet about the import once the line is present ------------------------------
printf '\n@AGENTS.md\n' >> "$FIXTURE/CLAUDE.md"
out="$(install)"
saysn "install after import: no import warning" "$out" "does not import"

# --- 6: text guards — the rule is documented where a writer/reviewer reads it ----------------------
grep -qF '@AGENTS.md' "$REPO/adapters/claude-code/CLAUDE.md" \
  && ok "adapter template carries the @AGENTS.md import" \
  || bad "adapter template carries the @AGENTS.md import" "no @AGENTS.md in adapters/claude-code/CLAUDE.md"
grep -qF 'import gap' "$REPO/core/skills/harness-update/SKILL.md" \
  && ok "harness-update skill documents the import gap" \
  || bad "harness-update skill documents the import gap" "no 'import gap' in harness-update/SKILL.md"
grep -qF '@AGENTS.md' "$REPO/adapters/claude-code/INSTALL.md" \
  && ok "claude-code INSTALL.md documents the import" \
  || bad "claude-code INSTALL.md documents the import" "no '@AGENTS.md' in adapters/claude-code/INSTALL.md"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
