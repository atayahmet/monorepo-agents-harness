#!/usr/bin/env bash
# Tests for the team-registry integration points (issue #55): `tracker-issue.sh --assignee`, and the
# skill / rule text that wires team.sh into intent capture, review, dispatch, the root rules and
# self-improvement. Structural on purpose: the skills are prose, so the contract is that the text
# names the commands an agent must run and the fallbacks it must keep.
#
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
# Run it from anywhere:  bash tests/team-integration.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-team.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected text to mention '$3'" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "expected text NOT to mention '$3'" ;; *) ok "$1" ;; esac; }

mkdir -p "$FIXTURE/bin" "$FIXTURE/.agents"
cp "$REPO/core/scripts/tracker-issue.sh" "$REPO/core/scripts/forge.sh" "$FIXTURE/"
( cd "$FIXTURE" && git init -q . && git config user.email t@example.com && git config user.name t \
    && git remote add origin https://github.com/acme/web.git )
cat > "$FIXTURE/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GH_LOG:?}"
case "$1 $2" in
  "auth status") exit 0 ;;
  "issue create") [ "${3:-}" = "--help" ] && { echo "  --assignee --parent"; exit 0; }
                  if [ "${GH_BAD_ASSIGNEE:-0}" = "1" ] && case " $* " in *" --assignee "*) true;; *) false;; esac; then
                    echo "could not assign user: not a collaborator" >&2; exit 1
                  fi
                  [ "${GH_FAIL_CREATE:-0}" = "1" ] && { echo "boom" >&2; exit 1; }
                  echo "https://github.com/acme/web/issues/7"; exit 0 ;;
esac
exit 0
STUB
chmod +x "$FIXTURE/bin/gh"
ti() { ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --tracker github "$@" 2>&1 ); }
ti_code() { ( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" bash tracker-issue.sh --tracker github "$@" >/dev/null 2>&1 ); echo $?; }

# --- tracker-issue.sh --assignee ----------------------------------------------------------------
out="$(ti --title T --body B --assignee alice-example --dry-run)"
says "dry-run names the assignee" "$out" "alice-example"
: > "$FIXTURE/gh.log"
out="$(ti --title T --body B --assignee alice-example --create)"
says "github create passes --assignee to gh" "$(cat "$FIXTURE/gh.log")" "--assignee alice-example"
says "create still prints the issue number" "$out" "created number=7"
: > "$FIXTURE/gh.log"
ti --title T --body B --create >/dev/null
saysn "no --assignee means no assignee flag (today's behavior)" "$(cat "$FIXTURE/gh.log")" "--assignee"
# An assignee GitHub refuses never costs the issue: it is filed unassigned, with a note.
: > "$FIXTURE/gh.log"
out="$( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" GH_BAD_ASSIGNEE=1 bash tracker-issue.sh --tracker github --title T --body B --assignee ghost --create 2>&1 )"
says "refused assignee still files the issue" "$out" "created number=7"
says "refused assignee is reported" "$out" "could not assign"
is "refused assignee retried exactly once without it" "$(grep -c 'issue create' "$FIXTURE/gh.log")" "2"
# any other create failure is still a failure
is "unrelated create failure exits 1" "$( cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" GH_FAIL_CREATE=1 bash tracker-issue.sh --tracker github --title T --body B --assignee alice-example --create >/dev/null 2>&1; echo $? )" "1"
out="$(ti --title T --body B --assignee 557058:0000 --tracker jira --create)"
is "jira create still exits 3" "$(ti_code --title T --body B --assignee 557058:0000 --tracker jira --create)" "3"
says "jira paste-ready block carries the assignee" "$out" "--- assignee ---"
says "jira paste-ready block carries the id" "$out" "557058:0000"
is "--assignee needs a value" "$(ti_code --title T --body B --assignee)" "2"

# --- skill and rule text ------------------------------------------------------------------------
SKILL="$(cat "$REPO/core/skills/intent-workflow/SKILL.md")"
says "intent skill: capture runs whoami" "$SKILL" "team.sh whoami"
says "intent skill: author is the registry name" "$SKILL" "registry **name**"
says "intent skill: approver login is mapped with resolve" "$SKILL" "team.sh resolve github"
says "intent skill: dispatch reports self-approval" "$SKILL" "self-approval"
says "intent skill: dispatch reads assignee routing" "$SKILL" "team.sh assignee"
says "intent skill: assignee is passed to the tracker" "$SKILL" "--assignee"
says "intent skill: never assigns on a guess" "$SKILL" "never assign on a guess"
says "intent skill: no registry falls back with a hint" "$SKILL" "/monorepo-harness-team"
GOV="$(cat "$REPO/core/governance/intents/AGENTS.md")"
says "intents governance: author is a registry name" "$GOV" "registry"
ROOTMD="$(cat "$REPO/core/root-AGENTS.md")"
says "root rules: no hardcoded people" "$ROOTMD" "never hardcode people"
says "root rules: read the registry through team.sh" "$ROOTMD" "team.sh"
says "root rules: departure is forward-only" "$ROOTMD" "forward-only"
says "root rules: history is never rewritten" "$ROOTMD" "intents, task artifacts, fixtures"
SELF="$(tr "[:upper:]" "[:lower:]" < "$REPO/core/skills/self-improvement-workflow/SKILL.md")"
says "self-improve flags hardcoded people" "$SELF" "hardcoded names"
TEAMSKILL="$(cat "$REPO/core/skills/team-registry/SKILL.md")"
saysn "team skill no longer promises a future phase" "$TEAMSKILL" "Phase B (planned)"
says "team skill documents resolve" "$TEAMSKILL" "resolve"

# --- the example template is a valid registry -----------------------------------------------------
mkdir -p "$FIXTURE/tpl/.agents" "$FIXTURE/tpl/apps/api" "$FIXTURE/tpl/apps/web"
cp "$REPO/core/team/team.example.yml" "$FIXTURE/tpl/.agents/team.yml"
( cd "$FIXTURE/tpl" && git init -q . )
is "shipped template passes lint" "$( cd "$FIXTURE/tpl" && bash "$REPO/core/scripts/team.sh" lint >/dev/null 2>&1; echo $? )" "0"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
