#!/usr/bin/env bash
#
# audit-install.sh - post-install/post-update reliability check for the agent harness.
#
# Compares the consumer project's installed state against a bundle-source tree (a fresh clone, or
# the original install source) to catch files that should have landed but didn't — the failure
# class behind real bugs like a missing adapter command or a missing core/root-REVIEW.md. Every
# copy step in INSTALL.md and core/skills/harness-update/SKILL.md is executed by an agent reading
# prose; this script is the deterministic check that nothing was missed, independent of that.
#
# Usage:
#   audit-install.sh --against <bundle-source-dir> [--json]
#
# <bundle-source-dir> is whatever tree the caller already has on disk to compare against — the
# temporary clone made during an update (.agents/.harness-update-v<latest>), or the original bundle
# source used at install time.
#
# Exit codes: 0 = everything in sync, 1 = at least one gap found, 2 = usage error.
# Dependencies: git + coreutils only. Read-only — never writes or deletes anything.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/.agents/monorepo-agents-harness}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT_SCRIPT="${DETECT_SCRIPT:-$BUNDLE_DIR/core/scripts/detect-monorepo-framework.sh}"

against=""
json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --against) against="${2:-}"; shift 2 ;;
    --json) json=1; shift ;;
    *) echo "audit-install: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$against" ] || [ ! -d "$against" ]; then
  echo "audit-install: --against <bundle-source-dir> is required and must exist" >&2
  exit 2
fi

gaps=()
add_gap() { gaps+=("$1"); }

semver_is_older() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

# --- Check 1: bundle sync (core/, adapters/) — delegate to harness-update.sh verify-copy ---
check_bundle_sync() {
  local label="$1" src="$against/$1" dst="$BUNDLE_DIR/$1" out rc
  [ -d "$src" ] || return 0
  out="$(bash "$SCRIPT_DIR/harness-update.sh" verify-copy "$src" "$dst" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    while IFS= read -r line; do
      case "$line" in
        *"missing after copy:"*) add_gap "bundle ($label): ${line#*missing after copy: }" ;;
      esac
    done <<<"$out"
  fi
}

# --- Check 2: adapter entry-point freshness ---
DENY_BASENAMES="settings.json opencode.jsonc config.toml hooks.json CLAUDE.md README.md INSTALL.md package.json package-lock.json"

is_denied() {
  local base d
  base="$(basename "$1")"
  for d in $DENY_BASENAMES; do
    [ "$base" = "$d" ] && return 0
  done
  return 1
}

required_entrypoints() {
  case "$1" in
    claude-code)
      printf '%s\n' \
        ".claude/commands/monorepo-harness-build.md" \
        ".claude/commands/monorepo-harness/update.md" \
        ".claude/agents/verifier.md"
      ;;
    opencode)
      printf '%s\n' \
        ".opencode/commands/monorepo-harness-build.md" \
        ".opencode/commands/monorepo-harness-update.md"
      ;;
    codex)
      printf '%s\n' \
        ".agents/skills/monorepo-harness-build/SKILL.md" \
        ".agents/skills/monorepo-harness-update/SKILL.md"
      ;;
  esac
}

check_adapter_entrypoints() {
  local agent="$1" adapter_dir="$against/adapters/$1" rel proj_path f req
  [ -d "$adapter_dir" ] || return 0

  while IFS= read -r f; do
    rel="${f#"$adapter_dir"/}"
    is_denied "$rel" && continue
    proj_path="$ROOT/$rel"
    if [ -e "$proj_path" ] && ! cmp -s "$f" "$proj_path"; then
      add_gap "entrypoint stale ($agent): $rel"
    fi
  done < <(find "$adapter_dir" -type f 2>/dev/null)

  while IFS= read -r req; do
    [ -e "$ROOT/$req" ] || add_gap "entrypoint missing ($agent, required): $req"
  done < <(required_entrypoints "$agent")
}

# --- Check 3: root AGENTS.md provenance freshness ---
check_agents_md() {
  local agents_file="$ROOT/AGENTS.md" marker_version installed_version
  if [ ! -f "$agents_file" ]; then
    add_gap "AGENTS.md: missing at repo root"
    return
  fi
  marker_version="$(head -1 "$agents_file" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d 'v')"
  if [ -z "$marker_version" ]; then
    add_gap "AGENTS.md: no provenance marker on line 1 (expected '<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->')"
    return
  fi
  if [ -f "$BUNDLE_DIR/VERSION" ]; then
    installed_version="$(tr -d '[:space:]' <"$BUNDLE_DIR/VERSION")"
  elif [ -f "$BUNDLE_DIR/core/VERSION" ]; then
    installed_version="$(tr -d '[:space:]' <"$BUNDLE_DIR/core/VERSION")"
  else
    return
  fi
  if semver_is_older "$marker_version" "$installed_version" && [ ! -f "$agents_file.harness-proposed" ]; then
    add_gap "AGENTS.md: provenance marker v$marker_version is older than installed v$installed_version, and no AGENTS.md.harness-proposed is present"
  fi
}

# --- Check 4: per-workspace scaffold seeds ---
check_workspace_scaffold() {
  local parents=() parent ws dest f
  if [ -x "$DETECT_SCRIPT" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] && parents+=("$p")
    done < <("$DETECT_SCRIPT" --workspaces 2>/dev/null || true)
  fi
  [ "${#parents[@]}" -eq 0 ] && parents=("$ROOT/apps" "$ROOT/packages")

  for parent in "${parents[@]}"; do
    [ -d "$parent" ] || continue
    for ws in "$parent"/*/; do
      [ -d "$ws" ] || continue
      dest="${ws%/}/.agents"
      for f in session-log.md lessons.md todo.md artifacts/AGENTS.md artifacts/index.md intents/AGENTS.md; do
        [ -e "$dest/$f" ] || add_gap "workspace scaffold missing: ${dest#"$ROOT"/}/$f"
      done
    done
  done
}

check_bundle_sync "core"
check_bundle_sync "adapters"

for agent in claude-code opencode codex; do
  case "$agent" in
    claude-code) [ -d "$ROOT/.claude" ] || continue ;;
    opencode)    [ -d "$ROOT/.opencode" ] || continue ;;
    codex)       [ -d "$ROOT/.agents/skills" ] || continue ;;
  esac
  check_adapter_entrypoints "$agent"
done

check_agents_md
check_workspace_scaffold

if [ "$json" -eq 1 ]; then
  printf '{"status":"%s","gaps":[' "$([ "${#gaps[@]}" -eq 0 ] && echo clean || echo incomplete)"
  for i in "${!gaps[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '"%s"' "$(printf '%s' "${gaps[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  done
  printf ']}\n'
else
  if [ "${#gaps[@]}" -eq 0 ]; then
    echo "audit-install: clean — installed state matches $against"
  else
    echo "audit-install: ${#gaps[@]} gap(s) found against $against" >&2
    for g in "${gaps[@]}"; do
      echo "  - $g" >&2
    done
  fi
fi

[ "${#gaps[@]}" -eq 0 ]
