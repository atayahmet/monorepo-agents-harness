#!/usr/bin/env bash
# Parity check for `/monorepo-harness-worktree` (issue #85): the three adapter entry points carry the
# same body, every install row exists, the script is executable, the docs list the command and carry
# the after-`create` install note, and no install guide grew past the 100-line cap.
# Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()    { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()   { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected '$3'" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "did not expect '$3'" ;; *) ok "$1" ;; esac; }
same()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "bodies differ"; fi; }

CLAUDE="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-worktree.md"
OPENCODE="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-worktree.md"
CODEX="$REPO/adapters/codex/.agents/skills/monorepo-harness-worktree/SKILL.md"
SCRIPT="$REPO/core/scripts/worktree.sh"
DOC="$REPO/docs/worktrees.md"

body() { awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm && !d && /^---[[:space:]]*$/ {d=1; next} d || !fm {print}' "$1"; }

for f in "$CLAUDE" "$OPENCODE" "$CODEX" "$SCRIPT" "$DOC"; do
  if git -C "$REPO" ls-files --error-unmatch -- "${f#"$REPO"/}" >/dev/null 2>&1; then ok "tracked: ${f#"$REPO"/}"
  else bad "tracked: ${f#"$REPO"/}" "missing or not tracked by git (issue #66)"; fi
done
same "claude and opencode bodies identical" "$(body "$CLAUDE")" "$(body "$OPENCODE")"
same "claude and codex bodies identical" "$(body "$CLAUDE")" "$(body "$CODEX")"
says "codex skill is named" "$(cat "$CODEX")" "name: monorepo-harness-worktree"

b="$(body "$CLAUDE")"
for w in "core/scripts/worktree.sh" "No arguments" "Never build a worktree path" "git worktree" \
         "new agent session" "docs/worktrees.md" "not copied" "pnpm install" ".env" \
         "Never run an install yourself" "--force" "--delete-branch" "in this turn" \
         "Remove these N worktrees?" "--yes" "external" "Exit 3"; do
  says "body mentions: $w" "$b" "$w"
done

says "claude manifest row" "$(cat "$REPO/adapters/claude-code/manifest.txt")" "copy  .claude/commands/monorepo-harness-worktree.md"
says "opencode manifest row" "$(cat "$REPO/adapters/opencode/manifest.txt")" "copy  .opencode/commands/monorepo-harness-worktree.md"
says "codex manifest row" "$(cat "$REPO/adapters/codex/manifest.txt")" "copy  .agents/skills/monorepo-harness-worktree/SKILL.md"
says "bundle row: core/scripts/worktree.sh" "$(cat "$REPO/core/install-manifest.txt")" "core/scripts/worktree.sh"
[ -x "$SCRIPT" ] && ok "worktree.sh is executable" || bad "worktree.sh is executable" "mode lacks +x"
# The task ADRs live under the git-ignored .agents/artifacts/: they never ship, so the installed
# script points at docs/worktrees.md instead (PR #86 review).
saysn "worktree.sh cites no ADR (ADRs do not ship)" "$(cat "$SCRIPT")" "ADR 0"
mode="$(git -C "$REPO" ls-files -s -- core/scripts/worktree.sh | cut -d' ' -f1)"
[ "$mode" = "100755" ] && ok "worktree.sh is executable in git" || bad "worktree.sh is executable in git" "index mode is '$mode'"

d="$(cat "$DOC" 2>/dev/null)"
for w in "~/.harness-worktrees" "HARNESS_WORKTREE_ROOT" "<repo-id>" "worktree-junk.txt" "harnessBase" \
         "## After \`create\`" "not copied" "pnpm install" ".env" "--add-dir" "Why not inside the repository" \
         "/monorepo-harness-worktree" "checkout.defaultRemote" "harnessStart" "showUntrackedFiles" \
         "GIT_OPTIONAL_LOCKS" "merge commit of its own" "its own base" "never deletes the default branch" \
         "bisect" "same-name tag"; do
  says "docs/worktrees.md mentions: $w" "$d" "$w"
done

for f in INSTALL.md adapters/claude-code/INSTALL.md adapters/opencode/INSTALL.md adapters/codex/INSTALL.md; do
  n="$(wc -l < "$REPO/$f" | tr -d ' ')"
  [ "$n" -le 100 ] && ok "$f within the 100-line cap ($n)" || bad "$f within the 100-line cap" "$n lines"
  says "$f lists the command" "$(cat "$REPO/$f")" "/monorepo-harness-worktree"
done
says "README cheat sheet lists the command" "$(cat "$REPO/README.md")" "/monorepo-harness-worktree"
says "PORTABILITY lists the command" "$(cat "$REPO/PORTABILITY.md")" "/monorepo-harness-worktree"
for a in claude-code opencode codex; do
  says "$a README documents the command" "$(cat "$REPO/adapters/$a/README.md")" "/monorepo-harness-worktree"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
