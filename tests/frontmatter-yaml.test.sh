#!/usr/bin/env bash
# Every shipped markdown frontmatter must be valid YAML (issue #87). Codex parses SKILL.md
# frontmatter as strict YAML and skips a skill that fails, with no error in the chat.
#
# The lint below is not a YAML parser. It catches the two shapes this repo has shipped, plus one
# that Codex rejects although YAML parsers accept it:
#   1. a plain (unquoted, non-block) value whose text contains ':' followed by a space or tab, or
#      ends with ':' (on the key line or on an indented continuation line);
#   2. a continuation line that starts in column 1;
#   3. a top-level key that appears twice.
# When Ruby is present, a real parse (Psych, plus a duplicate-key check) tests each block as a
# second opinion; without Ruby it prints one skip line. No PyYAML needed. Repo-local, never installed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
skip() { printf '  skip %s\n' "$1"; }

TMP="$(mktemp -d)" && [ -d "$TMP" ] || { echo "mktemp failed" >&2; exit 1; }
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
      return (s ~ /:[[:space:]]/ || s ~ /:$/)
    }
    { ln = NR + 1 }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    /^[^[:space:]]/ {
      if ($0 !~ /^[A-Za-z0-9_-]+:([[:space:]]|$)/) {
        print "line " ln ": continuation line not indented"; plain = 0; next
      }
      k = $0; sub(/:.*/, "", k)
      if (k in seen) print "line " ln ": duplicate key '\''" k "'\''"
      seen[k] = 1
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
  # Psych accepts a repeated top-level key, which Codex rejects, so check for one in the tree.
  fm "$1" | ruby -ryaml -e 'begin
      doc = Psych.parse($stdin.read); m = doc && doc.root; seen = {}
      (m.is_a?(Psych::Nodes::Mapping) ? m.children.each_slice(2) : []).each do |k, _|
        next unless k.is_a?(Psych::Nodes::Scalar)
        if seen[k.value] then warn "line #{k.start_line + 2}: duplicate key '\''#{k.value}'\''"; exit 1 end
        seen[k.value] = true
      end
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
fixture plain-colon-tab    $'description: Use it when:\tthe user asks'
# Psych accepts a repeated key; Codex rejects the whole skill (probed on 0.149.0).
fixture duplicate-key      $'description: Use it when the user asks.\ndescription: A second value.'

FLAGGED="plain-colon plain-trailing plain-cont-colon col1-continuation plain-colon-tab duplicate-key"
CLEAN="quoted-colon folded-colon literal-blank plain-cont comment-line trailing-comment nested-mapping flow-sequence"
for c in $FLAGGED; do
  out="$(fm_lint "$TMP/$c.md")"
  [ -n "$out" ] && ok "lint flags fixture: $c" || bad "lint flags fixture: $c" "lint printed nothing"
done
for c in $CLEAN; do
  out="$(fm_lint "$TMP/$c.md")"
  [ -z "$out" ] && ok "lint passes fixture: $c" || bad "lint passes fixture: $c" "$out"
done
for want in "col1-continuation|line 4: continuation line not indented" \
            "duplicate-key|line 4: duplicate key 'description'"; do
  case "$(fm_lint "$TMP/${want%%|*}.md")" in
    *"${want#*|}"*) ok "lint names the line and the reason: ${want%%|*}" ;;
    *) bad "lint names the line and the reason: ${want%%|*}" "expected '${want#*|}'" ;;
  esac
done
if [ "$HAVE_RUBY" = 1 ]; then
  # The fixtures must mean what the lint says: invalid ones fail a real parse, clean ones pass it.
  for c in $FLAGGED; do
    if yaml_parse "$TMP/$c.md" >/dev/null; then bad "ruby rejects fixture: $c" "parsed"; else ok "ruby rejects fixture: $c"; fi
  done
  for c in $CLEAN; do
    if err="$(yaml_parse "$TMP/$c.md")"; then ok "ruby parses fixture: $c"; else bad "ruby parses fixture: $c" "$err"; fi
  done
fi

# --- Every shipped frontmatter ------------------------------------------------------------------
# Print, NUL-separated, each tracked *.md under core/ and adapters/ of repo "$1" whose first line
# is '---'.
shipped_md() {
  git -C "$1" ls-files -z -- core adapters | while IFS= read -r -d '' p; do
    case "$p" in *.md) [ "$(head -n1 "$1/$p")" = "---" ] && printf '%s\0' "$p" ;; esac
  done
}

# The list must not drop a file because of its name: git quotes a non-ASCII path unless -z is used.
QP="$TMP/quoted-path"
mkdir -p "$QP/core" && git -C "$QP" init -q && printf -- '---\nname: x\n---\n' >"$QP/core/ä.md" \
  && git -C "$QP" add -A
got="$(shipped_md "$QP" | tr '\0' '\n')"
[ "$got" = "core/ä.md" ] && ok "file list keeps a non-ASCII name" || bad "file list keeps a non-ASCII name" "got '$got'"

files=()
while IFS= read -r -d '' p; do files+=("$p"); done < <(shipped_md "$REPO")

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
