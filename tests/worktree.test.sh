#!/usr/bin/env bash
# Tests for worktree.sh — one adapter-neutral root for the worktrees the harness creates, and the
# path / create / list / remove / prune contract (issue #85). One section per acceptance criterion
# in the task spec (AC1–AC11). Issue #88 (the project-owned setup step: copy list, setup script,
# `setup <slug>`, exit 4) adds the sections marked "#88 AC<n>". Issue #93 (the junk list read from
# the main checkout) adds the sections marked "#93 AC<n>". Issue #89 (adopting a worktree made
# elsewhere; prune keeps a worktree with no create record) adds the sections marked "#89 AC<n>".
# Issue #95 (bare repository: no copy list or setup script read in a harness worktree) adds the
# sections marked "#95 AC<n>". Issue #102 (create names the committed agent files that differ) adds the
# sections marked "#102 AC<n>". Issue #104 (the script drops the caller's git repository variables)
# adds the sections marked "#104 AC<n>".
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

echo "Issue #88 — security review round 1"
# wt_bounded <secs> <fifo> <dir> <args...> - wt in the background. When it still runs after <secs>,
# set HUNG=1 and open <fifo> for writing once, which releases a reader blocked on it.
wt_bounded() {
  local secs="$1" fifo="$2" d="$3" pid n=0; shift 3
  HUNG=0
  ( wt "$d" "$@"; printf '%s' "$RC" > "$TMP/.b.rc"; printf '%s' "$OUT" > "$TMP/.b.out"; printf '%s' "$ERR" > "$TMP/.b.err" ) &
  pid=$!
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt $((secs * 5)) ]; do sleep 0.2; n=$((n+1)); done
  if kill -0 "$pid" 2>/dev/null; then HUNG=1; ( : > "$fifo" ) & fi
  wait "$pid"
  RC="$(cat "$TMP/.b.rc")"; OUT="$(cat "$TMP/.b.out")"; ERR="$(cat "$TMP/.b.err")"
}
copylist .env
P="$(mkwt "$S" s-fifo)"
if fixture_dir "$P"; then rm -f "$P/.env"; mkfifo "$P/.env"; fi
wt_bounded 5 "$P/.env" "$S" setup s-fifo
is    "#88 R1: a FIFO destination does not hang setup" "$HUNG" 0
is    "#88 R1: setup with a FIFO destination exits 0" "$RC" 0
says  "#88 R1: a non-regular destination is kept" "$ERR" "kept .env (not a regular file"
check "#88 R1: the FIFO is left as it is" test -p "$P/.env"
if fixture_dir "$P"; then rm -f "$P/.env"; mkdir -p "$P/.agents"; mkfifo "$P/.agents/worktree-setup.sh"; fi
wt_bounded 5 "$P/.agents/worktree-setup.sh" "$S" setup s-fifo
is    "#88 R1: a FIFO as the worktree's setup script does not hang setup" "$HUNG" 0
is    "#88 R1: setup still runs the main checkout's script" "$RC" 0
if fixture_dir "$P"; then rm -f "$P/.agents/worktree-setup.sh"; fi
# .git in any letter case names the git dir on a case-insensitive filesystem (macOS default).
n=0
for e in .GIT/config 'sub/.Git/hooks/x'; do
  n=$((n+1)); copylist .env "$e"
  wt "$S" create "s-case$n"
  is     "#88 R1: '$e' is refused" "$RC" 1
  says   "#88 R1: the refusal for '$e' names .git" "$ERR" "names .git"
  checkn "#88 R1: '$e' creates no branch" has_branch "$S" "s-case$n"
done
copylist .env

# ---------------------------------------------------------------------------------------------
# Issue #93 — remove and prune read .agents/worktree-junk.txt from the main checkout, so a branch
# nobody reviewed cannot make an .env junk by running the script from its own worktree.
echo "Issue #93 AC1/AC4 — a branch's own junk list is not used"
J="$TMP/jm/proj"; new_repo "$J"
put "$J" .gitignore ".env" && git -C "$J" add -A && git -C "$J" commit -qm "ignore .env"
PA="$(mkwt "$J" j-a)"
if put "$PA" .agents/worktree-junk.txt ".env"; then git -C "$PA" add -A && git -C "$PA" commit -qm "junk: .env"; fi
PB="$(mkwt "$J" j-b)"; put "$PB" .env "EDITED=b"
PC="$(mkwt "$J" j-c)"; commit "$PC" jc.txt "jc work"
git -C "$J" merge -q --no-ff -m "merge j-c" j-c; put "$PC" .env "EDITED=c"
wt "$PA" remove j-b
is    "#93 AC1: remove from a worktree whose branch lists .env is refused" "$RC" 1
says  "#93 AC1: the refusal names the .env" "$ERR" ".env"
check "#93 AC1: the edited .env stays" test -f "$PB/.env"
says  "#93 AC4: the note names the differing list" "$ERR" "this checkout's own .agents/worktree-junk.txt differs"
says  "#93 AC4: the note says the main checkout's list is used" "$ERR" "the main checkout's list is used"

echo "Issue #93 AC3 — prune reads the same list"
wt "$PA" prune
is    "#93 AC3: prune does not list a merged worktree with an edited .env" "$(row j-c)" ""
says  "#93 AC3: prune says why" "$ERR" "kept j-c: ignored files outside the junk list"
wt "$PA" prune --yes
check "#93 AC3: prune --yes keeps the edited .env" test -f "$PC/.env"

echo "Issue #93 AC2/AC4 — the main checkout's list applies everywhere"
if fixture_dir "$J"; then mkdir -p "$J/.agents"; printf '.env\n' > "$J/.agents/worktree-junk.txt"; fi
wt "$PA" remove j-b
is    "#93 AC2: remove passes once the main checkout's list has .env" "$RC" 0
check "#93 AC2: the worktree is gone" test ! -e "$PB"
saysn "#93 AC4: no note when the lists are identical" "$ERR" "worktree-junk.txt differs"
PD="$(mkwt "$J" j-d)"; PE="$(mkwt "$J" j-e)"; put "$PE" .env "EDITED=e"
wt "$PD" remove j-e
is    "#93 AC2: remove from a worktree without its own list uses the main checkout's" "$RC" 0
check "#93 AC2: that worktree is gone" test ! -e "$PE"
saysn "#93 AC4: no note when the worktree has no list" "$ERR" "worktree-junk.txt differs"
wt "$PD" prune
check "#93 AC3: with the main checkout's list, prune lists j-c" test -n "$(row j-c)"
wt "$J" prune
saysn "#93 AC4: no note from the main checkout" "$ERR" "worktree-junk.txt differs"
if fixture_dir "$J"; then printf '.env\n# main\n' > "$J/.agents/worktree-junk.txt"; fi
wt "$PA" prune
says  "#93 AC4: a note when both lists exist and differ" "$ERR" "this checkout's own .agents/worktree-junk.txt differs"

