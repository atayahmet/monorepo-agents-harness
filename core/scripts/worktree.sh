#!/usr/bin/env bash
# worktree — one adapter-neutral root for the git worktrees the harness creates (issue #85).
# Agent-agnostic: `/monorepo-harness-worktree` on every adapter only calls this script.
#
# Every harness worktree lives outside the repository, at
#   ${HARNESS_WORKTREE_ROOT:-$HOME/.harness-worktrees}/<repo-id>/<slug>
# <repo-id> is <name>-<hash8> of the repo's common git dir, so it is the same from every worktree.
# HARNESS_WORKTREE_ROOT exists only for CI and containers where $HOME does not work: it must be an
# absolute path, and a root inside the repository is refused. Docs: docs/worktrees.md.
#
# Subcommands (run from anywhere inside the project's git repo):
#   path <slug>                                  print the path; writes nothing
#   create <slug> [--base <ref>] [--branch <b>] [--setup]
#                                                add the worktree and print its path (new branch from
#                                                --base or the default branch, or an existing branch),
#                                                then copy the files .agents/worktree-copy.txt lists;
#                                                --setup also runs .agents/worktree-setup.sh there
#   setup <slug>                                 run the copy and setup steps again in a harness
#                                                worktree and print its path
#   list [--all]                                 table: kind slug branch state merged last_commit path
#                                                (--all adds the worktrees the harness did not create)
#   remove <slug> [--delete-branch] [--force]    remove one harness worktree after the safety checks
#   prune [--yes]                                dry run by default: the clean+merged or missing
#                                                harness worktrees; --yes removes them
#
# Project-owned files (optional; the harness reads them and never writes them):
#   .agents/worktree-copy.txt  ignored files to copy from the main checkout into a new worktree, one
#                              repo-relative path or glob per line (read from the main checkout)
#   .agents/worktree-setup.sh  an executable run in the new worktree, only on --setup or setup, with
#                              HARNESS_WORKTREE_MAIN, HARNESS_WORKTREE_PATH, HARNESS_WORKTREE_BRANCH
#                              set and stdin from /dev/null (read from the main checkout)
#   .agents/worktree-junk.txt  extra junk-list entries for remove and prune (read from the main
#                              checkout)
#
# stdout carries only the result (a path or a table); notes, refusals and everything the setup
# script prints go to stderr. Needs git >= 2.17 and coreutils. Never fetches or pushes.
#
# Exit codes: 0 done, 1 refused (reason printed), 2 bad call, 3 environment (not inside a git work
# tree, HOME unset, root not writable, root inside the repository), 4 the worktree exists but the
# copy or setup step failed (create and setup still print its path).
set -uo pipefail
# The caller's locale and lock settings, given back to the project's setup script: it runs the
# project's own tools, not this script's parsing.
CALLER_LC_ALL="${LC_ALL-}"; CALLER_LC_ALL_SET="${LC_ALL+1}"
CALLER_GOL="${GIT_OPTIONAL_LOCKS-}"; CALLER_GOL_SET="${GIT_OPTIONAL_LOCKS+1}"
# GIT_OPTIONAL_LOCKS=0: `git status` never takes index.lock, so a scan cannot make a concurrent
# git command in that worktree fail.
export LC_ALL=C GIT_OPTIONAL_LOCKS=0

COPY_LIST=.agents/worktree-copy.txt
SETUP_SCRIPT=.agents/worktree-setup.sh
JUNK_LIST=.agents/worktree-junk.txt

# Ignored files that can be rebuilt, so `remove` may lose them (docs/worktrees.md, "Junk list"). An
# entry matches the name of the ignored file or directory itself (`*`, `?`, `[` are globs), never a
# folder above it. A project adds entries in the main checkout's .agents/worktree-junk.txt.
# `.index.sqlite*` is the harness's own derived cache (kb-index.sh).
JUNK_DEFAULT='node_modules dist build out .turbo .next .nuxt .svelte-kit .output .vercel .cache
.parcel-cache coverage .nyc_output target __pycache__ .pytest_cache .mypy_cache .ruff_cache .venv
.gradle .eslintcache .DS_Store *.tsbuildinfo *.pyc *.log .index.sqlite*'

usage() { awk 'NR == 1 { next } /^#/ { print; next } { exit }' "$0"; }
note()  { printf 'worktree: %s\n' "$*" >&2; }
# die <code> <message> - print the reason on stderr and exit with <code> (1, 2 or 3).
die()   { local c="$1"; shift; note "$*"; exit "$c"; }

# phys <abs-path> - the physical path. Symlinks and `..` are resolved through every directory that
# exists; the part that does not exist yet is appended as written (without `.` and `..`).
phys() {
  local p="$1" r part cur="" IFS=/
  if [ -d "$p" ] && r="$(cd -P -- "$p" 2>/dev/null && pwd -P)"; then printf '%s' "$r"; return; fi
  set -f
  for part in $p; do
    case "$part" in
      ""|.) continue ;;
      ..)   cur="${cur%/*}"; continue ;;
    esac
    if [ -d "$cur/$part" ] && r="$(cd -P -- "$cur/$part" 2>/dev/null && pwd -P)"; then
      [ "$r" = / ] && r=""
      cur="$r"
    else
      cur="$cur/$part"
    fi
  done
  set +f
  printf '%s' "${cur:-/}"
}

check_slug() {
  case "$1" in
    "") die 2 "$CMD needs a <slug>" ;;
    .|..|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*)
      die 2 "invalid slug '$1': use letters, digits, '.', '_' and '-', starting with a letter or digit" ;;
  esac
  [ "${#1}" -le 64 ] || die 2 "invalid slug '$1': at most 64 characters"
}

check_branch() {
  local out
  out="$(git check-ref-format --branch "$1" 2>/dev/null)" && [ "$out" = "$1" ] \
    || die 2 "invalid branch name: '$1'"
}

