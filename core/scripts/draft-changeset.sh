#!/usr/bin/env bash
# draft-changeset - deterministic drafts of changesets-compatible release entries from harness task
# artifacts. Agent-agnostic; no dependency on @changesets/cli (compatibility is by file format only).
#
# Reads a task's approved 2_plan.md, derives a summary from the task's memory -> spec -> plan, and
# emits a standard changesets entry -- a '---' frontmatter bump table plus the summary -- to stdout
# (default, --dry-run) or to .changeset/monorepo-harness-<YYYYMMDD>-<slug>-r<N>.md (--write).
#
# A changeset file NEVER carries a concrete version: the v1.0.0-alpha.0 -> v1.0.0-alpha.1 sequence is
# produced by the consumer's own 'changeset pre' + 'changeset version', not by this script. Multiple
# changesets for the same plan are expressed through the revision number 'r<N>' in the filename.
#
# Bump levels are policy, never derived here: every package needs an explicit --package/--bump pair
# (the changeset-workflow skill drives the user confirmation loop that supplies them).
#
# Usage (from the target repo root):
#   draft-changeset.sh <2_plan.md> [--package <name> --bump <major|minor|patch>]...
#                      [--revision N] [--summary <text|auto>] [--changeset-dir <dir>]
#                      [--dry-run] [--write]
#
#   --package <name>  a package (exact package.json name) to bump; repeatable, paired by position
#                     with --bump, equal counts required
#   --bump <level>    one of major|minor|patch for the most recent --package
#   --revision N      changeset sequence number for this task (default 1); a second changeset for the
#                     same plan uses --revision 2, and so on
#   --summary <text>  explicit summary (default: 'auto' - derive from 3_memory.md '## What was
#                     done', else 1_spec.md '## Scope', else 2_plan.md '## Problem')
#   --changeset-dir   directory containing/that will contain changeset files (default: <root>/.changeset)
#   --dry-run         print the changeset to stdout, write nothing (default)
#   --write           create the changeset file and print its path
#
# Exit codes: 0 = success (draft emitted / file written), 1 = guard failure, 2 = usage error.
# Dependencies: git + coreutils (grep/awk/sed). Mirrors the dependency-light style of task-state.sh.

set -euo pipefail

usage() { sed -n '3,27p' "$0"; exit 2; }

root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# frontmatter_field <file> <key> - print the value of a top-level frontmatter key ('key: value'),
# or nothing if the file or key is absent. Same contract as task-state.sh.
frontmatter_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v k="$key" '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR==1 { in_fm=1; next }
    in_fm && $0 ~ /^---[[:space:]]*$/ { exit }
    in_fm && match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*") {
      print substr($0, RSTART+RLENGTH); exit
    }
  ' "$file"
}

# section_first_para <file> <heading> - print the first non-empty paragraph that follows the given
# '## <heading>' section heading, lines collapsed to a single line, one paragraph only ('-' ke "").
section_first_para() {
  local file="$1" heading="$2"
  [ -f "$file" ] || return 1
  local raw
  raw="$(awk -v h="$heading" '
    $0 ~ "^## " h "[[:space:]]*$" { in_sec=1; next }
    in_sec && $0 ~ /^##[[:space:]]/ { exit }
    in_sec && in_para && NF==0 { exit }
    in_sec && NF { print; in_para=1 }
  ' "$file" | tr '\n' ' ' | tr -s ' ' | sed 's/[[:space:]]*$//') "
  [ -n "${raw//[[:space:]]/}" ] || return 1
  printf '%s\n' "$raw"
}

# derive_summary <task_dir> - memory -> spec -> plan, one paragraph, capped for readability.
derive_summary() {
  local dir="$1" s=""
  s="$(section_first_para "$dir/3_memory.md" "What was done" 2>/dev/null || true)"
  [ -n "$s" ] || s="$(section_first_para "$dir/1_spec.md" "Scope" 2>/dev/null || true)"
  [ -n "$s" ] || s="$(section_first_para "$dir/2_plan.md" "Problem" 2>/dev/null || true)"
  [ -n "$s" ] || return 1
  if [ "${#s}" -gt 300 ]; then
    printf '%s…\n' "${s:0:297}"
  else
    printf '%s\n' "$s"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ $# -ge 1 ] || usage

plan="${1:-}"; shift || true
[ -n "$plan" ] || usage

ROOT="$(root)"
cs_dir=""
revision=1
summary_mode="auto"
summary_text=""
write_mode=0
packages=()
bumps=()

while [ $# -gt 0 ]; do
  case "$1" in
    --package) [ -n "${2:-}" ] || usage; packages+=("$2"); shift 2 ;;
    --bump)    [ -n "${2:-}" ] || usage; bumps+=("$2"); shift 2 ;;
    --revision) revision="${2:-}"; [ -n "$revision" ] || usage; shift 2 ;;
    --summary) summary_mode="${2:-}"; shift 2 ;;
    --changeset-dir) cs_dir="${2:-}"; shift 2 ;;
    --dry-run) write_mode=0; shift ;;
    --write)   write_mode=1; shift ;;
    -h|--help) sed -n '3,27p' "$0"; exit 0 ;;
    *) echo "draft-changeset: unknown argument: $1" >&2; usage ;;
  esac
