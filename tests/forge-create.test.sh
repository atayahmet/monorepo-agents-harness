#!/usr/bin/env bash
# Tests for `forge.sh create` — the PR-opening write that `/monorepo-harness-intent --pr` uses to
# open the intent's pull request after the branch is pushed (issue #60).
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# The fixture is a throwaway git repo with a GitHub `origin`, a `main` branch, a fake `gh` on PATH for
# the cli rung, and a fake `curl` (plus the real `jq`) for the rest rung. Both stubs log every argv.
#
# Run it from anywhere:  bash tests/forge-create.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-create-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
not_says() { case "$2" in *"$3"*) bad "$1" "output must not mention '$3', got: $2" ;; *) ok "$1" ;; esac; }

FORGE_SRC="$REPO/core/scripts/forge.sh"
JQ_BIN="$(command -v jq || true)"
URL="https://github.com/acme/web/pull/7"

# new_fixture [<origin-url>] — a git repo with an origin and a `main` commit, plus the two stubs.
# State the gh stub honours:
#   GH_EXISTING     a PR url `gh pr list --head` reports as already open for the head
#   GH_CREATE_EXIT  exit code of `pr create`, default 0
#   GH_CREATE_EMPTY when "1", a successful `pr create` prints no url (a write we cannot confirm)
# State the curl stub honours:
#   CURL_BODY       the JSON body it prints for every request
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE/bin" "$FIXTURE/emptybin" "$FIXTURE/restbin"
  cp "$FORGE_SRC" "$FIXTURE/forge.sh"
  git -C "$FIXTURE" init -q -b main 2>/dev/null || git -C "$FIXTURE" init -q
  git -C "$FIXTURE" remote add origin "${1:-https://github.com/acme/web.git}" 2>/dev/null || true
  git -C "$FIXTURE" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git -C "$FIXTURE" branch -M main 2>/dev/null || true
  cat > "$FIXTURE/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
printf '%s\n' "$*" >> "${GH_LOG:?}"
case "${1:-}" in
  auth) exit 0 ;;
  pr)
    shift
    case "${1:-}" in
      list) [ -n "${GH_EXISTING:-}" ] && printf '%s\n' "$GH_EXISTING" ;;
      create)
        if [ "${GH_CREATE_EXIT:-0}" -ne 0 ]; then echo "gh: could not create pull request" >&2; exit "$GH_CREATE_EXIT"; fi
        [ "${GH_CREATE_EMPTY:-0}" = "1" ] || printf '%s\n' "${GH_CREATE_URL:-https://github.com/acme/web/pull/7}" ;;
    esac ;;
esac
exit 0
STUB
  cat > "$FIXTURE/restbin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CURL_LOG:?}"
printf '%s' "${CURL_BODY:-{\}}"
exit 0
STUB
  chmod +x "$FIXTURE/bin/gh" "$FIXTURE/restbin/curl"
  [ -z "$JQ_BIN" ] || ln -s "$JQ_BIN" "$FIXTURE/restbin/jq"
  : > "$FIXTURE/gh.log"; : > "$FIXTURE/curl.log"
}

# create <args> — the cli rung: stub gh first on PATH, no token in the environment.
create() {
  (
    cd "$FIXTURE" || exit 99
    env -u GITHUB_TOKEN -u GITLAB_TOKEN -u BITBUCKET_TOKEN -u GITEA_TOKEN -u HARNESS_FORGE \
      PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" \
      bash ./forge.sh create --head intent/add_login --title "chore(intent): capture add login" \
        --body "No code change." "$@" 2>&1
  )
}
# create_rest <token-var=value> <args> — the rest rung: no gh on PATH, a fake curl and the real jq.
create_rest() {
  local tok="$1"; shift
  (
    cd "$FIXTURE" || exit 99
    env -u GITHUB_TOKEN -u GITLAB_TOKEN -u BITBUCKET_TOKEN -u GITEA_TOKEN -u HARNESS_FORGE \
      "$tok" PATH="$FIXTURE/restbin:/usr/bin:/bin" CURL_LOG="$FIXTURE/curl.log" \
      bash ./forge.sh create --head intent/add_login --title "chore(intent): capture add login" \
        --body "No code change." "$@" 2>&1
  )
}
logged() { grep -q -- "$1" "$FIXTURE/gh.log"; }
gh_logged() { if logged "$1"; then echo yes; else echo no; fi; }
curl_logged() { if grep -q -- "$1" "$FIXTURE/curl.log"; then echo yes; else echo no; fi; }