echo "Issue #93 AC5 — a bare repository uses the current checkout's list"
BR="$TMP/bm/proj.git"; mkdir -p "$TMP/bm"; git clone -q --bare "$J" "$BR"
BC="$TMP/bm/main"; git -C "$BR" worktree add -q "$BC" main
put "$BC" .agents/worktree-junk.txt ".env"
PX="$(mkwt "$BC" b-x)"; put "$PX" .env "EDITED=x"
wt "$BC" remove b-x
is    "#93 AC5: in a bare repository the current checkout's list applies" "$RC" 0
check "#93 AC5: the worktree is gone" test ! -e "$PX"
saysn "#93 AC5: no note in a bare repository" "$ERR" "worktree-junk.txt differs"

echo "Issue #93 review round 1 — a bare repository never reads a harness worktree's list"
# A bare repository has no main checkout. A harness worktree is where an unreviewed branch lands
# (create --branch), so run from one, only the default list applies.
PY="$(mkwt "$BC" b-y)"
if put "$PY" .agents/worktree-junk.txt ".env"; then git -C "$PY" add -A && git -C "$PY" commit -qm "junk: .env"; fi
PZ="$(mkwt "$BC" b-z)"; put "$PZ" .env "EDITED=z"
wt "$PY" remove b-z
is    "#93 R1: bare repo, run from a harness worktree: its own list is not used" "$RC" 1
check "#93 R1: the edited .env stays" test -f "$PZ/.env"
says  "#93 R1: the note says only the default list applies" "$ERR" "in a harness worktree only the default list applies"
PW="$(mkwt "$BC" b-w)"
wt "$PW" remove b-z
is    "#93 R1: also from a harness worktree without a list of its own" "$RC" 1
says  "#93 R1: the note appears there too" "$ERR" "in a harness worktree only the default list applies"
wt "$BC" remove b-z
is    "#93 R1: the bare repository's own checkout still uses its list" "$RC" 0
check "#93 R1: that worktree is gone" test ! -e "$PZ"
saysn "#93 R1: no harness note from that checkout" "$ERR" "only the default list applies"

echo "Issue #95 AC1-AC5 — bare repository: a harness worktree never supplies the copy list or setup script"
# The harness worktree holds an unreviewed branch: its own copy list and setup script. The main
# branch carries other ones, which the bare repository's own checkout uses. Each script leaves its
# own marker in the worktree it ran in.
S95="$TMP/b95/src"; mkdir -p "$TMP/b95"; new_repo "$S95"
put "$S95" .gitignore $'.env\nsecret.env\nran-own\nran-branch'
put "$S95" .agents/worktree-copy.txt ".env"
if put "$S95" .agents/worktree-setup.sh $'#!/bin/sh\n: > ran-own'; then
  chmod +x "$S95/.agents/worktree-setup.sh"; git -C "$S95" add -A && git -C "$S95" commit -qm "project files"
fi
B95="$TMP/b95/proj.git"; git clone -q --bare "$S95" "$B95"
C95="$TMP/b95/main"; git -C "$B95" worktree add -q "$C95" main
put "$C95" .env "SECRET=own"
PU="$(mkwt "$C95" u-branch)"; H95="${PU%/*}"
put "$PU" .agents/worktree-copy.txt "secret.env"
if put "$PU" .agents/worktree-setup.sh $'#!/bin/sh\n: > ran-branch'; then
  git -C "$PU" add -A && git -C "$PU" commit -qm "unreviewed project files"
fi
put "$PU" secret.env "SECRET=branch"

wt "$PU" create v-setup --setup
is     "#95 AC1: create --setup from a harness worktree is refused" "$RC" 1
says   "#95 AC1: the refusal says why" "$ERR" "a bare repository has no main checkout, so in a harness worktree"
says   "#95 AC1: the refusal says nothing was created" "$ERR" "nothing created"
check  "#95 AC1: no directory" test ! -e "$H95/v-setup"
checkn "#95 AC1: no branch" has_branch "$B95" v-setup

wt "$PU" create v-plain
is     "#95 AC2: create without --setup works" "$RC" 0
is     "#95 AC2: stdout is the path alone" "$OUT" "$H95/v-plain"
check  "#95 AC2: the branch's listed file is not copied" test ! -e "$H95/v-plain/secret.env"
check  "#95 AC2: no script ran" test ! -e "$H95/v-plain/ran-branch"
says   "#95 AC2: stderr says why" "$ERR" "a bare repository has no main checkout, so in a harness worktree"
says   "#95 AC2: stderr says nothing was copied" "$ERR" "nothing copied"
saysn  "#95 AC2: no 'differs' note" "$ERR" "differs"
saysn  "#95 AC2: no hint to run the unread script" "$ERR" "was not run"

# A branch with neither file: hints to add one there would point at a file that is not read either.
PN="$(mkwt "$C95" u-none)"
if fixture_dir "$PN"; then
  git -C "$PN" rm -q .agents/worktree-copy.txt .agents/worktree-setup.sh && git -C "$PN" commit -qm "no files"
fi
wt "$PN" create v-none
is     "#95 AC2: create from a harness worktree without the files" "$RC" 0
says   "#95 AC2: the same reason there" "$ERR" "nothing copied"
saysn  "#95 AC2: no hint to list a file in the unread list" "$ERR" "or list it in .agents/worktree-copy.txt"
saysn  "#95 AC2: no hint to add the unread script" "$ERR" "or add .agents/worktree-setup.sh"
says   "#95 review: the install reminder stays" "$ERR" "run the project's own install in the new worktree (e.g. pnpm install)"
says   "#95 review: so does the .env reminder" "$ERR" "bring over any .env by hand"

PU2="$(mkwt "$C95" u-hosts)"
if put "$PU2" .agents/worktree-copy.txt "/etc/hosts"; then
  git -C "$PU2" add -A && git -C "$PU2" commit -qm "bad copy list"
fi
wt "$PU2" create v-hosts
is     "#95 AC3: a bad entry in that worktree's list is not read" "$RC" 0
saysn  "#95 AC3: the entry is never seen" "$ERR" "/etc/hosts"
check  "#95 AC3: the worktree exists" test -d "$H95/v-hosts"