# load_repo - TOP (this checkout), COMMON (the shared git dir), REPO_ID and the worktree table.
load_repo() {
  local c name
  TOP="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$TOP" ] \
    || die 3 "not inside a git work tree: run this from the project's repository (the main checkout or one of its worktrees)"
  c="$(git -C "$TOP" rev-parse --git-common-dir 2>/dev/null)" || die 3 "cannot read the git common dir"
  case "$c" in /*) ;; *) c="$TOP/$c" ;; esac
  COMMON="$(cd -P -- "$c" 2>/dev/null && pwd -P)" || die 3 "cannot read the git common dir: $c"
  TOP="$(phys "$TOP")"
  case "$COMMON" in
    */.git) name="${COMMON%/.git}"; name="${name##*/}" ;;
    *)      name="${COMMON##*/}"; name="${name%.git}" ;;
  esac
  name="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')"
  [ -n "$name" ] || name=repo
  REPO_ID="$name-$(printf '%s' "$COMMON" | git hash-object --stdin | cut -c1-8)"
  load_worktrees
  # MAIN: the main checkout. The project's copy list, setup script and junk list are read there and
  # the copy list copies from there, whatever branch a worktree is on. A bare repository has no main
  # checkout: the checkout this script runs in stands in.
  if [ "${WT_BARE[0]:-0}" = 1 ]; then MAIN="$TOP"; else MAIN="${WT_PHYS[0]}"; fi
}

# load_worktrees - parse `git worktree list --porcelain` into parallel arrays. Index 0 is the main
# worktree (or the bare repository).
load_worktrees() {
  local line list i=-1
  list="$(git -C "$TOP" worktree list --porcelain 2>/dev/null)" || die 3 "cannot read git worktree list"
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        i=$((i+1))
        WT_PATH[i]="${line#worktree }"; WT_HEAD[i]=""; WT_BRANCH[i]=""; WT_LOCKED[i]=0; WT_BARE[i]=0 ;;
      "HEAD "*)          WT_HEAD[i]="${line#HEAD }" ;;
      "branch "*)        WT_BRANCH[i]="${line#branch refs/heads/}" ;;
      locked|"locked "*) WT_LOCKED[i]=1 ;;
      bare)              WT_BARE[i]=1 ;;
    esac
  done <<EOF
$list
EOF
  WT_N=$((i+1))
  i=0
  while [ "$i" -lt "$WT_N" ]; do WT_PHYS[i]="$(phys "${WT_PATH[i]}")"; i=$((i+1)); done
}

# resolve_root - ROOT and BASE_DIR (<root>/<repo-id>), both physical. Refuses a root inside any
# worktree of this repository: there is no in-repo mode (docs/worktrees.md, "Why not inside the
# repository").
resolve_root() {
  local r i d
  if [ -n "${HARNESS_WORKTREE_ROOT:-}" ]; then
    r="$HARNESS_WORKTREE_ROOT"
    case "$r" in /*) ;; *) die 2 "HARNESS_WORKTREE_ROOT must be an absolute path, got: $r" ;; esac
  else
    case "${HOME:-}" in
      /*) r="$HOME/.harness-worktrees" ;;
      *)  die 3 "HOME is not set: set HARNESS_WORKTREE_ROOT to an absolute, writable, persistent directory outside the repository" ;;
    esac
  fi
  ROOT="$(phys "$r")"
  BASE_DIR="$(phys "${ROOT%/}/$REPO_ID")"
  i=0
  while [ "$i" -lt "$WT_N" ]; do
    if [ "${WT_BARE[i]}" = 0 ]; then
      for d in "$ROOT" "$BASE_DIR"; do
        case "$d/" in
          "${WT_PHYS[i]}"/*)
            die 3 "the worktree root must be outside the repository: $d is inside ${WT_PHYS[i]} (HARNESS_WORKTREE_ROOT is only for CI and containers where \$HOME does not work)" ;;
        esac
      done
    fi
    i=$((i+1))
  done
}

# default_branch - origin/HEAD, then main, then master (the order forge.sh uses). Bare name.
default_branch() {
  local ref b
  ref="$(git -C "$TOP" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ]; then printf '%s' "${ref#origin/}"; return 0; fi
  for b in main master; do
    if git -C "$TOP" rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1 \
       || git -C "$TOP" rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null 2>&1; then
      printf '%s' "$b"; return 0
    fi
  done
  return 1
}

# base_refs <base> - BASE_REFS: the refs a base stands for, best first. A full ref is itself; a bare
# branch name is the local branch, then origin's. Never the short name itself: git resolves a
# same-name tag before the branch.
base_refs() {
  case "$1" in
    refs/*) BASE_REFS=("$1") ;;
    *)      BASE_REFS=("refs/heads/$1" "refs/remotes/origin/$1") ;;
  esac
}

# base_of <branch> - branch.<b>.harnessBase while one of its refs resolves, else the default branch.
# A stacked branch whose base was merged and deleted falls back to the default branch.
base_of() {
  local v="" c
  [ -n "$1" ] && v="$(git -C "$TOP" config --get "branch.$1.harnessBase" 2>/dev/null)"
  if [ -n "$v" ]; then
    base_refs "$v"
    for c in "${BASE_REFS[@]}"; do
      git -C "$TOP" rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 && { printf '%s' "$v"; return 0; }
    done
  fi
  default_branch
}

# short_ref <ref> - a ref for messages: refs/heads/ and refs/remotes/ dropped.
short_ref() { local r="${1#refs/heads/}"; printf '%s' "${r#refs/remotes/}"; }

# merged_state <tip> <base> [<branch>] - sets MERGED (merged | unmerged | unknown), MERGE_CAND (the
# first base ref that exists) and MERGE_NOTE (why it is unknown). Merged = the tip is an ancestor of
# the base's local or origin branch, or `git cherry` finds every commit there by patch-id. A branch
# is never measured against itself (`create --branch main`: the base is main too). Unsure means not
# merged (docs/worktrees.md, "Merged rule").
merged_state() {
  local tip="$1" base="$2" branch="${3:-}" c out m
  MERGED=unknown; MERGE_CAND=""; MERGE_NOTE=""
  [ -n "$base" ] && [ -n "$tip" ] || return 0
  base_refs "$base"
  for c in "${BASE_REFS[@]}"; do
    if [ -n "$branch" ] && [ "$c" = "refs/heads/$branch" ]; then
      MERGE_NOTE="the branch is its own base (branch.<b>.harnessBase or the default branch)"; return 0
    fi
    git -C "$TOP" rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 || continue
    MERGED=unmerged; [ -n "$MERGE_CAND" ] || MERGE_CAND="$c"
    if git -C "$TOP" merge-base --is-ancestor "$tip" "$c" 2>/dev/null; then MERGED=merged; return 0; fi
    # git cherry skips merge commits, so a merge with a change of its own would read merged: the
    # patch-id rule applies only to a branch with no merge commit of its own.
    m="$(git -C "$TOP" rev-list --merges "$c..$tip" 2>/dev/null)" || m=unreadable
    if [ -z "$m" ] && out="$(git -C "$TOP" cherry "$c" "$tip" 2>/dev/null)" \
       && ! printf '%s\n' "$out" | grep -q '^+'; then
      MERGED=merged; return 0
    fi
  done
  return 0
}

# row_of <i> - the list columns for worktree i: R_KIND R_SLUG R_BRANCH R_STATE R_MERGED R_DATE
# R_PATH, plus R_STATUS (git status --porcelain lines of a present worktree).
row_of() {
  local i="$1" s
  R_PATH="${WT_PHYS[i]}"
  if [ "${R_PATH%/*}" = "$BASE_DIR" ]; then R_KIND=harness; R_SLUG="${R_PATH##*/}"
  else R_KIND=external; R_SLUG=-; fi
  R_BRANCH="${WT_BRANCH[i]:-(detached)}"
  R_STATUS=""
  if [ ! -d "$R_PATH" ]; then
    R_STATE=missing
  elif s="$(git -C "$R_PATH" status --porcelain --untracked-files=normal 2>&1)"; then
    R_STATUS="$s"
    if [ -n "$s" ]; then R_STATE=dirty; else R_STATE=clean; fi
  else
    R_STATUS="cannot read git status: $s"; R_STATE=dirty
  fi
  merged_state "${WT_HEAD[i]}" "$(base_of "${WT_BRANCH[i]}")" "${WT_BRANCH[i]}"
  R_MERGED="$MERGED"
  R_DATE="$(git -C "$TOP" log -1 --format=%cd --date=short "${WT_HEAD[i]}" 2>/dev/null)"
  R_DATE="${R_DATE:--}"
}

