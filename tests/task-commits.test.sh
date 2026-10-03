#!/usr/bin/env bash
# Tests for `task-state.sh sync-commits`: keeping a 3_memory.md `commits:` list true across a rebase,
# a squash or a force-push.
#
# Repo-local on purpose: this file is NOT listed in core/install-manifest.txt, so it never reaches a
# consumer bundle (core/ is copied whole into every install, and a test tree there would ship).
#
# The fixture is a real git history that is rewritten for real — a branch commit is rebased so its
# sha changes while its content does not, which is exactly the situation issue #21 is about. Nothing
# is stubbed: if the plumbing stops behaving the way it did at release time, these fail.
#
# Run it from anywhere:  bash tests/task-commits.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/harness-tc-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
says() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to mention '$3', got: $2" ;; esac; }
field() { sed -n 's/^'"$2"': //p' "$1"; }   # field <file> <key> — the raw value, shape and all

TS="$REPO/core/scripts/task-state.sh"

# A history whose task branch commit is rebased onto main, then fast-forwarded in: the sha recorded in
# the memory is gone, and the change itself is on main under a new sha. Exports OLD_SHA / NEW_SHA.
new_fixture() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  ( cd "$FIXTURE" \
    && git init -q -b main . \
    && git config user.email t@example.com && git config user.name test \
    && printf 'a\n' > base.txt && git add -A && git commit -qm "A" \
    && git checkout -q -b task && printf 'a\nb\n' > feature.txt && git add feature.txt \
    && git commit -qm "the task commit" \
    && git rev-parse HEAD > .old_sha \
    && git checkout -q main && printf 'c\n' > other.txt && git add -A && git commit -qm "unrelated main work" \
    && git checkout -q task && git rebase -q main \
    && git checkout -q main && git merge -q --ff-only task \
    && git rev-parse HEAD > .new_sha )
  OLD_SHA="$(cat "$FIXTURE/.old_sha")"
  NEW_SHA="$(cat "$FIXTURE/.new_sha")"
  rm -f "$FIXTURE/.old_sha" "$FIXTURE/.new_sha"
  printf -- '---\nphase: memory\ncommits: [%s]\n---\n\n# Memory\n' "$OLD_SHA" > "$FIXTURE/3_memory.md"
  PATCH_ID="$(cd "$FIXTURE" && git show --format= "$OLD_SHA" | git patch-id --stable | cut -d' ' -f1)"
}
sync()       { ( cd "$FIXTURE" && bash "$TS" sync-commits 3_memory.md "$@" 2>&1 ); }
sync_code()  { ( cd "$FIXTURE" && bash "$TS" sync-commits 3_memory.md "$@" >/dev/null 2>&1 ); echo $?; }

# --- the rebase case, the reason this command exists ---------------------------------------------------
new_fixture
out="$(sync)"
is "a stale sha is remapped to the sha carrying the same change" "$(field "$FIXTURE/3_memory.md" commits)" "[$OLD_SHA]"
is "a dry run exits 0" "$(sync_code)" "0"
says "the report names the sha it remapped to" "$out" "$OLD_SHA -> $NEW_SHA"
says "the report says which ref it compared against" "$out" "against main"
says "a dry run says it wrote nothing" "$out" "dry run, nothing written"

new_fixture
sync --write >/dev/null
is "--write replaces the sha" "$(field "$FIXTURE/3_memory.md" commits)" "[$NEW_SHA]"
is "--write records the patch-id" "$(field "$FIXTURE/3_memory.md" patch_ids)" "[$PATCH_ID]"
is "the synced sha is reachable from main" "$(cd "$FIXTURE" && git merge-base --is-ancestor "$NEW_SHA" main && echo yes)" "yes"

new_fixture
sync --write >/dev/null
out="$(sync --write)"
is "a second run is a no-op on the commits" "$(field "$FIXTURE/3_memory.md" commits)" "[$NEW_SHA]"
says "a second run says unchanged" "$out" "unchanged $NEW_SHA"

# --- a sha that is still reachable is left alone, and the history is never walked ---------------------
new_fixture
printf -- '---\nphase: memory\ncommits: [%s]\n---\n' "$NEW_SHA" > "$FIXTURE/3_memory.md"
out="$(sync --write)"
is "a reachable sha is kept" "$(field "$FIXTURE/3_memory.md" commits)" "[$NEW_SHA]"
is "a reachable sha still gets its patch-id" "$(field "$FIXTURE/3_memory.md" patch_ids)" "[$PATCH_ID]"
says "a reachable sha is reported as unchanged" "$out" "unchanged $NEW_SHA"

