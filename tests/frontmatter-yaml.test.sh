#!/usr/bin/env bash
# Every shipped markdown frontmatter must be valid YAML (issue #87). Codex parses SKILL.md
# frontmatter as strict YAML and skips a skill that fails, with no error in the chat.
#
# The lint below is not a YAML parser. It catches the two shapes this repo has shipped:
#   1. a plain (unquoted, non-block) value whose text contains ': ' or ends with ':'
#      (on the key line or on an indented continuation line);
#   2. a continuation line that starts in column 1.
# When Ruby is present, a real parse (Psych) checks each block as a second opinion; without Ruby it
# prints one skip line. No PyYAML needed. Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
skip() { printf '  skip %s\n' "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Print the frontmatter block: the lines between a first-line '---' and the next '---'.
fm() {
  awk 'NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
       NR==1 { next }
       /^---[[:space:]]*$/ { exit }
       { print }' "$1"
}

# Print one 'line N: <reason>' per problem (N is the file's line number); print nothing when clean.
fm_lint() {
  fm "$1" | awk '
    function colon(s) {
      sub(/[[:space:]]+#.*$/, "", s)          # a " #" starts a YAML comment
      sub(/[[:space:]]+$/, "", s)
      return (s ~ /: / || s ~ /:$/)
    }
    { ln = NR + 1 }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    /^[^[:space:]]/ {
      if ($0 !~ /^[A-Za-z0-9_-]+:([[:space:]]|$)/) {
        print "line " ln ": continuation line not indented"; plain = 0; next
      }
      v = $0; sub(/^[A-Za-z0-9_-]+:[[:space:]]*/, "", v)
      plain = (v != "" && v !~ /^["'\''|>[{&*!]/)
      if (plain && colon(v)) print "line " ln ": '\'': '\'' inside a plain scalar - quote the value or use >-"
      next
    }
    plain && colon($0) { print "line " ln ": '\'': '\'' inside a plain scalar - quote the value or use >-" }
  '
}

# Exit 0 when Ruby parses the frontmatter of "$1"; print the parser error otherwise.
HAVE_RUBY=0
ruby -ryaml -e 1 >/dev/null 2>&1 && HAVE_RUBY=1
yaml_parse() {
  # Psych counts lines inside the block; +1 gives the file's line (the opening '---' is line 1).
  fm "$1" | ruby -ryaml -e 'begin; Psych.parse($stdin.read)
    rescue Psych::SyntaxError => e; warn "line #{e.line + 1}: #{e.problem} #{e.context}".strip; exit 1; end' \
    2>&1 >/dev/null | head -n1
  return "${PIPESTATUS[1]}"
}

# --- Lint rules, proven on fixtures -------------------------------------------------------------
fixture() { printf -- '---\nname: fixture\n%s\n---\n\nBody.\n' "$2" >"$TMP/$1.md"; }
fixture plain-colon        'description: Use it when: the user asks'
fixture plain-trailing     'description: Use it when the user asks for:'
fixture plain-cont-colon   $'description: Use it when the user asks\n  for a decision): a new dependency'
fixture col1-continuation  $'description: Use it when the user types\n/some-command, or asks'
fixture quoted-colon       'description: "Use it when: the user asks"'
fixture folded-colon       $'description: >-\n  Use it when: the user asks\n  for a new dependency.'
fixture literal-blank      $'description: |\n  First paragraph: here.\n\n  Second paragraph.'
fixture plain-cont         $'description: Use it when the user asks\n  for a new dependency.'
fixture comment-line       $'description: Use it when the user asks\n# note: a comment, not content\nstatus: approved'
fixture trailing-comment   'intent: 0_intent.md   # only when: seeded by an intent'
fixture nested-mapping     $'description: Use it.\nmetadata:\n  version: 0.1.0\n  owner: team'
fixture flow-sequence      'argument-hint: [path: optional]'

for c in plain-colon plain-trailing plain-cont-colon col1-continuation; do
  out="$(fm_lint "$TMP/$c.md")"
  [ -n "$out" ] && ok "lint flags fixture: $c" || bad "lint flags fixture: $c" "lint printed nothing"
done
for c in quoted-colon folded-colon literal-blank plain-cont comment-line trailing-comment nested-mapping flow-sequence; do
  out="$(fm_lint "$TMP/$c.md")"
  [ -z "$out" ] && ok "lint passes fixture: $c" || bad "lint passes fixture: $c" "$out"
done
case "$(fm_lint "$TMP/col1-continuation.md")" in
  *"line 4: continuation line not indented"*) ok "lint names the line and the reason" ;;
  *) bad "lint names the line and the reason" "expected 'line 4: continuation line not indented'" ;;
esac
if [ "$HAVE_RUBY" = 1 ]; then
  # The fixtures must mean what the lint says: invalid ones fail a real parse, clean ones pass it.
  for c in plain-colon plain-trailing plain-cont-colon col1-continuation; do
    if yaml_parse "$TMP/$c.md" >/dev/null; then bad "ruby rejects fixture: $c" "parsed"; else ok "ruby rejects fixture: $c"; fi
  done
  for c in quoted-colon folded-colon literal-blank plain-cont comment-line trailing-comment nested-mapping flow-sequence; do
    if err="$(yaml_parse "$TMP/$c.md")"; then ok "ruby parses fixture: $c"; else bad "ruby parses fixture: $c" "$err"; fi
  done
fi

# --- Every shipped frontmatter ------------------------------------------------------------------
files=()
while IFS= read -r p; do
  [ "$(head -n1 "$REPO/$p")" = "---" ] && files+=("$p")
done < <(git -C "$REPO" ls-files -- core adapters | grep '\.md$')

# Guard against a vacuous pass: an empty or truncated list must fail.
if [ "${#files[@]}" -ge 60 ]; then ok "found ${#files[@]} shipped frontmatters (>= 60)"
else bad "found ${#files[@]} shipped frontmatters (>= 60)" "the file list is too short"; fi
list="$(printf '%s\n' "${files[@]}")"
for p in core/skills/adr-workflow/SKILL.md core/skills/intent-workflow/SKILL.md \
         adapters/codex/.agents/skills/monorepo-harness-intent-dispatch/SKILL.md; do
  case $'\n'"$list"$'\n' in *$'\n'"$p"$'\n'*) ok "checked: $p" ;; *) bad "checked: $p" "not in the file list" ;; esac
done

for p in "${files[@]}"; do
  out="$(fm_lint "$REPO/$p")"
  [ -z "$out" ] && ok "lint: $p" || bad "lint: $p" "$(printf '%s' "$out" | tr '\n' ';')"
done

if [ "$HAVE_RUBY" = 1 ]; then
  for p in "${files[@]}"; do
    if err="$(yaml_parse "$REPO/$p")"; then ok "ruby parses: $p"; else bad "ruby parses: $p" "$err"; fi
  done
else
  skip "ruby not found: strict YAML parse not run (the lint above still ran)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