print_header() { printf 'kind\tslug\tbranch\tstate\tmerged\tlast_commit\tpath\n'; }
print_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$R_KIND" "$R_SLUG" "$R_BRANCH" "$R_STATE" "$R_MERGED" "$R_DATE" "$R_PATH"
}

# read_list <file> - LIST: the entries of a project list file, one per line, with blank lines and
# `#` comments skipped and surrounding whitespace trimmed; LIST_LINE: each entry's line number.
# A missing file is an empty list.
read_list() {
  local line n=0
  LIST=(); LIST_LINE=()
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n+1))
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    case "$line" in ""|"#"*) continue ;; esac
    LIST[${#LIST[@]}]="$line"; LIST_LINE[${#LIST_LINE[@]}]="$n"
  done < "$1"
}

# load_junk - the default junk list plus the main checkout's .agents/worktree-junk.txt (read-only).
# The list decides what remove may delete without --force, so a branch never extends it: run from
# another checkout, that checkout's own copy is only compared (regular files only: cmp blocks on a
# FIFO), and a difference is a note. A bare repository has no main checkout and the current one
# stands in, except a harness worktree (where an unreviewed branch lands): there only the default
# list applies. Needs load_repo and resolve_root.
load_junk() {
  local e i=0
  JUNK=()
  set -f
  for e in $JUNK_DEFAULT; do JUNK[${#JUNK[@]}]="$e"; done
  set +f
  if [ "${WT_BARE[0]:-0}" = 1 ] && [ "${TOP%/*}" = "$BASE_DIR" ]; then
    note "junk list: a bare repository has no main checkout, so in a harness worktree only the default list applies (run from another checkout to use the project's $JUNK_LIST)"
    return 0
  fi
  if [ "$TOP" != "$MAIN" ] && [ -f "$TOP/$JUNK_LIST" ] \
     && { [ ! -f "$MAIN/$JUNK_LIST" ] || ! cmp -s "$MAIN/$JUNK_LIST" "$TOP/$JUNK_LIST"; }; then
    note "junk list: this checkout's own $JUNK_LIST differs; the main checkout's list is used"
  fi
  read_list "$MAIN/$JUNK_LIST"
  while [ "$i" -lt "${#LIST[@]}" ]; do JUNK[${#JUNK[@]}]="${LIST[i]%/}"; i=$((i+1)); done
}

# is_junk <path> - true when an ignored entry is rebuildable output. Only the entry's own name
# counts: an ignored key inside a tracked build/ folder is not junk because of build/.
is_junk() {
  local base="${1%/}" e
  base="${base##*/}"
  for e in "${JUNK[@]}"; do
    case "$base" in $e) return 0 ;; esac
  done
  return 1
}

# in_main <dir> <entry> - true when an ignored entry of worktree <dir> is a regular file (not a
# symlink) that the main checkout has byte for byte at the same path: the main checkout still has
# it, so removing the worktree loses nothing (a copied .env). A directory entry never counts.
in_main() {
  local a="$1/$2" b="$MAIN/$2"
  [ "$1" != "$MAIN" ] || return 1
  case "$2" in */) return 1 ;; esac
  [ -f "$a" ] && [ ! -L "$a" ] && [ -f "$b" ] && [ ! -L "$b" ] && cmp -s "$a" "$b"
}

# nonjunk_ignored <dir> - the ignored files and directories outside the junk list, one per line,
# without the ones the main checkout has byte for byte (in_main).
# --untracked-files=normal overrides status.showUntrackedFiles=no, which hides them (and makes
# --ignored=matching fail). A failed git status is reported as a finding, never read as "none".
nonjunk_ignored() {
  local e
  while IFS= read -r -d '' e; do
    case "$e" in
      '!! '*) e="${e#!! }"; is_junk "$e" || in_main "$1" "$e" || printf '%s\n' "$e" ;;
      'rc '*) [ "$e" = 'rc 0' ] || printf '%s\n' "(cannot list the ignored files: git status failed)" ;;
    esac
  done < <(git -C "$1" status --porcelain -z --ignored=matching --untracked-files=normal 2>/dev/null
           printf 'rc %s\0' "$?")
}

# assess <i> - row_of plus the removal findings:
#   A_HARD  a reason nothing skips (locked, current directory inside), or empty
#   A_DIRTY the git status lines of a present worktree
#   A_IGN   ignored files outside the junk list
#   A_UNM   the commits not in the base (or why that is unknown); empty when merged. A missing
#           worktree on a branch loses no commit (the branch stays), so it is only checked when
#           detached.
#   A_OP    a git operation stopped in it (rebase, merge, cherry-pick, revert, bisect), or empty
assess() {
  local i="$1" cwd
  row_of "$i"
  A_HARD=""; A_DIRTY="$R_STATUS"; A_IGN=""; A_UNM=""; A_OP=""
  cwd="$(pwd -P)"
  case "$cwd/" in "$R_PATH"/*) A_HARD="the current directory is inside it: run this from another checkout" ;; esac
  [ "${WT_LOCKED[i]}" = 1 ] && A_HARD="it is locked (unlocking it with 'git worktree unlock' is your call)"
  if [ "$R_STATE" != missing ]; then
    A_IGN="$(nonjunk_ignored "$R_PATH")"
    A_OP="$(op_in_progress "$R_PATH")"
  fi
  if [ "$R_MERGED" != merged ] && { [ "$R_STATE" != missing ] || [ -z "${WT_BRANCH[i]}" ]; }; then
    if [ "$R_MERGED" = unknown ]; then
      A_UNM="cannot tell whether its commits are merged: ${MERGE_NOTE:-no base resolves (branch.<b>.harnessBase, origin/HEAD, main, master)}"
    else
      A_UNM="$(git -C "$TOP" cherry -v "$MERGE_CAND" "${WT_HEAD[i]}" 2>/dev/null | grep '^+')"
      [ -n "$A_UNM" ] \
        || A_UNM="$(git -C "$TOP" log --merges --format='+ %h %s' "$MERGE_CAND..${WT_HEAD[i]}" 2>/dev/null)"
      [ -n "$A_UNM" ] || A_UNM="commits not in $(short_ref "$MERGE_CAND")"
    fi
  fi
}

# op_in_progress <dir> - the git operation stopped in a worktree ("a rebase", "a merge", ...), or
# nothing. A rebase stopped at `break` or a bisect leaves the tree clean (the rebase also detached),
# so only the state files in the worktree's git dir show that someone is in the middle of it.
op_in_progress() {
  local out f
  out="$(git -C "$1" rev-parse --git-path rebase-merge --git-path rebase-apply --git-path MERGE_HEAD \
         --git-path CHERRY_PICK_HEAD --git-path REVERT_HEAD --git-path BISECT_LOG 2>/dev/null)" || return 0
  while IFS= read -r f; do
    case "$f" in /*) ;; *) f="$1/$f" ;; esac
    [ -e "$f" ] || continue
    case "${f##*/}" in
      rebase-merge|rebase-apply) printf 'a rebase' ;;
      MERGE_HEAD)       printf 'a merge' ;;
      CHERRY_PICK_HEAD) printf 'a cherry-pick' ;;
      REVERT_HEAD)      printf 'a revert' ;;
      BISECT_LOG)       printf 'a bisect' ;;
    esac
    return 0
  done <<EOF