# --- the happy path: a real write, the URL comes back ---------------------------------------------------
new_fixture
out="$(create --yes)"; code=$?
is "create --yes exits 0" "$code" "0"
says "the success prints the PR url" "$out" "$URL"
says "the success names the platform" "$out" "github"
is "gh pr create ran" "$(gh_logged 'pr create')" "yes"
is "the head reached the forge" "$(gh_logged '--head intent/add_login')" "yes"
is "the base defaults to the default branch" "$(gh_logged '--base main')" "yes"
is "the title reached the forge" "$(gh_logged 'chore(intent): capture add login')" "yes"
is "the body reached the forge" "$(gh_logged 'No code change.')" "yes"
is "a ready PR is not a draft" "$(gh_logged '--draft')" "no"
is "create never calls a merge subcommand" "$(gh_logged 'pr merge')" "no"
is "create never approves" "$(gh_logged 'pr review')" "no"
is "create never pushes" "$(gh_logged 'push')" "no"

# --- --base and --draft --------------------------------------------------------------------------------
new_fixture
out="$(create --yes --draft --base develop)"; code=$?
is "a draft create exits 0" "$code" "0"
is "--draft reached gh" "$(gh_logged '--draft')" "yes"
is "--base overrides the default branch" "$(gh_logged '--base develop')" "yes"

new_fixture
printf 'Body from a file.\nSecond line.\n' > "$FIXTURE/body.md"
out="$(
  cd "$FIXTURE" || exit 99
  env -u GITHUB_TOKEN -u HARNESS_FORGE PATH="$FIXTURE/bin:$PATH" GH_LOG="$FIXTURE/gh.log" \
    bash ./forge.sh create --head intent/add_login --title t --body-file body.md --yes 2>&1
)"; code=$?
is "--body-file exits 0" "$code" "0"
is "--body-file content reached gh" "$(gh_logged 'Second line.')" "yes"

# --- dry run: --yes is the in-turn consent, and --explain is the same ----------------------------------
new_fixture
out="$(create)"; code=$?
is "create without --yes exits 0 as a dry run" "$code" "0"
says "the dry run shows what would run" "$out" "would open PR"
says "the dry run says nothing was opened" "$out" "nothing opened"
is "the dry run created nothing" "$(gh_logged 'pr create')" "no"

new_fixture
out="$(create --explain --yes)"; code=$?
is "--explain exits 0" "$code" "0"
says "--explain shows what would run" "$out" "would open PR"
is "--explain created nothing even with --yes" "$(gh_logged 'pr create')" "no"

# --- idempotence: an open PR for the head is reported, not duplicated -----------------------------------
new_fixture
export GH_EXISTING="https://github.com/acme/web/pull/3"
out="$(create --yes)"; code=$?
is "an already-open PR exits 0" "$code" "0"
says "the no-op names the existing PR" "$out" "https://github.com/acme/web/pull/3"
says "the no-op says it is already open" "$out" "already open"
is "no second PR was created" "$(gh_logged 'pr create')" "no"
unset GH_EXISTING

# --- refusals and unconfirmed writes keep their different answers ---------------------------------------
new_fixture
export GH_CREATE_EXIT=1
out="$(create --yes)"; code=$?
is "a forge refusal exits 1" "$code" "1"
says "the refusal is reported" "$out" "NOT opened"
says "the refusal carries the forge's reason" "$out" "could not create"
unset GH_CREATE_EXIT

new_fixture
export GH_CREATE_EMPTY=1
out="$(create --yes)"; code=$?
is "a create with no url exits 1" "$code" "1"
says "an unconfirmed create is reported honestly" "$out" "could not confirm"
not_says "an unconfirmed create is never reported as created" "$out" "created PR"
unset GH_CREATE_EMPTY

# --- no mechanism: exit 3 with paste-ready steps -------------------------------------------------------
new_fixture
out="$(
  cd "$FIXTURE" || exit 99
  env -u GITHUB_TOKEN -u HARNESS_FORGE PATH="$FIXTURE/emptybin:/usr/bin:/bin" \
    bash ./forge.sh create --head intent/add_login --title "t" --body "b" --yes 2>&1
)"; code=$?
is "no mechanism exits 3, not 1" "$code" "3"
says "the handoff says nothing was opened" "$out" "NOT opened"
says "the paste steps name the head branch" "$out" "intent/add_login"
says "the paste steps name the title" "$out" "t"

# --- mcp rung: a handoff the script cannot drive --------------------------------------------------------
new_fixture
printf '{"mcpServers":{"github":{"command":"npx","args":["github-mcp"]}}}\n' > "$FIXTURE/.mcp.json"
[ -z "$JQ_BIN" ] || ln -s "$JQ_BIN" "$FIXTURE/emptybin/jq"   # the mcp scan reads the config with jq
out="$(
  cd "$FIXTURE" || exit 99
  env -u GITHUB_TOKEN -u HARNESS_FORGE PATH="$FIXTURE/emptybin:/usr/bin:/bin" \
    bash ./forge.sh create --head intent/add_login --title "the title" --body "the body" --yes 2>&1
)"; code=$?
is "an mcp-only forge exits 3" "$code" "3"
says "the handoff names the mcp mechanism" "$out" "mechanism=mcp"
says "the handoff carries the title" "$out" "the title"
says "the handoff carries the body" "$out" "the body"
says "the handoff carries the head" "$out" "intent/add_login"
says "the handoff says nothing was opened" "$out" "NOT opened"

