#!/usr/bin/env bash
# Every file a manifest row ships must be TRACKED by git, not merely present on disk (issue #66):
# a bare `.agents/` line in .gitignore hid adapters/codex/.agents/skills/monorepo-harness-team/SKILL.md,
# so rc.29 shipped a manifest row whose source was not in the tag and `install-adapter.sh codex --refresh`
# failed. A working-tree `[ -f ]` check cannot see that; `git ls-files` can.
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
# Run it from anywhere:  bash tests/manifest-sources-tracked.test.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

rows() { grep -Ev '^[[:space:]]*(#|$)' "$1"; }

for m in adapters/*/manifest.txt; do
  adapter="$(dirname "$m")"
  while read -r verb path _; do
    case "$verb" in copy|merge|tmpl) ;; *) continue ;; esac
    src="$adapter/$path"
    if git ls-files --error-unmatch -- "$src" >/dev/null 2>&1; then ok "tracked: $src"
    else bad "tracked: $src" "$verb row in $m, but the source is not tracked by git (ignored or never added)"; fi
  done < <(rows "$m")
done

while read -r path _; do
  if [ -n "$(git ls-files -- "$path")" ]; then ok "tracked: $path"
  else bad "tracked: $path" "row in core/install-manifest.txt, but nothing under it is tracked by git"; fi
done < <(rows core/install-manifest.txt)

hidden="$(git ls-files -o -i --exclude-standard -- adapters core)"
if [ -z "$hidden" ]; then ok "nothing under adapters/ or core/ is ignored by .gitignore"
else bad "nothing under adapters/ or core/ is ignored by .gitignore" "$hidden"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
