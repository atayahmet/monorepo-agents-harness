#!/usr/bin/env bash
# Parity check for `/monorepo-harness-init` (issues #71, #73): the three adapter entry points carry
# the same body, every install row exists, the shared skill defines each step, the scaffold hint is
# wired, and no install guide grew past the 100-line cap. Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected '$3'" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "bodies differ"; fi; }

CLAUDE="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-init.md"
OPENCODE="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-init.md"
CODEX="$REPO/adapters/codex/.agents/skills/monorepo-harness-init/SKILL.md"
SKILL="$REPO/core/skills/agents-init/SKILL.md"

body() { awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm && !d && /^---[[:space:]]*$/ {d=1; next} d || !fm {print}' "$1"; }

for f in "$CLAUDE" "$OPENCODE" "$CODEX" "$SKILL" "$REPO/core/scripts/agents-tree.sh"; do
  if git -C "$REPO" ls-files --error-unmatch -- "${f#"$REPO"/}" >/dev/null 2>&1; then ok "tracked: ${f#"$REPO"/}"
  else bad "tracked: ${f#"$REPO"/}" "missing or not tracked by git (issue #66)"; fi
done
same "claude and opencode bodies identical" "$(body "$CLAUDE")" "$(body "$OPENCODE")"
same "claude and codex bodies identical" "$(body "$CLAUDE")" "$(body "$CODEX")"
says "codex skill is named" "$(cat "$CODEX")" "name: monorepo-harness-init"
for f in "$CLAUDE" "$OPENCODE" "$CODEX"; do
  says "description says it is not the harness install: ${f#"$REPO"/}" "$(head -4 "$f")" "not the harness install"
done

# Issue #73: the old name is gone from the repo, and each manifest retires its old entry point.
for old in adapters/claude-code/.claude/commands/monorepo-harness-agents-init.md \
           adapters/opencode/.opencode/commands/monorepo-harness-agents-init.md \
           adapters/codex/.agents/skills/monorepo-harness-agents-init/SKILL.md; do
  [ -e "$REPO/$old" ] && bad "old entry point removed: $old" "still present" || ok "old entry point removed: $old"
done
retire_row() { grep -E "^retire[[:space:]]+$2[[:space:]]+[0-9a-f]{64}" "$REPO/adapters/$1/manifest.txt" >/dev/null; }
retire_row claude-code '\.claude/commands/monorepo-harness-agents-init\.md' && ok "claude retires the old command" || bad "claude retires the old command" "no retire row with a sha256"
retire_row opencode '\.opencode/commands/monorepo-harness-agents-init\.md' && ok "opencode retires the old command" || bad "opencode retires the old command" "no retire row with a sha256"
retire_row codex '\.agents/skills/monorepo-harness-agents-init/SKILL\.md' && ok "codex retires the old skill" || bad "codex retires the old skill" "no retire row with a sha256"

b="$(body "$CLAUDE")"
for w in "core/skills/agents-init/SKILL.md" "agents-tree.sh survey" "agents-tree.sh candidates" \
         "agents-tree.sh link" "agents-tree.sh lint" "explicitly says yes" "never copy" "--audit" "write nothing"; do
  says "body mentions: $w" "$b" "$w"
done

s="$(cat "$SKILL")"
for w in "### Step 0" "### Step 1" "### Step 2" "### Step 3" "### Step 4" "### Step 5" "### Step 6" "### Step 7" \
         "## Hard nevers" "approved map is the plan" "Stop here" "80 lines" "150 lines" "drift"; do
  says "skill defines: $w" "$s" "$w"
done

says "claude manifest row" "$(cat "$REPO/adapters/claude-code/manifest.txt")" "copy  .claude/commands/monorepo-harness-init.md"
says "opencode manifest row" "$(cat "$REPO/adapters/opencode/manifest.txt")" "copy  .opencode/commands/monorepo-harness-init.md"
says "codex manifest row" "$(cat "$REPO/adapters/codex/manifest.txt")" "copy  .agents/skills/monorepo-harness-init/SKILL.md"
bundle="$(cat "$REPO/core/install-manifest.txt")"
for r in core/scripts/agents-tree.sh core/skills/agents-init/SKILL.md; do says "bundle row: $r" "$bundle" "$r"; done
[ -x "$REPO/core/scripts/agents-tree.sh" ] && ok "agents-tree.sh is executable" || bad "agents-tree.sh is executable" "mode lacks +x"
says "scaffold prints the hint" "$(cat "$REPO/core/scripts/scaffold-workspace-agents.sh")" "/monorepo-harness-init"

for f in INSTALL.md adapters/claude-code/INSTALL.md adapters/opencode/INSTALL.md adapters/codex/INSTALL.md; do
  n="$(wc -l < "$REPO/$f" | tr -d ' ')"
  [ "$n" -le 100 ] && ok "$f within the 100-line cap ($n)" || bad "$f within the 100-line cap" "$n lines"
  says "$f lists the command" "$(cat "$REPO/$f")" "/monorepo-harness-init"
done
says "README cheat sheet lists the command" "$(cat "$REPO/README.md")" "/monorepo-harness-init"
says "PORTABILITY lists the command" "$(cat "$REPO/PORTABILITY.md")" "/monorepo-harness-init"
for a in claude-code opencode codex; do
  says "$a README documents the command" "$(cat "$REPO/adapters/$a/README.md")" "/monorepo-harness-init"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
