#!/usr/bin/env bash
# write-intent-ref — mechanically create a 0_intent.md reference stub.
#
# Usage:
#   write-intent-ref.sh <task_dir> <intent_path>
#
# The intent file must exist and have `status: approved`. The output file is
# <task_dir>/0_intent.md and contains only a phase: intent-ref stub linking back
# to the original intent file — never a copy of its content.
#
# Exit codes: 0 = stub written, 1 = error (intent not approved, path issues, etc.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() { echo "write-intent-ref: $1" >&2; exit 1; }

[ "$#" -eq 2 ] || fail "usage: write-intent-ref.sh <task_dir> <intent_path>"

task_dir="$1"
intent_path="$2"

[ -d "$task_dir" ] || fail "task directory '$task_dir' does not exist"
[ -f "$intent_path" ] || fail "intent file '$intent_path' does not exist"

# Resolve absolute paths so relative-path arithmetic is reliable.
if command -v realpath >/dev/null 2>&1; then
  abs_task_dir="$(realpath "$task_dir")"
  abs_intent="$(realpath "$intent_path")"
else
  abs_task_dir="$(cd "$task_dir" && pwd -P)"
  abs_intent="$(cd "$(dirname "$intent_path")" && pwd -P)/$(basename "$intent_path")"
fi

# Verify approval before writing anything.
if ! bash "$SCRIPT_DIR/task-state.sh" check-intent-approved "$abs_intent" >/dev/null; then
  fail "intent '$intent_path' is not approved; refusing to write 0_intent.md"
fi

# Compute the path from the task directory to the intent file.
if command -v realpath >/dev/null 2>&1 && realpath --relative-to="$abs_task_dir" "$abs_intent" >/dev/null 2>&1; then
  rel_source="$(realpath --relative-to="$abs_task_dir" "$abs_intent")"
else
  # Portable fallback using Python, which is available on nearly all developer
  # machines and avoids a large pure-bash relative-path implementation.
  if command -v python3 >/dev/null 2>&1; then
    rel_source="$(python3 -c "import os.path, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$abs_intent" "$abs_task_dir")"
  else
    fail "realpath --relative-to or python3 is required to compute the relative source path"
  fi
fi

# Prefer a clean relative path without leading ./ when possible.
rel_source="${rel_source#./}"

out_file="$abs_task_dir/0_intent.md"
today="$(date +%Y-%m-%d)"

cat > "$out_file" <<EOF
---
phase: intent-ref
date: $today
source: $rel_source
---

# Intent reference

Seeded by the approved intent at [$rel_source]($rel_source) — see that file for the full problem
statement, proposed outcome, constraints, and review decision. This stub only records where the
source of truth lives; it is never a copy.
EOF

echo "write-intent-ref: wrote $out_file -> $rel_source"
