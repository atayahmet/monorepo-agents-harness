#!/usr/bin/env bash
# review-fix-loop — the deterministic checks behind `/monorepo-harness-review --auto-fix` (issue #77).
# Agent-agnostic.
#
# The review-fix loop itself (review → fix Important findings → verify → commit locally → review
# again) is described once in core/skills/pr-review/SKILL.md, "Review-fix loop (--auto-fix)". The
# decisions that must not depend on the model live here, so every adapter reaches the same answer
# and a test can assert it — the same split as build-review-tier.sh (issue #41).
#
# Subcommands (run from inside the project's git work tree):
#   preflight [--max-rounds <n>]  — refuse to start on a dirty working tree (tracked changes, staged
#                                   changes or untracked files). <n> is an integer from 1 to 5
#                                   (default 2). On success prints `base: <sha>` and `max-rounds: <n>`.
#   check-fix <base-ref>          — run before each fix commit. Lists the files added since
#                                   <base-ref> (committed, staged or untracked) and refuses when one of
#                                   them is not a test file: a new non-test file means "stop and ask".
#                                   Test files: *.test.*, *.spec.*, *_test.*, test_*, or any path
#                                   under tests/, test/ or __tests__/.
#   security-due <from-ref>       — line 1 is exactly `yes` or `no`: whether <from-ref>..HEAD touched a
#                                   security-sensitive path, so the security pass must run on the
#                                   next review even if it is not the closing pass. The rest explains.
#
# The script never commits, pushes or edits anything.
#
# Exit codes: 0 = pass / decided, 1 = refused (preflight, check-fix), 2 = usage error.
set -uo pipefail

DEFAULT_ROUNDS=2
MAX_ROUNDS_CAP=5

usage() { sed -n '2,26p' "$0"; }
die_usage() { echo "review-fix-loop: $*" >&2; exit 2; }

in_work_tree() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die_usage "not inside a git work tree"
}

# resolve_ref <ref> - print the commit sha, or fail as a usage error.
resolve_ref() {
  [ -n "${1:-}" ] || die_usage "$CMD needs a git ref (usage: review-fix-loop.sh $CMD <ref>)"
  git rev-parse --verify -q "$1^{commit}" 2>/dev/null \
    || die_usage "not a commit: $1"
}

# is_test_file <path> - true for the common test-file layouts.
is_test_file() {
  local p="$1" b
  b="${p##*/}"
  case "/$p" in */tests/*|*/test/*|*/__tests__/*) return 0 ;; esac
  case "$b" in *.test.*|*.spec.*|*_test.*|test_*) return 0 ;; esac
  return 1
}

# sensitive_reason <path> - print why a path is security-sensitive, or nothing.
sensitive_reason() {
  local p="$1" b lower
  b="${p##*/}"
  case "$b" in
    .env|.env.*) echo "env file"; return ;;
    package-lock.json|npm-shrinkwrap.json|pnpm-lock.yaml|yarn.lock|bun.lockb|bun.lock)
      echo "lockfile"; return ;;
  esac
  lower="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  if printf '%s' "$lower" \
    | grep -Eq '(auth|security|secret|crypto|token|session|permission|acl|oauth|jwt|password|credential|webhook)'; then
    echo "security keyword in path"
  fi
}

CMD="${1:-}"
case "$CMD" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
shift

case "$CMD" in
  preflight)
    rounds="$DEFAULT_ROUNDS"
    while [ $# -gt 0 ]; do
      case "$1" in
        --max-rounds)
          [ $# -ge 2 ] || die_usage "--max-rounds needs a value from 1 to $MAX_ROUNDS_CAP"
          rounds="$2"; shift 2 ;;
        *) die_usage "unknown preflight option: $1" ;;
      esac
    done
    case "$rounds" in
      ''|*[!0-9]*) die_usage "--max-rounds must be an integer from 1 to $MAX_ROUNDS_CAP, got: $rounds" ;;
    esac
    if [ "$rounds" -lt 1 ] || [ "$rounds" -gt "$MAX_ROUNDS_CAP" ]; then
      die_usage "--max-rounds must be an integer from 1 to $MAX_ROUNDS_CAP, got: $rounds"
    fi
    in_work_tree
    dirty="$(git status --porcelain --untracked-files=all 2>/dev/null)"
    if [ -n "$dirty" ]; then
      echo "review-fix-loop: preflight refused — the working tree is not clean."
      echo "Commit, stash or remove these changes first; the loop only starts from a clean tree:"
      printf '%s\n' "$dirty" | sed 's/^/  /'
      exit 1
    fi
    base="$(git rev-parse --verify -q HEAD 2>/dev/null)" \
      || die_usage "no commit yet (HEAD does not resolve)"
    echo "review-fix-loop: preflight passed — clean working tree."
    echo "base: $base"
    echo "max-rounds: $rounds"
    ;;

  check-fix)
    in_work_tree
    base="$(resolve_ref "${1:-}")" || exit 2
    added="$( { git diff --name-only --diff-filter=A "$base" 2>/dev/null
                git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )"
    offenders=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      is_test_file "$f" || offenders="${offenders}${f}"$'\n'
    done <<< "$added"
    if [ -n "$offenders" ]; then
      echo "review-fix-loop: check-fix refused — the fix adds a new non-test file."
      echo "A new file or module is a scope change: stop and ask the user before committing."
      printf '%s' "$offenders" | sed 's/^/  /'
      exit 1
    fi
    if [ -n "$added" ]; then
      echo "review-fix-loop: check-fix passed — only new test files since ${base:0:12}:"
      printf '%s\n' "$added" | sed 's/^/  /'
    else
      echo "review-fix-loop: check-fix passed — no new files since ${base:0:12}."
    fi
    ;;

  security-due)
    in_work_tree
    from="$(resolve_ref "${1:-}")" || exit 2
    hits=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      reason="$(sensitive_reason "$f")"
      [ -n "$reason" ] && hits="${hits}${f} (${reason})"$'\n'
    done <<< "$(git diff --name-only "$from"..HEAD 2>/dev/null)"
    if [ -n "$hits" ]; then
      echo "yes"
      echo "Security-sensitive paths changed since ${from:0:12} — run the security pass now:"
      printf '%s' "$hits" | sed 's/^/  /'
    else
      echo "no"
      echo "No security-sensitive path changed since ${from:0:12} — the security pass waits for the closing pass."
    fi
    ;;

  *) usage >&2; die_usage "unknown subcommand: $CMD" ;;
esac
