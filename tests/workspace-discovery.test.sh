#!/usr/bin/env bash
# Tests for language-agnostic workspace discovery (issue #83): the .agents/workspaces.txt declaration,
# detect-monorepo-framework.sh --workspace-dirs, and the scripts that call it.
#
# Repo-local on purpose: NOT listed in core/install-manifest.txt. Every case runs in a throwaway git
# repo laid out like an installed project.  bash tests/workspace-discovery.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-ws-test.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
F="$TMP/fix"
TODAY="$(date +%Y_%m_%d)"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
saysn() { case "$2" in *"$3"*) bad "$1" "did not expect '$3' in: $2" ;; *) ok "$1" ;; esac; }

# A python3 and a jq that always fail: the layouts here must not need either.
BROKEN="$TMP/broken"; mkdir -p "$BROKEN"
for b in python3 jq; do printf '#!/bin/sh\nexit 127\n' > "$BROKEN/$b"; chmod +x "$BROKEN/$b"; done

new_fixture() { # new_fixture [dir]
  F="${1:-$TMP/fix}"; rm -rf "$F"; mkdir -p "$F/.agents/monorepo-agents-harness"
  ( cd "$F" && git init -q . && git config user.email t@example.com && git config user.name test )
  cp -R "$REPO/core" "$F/.agents/monorepo-agents-harness/core"
}
S=".agents/monorepo-agents-harness/core/scripts"
declare_ws() { printf '%s\n' "$@" > "$F/.agents/workspaces.txt"; }
# dirs -> workspace dirs, repo-relative, space-joined ("." is the repo root). stderr dropped.
dirs() { ( cd "$F" && bash $S/detect-monorepo-framework.sh --workspace-dirs 2>/dev/null ) \
  | while IFS= read -r d; do if [ "$d" = "$F" ]; then echo .; else printf '%s\n' "${d#"$F"/}"; fi; done \
  | tr '\n' ' ' | sed 's/ $//'; }
warns() { ( cd "$F" && bash $S/detect-monorepo-framework.sh --workspace-dirs 2>&1 >/dev/null ); }
scaffold() { ( cd "$F" && bash $S/scaffold-workspace-agents.sh 2>&1 ); }
has() { if [ -e "$F/$2" ]; then ok "$1"; else bad "$1" "missing: $2"; fi; }
hasn() { if [ -e "$F/$2" ]; then bad "$1" "unexpected: $2"; else ok "$1"; fi; }
build_task() { # build_task <workspace> — a task at the build stage with no memory
  local d="$F/$1/.agents/artifacts/task_${TODAY}_x"; mkdir -p "$d"
  printf -- '---\nphase: spec\n---\n\n## Test / verification plan\nrun tests\n' > "$d/1_spec.md"
  printf -- '---\nphase: plan\nstatus: approved\nbuild_started: 2026-01-01T00:00:00+0000\n---\n\n# Plan\n' > "$d/2_plan.md"
}
gate_code() { ( cd "$F" && bash $S/memory-gate.sh >/dev/null 2>&1 </dev/null ); echo $?; }

# The seven layouts of issue #83: layout <name> -> sets F, WS (the workspace) and DECL (its line).
layout() {
  new_fixture
  case "$1" in
    turbo)   echo '{}' > "$F/turbo.json"; WS=apps/web; DECL='apps/*' ;;
    cargo)   printf '[workspace]\nmembers=["crates/*"]\n' > "$F/Cargo.toml"; WS=crates/core; DECL='crates/*' ;;
    gowork)  printf 'go 1.23\nuse ./services/api\n' > "$F/go.work"; WS=services/api; DECL='services/*' ;;
    maven)   echo '<project/>' > "$F/pom.xml"; WS=billing; DECL='billing' ;;
    uv)      printf '[tool.uv.workspace]\nmembers=["packages/*"]\n' > "$F/pyproject.toml"; WS=packages/a; DECL='packages/*' ;;
    gomod)   echo 'module x' > "$F/go.mod"; WS=.; DECL='.' ;;
    turbopnpm) echo '{}' > "$F/turbo.json"; printf 'packages:\n  - "apps/*"\n  - "services/*"\n' > "$F/pnpm-workspace.yaml"
             WS=services/api; DECL='services/*' ;;
  esac
  mkdir -p "$F/$WS"
}

echo "workspace discovery — the layouts of issue #83"
for l in turbo cargo gowork maven uv gomod turbopnpm; do
  layout $l; declare_ws "$DECL"; scaffold >/dev/null
  has "$l: a declared workspace is scaffolded" "$WS/.agents/artifacts/index.md"
  build_task "$WS"; is "$l: declared, the gate blocks" "$(gate_code)" "1"
  layout $l; build_task "$WS"; is "$l: not declared, the gate blocks" "$(gate_code)" "1"
