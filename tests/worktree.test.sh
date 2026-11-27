#!/usr/bin/env bash
# Tests for worktree.sh — one adapter-neutral root for the worktrees the harness creates, and the
# path / create / list / remove / prune contract (issue #85). One section per acceptance criterion
# in the task spec (AC1–AC11). Issue #88 (the project-owned setup step: copy list, setup script,
# `setup <slug>`, exit 4) adds the sections marked "#88 AC<n>".
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle.
#
# Every case runs in throwaway repos under mktemp -d. HOME and HARNESS_WORKTREE_ROOT point into that
# temp dir, so the suite never touches the real ~/.harness-worktrees. Run it from anywhere:
#   bash tests/worktree.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WT="$REPO/core/scripts/worktree.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-worktree-test.XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
TMPP="$(cd "$TMP" && pwd -P)"

# Fixture git commands must never reach the repo the suite runs from. Against an unfinished script
# a fixture path can come back empty, and `git -C ""` means "the current directory": run from inside
# the temp dir, stop git's repo discovery above it, and refuse an empty or missing fixture dir.
cd "$TMP" || exit 1
export GIT_CEILING_DIRECTORIES="$(dirname "$TMPP")"
mkdir -p "$TMP/home"
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export HARNESS_WORKTREE_ROOT="$TMP/root"
ROOTP="$TMPP/root"
HEADER="$(printf 'kind\tslug\tbranch\tstate\tmerged\tlast_commit\tpath')"

