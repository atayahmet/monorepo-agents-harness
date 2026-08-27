#!/usr/bin/env bash
#
# cleanup-harness-trash.sh - purge .agents/.harness-trash/.
#
# core/skills/harness-update/SKILL.md and INSTALL.md never delete anything directly — they `mv`
# old copies aside into .agents/.harness-trash/<run>/ instead of `rm -rf`, so the install/update
# flow keeps working even under a permission policy that blocks destructive commands for an agent.
# This script is the other half of that: your own explicit, standalone command to actually free the
# disk space, run whenever *you* choose to, under your own permission context — never invoked
# automatically by anything else in this bundle.
#
# Usage:
#   cleanup-harness-trash.sh          purge .agents/.harness-trash/ entirely
#   cleanup-harness-trash.sh --list   show what's in there without deleting anything
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TRASH="$ROOT/.agents/.harness-trash"

if [ "${1:-}" = "--list" ]; then
  if [ -d "$TRASH" ]; then
    find "$TRASH" -mindepth 1 -maxdepth 2
  else
    echo "cleanup-harness-trash: nothing in $TRASH"
  fi
  exit 0
fi

if [ ! -d "$TRASH" ]; then
  echo "cleanup-harness-trash: nothing to clean ($TRASH does not exist)"
  exit 0
fi

du -sh "$TRASH" 2>/dev/null || true
rm -rf "$TRASH"
echo "cleanup-harness-trash: removed $TRASH"