PT="$(mkwt "$C95" t-set)"
wt "$PU" setup t-set
is     "#95 AC4: setup from a harness worktree is refused" "$RC" 1
says   "#95 AC4: the refusal says why" "$ERR" "a bare repository has no main checkout, so in a harness worktree"
says   "#95 AC4: the refusal says nothing ran" "$ERR" "nothing run"
check  "#95 AC4: nothing copied" test ! -e "$PT/secret.env"
check  "#95 AC4: nothing run" test ! -e "$PT/ran-branch"
wt "$PU" setup no-such
is     "#95 AC4: an unknown slug still exits 1" "$RC" 1
says   "#95 AC4: and keeps its message" "$ERR" "no harness worktree 'no-such'"

wt "$PU" create t-set --setup
is     "#95 AC5: a re-run still exits 0" "$RC" 0
is     "#95 AC5: and prints the path" "$OUT" "$PT"
says   "#95 AC5: the note points at your own checkout" "$ERR" "from your own checkout"
says   "#95 AC5: --setup stays unused on a re-run" "$ERR" "--setup not used"

echo "Issue #95 AC6 — the bare repository's own checkout still applies both files"
wt "$C95" create o-setup --setup
is     "#95 AC6: create --setup from your own checkout" "$RC" 0
check  "#95 AC6: the listed file is copied" test -f "$H95/o-setup/.env"
check  "#95 AC6: your setup script runs" test -f "$H95/o-setup/ran-own"
saysn  "#95 AC6: no harness note there" "$ERR" "in a harness worktree"
P95="$(mkwt "$C95" o-later)"
if fixture_dir "$P95"; then rm -f "$P95/.env" "$P95/ran-own"; fi
wt "$C95" setup o-later
is     "#95 AC6: setup <slug> from your own checkout" "$RC" 0
check  "#95 AC6: it copies the listed file" test -f "$P95/.env"
check  "#95 AC6: it runs your setup script" test -f "$P95/ran-own"

echo "Issue #95 review — a harness worktree is recognised whatever the letter case of the root"
# On a case-insensitive disk (the macOS default) <root> and <ROOT> are one folder but differ as text:
# the check must compare folders, or an unreviewed branch's files are read again.
if [ -d "$TMP/ROOT" ]; then
  ENVX=(HARNESS_WORKTREE_ROOT="$TMP/ROOT")
  PK="$(mkwt "$C95" u-case)"; PJ="$(mkwt "$C95" j-case)"; HK="${PK%/*}"
  put "$PK" .agents/worktree-junk.txt ".env"
  if put "$PK" .agents/worktree-setup.sh $'#!/bin/sh\n: > ran-case'; then
    git -C "$PK" add -A && git -C "$PK" commit -qm "unreviewed project files"
  fi
  put "$PJ" .env "EDITED=j"
  wt "$PK" create v-case --setup
  is     "#95 review: create --setup is refused with the root in another case" "$RC" 1
  says   "#95 review: for the bare-repository reason" "$ERR" "in a harness worktree"
  check  "#95 review: nothing created, so nothing ran" test ! -e "$HK/v-case"
  wt "$PK" remove j-case
  is     "#95 review: that worktree's junk list is not used either" "$RC" 1
  check  "#95 review: the edited .env stays" test -f "$PJ/.env"
  ENVX=()
else
  echo "  (skipped: the filesystem is case-sensitive)"
fi

# ---------------------------------------------------------------------------------------------
# Issue #89 — adopt worktrees an agent made elsewhere (docs/worktrees.md, "Adopting a worktree made
# elsewhere"), and prune keeps a present harness worktree that has no create record.
echo "Issue #89 AC6 — the documented adoption flow"
AD="$TMP/ad/proj"; new_repo "$AD"; IDAD="$(repo_id "$AD")"
put "$AD" .gitignore ".env" && git -C "$AD" add -A && git -C "$AD" commit -qm "ignore .env"
EXT="$AD/.claude/worktrees"; EXTP="$TMPP/ad/proj/.claude/worktrees"; ADR="$ROOTP/$IDAD"
for s in a-fresh a-done a-wip a-gone; do git -C "$AD" worktree add -q -b "$s" "$EXT/$s"; done
commit "$EXT/a-done" ad.txt "ad work" && git -C "$AD" merge -q --no-ff -m "merge a-done" a-done
put "$EXT/a-wip" wip.txt
wt "$AD" list --all
r="$(printf '%s\n' "$OUT" | awk -F'\t' -v p="$EXTP/a-fresh" '$7==p')"
is     "#89 AC6: a worktree inside the repository is external" "$(field "$r" 1)" external
wt "$AD" path a-fresh; dest="$OUT"
is     "#89 AC6: path names the harness root" "$dest" "$ADR/a-fresh"
checkn "#89 AC6: git worktree move fails while the parent folder is missing" \
       git -C "$AD" worktree move "$EXT/a-fresh" "$dest"
