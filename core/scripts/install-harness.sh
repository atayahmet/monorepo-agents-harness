#!/usr/bin/env bash
#
# install-harness.sh - Phase 1 (core) install of the agent harness, deterministically.
#
# Executes core/install-manifest.txt instead of asking an agent to interpret prose copy steps —
# the failure class behind every "a file never reached the consumer project" bug so far.
# Idempotent: safe to re-run. Never deletes anything; replaced content is moved into
# .agents/.harness-trash/<timestamp>_<pid>/ (purge it yourself with cleanup-harness-trash.sh).
#
# Usage (run from the TARGET repo root):
#   git clone --depth 1 https://github.com/atayahmet/monorepo-agents-harness .agents/.harness-install
#   bash .agents/.harness-install/core/scripts/install-harness.sh
#
#   install-harness.sh [--from <dir>] [--project-name <name>] [--no-git-hook] [--sync-only]
#
#   --from <dir>        bundle source to install from (default: this script's own bundle root)
#   --project-name <n>  value for {{PROJECT_NAME}} (default: package.json .name, else repo dir name)
#   --no-git-hook       do not wire core/scripts/memory-gate.sh as .git/hooks/pre-commit
#   --sync-only         sync the bundle files only; skip AGENTS.md, workspace scaffolding and the
#                       git hook. This is the mode a harness UPDATE uses.
#
# Exit codes: 0 = installed and verified, 1 = something did not land (never claims success),
# 2 = usage error. Dependencies: git + coreutils.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/harness-common.sh"

SRC="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_NAME=""
WIRE_GIT_HOOK=1
SYNC_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --from)         SRC="${2:-}"; shift 2 ;;
    --project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    --no-git-hook)  WIRE_GIT_HOOK=0; shift ;;
    --sync-only)    SYNC_ONLY=1; shift ;;
    -h|--help)      sed -n '3,23p' "$0"; exit 0 ;;
    *) echo "install-harness: unknown argument: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(harness_root)"
DEST="$ROOT/.agents/monorepo-agents-harness"
MANIFEST="$SRC/core/install-manifest.txt"

[ -d "$SRC" ] || { echo "install-harness: source dir not found: $SRC" >&2; exit 2; }
SRC="$(cd "$SRC" && pwd -P)"
[ -f "$MANIFEST" ] || { echo "install-harness: not a harness bundle (no core/install-manifest.txt): $SRC" >&2; exit 2; }