pass=0; fail=0
ok()     { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()    { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()     { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn()  { case "$2" in *"$3"*) bad "$1" "expected output NOT to mention '$3', got: $2" ;; *) ok "$1" ;; esac; }
check()  { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n" "failed: $*"; fi; }
checkn() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$n" "succeeded: $*"; else ok "$n"; fi; }

# wt <dir> <args...> - run worktree.sh in <dir> with the extra env in ENVX (e.g. -u HOME).
# Sets OUT (stdout), ERR (stderr) and RC.
ENVX=()
wt() {
  local d="$1"; shift
  OUT="$(cd "$d" && env ${ENVX[@]+"${ENVX[@]}"} bash "$WT" "$@" 2>"$TMP/.err")"; RC=$?
  ERR="$(cat "$TMP/.err")"
}
# mkwt <repo> <slug> [args...] - create a harness worktree and print its path.
mkwt() { local r="$1"; shift; wt "$r" create "$@"; printf '%s' "$OUT"; }

# new_repo <dir> - a repo with one commit on main.
new_repo() { git init -q -b main "$1" && commit "$1" README.md seed; }
# fixture_dir <dir> - refuse an empty path or one outside the temp dir.
fixture_dir() {
  case "$1" in "$TMP"/*|"$TMPP"/*) [ -d "$1" ] && return 0 ;; esac
  echo "  (fixture skipped: '$1' is not a directory under the temp dir)" >&2; return 1
}
# put <dir> <file> [content] - write a file, creating parent directories.
put() { fixture_dir "$1" || return 1; mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "${3:-$2}" > "$1/$2"; }
# commit <dir> <file> <message> - write a file and commit everything.
commit() { put "$1" "$2" "$3" || return 1; git -C "$1" add -A && git -C "$1" commit -qm "$3"; }
# repo_id <dir> - the expected <name>-<hash8>, computed independently of the script.
repo_id() {
  local c; c="$(cd "$1" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
  printf '%s-%s' "$(basename "$(dirname "$c")")" "$(printf '%s' "$c" | git hash-object --stdin | cut -c1-8)"
}
# row <slug> - the table row in OUT whose slug column is <slug>.
row() { printf '%s\n' "$OUT" | awk -F'\t' -v s="$1" 'NR>1 && $2==s'; }
# field <row> <n> - column n of a table row.
field() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '{print $n}'; }
# listed <repo> <path> - git still has a worktree record for <path>.
listed() { git -C "$1" worktree list --porcelain | grep -qxF "worktree $2"; }
has_branch() { git -C "$1" rev-parse --verify -q "refs/heads/$2" >/dev/null; }

R1="$TMP/a/proj"; new_repo "$R1"; ID1="$(repo_id "$R1")"
R1P="$(cd "$R1" && pwd -P)"

echo "usage and bad calls"
wt "$R1" --help
is   "--help exits 0" "$RC" 0
says "--help lists the exit codes" "$OUT" "Exit codes"
wt "$R1";                    is "no subcommand is a bad call" "$RC" 2
wt "$R1" frobnicate;         is "unknown subcommand is a bad call" "$RC" 2
wt "$R1" path;               is "path without a slug is a bad call" "$RC" 2
wt "$R1" create;             is "create without a slug is a bad call" "$RC" 2
wt "$R1" create x --base;    is "--base without a value is a bad call" "$RC" 2
wt "$R1" create x --bogus;   is "unknown create option is a bad call" "$RC" 2
wt "$R1" list --bogus;       is "unknown list option is a bad call" "$RC" 2
wt "$R1" remove;             is "remove without a slug is a bad call" "$RC" 2
wt "$R1" prune --bogus;      is "unknown prune option is a bad call" "$RC" 2
for s in '' '../x' '.hidden' '-x' 'a b' 'a/b' '..' '.'; do
  wt "$R1" path "$s"; is "invalid slug '$s' is a bad call" "$RC" 2
done
wt "$R1" path "$(printf 'a%.0s' $(seq 1 65))"; is "a 65-character slug is a bad call" "$RC" 2
wt "$R1" path "$(printf 'a%.0s' $(seq 1 64))"; is "a 64-character slug is accepted" "$RC" 0
mkdir -p "$TMP/norepo"
wt "$TMP/norepo" path x
is   "outside a git repo is an environment error" "$RC" 3

echo "AC4 — path writes nothing"
wt "$R1" path feat-x
is    "path exits 0" "$RC" 0
is    "path prints <root>/<repo-id>/<slug>" "$OUT" "$ROOTP/$ID1/feat-x"
check "path does not create the root" test ! -e "$TMP/root"

echo "AC1 — one root outside the repo"
ENVX=(-u HARNESS_WORKTREE_ROOT); wt "$R1" path feat-x; ENVX=()
is   "the default root is \$HOME/.harness-worktrees" "$OUT" "$TMPP/home/.harness-worktrees/$ID1/feat-x"
ENVX=(-u HARNESS_WORKTREE_ROOT -u HOME); wt "$R1" path feat-x; ENVX=()
is   "HOME unset and no override is an environment error" "$RC" 3
says "the HOME error names the override" "$ERR" "HARNESS_WORKTREE_ROOT"

echo "AC2 — HARNESS_WORKTREE_ROOT: absolute, outside the repo"
ENVX=(HARNESS_WORKTREE_ROOT=relative/wts); wt "$R1" path x; ENVX=()
is   "a relative override is a bad call" "$RC" 2
ENVX=(HARNESS_WORKTREE_ROOT="$TMP/other/"); wt "$R1" path x; ENVX=()
is   "the override moves the root (trailing / dropped)" "$OUT" "$TMPP/other/$ID1/x"
ENVX=(HARNESS_WORKTREE_ROOT="$R1/.worktrees"); wt "$R1" create x; ENVX=()
is   "a root inside the main worktree is an environment error" "$RC" 3
says "the refusal names the rule" "$ERR" "outside the repository"
check "nothing is created inside the repo" test ! -e "$R1/.worktrees"
checkn "no branch is created" has_branch "$R1" x
ENVX=(HARNESS_WORKTREE_ROOT="$R1"); wt "$R1" path x; ENVX=()
is   "the main worktree itself as root is an environment error" "$RC" 3
ln -s "$R1" "$TMP/link-to-proj"
ENVX=(HARNESS_WORKTREE_ROOT="$TMP/link-to-proj/wts"); wt "$R1" path x; ENVX=()
is   "a root inside the repo through a symlink is an environment error" "$RC" 3
ENVX=(HARNESS_WORKTREE_ROOT="$TMP/nowhere/../a/proj/wts"); wt "$R1" path x; ENVX=()
is   "a root inside the repo through .. is an environment error" "$RC" 3
git -C "$R1" worktree add -q -b ext1 "$TMP/ext1"
ENVX=(HARNESS_WORKTREE_ROOT="$TMP/ext1/wts"); wt "$R1" path x; ENVX=()
is   "a root inside a linked worktree is an environment error" "$RC" 3
if [ "$(id -u)" != 0 ]; then
  mkdir -p "$TMP/ro" && chmod 555 "$TMP/ro"
  ENVX=(HARNESS_WORKTREE_ROOT="$TMP/ro/root"); wt "$R1" create x; ENVX=()
  is   "an unwritable root is an environment error" "$RC" 3
  says "the unwritable-root error says what to set" "$ERR" "set HARNESS_WORKTREE_ROOT"
  checkn "no branch is created when the root is unwritable" has_branch "$R1" x
fi

echo "AC3 — repo-id"
R2="$TMP/b/proj"; new_repo "$R2"; ID2="$(repo_id "$R2")"
wt "$R1" path x; P1="$OUT"
wt "$R2" path x; P2="$OUT"
check "two repos with the same dir name get different paths" test "$P1" != "$P2"
says "the repo-id starts with the directory name" "$P2" "$ROOTP/proj-"
is   "the script's repo-id matches <name>-<hash8>" "$P2" "$ROOTP/$ID2/x"
wt "$TMP/ext1" path x
is   "the path is the same from a linked worktree" "$OUT" "$P1"
mkdir -p "$R1/sub/dir"
wt "$R1/sub/dir" path x
is   "the path is the same from a subdirectory" "$OUT" "$P1"

echo "AC1/AC6 — create"
wt "$R1" create feat-a
is    "create exits 0" "$RC" 0
is    "create prints only the path" "$OUT" "$ROOTP/$ID1/feat-a"
check "the worktree exists" test -d "$ROOTP/$ID1/feat-a"
is    "a new branch is checked out" "$(git -C "$ROOTP/$ID1/feat-a" rev-parse --abbrev-ref HEAD)" feat-a
is    "the new branch starts at the default branch" "$(git -C "$R1" rev-parse feat-a)" "$(git -C "$R1" rev-parse main)"
is    "the base is recorded in branch.<b>.harnessBase" "$(git -C "$R1" config --get branch.feat-a.harnessBase)" main
checkn "the new branch has no upstream" git -C "$R1" rev-parse --abbrev-ref --verify -q 'feat-a@{upstream}'
is    "the main checkout stays clean" "$(git -C "$R1" status --porcelain)" ""
check "no ignore rule is written to the repo" test ! -e "$R1/.gitignore"
says  "create warns when the bundle is missing in the worktree" "$ERR" ".agents/monorepo-agents-harness"

git -C "$R1" checkout -q -b dev && commit "$R1" dev.txt "dev work" && git -C "$R1" checkout -q main
wt "$R1" create feat-b --base dev
is   "--base: exits 0" "$RC" 0
is   "--base: the branch starts at the base" "$(git -C "$R1" rev-parse feat-b)" "$(git -C "$R1" rev-parse dev)"
is   "--base: the base is recorded" "$(git -C "$R1" config --get branch.feat-b.harnessBase)" dev

wt "$R1" create slug-c --branch feature/c
is   "--branch: exits 0" "$RC" 0
is   "--branch: the path uses the slug" "$OUT" "$ROOTP/$ID1/slug-c"
is   "--branch: the named branch is checked out" "$(git -C "$ROOTP/$ID1/slug-c" rev-parse --abbrev-ref HEAD)" feature/c

git -C "$R1" branch old-branch
wt "$R1" create old-branch
is   "an existing local branch: exits 0" "$RC" 0
is   "an existing local branch is checked out" "$(git -C "$ROOTP/$ID1/old-branch" rev-parse --abbrev-ref HEAD)" old-branch
checkn "an existing branch gets no harnessBase" git -C "$R1" config --get branch.old-branch.harnessBase

git -C "$R1" branch other
wt "$R1" create other --base main
is    "--base with an existing branch is a bad call" "$RC" 2
check "--base with an existing branch creates nothing" test ! -e "$ROOTP/$ID1/other"
wt "$R1" create bad --branch 'bad..name'
is    "an invalid branch name is a bad call" "$RC" 2
wt "$R1" create nob --base no-such-ref
is    "--base that is not a commit is a bad call" "$RC" 2
check "an invalid --base creates nothing" test ! -e "$ROOTP/$ID1/nob"
checkn "an invalid --base creates no branch" has_branch "$R1" nob

R4="$TMP/e/proj"; new_repo "$R4"; commit "$R4" .agents/monorepo-agents-harness/VERSION "bundle"
wt "$R4" create with-bundle
is    "a repo with a tracked bundle: exits 0" "$RC" 0
saysn "no bundle warning when the bundle is tracked" "$ERR" "monorepo-agents-harness"

R5="$TMP/f/proj"; git init -q -b trunk "$R5"; commit "$R5" README.md seed
wt "$R5" create x
is   "no default branch and no --base is a bad call" "$RC" 2
says "the error says to pass --base" "$ERR" "--base"

ORIGIN="$TMP/origin.git"; git init -q --bare -b main "$ORIGIN"
SEED="$TMP/seed"; new_repo "$SEED"; git -C "$SEED" push -q "$ORIGIN" main 2>/dev/null
git -C "$SEED" checkout -q -b remote-only && commit "$SEED" r.txt "remote work"
git -C "$SEED" push -q "$ORIGIN" remote-only 2>/dev/null
R3="$TMP/c/proj3"; git clone -q "$ORIGIN" "$R3" 2>/dev/null
wt "$R3" create remote-only --base main
is   "--base with a remote-only branch is a bad call" "$RC" 2
wt "$R3" create remote-only
is   "a branch one remote has: exits 0" "$RC" 0
is   "a branch one remote has is checked out at the remote tip" "$(git -C "$OUT" rev-parse HEAD)" "$(git -C "$R3" rev-parse origin/remote-only)"
wt "$R3" create feat-r
is   "the default branch comes from origin/HEAD" "$(git -C "$R3" config --get branch.feat-r.harnessBase)" main

echo "AC5 — create on a branch that is already checked out"
before="$(git -C "$R1" worktree list --porcelain)"
wt "$R1" create feat-a
is   "a re-run exits 0" "$RC" 0
is   "a re-run prints the existing path" "$OUT" "$ROOTP/$ID1/feat-a"
says "a re-run says nothing was created" "$ERR" "already checked out"
is   "a re-run changes no worktree record" "$(git -C "$R1" worktree list --porcelain)" "$before"
# Only a harness worktree is a re-run; a branch in the main checkout or an external worktree is
# refused, so the agent never sends the developer to the checkout they are in (review round 3).
wt "$R1" create mainline --branch main
is   "a branch checked out in the main checkout is refused" "$RC" 1
is   "and prints no path" "$OUT" ""
says "the refusal says where it is checked out" "$ERR" "$R1P"
wt "$R1" create ext-x --branch ext1
is   "a branch checked out in an external worktree is refused" "$RC" 1
says "the refusal names the external worktree" "$ERR" "$TMPP/ext1"
is   "a branch checked out elsewhere changes no worktree record" "$(git -C "$R1" worktree list --porcelain)" "$before"
check "nothing is created for a branch checked out elsewhere" test ! -e "$ROOTP/$ID1/mainline"
mkdir -p "$ROOTP/$ID1/occupied"
wt "$R1" create occupied
is   "an occupied path is refused" "$RC" 1
checkn "an occupied path creates no branch" has_branch "$R1" occupied

echo "AC7 — list"
wt "$R1" list
is   "list exits 0" "$RC" 0
is   "list prints the header" "$(printf '%s\n' "$OUT" | head -n1)" "$HEADER"
check "every row has seven columns" awk -F'\t' 'NF!=7 {exit 1}' <<< "$OUT"
r="$(row feat-a)"
is   "kind is harness" "$(field "$r" 1)" harness
is   "branch column" "$(field "$r" 3)" feat-a
is   "state is clean" "$(field "$r" 4)" clean
is   "a branch with no new commits is merged" "$(field "$r" 5)" merged
check "last_commit is a date" grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' <<< "$(field "$r" 6)"
is   "path column" "$(field "$r" 7)" "$ROOTP/$ID1/feat-a"
is   "the main worktree is never listed" "$(printf '%s\n' "$OUT" | awk -F'\t' -v p="$R1P" '$7==p')" ""
saysn "external worktrees are not listed without --all" "$OUT" "$TMPP/ext1"
wt "$R1" list --all
r="$(printf '%s\n' "$OUT" | awk -F'\t' -v p="$TMPP/ext1" '$7==p')"
is   "--all lists an external worktree as external" "$(field "$r" 1)" external
is   "an external row has no slug" "$(field "$r" 2)" "-"
put "$ROOTP/$ID1/feat-b" scratch.txt
rm -rf "${ROOTP:?}/$ID1/slug-c"
git -C "$R1" worktree add -q --detach "$ROOTP/$ID1/det"
wt "$R1" list
is   "an untracked file makes the state dirty" "$(field "$(row feat-b)" 4)" dirty
is   "a deleted directory is missing" "$(field "$(row slug-c)" 4)" missing
check "a missing row still has a last_commit date" grep -Eq '^[0-9]{4}-' <<< "$(field "$(row slug-c)" 6)"
is   "a detached worktree shows (detached)" "$(field "$(row det)" 3)" "(detached)"
wt "$R1" create slug-c2 --branch feature/c
is   "a branch checked out in a missing worktree is refused" "$RC" 1
says "the refusal points at prune" "$ERR" "prune"
wt "$R2" list
is   "list on a repo without worktrees prints only the header" "$OUT" "$HEADER"
check "list writes nothing" test ! -e "$ROOTP/$ID2"

echo "AC8 — merged rule"
M="$TMP/m/proj"; new_repo "$M"
P="$(mkwt "$M" m-merge)"; commit "$P" merge.txt "merge work"
git -C "$M" merge -q --no-ff -m "merge m-merge" m-merge
P="$(mkwt "$M" m-rebase)"; commit "$P" rb1.txt "rebase one"; commit "$P" rb2.txt "rebase two"
c2="$(git -C "$P" rev-parse HEAD)"; c1="$(git -C "$P" rev-parse HEAD~1)"
commit "$M" main-only.txt "main moves on"; git -C "$M" cherry-pick "$c1" "$c2" >/dev/null
P="$(mkwt "$M" m-squash1)"; commit "$P" sq1.txt "squash one"
git -C "$M" merge -q --squash m-squash1 >/dev/null && git -C "$M" commit -qm "squash m-squash1"
P="$(mkwt "$M" m-squash2)"; commit "$P" sq2a.txt "squash two a"; commit "$P" sq2b.txt "squash two b"
git -C "$M" merge -q --squash m-squash2 >/dev/null && git -C "$M" commit -qm "squash m-squash2"
P="$(mkwt "$M" m-open)"; commit "$P" open.txt "open work"
P="$(mkwt "$M" m-gone)"; commit "$P" gone.txt "gone work"
git -C "$M" merge -q --no-ff -m "merge m-gone" m-gone; git -C "$M" config branch.m-gone.harnessBase gone-branch
wt "$M" list
is "a merge commit reads merged" "$(field "$(row m-merge)" 5)" merged
is "a rebase-merge reads merged" "$(field "$(row m-rebase)" 5)" merged
is "a one-commit squash reads merged" "$(field "$(row m-squash1)" 5)" merged
is "a squash of several commits reads unmerged" "$(field "$(row m-squash2)" 5)" unmerged
is "an open branch reads unmerged" "$(field "$(row m-open)" 5)" unmerged
is "a recorded base that no longer resolves falls back to the default branch" "$(field "$(row m-gone)" 5)" merged
mkwt "$R5" u-gone --base trunk >/dev/null; git -C "$R5" config branch.u-gone.harnessBase gone-branch
wt "$R5" list
is "no base resolves at all: unknown" "$(field "$(row u-gone)" 5)" unknown
P="$(mkwt "$R3" feat-o)"; commit "$P" o.txt "merged upstream"
git -C "$R3" push -q origin feat-o:main 2>/dev/null
wt "$R3" list
is "merged on origin/<base> only reads merged" "$(field "$(row feat-o)" 5)" merged

echo "AC9 — remove safety"
D="$TMP/d/proj"; new_repo "$D"
printf '.env\nnode_modules/\n*.log\nsecret.key\nknowledge/.index.sqlite*\n' > "$D/.gitignore"; git -C "$D" add -A && git -C "$D" commit -qm ignores
P_dirty="$(mkwt "$D" d-dirty)"; put "$P_dirty" notes.txt
wt "$D" remove d-dirty
is    "a dirty worktree is refused" "$RC" 1
says  "the refusal prints the dirty file" "$ERR" "notes.txt"
check "a refused worktree stays" test -d "$P_dirty"
P_env="$(mkwt "$D" d-env)"; put "$P_env" .env "SECRET=1"
wt "$D" remove d-env
is    "an ignored .env is refused" "$RC" 1
says  "the refusal prints the ignored file" "$ERR" ".env"
check "the .env worktree stays" test -f "$P_env/.env"
P="$(mkwt "$D" d-junk)"; put "$P" node_modules/pkg/index.js; put "$P" debug.log
put "$P" knowledge/.index.sqlite
wt "$D" remove d-junk
is    "junk-only ignored files are accepted" "$RC" 0
check "the junk-only worktree is gone" test ! -e "$P"
checkn "git no longer lists it" listed "$D" "$P"
check "remove keeps the branch" has_branch "$D" d-junk
P="$(mkwt "$D" d-key)"; put "$P" secret.key
wt "$D" remove d-key
is    "an ignored file outside the junk list is refused" "$RC" 1
mkdir -p "$D/.agents"; printf '# project junk\n\nsecret.key\n' > "$D/.agents/worktree-junk.txt"
wt "$D" remove d-key
is    ".agents/worktree-junk.txt extends the junk list" "$RC" 0
check "the extended-junk worktree is gone" test ! -e "$P"
P_open="$(mkwt "$D" d-open)"; commit "$P_open" open.txt "open work"
wt "$D" remove d-open
is    "unmerged commits are refused" "$RC" 1
says  "the refusal prints the unmerged commit" "$ERR" "open work"
P="$(mkwt "$D" d-cwd)"; mkdir -p "$P/sub"
wt "$P/sub" remove d-cwd
is    "a current directory inside the worktree is refused" "$RC" 1
wt "$P" remove d-cwd --force
is    "--force never skips the current-directory check" "$RC" 1
check "the cwd worktree stays" test -d "$P"
git -C "$D" worktree add -q -b d-outside "$TMP/d-outside"
wt "$D" remove d-outside --force
is    "a worktree outside the root is refused, even with --force" "$RC" 1
check "the outside worktree stays" test -d "$TMP/d-outside"
wt "$D" remove no-such
is    "an unknown slug is refused" "$RC" 1
P="$(mkwt "$D" d-lock)"; git -C "$D" worktree lock "$P"
wt "$D" remove d-lock --force
is    "a locked worktree is refused, even with --force" "$RC" 1
check "the locked worktree stays" test -d "$P"
wt "$D" remove d-dirty --force
is    "--force removes a dirty worktree" "$RC" 0
says  "--force names what is lost" "$ERR" "--force: discarding"
check "the dirty worktree is gone" test ! -e "$P_dirty"
wt "$D" remove d-env --force
is    "--force removes a worktree with an ignored .env" "$RC" 0
says  "--force names the ignored file" "$ERR" ".env"
wt "$D" remove d-open --force
is    "--force removes a worktree with unmerged commits" "$RC" 0
check "--force without --delete-branch keeps the branch" has_branch "$D" d-open
says  "--force says the branch keeps the unmerged commits" "$ERR" "branch d-open keeps them"
P="$(mkwt "$D" d-miss)"; rm -rf "$P"
wt "$D" remove d-miss
is    "a missing worktree is removed" "$RC" 0
checkn "the missing record is gone" listed "$D" "$P"

echo "AC10 — --delete-branch"
P="$(mkwt "$D" d-merged)"; commit "$P" m.txt "merged work"
git -C "$D" merge -q --no-ff -m "merge d-merged" d-merged
wt "$D" remove d-merged --delete-branch
is    "--delete-branch on a merged branch exits 0" "$RC" 0
checkn "a merged branch is deleted" has_branch "$D" d-merged
checkn "its harnessBase goes with it" git -C "$D" config --get branch.d-merged.harnessBase
P="$(mkwt "$D" d-sq)"; commit "$P" sq.txt "squashed work"
git -C "$D" merge -q --squash d-sq >/dev/null && git -C "$D" commit -qm "squash d-sq"
wt "$D" remove d-sq --delete-branch
is    "--delete-branch on a squash-merged branch exits 0" "$RC" 0
checkn "a patch-equal branch is deleted" has_branch "$D" d-sq
P="$(mkwt "$D" d-unm)"; commit "$P" u.txt "unmerged work"
wt "$D" remove d-unm --delete-branch --force
is    "--delete-branch --force on an unmerged branch removes the worktree" "$RC" 0
check "the unmerged worktree is gone" test ! -e "$P"
check "an unmerged branch is never deleted" has_branch "$D" d-unm
says  "stderr says the branch was kept" "$ERR" "kept branch d-unm (unmerged)"

echo "AC11 — prune"
PR="$TMP/p/proj"; new_repo "$PR"
printf '.env\nnode_modules/\n' > "$PR/.gitignore"; git -C "$PR" add -A && git -C "$PR" commit -qm ignores
# Candidates have a commit of their own that is merged: a worktree with no commit since create may
# still be in use (PR #86 review, round 2).
P_clean="$(mkwt "$PR" p-clean)"; commit "$P_clean" pc.txt "pc work"
git -C "$PR" merge -q --ff-only p-clean
P_merged="$(mkwt "$PR" p-merged)"; commit "$P_merged" pm.txt "pm work"
git -C "$PR" merge -q --no-ff -m "merge p-merged" p-merged
P_dirty="$(mkwt "$PR" p-dirty)"; put "$P_dirty" wip.txt
P_unm="$(mkwt "$PR" p-unm)"; commit "$P_unm" pu.txt "pu work"
P_env="$(mkwt "$PR" p-env)"; put "$P_env" .env "SECRET=1"
P_junk="$(mkwt "$PR" p-junk)"; commit "$P_junk" pj.txt "pj work"
git -C "$PR" merge -q --no-ff -m "merge p-junk" p-junk; put "$P_junk" node_modules/x/index.js
P_miss="$(mkwt "$PR" p-miss)"; rm -rf "$P_miss"
git -C "$PR" worktree add -q -b p-extmiss "$TMP/p-extmiss"; rm -rf "$TMP/p-extmiss"
before="$(git -C "$PR" worktree list --porcelain)"
wt "$PR" prune
is   "a dry run exits 0" "$RC" 0
is   "a dry run prints the header" "$(printf '%s\n' "$OUT" | head -n1)" "$HEADER"
for s in p-clean p-merged p-junk p-miss; do
  check "the dry run lists $s" test -n "$(row "$s")"
done
for s in p-dirty p-unm p-env; do
  is "the dry run does not list $s" "$(row "$s")" ""
  says "the dry run says why $s is kept" "$ERR" "kept $s:"
done
is   "a dry run changes no worktree record" "$(git -C "$PR" worktree list --porcelain)" "$before"
check "a dry run removes no directory" test -d "$P_clean"
wt "$PR" prune --yes
is   "prune --yes exits 0" "$RC" 0
for p in "$P_clean" "$P_merged" "$P_junk" "$P_miss"; do
  checkn "prune --yes removed ${p##*/}" listed "$PR" "$p"
done
check "prune --yes removed the clean directory" test ! -e "$P_clean"
for p in "$P_dirty" "$P_unm" "$P_env"; do
  check "prune --yes kept ${p##*/}" test -d "$p"
done
for b in p-clean p-merged p-junk p-miss; do
  check "prune never deletes a branch ($b)" has_branch "$PR" "$b"
done
check "prune leaves the record of a missing external worktree" listed "$PR" "$TMPP/p-extmiss"
wt "$PR" prune
is   "after prune --yes the dry run has no candidates" "$OUT" "$HEADER"

echo "Review round 1 (PR #86)"
# A junk entry matches the ignored entry's own name, never a folder above it.
J="$TMP/j/proj"; new_repo "$J"
printf '*.p12\nnode_modules/\ndist/\n' > "$J/.gitignore"; commit "$J" build/README "tracked build dir"
P="$(mkwt "$J" j-cert)"; put "$P" build/signing.p12
wt "$J" remove j-cert
is     "an ignored key in a tracked junk-named folder is refused" "$RC" 1
says   "the refusal names the key" "$ERR" "build/signing.p12"
check  "the worktree with the key stays" test -f "$P/build/signing.p12"
wt "$J" prune
is     "prune does not list it" "$(row j-cert)" ""
says   "prune says why it is kept" "$ERR" "kept j-cert:"
P="$(mkwt "$J" j-nested)"; put "$P" packages/a/node_modules/x/index.js; put "$P" packages/a/dist/out.js
wt "$J" remove j-nested
is     "nested junk folders are still junk" "$RC" 0

# A branch that several remotes have is ambiguous, as in git's own DWIM.
UP="$TMP/upstream.git"; git init -q --bare -b main "$UP"
git -C "$SEED" push -q "$UP" main 2>/dev/null
git -C "$SEED" checkout -q -b up-work remote-only && commit "$SEED" u.txt "upstream work"
git -C "$SEED" push -q "$UP" up-work:remote-only 2>/dev/null
R6="$TMP/g/proj"; git clone -q "$ORIGIN" "$R6" 2>/dev/null
git -C "$R6" remote add upstream "$UP"; git -C "$R6" fetch -q upstream 2>/dev/null
wt "$R6" create remote-only
is     "a branch on two remotes is a bad call" "$RC" 2
says   "the error names the remotes" "$ERR" "upstream"
checkn "a branch on two remotes creates no local branch" has_branch "$R6" remote-only
check  "a branch on two remotes creates no directory" test ! -e "$ROOTP/$(repo_id "$R6")/remote-only"
wt "$R6" create remote-only --base main
is     "--base with a branch on two remotes is a bad call" "$RC" 2
checkn "and creates no local branch" has_branch "$R6" remote-only
git -C "$R6" config checkout.defaultRemote upstream
wt "$R6" create remote-only
is     "checkout.defaultRemote picks the remote: exits 0" "$RC" 0
is     "it checks out that remote's tip" "$(git -C "$OUT" rev-parse HEAD)" "$(git -C "$R6" rev-parse upstream/remote-only)"

# A target path git still has registered, with its directory gone.
P="$(mkwt "$R1" q-gone)"; rm -rf "$P"
wt "$R1" create q-gone --branch q-other
is     "a target path registered to a missing worktree is refused" "$RC" 1
says   "the refusal points at remove or prune" "$ERR" "prune"
checkn "it creates no branch" has_branch "$R1" q-other

# A failed checkout leaves no branch behind.
F="$TMP/h/proj"; new_repo "$F"
printf '* filter=boom\n' > "$F/.gitattributes"; git -C "$F" add -A && git -C "$F" commit -qm attrs
git -C "$F" config filter.boom.smudge false; git -C "$F" config filter.boom.required true
wt "$F" create f-fail
is     "a failed checkout is refused" "$RC" 1
says   "the failure names the base" "$ERR" "from main"
checkn "a failed checkout leaves no branch behind" has_branch "$F" f-fail
check  "a failed checkout leaves no directory" test ! -e "$ROOTP/$(repo_id "$F")/f-fail"

# --base is recorded as a branch name, never as text relative to the caller's HEAD.
wt "$R1" create rel-head --base HEAD
is     "--base HEAD records the branch HEAD is on" "$(git -C "$R1" config --get branch.rel-head.harnessBase)" main
wt "$R1" create rel-sha --base "$(git -C "$R1" rev-parse main)"
is     "--base <commit>: exits 0" "$RC" 0
checkn "--base <commit> records no harnessBase" git -C "$R1" config --get branch.rel-sha.harnessBase
says   "it says the default branch is used" "$ERR" "default branch"
wt "$R3" create rel-remote --base origin/main
is     "--base <remote>/<branch> records the full remote ref" "$(git -C "$R3" config --get branch.rel-remote.harnessBase)" refs/remotes/origin/main
P="$(mkwt "$R1" rel-cwd --base HEAD)"; commit "$P" rc.txt "rel work"
wt "$P" list; a="$(field "$(row rel-cwd)" 5)"
wt "$R1" list; b="$(field "$(row rel-cwd)" 5)"
is     "the merged column is the same from the worktree and the main checkout" "$a" "$b"
is     "and it reads unmerged" "$b" unmerged

# A branch checked out in a missing external worktree: prune cannot help.
git -C "$R1" worktree add -q -b ext-gone "$TMP/ext-gone"; rm -rf "$TMP/ext-gone"
wt "$R1" create eg --branch ext-gone
is     "a branch in a missing external worktree is refused" "$RC" 1
says   "the hint names git worktree remove" "$ERR" "git worktree remove"
saysn  "the hint does not point at worktree.sh prune" "$ERR" "worktree.sh prune"

wt "$R1" create empty-b --branch ""
is     "--branch with an empty value is a bad call" "$RC" 2
checkn "and creates no branch" has_branch "$R1" empty-b

echo "Review round 2 (PR #86)"
# status.showUntrackedFiles=no must not hide untracked or ignored files from the safety checks.
U="$TMP/u/proj"; new_repo "$U"
printf '.env\n' > "$U/.gitignore"; git -C "$U" add -A && git -C "$U" commit -qm ignores
git -C "$U" config status.showUntrackedFiles no
P="$(mkwt "$U" u-hidden)"; commit "$P" u.txt "u work"; git -C "$U" merge -q --ff-only u-hidden
put "$P" .env "SECRET=1"; put "$P" new.txt
wt "$U" list
is     "showUntrackedFiles=no: an untracked file still reads dirty" "$(field "$(row u-hidden)" 4)" dirty
wt "$U" prune --yes
check  "prune --yes keeps it" test -f "$P/.env"
wt "$U" remove u-hidden
is     "remove refuses it" "$RC" 1
says   "the refusal names the untracked file" "$ERR" "new.txt"
says   "the refusal names the ignored .env" "$ERR" ".env"
check  "the files stay" test -f "$P/new.txt"
P="$(mkwt "$U" u-broken)"; printf 'garbage' > "$(git -C "$P" rev-parse --git-dir)/index"
wt "$U" remove u-broken
is     "a worktree git status cannot read is refused" "$RC" 1
says   "a failed ignored-file scan is a finding, never 'none'" "$ERR" "cannot list the ignored files"

# A merge commit with a change of its own is not merged: git cherry skips merge commits.
E="$TMP/e2/proj"; new_repo "$E"
git -C "$E" checkout -q -b side && commit "$E" s.txt "side work" && git -C "$E" checkout -q main
P="$(mkwt "$E" e-evil)"
git -C "$E" merge -q --no-ff -m "merge side" side
git -C "$P" merge -q --no-ff --no-commit side >/dev/null 2>&1; put "$P" README.md "edit inside the merge"
git -C "$P" add -A && git -C "$P" commit -qm "merge side into e-evil"
wt "$E" list
is     "a merge commit with its own change reads unmerged" "$(field "$(row e-evil)" 5)" unmerged
wt "$E" remove e-evil --delete-branch
is     "remove refuses it" "$RC" 1
says   "the refusal names the merge commit" "$ERR" "merge side into e-evil"
check  "the branch stays" has_branch "$E" e-evil

# A worktree with no commit since create may still be in use: prune keeps it, remove still works.
P="$(mkwt "$PR" p-fresh)"; put "$P" node_modules/x/index.js
is     "create records the start commit" "$(git -C "$PR" config --get branch.p-fresh.harnessStart)" "$(git -C "$PR" rev-parse main)"
wt "$PR" prune
is     "prune does not list a worktree with no commit since create" "$(row p-fresh)" ""
says   "prune says why it is kept" "$ERR" "kept p-fresh:"
wt "$PR" prune --yes
check  "prune --yes keeps it" test -d "$P"
wt "$PR" remove p-fresh
is     "remove still removes it" "$RC" 0
git -C "$PR" branch -q p-old
wt "$PR" create p-old
is     "an existing branch records its start commit too" "$(git -C "$PR" config --get branch.p-old.harnessStart)" "$(git -C "$PR" rev-parse p-old)"

# Never run git status in an external worktree, and take no optional index.lock anywhere.
mkdir -p "$TMP/bin"; REALGIT="$(command -v git)"
cat > "$TMP/bin/git" <<EOF
#!/bin/sh
printf '%s|%s\n' "\${GIT_OPTIONAL_LOCKS:-unset}" "\$*" >> "$TMP/git.log"
if [ -n "\${CHANGE_ON:-}" ] && [ ! -e "$TMP/.changed" ]; then
  case "\$*" in
    *"\$CHANGE_ON"*--ignored=matching*)
      : > "$TMP/.changed"; echo late > "\$CHANGE_ON/late.txt"
      "$REALGIT" -C "\$CHANGE_ON" add late.txt && "$REALGIT" -C "\$CHANGE_ON" commit -qm "late work" ;;
  esac
fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$TMP/bin/git"
git -C "$PR" worktree add -q -b p-ext "$TMP/p-ext"
: > "$TMP/git.log"; ENVX=(PATH="$TMP/bin:$PATH"); wt "$PR" prune; wt "$PR" list; ENVX=()
is     "prune and list run git in no external worktree" "$(grep -E -- '-C [^ ]*/p-ext ' "$TMP/git.log")" ""
check  "the wrapper saw the script's git status calls" grep -q ' status ' "$TMP/git.log"
is     "every git status runs with GIT_OPTIONAL_LOCKS=0" "$(grep ' status ' "$TMP/git.log" | grep -v '^0|')" ""

# prune --yes re-reads the worktree list: a commit made after the dry-run pass keeps the worktree.
P="$(mkwt "$PR" p-late)"; commit "$P" pl.txt "pl work"; git -C "$PR" merge -q --ff-only p-late
ENVX=(PATH="$TMP/bin:$PATH" CHANGE_ON="$P"); wt "$PR" prune --yes; ENVX=()
check  "the change was made between the two passes" test -e "$TMP/.changed"
check  "a worktree that got an unmerged commit is kept" test -d "$P"
says   "prune says it was not removed" "$ERR" "not removed p-late"

echo "Review round 3 (PR #86)"
# A branch that is its own base is never "merged", and the default branch is never deleted.
X="$TMP/x/proj"; new_repo "$X"; commit "$X" mo.txt "main-only work"; git -C "$X" checkout -q -b feature HEAD~1
mkwt "$X" x-main --branch main >/dev/null
wt "$X" list
is     "a branch that is its own base reads unknown" "$(field "$(row x-main)" 5)" unknown
wt "$X" remove x-main --delete-branch
is     "remove refuses it" "$RC" 1
says   "the refusal says the branch is its own base" "$ERR" "its own base"
wt "$X" remove x-main --delete-branch --force
is     "--force removes the worktree" "$RC" 0
check  "the default branch is kept" has_branch "$X" main
is     "its commit is still there" "$(git -C "$X" log -1 --format=%s main)" "main-only work"
Y="$TMP/y/proj"; new_repo "$Y"; git -C "$Y" checkout -q -b feature; commit "$Y" f.txt "feature work"
mkwt "$Y" y-main --branch main >/dev/null; git -C "$Y" config branch.main.harnessBase feature
wt "$Y" remove y-main --delete-branch
is     "a merged default branch: the worktree is removed" "$RC" 0
check  "the default branch is never deleted, even when merged" has_branch "$Y" main
says   "stderr says it is the default branch" "$ERR" "default branch"

# A remote branch whose name a tag shadows: check out the remote branch, never the tag.
git -C "$SEED" push -q "$ORIGIN" remote-only:refs/heads/rel 2>/dev/null; git -C "$R3" fetch -q origin 2>/dev/null
git -C "$R3" tag rel main
wt "$R3" create rel
is     "a remote branch shadowed by a tag: exits 0" "$RC" 0
is     "it is checked out as the branch" "$(git -C "$OUT" symbolic-ref -q HEAD 2>/dev/null)" refs/heads/rel
is     "at the remote branch's tip" "$(git -C "$R3" rev-parse -q --verify refs/heads/rel)" "$(git -C "$R3" rev-parse refs/remotes/origin/rel)"
is     "tracking the remote branch" "$(git -C "$R3" config --get branch.rel.merge)" refs/heads/rel

# A base name that a tag shadows: the branch wins, in create and in the merged check.
T="$TMP/t/proj"; new_repo "$T"; git -C "$T" tag release
git -C "$T" checkout -q -b release && commit "$T" rel.txt "release work" && git -C "$T" checkout -q main
P="$(mkwt "$T" t-st --base release)"
is     "--base <name> starts from the branch, not a same-name tag" "$(git -C "$T" rev-parse -q --verify refs/heads/t-st)" "$(git -C "$T" rev-parse refs/heads/release)"
is     "and records the branch" "$(git -C "$T" config --get branch.t-st.harnessBase)" release
commit "$P" st.txt "stacked work"; git -C "$T" branch -f release t-st
wt "$T" list
is     "the merged check reads the branch, not the tag" "$(field "$(row t-st)" 5)" merged

# A bisect, or a rebase stopped at break (detached), is work in progress: prune keeps it.
P="$(mkwt "$PR" p-bisect)"; commit "$P" pb.txt "pb work"; git -C "$PR" merge -q --ff-only p-bisect
git -C "$P" bisect start >/dev/null 2>&1
P2="$(mkwt "$PR" p-rebase)"; commit "$P2" pr1.txt "pr one"; commit "$P2" pr2.txt "pr two"
git -C "$PR" merge -q --ff-only p-rebase
printf '#!/bin/sh\nprintf "break\\n" > "$1"\n' > "$TMP/seq-break"; chmod +x "$TMP/seq-break"
GIT_SEQUENCE_EDITOR="$TMP/seq-break" git -C "$P2" rebase -i HEAD~1 >/dev/null 2>&1
check  "the rebase fixture is stopped and detached" test -z "$(git -C "$P2" symbolic-ref -q HEAD)"
wt "$PR" prune
is     "prune does not list a worktree with a bisect in progress" "$(row p-bisect)" ""
says   "prune says why it keeps the bisect" "$ERR" "kept p-bisect:"
is     "prune does not list a detached worktree in a rebase" "$(row p-rebase)" ""
says   "prune says why it keeps the rebase" "$ERR" "kept p-rebase:"
wt "$PR" remove p-bisect
is     "remove refuses a worktree with a bisect in progress" "$RC" 1
says   "the refusal names the bisect" "$ERR" "bisect"
wt "$PR" remove p-bisect --force
is     "--force removes it" "$RC" 0

# ---------------------------------------------------------------------------------------------
# Issue #88 — a project-owned setup step after create: .agents/worktree-copy.txt (copied on every
# create) and .agents/worktree-setup.sh (run on create --setup or setup <slug>), both read from the
# main checkout; exit 4 when a post-create step fails; byte-identical ignored files are recoverable.

echo "Issue #88 AC1 — no project files: create as in 0.4.0-rc.42"
S0="$TMP/s0/proj"; new_repo "$S0"; IDS0="$(repo_id "$S0")"
wt "$S0" create s0-a
is    "#88 AC1: create exits 0" "$RC" 0
is    "#88 AC1: create prints only the path" "$OUT" "$ROOTP/$IDS0/s0-a"
says  "#88 AC1: the install note stays" "$ERR" "run the project's own install"
says  "#88 AC1: the .env note stays" "$ERR" "bring over any .env by hand"
saysn "#88 AC1: no setup command without a setup script" "$ERR" "worktree.sh setup"
wt "$S0" setup s0-a
is    "#88 AC1: setup with neither file exits 0" "$RC" 0
is    "#88 AC1: setup prints the path" "$OUT" "$ROOTP/$IDS0/s0-a"
says  "#88 AC1: setup says there is nothing to set up" "$ERR" "nothing to set up"

# Fixture: a main checkout with ignored files, a setup script that records how it ran, a branch
# that carries its own (different) setup script, and a branch where conf/ is a tracked symlink that
# leads outside the worktree.
S="$TMP/s/proj"; new_repo "$S"; IDS="$(repo_id "$S")"; SP="$(cd "$S" && pwd -P)"
printf '.env\n.env.local\nnode_modules/\ncerts/\nlinked.env\nx.env\nsecret.env\n' > "$S/.gitignore"
git -C "$S" add -A && git -C "$S" commit -qm ignores
git -C "$S" checkout -q -b other-setup
put "$S" .agents/worktree-setup.sh '#!/bin/sh
mkdir -p node_modules && : > node_modules/.branch-ran'
chmod +x "$S/.agents/worktree-setup.sh"; git -C "$S" add -A && git -C "$S" commit -qm "branch setup"
git -C "$S" checkout -q main
mkdir -p "$TMP/outside" "$TMP/outside2"
git -C "$S" checkout -q -b symlinked
ln -s "$TMP/outside2" "$S/conf"; ln -s ../nowhere "$S/conf2"
git -C "$S" add -A && git -C "$S" commit -qm "conf links"
git -C "$S" checkout -q main
put "$S" .env "SECRET=main"; chmod 600 "$S/.env"
put "$S" apps/web/.env.local "WEB=1"; put "$S" apps/api/.env.local "API=1"
put "$S" .agents/worktree-setup.sh '#!/bin/sh
echo "setup-stdout-marker"
mkdir -p node_modules
{
  echo "cwd=$(pwd -P)"
  echo "main=$HARNESS_WORKTREE_MAIN"
  echo "path=$HARNESS_WORKTREE_PATH"
  echo "branch=$HARNESS_WORKTREE_BRANCH"
  echo "lc_all=${LC_ALL-unset}"
  if [ -f .env ]; then echo "env=yes"; else echo "env=no"; fi
  if [ -t 0 ]; then echo "stdin=tty"; else echo "stdin=$(wc -c | tr -d " ")"; fi
} > node_modules/.setup-ran
exit "${SETUP_EXIT:-0}"'
chmod +x "$S/.agents/worktree-setup.sh"
# copylist <entry>... - write the main checkout's .agents/worktree-copy.txt, one entry per line.
copylist() { printf '%s\n' "$@" > "$S/.agents/worktree-copy.txt"; }

echo "Issue #88 AC2 — the copy list"
copylist '# env files' '' '  .env  ' './apps/*/.env.local' 'missing.env' 'nomatch/*.env'
wt "$S" create s-copy
P="$ROOTP/$IDS/s-copy"
is    "#88 AC2: create with a copy list exits 0" "$RC" 0
is    "#88 AC2: stdout is only the path" "$OUT" "$P"
is    "#88 AC2: a literal entry is copied" "$(cat "$P/.env" 2>/dev/null)" "SECRET=main"
is    "#88 AC2: the copy keeps the mode" "$(ls -l "$P/.env" 2>/dev/null | cut -c1-10)" "-rw-------"
is    "#88 AC2: a glob entry is copied (web)" "$(cat "$P/apps/web/.env.local" 2>/dev/null)" "WEB=1"
is    "#88 AC2: a glob entry is copied (api)" "$(cat "$P/apps/api/.env.local" 2>/dev/null)" "API=1"
says  "#88 AC2: a missing source is reported" "$ERR" "no match for missing.env"
says  "#88 AC2: an empty glob is reported" "$ERR" "no match for nomatch/*.env"
saysn "#88 AC2: no .env-by-hand note with a copy list" "$ERR" "bring over any .env by hand"
is    "#88 AC2: the copies leave the worktree clean" "$(git -C "$P" status --porcelain 2>/dev/null)" ""

echo "Issue #88 AC3 — copy-list entries that leave the repository"
n=0
for e in /etc/hosts ../x 'a/../../x' .git/config 'sub/.git/hooks/x'; do
  n=$((n+1)); copylist .env "$e"
  wt "$S" create "s-bad$n"
  is     "#88 AC3: '$e' is refused" "$RC" 1
  says   "#88 AC3: the refusal for '$e' names the line" "$ERR" "line 2"
  check  "#88 AC3: '$e' creates no directory" test ! -e "$ROOTP/$IDS/s-bad$n"
  checkn "#88 AC3: '$e' creates no branch" has_branch "$S" "s-bad$n"
done

# A glob such as .*/x can match .. in bash 3.2 (newer bash skips it): a match is checked again.
mkdir -p "$TMP/s/outside3"; put "$TMP/s/outside3" secret.env "OUT=3"
copylist '.*/outside3/secret.env'
wt "$S" setup s-copy
check  "#88 AC3: a glob that matches .. writes nothing outside the worktree" test ! -e "$ROOTP/$IDS/outside3"
saysn  "#88 AC3: a glob that matches .. copies nothing" "$ERR" "copy: ../outside3"

echo "Issue #88 AC4 — copy guards"
ln -s .env "$S/linked.env"
put "$S" certs/a.pem "PEM"
put "$TMP/outside" secret.env "OUT=1"; ln -s "$TMP/outside" "$S/ext"
put "$S" notignored.txt "plain"
put "$S" conf/x.env "X=1"; put "$S" conf2/x.env "X=2"
copylist .env linked.env certs ext/secret.env notignored.txt conf/x.env conf2/x.env
wt "$S" create s-guard --base symlinked
P="$ROOTP/$IDS/s-guard"
is    "#88 AC4: a refused entry makes create exit 4" "$RC" 4
is    "#88 AC4: exit 4 still prints the path" "$OUT" "$P"
check "#88 AC4: the worktree stays" test -d "$P"
check "#88 AC4: the branch stays" has_branch "$S" s-guard
is    "#88 AC4: the other entries are still copied" "$(cat "$P/.env" 2>/dev/null)" "SECRET=main"
for e in linked.env certs ext/secret.env notignored.txt conf/x.env; do
  says "#88 AC4: refused $e is reported" "$ERR" "refused $e"
done
check "#88 AC4: a symlink source is not copied" test ! -e "$P/linked.env"
check "#88 AC4: a directory is not copied" test ! -e "$P/certs"
check "#88 AC4: a source outside the main checkout is not copied" test ! -e "$P/ext"
check "#88 AC4: a file git does not ignore is not copied" test ! -e "$P/notignored.txt"
check "#88 AC4: nothing is written through a symlinked folder" test ! -e "$TMP/outside2/x.env"
# The copy never writes through a symlink in the worktree, also one that is dangling there.
says  "#88 AC4: a symlinked folder is refused for that reason" "$ERR" "refused conf/x.env: a folder on its path in the worktree is a symlink"
says  "#88 AC4: a dangling symlinked folder is refused for that reason" "$ERR" "refused conf2/x.env: a folder on its path in the worktree is a symlink"
says  "#88 AC4: stderr says how to retry" "$ERR" "worktree.sh setup s-guard"
copylist .env
put "$ROOTP/$IDS/s-copy" .env "EDITED"
wt "$S" setup s-copy
is    "#88 AC4: setup with a differing destination exits 0" "$RC" 0
says  "#88 AC4: a differing destination is kept" "$ERR" "kept .env"
is    "#88 AC4: an existing destination is never overwritten" "$(cat "$ROOTP/$IDS/s-copy/.env" 2>/dev/null)" "EDITED"

echo "Issue #88 AC5 — the setup script runs only on --setup"
wt "$S" create s-plain
P="$ROOTP/$IDS/s-plain"
is    "#88 AC5: a plain create exits 0" "$RC" 0
check "#88 AC5: a plain create never runs the setup script" test ! -e "$P/node_modules/.setup-ran"
says  "#88 AC5: stderr names the setup command" "$ERR" "worktree.sh setup s-plain"
saysn "#88 AC5: no install note when a setup script exists" "$ERR" "run the project's own install"
mv "$S/.agents/worktree-setup.sh" "$TMP/setup.saved"
wt "$S" create s-noscript --setup
is     "#88 AC5: --setup without a setup script is refused" "$RC" 1
says   "#88 AC5: the refusal names the file" "$ERR" "worktree-setup.sh"
check  "#88 AC5: nothing is created without a setup script" test ! -e "$ROOTP/$IDS/s-noscript"
checkn "#88 AC5: no branch is created without a setup script" has_branch "$S" s-noscript
mv "$TMP/setup.saved" "$S/.agents/worktree-setup.sh"; chmod -x "$S/.agents/worktree-setup.sh"
wt "$S" create s-noexec --setup
is     "#88 AC5: --setup with a non-executable script is refused" "$RC" 1
check  "#88 AC5: nothing is created for a non-executable script" test ! -e "$ROOTP/$IDS/s-noexec"
chmod +x "$S/.agents/worktree-setup.sh"

echo "Issue #88 AC6 — create --setup"
ENVX=(LC_ALL=POSIX); wt "$S" create s-setup --setup <<<"stdin-data"; ENVX=()
P="$ROOTP/$IDS/s-setup"; M="$P/node_modules/.setup-ran"
is   "#88 AC6: create --setup exits 0" "$RC" 0
is   "#88 AC6: stdout is exactly the path" "$OUT" "$P"
is   "#88 AC6: the script runs in the new worktree" "$(grep '^cwd=' "$M" 2>/dev/null)" "cwd=$P"
is   "#88 AC6: HARNESS_WORKTREE_MAIN is the main checkout" "$(grep '^main=' "$M" 2>/dev/null)" "main=$SP"
is   "#88 AC6: HARNESS_WORKTREE_PATH is the worktree" "$(grep '^path=' "$M" 2>/dev/null)" "path=$P"
is   "#88 AC6: HARNESS_WORKTREE_BRANCH is the branch" "$(grep '^branch=' "$M" 2>/dev/null)" "branch=s-setup"
is   "#88 AC6: the caller's LC_ALL is restored" "$(grep '^lc_all=' "$M" 2>/dev/null)" "lc_all=POSIX"
is   "#88 AC6: the copy step runs first" "$(grep '^env=' "$M" 2>/dev/null)" "env=yes"
is   "#88 AC6: stdin is empty" "$(grep '^stdin=' "$M" 2>/dev/null)" "stdin=0"
says "#88 AC6: the script's stdout goes to stderr" "$ERR" "setup-stdout-marker"
ENVX=(-u LC_ALL); wt "$S" create s-setup2 --setup; ENVX=()
is   "#88 AC6: an unset LC_ALL stays unset" "$(grep '^lc_all=' "$ROOTP/$IDS/s-setup2/node_modules/.setup-ran" 2>/dev/null)" "lc_all=unset"
wt "$S" create s-branchcopy --base other-setup --setup
P="$ROOTP/$IDS/s-branchcopy"
is    "#88 AC6: exits 0 when the branch has its own script" "$RC" 0
check "#88 AC6: the main checkout's script runs" test -f "$P/node_modules/.setup-ran"
check "#88 AC6: the branch's script does not run" test ! -e "$P/node_modules/.branch-ran"
says  "#88 AC6: stderr says the worktree's copy differs" "$ERR" "differs"

echo "Issue #88 AC7 — a failing setup script"
ENVX=(SETUP_EXIT=7); wt "$S" create s-fail --setup; ENVX=()
P="$ROOTP/$IDS/s-fail"
is    "#88 AC7: a failing setup exits 4" "$RC" 4
is    "#88 AC7: exit 4 still prints the path" "$OUT" "$P"
check "#88 AC7: the worktree stays" test -d "$P"
check "#88 AC7: the branch stays" has_branch "$S" s-fail
says  "#88 AC7: stderr names the exit code" "$ERR" "exited 7"
says  "#88 AC7: stderr says how to retry" "$ERR" "worktree.sh setup s-fail"

echo "Issue #88 AC8 — setup <slug> and a re-run of create"
wt "$S" setup s-fail
is   "#88 AC8: setup re-runs both steps (exit 0 once fixed)" "$RC" 0
is   "#88 AC8: setup prints the path" "$OUT" "$ROOTP/$IDS/s-fail"
says "#88 AC8: setup runs the script" "$ERR" "setup-stdout-marker"
wt "$S" setup;             is "#88 AC8: setup without a slug is a bad call" "$RC" 2
wt "$S" setup a b;         is "#88 AC8: setup takes one slug" "$RC" 2
wt "$S" setup s-fail --x;  is "#88 AC8: setup takes no option" "$RC" 2
wt "$S" setup no-such;     is "#88 AC8: an unknown slug is refused" "$RC" 1
git -C "$S" worktree add -q -b s-ext "$TMP/s-ext"
wt "$S" setup s-ext;       is "#88 AC8: an external worktree is refused" "$RC" 1
P="$(mkwt "$S" s-gone)"; case "$P" in "$TMPP"/*) rm -rf "$P" ;; esac
wt "$S" setup s-gone;      is "#88 AC8: a missing worktree directory is refused" "$RC" 1
rm -f "$ROOTP/$IDS/s-fail/node_modules/.setup-ran"
wt "$S" create s-fail --setup
is    "#88 AC8: a re-run of create --setup exits 0" "$RC" 0
is    "#88 AC8: a re-run of create prints the path" "$OUT" "$ROOTP/$IDS/s-fail"
check "#88 AC8: a re-run of create runs no setup" test ! -e "$ROOTP/$IDS/s-fail/node_modules/.setup-ran"
says  "#88 AC8: a re-run of create names setup <slug>" "$ERR" "worktree.sh setup s-fail"
wt "$S" create s-fail
says  "#88 AC8: a plain re-run of create names setup <slug> too" "$ERR" "worktree.sh setup s-fail"

echo "Issue #88 AC9 — byte-identical ignored files are recoverable"
copylist .env
# A copy made by hand counts too: the rule reads the bytes, not the copy list.
P="$(mkwt "$S" s-ident)"; put "$P" .env "SECRET=main"; put "$P" apps/web/.env.local "WEB=1"
wt "$S" remove s-ident
is    "#88 AC9: identical ignored files do not stop remove" "$RC" 0
check "#88 AC9: the worktree is gone" test ! -e "$ROOTP/$IDS/s-ident"
P="$(mkwt "$S" s-edit)"; put "$P" .env "SECRET=edited"
wt "$S" remove s-edit
is    "#88 AC9: an edited copy stops remove" "$RC" 1
says  "#88 AC9: the refusal names the edited copy" "$ERR" ".env"
P="$(mkwt "$S" s-link)"
if fixture_dir "$P"; then rm -f "$P/.env"; ln -s "$SP/.env" "$P/.env"; fi
wt "$S" remove s-link
is    "#88 AC9: a symlinked .env stops remove" "$RC" 1
P="$(mkwt "$S" s-maingone)"; put "$P" apps/api/.env.local "API=1"
mv "$S/apps/api/.env.local" "$TMP/api.saved"
wt "$S" remove s-maingone
is    "#88 AC9: a copy whose main-checkout file is gone stops remove" "$RC" 1
says  "#88 AC9: the refusal names that file" "$ERR" "apps/api/.env.local"
mv "$TMP/api.saved" "$S/apps/api/.env.local"
P="$(mkwt "$S" s-pident)"; put "$P" .env "SECRET=main"; commit "$P" pi.txt "pi work"
git -C "$S" merge -q --ff-only s-pident
P="$(mkwt "$S" s-pedit)"; put "$P" .env "SECRET=edited"; commit "$P" pe.txt "pe work"
git -C "$S" merge -q --ff-only s-pedit
wt "$S" prune
check "#88 AC9: prune lists a merged worktree with an identical .env" test -n "$(row s-pident)"
is    "#88 AC9: prune keeps a merged worktree with an edited .env" "$(row s-pedit)" ""
says  "#88 AC9: prune says why" "$ERR" "kept s-pedit: ignored files"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
