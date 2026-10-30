#!/usr/bin/env bash
# Tests for core/scripts/team.sh (issue #55): lookup, glob routing, lint, exit codes, refs.
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
#
# Run it from anywhere:  bash tests/team.test.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEAM="$REPO/core/scripts/team.sh"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says(){ case "$2" in *"$3"*) ok "$1";; *) bad "$1" "expected '$3' in: $2";; esac; }
saysn(){ case "$2" in *"$3"*) bad "$1" "did not expect '$3' in: $2";; *) ok "$1";; esac; }
is(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q && git config user.email a@example.com && git config user.name A
mkdir -p apps/api apps/web libs/payments/core libs/payments/api services/billing

run(){ out="$("$TEAM" "$@" 2>&1)"; ec=$?; }

# --- no registry: every subcommand says so and exits 4 ------------------------------------------
for c in "whoami" "get alice" "find --role developer" "resolve github x" "assignee ." "lint" "refs alice"; do
  run $c; is "no registry: '$c' exits 4" "$ec" "4"
done
says "no registry message names the file" "$out" ".agents/team.yml"

mkdir -p .agents
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: alice
    name: Alice Example      # trailing comment
    role: developer
    title: Staff Engineer
    ids:
      git:
        - a@example.com
        - alice@users.noreply.github.com
      github: alice-example
      jira: "557058:0000"
      slack: U0000000
  - key: carol
    name: Carol Example
    role: developer
    ids: { git: carol@example.com, github: Carol-Example }
contacts:
  - key: bob
    name: Bob Example
    role: product_owner
    ids: { slack: U1111111 }
assignee_by_workspace:
  .: [alice]
  apps/api: [alice, carol]
  apps/web: []
  "libs/payments/*": [carol]
  libs/payments/core: [alice]
  "services/**": [carol]
YAML

# --- whoami -------------------------------------------------------------------------------------
run whoami; is "whoami exits 0" "$ec" "0"; says "whoami returns key" "$out" "alice"; says "whoami returns name" "$out" "Alice Example"
run whoami --email CAROL@example.com; says "whoami is case-insensitive" "$out" "carol"
run whoami --email nobody@example.com; is "whoami unknown email exits 3" "$ec" "3"
run whoami --json; says "whoami --json has key" "$out" '"key":"alice"'

# --- get / find / resolve ----------------------------------------------------------------------
run get alice name; is "get name" "$out" "Alice Example"
run get alice ids.jira; is "get quoted id keeps the colon" "$out" "557058:0000"
run get carol ids.github; is "get flow-map id" "$out" "Carol-Example"
run get alice ids.git; says "get lists every git email" "$out" "alice@users.noreply.github.com"
run get nobody name; is "get unknown key exits 3" "$ec" "3"
run get alice ids.discord; is "get missing id exits 3" "$ec" "3"
run find --role developer; is "find developers" "$out" "$(printf 'alice\ncarol')"
run find --role product_owner; is "find product_owner" "$out" "bob"
run find --role nonexistent; is "find nothing exits 3" "$ec" "3"
run find --role developer --kind contacts; is "find --kind contacts filters" "$ec" "3"
run resolve github alice-example; says "resolve github" "$out" "alice"
run resolve github carol-example; says "resolve github is case-insensitive" "$out" "carol"
run resolve slack U1111111; says "resolve slack -> contact" "$out" "bob"
run resolve key ALICE; says "resolve pseudo-platform key" "$out" "alice"
run resolve name "carol example"; says "resolve pseudo-platform name" "$out" "carol"
run resolve name "Somebody Else"; is "resolve unknown exits 3" "$ec" "3"
run match github alice-example; says "match stays an alias of resolve" "$out" "alice"

# --- assignee: exact first, then longest glob; ask when vacant/missing/unknown -----------------
run assignee .; is "assignee root" "$out" "alice"
run assignee ./apps/api/; is "assignee normalizes path" "$out" "$(printf 'alice\ncarol')"
run assignee apps/web; is "assignee empty list -> ask" "$out" "ask"
run assignee apps/other; is "assignee missing workspace -> ask" "$out" "ask"
run assignee libs/payments/api; is "assignee single-segment glob" "$out" "carol"
run assignee libs/payments/core; is "assignee exact beats glob" "$out" "alice"
run assignee libs/payments/core/deep; is "assignee '*' does not cross '/'" "$out" "ask"
run assignee services/billing/worker; is "assignee '**' crosses segments" "$out" "carol"
run assignee --json apps/api; says "assignee --json" "$out" '"alice"'

# --- lint: ok, then each failure mode ---------------------------------------------------------
run lint; is "lint ok exits 0" "$ec" "0"
cp .agents/team.yml "$tmp/good.yml"
break_with(){ cp "$tmp/good.yml" .agents/team.yml; printf '%s\n' "$1" >> .agents/team.yml; }

break_with '  apps/ghost: [dave]'; run lint
is "lint unknown member exits 1" "$ec" "1"; says "lint names the unknown member" "$out" "dave"
break_with '  apps/ops: [bob]'; run lint
is "lint contact as assignee exits 1" "$ec" "1"; says "lint explains contacts are not assignable" "$out" "contact"
break_with '  apps/ghost: [alice]'; run lint
is "lint unmatched workspace still exits 0" "$ec" "0"; says "lint warns about unmatched workspace" "$out" "apps/ghost"
sed 's/key: carol/key: alice/' "$tmp/good.yml" > .agents/team.yml; run lint
is "lint duplicate key exits 1" "$ec" "1"; says "lint names duplicate" "$out" "duplicate"
sed 's/carol@example.com/a@example.com/' "$tmp/good.yml" > .agents/team.yml; run lint
is "lint duplicate id exits 1" "$ec" "1"; says "lint names duplicated id" "$out" "a@example.com"
sed '/name: Bob Example/d' "$tmp/good.yml" > .agents/team.yml; run lint
is "lint missing name exits 1" "$ec" "1"; says "lint names the nameless entry" "$out" "bob"
sed '/name: Carol Example/d' "$tmp/good.yml" > .agents/team.yml; run lint
is "lint missing name in the middle exits 1" "$ec" "1"; says "lint names carol" "$out" "carol"

# --- broken or foreign shape: exit 5, never a silent fallback -----------------------------------
cat > .agents/team.yml << 'YAML'
team_lead:
  jira_account_id: "123"
  slack_id: U1
jira_assignee_by_work_type:
  backend: someone
YAML
run whoami; is "foreign shape exits 5" "$ec" "5"
run lint;   is "foreign shape lint exits 5" "$ec" "5"
printf 'version: 2\nmembers: []\n' > .agents/team.yml; run assignee .
is "unsupported version exits 5" "$ec" "5"
sed 's/^  apps\/web: \[\]/  apps\/web:\n    - alice\n  - stray: line/' "$tmp/good.yml" > .agents/team.yml; run lint
is "unsupported syntax exits 5" "$ec" "5"; says "unsupported syntax names a line" "$out" "line"

# --- departed member in an assignee list is skipped, never proposed ----------------------------
sed 's/^  apps\/api: \[alice, carol\]/  apps\/api: [alice, ghost]/' "$tmp/good.yml" > .agents/team.yml
run assignee apps/api; is "unknown member is never proposed" "$out" "alice"

# --- CRLF files parse the same ------------------------------------------------------------------
sed 's/$/\r/' "$tmp/good.yml" > .agents/team.yml; run get alice name; is "CRLF registry parses" "$out" "Alice Example"

# --- refs: forward-looking only ----------------------------------------------------------------
cp "$tmp/good.yml" .agents/team.yml
mkdir -p .claude/commands apps/api/.agents/intents apps/api/.agents/artifacts/task_x tests/fixtures knowledge
echo 'assign to Alice Example'              > .claude/commands/status.md
echo 'author: Alice Example'                > apps/api/.agents/intents/intent_old.md
echo 'Alice Example did this'               > apps/api/.agents/artifacts/task_x/3_memory.md
echo 'alice-example'                        > tests/fixtures/user.json
echo 'Alice Example'                        > CHANGELOG.md
echo 'slack U0000000'                       > knowledge/page.md
run refs alice
says "refs finds a project command" "$out" ".claude/commands/status.md"
saysn "refs skips intents" "$out" "intents/"
saysn "refs skips task artifacts" "$out" "artifacts/"
saysn "refs skips fixtures" "$out" "tests/fixtures"
saysn "refs skips the changelog" "$out" "CHANGELOG.md"
saysn "refs skips the compiled knowledge base" "$out" "knowledge/"
saysn "refs skips the registry itself" "$out" "team.yml"
run refs nobody; is "refs unknown key exits 3" "$ec" "3"
before="$(find . -path ./.git -prune -o -type f -print | sort | xargs cat | cksum)"
"$TEAM" refs alice >/dev/null 2>&1
after="$(find . -path ./.git -prune -o -type f -print | sort | xargs cat | cksum)"
is "refs edits nothing" "$before" "$after"

# --- review findings (PR #64) -------------------------------------------------------------------------
# 1. an unknown top-level key WITH children must not make the registry unreadable
cp "$tmp/good.yml" .agents/team.yml
printf 'settings:\n  theme: dark\n  nested:\n    - a\nnotes: later\n' >> .agents/team.yml
run assignee apps/api; is "unknown top-level key with children: lookups still work" "$ec" "0"
run lint; is "unknown top-level key with children: lint exits 0" "$ec" "0"
says "unknown top-level key is reported as a warning" "$out" "settings"
run whoami; is "unknown top-level key with children: whoami works" "$ec" "0"

# 2. the most specific glob wins, not the longest string
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: bob
    name: Bob B
  - key: eve
    name: Eve E
  - key: zed
    name: Zed Z
assignee_by_workspace:
  "apps/*": [bob]
  "apps/**": [eve]
  "a/**/x": [eve]
  "a/b/*": [zed]
YAML
run assignee apps/api; is "'*' beats the longer '**' pattern" "$out" "bob"
run assignee apps/api/deep; is "'**' still covers deeper paths" "$out" "eve"
run assignee a/b/x; is "fewer '**' wins on equal literals" "$out" "zed"

# 3. quoted scalars: escapes are honoured and JSON output stays valid
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: bob
    name: "Bob \"B\" O'Neil"
    ids: { git: bob@example.com }
  - key: sue
    name: 'Sue O''Hara'
    ids: { git: sue@example.com }
YAML
run get bob name; is "double-quoted escapes are decoded" "$out" "Bob \"B\" O'Neil"
run get sue name; is "single-quoted '' is one quote" "$out" "Sue O'Hara"
run whoami --email bob@example.com --json
says "--json escapes quotes in names" "$out" '"name":"Bob \"B\" O'"'"'Neil"'
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; json.loads(sys.argv[1])' "$out" 2>/dev/null && ok "--json output parses as JSON" || bad "--json output parses as JSON" "$out"
fi

# 4. registry keys are normalized like the lookup argument
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: alice
    name: Alice Example
assignee_by_workspace:
  apps/api/: [alice]
  ./apps/web: [alice]
YAML
run assignee apps/api; is "key written with a trailing slash matches" "$out" "alice"
run assignee apps/web; is "key written with ./ matches" "$out" "alice"

# --- review findings, second round (PR #64) -----------------------------------------------------------
# 7. lint must not warn falsely when the repo path has regex/glob characters
weird="$tmp/we[ird]+dir.x"; mkdir -p "$weird/apps/api" "$weird/.agents"
( cd "$weird" && git init -q . && printf 'packages:\n  - "apps/*"\n' > pnpm-workspace.yaml )
printf 'version: 1\nmembers:\n  - key: alice\n    name: Alice\nassignee_by_workspace:\n  apps/api: [alice]\n' > "$weird/.agents/team.yml"
out="$( cd "$weird" && "$TEAM" lint 2>&1 )"; ec=$?
is "lint in a repo path with [ + . characters exits 0" "$ec" "0"
saysn "no false 'not under a workspace' warning for such a path" "$out" "not under a workspace"
# a "*" workspace glob makes the repo root the detector's parent dir (".") and covers every directory.
# A stub detector keeps this independent of PyYAML/jq being installed.
rm -rf "$tmp/star" "$tmp/stub"; mkdir -p "$tmp/star/svc/api" "$tmp/star/.agents" "$tmp/stub"
cp "$TEAM" "$tmp/stub/team.sh"
printf '#!/usr/bin/env bash\ngit rev-parse --show-toplevel\n' > "$tmp/stub/detect-monorepo-framework.sh"
( cd "$tmp/star" && git init -q . )
printf 'version: 1\nmembers:\n  - key: alice\n    name: Alice\nassignee_by_workspace:\n  svc/api: [alice]\n' > "$tmp/star/.agents/team.yml"
out="$( cd "$tmp/star" && bash "$tmp/stub/team.sh" lint 2>&1 )"
saysn "a '*' workspace glob does not trigger the warning" "$out" "not under a workspace"

# 8. build output directories are not workspaces
mkdir -p build/pkg/api
printf 'version: 1\nmembers:\n  - key: alice\n    name: Alice\nassignee_by_workspace:\n  "build/pkg/*": [alice]\n' > .agents/team.yml
run lint; says "lint ignores directories under build/ (pruned)" "$out" "matches no directory"

# 9. refs cleans up after itself without a lingering RETURN trap
cp "$tmp/good.yml" .agents/team.yml
mkdir -p "$tmp/tt"; TMPDIR="$tmp/tt" "$TEAM" refs alice >/dev/null 2>&1
is "refs leaves no temp file behind" "$(ls -A "$tmp/tt" | wc -l | tr -d ' ')" "0"
if grep -Eq 'trap .*RETURN' "$TEAM"; then bad "team.sh sets no RETURN trap" "trap ... RETURN found"; else ok "team.sh sets no RETURN trap"; fi

# 10. only case-insensitive platforms ignore case
cat > .agents/team.yml << 'YAML'
version: 1
members:
  - key: ann
    name: Ann A
    ids: { git: Ann@Example.com, github: Ann-Dev, jira: "AbC123" }
  - key: ben
    name: Ben B
    ids: { jira: "abc123" }
YAML
run lint; is "ids differing only by case on a case-sensitive platform are not duplicates" "$ec" "0"
run resolve jira abc123; says "resolve jira is exact (lower case)" "$out" "ben"
run resolve jira AbC123; says "resolve jira is exact (mixed case)" "$out" "ann"
run resolve jira ABC123; is "resolve jira does not fold case" "$ec" "3"
run resolve github ann-dev; says "github logins stay case-insensitive" "$out" "ann"
run whoami --email ann@example.com; says "git emails stay case-insensitive" "$out" "ann"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