# --- rest rung ------------------------------------------------------------------------------------------
if [ -n "$JQ_BIN" ]; then
  new_fixture
  export CURL_BODY='{"html_url":"https://github.com/acme/web/pull/9"}'
  out="$(create_rest GITHUB_TOKEN=x --yes --draft)"; code=$?
  is "rest create exits 0" "$code" "0"
  says "rest create prints the url from the response" "$out" "https://github.com/acme/web/pull/9"
  is "rest create is a POST" "$(curl_logged '-X POST')" "yes"
  is "rest create targets the pulls endpoint" "$(curl_logged '/repos/acme/web/pulls')" "yes"
  is "rest create sends the head" "$(curl_logged '"head":"intent/add_login"')" "yes"
  is "rest create sends the base" "$(curl_logged '"base":"main"')" "yes"
  is "rest create sends the draft flag" "$(curl_logged '"draft":true')" "yes"
  not_says "the token value is never printed" "$out" "Bearer x"

  new_fixture
  export CURL_BODY='{"message":"Validation Failed"}'
  out="$(create_rest GITHUB_TOKEN=x --yes)"; code=$?
  is "a rest response without a url exits 1" "$code" "1"
  not_says "a rest response without a url is not a creation" "$out" "created PR"

  new_fixture "https://gitlab.com/acme/web.git"
  export CURL_BODY='{"web_url":"https://gitlab.com/acme/web/-/merge_requests/4"}'
  out="$(create_rest GITLAB_TOKEN=x --yes --draft)"; code=$?
  is "gitlab rest create exits 0" "$code" "0"
  says "gitlab prints web_url" "$out" "merge_requests/4"
  is "gitlab targets the encoded project path" "$(curl_logged 'projects/acme%2Fweb/merge_requests')" "yes"
  is "gitlab sends source_branch" "$(curl_logged '"source_branch":"intent/add_login"')" "yes"
  is "gitlab drafts through the Draft: prefix" "$(curl_logged '"title":"Draft: ')" "yes"

  new_fixture "https://bitbucket.org/acme/web.git"
  export CURL_BODY='{"links":{"html":{"href":"https://bitbucket.org/acme/web/pull-requests/5"}}}'
  out="$(create_rest BITBUCKET_TOKEN=x --yes)"; code=$?
  is "bitbucket rest create exits 0" "$code" "0"
  says "bitbucket prints links.html.href" "$out" "pull-requests/5"
  is "bitbucket sends the source branch" "$(curl_logged '"source":{"branch":{"name":"intent/add_login"}}')" "yes"

  new_fixture "https://bitbucket.org/acme/web.git"
  out="$(create_rest BITBUCKET_TOKEN=x --yes --draft)"; code=$?
  is "a bitbucket draft exits 3" "$code" "3"
  says "a bitbucket draft says drafts are unsupported" "$out" "draft"
  is "a bitbucket draft sent no request" "$(curl_logged 'pullrequests')" "no"
  unset CURL_BODY
else
  printf '  skip rest-rung cases: jq not installed\n'
fi

# --- policy: nothing in create may reach for the merge-only flags ----------------------------------------
new_fixture
out="$(create --yes --draft)"
for flag in --admin --delete-branch --squash --rebase --ff-only --auto; do
  not_says "create output never carries $flag" "$out $(cat "$FIXTURE/gh.log")" "$flag"
done

# --- option contract ------------------------------------------------------------------------------------
new_fixture
out="$(cd "$FIXTURE" && bash ./forge.sh create --title t --body b 2>&1)"; code=$?
is "create without --head is a usage error (exit 2)" "$code" "2"
out="$(cd "$FIXTURE" && bash ./forge.sh create --head h --body b 2>&1)"; code=$?
is "create without --title is a usage error (exit 2)" "$code" "2"
out="$(cd "$FIXTURE" && bash ./forge.sh create --head h --title t 2>&1)"; code=$?
is "create without a body is a usage error (exit 2)" "$code" "2"
out="$(cd "$FIXTURE" && bash ./forge.sh state 42 --head h 2>&1)"; code=$?
is "--head is refused outside create (exit 2)" "$code" "2"
out="$(cd "$FIXTURE" && bash ./forge.sh approve 42 --draft 2>&1)"; code=$?
is "--draft is refused outside create (exit 2)" "$code" "2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
