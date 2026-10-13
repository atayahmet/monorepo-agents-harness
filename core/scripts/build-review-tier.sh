#!/usr/bin/env bash
# build-review-tier — decide how strongly to suggest a review when a build finishes. Agent-agnostic.
#
# `/monorepo-harness-build` ends by pointing the developer at `/monorepo-harness-review` (issue #41).
# The strength of that prompt is decided here, deterministically, so every adapter reaches the same
# answer and a test can assert it — the model only presents the result (issue #41).
#
# Two signals:
#   - changed files  — the union of the files in the task's `3_memory.md` `commits:`, falling back to
#                      the bullet count of `## Affected files / modules` in `2_plan.md`.
#   - architectural  — any `adr/*.md` file, or a non-`N/A` body under `## Architectural decisions`,
#                      `## API / contracts` or `## Data model` in `1_spec.md`.
#
# Tier rule: <=3 changed files AND no architectural signal -> `simple`; otherwise `comprehensive`.
#
# Usage:
#   build-review-tier.sh <task_dir>
#
# Output: line 1 is exactly `simple` or `comprehensive`; the rest explains the decision.
# Advisory by design: it never blocks. Exit codes: 0 = decided, 2 = usage error.
set -uo pipefail

THRESHOLD=3

usage() { sed -n '2,20p' "$0"; }

TASK_DIR="${1:-}"
case "$TASK_DIR" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
if [ ! -d "$TASK_DIR" ]; then
  echo "build-review-tier: not a directory: $TASK_DIR" >&2
  exit 2
fi

SPEC="$TASK_DIR/1_spec.md"
PLAN="$TASK_DIR/2_plan.md"
MEMORY="$TASK_DIR/3_memory.md"

# Shas from the memory frontmatter `commits:`, accepting both the inline form
# `commits: [sha1, sha2]` and the YAML list form (`commits:` then `  - sha`).
parse_commits() {
  awk '
    /^commits:/ {
      line = $0; sub(/^commits:[[:space:]]*/, "", line); gsub(/[][,]/, " ", line)
      n = split(line, a, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (a[i] ~ /^[0-9a-fA-F]{7,40}$/) print a[i]
      inlist = 1; next
    }
    inlist && /^[[:space:]]*-[[:space:]]*/ {
      v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); gsub(/[][,]/, " ", v)
      n = split(v, a, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (a[i] ~ /^[0-9a-fA-F]{7,40}$/) print a[i]
      next
    }
    inlist && /^[^[:space:]]/ { inlist = 0 }
  ' "$1" 2>/dev/null
}

# Bullet lines under `## Affected files / modules` in the plan, minus a lone `- none`.
plan_affected_count() {
  awk '
    /^## Affected files \/ modules/ { in_s = 1; next }
    /^## / { if (in_s) exit }
    in_s && /^[[:space:]]*-[[:space:]]*/ {
      v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v)
      if (v != "" && v !~ /^none$/i) c++
    }
    END { print c + 0 }
  ' "$1" 2>/dev/null
}

# Body of a `## <heading>` section (until the next `## `), trimmed. Empty when absent.
section_body() {
  awk -v h="## $2" '
    $0 == h { in_s = 1; next }
    /^## / { if (in_s) exit }
    in_s { print }
  ' "$1" 2>/dev/null
}

# True (0) when the section is absent, empty, or its first non-blank line starts with `N/A`.
section_is_na() {
  local first
  first="$(section_body "$1" "$2" | sed -n '/[^[:space:]]/{s/^[[:space:]]*//; p; q;}')"
  [ -z "$first" ] && return 0
  case "$first" in N/A*|n/a*) return 0 ;; esac
  return 1
}

REPO_ROOT="$(git -C "$TASK_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

file_count=0
file_source="none"
if [ -n "$REPO_ROOT" ] && [ -f "$MEMORY" ]; then
  files="$(
    parse_commits "$MEMORY" | while IFS= read -r sha; do
      [ -n "$sha" ] && git -C "$REPO_ROOT" show --name-only --format= "$sha" 2>/dev/null
    done | sed '/^$/d' | sort -u
  )"
  if [ -n "$files" ]; then
    file_count="$(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"
    file_source="memory commits"
  fi
fi
if [ "$file_source" = "none" ] && [ -f "$PLAN" ]; then
  file_count="$(plan_affected_count "$PLAN")"
  file_source="plan affected files"
fi

signal=""
if compgen -G "$TASK_DIR/adr/*.md" >/dev/null 2>&1; then
  signal="adr/ present"
fi
for sec in "Architectural decisions" "API / contracts" "Data model"; do
  if [ -f "$SPEC" ] && ! section_is_na "$SPEC" "$sec"; then
    [ -n "$signal" ] && signal="$signal; "
    signal="${signal}spec '$sec' is not N/A"
  fi
done

if [ "$file_count" -le "$THRESHOLD" ] && [ -z "$signal" ]; then
  tier="simple"
else
  tier="comprehensive"
fi

printf '%s\n' "$tier"
printf 'changed files: %s (%s)\n' "$file_count" "$file_source"
printf 'architectural signal: %s\n' "${signal:-none}"
exit 0
