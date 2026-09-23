#!/usr/bin/env bash
# kb-ingest — incremental knowledge-base ingest for ONE task directory, at task end. Agent-agnostic.
#
# The repo-root knowledge/ layer (Karpathy "LLM Wiki": compile once, keep current) is updated from a
# finished task's artifacts. This script performs the deterministic parts (structure, catalog rows,
# log entry, ADR copies, page skeletons); the agent then fills the synthesis prose
# (core/skills/knowledge-base/SKILL.md + knowledge/schema.md). /monorepo-harness-build calls it
# (WRITE mode) right after 3_memory.md / 4_verify.md / adr/ are written, so the KB update lands in
# the same commit — there is no batch/backfill compiler. Running it twice is idempotent.
#
# No task memory (research-only / N/A) => clean no-op (exit 0), nothing written.
#
# USAGE:
#   bash kb-ingest.sh <task_dir> [--kb <root>] [--write|--dry-run]
#
#     <task_dir>  the task's artifact directory:
#                 <workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/
#     --kb <root> knowledge/ root (default: <git toplevel>/knowledge)
#     --write     write the mechanical KB updates (DEFAULT)
#     --dry-run   print what would change, write nothing
#
# Exit codes: 0 = ok (no-op, dry-run, or written), 1 = missing input / broken KB, 2 = usage error.

set -euo pipefail

GIT_TOP="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
KB="${KB:-$GIT_TOP/knowledge}"
WRITE=1
TASK_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --kb) KB="${2:-}"; [ -n "$KB" ] || { echo "kb-ingest: --kb needs a path" >&2; exit 2; }; shift 2 ;;
    --write) WRITE=1; shift ;;
    --dry-run) WRITE=0; shift ;;
    -h|--help) sed -n '1,35p' "$0"; exit 0 ;;
    *) [ -z "$TASK_DIR" ] || { echo "kb-ingest: usage error (extra arg '$1')" >&2; exit 2; }
       TASK_DIR="$1"; shift ;;
  esac
done

[ -n "$TASK_DIR" ] || { echo "kb-ingest: usage: kb-ingest.sh <task_dir> [--kb <root>] [--write|--dry-run]" >&2; exit 2; }
[ -d "$TASK_DIR" ] || { echo "kb-ingest: task dir '$TASK_DIR' does not exist" >&2; exit 1; }

# Research-only / N/A tasks have no 3_memory.md — nothing to ingest.
[ -f "$TASK_DIR/3_memory.md" ] || { echo "kb-ingest: no 3_memory.md in $TASK_DIR — research-only / N/A, nothing to ingest"; exit 0; }

# KB must be seeded (knowledge/schema.md present) before anything can be ingested.
[ -f "$KB/schema.md" ] || { echo "kb-ingest: KB root '$KB' has no schema.md — seed knowledge/ first (core/knowledge-template/, core/scripts/scaffold-knowledge.sh)" >&2; exit 1; }

slug="$(basename "$TASK_DIR")"
rel="${TASK_DIR#"$GIT_TOP"/}"
mode="WRITE"; [ "$WRITE" -eq 0 ] && mode="DRY-RUN"

echo "kb-ingest: task $slug → KB '$KB' (mode: $mode)"

# echo = trace of an action; wf = write a file (or trace in dry-run).
w() { if [ "$WRITE" -eq 1 ]; then printf '%s\n' "$2" > "$1"; else echo "kb-ingest:   (dry-run) $1"; fi; }
act() { if [ "$WRITE" -eq 1 ]; then echo "kb-ingest:   $1"; else echo "kb-ingest:   (dry-run) $1"; fi; }