done

fail() { echo "draft-changeset: $1" >&2; exit 1; }

# --- Guard cluster -----------------------------------------------------------------------------
bash "$SCRIPT_DIR/task-state.sh" check-plan "$plan" >/dev/null || exit 1
task_dir="$(cd "$(dirname "$plan")" 2>/dev/null && pwd -P || true)"
[ -n "$task_dir" ] || task_dir="$(dirname "$plan")"

[ -n "$cs_dir" ] || cs_dir="$ROOT/.changeset"
case "$cs_dir" in
  /*) : ;;
  *)  cs_dir="$ROOT/$cs_dir" ;;
esac
[ -d "$cs_dir" ] || fail "no '$cs_dir' directory - this project does not appear to use changesets. Run 'changeset init' (or create .changeset/) if you intend to, then re-run."

[ "${#packages[@]}" -eq 0 ] && fail "no packages given - pass --package <name> --bump <level> pairs (bumps are your policy, never machine-decided)"
[ "${#packages[@]}" -eq "${#bumps[@]}" ] || fail "got ${#packages[@]} --package(s) but ${#bumps[@]} --bump(s) - they must pair one-to-one"
for b in "${bumps[@]}"; do
  case "$b" in
    major|minor|patch) : ;;
    *) fail "invalid bump '$b' - use major, minor, or patch" ;;
  esac
done
if [ -z "${revision//[0-9]/}" ] && [ "$revision" -gt 0 ] 2>/dev/null; then :; else
  fail "invalid --revision '$revision' - a positive integer"
fi
if [ "$summary_mode" = "auto" ]; then
  summary="$(derive_summary "$task_dir" || true)"
  [ -n "$summary" ] || fail "could not derive a summary (no memory/spec/plan paragraph) - pass --summary '<text>'"
else
  summary="$summary_mode"
fi

# --- Deterministic filename --------------------------------------------------------------------
date_fm="$(frontmatter_field "$plan" date || true)"
date_fm="${date_fm//[^0-9]/}"
[ "${#date_fm}" -eq 8 ] || date_fm="$(date +%Y%m%d)"
slug="$(frontmatter_field "$plan" slug || true)"
slug="${slug//[^a-z0-9_]/}"
if [ -z "$slug" ]; then
  base="$(basename "$task_dir")"
  slug="${base#task_${date_fm}_}"
  [ -n "$slug" ] || fail "no 'slug:' frontmatter in '$plan' and the task dir name carries no slug"
fi

out="$cs_dir/monorepo-harness-$date_fm-$slug-r$revision.md"
if [ -e "$out" ]; then
  # Suggest the next revision for this task, so re-runs guide instead of puzzle.
  next=1
  for f in "$cs_dir"/monorepo-harness-$date_fm-$slug-r*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" | sed -n 's/.*-r\([0-9][0-9]*\)\.md$/\1/p')"
    [ -n "$n" ] && [ "$n" -ge "$next" ] && next=$((n + 1))
  done
  fail "changeset already exists: $out - re-running with the same revision would duplicate it. Use --revision $next for the next changeset from this plan (each plan revision/merge gets its own changeset)."
fi

# --- Emit --------------------------------------------------------------------------------------
frontmatter="---\n"
for i in "${!packages[@]}"; do
  name="${packages[$i]}"
  [ -n "$name" ] || fail "empty --package name at position $((i + 1))"
  frontmatter+="\"$name\": ${bumps[$i]}\n"
done
frontmatter+="---"

if [ "$write_mode" -eq 1 ]; then
  printf '%b\n\n%s\n\n<!-- task: %s; revision: %s -->\n' \
    "$frontmatter" "$summary" "${task_dir#"$ROOT"/}" "$revision" > "$out"
  echo "draft-changeset: wrote $out"
else
  printf 'draft-changeset: would write %s (run with --write to create it)\n' "${out#"$ROOT"/}"
  printf '%b\n\n%s\n\n<!-- task: %s; revision: %s -->\n' \
    "$frontmatter" "$summary" "${task_dir#"$ROOT"/}" "$revision"
fi