$out
EOF
}

# checked_out <branch> - the index of the worktree that has <branch> checked out, or nothing.
checked_out() {
  local i=0
  while [ "$i" -lt "$WT_N" ]; do
    [ "${WT_BRANCH[i]}" = "$1" ] && { printf '%s' "$i"; return 0; }
    i=$((i+1))
  done
  return 1
}

# harness_index <slug> - the worktree index registered at <root>/<repo-id>/<slug>, or nothing.
harness_index() {
  local i=1
  while [ "$i" -lt "$WT_N" ]; do
    [ "${WT_PHYS[i]}" = "$BASE_DIR/$1" ] && { printf '%s' "$i"; return 0; }
    i=$((i+1))
  done
  return 1
}

# drop <path> - git worktree remove [--force] <path>; a missing worktree is dropped per path, never
# with a global `git worktree prune` (that would also drop the records of external worktrees).
drop() {
  local p="$1" force="${2:-}"
  if [ -d "$p" ]; then
    git -C "$TOP" worktree remove ${force:+--force} "$p" >&2 && return 0
    note "git worktree remove failed for $p (see above)"
    return 1
  fi
  git -C "$TOP" worktree remove "$p" >&2 2>&1 && return 0
  note "this git cannot drop the record of the missing worktree $p; drop it by hand with 'git worktree prune' (that also drops the records of every other missing worktree)"
  return 1
}

indent() { printf '%s\n' "$1" | sed 's/^/    /' >&2; }

# --- The post-create steps (issue #88; docs/worktrees.md, "After create") ---------------------

