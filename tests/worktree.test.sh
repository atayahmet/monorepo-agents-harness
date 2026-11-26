#!/usr/bin/env bash
# Tests for worktree.sh — one adapter-neutral root for the worktrees the harness creates, and the
# path / create / list / remove / prune contract (issue #85). One section per acceptance criterion
# in the task spec (AC1–AC11).
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
wt "$R1" create mainline --branch main
is   "a branch checked out in the main worktree: exits 0" "$RC" 0
is   "a branch checked out in the main worktree prints that path" "$OUT" "$R1P"
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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