check  "#89 AC6: the failed move leaves the worktree where it was" test -d "$EXT/a-fresh"
wt "$AD" create a-fresh
is     "#89 AC6: create on a branch an external worktree has checked out exits 1" "$RC" 1
case "$dest" in "$ROOTP"/*) mkdir -p "${dest%/*}" ;; esac
for s in a-fresh a-done a-wip a-gone; do
  wt "$AD" path "$s"; dest="$OUT"
  check "#89 AC6: git worktree move $s into the root (after mkdir -p)" \
        git -C "$AD" worktree move "$EXT/$s" "$dest"
done
put "$AD" .agents/worktree-copy.txt ".env"; put "$AD" .env "SECRET=main"
wt "$AD" setup a-wip
is     "#89 AC6: setup <slug> runs in an adopted worktree" "$RC" 0
is     "#89 AC6: setup prints the adopted path" "$OUT" "$ADR/a-wip"
check  "#89 AC6: setup copies the copy list there" test -f "$ADR/a-wip/.env"
wt "$AD" list
for s in a-fresh a-done a-wip a-gone; do
  is "#89 AC6: list shows the adopted $s as harness" "$(field "$(row "$s")" 1)" harness
  is "#89 AC6: list shows $s on its own branch" "$(field "$(row "$s")" 3)" "$s"
done

echo "Issue #89 AC5 — prune keeps a harness worktree with no create record"
case "$ADR" in "$ROOTP"/*) rm -rf "${ADR:?}/a-gone" ;; esac
git -C "$AD" worktree add -q --detach "$ADR/a-det"
P="$(mkwt "$AD" a-made)"; commit "$P" am.txt "am work" && git -C "$AD" merge -q --no-ff -m "merge a-made" a-made
# Review round 2: a create-made worktree switched to another branch has no record for that branch.
P="$(mkwt "$AD" a-sw)"; fixture_dir "$P" && git -C "$P" switch -q -c a-sw2
wt "$AD" prune
is     "#89 AC5: prune exits 0" "$RC" 0
for s in a-fresh a-done a-det a-sw; do
  is   "#89 AC5: prune does not list $s" "$(row "$s")" ""
  says "#89 AC5: prune says $s has no create record" "$ERR" \
       "kept $s: no create record (adopted, made by hand, or not on the branch create made), so it may still be in use ('worktree.sh remove $s' removes it)"
done
is     "#89 AC5: prune does not list a-wip" "$(row a-wip)" ""
says   "#89 AC5: the first reason still wins (a-wip is dirty)" "$ERR" "kept a-wip: uncommitted changes"
check  "#89 AC5: a missing adopted worktree is still a candidate" test -n "$(row a-gone)"
check  "#89 AC5: a create-made worktree with a merged commit is still a candidate" test -n "$(row a-made)"
wt "$AD" prune --yes
is     "#89 AC5: prune --yes exits 0" "$RC" 0
for s in a-fresh a-done a-wip a-det; do
  check "#89 AC5: prune --yes keeps $s" test -d "$ADR/$s"
done
checkn "#89 AC5: prune --yes drops the missing adopted worktree's record" listed "$AD" "$ADR/a-gone"
checkn "#89 AC5: prune --yes removes the create-made merged worktree" listed "$AD" "$ADR/a-made"
wt "$AD" remove a-done --delete-branch
is     "#89 AC5: remove still removes an adopted worktree" "$RC" 0
check  "#89 AC5: its directory is gone" test ! -e "$ADR/a-done"
checkn "#89 AC6: --delete-branch deletes the merged adopted branch" has_branch "$AD" a-done
wt "$AD" remove a-fresh
is     "#89 AC5: remove removes a fresh adopted worktree" "$RC" 0
check  "#89 AC5: without --delete-branch its branch stays" has_branch "$AD" a-fresh
wt "$AD" remove a-det
is     "#89 AC5: remove removes a clean detached worktree at the base" "$RC" 0

echo "Issue #90 AC1 — create seeds the session log from the main checkout"
# The project ignores the per-checkout files (the installer's .gitignore lines). apps/web has a session
# log and a todo file in the main checkout; apps/api has neither.
S9="$TMP/n/proj"; new_repo "$S9"; IDS9="$(repo_id "$S9")"; S9P="$(cd "$S9" && pwd -P)"
printf '**/.agents/session-log.md\n**/.agents/todo.md\n' > "$S9/.gitignore"
put "$S9" apps/web/package.json '{}'; put "$S9" apps/api/package.json '{}'
git -C "$S9" add -A && git -C "$S9" commit -qm "workspaces and ignore rules"
put "$S9" apps/web/.agents/session-log.md "web log (main)"
put "$S9" apps/web/.agents/todo.md "web todo (main)"
wt "$S9" create n-seed
is    "#90 AC1: create exits 0" "$RC" 0
is    "#90 AC1: create prints only the path" "$OUT" "$ROOTP/$IDS9/n-seed"
N1="$ROOTP/$IDS9/n-seed"
check "#90 AC1: the web session log is copied from the main checkout" \
      test "$(cat "$N1/apps/web/.agents/session-log.md" 2>/dev/null)" = "web log (main)"
checkn "#90 AC1: apps/api (no session log in main) gets none" test -e "$N1/apps/api/.agents/session-log.md"
checkn "#90 AC1: todo.md is not seeded (the task writes it)" test -e "$N1/apps/web/.agents/todo.md"
check  "#90 AC1: the worktree is clean (the seeded copy is ignored)" test -z "$(git -C "$N1" status --porcelain)"

echo "Issue #90 AC2 — a tracked file in the copy list is kept"
S9c="$TMP/n/copytracked"; new_repo "$S9c"
put "$S9c" .agents/worktree-copy.txt "README.md"
git -C "$S9c" add -A && git -C "$S9c" commit -qm "copy list names a tracked file"
wt "$S9c" create n-tracked
is    "#90 AC2: a listed tracked file exits 0" "$RC" 0
saysn "#90 AC2: the tracked file is not refused" "$ERR" "refused"
check "#90 AC2: the tracked file is still in the worktree" test -f "$ROOTP/$(repo_id "$S9c")/n-tracked/README.md"

echo "Issue #90 AC3 — prune removes a worktree whose only ignored state is the session log and todo"
# n-seed: the session edits the seeded log, commits its work, and the branch is merged.
N1="$ROOTP/$IDS9/n-seed"
# The session writes its log; mkdir keeps the write valid before the seed exists (the red run).
mkdir -p "$N1/apps/web/.agents"
printf 'session 2\n' >> "$N1/apps/web/.agents/session-log.md"
commit "$N1" apps/web/feature.txt "n-seed work"
git -C "$S9" merge -q --ff-only n-seed
wt "$S9" prune
check "#90 AC3: prune lists n-seed as a candidate" test -n "$(row n-seed)"
wt "$S9" prune --yes
is    "#90 AC3: prune --yes exits 0" "$RC" 0
checkn "#90 AC3: prune --yes removes n-seed (session log is junk)" test -d "$N1"
# n-todo: the same for an ignored todo file.
wt "$S9" create n-todo; N5="$OUT"
mkdir -p "$N5/apps/web/.agents"
printf 'task todo\n' >> "$N5/apps/web/.agents/todo.md"
commit "$N5" apps/web/todo-work.txt "n-todo work"
git -C "$S9" merge -q --ff-only n-todo
wt "$S9" prune --yes
is    "#90 AC3: prune --yes exits 0 with an ignored todo file" "$RC" 0
checkn "#90 AC3: prune --yes removes n-todo (todo is junk)" test -d "$N5"

echo "Issue #90 AC4 — setup copies the session log back"
wt "$S9" create n-again; N3="$OUT"
rm -f "$N3/apps/web/.agents/session-log.md"
wt "$S9" setup n-again
is    "#90 AC4: setup exits 0" "$RC" 0
check "#90 AC4: setup copies the session log back" \
      test "$(cat "$N3/apps/web/.agents/session-log.md" 2>/dev/null)" = "web log (main)"
saysn "#90 AC4: setup does not say nothing to set up" "$ERR" "nothing to set up"

echo "Issue #90 AC5 — an unignored session log is named, not copied"
S9d="$TMP/n/unignored"; new_repo "$S9d"
put "$S9d" apps/web/package.json '{}'
git -C "$S9d" add -A && git -C "$S9d" commit -qm "workspace"
put "$S9d" apps/web/.agents/session-log.md "web log (unignored)"
wt "$S9d" create n-unignored; N4="$OUT"
is    "#90 AC5: create exits 0" "$RC" 0
checkn "#90 AC5: the unignored session log is not copied" test -e "$N4/apps/web/.agents/session-log.md"
says  "#90 AC5: the refusal is named on stderr" "$ERR" "copy: not copied apps/web/.agents/session-log.md"
says  "#90 AC5: the reason is given" "$ERR" "not ignored in the new worktree"