# lower <text> - ASCII lower case. `.git` is matched in any letter case: on a case-insensitive
# filesystem (the macOS default) `.GIT/config` is the git dir's config.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# load_copy_list - COPY / COPY_LINE: the main checkout's copy list, a leading ./ dropped. An entry
# that leaves the repository (absolute, a .. component) or names .git (any letter case) is refused
# here, before anything changes: exit 1.
load_copy_list() {
  local i=0 e
  read_list "$MAIN/$COPY_LIST"
  COPY=(); COPY_LINE=()
  while [ "$i" -lt "${#LIST[@]}" ]; do
    e="${LIST[i]}"
    while [ "${e#./}" != "$e" ]; do e="${e#./}"; done
    case "$e" in
      "")  die 1 "refused: $COPY_LIST line ${LIST_LINE[i]}: '${LIST[i]}' names no file; nothing created" ;;
      /*)  die 1 "refused: $COPY_LIST line ${LIST_LINE[i]}: $e leaves the repository (absolute path); nothing created" ;;
    esac
    case "/$e/" in
      */../*) die 1 "refused: $COPY_LIST line ${LIST_LINE[i]}: $e leaves the repository (a .. component); nothing created" ;;
    esac
    case "/$(lower "$e")/" in
      */.git/*) die 1 "refused: $COPY_LIST line ${LIST_LINE[i]}: $e names .git; nothing created" ;;
    esac
    COPY[${#COPY[@]}]="$e"; COPY_LINE[${#COPY_LINE[@]}]="${LIST_LINE[i]}"
    i=$((i+1))
  done
}

# copy_matches <pattern> - the paths under the main checkout that a copy-list entry names, relative
# and NUL-separated: shell globbing (no dotglob, no globstar) with no word splitting. A pattern that
# matches nothing comes back as itself and fails the -e / -L test.
copy_matches() {
  ( cd "$MAIN" 2>/dev/null || exit 0
    set +f; shopt -u dotglob nullglob failglob 2>/dev/null; IFS=
    for m in $1; do
      if [ -e "$m" ] || [ -L "$m" ]; then printf '%s\0' "$m"; fi
    done )
}

# copy_step <worktree> - copy every copy-list match from the main checkout to the same path in
# <worktree> with cp -p. Only ignored regular files are copied; an existing destination is never
# overwritten. A refusal or a failed copy sets POST_FAIL=1; the other entries still run.
copy_step() {
  local wt="$1" i=0 e rel src dst d r n why
  if [ -f "$wt/$COPY_LIST" ] && ! cmp -s "$MAIN/$COPY_LIST" "$wt/$COPY_LIST"; then
    note "copy: this worktree's own $COPY_LIST differs; the main checkout's list is used"
  fi
  while [ "$i" -lt "${#COPY[@]}" ]; do
    e="${COPY[i]}"; i=$((i+1)); n=0
    while IFS= read -r -d '' rel; do
      n=$((n+1)); why=""
      src="$MAIN/$rel"; dst="$wt/$rel"
      # A glob such as .*/x can match .. or .git itself: check every match again.
      case "/$rel/" in */../*) why="it leaves the repository" ;; esac
      case "/$(lower "$rel")/" in */.git/*) why="it is inside .git" ;; esac
      if [ -z "$why" ]; then
        if [ -L "$src" ]; then why="it is a symlink"
        elif [ ! -f "$src" ]; then why="it is not a regular file"
        else
          d="$(phys "$(dirname "$src")")"
          case "$d/" in "$MAIN"/*) ;; *) why="it resolves outside the main checkout ($d)" ;; esac
        fi
      fi
      # Never write through a symlink in the worktree: a tracked symlinked folder can lead outside
      # it, and a dangling one cannot even be resolved.
      if [ -z "$why" ]; then
        d="$wt"; r="$rel"
        while [ "${r#*/}" != "$r" ]; do
          d="$d/${r%%/*}"; r="${r#*/}"
          if [ -L "$d" ]; then why="a folder on its path in the worktree is a symlink (${d#"$wt"/})"; break; fi
        done
      fi
      [ -n "$why" ] || [ ! -L "$dst" ] || why="the destination in the worktree is a symlink"
      if [ -z "$why" ]; then
        git -C "$wt" check-ignore -q -- "$rel" 2>/dev/null
        case "$?" in
          0) ;;
          1) why="it is not ignored in the new worktree, so git add -A could commit it" ;;
          *) why="git check-ignore failed, so it may not be ignored there" ;;
        esac
      fi
      if [ -n "$why" ]; then note "copy: refused $rel: $why"; POST_FAIL=1; continue; fi
      # Compare only a regular file: cmp would block on a FIFO.
      if [ -e "$dst" ]; then
        if [ ! -f "$dst" ]; then
          note "copy: kept $rel (not a regular file in the worktree; never overwritten)"
        elif ! cmp -s "$src" "$dst"; then
          note "copy: kept $rel (differs from the main checkout's; never overwritten)"
        fi
        continue
      fi
      if mkdir -p "$(dirname "$dst")" && cp -p "$src" "$dst"; then note "copy: $rel"
      else note "copy: could not copy $rel (see above)"; POST_FAIL=1; fi
    done < <(copy_matches "$e")
    [ "$n" -gt 0 ] || note "copy: no match for $e ($COPY_LIST line ${COPY_LINE[i-1]})"
  done
}

# need_setup_script - exit 1 unless the main checkout has an executable setup script (create
# --setup checks this before anything is created).
need_setup_script() {
  [ -f "$MAIN/$SETUP_SCRIPT" ] && [ -x "$MAIN/$SETUP_SCRIPT" ] \
    || die 1 "refused: --setup needs an executable $SETUP_SCRIPT in the main checkout ($MAIN); nothing created"
}

# setup_step <worktree> <branch> - run the main checkout's setup script in <worktree>: by its own
# shebang, stdin from /dev/null, all output to stderr, the caller's LC_ALL and GIT_OPTIONAL_LOCKS
# restored, HARNESS_WORKTREE_MAIN / _PATH / _BRANCH set. The worktree's own copy is never run.
# A script that cannot run or exits non-zero sets POST_FAIL=1.
setup_step() {
  local wt="$1" br="$2" s="$MAIN/$SETUP_SCRIPT" rc
  if [ ! -f "$s" ] || [ ! -x "$s" ]; then
    note "setup: $SETUP_SCRIPT in the main checkout is not executable (chmod +x it)"; POST_FAIL=1; return 0
  fi
  note "setup: running $SETUP_SCRIPT from the main checkout in $wt"
  if [ -f "$wt/$SETUP_SCRIPT" ] && ! cmp -s "$s" "$wt/$SETUP_SCRIPT"; then
    note "setup: this worktree's own $SETUP_SCRIPT differs; the main checkout's copy runs"
  fi
  (
    cd "$wt" || exit 1
    if [ -n "$CALLER_LC_ALL_SET" ]; then export LC_ALL="$CALLER_LC_ALL"; else unset LC_ALL; fi
    if [ -n "$CALLER_GOL_SET" ]; then export GIT_OPTIONAL_LOCKS="$CALLER_GOL"; else unset GIT_OPTIONAL_LOCKS; fi
    export HARNESS_WORKTREE_MAIN="$MAIN" HARNESS_WORKTREE_PATH="$wt" HARNESS_WORKTREE_BRANCH="$br"
    exec "$s"
  ) </dev/null 1>&2
  rc=$?
  if [ "$rc" -ne 0 ]; then note "setup: $SETUP_SCRIPT exited $rc"; POST_FAIL=1; fi
  return 0
}

