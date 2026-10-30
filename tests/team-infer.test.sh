#!/usr/bin/env bash
# Tests for core/scripts/team-infer.sh (issue #55): the read-only draft /monorepo-harness-team init
# starts from. Inference is only ever a suggestion, so the suite pins the cases the issue names:
# a person who left (stale), people who never commit (absent), bots, one email under two names, and a
# CODEOWNERS seed.
#
# Repo-local on purpose: NOT listed in core/install-manifest.txt, so it never reaches a consumer.
# Run it from anywhere:  bash tests/team-infer.test.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INFER="$REPO/core/scripts/team-infer.sh"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
says(){ case "$2" in *"$3"*) ok "$1";; *) bad "$1" "expected '$3' in: $2";; esac; }
saysn(){ case "$2" in *"$3"*) bad "$1" "did not expect '$3' in: $2";; *) ok "$1";; esac; }
is(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q . && git config user.email root@example.com && git config user.name root
mkdir -p apps/api apps/web packages/ui .github
printf '{"workspaces":["apps/*","packages/*"]}\n' > package.json
printf 'packages:\n  - "apps/*"\n  - "packages/*"\n' > pnpm-workspace.yaml

commit(){ # commit <name> <email> <iso-date> <file>
  echo "$4 $3" >> "$4"; git add "$4"
  GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2" \
  GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" git commit -q -m "c $3"
}
now="$(date -u +%Y-%m-%dT%H:%M:%S)"
old="$(date -u -v-120d +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d '120 days ago' +%Y-%m-%dT%H:%M:%S)"
commit "Alice Example" "alice@example.com" "$now" apps/api/a.txt
commit "Alice E."      "ALICE@example.com" "$now" apps/api/b.txt
commit "Carol Example" "carol@example.com" "$now" apps/web/c.txt
commit "Dave Gone"     "dave@example.com"  "$old" apps/web/d.txt
commit "dependabot[bot]" "49699333+dependabot[bot]@users.noreply.github.com" "$now" packages/ui/e.txt
commit "Erin Example"  "12345+erin-example@users.noreply.github.com" "$now" packages/ui/f.txt
cat > .github/CODEOWNERS <<'EOF'
# owners
/apps/api/ @alice-example
apps/web/**  @carol-example @alice-example
*.md @docs
/nonexistent/ @ghost
EOF

out="$("$INFER" --since "200 days ago" 2>&1)"; ec=$?
is "exits 0" "$ec" "0"
says "lists workspaces" "$out" "workspace	apps/api"
says "lists a second app" "$out" "workspace	apps/web"
says "lists packages" "$out" "workspace	packages/ui"
alice_row="$(grep $'^person\talice@example.com\t' <<< "$out")"
says "merges one email under two names (one row)" "$(grep -c 'alice@example.com' <<< "$out")" "1"
says "keeps both names on the merged row" "$alice_row" "Alice Example"
says "keeps the second name too" "$alice_row" "Alice E."
says "counts commits per person" "$alice_row" "	2	"
says "people carry the last commit date" "$out" "$(date -u +%Y-%m-%d)"
says "a long-gone committer is flagged stale" "$(grep dave@ <<< "$out")" "stale"
saysn "an active committer is not stale" "$(grep carol@ <<< "$out")" "stale"
says "bots are flagged" "$(grep dependabot <<< "$out")" "bot"
says "noreply email suggests a github login" "$(grep erin <<< "$out")" "github=erin-example"
says "CODEOWNERS seeds a workspace" "$out" "owners	apps/api	@alice-example"
says "CODEOWNERS globs are reduced to the directory" "$out" "owners	apps/web	@carol-example,@alice-example"
saysn "CODEOWNERS file patterns are skipped" "$out" "@docs"
saysn "CODEOWNERS paths that are not directories are skipped" "$out" "@ghost"

out="$("$INFER" --since "30 days ago" 2>&1)"
saysn "--since narrows the window" "$out" "dave@example.com"

before="$(git status --porcelain; git log --oneline | wc -l)"
"$INFER" >/dev/null 2>&1
is "inference writes nothing" "$(git status --porcelain; git log --oneline | wc -l)" "$before"
[ ! -e .agents/team.yml ] && ok "inference never creates team.yml" || bad "inference never creates team.yml" "file exists"

out="$("$INFER" --bogus 2>&1)"; ec=$?
is "unknown flag exits 2" "$ec" "2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