# --- 1. module page — derive workspace from the task path under apps|packages|libs ---------------
ws=""
for root in apps packages libs; do
  case "$rel" in
    "$root"/*) ws="${rel#"$root"/}"; ws="${ws%%/*}"; break ;;
  esac
done
[ -n "$ws" ] || ws="project"
module_page="$KB/modules/$ws.md"
if [ -f "$module_page" ]; then
  act "module modules/$ws.md exists (agent: enrich 'Key facts' if this task adds durable facts)"
else
  if [ "$WRITE" -eq 1 ]; then
    { echo "# Module: $ws"
      echo
      echo "<!-- Compiled by kb-ingest.sh; prose authored by the agent per knowledge/schema.md. -->"
      echo
      echo "## Key facts"
      echo
      echo "- "
      echo
      echo "## Sources"
      echo
      echo "- \`$rel/3_memory.md\`"
    } > "$module_page"
    echo "kb-ingest:   created modules/$ws.md"
  else
    echo "kb-ingest:   (dry-run) would create modules/$ws.md"
  fi
fi

# --- 2. decision-records/: one cited copy per adr/NNNN-*.md ---------------------------------------
adr_count=0
for adr in "$TASK_DIR"/adr/*.md; do
  [ -f "$adr" ] || continue
  adr_count=$((adr_count + 1))
  base="$(basename "$adr")"
  target="$KB/decision-records/$base"
  if [ -f "$target" ]; then
    act "update decision-records/$base (source ADR changed)"
  else
    act "new   decision-records/$base (compiled from $rel/adr/$base)"
  fi
  [ "$WRITE" -eq 1 ] && cp "$adr" "$target"
done

# --- 3. verified-facts/: skeleton from 4_verify.md when present ------------------------------------
vf_page=""
if [ -f "$TASK_DIR/4_verify.md" ]; then
  vf_page="$KB/verified-facts/$slug.md"
  if [ -f "$vf_page" ]; then
    act "verified-facts/$slug.md exists (agent: add/refresh claims per 4_verify.md)"
  else
    if [ "$WRITE" -eq 1 ]; then
      { echo "# Verified facts: $slug"
        echo
        echo "Compiled from: \`$rel/4_verify.md\`"
        echo
        echo "## Claims verified"
        echo
        echo "- "
      } > "$vf_page"
      echo "kb-ingest:   created verified-facts/$slug.md"
    else
      echo "kb-ingest:   (dry-run) would create verified-facts/$slug.md"
    fi
  fi
else
  act "no 4_verify.md → no verified-facts page for this task"
fi

# --- 4. sources/: synopsis page -------------------------------------------------------------------
src_page="$KB/sources/$slug.md"
if [ -f "$src_page" ]; then
  act "sources/$slug.md exists (agent: refresh synopsis if the task tells something new)"
else
  if [ "$WRITE" -eq 1 ]; then
    { echo "# Source: $slug"
      echo
      echo "Raw task dir: \`$rel\`"
      echo
      echo "<!-- One-paragraph synopsis written by the agent (knowledge-base skill). -->"
    } > "$src_page"
    echo "kb-ingest:   created sources/$slug.md"
  else
    echo "kb-ingest:   (dry-run) would create sources/$slug.md"
  fi
fi

# --- 5. log.md append (dedup by task slug + timestamp) + index.md catalog rows ----------------------
log_row="| $(date +%Y-%m-%d) | ingest | $slug | synopsis, [$( [ $adr_count -gt 0 ] && echo "ADR x$adr_count, " || true)$( [ -n "$vf_page" ] && echo "verified facts, " || true)module/concept] sources/$slug.md |"
if [ "$WRITE" -eq 1 ]; then
  if grep -qF "| ingest | $slug |" "$KB/log.md" 2>/dev/null; then
    echo "kb-ingest:   log.md already has an ingest row for $slug — not duplicated"
  else
    printf '%s\n' "$log_row" >> "$KB/log.md"
    echo "kb-ingest:   appended log.md row for $slug"
  fi
else
  echo "kb-ingest:   (dry-run) would append log.md row for $slug"
fi

catalog_row () { # <section-header> <row text> — append row to the section if absent
  local section="$1" row="$2"
  if [ "$WRITE" -eq 1 ]; then
    if grep -qF "$row" "$KB/index.md"; then
      echo "kb-ingest:   index.md already has: $row"
    else
      # Insert right after the matching `### Section` header line plus its header row line.
      awk -v sec="$section" -v row="$row" '
        insert { print row; inserted=1; insert=0 }
        $0 == "### " sec { print; print "| Page | Overview |"; print "| ---- | -------- |"; insert=1; next }
        1
        END { if (!inserted) exit 1 }
      ' "$KB/index.md" > "$KB/index.md.tmp" && mv "$KB/index.md.tmp" "$KB/index.md" \
        || { echo "kb-ingest: section '### $section' not found in $KB/index.md" >&2; exit 1; }
      echo "kb-ingest:   index.md += $row"
    fi
  else
    echo "kb-ingest:   (dry-run) index.md += $row"
  fi
}

catalog_row "Sources (per-task synopses)" "| $slug | [$slug](sources/$slug.md) | $rel |"
if [ "$adr_count" -gt 0 ]; then
  for adr in "$TASK_DIR"/adr/*.md; do
    [ -f "$adr" ] || continue
    base="$(basename "$adr")"
    catalog_row "Decision records (compiled from adr/)" "| $base | $(head -1 "$adr" | tr -d '#') — [decision-records/$base](decision-records/$base) |"
  done
fi
if [ -n "$vf_page" ]; then
  catalog_row "Verified facts (from 4_verify.md)" "| $slug | Claims from $rel/4_verify.md — [verified-facts/$slug.md](verified-facts/$slug.md) |"
fi

echo "kb-ingest: done. Run 'task-state.sh check-kb $TASK_DIR' to verify coverage."
exit 0