if [ -d "$DEST" ]; then
  dest_real="$(cd "$DEST" && pwd -P)"
  case "$SRC" in
    "$dest_real"|"$dest_real"/*)
      echo "install-harness: refusing to install from the installed bundle itself ($SRC)." >&2
      echo "install-harness: that is an update — see core/skills/harness-update/SKILL.md." >&2
      exit 2 ;;
  esac
fi

TRASH=""
followups=()
problems=0

ensure_trash() { [ -n "$TRASH" ] || TRASH="$(harness_trash_dir "$ROOT")"; }
note()  { followups+=("$1"); }
fail()  { echo "install-harness: $1" >&2; problems=$((problems + 1)); }

# --- 1. Sync every manifest row into the installed bundle -----------------------------------
mkdir -p "$DEST"
rows=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  src_path="$SRC/$row"
  dst_path="$DEST/$row"
  if [ ! -e "$src_path" ]; then
    fail "manifest row missing from the source bundle: $row"
    continue
  fi
  mkdir -p "$(dirname "$dst_path")"
  if [ -e "$dst_path" ]; then
    ensure_trash
    mv "$dst_path" "$TRASH/${row//\//_}" || { fail "could not move aside: $row"; continue; }
  fi
  cp -R "$src_path" "$dst_path" || { fail "could not copy: $row"; continue; }
  rows=$((rows + 1))
  echo "  + $row"
done < <(harness_manifest_rows "$MANIFEST")

# --- 2. Verify the sync deterministically ---------------------------------------------------
while IFS= read -r row; do
  [ -n "$row" ] || continue
  if [ -d "$SRC/$row" ]; then
    bash "$DEST/core/scripts/harness-update.sh" verify-copy "$SRC/$row" "$DEST/$row" >/dev/null \
      || fail "verify failed for directory row: $row"
  elif [ -f "$SRC/$row" ] && ! cmp -s "$SRC/$row" "$DEST/$row"; then
    fail "verify failed for file row: $row"
  fi
done < <(harness_manifest_rows "$MANIFEST")

if [ "$problems" -ne 0 ]; then
  echo "install-harness: $problems problem(s) — install is INCOMPLETE, not proceeding" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' <"$DEST/VERSION" 2>/dev/null || true)"
echo "install-harness: synced $rows manifest row(s) — harness v${VERSION:-unknown}"

if [ "$SYNC_ONLY" -eq 1 ]; then
  [ -n "$TRASH" ] && echo "install-harness: previous copies moved to ${TRASH#"$ROOT"/}"
  exit 0
fi

# --- 3. Root AGENTS.md ----------------------------------------------------------------------
[ -n "$PROJECT_NAME" ] || PROJECT_NAME="$(harness_project_name "$ROOT")"
FRAMEWORK="$(harness_framework "$DEST/core/scripts/detect-monorepo-framework.sh")"

if [ ! -e "$ROOT/AGENTS.md" ]; then
  { printf '<!-- monorepo-agents-harness: root-AGENTS.md v%s -->\n\n' "$VERSION"
    harness_resolve_placeholders "$DEST/core/root-AGENTS.md" "$PROJECT_NAME" "$FRAMEWORK"
  } >"$ROOT/AGENTS.md" || fail "could not write AGENTS.md"
  echo "  + AGENTS.md (project: $PROJECT_NAME, framework: $FRAMEWORK)"
  note "Fill in {{PROJECT_GOTCHAS}} in AGENTS.md (or delete the example item) — only you know your project's rules."
else
  echo "  = AGENTS.md exists — left untouched"
  note "AGENTS.md already existed: reconcile it with core/skills/agents-md-merge/SKILL.md (it keeps 100% of your content and asks before writing)."
fi

# --- 4. Per-workspace state -----------------------------------------------------------------
bash "$DEST/core/scripts/scaffold-workspace-agents.sh" || fail "workspace scaffolding failed"

# --- 5. Universal hard gate -----------------------------------------------------------------
if [ "$WIRE_GIT_HOOK" -eq 1 ]; then
  chmod +x "$DEST/core/scripts/memory-gate.sh" 2>/dev/null || true
  hook_target="../../.agents/monorepo-agents-harness/core/scripts/memory-gate.sh"
  if [ ! -d "$ROOT/.git/hooks" ]; then
    note "No .git/hooks directory — wire core/scripts/memory-gate.sh into CI instead (INSTALL.md)."
  elif [ -L "$ROOT/.git/hooks/pre-commit" ] && [ "$(readlink "$ROOT/.git/hooks/pre-commit")" = "$hook_target" ]; then
    echo "  = .git/hooks/pre-commit already wired to memory-gate.sh"
  elif [ -e "$ROOT/.git/hooks/pre-commit" ]; then
    note "A .git/hooks/pre-commit already exists — add 'bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh' to it yourself."
  else
    ln -s "$hook_target" "$ROOT/.git/hooks/pre-commit" \
      && echo "  + .git/hooks/pre-commit -> memory-gate.sh" \
      || note "Could not create .git/hooks/pre-commit — wire memory-gate.sh manually."
  fi
fi

# --- 6. Move the temporary clone aside ------------------------------------------------------
case "$SRC" in
  "$ROOT"/.agents/.harness-install*)
    ensure_trash
    mv "$SRC" "$TRASH/harness-install-clone" && echo "  - moved the install clone to trash" ;;
esac

# --- 7. Report ------------------------------------------------------------------------------
echo
echo "install-harness: core installed (v${VERSION:-unknown})."
echo "install-harness: next -> bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <claude-code|codex|opencode>"
if [ "${#followups[@]}" -gt 0 ]; then
  echo
  echo "Needs you:"
  for f in "${followups[@]}"; do echo "  - $f"; done
fi
if [ -n "$TRASH" ]; then
  echo
  echo "Replaced copies were moved (never deleted) to ${TRASH#"$ROOT"/}"
  echo "Purge whenever you like: bash .agents/monorepo-agents-harness/core/scripts/cleanup-harness-trash.sh"
fi

[ "$problems" -eq 0 ]
