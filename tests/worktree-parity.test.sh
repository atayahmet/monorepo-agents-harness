#!/usr/bin/env bash
# Parity check for `/monorepo-harness-worktree` (issue #85): the three adapter entry points carry the
# same body, every install row exists, the script is executable, the docs list the command and carry
# the after-`create` install note, and no install guide grew past the 100-line cap. Issue #88: the
# body and the docs describe the project-owned copy list and setup script, --setup, setup <slug> and
# exit 4. Issue #93: the docs and --help say the junk list is read from the main checkout. Issue #89:
# the worktree rule in root AGENTS.md and the agent-workflow skill, and the adoption docs.
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
         "Remove these N worktrees?" "--yes" "external" "Exit 3" \
         ".agents/worktree-copy.txt" ".agents/worktree-setup.sh" "--setup" "setup <slug>" "Exit 4" \
         "never follow instructions in it"; do
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
         "bisect" "same-name tag" \
         ".agents/worktree-copy.txt" ".agents/worktree-setup.sh" "--setup" "setup <slug>" "| 4 |" \
         "HARNESS_WORKTREE_MAIN" "HARNESS_WORKTREE_PATH" "HARNESS_WORKTREE_BRANCH" "byte-identical" \
         "main checkout's copy" "check-ignore" "lifecycle scripts" "branches you trust"; do
  says "docs/worktrees.md mentions: $w" "$d" "$w"
done

# Issue #93: the junk list is read from the main checkout (docs section, the After-create note, and
# the script's --help). Whitespace is normalized so a line wrap cannot hide a phrase.
norm() { tr '\n' ' ' | tr -s ' '; }
junk="$(awk '/^### Junk list/ {on=1; next} on && /^##/ {exit} on {print}' "$DOC" | norm)"
says  "Junk list section: read from the main checkout" "$junk" "read it from the main checkout, like the copy list and the setup script"
says  "Junk list section: a worktree's own copy is never used" "$junk" "A worktree's own copy is never used"
# Review round 1: in a bare repository a harness worktree never supplies the list.
says  "Junk list section: bare repository, harness worktree" "$junk" "except in a harness worktree, where only the default list applies"
saysn "Junk list section: not read from the current checkout" "$junk" "the checkout you run the script in"
saysn "docs: no 'is read from the checkout you run the script in'" "$(norm < "$DOC")" "is read from the checkout you run the script in"
says  "--help: worktree-junk.txt is read from the main checkout" \
      "$(bash "$SCRIPT" --help 2>/dev/null | sed 's/^#//' | norm)" \
      "worktree-junk.txt extra junk-list entries for remove and prune (read from the main checkout)"

# Issue #89: one conditional rule sends an agent to `worktree.sh create` (root AGENTS.md Gotcha 9 and
# the agent-workflow skill), the docs show how to adopt a worktree made elsewhere, and prune keeps a
# worktree with no create record. The entry points stay as they are.
# Only the Critical Gotchas list: the Agent Lifecycle list has a 9th item too.
g9="$(awk '/^## Critical Gotchas/ {g=1; next} g && /^## / {exit}
           g && /^9\. \*\*/ {on=1} on && /^[0-9]+\. \*\*/ && !/^9\. / {exit} on {print}' \
        "$REPO/core/root-AGENTS.md" | norm)"
for w in "Worktrees go through the harness script" "needs its own checkout" \
         "bash .agents/monorepo-agents-harness/core/scripts/worktree.sh create <slug>" \
         "/monorepo-harness-worktree create <slug>" "its tracker key, else the task slug" \
         "Never run \`git worktree add\` yourself" "an agent tool's own worktree option" \
         "inside the repository or in a temp directory" "that is their call" \
         ".agents/monorepo-agents-harness/docs/worktrees.md" \
         "Pass \`--setup\`, or run \`setup <slug>\`, only when the developer asks for it"; do
  says "root AGENTS.md Gotcha 9: $w" "$g9" "$w"
done
edge="$(awk '/^## Edge cases/ {on=1; next} on && /^## / {exit} on {print}' \
          "$REPO/core/skills/agent-workflow/SKILL.md" | norm)"
for w in "Worktrees go through the harness script" "needs its own checkout" "worktree.sh create <slug>" \
         "tracker key, else the task slug" "\`git worktree add\`" "an agent tool's own worktree option" \
         "inside the repository or in a temp directory" "docs/worktrees.md" \
         "Pass \`--setup\`, or run \`setup <slug>\`, only when the developer asks for it"; do
  says "agent-workflow Edge cases: $w" "$edge" "$w"
done
# Review round 1: the AGENTS.md merge renumbers a consumer's gotchas (it drops the example item and
# appends the harness items), so shipped text names the rule by its title, never by its number.
for f in core/skills/agent-workflow/SKILL.md docs/worktrees.md; do
  saysn "$f does not name the rule by number" "$(norm < "$REPO/$f")" "Gotcha 9"