# post_steps <worktree> <branch> <run-setup: 0|1> - the copy step (when the main checkout has a
# copy list), then the setup step (with 1). POST_FAIL says whether either failed.
post_steps() {
  POST_FAIL=0
  if [ -f "$MAIN/$COPY_LIST" ]; then copy_step "$1"; fi
  if [ "$3" = 1 ]; then setup_step "$1" "$2"; fi
  return 0
}

# finish <slug> <path> - print the path; exit 4 after a failed post-create step (the worktree stays).
finish() {
  if [ "$POST_FAIL" = 1 ]; then
    note "the worktree is at $2, but a post-create step failed (see above): fix the cause and run 'worktree.sh setup $1'"
    printf '%s\n' "$2"
    exit 4
  fi
  printf '%s\n' "$2"
}

cmd_path() {
  [ $# -ge 1 ] || die 2 "path needs a <slug> (usage: worktree.sh path <slug>)"
  [ $# -eq 1 ] || die 2 "path takes one <slug>"
  check_slug "$1"
  load_repo; resolve_root
  printf '%s\n' "$BASE_DIR/$1"
}

# add_new_branch <git worktree add args> - a `git worktree add` that creates $branch (the caller's).
# git creates the branch before the checkout, so a failed add can leave it behind; it did not exist
# before this call, so it is deleted again unless a worktree has it checked out.
add_new_branch() {
  git -C "$TOP" worktree add "$@" >&2 && return 0
  load_worktrees
  if git -C "$TOP" rev-parse --verify -q "refs/heads/$branch" >/dev/null 2>&1 \
     && ! checked_out "$branch" >/dev/null; then
    git -C "$TOP" branch -D "$branch" >/dev/null 2>&1 && note "deleted the new branch $branch again"
  fi
  return 1
}

cmd_create() {
  local slug="" have=0 base="" branch="" p i r remotes="" remote="" mode=new base_ref="" base_name="" full dr
  local setup=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --base)   [ $# -ge 2 ] && [ -n "$2" ] || die 2 "--base needs a <ref>"; base="$2"; shift 2 ;;
      --branch) [ $# -ge 2 ] && [ -n "$2" ] || die 2 "--branch needs a <name>"; branch="$2"; shift 2 ;;
      --setup)  setup=1; shift ;;
      -*)       die 2 "unknown create option: $1" ;;
      *)        [ "$have" = 0 ] || die 2 "create takes one <slug>, got another: $1"
                slug="$1"; have=1; shift ;;
    esac
  done
  [ "$have" = 1 ] || die 2 "create needs a <slug> (usage: worktree.sh create <slug> [--base <ref>] [--branch <name>] [--setup])"
  check_slug "$slug"
  [ "$branch" != "" ] || branch="$slug"
  check_branch "$branch"
  load_repo; resolve_root
  p="$BASE_DIR/$slug"

  # 1. The branch is checked out already. In a harness worktree, a re-run: print that path and change
  #    nothing. Anywhere else (the main checkout, an external worktree) refuse: git checks a branch
  #    out in one place only, and printing that path would send the developer where they already are.
  if i="$(checked_out "$branch")"; then
    if [ "${WT_PHYS[i]%/*}" = "$BASE_DIR" ]; then
      [ -d "${WT_PHYS[i]}" ] \
        || die 1 "branch $branch is checked out at ${WT_PHYS[i]}, which no longer exists: run 'worktree.sh remove ${WT_PHYS[i]##*/}' or 'worktree.sh prune' first"
      note "branch $branch is already checked out at ${WT_PHYS[i]}; nothing created${base:+ (--base $base not used)}"
      [ "$setup" = 0 ] || note "--setup not used: a re-run of create changes nothing"
      if [ -f "$MAIN/$COPY_LIST" ] || [ -e "$MAIN/$SETUP_SCRIPT" ]; then
        note "run 'worktree.sh setup ${WT_PHYS[i]##*/}' to re-run the copy and setup steps there"
      fi
      printf '%s\n' "${WT_PHYS[i]}"
      return 0
    fi
    [ -d "${WT_PHYS[i]}" ] \
      || die 1 "branch $branch is checked out at ${WT_PHYS[i]}, which no longer exists and is not a harness worktree: drop its record with 'git worktree remove ${WT_PHYS[i]}' first"
    if [ "$i" = 0 ]; then r="the main checkout at ${WT_PHYS[i]}"
    else r="the worktree at ${WT_PHYS[i]}, which the harness did not create"; fi
    die 1 "branch $branch is checked out in $r, and git checks a branch out in one place only: work there, switch that checkout to another branch, or pass --branch <new-name>"
  fi
  # 2. Something else is at the target path, or git still has a record for it.
  i=0
  while [ "$i" -lt "$WT_N" ] && [ "${WT_PHYS[i]}" != "$p" ]; do i=$((i+1)); done
  if [ "$i" -lt "$WT_N" ] && [ ! -d "$p" ]; then
    die 1 "$p is still registered as a worktree (${WT_BRANCH[i]:-detached}) but its directory is gone: run 'worktree.sh remove $slug' or 'worktree.sh prune' first"
  fi
  if [ -e "$p" ] || [ -L "$p" ]; then die 1 "$p exists and is not the worktree of branch $branch"; fi

  # An existing branch: local, or one remote has it (as git decides: exactly one remote, or the one
  # checkout.defaultRemote names). Several remotes without that setting is ambiguous, as in git. The
  # remote branch is then checked out by its full ref, never by the short name, which a same-name
  # tag or an abbreviated sha would win.
  if git -C "$TOP" show-ref --verify -q "refs/heads/$branch"; then
    mode=local
  else
    for r in $(git -C "$TOP" remote 2>/dev/null); do
      git -C "$TOP" show-ref --verify -q "refs/remotes/$r/$branch" && remotes="$remotes $r"
    done
    remotes="${remotes# }"
    case "$remotes" in
      "") ;;
      *" "*)
        dr="$(git -C "$TOP" config --get checkout.defaultRemote 2>/dev/null)"
        case " $remotes " in
          *" $dr "*) [ -n "$dr" ] && remote="$dr" ;;
        esac
        [ -n "$remote" ] \
          || die 2 "branch $branch exists on several remotes ($remotes): create it from one first, e.g. 'git branch --track $branch ${remotes%% *}/$branch', or set checkout.defaultRemote, then run create again" ;;
      *) remote="$remotes" ;;
    esac
    [ -z "$remote" ] || mode=remote
  fi
  if [ "$mode" != new ]; then
    [ -z "$base" ] || die 2 "--base cannot be used with the existing branch $branch: drop --base, or pick a new --branch name"
  elif [ -n "$base" ]; then
    # A branch name means the branch, even when a tag has the same name (git would pick the tag).
    # Otherwise record the branch the base names, never text relative to this checkout's HEAD
    # (HEAD, @{-1}). A tag or a commit names no branch: the merged check then uses the default branch.
    if git -C "$TOP" show-ref --verify -q "refs/heads/$base"; then
      base_ref="refs/heads/$base"; base_name="$base"
    elif git -C "$TOP" show-ref --verify -q "refs/remotes/$base"; then
      base_ref="refs/remotes/$base"; base_name="refs/remotes/$base"
    else
      git -C "$TOP" rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1 || die 2 "--base is not a commit: $base"
      base_ref="$base"
      full="$(git -C "$TOP" rev-parse --symbolic-full-name "$base" 2>/dev/null)"
      case "$full" in
        refs/heads/*)   base_name="${full#refs/heads/}" ;;
        refs/remotes/*) base_name="$full" ;;
      esac
    fi
  else
    base_name="$(default_branch)" || die 2 "no default branch found (origin/HEAD, main, master): pass --base <ref>"
    if git -C "$TOP" rev-parse --verify -q "refs/heads/$base_name" >/dev/null 2>&1; then
      base_ref="refs/heads/$base_name"
    elif git -C "$TOP" rev-parse --verify -q "refs/remotes/origin/$base_name" >/dev/null 2>&1; then
      base_ref="refs/remotes/origin/$base_name"
    else
      die 2 "the default branch $base_name does not resolve here: pass --base <ref>"
    fi
  fi

  # The project's post-create files are checked before anything is created: a copy-list entry that
  # leaves the repository, or --setup without an executable setup script, exits 1 here.
  load_copy_list
  [ "$setup" = 0 ] || need_setup_script

  # 3. The root.
  { mkdir -p "$BASE_DIR" 2>/dev/null && [ -w "$BASE_DIR" ]; } \
    || die 3 "cannot create the worktree root $ROOT: set HARNESS_WORKTREE_ROOT to a writable, persistent directory"

  # 4./5. Check out the existing branch (a remote one as a local branch tracking it), or create the
  #      new one with no upstream.
  case "$mode" in
    local)
      git -C "$TOP" worktree add "$p" "$branch" >&2 || die 1 "git worktree add failed for $branch (see above)" ;;
    remote)
      add_new_branch --track -b "$branch" "$p" "refs/remotes/$remote/$branch" \
        || die 1 "git worktree add failed for $branch from $remote/$branch (see above)" ;;
    new)
      add_new_branch --no-track -b "$branch" "$p" "$base_ref" \
        || die 1 "git worktree add failed for $branch from ${base:-$base_name} (see above)" ;;
  esac
  if [ "$mode" = new ]; then
    if [ -z "$base_name" ]; then
      note "--base $base names no branch: the merged check uses the default branch"
    else
      git -C "$TOP" config "branch.$branch.harnessBase" "$base_name" \
        || note "warning: could not record branch.$branch.harnessBase; the merged check falls back to the default branch"
    fi
  fi

  # The start commit: until the branch moves past it, prune keeps the worktree (it may be in use).
  git -C "$TOP" config "branch.$branch.harnessStart" "$(git -C "$p" rev-parse HEAD 2>/dev/null)" \
    || note "warning: could not record branch.$branch.harnessStart; prune may list this worktree before its first commit"

  # 6. The project's post-create steps: the copy list, then (only with --setup) the setup script.
  post_steps "$p" "$branch" "$setup"

  # 7. The bundle travels with git only.
  [ -d "$p/.agents/monorepo-agents-harness" ] \
    || note "warning: $p has no .agents/monorepo-agents-harness/ (the bundle is not tracked in git), so hooks and /monorepo-harness-* commands cannot run in this worktree until the bundle is committed or installed there"
  [ -f "$MAIN/$COPY_LIST" ] \
    || note "ignored files (node_modules, .env, build output) are not copied: bring over any .env by hand, or list it in $COPY_LIST"
  if [ ! -e "$MAIN/$SETUP_SCRIPT" ]; then
    note "run the project's own install in the new worktree (e.g. pnpm install), or add $SETUP_SCRIPT"
  elif [ "$setup" = 0 ]; then
    note "$SETUP_SCRIPT was not run: run 'worktree.sh setup $slug' to run it in the new worktree"
  fi
  finish "$slug" "$p"
}

cmd_setup() {
  local slug="" have=0 i p run=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die 2 "unknown setup option: $1" ;;
      *)  [ "$have" = 0 ] || die 2 "setup takes one <slug>, got another: $1"
          slug="$1"; have=1; shift ;;
    esac
  done
  [ "$have" = 1 ] || die 2 "setup needs a <slug> (usage: worktree.sh setup <slug>)"
  check_slug "$slug"
  load_repo; resolve_root
  i="$(harness_index "$slug")" \
    || die 1 "no harness worktree '$slug' at $BASE_DIR/$slug ('worktree.sh list' shows them; setup runs only in a worktree the harness created)"
  p="${WT_PHYS[i]}"
  [ -d "$p" ] || die 1 "$p is still registered but its directory is gone: run 'worktree.sh remove $slug' or 'worktree.sh prune' first"
  load_copy_list
  if [ ! -f "$MAIN/$COPY_LIST" ] && [ ! -e "$MAIN/$SETUP_SCRIPT" ]; then
    note "nothing to set up: the main checkout has no $COPY_LIST or $SETUP_SCRIPT"
    printf '%s\n' "$p"
    return 0
  fi
  [ ! -e "$MAIN/$SETUP_SCRIPT" ] || run=1
  post_steps "$p" "${WT_BRANCH[i]}" "$run"
  finish "$slug" "$p"
}

cmd_list() {
  local all=0 i=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1; shift ;;
      *) die 2 "unknown list option: $1" ;;
    esac
  done
  load_repo; resolve_root
  print_header
  while [ "$i" -lt "$WT_N" ]; do
    # An external worktree is read only with --all.
    if [ "$all" = 1 ] || [ "${WT_PHYS[i]%/*}" = "$BASE_DIR" ]; then row_of "$i"; print_row; fi
    i=$((i+1))
  done
}

cmd_remove() {
  local slug="" have=0 force="" delete_branch=0 i p branch refused=0 what
  while [ $# -gt 0 ]; do
    case "$1" in
      --force)         force=1; shift ;;
      --delete-branch) delete_branch=1; shift ;;
      -*) die 2 "unknown remove option: $1" ;;
      *)  [ "$have" = 0 ] || die 2 "remove takes one <slug>, got another: $1"
          slug="$1"; have=1; shift ;;
    esac
  done
  [ "$have" = 1 ] || die 2 "remove needs a <slug> (usage: worktree.sh remove <slug> [--delete-branch] [--force])"
  check_slug "$slug"
  load_repo; resolve_root
  i="$(harness_index "$slug")" \
    || die 1 "no harness worktree '$slug' at $BASE_DIR/$slug ('worktree.sh list --all' shows every worktree; the harness never removes one it did not create)"
  p="${WT_PHYS[i]}"; branch="${WT_BRANCH[i]}"
  load_junk
  assess "$i"
  [ -z "$A_HARD" ] || die 1 "refused to remove $p: $A_HARD"

  for what in op dirty ign unm; do
    case "$what" in
      op)    [ -n "$A_OP" ]    || continue; set -- "$A_OP in progress" "finish or abort it there first (git status shows how)" "" ;;
      dirty) [ -n "$A_DIRTY" ] || continue; set -- "uncommitted changes" "$A_DIRTY" "" ;;
      ign)   [ -n "$A_IGN" ]   || continue; set -- "ignored files outside the junk list" "$A_IGN" "" ;;
      unm)   [ -n "$A_UNM" ]   || continue
             if [ -n "$branch" ]; then set -- "commits not merged into the base" "$A_UNM" " (branch $branch keeps them)"
             else set -- "commits not merged into the base" "$A_UNM" " (detached: no branch keeps them)"; fi ;;
    esac
    if [ -n "$force" ]; then note "--force: discarding $1 in $p$3:"
    else note "refused: $1 in $p:"; refused=1; fi
    indent "$2"
  done
  [ "$refused" = 0 ] || die 1 "nothing removed. Commit, move or delete these first, or pass --force to discard them"

  drop "$p" "$force" || exit 1
  note "removed $p"
  if [ "$delete_branch" = 1 ]; then
    if [ -z "$branch" ]; then
      note "$p was detached: no branch to delete"
    elif [ "$branch" = "$(default_branch)" ]; then
      note "kept branch $branch (the default branch is never deleted)"
    elif [ "$R_MERGED" = merged ]; then
      git -C "$TOP" branch -D "$branch" >&2 || note "could not delete branch $branch"
    else
      note "kept branch $branch (unmerged)"
    fi
  fi
}

# prune_why <i> - assess, then WHY: the reason prune keeps worktree i, or empty for a candidate.
# Beyond remove's checks, prune keeps a worktree whose branch has no commit since create: it may
# still be in use by another session (an explicit remove still removes it).
prune_why() {
  local i="$1" start
  assess "$i"
  WHY="$A_HARD"
  [ -n "$WHY" ] || [ -z "$A_OP" ]    || WHY="$A_OP in progress"
  [ -n "$WHY" ] || [ -z "$A_DIRTY" ] || WHY="uncommitted changes"
  [ -n "$WHY" ] || [ -z "$A_IGN" ]   || WHY="ignored files outside the junk list: $(printf '%s' "$A_IGN" | tr '\n' ' ')"
  if [ -z "$WHY" ] && [ -n "$A_UNM" ]; then
    if [ "$R_MERGED" = unknown ]; then WHY="cannot tell whether it is merged (${MERGE_NOTE:-no base resolves})"
    else WHY="commits not merged into the base"; fi
  fi
  if [ -z "$WHY" ] && [ "$R_STATE" != missing ] && [ -n "${WT_BRANCH[i]}" ]; then
    start="$(git -C "$TOP" config --get "branch.${WT_BRANCH[i]}.harnessStart" 2>/dev/null)"
    [ -n "$start" ] && [ "$start" = "${WT_HEAD[i]}" ] \
      && WHY="no commit since create, so it may still be in use ('worktree.sh remove $R_SLUG' removes it)"
  fi
  return 0
}

cmd_prune() {
  local yes=0 i=1 n=0 failed=0 slug j
  local -a cand
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes) yes=1; shift ;;
      *) die 2 "unknown prune option: $1" ;;
    esac
  done
  load_repo; resolve_root; load_junk
  print_header
  while [ "$i" -lt "$WT_N" ]; do
    # Only harness worktrees: an external one is never read.
    if [ "${WT_PHYS[i]%/*}" = "$BASE_DIR" ]; then
      prune_why "$i"
      if [ -n "$WHY" ]; then note "kept $R_SLUG: $WHY"
      else print_row; cand[n]="${WT_PHYS[i]##*/}"; n=$((n+1)); fi
    fi
    i=$((i+1))
  done
  [ "$yes" = 1 ] || return 0
  # Re-read the worktree list and re-check each candidate right before removing it: a lock, a
  # commit or a new file since the first pass keeps it. Nothing skips here (no --force, no branch
  # delete).
  load_worktrees
  i=0
  while [ "$i" -lt "$n" ]; do
    slug="${cand[i]}"; i=$((i+1))
    j="$(harness_index "$slug")" || { note "$slug is already gone"; continue; }
    prune_why "$j"
    if [ -n "$WHY" ]; then
      note "not removed $slug: $WHY"; failed=1
    elif drop "$R_PATH"; then
      note "removed $R_PATH"
    else
      failed=1
    fi
  done
  [ "$failed" = 0 ] || exit 1
}

CMD="${1:-}"
case "$CMD" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
shift

case "$CMD" in
  path)   cmd_path "$@" ;;
  create) cmd_create "$@" ;;
  setup)  cmd_setup "$@" ;;
  list)   cmd_list "$@" ;;
  remove) cmd_remove "$@" ;;
  prune)  cmd_prune "$@" ;;
  *) usage >&2; die 2 "unknown subcommand: $CMD" ;;
esac
