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
#   create <slug> [--base <ref>] [--branch <b>]  add the worktree and print its path (new branch from
#                                                --base or the default branch, or an existing branch)
#   list [--all]                                 table: kind slug branch state merged last_commit path
#                                                (--all adds the worktrees the harness did not create)
#   remove <slug> [--delete-branch] [--force]    remove one harness worktree after the safety checks
#   prune [--yes]                                dry run by default: the clean+merged or missing
#                                                harness worktrees; --yes removes them
#
# stdout carries only the result (a path or a table); notes and refusals go to stderr.
# Needs git >= 2.17 and coreutils. Never fetches or pushes.
#
# Exit codes: 0 done, 1 refused (reason printed), 2 bad call, 3 environment (not inside a git work
# tree, HOME unset, root not writable, root inside the repository).
set -uo pipefail
export LC_ALL=C

# Ignored files that can be rebuilt, so `remove` may lose them (docs/worktrees.md, "Junk list"). An
# entry matches the name of the ignored file or directory itself (`*`, `?`, `[` are globs), never a
# folder above it. A project adds entries in .agents/worktree-junk.txt. `.index.sqlite*` is the
# harness's own derived cache (kb-index.sh).
JUNK_DEFAULT='node_modules dist build out .turbo .next .nuxt .svelte-kit .output .vercel .cache
.parcel-cache coverage .nyc_output target __pycache__ .pytest_cache .mypy_cache .ruff_cache .venv
.gradle .eslintcache .DS_Store *.tsbuildinfo *.pyc *.log .index.sqlite*'

usage() { sed -n '2,25p' "$0"; }
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

# base_of <branch> - branch.<b>.harnessBase while it (or origin/<it>) resolves, else the default
# branch. A stacked branch whose base was merged and deleted falls back to the default branch.
base_of() {
  local v=""
  [ -n "$1" ] && v="$(git -C "$TOP" config --get "branch.$1.harnessBase" 2>/dev/null)"
  if [ -n "$v" ] && { git -C "$TOP" rev-parse --verify -q "$v^{commit}" >/dev/null 2>&1 \
       || git -C "$TOP" rev-parse --verify -q "refs/remotes/origin/$v^{commit}" >/dev/null 2>&1; }; then
    printf '%s' "$v"
  else
    default_branch
  fi
}

# merged_state <tip> <base> - sets MERGED (merged | unmerged | unknown) and MERGE_CAND (the first
# base candidate that exists). Merged = the tip is an ancestor of <base> or origin/<base>, or
# `git cherry` finds every commit there by patch-id. Unsure means not merged (docs/worktrees.md,
# "Merged rule").
merged_state() {
  local tip="$1" base="$2" c out
  MERGED=unknown; MERGE_CAND=""
  [ -n "$base" ] && [ -n "$tip" ] || return 0
  for c in "$base" "refs/remotes/origin/$base"; do
    git -C "$TOP" rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 || continue
    MERGED=unmerged; [ -n "$MERGE_CAND" ] || MERGE_CAND="$c"
    if git -C "$TOP" merge-base --is-ancestor "$tip" "$c" 2>/dev/null; then MERGED=merged; return 0; fi
    if out="$(git -C "$TOP" cherry "$c" "$tip" 2>/dev/null)" \
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
  elif s="$(git -C "$R_PATH" status --porcelain 2>&1)"; then
    R_STATUS="$s"
    if [ -n "$s" ]; then R_STATE=dirty; else R_STATE=clean; fi
  else
    R_STATUS="cannot read git status: $s"; R_STATE=dirty
  fi
  merged_state "${WT_HEAD[i]}" "$(base_of "${WT_BRANCH[i]}")"
  R_MERGED="$MERGED"
  R_DATE="$(git -C "$TOP" log -1 --format=%cd --date=short "${WT_HEAD[i]}" 2>/dev/null)"
  R_DATE="${R_DATE:--}"
}