done
layout turbopnpm; mkdir -p "$F/apps/web"
is "turbo + pnpm: the real list is read" "$(dirs)" "apps/web services/api"
out="$( cd "$F" && PATH="$BROKEN:$PATH" bash $S/scaffold-workspace-agents.sh 2>&1 )"
has "turbo + pnpm services/*: scaffolded without python3 and jq" "services/api/.agents/session-log.md"

echo "declaration file"
new_fixture; mkdir -p "$F/crates/a" "$F/crates/b" "$F/billing" "$F/services/a/b" "$F/apps/web" "$F/crates/node_modules"
printf '# comment\r\n\r\n  ./crates/*/  \r\nbilling # the module\r\nservices/a/b\r\ncrates/a\r\n' > "$F/.agents/workspaces.txt"
is "comments, CRLF, spaces, ./, trailing /, nested paths, no duplicates" "$(dirs)" "crates/a crates/b billing services/a/b"
is "a clean file prints no warning" "$(warns)" ""
declare_ws '*'; saysn "node_modules is never a workspace" "$(declare_ws 'crates/*'; dirs)" "node_modules"
saysn "the declaration replaces detection" "$(declare_ws billing; dirs)" "apps/web"
declare_ws billing '.'; is "the repo root can be declared" "$(dirs)" "billing ."
declare_ws './'; is "./ is the repo root" "$(dirs)" "."
declare_ws 'crates/**'; is "a trailing /** is read as /*" "$(dirs)" "crates/a crates/b"
says "and it warns" "$(warns)" "crates/**"
declare_ws '/etc' '../x' 'a/../b' billing; is "absolute and .. lines are skipped" "$(dirs)" "billing"
says "an absolute path warns" "$(warns)" "/etc"; says "a .. segment warns" "$(warns)" "../x"; says "an inner .. warns" "$(warns)" "a/../b"
declare_ws nope billing; says "a line that matches nothing warns" "$(warns)" "nope"
is "and does not fail" "$(cd "$F" && bash $S/detect-monorepo-framework.sh --workspace-dirs >/dev/null 2>&1; echo $?)" "0"
declare_ws nope; is "a well-formed line still replaces detection when it matches nothing" "$(dirs)" ""
declare_ws '# nothing' ''; is "no usable line: detection runs" "$(dirs)" "apps/web"
printf 'billing' > "$F/.agents/workspaces.txt"; is "a last line without a newline counts" "$(dirs)" "billing"
declare_ws '*/a' billing; is "a * in the first segment" "$(dirs)" "crates/a services/a billing"
out="$(cd "$F" && bash $S/detect-monorepo-framework.sh --workspaces 2>/dev/null)"
is "--workspaces prints the parents of glob lines only" "$(declare_ws 'crates/*' billing '.'; cd "$F" && bash $S/detect-monorepo-framework.sh --workspaces 2>/dev/null)" "$F/crates"

echo "framework sources"
new_fixture; mkdir -p "$F/apps/web" "$F/packages/ui"
is "no framework: apps/* and packages/*" "$(dirs)" "apps/web packages/ui"
is "unknown framework name unchanged" "$(cd "$F" && bash $S/detect-monorepo-framework.sh --framework)" "unknown"
echo '{}' > "$F/turbo.json"; is "turbo without a list: apps/* and packages/*" "$(dirs)" "apps/web packages/ui"
is "--workspaces is unchanged for it" "$(cd "$F" && bash $S/detect-monorepo-framework.sh --workspaces | tr '\n' ' ')" "$F/apps $F/packages "
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$F/tools/cli" "$F/tools/other"
  echo '{"workspaces":["tools/cli"]}' > "$F/package.json"; is "turbo + package.json: an exact path has no siblings" "$(dirs)" "tools/cli"
  echo '{"workspaces":{"packages":["packages/*"]}}' > "$F/package.json"; is "package.json workspaces object form" "$(dirs)" "packages/ui"
fi
new_fixture; mkdir -p "$F/apps/web" "$F/libs/x" "$F/libs/skip" "$F/q" "$F/other/z"
printf 'catalog:\n  react: 1\n"packages": # list\n# c\n- libs/* # trailing\n  - '"'"'apps/*'"'"'\n  - "!libs/skip"\n  - .\nonlyBuiltDependencies:\n  - other/*\n' > "$F/pnpm-workspace.yaml"
is "pnpm block list: quotes, comments, exclusion, end of list, no root" "$(dirs)" "libs/x apps/web"
printf 'packages: ["apps/*", q]\n' > "$F/pnpm-workspace.yaml"; is "pnpm inline list" "$(dirs)" "apps/web q"
printf 'packages: [\n  "apps/*", # c\n  "libs/*"\n]\nother:\n  - q\n' > "$F/pnpm-workspace.yaml"; is "pnpm inline list on several lines" "$(dirs)" "apps/web libs/skip libs/x"
printf 'packages:\n  - "**"\n  - "!**/skip/**"\n  - "libs/*"\n' > "$F/pnpm-workspace.yaml"; saysn "a ** exclusion applies" "$(dirs)" "libs/skip"

