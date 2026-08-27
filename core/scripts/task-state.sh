#!/usr/bin/env bash
# task-state — read-only validation of the per-SDLC-stage artifact chain. Agent-agnostic.
#
# The stage commands (/monorepo-harness-spec, -plan, -build) call this before acting so a stage can
# never be run against a stale or unwarranted input. It mirrors the frontmatter-parsing style of
# memory-gate.sh (plain grep/sed, no dependencies).
#
# Subcommands (each prints a reason on stdout and exits 1 on failure, 0 on success):
#   check-intent-approved <intent.md>  — file exists AND frontmatter has `status: approved`.
#   check-spec <spec.md>               — file exists AND frontmatter has `phase: spec`.
#   check-plan <plan.md>               — file exists AND frontmatter has `phase: plan`.
#   check-chain <plan.md>              — the plan's task dir also has a `1_spec.md`; and, when the
#                                        task was seeded by an intent (a `0_intent.md` is present),
#                                        that intent is approved. Ad-hoc tasks (no `0_intent.md`)
#                                        are exempt from the intent requirement.
#
# Web usage (from the shared bundle root in a consumer project):
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved \
#        apps/api/.agents/intents/intent_2026_08_27_add_auth.md
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-chain \
#        apps/api/.agents/artifacts/task_2026_08_27_add_auth/2_plan.md

set -euo pipefail

cmd="${1:-}"
[ -n "$cmd" ] || { echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain> <path>" >&2; exit 2; }
path="${2:-}"
[ -n "$path" ] || { echo "usage: task-state.sh $cmd <path>" >&2; exit 2; }

# frontmatter_field <file> <key> — print the value of a top-level frontmatter key (`key: value`),
# or nothing if the file or key is absent. Only the first fenced `---` block is treated as
# frontmatter; regex-anchored so `key:` values are not matched mid-block.
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

fail() { echo "task-state: $cmd — $1" >&2; exit 1; }

case "$cmd" in
  check-intent-approved)
    [ -f "$path" ] || fail "intent file '$path' missing"
    value="$(frontmatter_field "$path" status || true)"
    [ "$value" = "approved" ] || fail "intent '$path' is not approved (status: '${value:-<none>}')"
    echo "task-state: intent approved — $path"
    ;;
  check-spec)
    [ -f "$path" ] || fail "spec file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "spec" ] || fail "'$path' is not a spec (phase: '${value:-<none>}')"
    echo "task-state: spec valid — $path"
    ;;
  check-plan)
    [ -f "$path" ] || fail "plan file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "plan" ] || fail "'$path' is not a plan (phase: '${value:-<none>}')"
    echo "task-state: plan valid — $path"
    ;;
  check-chain)
    dir="$(dirname "$path")"
    [ -f "$path" ] || fail "plan file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "plan" ] || fail "'$path' is not a plan (phase: '${value:-<none>}')"
    [ -f "$dir/1_spec.md" ] || fail "task dir '$dir' is missing 1_spec.md"
    if [ -f "$dir/0_intent.md" ]; then
      ival="$(frontmatter_field "$dir/0_intent.md" status || true)"
      [ "$ival" = "approved" ] || \
        fail "task '$dir' is intent-seeded (0_intent.md) but that intent is not approved (status: '${ival:-<none>}')"
      echo "task-state: chain valid — spec + plan present, intent approved — $dir"
    else
      echo "task-state: chain valid — spec + plan present, ad-hoc (no intent required) — $dir"
    fi
    ;;
  *)
    echo "task-state: unknown subcommand '$cmd'" >&2
    echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain> <path>" >&2
    exit 2
    ;;
esac