print_header() { printf 'kind\tslug\tbranch\tstate\tmerged\tlast_commit\tpath\n'; }
print_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$R_KIND" "$R_SLUG" "$R_BRANCH" "$R_STATE" "$R_MERGED" "$R_DATE" "$R_PATH"
}

# load_junk - the default junk list plus the project's .agents/worktree-junk.txt (read-only).
load_junk() {
  local e line f="$TOP/.agents/worktree-junk.txt"
  JUNK=()
  set -f
  for e in $JUNK_DEFAULT; do JUNK[${#JUNK[@]}]="$e"; done
  set +f
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    case "$line" in ""|"#"*) continue ;; esac
    JUNK[${#JUNK[@]}]="${line%/}"
  done < "$f"
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

# nonjunk_ignored <dir> - the ignored files and directories outside the junk list, one per line.
nonjunk_ignored() {
  local e
  while IFS= read -r -d '' e; do
    case "$e" in '!! '*) e="${e#!! }" ;; *) continue ;; esac
    is_junk "$e" || printf '%s\n' "$e"
  done < <(git -C "$1" status --porcelain -z --ignored=matching 2>/dev/null)
}

# assess <i> - row_of plus the removal findings:
#   A_HARD  a reason nothing skips (locked, current directory inside), or empty
#   A_DIRTY the git status lines of a present worktree
#   A_IGN   ignored files outside the junk list
#   A_UNM   the commits not in the base (or why that is unknown); empty when merged. A missing
#           worktree on a branch loses no commit (the branch stays), so it is only checked when
#           detached.
assess() {
  local i="$1" cwd
  row_of "$i"
  A_HARD=""; A_DIRTY="$R_STATUS"; A_IGN=""; A_UNM=""
  cwd="$(pwd -P)"
  case "$cwd/" in "$R_PATH"/*) A_HARD="the current directory is inside it: run this from another checkout" ;; esac
  [ "${WT_LOCKED[i]}" = 1 ] && A_HARD="it is locked (unlocking it with 'git worktree unlock' is your call)"
  [ "$R_STATE" = missing ] || A_IGN="$(nonjunk_ignored "$R_PATH")"
  if [ "$R_MERGED" != merged ] && { [ "$R_STATE" != missing ] || [ -z "${WT_BRANCH[i]}" ]; }; then
    if [ "$R_MERGED" = unknown ]; then
      A_UNM="cannot tell whether its commits are merged: no base resolves (branch.<b>.harnessBase, origin/HEAD, main, master)"
    else
      A_UNM="$(git -C "$TOP" cherry -v "$MERGE_CAND" "${WT_HEAD[i]}" 2>/dev/null | grep '^+')"
      [ -n "$A_UNM" ] || A_UNM="commits not in ${MERGE_CAND#refs/remotes/}"
    fi
  fi
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

cmd_path() {
  [ $# -ge 1 ] || die 2 "path needs a <slug> (usage: worktree.sh path <slug>)"
  [ $# -eq 1 ] || die 2 "path takes one <slug>"
  check_slug "$1"
  load_repo; resolve_root
  printf '%s\n' "$BASE_DIR/$1"
}

cmd_create() {
  local slug="" have=0 base="" branch="" p i r remotes="" existing=0 base_ref="" base_name="" full dr
  while [ $# -gt 0 ]; do
    case "$1" in
      --base)   [ $# -ge 2 ] && [ -n "$2" ] || die 2 "--base needs a <ref>"; base="$2"; shift 2 ;;
      --branch) [ $# -ge 2 ] && [ -n "$2" ] || die 2 "--branch needs a <name>"; branch="$2"; shift 2 ;;
      -*)       die 2 "unknown create option: $1" ;;
      *)        [ "$have" = 0 ] || die 2 "create takes one <slug>, got another: $1"
                slug="$1"; have=1; shift ;;
    esac
  done
  [ "$have" = 1 ] || die 2 "create needs a <slug> (usage: worktree.sh create <slug> [--base <ref>] [--branch <name>])"
  check_slug "$slug"
  [ "$branch" != "" ] || branch="$slug"
  check_branch "$branch"
  load_repo; resolve_root
  p="$BASE_DIR/$slug"

  # 1. The branch is checked out already: print that path and change nothing.
  if i="$(checked_out "$branch")"; then
    if [ ! -d "${WT_PHYS[i]}" ]; then
      if [ "${WT_PHYS[i]%/*}" = "$BASE_DIR" ]; then
        die 1 "branch $branch is checked out at ${WT_PHYS[i]}, which no longer exists: run 'worktree.sh remove ${WT_PHYS[i]##*/}' or 'worktree.sh prune' first"
      fi
      die 1 "branch $branch is checked out at ${WT_PHYS[i]}, which no longer exists and is not a harness worktree: drop its record with 'git worktree remove ${WT_PHYS[i]}' first"
    fi
    note "branch $branch is already checked out at ${WT_PHYS[i]}; nothing created${base:+ (--base $base not used)}"
    printf '%s\n' "${WT_PHYS[i]}"
    return 0
  fi
  # 2. Something else is at the target path, or git still has a record for it.
  i=0
  while [ "$i" -lt "$WT_N" ] && [ "${WT_PHYS[i]}" != "$p" ]; do i=$((i+1)); done
  if [ "$i" -lt "$WT_N" ] && [ ! -d "$p" ]; then
    die 1 "$p is still registered as a worktree (${WT_BRANCH[i]:-detached}) but its directory is gone: run 'worktree.sh remove $slug' or 'worktree.sh prune' first"
  fi
  if [ -e "$p" ] || [ -L "$p" ]; then die 1 "$p exists and is not the worktree of branch $branch"; fi

  # An existing branch: local, or one remote has it (git's own DWIM: exactly one remote, or the one
  # checkout.defaultRemote names). Several remotes without that setting is ambiguous, as in git.
  if git -C "$TOP" rev-parse --verify -q "refs/heads/$branch" >/dev/null 2>&1; then
    existing=1
  else
    for r in $(git -C "$TOP" remote 2>/dev/null); do
      git -C "$TOP" rev-parse --verify -q "refs/remotes/$r/$branch" >/dev/null 2>&1 && remotes="$remotes $r"
    done
    remotes="${remotes# }"
    case "$remotes" in
      "") ;;
      *" "*)
        dr="$(git -C "$TOP" config --get checkout.defaultRemote 2>/dev/null)"
        case " $remotes " in
          *" $dr "*) [ -n "$dr" ] && existing=1 ;;
        esac
        [ "$existing" = 1 ] \
          || die 2 "branch $branch exists on several remotes ($remotes): create it from one first, e.g. 'git branch --track $branch ${remotes%% *}/$branch', or set checkout.defaultRemote, then run create again" ;;
      *) existing=1 ;;
    esac
  fi
  if [ "$existing" = 1 ]; then
    [ -z "$base" ] || die 2 "--base cannot be used with the existing branch $branch: drop --base, or pick a new --branch name"
  elif [ -n "$base" ]; then
    git -C "$TOP" rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1 || die 2 "--base is not a commit: $base"
    base_ref="$base"
    # Record the branch the base names, never text relative to this checkout's HEAD (HEAD, @{-1}).
    # A tag or a commit names no branch: the merged check then uses the default branch.
    full="$(git -C "$TOP" rev-parse --symbolic-full-name "$base" 2>/dev/null)"
    case "$full" in
      refs/heads/*)   base_name="${full#refs/heads/}" ;;
      refs/remotes/*) base_name="$full" ;;
    esac
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

  # 3. The root.
  { mkdir -p "$BASE_DIR" 2>/dev/null && [ -w "$BASE_DIR" ]; } \
    || die 3 "cannot create the worktree root $ROOT: set HARNESS_WORKTREE_ROOT to a writable, persistent directory"

  # 4./5. Check out the existing branch, or create the new one with no upstream.
  if [ "$existing" = 1 ]; then
    git -C "$TOP" worktree add "$p" "$branch" >&2 || die 1 "git worktree add failed for $branch (see above)"
  else
    if ! git -C "$TOP" worktree add --no-track -b "$branch" "$p" "$base_ref" >&2; then
      # git creates the branch before the checkout, so a failed add can leave it behind. It did not
      # exist before this call: delete it again unless a worktree has it checked out.
      load_worktrees
      if git -C "$TOP" rev-parse --verify -q "refs/heads/$branch" >/dev/null 2>&1 \
         && ! checked_out "$branch" >/dev/null; then
        git -C "$TOP" branch -D "$branch" >/dev/null 2>&1 && note "deleted the new branch $branch again"
      fi
      die 1 "git worktree add failed for $branch from ${base:-$base_name} (see above)"
    fi
    if [ -z "$base_name" ]; then
      note "--base $base names no branch: the merged check uses the default branch"
    else
      git -C "$TOP" config "branch.$branch.harnessBase" "$base_name" \
        || note "warning: could not record branch.$branch.harnessBase; the merged check falls back to the default branch"
    fi
  fi

  # 6. The bundle travels with git only.
  [ -d "$p/.agents/monorepo-agents-harness" ] \
    || note "warning: $p has no .agents/monorepo-agents-harness/ (the bundle is not tracked in git), so hooks and /monorepo-harness-* commands cannot run in this worktree until the bundle is committed or installed there"
  note "ignored files (node_modules, .env, build output) are not copied: run the project's own install in the new worktree and bring over any .env by hand"
  printf '%s\n' "$p"
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
    row_of "$i"
    if [ "$R_KIND" = harness ] || [ "$all" = 1 ]; then print_row; fi
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

  for what in dirty ign unm; do
    case "$what" in
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
    elif [ "$R_MERGED" = merged ]; then
      git -C "$TOP" branch -D "$branch" >&2 || note "could not delete branch $branch"
    else
      note "kept branch $branch (unmerged)"
    fi
  fi
}

cmd_prune() {
  local yes=0 i=1 n=0 failed=0 why
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
    assess "$i"
    if [ "$R_KIND" = harness ]; then
      why="$A_HARD"
      [ -n "$why" ] || [ -z "$A_DIRTY" ] || why="uncommitted changes"
      [ -n "$why" ] || [ -z "$A_IGN" ]   || why="ignored files outside the junk list: $(printf '%s' "$A_IGN" | tr '\n' ' ')"
      if [ -z "$why" ] && [ -n "$A_UNM" ]; then
        if [ "$R_MERGED" = unknown ]; then why="cannot tell whether it is merged (no base resolves)"
        else why="commits not merged into the base"; fi
      fi
      if [ -n "$why" ]; then note "kept $R_SLUG: $why"
      else print_row; cand[n]="$i"; n=$((n+1)); fi
    fi
    i=$((i+1))
  done
  [ "$yes" = 1 ] || return 0
  i=0
  while [ "$i" -lt "$n" ]; do
    # Re-check right before removing: nothing skips here (no --force, no branch delete).
    assess "${cand[i]}"
    if [ -n "$A_HARD$A_DIRTY$A_IGN$A_UNM" ]; then
      note "not removed $R_SLUG: it changed since the check"; failed=1
    elif drop "$R_PATH"; then
      note "removed $R_PATH"
    else
      failed=1
    fi
    i=$((i+1))
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
  list)   cmd_list "$@" ;;
  remove) cmd_remove "$@" ;;
  prune)  cmd_prune "$@" ;;
  *) usage >&2; die 2 "unknown subcommand: $CMD" ;;
esac