# --- both frontmatter shapes, and a body that merely mentions commits -----------------------------------
new_fixture
printf -- '---\nphase: memory\ncommits:\n  - %s\n---\n\n# Memory\n\nA line that says commits: [%s] in prose.\n' \
  "$OLD_SHA" "$OLD_SHA" > "$FIXTURE/3_memory.md"
sync --write >/dev/null
is "a block list is read and rewritten" "$(field "$FIXTURE/3_memory.md" commits)" "[$NEW_SHA]"
is "the body is untouched" \
  "$(grep -c 'in prose' "$FIXTURE/3_memory.md")" "1"
is "a prose commits: line in the body is not frontmatter" \
  "$(grep -c '^commits' "$FIXTURE/3_memory.md")" "1"

new_fixture
printf -- '---\nphase: memory\ncommits: [%s]\npatch_ids: [0000000000000000000000000000000000000000]\n---\n' \
  "$OLD_SHA" > "$FIXTURE/3_memory.md"
sync --write >/dev/null
is "a stale patch_ids line is replaced, not duplicated" \
  "$(grep -c '^patch_ids' "$FIXTURE/3_memory.md")" "1"
is "the stale patch-id is gone" \
  "$(grep -c '0000000000000000000000000000000000000000' "$FIXTURE/3_memory.md")" "0"

# --- what it must refuse to guess ----------------------------------------------------------------------
new_fixture
printf -- '---\nphase: memory\ncommits: [0123456789012345678901234567890123456789]\n---\n' > "$FIXTURE/3_memory.md"
out="$(sync --write)"
is "a commit that exists nowhere exits 1" "$(sync_code --write)" "1"
says "an unmappable sha is named" "$out" "UNMAPPED  0123456789012345678901234567890123456789"
is "an unmappable sha is left exactly as written" \
  "$(field "$FIXTURE/3_memory.md" commits)" "[0123456789012345678901234567890123456789]"
is "no patch_ids line is invented for it" "$(grep -c '^patch_ids' "$FIXTURE/3_memory.md")" "0"

# Two commits with identical content reachable from the ref — the same change, cherry-picked and
# reworded so it has its own sha. Content cannot say which one the memory meant, so the command must
# not pick.
new_fixture
( cd "$FIXTURE" \
  && git checkout -q -b other "$NEW_SHA"~1 \
  && git cherry-pick "$NEW_SHA" >/dev/null \
  && git commit -q --amend -m "the task commit, cherry-picked elsewhere" \
  && git checkout -q main && git merge -q --no-ff -m "merged elsewhere" other \
  && git log --no-color -p --format='commit %H' main | git patch-id --stable | grep -c "^$PATCH_ID " > .count )
is "the fixture really does have two commits with that patch-id" "$(cat "$FIXTURE/.count")" "2"
rm -f "$FIXTURE/.count"
out="$(sync --write)"
is "a patch-id shared by two commits is not resolved by guessing" "$(sync_code --write)" "1"
says "the ambiguity is named" "$out" "share its patch-id"
is "the ambiguous sha is left as written" \
  "$(field "$FIXTURE/3_memory.md" commits)" "[$OLD_SHA]"

# --- ref resolution and the option contract -----------------------------------------------------------
new_fixture
out="$(sync --write --ref main)"
is "--ref is used when given" "$(field "$FIXTURE/3_memory.md" commits)" "[$NEW_SHA]"
says "--ref is reported" "$out" "against main"

new_fixture
out="$(sync --write --ref task)"
says "a named ref that has no mapping is reported by name" "$out" "against task"

new_fixture
rm -rf "$FIXTURE/.git"
out="$(sync)"
is "no ref at all exits 3, not 1" "$(sync_code)" "3"
says "no ref says nothing was compared" "$out" "nothing was compared"
is "no ref leaves the memory alone" "$(field "$FIXTURE/3_memory.md" commits)" "[$OLD_SHA]"

is "--write is refused by stage" "$(bash "$TS" stage . --write 2>&1 >/dev/null | wc -l | tr -d ' ')" "1"
is "--ref is refused by stage" "$(bash "$TS" stage . --ref main 2>&1 >/dev/null | wc -l | tr -d ' ')" "1"
is "--ref without a value is refused" \
  "$(bash "$TS" sync-commits "$FIXTURE/3_memory.md" --ref 2>&1 >/dev/null | wc -l | tr -d ' ')" "1"

new_fixture
printf -- '# not a memory\n' > "$FIXTURE/3_memory.md"
is "a file with no frontmatter exits 1" "$(sync_code --write)" "1"
is "a file with no frontmatter is not modified" "$(cat "$FIXTURE/3_memory.md")" "# not a memory"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]