echo "Issue #90 AC6 — a tracked session log is kept byte for byte"
S9e="$TMP/n/tracked-log"; new_repo "$S9e"
put "$S9e" apps/web/package.json '{}'; put "$S9e" apps/web/.agents/session-log.md "tracked log (main)"
git -C "$S9e" add -A && git -C "$S9e" commit -qm "tracked session log"
wt "$S9e" create n-tracked-log; N6="$OUT"
is    "#90 AC6: create exits 0" "$RC" 0
check "#90 AC6: the tracked session log is unchanged" \
      test "$(cat "$N6/apps/web/.agents/session-log.md")" = "tracked log (main)"
saysn "#90 AC6: the tracked log is not refused" "$ERR" "refused"

echo "Issue #90 review round 1 — the junk names count only in a workspace's .agents/ folder"
# A project's own ignored docs/todo.md or log/session-log.md is not scratch: remove keeps the worktree
# and names the file, as it does on main. The harness's own copies (.agents/) stay junk.
S9f="$TMP/n/own-notes"; new_repo "$S9f"
printf 'docs/todo.md\nlog/session-log.md\n' > "$S9f/.gitignore"
git -C "$S9f" add -A && git -C "$S9f" commit -qm "ignore project notes"
wt "$S9f" create r-notes; NF="$OUT"
put "$NF" docs/todo.md "my own notes"
put "$NF" log/session-log.md "project log"
commit "$NF" feature.txt "r-notes work"
git -C "$S9f" merge -q --ff-only r-notes
wt "$S9f" remove r-notes
is    "#90 review: remove refuses a project's own ignored notes" "$RC" 1
says  "#90 review: the refusal names docs/todo.md" "$ERR" "docs/todo.md"
says  "#90 review: the refusal names log/session-log.md" "$ERR" "log/session-log.md"
check "#90 review: the project's notes file survives" test -f "$NF/docs/todo.md"
check "#90 review: the worktree is still there" test -d "$NF"

# Control: a root-level .agents/todo.md (the harness's own scratch, root workspace) is still junk.
S9g="$TMP/n/root-scratch"; new_repo "$S9g"
printf '.agents/todo.md\n' > "$S9g/.gitignore"
git -C "$S9g" add -A && git -C "$S9g" commit -qm "ignore root scratch"
wt "$S9g" create r-root; NR="$OUT"
mkdir -p "$NR/.agents"; printf 'root todo\n' > "$NR/.agents/todo.md"
commit "$NR" root-work.txt "r-root work"
git -C "$S9g" merge -q --ff-only r-root
wt "$S9g" remove r-root
is    "#90 review control: remove discards the root .agents/todo.md (junk)" "$RC" 0

echo "Issue #102 AC2 — create names the agent files that differ"
# agent_line <path> - stderr has <path> as one indented line of its own.
agent_line() { printf '%s\n' "$ERR" | grep -qxF "    $1"; }
DIFFER="agent files differ from the ones committed in"
S102="$TMP/q/agents"; new_repo "$S102"; S102P="$(cd "$S102" && pwd -P)"
for f in .agents/monorepo-agents-harness/core/scripts/lib.sh .agents/skills/s/SKILL.md \
         .claude/settings.json .claude/commands/x.md .mcp.json opencode.json AGENTS.md \
         apps/web/AGENTS.md apps/web/code.js docs/notes.md .claude/commands/old.md; do
  put "$S102" "$f"
done
git -C "$S102" add -A && git -C "$S102" commit -qm "tooling"
git -C "$S102" checkout -qb same; commit "$S102" apps/web/code.js "app code only"
git -C "$S102" checkout -q main; git -C "$S102" checkout -qb agents
CHANGED=".agents/monorepo-agents-harness/core/scripts/lib.sh .agents/skills/s/SKILL.md
.agents/rules/r.md .codex/hooks.json .opencode/plugins/p.js .mcp.json opencode.json opencode.jsonc
AGENTS.md CLAUDE.md apps/web/AGENTS.md apps/web/CLAUDE.md apps/web/.claude/settings.json"
for f in $CHANGED; do put "$S102" "$f" "changed on the branch"; done
git -C "$S102" rm -q .claude/settings.json
git -C "$S102" mv .claude/commands/x.md docs/x.md
git -C "$S102" mv .claude/commands/old.md .claude/commands/new.md
git -C "$S102" add -A && git -C "$S102" commit -qm "branch tooling"
git -C "$S102" checkout -q main
ID102="$(repo_id "$S102")"; Q1="$ROOTP/$ID102/q-agents"
wt "$S102" create q-agents --branch agents
is    "#102 AC2: create exits 0 when agent files differ" "$RC" 0
is    "#102 AC2: stdout is the path alone" "$OUT" "$Q1"
says  "#102 AC2: stderr says they differ from the main checkout" "$ERR" "$DIFFER $S102P."
says  "#102 AC2: stderr names the worktree to review" "$ERR" "start an agent session in $Q1:"

echo "Issue #102 AC4 — every listed path is caught"
for f in $CHANGED; do check "#102 AC4: names $f" agent_line "$f"; done
check "#102 AC4: names a deleted file" agent_line .claude/settings.json
check "#102 AC4: names a file moved out of .claude/" agent_line .claude/commands/x.md
check "#102 AC4: a rename inside the list: the old name" agent_line .claude/commands/old.md
check "#102 AC4: a rename inside the list: the new name" agent_line .claude/commands/new.md
saysn "#102 AC4: does not name the new path outside the list" "$ERR" "docs/x.md"

echo "Issue #102 AC5 — a re-run of create says it again"
wt "$S102" create q-agents --branch agents
is    "#102 AC5: a re-run exits 0" "$RC" 0
is    "#102 AC5: a re-run prints the path" "$OUT" "$Q1"
says  "#102 AC5: a re-run has the note" "$ERR" "$DIFFER $S102P."
check "#102 AC5: a re-run names the files" agent_line AGENTS.md

echo "Issue #102 AC3 — no note when the agent files are the same"
wt "$S102" create q-same --branch same
is    "#102 AC3: create exits 0" "$RC" 0
saysn "#102 AC3: no note when only app code differs" "$ERR" "agent files"
wt "$S102" create q-new
saysn "#102 AC3: no note for a new branch" "$ERR" "agent files"
wt "$S102" create q-new
saysn "#102 AC3: no note on its re-run" "$ERR" "agent files"

