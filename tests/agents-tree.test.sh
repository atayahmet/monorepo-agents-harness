#!/usr/bin/env bash
# Tests for core/scripts/agents-tree.sh (issue #71): survey, candidates, link, lint. Each case builds
# a fixture repo in a temp dir. Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$REPO/core/scripts/agents-tree.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected '$3' in: $2" ;; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "did not expect '$3' in: $2" ;; *) ok "$1" ;; esac; }
code()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "exit $2, expected $3"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# fixture - a fresh small monorepo per call; prints its path.
fixture() {
  local r; r="$(mktemp -d "$TMP/repo.XXXXXX")"
  mkdir -p "$r/.agents/rules" "$r/apps/web/src/store" "$r/apps/web/src/pages" "$r/apps/web/src/util" \
           "$r/apps/api/src" "$r/packages/lib"
  git -C "$r" init -q
  cat > "$r/AGENTS.md" <<'EOF'
# Root
## Rules
- Always run the narrowest workspace-scoped verification first.
- Commits are mandatory at the end of any file-changing task.
- All markdown files must be in English.
- Never put secrets into installed files.
- Keep adapters thin and free of duplicated rules.
EOF
  printf '# Rule\nUse simple English.\n' > "$r/.agents/rules/simple.md"
  cat > "$r/apps/web/AGENTS.md" <<'EOF'
# web
## Commands
`pnpm --filter web test`
## Routing
| Area | File |
|---|---|
| Store | `src/store/AGENTS.md` |
Read `package.json` first.
EOF
  printf '{}\n' > "$r/apps/web/package.json"
  printf '# store\n## Boundaries\nOnly `src/store/index.ts` is public.\n' > "$r/apps/web/src/store/AGENTS.md"
  for f in index.ts a.ts b.ts c.ts; do printf 'export const x = 1\n' > "$r/apps/web/src/store/$f"; done
  printf 'test()\n' > "$r/apps/web/src/store/a.test.ts"
  printf "import { x } from '../store'\n" > "$r/apps/web/src/pages/home.ts"
  printf "import { x } from '../store/a'\n" > "$r/apps/web/src/pages/about.ts"
  printf 'export const u = 1\n' > "$r/apps/web/src/util/u.ts"
  printf 'export const v = 1\n' > "$r/apps/web/src/util/v.ts"
  ( cd "$r/apps/web" && ln -s AGENTS.md CLAUDE.md && ln -s AGENTS.md GEMINI.md )
  ( cd "$r/apps/web/src/store" && ln -s AGENTS.md CLAUDE.md && ln -s AGENTS.md GEMINI.md )
  printf '# api\nplain file\n' > "$r/apps/api/src/CLAUDE.md"
  printf '# lib\n## Scope\nsmall\n' > "$r/packages/lib/AGENTS.md"
  printf '%s\n' "$r"
}
run() { local r="$1"; shift; ( cd "$r" && bash "$SCRIPT" "$@" 2>&1 ); }
snap() { ( cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | LC_ALL=C sort | while IFS= read -r f; do
  if [ -L "$f" ]; then printf '%s -> %s\n' "$f" "$(readlink "$f")"; else printf '%s %s\n' "$f" "$(cksum < "$f")"; fi; done ); }

echo "== usage"
r="$(fixture)"
out="$(run "$r")"; code "no subcommand exits 2" "$?" 2
out="$(run "$r" lint apps/nope)"; code "unknown workspace exits 2" "$?" 2
says "unknown workspace names the path" "$out" "apps/nope"

echo "== survey"
r="$(fixture)"; before="$(snap "$r")"
out="$(run "$r" survey)"; code "survey exits 0" "$?" 0
says "lists the web AGENTS.md with symlinks" "$out" "$(printf 'apps/web/AGENTS.md\t8\tsymlink\tsymlink')"
says "lists headings" "$out" "Commands;Routing"
says "reports plain CLAUDE.md as drift" "$out" "apps/api/src/CLAUDE.md"
says "reports the missing symlink" "$out" "$(printf 'packages/lib/AGENTS.md\tCLAUDE.md missing')"
out="$(run "$r" survey --workspace apps/web)"
lacks "--workspace scopes the survey" "$out" "packages/lib"
[ "$before" = "$(snap "$r")" ] && ok "survey writes nothing" || bad "survey writes nothing" "tree changed"