echo "odd repo paths"
new_fixture "$TMP/we[ird] dir+x"; mkdir -p "$F/crates/core"; declare_ws 'crates/*'
is "a repo path with spaces and [" "$(dirs)" "crates/core"
build_task crates/core; is "the gate blocks there too" "$(gate_code)" "1"
rm "$F/.agents/workspaces.txt"; is "and without a declaration" "$(gate_code)" "1"

echo "no workspace found"
new_fixture; echo 'module x' > "$F/go.mod"
says "scaffold warns and names the file" "$(scaffold)" ".agents/workspaces.txt"
base="$(cd "$F" && bash $S/audit-install.sh 2>&1)"; code0=$?
says "audit warns and names the file" "$base" ".agents/workspaces.txt"
json="$(cd "$F" && bash $S/audit-install.sh --json 2>/dev/null)"
says "audit --json has warnings" "$json" '"warnings":["'
saysn "the warning is not a gap" "${json%%\"warnings\"*}" "workspaces.txt"
declare_ws '.'; scaffold >/dev/null
has "a declared root is scaffolded" ".agents/session-log.md"
json="$(cd "$F" && bash $S/audit-install.sh --json 2>/dev/null)"; code1=$?
says "with a declaration the warnings are empty" "$json" '"warnings":[]'
if command -v jq >/dev/null 2>&1; then is "the JSON is valid" "$(printf '%s' "$json" | jq -r '.warnings | length' 2>&1)" "0"; fi
declare_ws '.' gone; says "audit passes on a declaration warning" "$(cd "$F" && bash $S/audit-install.sh 2>&1)" "gone"
saysn "scaffold prints no no-workspace warning when one exists" "$(scaffold)" "no workspace found"

# The audit exit code: a complete install stays 0 with no workspace.
inst="$TMP/inst"; mkdir -p "$inst"; ( cd "$inst" && git init -q . && echo 'module x' > go.mod )
out="$( cd "$inst" && bash "$REPO/core/scripts/install-harness.sh" --from "$REPO" 2>&1 )"
needs="${out#*Needs you:}"
says "the installer lists it under Needs you" "$needs" ".agents/workspaces.txt"
( cd "$inst" && bash .agents/monorepo-agents-harness/core/scripts/audit-install.sh >/dev/null 2>&1 ); is "audit exits 0 on a complete install with no workspace" "$?" "0"

echo "callers"
new_fixture; mkdir -p "$F/crates/core"; declare_ws 'crates/*' '.'
out="$(cd "$F" && bash $S/team-infer.sh 2>&1)"
says "team-infer lists a declared workspace" "$out" "workspace	crates/core"
says "team-infer lists a declared root" "$out" "workspace	."
printf 'version: 1\nmembers:\n  - key: alice\n    name: Alice\nassignee_by_workspace:\n  crates/core: [alice]\n' > "$F/.agents/team.yml"
declare_ws crates/core
saysn "team lint accepts an exact declared path" "$(cd "$F" && bash $S/team.sh lint 2>&1)" "not under a workspace"

echo "kb-ingest module page"
kb() { # kb <workspace> -> module pages created
  mkdir -p "$F/$1/.agents/artifacts/task_2026_01_01_x"; printf -- '---\nphase: memory\n---\n\n# Memory — x\n' > "$F/$1/.agents/artifacts/task_2026_01_01_x/3_memory.md"
  ( cd "$F" && rm -rf knowledge && bash $S/scaffold-knowledge.sh >/dev/null 2>&1
    p="$1/.agents/artifacts/task_2026_01_01_x"; [ "$1" = . ] && p=".agents/artifacts/task_2026_01_01_x"
    bash $S/kb-ingest.sh "$p" 2>&1 | grep -oE 'modules/[^ ]+\.md' | head -1 )
}
new_fixture
is "crates/core -> core" "$(kb crates/core)" "modules/core.md"
is "billing -> billing" "$(kb billing)" "modules/billing.md"
is "services/a/b -> b" "$(kb services/a/b)" "modules/b.md"
is "apps/api is unchanged" "$(kb apps/api)" "modules/api.md"
is "the repo root is unchanged" "$(kb .)" "modules/project.md"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