echo "Issue #102 AC4 — variants: letter case, symlinks, a submodule, odd names, the caller's settings"
S102v="$TMP/q/variants"; new_repo "$S102v"; commit "$S102v" docs/notes.md "docs"
git -C "$S102v" checkout -qb variants
if fixture_dir "$S102v"; then
  mkdir -p "$S102v/apps/web"
  ln -s docs "$S102v/.claude"; ln -s docs "$S102v/.agents"; ln -s ../../docs "$S102v/apps/web/.claude"
  put "$S102v" .Codex/hooks.json; put "$S102v" x/agents.md; put "$S102v" x/Claude.md
  put "$S102v" ".Codex/$(printf 'line\nbreak').md" odd
  put "$S102v" ".Codex/$(printf '\303\247').md" odd
  git -C "$S102v" add -A
  git -C "$S102v" update-index --add --cacheinfo "160000,$(git -C "$S102v" rev-parse HEAD),.opencode"
  git -C "$S102v" commit -qm variants
fi
git -C "$S102v" checkout -qf main
git -C "$S102v" config diff.ignoreSubmodules all
git -C "$S102v" config core.quotePath false
wt "$S102v" create q-variants --branch variants
is    "#102 AC4: create exits 0 for the variants" "$RC" 0
check "#102 AC4: a case variant (.Codex/, main has no .codex/)" agent_line .Codex/hooks.json
check "#102 AC4: a symlink named .claude" agent_line .claude
check "#102 AC4: a nested symlink named .claude" agent_line apps/web/.claude
check "#102 AC4: .agents itself replaced by a symlink" agent_line .agents
check "#102 AC4: a submodule at .opencode, with diff.ignoreSubmodules=all" agent_line .opencode
check "#102 AC4: a nested agents.md in another letter case" agent_line x/agents.md
check "#102 AC4: a nested Claude.md" agent_line x/Claude.md
check "#102 AC4: a newline in a name stays quoted on one line" agent_line '".Codex/line\nbreak.md"'
check "#102 AC4: a non-ASCII name is quoted with core.quotePath=false" agent_line '".Codex/\303\247.md"'
ENVX=(GIT_LITERAL_PATHSPECS=1); wt "$S102v" create q-variants --branch variants; ENVX=()
check "#102 AC4: GIT_LITERAL_PATHSPECS=1 keeps a case variant" agent_line .Codex/hooks.json
check "#102 AC4: GIT_LITERAL_PATHSPECS=1 keeps a nested file" agent_line x/agents.md

echo "Issue #102 AC6 — a failed comparison is reported"
S102u="$TMP/q/unborn"; new_repo "$S102u"; git -C "$S102u" branch other
git -C "$S102u" checkout -q --orphan fresh
wt "$S102u" create q-unborn --branch other
is    "#102 AC6: create exits 0 with an unborn main HEAD" "$RC" 0
says  "#102 AC6: says it could not compare" "$ERR" "agent files: could not compare"
git -C "$S102" config diff.orderFile "$TMP/q/no-such-order-file"
wt "$S102" create q-agents --branch agents
git -C "$S102" config --unset diff.orderFile
is    "#102 AC6: a failed git diff keeps exit 0" "$RC" 0
says  "#102 AC6: a failed git diff is reported" "$ERR" "agent files: could not compare"

echo "Issue #102 AC7 — bare repository"
B102="$TMP/q/bare.git"; git clone -q --bare "$S102" "$B102"
OWN="$TMP/q/own"; git -C "$B102" worktree add -q "$OWN" main 2>/dev/null
OWNP="$(cd "$OWN" && pwd -P)"
wt "$OWN" create q-bare --branch agents; H102="$OUT"
is    "#102 AC7: create exits 0 from your own checkout" "$RC" 0
says  "#102 AC7: your own checkout is compared" "$ERR" "$DIFFER $OWNP."
check "#102 AC7: it names the files" agent_line AGENTS.md
wt "$H102" create q-bare2 --branch same
is    "#102 AC7: create exits 0 from a harness worktree" "$RC" 0
says  "#102 AC7: a harness worktree says not compared" "$ERR" \
      "agent files: not compared: a bare repository has no main checkout, so in a harness worktree"
saysn "#102 AC7: and does not claim a difference" "$ERR" "$DIFFER"
wt "$H102" create q-bare --branch agents
says  "#102 AC7: a re-run there says not compared" "$ERR" "agent files: not compared"

echo "Issue #102 AC8 — a long list stops at 20"
git -C "$S102" checkout -qb many
for i in $(seq -w 1 25); do put "$S102" ".claude/commands/m$i.md"; done
git -C "$S102" add -A && git -C "$S102" commit -qm many
git -C "$S102" checkout -q main; git -C "$S102" checkout -qb twenty
for i in $(seq -w 1 20); do put "$S102" ".claude/commands/t$i.md"; done
git -C "$S102" add -A && git -C "$S102" commit -qm twenty
git -C "$S102" checkout -q main
MAIN12="$(git -C "$S102" rev-parse main | cut -c1-12)"
wt "$S102" create q-many --branch many
is    "#102 AC8: exactly 20 paths are listed" "$(printf '%s\n' "$ERR" | grep -c '^    \.claude/commands/m')" 20
says  "#102 AC8: says how many more" "$ERR" "5 more not shown"
says  "#102 AC8: gives the git diff command" "$ERR" "git -C $ROOTP/$ID102/q-many diff --name-only --no-renames --ignore-submodules=none $MAIN12 HEAD"
check "#102 AC8: that command shows the 25th file" \
      sh -c "git -C '$ROOTP/$ID102/q-many' diff --name-only --no-renames --ignore-submodules=none '$MAIN12' HEAD | grep -qx .claude/commands/m25.md"
wt "$S102" create q-twenty --branch twenty
is    "#102 AC8: 20 files are all listed" "$(printf '%s\n' "$ERR" | grep -c '^    \.claude/commands/t')" 20
saysn "#102 AC8: 20 files leave nothing over" "$ERR" "more not shown"

echo "Issue #102 review — look-alike names a disk reads as a listed one"
# branch_with <repo> <branch> <name>... - a branch from main with more files (names as printf escapes),
# built in a temporary index: on a disk that folds a name, writing it would replace the file it looks like.
branch_with() {
  local r="$1" b="$2" n blob tree idx="$TMP/q/index"; shift 2
  fixture_dir "$r" || return 1
  blob="$(printf 'BRANCH\n' | git -C "$r" hash-object -w --stdin)"
  GIT_INDEX_FILE="$idx" git -C "$r" read-tree main
  for n in "$@"; do GIT_INDEX_FILE="$idx" git -C "$r" update-index --add --cacheinfo "100644,$blob,$(printf "$n")"; done
  tree="$(GIT_INDEX_FILE="$idx" git -C "$r" write-tree)"
  git -C "$r" branch "$b" "$(git -C "$r" commit-tree "$tree" -p main -m "$b")"
  rm -f "$idx"
}
S102l="$TMP/q/lookalike"; new_repo "$S102l"
for f in AGENTS.md .mcp.json .agents/monorepo-agents-harness/x.sh; do put "$S102l" "$f" main; done
git -C "$S102l" add -A && git -C "$S102l" commit -qm tooling
# U+017F (long s) reads as "s" on APFS: these replace the files main has.
branch_with "$S102l" overwrite 'AGENT\305\277.md' '.mcp.j\305\277on' \
  '.agent\305\277/monorepo-agents-harness/x.sh' 'docs/\303\247.md'