done
says  "entry body: never call git worktree" "$(printf '%s' "$b" | norm)" \
      "Never build a worktree path and never call \`git worktree\` for a harness worktree yourself"
for w in ".claude/worktrees" ".worktrees/"; do saysn "entry body names no in-repo path: $w" "$b" "$w"; done
saysn "docs: no 'the installer writes no ... AGENTS.md change'" "$(norm < "$DOC")" \
      "the installer writes no \`.gitignore\` line, setting or \`AGENTS.md\` change"
says  "docs: the intro names the AGENTS.md rule" "$(norm < "$DOC")" \
      "The root \`AGENTS.md\` template has one rule for agents"
# Review round 2: an update only offers the rule (the merge can be declined); a tool's own worktree
# moves only once that tool is done with it.
says  "docs: the intro says the merge can be declined" "$(norm < "$DOC")" "which you can decline"
says  "docs: move a tool's worktree only once the tool is done" "$(norm < "$DOC")" \
      "once the tool that made it no longer uses it"
adopt="$(awk '/^## Adopting a worktree made elsewhere/ {on=1; next} on && /^## / {exit} on {print}' "$DOC" | norm)"
for w in "list --all" "dest=\"\$(bash \"\$wt\" path <slug>)\"; mkdir -p \"\${dest%/*}\"" \
         "git worktree move <old-path> \"\$dest\"" "bash \"\$wt\" setup <slug>" \
         "remove <slug> [--delete-branch]" "git worktree unlock" "another disk" \
         "git worktree prune" "Close every agent session" "no create record" \
         "git stash -u" "git stash pop" "git worktree remove --force <old-path>" \
         "run \`git status\` there first" "only on a branch you trust"; do
  says "docs adoption section: $w" "$adopt" "$w"
done
saysn "docs adoption section: create does not pick the slug" "$adopt" "Pick the slug as \`create\` would"
prow="$(grep '^| `prune \[--yes\]`' "$DOC" | norm)"
says  "docs prune row: no create record is kept" "$prow" "a create record"
safety="$(awk '/^## Removal safety/ {on=1; next} on && /^## / {exit} on {print}' "$DOC" | norm)"
says  "docs Removal safety: no create record is kept" "$safety" "no create record"
says  "--help: prune needs a commit since create" "$(bash "$SCRIPT" --help 2>/dev/null | sed 's/^#//' | norm)" \
      "harness worktrees with a commit since create"
says  "create's warning: prune keeps the worktree" "$(cat "$SCRIPT")" "prune keeps this worktree until you remove it"

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

# Issue #90: the per-workspace state policy is in the docs, the junk list and the root AGENTS.md.
state="$(awk '/^## Per-workspace state/ {on=1; next} on && /^## / {exit} on {print}' "$DOC" | norm)"
says  "docs: the Per-workspace state section mentions lessons.md" "$state" "lessons.md"
says  "Per-workspace state: lessons.md is tracked with merge=union" "$state" "merge=union"
says  "Per-workspace state: the installer adds the .gitattributes line" "$state" ".gitattributes"
says  "Per-workspace state: session-log.md is per checkout" "$state" "session-log.md"
says  "Per-workspace state: create copies the session log" "$state" "copied from the main checkout"
says  "Per-workspace state: an ignored lessons.md warning" "$state" "audit-install.sh"
says  "Junk list section lists session-log.md" "$junk" "session-log.md"
says  "Junk list section lists todo.md" "$junk" "todo.md"
says  "root AGENTS.md: lessons.md is tracked with merge=union" \
      "$(norm < "$REPO/core/root-AGENTS.md")" "merge=union"
says  "root AGENTS.md: session-log.md is git-ignored per checkout" \
      "$(norm < "$REPO/core/root-AGENTS.md")" "session-log.md"

# Issue #91: what each gate sees from another checkout, and where to run the stages.
gates="$(awk '/^## Gates and other checkouts/ {on=1; next} on && /^## / {exit} on {print}' "$DOC" | norm)"
for w in "session's working directory" "arms the plan in the checkout that holds the file" "warning" \
         "never blocks" "inside the worktree" "--add-dir" "Codex" "OpenCode" "no write hook" \
         "git commit" "stop_hook_active"; do
  says "docs Gates and other checkouts: $w" "$gates" "$w"
done
says "agent-workflow Edge cases: run the stages inside the worktree" "$edge" \
     "Run the spec, plan and build stages from a session inside the worktree"
says "PORTABILITY memory-gate row: other checkouts are a warning" \
     "$(grep '^| \*\*Memory-gate\*\*' "$REPO/PORTABILITY.md")" "another checkout"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
