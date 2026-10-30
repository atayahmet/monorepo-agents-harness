#!/usr/bin/env bash
# Tests for the claude-code `argument-hint` frontmatter and the task-linked `/monorepo-harness-spec`
# contract (issue #49).
#
# The suite is deliberately structural: it reads the first frontmatter block of every claude-code
# command, compares the hint to the argument the command body already names, and fails on a command
# that is neither hinted nor explicitly argument-less. It also proves the hint did not leak into
# opencode/codex (whose frontmatter has no equivalent key) and that the task-link/guard text reached
# the shared skill and all three spec bodies.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# Run it from anywhere:  bash tests/argument-hint.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLAUDE_CMDS="$REPO/adapters/claude-code/.claude/commands"
SPEC_BODIES=(
  "$REPO/adapters/claude-code/.claude/commands/monorepo-harness-spec.md"
  "$REPO/adapters/opencode/.opencode/commands/monorepo-harness-spec.md"
  "$REPO/adapters/codex/.agents/skills/monorepo-harness-spec/SKILL.md"
)
SKILL="$REPO/core/skills/agent-workflow/SKILL.md"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected text to mention '$3'" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected text NOT to mention '$3'" ;; *) ok "$1" ;; esac; }

# frontmatter <file> - print the first `---` block, or nothing.
frontmatter() {
  awk 'NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
       NR==1 { next }
       /^---[[:space:]]*$/ { exit }
       { print }' "$1"
}

# body <file> - everything after the closing frontmatter delimiter (or the whole file without one).
body() {
  awk '
    BEGIN { fm=0; done=0 }
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm && !done && /^---[[:space:]]*$/ { done=1; next }
    done || !fm { print }
  ' "$1"
}

# hint_of <file> - the argument-hint value with surrounding quotes removed, or nothing.
hint_of() {
  frontmatter "$1" | sed -n 's/^argument-hint:[[:space:]]*//p' | head -n 1 \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

# has_hint <file> - 0 when the frontmatter carries the key.
has_hint() {
  frontmatter "$1" | grep -q '^argument-hint:'
}

# --- expected hints ---------------------------------------------------------------------------
# command filename (without .md) -> the exact hint. The value comes from the argument the body
# already names. Quoted in the file so the frontmatter stays valid YAML.
expected_hint() {
  case "$1" in
    monorepo-harness-spec)            printf '%s' '[<intent.md>] [<task-issue-url>]' ;;
    monorepo-harness-plan)            printf '%s' '<1_spec.md>' ;;
    monorepo-harness-build)           printf '%s' '<2_plan.md>' ;;
    monorepo-harness-changeset)       printf '%s' '<2_plan.md>' ;;
    monorepo-harness-intent)          printf '%s' '[--pr [--draft] <description> | review | --approve <PR-url> ... | --reject <PR-url> ...]' ;;
    monorepo-harness-intent-dispatch) printf '%s' '<intent.md>' ;;
    monorepo-harness-security-review) printf '%s' '[diff-range-or-branch]' ;;
    monorepo-harness-team)            printf '%s' '[init | add | remove <key> | lint | migrate]' ;;
    monorepo-harness-kb-index)        printf '%s' '[<question> | rebuild | links] [--kind <k>] [--workspace <w>] [--limit <n>]' ;;
    *) return 1 ;;
  esac
}

# The four commands whose bodies take no argument. They stay without the key on purpose; the
# allowlist is what makes "every command is classified" the invariant, not "every command has a key".
argument_less() {
  case "$1" in
    monorepo-harness-review|monorepo-harness-ci|monorepo-harness-update|monorepo-self-improve) return 0 ;;
    *) return 1 ;;
  esac
}

printf '\nargument-hint frontmatter\n'

shopt -s nullglob
for file in "$CLAUDE_CMDS"/*.md; do
  name="$(basename "$file" .md)"
  if want="$(expected_hint "$name")"; then
    if has_hint "$file"; then
      is "$name has argument-hint" "$(hint_of "$file")" "$want"
    else
      bad "$name has argument-hint" "missing argument-hint: $want"
    fi
  elif argument_less "$name"; then
    if has_hint "$file"; then
      bad "$name is argument-less" "unexpected argument-hint: $(hint_of "$file")"
    else
      ok "$name is argument-less (no hint)"
    fi
  else
    bad "$name is classified" "new command must declare an argument-hint or join the argument-less allowlist"
  fi

  # A hint outside the frontmatter is prose, not metadata, and does nothing in the menu.
  if has_hint "$file"; then
    saysn "$name hint is metadata" "$(body "$file")" "argument-hint:"
  fi
done

# --- unsupported keys must not leak into the other adapters ----------------------------------
printf '\nopencode / codex stay unchanged\n'
opencode_hits="$(grep -rl '^argument-hint:' "$REPO/adapters/opencode" 2>/dev/null || true)"
is "opencode has no argument-hint" "$opencode_hits" ""
codex_hits="$(grep -rl '^argument-hint:' "$REPO/adapters/codex" 2>/dev/null || true)"
is "codex has no argument-hint" "$codex_hits" ""

# --- task-linked spec + multi-task guard -----------------------------------------------------
printf '\ntask-linked spec guard\n'
for file in "${SPEC_BODIES[@]}"; do
  rel="${file#"$REPO"/}"
  text="$(cat "$file")"
  says "$rel documents the task link" "$text" '[<task-issue-url>]'
  says "$rel documents the read path" "$text" 'tracker-issue.sh --show'
  says "$rel asks which task when no link is given" "$text" 'several tasks'
done

skill_text="$(cat "$SKILL")"
says "agent-workflow SKILL documents the task link" "$skill_text" '[<task-issue-url>]'
says "agent-workflow SKILL documents the read path" "$skill_text" 'tracker-issue.sh --show'
says "agent-workflow SKILL asks which task when no link is given" "$skill_text" 'which task this spec covers'

# The three stage stubs are byte-identical bodies by contract; a guard added to one must reach all.
first_body="$(body "${SPEC_BODIES[0]}")"
for file in "${SPEC_BODIES[@]:1}"; do
  rel="${file#"$REPO"/}"
  is "$rel body is byte-identical to claude-code spec" "$(body "$file")" "$first_body"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