wt "$S102l" create q-overwrite --branch overwrite
is    "#102 review: create exits 0" "$RC" 0
for n in '"AGENT\305\277.md"' '".mcp.j\305\277on"' '".agent\305\277/monorepo-agents-harness/x.sh"'; do
  check "#102 review: names $n" agent_line "$n"
done
saysn "#102 review: another non-ASCII name is not listed" "$ERR" '\303\247'
# Every letter whose Unicode case folding is ASCII, then every character HFS+ ignores in a name.
FOLDS='\303\237 \305\277 \341\272\236 \342\204\252 \357\254\200 \357\254\201 \357\254\202 \357\254\203
\357\254\204 \357\254\205 \357\254\206'
IGNORED='\342\200\214 \342\200\215 \342\200\216 \342\200\217 \342\200\252 \342\200\253 \342\200\254
\342\200\255 \342\200\256 \342\201\252 \342\201\253 \342\201\254 \342\201\255 \342\201\256 \342\201\257
\357\273\277'
names=(); for e in $FOLDS; do names[${#names[@]}]="w${e}x"; done
branch_with "$S102l" folds "${names[@]}"
wt "$S102l" create q-folds --branch folds
for e in $FOLDS; do check "#102 review: a folding letter $e is listed" agent_line "\"w${e}x\""; done
names=(); for e in $IGNORED; do names[${#names[@]}]="h${e}x/f"; done
branch_with "$S102l" ignored "${names[@]}"
wt "$S102l" create q-ignored --branch ignored
for e in $IGNORED; do check "#102 review: an ignored character $e is listed (in a folder name)" agent_line "\"h${e}x/f\""; done

echo "Issue #102 review — AGENTS.override.md and CLAUDE.local.md"
branch_with "$S102l" locals AGENTS.override.md CLAUDE.local.md apps/web/agents.override.md apps/web/Claude.local.md
wt "$S102l" create q-locals --branch locals
for n in AGENTS.override.md CLAUDE.local.md apps/web/agents.override.md apps/web/Claude.local.md; do
  check "#102 review: names $n" agent_line "$n"
done

echo "Issue #102 review — the caller's GIT_DIR does not silence the note"
ENVX=(GIT_DIR="$S102P/.git"); wt "$S102" create q-agents --branch agents; ENVX=()
is    "#102 review: a re-run with GIT_DIR exits 0" "$RC" 0
check "#102 review: GIT_DIR on a re-run" agent_line AGENTS.md
git -C "$S102" branch agents-copy agents
ENVX=(GIT_DIR="$S102P/.git"); wt "$S102" create q-gitdir --branch agents-copy; ENVX=()
is    "#102 review: create with GIT_DIR exits 0" "$RC" 0
check "#102 review: GIT_DIR on a new worktree" agent_line AGENTS.md
ENVX=(GIT_DIR="$S102P/.git"); wt "$S102" create q-same --branch same; ENVX=()
saysn "#102 review: GIT_DIR adds no note for the same agent files" "$ERR" "agent files"
# A shell alias run in a linked checkout exports that checkout's GIT_DIR.
git -C "$S102" worktree add -q -b mine "$TMP/q/mine" main
ENVX=(GIT_DIR="$S102P/.git/worktrees/mine"); wt "$TMP/q/mine" create q-agents --branch agents; ENVX=()
says  "#102 review: a linked checkout's GIT_DIR still compares with the main checkout" "$ERR" "$DIFFER $S102P."
check "#102 review: and names the files" agent_line AGENTS.md

# --- Issue #104: the caller's git repository variables never decide what the script reads -----
# git sets GIT_DIR for a hook and for a shell alias run in a linked worktree, and it beats
# `git -C <dir>`. `mine` is such a checkout, one commit behind main. `tracks` is a checkout whose
# branch tracks two files that main ignores.
S104="$TMP/r/env"; new_repo "$S104"; S104P="$(cd "$S104" && pwd -P)"
printf 'local.cfg\nshared.cfg\n' > "$S104/.gitignore"; git -C "$S104" add -A && git -C "$S104" commit -qm ignores
git -C "$S104" branch other-tree
commit "$S104" next.txt next
git -C "$S104" worktree add -q -b older "$TMP/r/mine" main~1
git -C "$S104" worktree add -q -b tracks "$TMP/r/tracks" main
put "$TMP/r/tracks" local.cfg KEY=1; put "$TMP/r/tracks" shared.cfg KEY=2
git -C "$TMP/r/tracks" add -f local.cfg shared.cfg && git -C "$TMP/r/tracks" commit -qm tracked
TRACKS_GIT="$S104P/.git/worktrees/tracks"
# alias_wt <dir> [git options...] -- <args...> - worktree.sh through a git shell alias run in <dir>.
alias_wt() {
  local d="$1" opts=(); shift
  while [ "$1" != -- ]; do opts[${#opts[@]}]="$1"; shift; done; shift
  OUT="$(git -C "$d" ${opts[@]+"${opts[@]}"} -c "alias.wt=!bash '$WT'" wt "$@" 2>"$TMP/.err")"; RC=$?
  ERR="$(cat "$TMP/.err")"
}

echo "Issue #104 AC1 — a shell alias in a linked checkout records the new worktree's HEAD"
alias_wt "$TMP/r/mine" -- create fresh
FRESH="$OUT"
is    "#104 AC1: create exits 0" "$RC" 0
is    "#104 AC1: the start commit is the new worktree's HEAD" \
      "$(git -C "$S104" config --get branch.fresh.harnessStart)" "$(git -C "$S104" rev-parse main)"
wt "$S104" prune
is    "#104 AC1: prune does not list it" "$(row fresh)" ""
wt "$S104" prune --yes
check "#104 AC1: prune --yes keeps it" test -d "$FRESH"
ENVX=(GIT_CONFIG="$TMP/r/other-config"); wt "$S104" create cfg; ENVX=()
is    "#104 AC1: with GIT_CONFIG set, create exits 0" "$RC" 0
is    "#104 AC1: and the start commit is in the repository config" \
      "$(git -C "$S104" config --get branch.cfg.harnessStart)" "$(git -C "$S104" rev-parse main)"
check "#104 AC1: nothing is written to the GIT_CONFIG file" test ! -e "$TMP/r/other-config"

echo "Issue #104 AC2 — remove with GIT_DIR sees a bisect in progress"
P="$(mkwt "$S104" e-bisect)"; git -C "$P" bisect start >/dev/null 2>&1
ENVX=(GIT_DIR="$S104P/.git"); wt "$S104" remove e-bisect; ENVX=()
is    "#104 AC2: remove refuses" "$RC" 1
says  "#104 AC2: names the bisect" "$ERR" "a bisect in progress"
check "#104 AC2: the worktree stays" test -d "$P"

echo "Issue #104 AC3 — remove with GIT_DIR sees an ignored file the caller's checkout tracks"
P="$(mkwt "$S104" e-ign)"; put "$P" local.cfg KEY=1; put "$P" shared.cfg KEY=2
ENVX=(GIT_DIR="$TRACKS_GIT"); wt "$S104" remove e-ign; ENVX=()
is    "#104 AC3: remove refuses" "$RC" 1
says  "#104 AC3: names the file" "$ERR" "local.cfg"
check "#104 AC3: the file stays" test -f "$P/local.cfg"

echo "Issue #104 AC4 — list with GIT_DIR reads the worktree itself"
P="$(mkwt "$S104" e-clean)"
ENVX=(GIT_DIR="$TRACKS_GIT"); wt "$S104" list; ENVX=()
is    "#104 AC4: a clean worktree reads clean" "$(field "$(row e-clean)" 4)" clean

echo "Issue #104 AC5 — the copy step with GIT_DIR"
put "$S104" shared.cfg KEY=2; put "$S104" .agents/worktree-copy.txt shared.cfg
ENVX=(GIT_DIR="$TRACKS_GIT"); wt "$S104" create e-copy; ENVX=()
is    "#104 AC5: create exits 0" "$RC" 0
check "#104 AC5: the ignored file is copied" test -f "$ROOTP/$(repo_id "$S104")/e-copy/shared.cfg"
rm -f "$S104/.agents/worktree-copy.txt"

echo "Issue #104 AC6 — the setup script's environment"
cat > "$S104/.agents/worktree-setup.sh" <<EOF
#!/bin/sh
printf '%s\n' "\${GIT_DIR:-unset}" > "$TMP/r/setup-env"
git rev-parse --absolute-git-dir > "$TMP/r/setup-gitdir"
EOF
chmod +x "$S104/.agents/worktree-setup.sh"
ENVX=(GIT_DIR="$S104P/.git"); wt "$S104" create e-setup --setup; ENVX=()
is    "#104 AC6: create --setup exits 0" "$RC" 0
is    "#104 AC6: the setup script sees no GIT_DIR" "$(cat "$TMP/r/setup-env" 2>/dev/null)" unset
is    "#104 AC6: its git commands answer for the new worktree" \
      "$(cat "$TMP/r/setup-gitdir" 2>/dev/null)" "$(git -C "$OUT" rev-parse --absolute-git-dir)"
rm -f "$S104/.agents/worktree-setup.sh"

echo "Issue #104 AC7 — create with GIT_INDEX_FILE leaves that index alone"
cp "$S104/.git/index" "$TMP/r/hook-index"; before="$(cksum < "$TMP/r/hook-index")"
ENVX=(GIT_INDEX_FILE="$TMP/r/hook-index"); wt "$S104" create e-index --branch other-tree; ENVX=()
is    "#104 AC7: create exits 0" "$RC" 0
is    "#104 AC7: the caller's index is unchanged" "$(cksum < "$TMP/r/hook-index")" "$before"
is    "#104 AC7: the new worktree is clean" "$(git -C "$OUT" status --porcelain)" ""

echo "Issue #104 AC8 — git -c settings still apply (guard)"
for r in a b; do
  git init -q --bare "$TMP/r/remote-$r.git"; git -C "$S104" remote add "$r" "$TMP/r/remote-$r.git"
  git -C "$S104" push -q "$r" main:refs/heads/two main:refs/heads/two-alias 2>/dev/null
  git -C "$S104" fetch -q "$r" 2>/dev/null
done
ENVX=(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=checkout.defaultRemote GIT_CONFIG_VALUE_0=b)
wt "$S104" create e-two --branch two; ENVX=()
is    "#104 AC8: GIT_CONFIG_COUNT still applies: exits 0" "$RC" 0
is    "#104 AC8: and picks that remote" "$(git -C "$S104" config --get branch.two.remote)" b
alias_wt "$S104" -c checkout.defaultRemote=b -- create e-two-alias --branch two-alias
is    "#104 AC8: git -c through an alias still applies: exits 0" "$RC" 0
is    "#104 AC8: and picks that remote" "$(git -C "$S104" config --get branch.two-alias.remote)" b

echo "Issue #104 — a repository reachable only through GIT_DIR"
ENVX=(GIT_DIR="$S104P/.git"); wt "$TMP/norepo" path x; ENVX=()
is    "#104: is an environment error" "$RC" 3

echo "Issue #104 review — the setup script keeps the caller's own variables"
cat > "$S104/.agents/worktree-setup.sh" <<EOF
#!/bin/sh
printf 'v=%s c=%s\n' "\${v-unset}" "\${c-unset}" > "$TMP/r/setup-vars"
EOF
chmod +x "$S104/.agents/worktree-setup.sh"
ENVX=(v=1.2.3 c=keep); wt "$S104" create e-vars --setup; ENVX=()
is    "#104 review: create --setup exits 0" "$RC" 0
is    "#104 review: v and c reach the setup script" "$(cat "$TMP/r/setup-vars" 2>/dev/null)" "v=1.2.3 c=keep"
rm -f "$S104/.agents/worktree-setup.sh"

# BSD grep still reads GREP_OPTIONS, so the cleanup must not pass the names through grep.
echo "Issue #104 review — GREP_OPTIONS does not switch the cleanup off (guard)"
ENVX=(GREP_OPTIONS=-n GIT_DIR="$S104P/.git"); wt "$TMP/norepo" path x; ENVX=()
is    "#104 review: GIT_DIR is still dropped" "$RC" 3

echo "Issue #104 review — a GIT_DIR naming another repository is ignored (guard)"
ENVX=(GIT_DIR="$R1P/.git"); wt "$S104" path x; ENVX=()
is    "#104 review: path answers for the current folder's repository" \
      "$OUT" "$ROOTP/$(repo_id "$S104")/x"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
