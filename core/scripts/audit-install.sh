#!/usr/bin/env bash
#
# audit-install.sh - post-install/post-update reliability check for the agent harness.
#
# Compares the consumer project's installed state against a bundle-source tree (a fresh clone, or
# the original install source) to catch files that should have landed but didn't — the failure
# class behind real bugs like a missing adapter command or a missing core/root-REVIEW.md.
#
# The expected state is read from the same manifests the installers execute — the bundle whitelist
# core/install-manifest.txt and each adapters/<agent>/manifest.txt — so this check and the install
# can never disagree about what "complete" means.
#
# Usage:
#   audit-install.sh [--against <bundle-source-dir>] [--json]
#
# <bundle-source-dir> defaults to the installed bundle (.agents/monorepo-agents-harness), which
# answers "does my project match the harness I have installed?" — the useful question after an
# install. Point it at a fresh clone (.agents/.harness-update-v<latest>) to instead ask "did this
# update land completely?".
#
# Exit codes: 0 = everything in sync, 1 = at least one gap found, 2 = usage error.
# Dependencies: git + coreutils only. Read-only — never writes or deletes anything.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/harness-common.sh"

ROOT="$(harness_root)"
BUNDLE_DIR="${BUNDLE_DIR:-$ROOT/.agents/monorepo-agents-harness}"
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

[ -n "$against" ] || against="$BUNDLE_DIR"
if [ ! -d "$against" ]; then
  echo "audit-install: no bundle to compare against: $against" >&2
  exit 2
fi

gaps=()
add_gap() { gaps+=("$1"); }

# --- Check 1: bundle sync — every core/install-manifest.txt row, via harness-update.sh verify-copy ---
check_bundle_sync() {
  local manifest="$against/core/install-manifest.txt" row src dst out rc
  if [ ! -f "$manifest" ]; then
    add_gap "bundle: core/install-manifest.txt missing from $against (not a harness bundle?)"
    return
  fi
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    src="$against/$row"
    dst="$BUNDLE_DIR/$row"
    if [ ! -e "$src" ]; then
      add_gap "bundle: manifest row missing from the source: $row"
      continue
    fi
    if [ ! -e "$dst" ]; then
      add_gap "bundle: not installed: $row"
      continue
    fi
    if [ -d "$src" ]; then
      out="$(bash "$SCRIPT_DIR/harness-update.sh" verify-copy "$src" "$dst" 2>&1)"
      rc=$?
      if [ "$rc" -ne 0 ]; then
        while IFS= read -r line; do
          case "$line" in
            *"missing after copy:"*) add_gap "bundle ($row): ${line#*missing after copy: }" ;;
          esac
        done <<<"$out"
      fi
    elif ! cmp -s "$src" "$dst"; then
      add_gap "bundle stale: $row"
    fi
  done < <(harness_manifest_rows "$manifest")
}

# --- Check 2: adapter entry points, driven by adapters/<agent>/manifest.txt ---
# copy/link rows must exist and match; merge/tmpl rows are user-owned config — their *absence* is a
# gap (the adapter is not wired), but their content is never compared, because a project is
# supposed to customize them.
check_adapter_entrypoints() {
  local agent="$1" adapter_dir="$against/adapters/$1" manifest verb path target
  [ -d "$adapter_dir" ] || return 0
  manifest="$adapter_dir/manifest.txt"
  if [ ! -f "$manifest" ]; then
    add_gap "adapter ($agent): manifest.txt missing from $adapter_dir"
    return
  fi
  while read -r verb path target; do
    [ -n "${verb:-}" ] || continue
    case "$verb" in
      copy)
        if [ ! -e "$ROOT/$path" ]; then
          add_gap "entrypoint missing ($agent): $path"
        elif ! cmp -s "$adapter_dir/$path" "$ROOT/$path"; then
          add_gap "entrypoint stale ($agent): $path"
        fi
        ;;
      link)
        if [ ! -e "$ROOT/$path" ]; then
          add_gap "entrypoint missing ($agent, symlink): $path"
        elif [ ! -L "$ROOT/$path" ]; then
          add_gap "entrypoint should be a symlink into the bundle ($agent): $path"
        fi
        ;;
      merge|tmpl)
        [ -e "$ROOT/$path" ] || add_gap "config missing ($agent): $path"
        ;;
      *) add_gap "adapter ($agent): unknown manifest verb '$verb'" ;;
    esac
  done < <(harness_manifest_rows "$manifest")
}

# --- Check 3: root AGENTS.md provenance freshness ---
check_agents_md() {
  local agents_file="$ROOT/AGENTS.md" marker_version installed_version
  if [ ! -f "$agents_file" ]; then
    add_gap "AGENTS.md: missing at repo root"
    return
  fi
  # Prerelease suffixes are part of the version — v0.1.0-rc.0 must not read as v0.1.0.
  marker_version="$(head -1 "$agents_file" \
    | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?' | head -1 | sed 's/^v//')"
  if [ -z "$marker_version" ]; then
    add_gap "AGENTS.md: no provenance marker on line 1 (expected '<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->')"
    return
  fi
  [ -f "$BUNDLE_DIR/VERSION" ] || return
  installed_version="$(tr -d '[:space:]' <"$BUNDLE_DIR/VERSION")"
  if harness_semver_is_older "$marker_version" "$installed_version" && [ ! -f "$agents_file.harness-proposed" ]; then
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

# An adapter counts as installed once any of its manifest copy rows exists in the project. Derived
# from the manifest rather than a per-agent directory guess, so a project that merely happens to
# have a .claude/ or .agents/skills/ dir is never audited against an adapter it never installed.
adapter_installed() {
  local manifest="$against/adapters/$1/manifest.txt" verb path target
  [ -f "$manifest" ] || return 1
  while read -r verb path target; do
    [ "${verb:-}" = "copy" ] || continue
    [ -e "$ROOT/$path" ] && return 0
  done < <(harness_manifest_rows "$manifest")
  return 1
}

check_bundle_sync

for agent in claude-code opencode codex; do
  adapter_installed "$agent" || continue
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
