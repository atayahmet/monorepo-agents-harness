#!/usr/bin/env bash
# Parity check for `/monorepo-harness-team` (issue #55): the three adapter entry points carry the
# same body, every install row exists, the shared skill defines each action, and no install guide
# grew past the 100-line cap. Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected '$3'" ;; esac; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "bodies differ"; fi; }

CLAUDE="$REPO/adapters/claude-code/.claude/commands/monorepo-harness-team.md"
OPENCODE="$REPO/adapters/opencode/.opencode/commands/monorepo-harness-team.md"
CODEX="$REPO/adapters/codex/.agents/skills/monorepo-harness-team/SKILL.md"
SKILL="$REPO/core/skills/team-registry/SKILL.md"

body() { awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm && !d && /^---[[:space:]]*$/ {d=1; next} d || !fm {print}' "$1"; }

for f in "$CLAUDE" "$OPENCODE" "$CODEX"; do
  if git -C "$REPO" ls-files --error-unmatch -- "${f#"$REPO"/}" >/dev/null 2>&1; then ok "tracked: ${f#"$REPO"/}"
  else bad "tracked: ${f#"$REPO"/}" "missing or not tracked by git (issue #66)"; fi
done
same "claude and opencode bodies identical" "$(body "$CLAUDE")" "$(body "$OPENCODE")"
same "claude and codex bodies identical" "$(body "$CLAUDE")" "$(body "$CODEX")"
says "claude hint lists every action" "$(sed -n 's/^argument-hint: //p' "$CLAUDE")" "init | add | remove <key> | lint | migrate"

b="$(body "$CLAUDE")"
for w in "team-infer.sh" "team.sh lint" "team.sh refs" "migrate" "explicit yes" "Never ask for a credential" "Never edit intents"; do
  case "$b" in *"$w"*) ok "body mentions: $w" ;; *) bad "body mentions: $w" "missing" ;; esac
done

s="$(cat "$SKILL")"
for w in "### init" "### add" "### remove" "### lint" "### migrate" "forward-only" "team.yml.proposed" "Hard nevers"; do
  says "skill defines: $w" "$s" "$w"
done

says "claude manifest row" "$(cat "$REPO/adapters/claude-code/manifest.txt")" "copy  .claude/commands/monorepo-harness-team.md"
says "opencode manifest row" "$(cat "$REPO/adapters/opencode/manifest.txt")" "copy  .opencode/commands/monorepo-harness-team.md"
says "codex manifest row" "$(cat "$REPO/adapters/codex/manifest.txt")" "copy  .agents/skills/monorepo-harness-team/SKILL.md"
bundle="$(cat "$REPO/core/install-manifest.txt")"
for r in core/scripts/team.sh core/scripts/team-infer.sh core/team/team.example.yml core/team/AGENTS.md core/skills/team-registry/SKILL.md; do
  says "bundle row: $r" "$bundle" "$r"
done
for f in team.sh team-infer.sh; do
  [ -x "$REPO/core/scripts/$f" ] && ok "$f is executable" || bad "$f is executable" "mode lacks +x"
done

for f in INSTALL.md adapters/claude-code/INSTALL.md adapters/opencode/INSTALL.md adapters/codex/INSTALL.md; do
  n="$(wc -l < "$REPO/$f" | tr -d ' ')"
  [ "$n" -le 100 ] && ok "$f within the 100-line cap ($n)" || bad "$f within the 100-line cap" "$n lines"
done
says "INSTALL lists the command under Optional extras" "$(sed -n '/Optional extras/,$p' "$REPO/INSTALL.md")" "/monorepo-harness-team"
says "README cheat sheet lists the command" "$(cat "$REPO/README.md")" "/monorepo-harness-team"
says "PORTABILITY lists the command" "$(cat "$REPO/PORTABILITY.md")" "/monorepo-harness-team"
for a in claude-code opencode codex; do
  says "$a README documents the command" "$(cat "$REPO/adapters/$a/README.md")" "/monorepo-harness-team"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