echo "== candidates"
r="$(fixture)"; before="$(snap "$r")"
out="$(run "$r" candidates apps/web)"; code "candidates exits 0" "$?" 0
first="$(printf '%s\n' "$out" | awk -F'\t' 'NR>1 && $2!="src" {print $2; exit}')"
[ "$first" = "src/store" ] && ok "src/store ranks above the other leaf dirs" || bad "src/store ranks first" "got '$first' in: $out"
says "store has index, tests, two importers and a hint" "$out" "$(printf 'src/store\t5\tyes\tyes\t2\tstore')"
out="$(run "$r" candidates apps/web --limit 1)"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 2 ] && ok "--limit caps rows" || bad "--limit caps rows" "$out"
[ "$before" = "$(snap "$r")" ] && ok "candidates writes nothing" || bad "candidates writes nothing" "tree changed"

echo "== link"
r="$(fixture)"; printf 'keep me\n' > "$r/packages/lib/GEMINI.md"
out="$(run "$r" link packages/lib)"; code "link exits 0" "$?" 0
[ "$(readlink "$r/packages/lib/CLAUDE.md")" = AGENTS.md ] && ok "creates CLAUDE.md -> AGENTS.md" || bad "creates CLAUDE.md symlink" "$out"
[ "$(cat "$r/packages/lib/GEMINI.md")" = "keep me" ] && ok "never replaces a plain file" || bad "never replaces a plain file" "overwritten"
says "reports the plain file" "$out" "GEMINI.md"
before="$(snap "$r")"; run "$r" link packages/lib >/dev/null
[ "$before" = "$(snap "$r")" ] && ok "second run changes nothing" || bad "second run changes nothing" "tree changed"

echo "== lint"
r="$(fixture)"; before="$(snap "$r")"
out="$(run "$r" lint apps/web)"; code "clean workspace passes" "$?" 0
[ "$before" = "$(snap "$r")" ] && ok "lint writes nothing" || bad "lint writes nothing" "tree changed"

r="$(fixture)"; rm "$r/apps/web/src/store/GEMINI.md"
out="$(run "$r" lint apps/web)"; code "missing symlink fails" "$?" 1
says "names the missing symlink" "$out" "src/store/AGENTS.md: GEMINI.md missing"

r="$(fixture)"; printf 'See `src/gone/file.ts`.\n' >> "$r/apps/web/src/store/AGENTS.md"
out="$(run "$r" lint apps/web)"; code "broken path fails" "$?" 1
says "names the broken path" "$out" "src/gone/file.ts"
r="$(fixture)"; printf 'See `src/gone`.\n' >> "$r/apps/web/src/store/AGENTS.md"
out="$(run "$r" lint apps/web)"; code "broken dir under an existing dir fails" "$?" 1

r="$(fixture)"; printf '```\ncat src/gone/x.ts `src/gone/y.ts`\n```\nSee https://x.io/a/b.md and `@scope/pkg` and `console.log` and `src/**/*.ts`.\nAlso `N/A`, `/monorepo-harness-build`, `SKILL.md`, `feat/x`.\n' >> "$r/apps/web/src/store/AGENTS.md"
out="$(run "$r" lint apps/web)"; code "fences, URLs, globs, packages and non-files are skipped" "$?" 0

r="$(fixture)"; mkdir -p "$r/apps/web/src/util"; printf '# util\n' > "$r/apps/web/src/util/AGENTS.md"
( cd "$r/apps/web/src/util" && ln -s AGENTS.md CLAUDE.md && ln -s AGENTS.md GEMINI.md )
out="$(run "$r" lint apps/web)"; code "unlinked nested file fails" "$?" 1
says "names the unlinked file" "$out" "src/util/AGENTS.md: not linked from AGENTS.md"

r="$(fixture)"; i=0; while [ $i -lt 80 ]; do echo "line $i" >> "$r/apps/web/AGENTS.md"; i=$((i+1)); done
out="$(run "$r" lint apps/web)"; code "over-budget root fails" "$?" 1
says "names the budget" "$out" "> 80"
out="$(run "$r" lint apps/web --root-max 200)"; code "--root-max raises the budget" "$?" 0

r="$(fixture)"; sed -n '3,7p' "$r/AGENTS.md" >> "$r/apps/web/src/store/AGENTS.md"
out="$(run "$r" lint apps/web)"; code "copied root block fails" "$?" 1
says "names the copied block" "$out" "copied from AGENTS.md"

r="$(fixture)"; out="$(run "$r" lint apps/api)"; code "workspace without AGENTS.md fails" "$?" 1
says "warns about the plain CLAUDE.md" "$out" "src/CLAUDE.md"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
