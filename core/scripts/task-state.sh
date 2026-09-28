#!/usr/bin/env bash
# task-state — read-only validation of the per-SDLC-stage artifact chain. Agent-agnostic.
#
# The stage commands (/monorepo-harness-spec, -plan, -build) call this before acting so a stage can
# never be run against a stale or unwarranted input. It mirrors the frontmatter-parsing style of
# memory-gate.sh (plain grep/sed, no dependencies).
#
# Subcommands (each prints a reason on stdout and exits 1 on failure, 0 on success):
#   check-intent-approved <intent.md> [--pr <pr-ref>]
#                                        — file exists AND (an approving review on the PR, if
#                                          --pr is given, ELSE frontmatter `status: approved`).
#                                          The PR is the human decision, so it is read first; the
#                                          file is the record of it. Missing/unauthenticated `gh`
#                                          warns and falls through to the file. On success the
#                                          source is named, with the reviewer and date from the PR
#                                          review so the caller can record them without inventing
#                                          them.
#   check-spec <spec.md>               — file exists AND frontmatter has `phase: spec`.
#   check-plan <plan.md>               — file exists AND frontmatter has `phase: plan`.
#   check-chain <plan.md>              — the plan's task dir also has a `1_spec.md`; and, when the
#                                        task was seeded by an intent (a `0_intent.md` reference stub
#                                        is present), that stub's `source:` link resolves to a real
#                                        file and THAT file (the actual intent, never a local copy)
#                                        is approved. Ad-hoc tasks (no `0_intent.md`) are exempt from
#                                        the intent requirement.
#   check-adr <spec.md>                — advisory (no gate): validates the ADRs the spec's
#                                        `## Architectural decisions` section references — each
#                                        linked `adr/NNNN-<title>.md` must exist and carry
#                                        `phase: adr` frontmatter. `N/A` and specs without the
#                                        section pass (backcompat, no ADRs expected).
#   check-kb <task_dir> [--path <kb>]   — gates a task's knowledge-base coverage: when the task has
#                                        `3_memory.md`, the KB must be seeded (knowledge/index.md +
#                                        schema.md present) and the pages the task's memory/verify/ADR
#                                        imply must be cataloged in knowledge/index.md (sources/<slug>,
#                                        decision-records/NNNN-* for each adr, verified-facts/<slug>
#                                        when 4_verify.md exists). Exit 0 when nothing to gate
#                                        (research-only / N/A task, no memory) or fully covered;
#                                        exit 1 (in non-advisory mode) on gaps.
#   merge-intent-pr <intent.md> [--pr <ref>] [--yes]
#                                        — merge the intent's own PR, but only on an explicit answer
#                                          and only when the PR itself carries an approving review.
#                                          Reads `pr:` from the intent when --pr is absent. Without
#                                          --yes it prints what it would do and exits 0 (a dry run the
#                                          caller shows before asking). With --yes it runs
#                                          'gh pr merge <ref> --merge': never --admin (bypassing
#                                          branch protection is a human's call), never
#                                          --delete-branch, never --squash/--rebase/--auto. An
#                                          already-merged PR is reported and exits 0, so a re-run is
#                                          harmless; a closed or conflicting PR fails.
#
# Web usage (from the shared bundle root in a consumer project):
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-intent-approved \
#        apps/api/.agents/intents/intent_2026_08_27_add_auth.md --pr 12
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr \
#        apps/api/.agents/intents/intent_2026_08_27_add_auth.md --yes
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-chain \
#        apps/api/.agents/artifacts/task_2026_08_27_add_auth/2_plan.md
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-adr \
#        apps/api/.agents/artifacts/task_2026_08_27_add_auth/1_spec.md

set -euo pipefail

cmd="${1:-}"
[ -n "$cmd" ] || { echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain|check-adr|check-kb|merge-intent-pr> <path> [--pr <pr-ref>] [--yes] [--path <kb>]" >&2; exit 2; }
path="${2:-}"
[ -n "$path" ] || { echo "usage: task-state.sh $cmd <path>" >&2; exit 2; }
shift 2 2>/dev/null || true

# Options, each allowed only by the subcommands that read it. --pr is the PR that carries the human
# approval; --yes is the developer's in-turn answer to "merge it now?"; --path relocates the KB.
# Any option a subcommand does not read is refused rather than ignored, so a typo in a gate argument
# can never read as "no PR, check the file only" and pass, nor "no --yes" silently become a merge.
pr_ref=""; merge_now=0; kb_path=""
opt_err() {
  echo "task-state: $cmd — '$1' is not a supported option for this subcommand" >&2
  exit 2
}
while [ $# -gt 0 ]; do
  case "$1" in
    --pr)
      case "$cmd" in check-intent-approved|merge-intent-pr) ;; *) opt_err "$1" ;; esac
      [ -n "${2:-}" ] || { echo "usage: task-state.sh $cmd <path> --pr <pr-ref>" >&2; exit 2; }
      pr_ref="$2"; shift 2 ;;
    --yes)
      case "$cmd" in merge-intent-pr) merge_now=1; shift ;; *) opt_err "$1" ;; esac ;;
    --path)
      case "$cmd" in check-kb) ;; *) opt_err "$1" ;; esac
      [ -n "${2:-}" ] || { echo "usage: task-state.sh $cmd <path> --path <kb>" >&2; exit 2; }
      kb_path="$2"; shift 2 ;;
    *) opt_err "$1" ;;
  esac
done

# frontmatter_field <file> <key> — print the value of a top-level frontmatter key (`key: value`),
# or nothing if the file or key is absent. Only the first fenced `---` block is treated as
# frontmatter; regex-anchored so `key:` values are not matched mid-block.
frontmatter_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v k="$key" '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR==1 { in_fm=1; next }
    in_fm && $0 ~ /^---[[:space:]]*$/ { exit }
    in_fm && match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*") {
      print substr($0, RSTART+RLENGTH); exit
    }
  ' "$file"
}

fail() { echo "task-state: $cmd — $1" >&2; exit 1; }

# --- The PR review reader, shared by the gate and the merge -------------------------------------
# Two subcommands now answer "is this PR approved?", so the answer is one function. 0.4.0-rc.5 had
# this inline in check-intent-approved and filtered on state itself after a test showed that trusting
# gh's jq filter let a CHANGES_REQUESTED review through. A second copy of that filter for the merge
# could disagree with the first about the same PR, which is the one bug class a gate cannot have.
#
# latest_reviews <pr-ref> — print "<login>\t<state>\t<submittedAt>" for each reviewer's LATEST
# review. Return 1 (reason on stderr) when gh is missing, unauthenticated, or the PR is unreadable —
# the caller then falls back to the intent file, which is the direction that cannot invent consent.
latest_reviews() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "task-state: gh not found, cannot read an approval on PR '$1'; falling back to the intent file" >&2
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "task-state: gh is not authenticated, cannot read an approval on PR '$1'; falling back to the intent file" >&2
    return 1
  fi
  rows="$(gh pr view "$1" --json reviews \
        -q '.reviews[] | "\(.author.login)\t\(.state)\t\(.submittedAt)"' 2>&1)" || {
    echo "task-state: gh could not read PR '$1' ($(printf '%s' "$rows" | head -1)); falling back to the intent file" >&2
    return 1
  }
  # Latest per reviewer by submittedAt, not by position: GitHub's ordering is not a contract, and a
  # reviewer who approved on Monday and asked for changes on Tuesday has not approved this PR.
  printf '%s\n' "$rows" | awk -F'\t' '
    NF >= 3 && $1 != "" { if ($3 > best[$1]) { best[$1] = $3; st[$1] = $2 } }
    END { for (l in st) print l "\t" st[l] "\t" best[l] }
  '
}

# approval_from_pr <pr-ref> — 0 and prints "<reviewer>\t<date>" when the PR is approved; 1 when it is
# not (an approval is required AND no reviewer may be asking for changes); 2 when the PR could not be
# read at all. DISMISSED and COMMENTED are neither an approval nor a block.
approval_from_pr() {
  if ! rows="$(latest_reviews "$1")"; then return 2; fi
  if [ -z "$rows" ]; then return 1; fi
  blockers="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "CHANGES_REQUESTED" { print $1 }')"
  if [ -n "$blockers" ]; then
    blockers="$(printf '%s\n' "$blockers" | tr '\n' ',' | sed 's/,$//')"
    echo "task-state: PR '$1' is not approved — reviewer(s) ${blockers} requested changes" >&2
    return 1
  fi
  ok="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "APPROVED"' | head -1)"
  [ -n "$ok" ] || return 1
  printf '%s\t%s\n' "$(printf '%s' "$ok" | cut -f1)" "$(printf '%s' "$ok" | cut -f3 | cut -c1-10)"
}

# pr_ref_from_intent <file> — the intent's own `pr:` field as a ref gh understands. The template ships
# the value as a placeholder, and a PR URL may name a different repository than the current one, so
# both spellings are normalized here rather than guessed at the call site. Returns 1 when there is no
# PR to merge (absent or the template placeholder) and 2 when there is a value we cannot parse - the
# caller says which, because "no pr: field" and "a pr: field I cannot read" are different mistakes.
pr_ref_from_intent() {
  local raw base rest num ref
  raw="$(frontmatter_field "$1" pr || true)"
  # The field is hand-written YAML, so quoting is the common case: pr: "42", pr: '42', and a quoted
  # URL all mean the ref without the quotes. Strip one layer of matching surrounding quotes after the
  # placeholder angle brackets, which the template itself ships as pr: <optional PR URL or #number>.
  raw="$(printf '%s' "$raw" | sed -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
  raw="${raw//[<>]/}"
  [ -n "$raw" ] || return 1
  # An unexpanded template value is not a malformed ref, it is no ref at all: the intent template
  # ships pr: <optional PR URL or #number>, and agents that fill the field by hand just as easily
  # write {{PR_URL}} or {{pr_url}}. Return the same "no PR" answer as an absent field, so the caller
  # asks for --pr instead of being told to fix a field that was never filled in on purpose.
  case "$raw" in
    *optional*|*none*|*PR\ URL*|*"{{"*|*"}}"*) return 1 ;;
  esac
  # Reduce every spelling to one ref gh understands, in parameter expansion rather than sed: a
  # 'sed -e' chain that substitutes twice prints two candidates, and one '#' inside a replacement
  # closes an s#...#...#p early on BSD sed. Both of those bit this function once already.
  base="$raw"
  case "$base" in
    *[a-zA-Z]://*) base="${base#*://}"; base="${base#*/}" ;;   # https://host/owner/name/...
    *@*)           base="${base#*@}"; base="${base#*:}" ;;     # git@host:owner/name/...
  esac
  case "$base" in
    *"/pull/"*)
      rest="${base%%/pull/*}"; num="${base##*/pull/}"; num="${num%%[^0-9]*}"
      case "$num" in ''|*[!0-9]*) return 2 ;; esac
      ref="$rest#$num" ;;
    \#*) ref="${base#\#}" ;;
    *\#*) ref="${base%%#*}#${base#*#}" ;;
    *)   ref="$base" ;;
  esac
  ref="$(printf '%s' "$ref" | tr -d '[:space:]')"
  [ -n "$ref" ] || return 2
  case "$ref" in *[!0-9A-Za-z_./#-]*) return 2 ;; esac
  printf '%s' "$ref"
}

case "$cmd" in
  check-intent-approved)
    [ -f "$path" ] || fail "intent file '$path' missing"
    # An approving review on the intent's PR *is* the human decision; the file is the record of it.
    # So the PR is read first, and the file is the fallback — not the other way round, which is what
    # refused an intent whose reviewer had already clicked "Approve" while the file still said pending.
    pr_checked="no"
    if [ -n "$pr_ref" ]; then
      pr_checked="yes"
      if approval="$(approval_from_pr "$pr_ref")"; then
        printf 'task-state: intent approved (source: PR %s, reviewer %s, %s) — %s\n' \
          "$pr_ref" "$(printf '%s' "$approval" | cut -f1)" "$(printf '%s' "$approval" | cut -f2)" "$path"
        exit 0
      fi
    fi
    value="$(frontmatter_field "$path" status || true)"
    if [ "$value" != "approved" ]; then
      if [ "$pr_checked" = "yes" ]; then
        fail "intent '$path' is not approved (status: '${value:-<none>}') and PR '$pr_ref' carries no approving review — both sources were checked"
      fi
      fail "intent '$path' is not approved (status: '${value:-<none>}')"
    fi
    if [ "$pr_checked" = "yes" ]; then
      echo "task-state: intent approved (source: file) — $path (PR '$pr_ref' carries no approving review)"
    else
      echo "task-state: intent approved — $path"
    fi
    ;;
  check-spec)
    [ -f "$path" ] || fail "spec file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "spec" ] || fail "'$path' is not a spec (phase: '${value:-<none>}')"
    echo "task-state: spec valid — $path"
    ;;
  check-plan)
    [ -f "$path" ] || fail "plan file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "plan" ] || fail "'$path' is not a plan (phase: '${value:-<none>}')"
    echo "task-state: plan valid — $path"
    ;;
  check-chain)
    dir="$(dirname "$path")"
    [ -f "$path" ] || fail "plan file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "plan" ] || fail "'$path' is not a plan (phase: '${value:-<none>}')"
    [ -f "$dir/1_spec.md" ] || fail "task dir '$dir' is missing 1_spec.md"
    if [ -f "$dir/0_intent.md" ]; then
      ref_phase="$(frontmatter_field "$dir/0_intent.md" phase || true)"
      [ "$ref_phase" = "intent-ref" ] || \
        fail "task '$dir' has 0_intent.md but its 'phase:' is not 'intent-ref' (found: '${ref_phase:-<none>}') — it must be a reference stub, never a copy of the intent"
      src="$(frontmatter_field "$dir/0_intent.md" source || true)"
      [ -n "$src" ] || \
        fail "task '$dir' has 0_intent.md but it has no 'source:' frontmatter pointing at the original intent"
      srcpath="$dir/$src"
      [ -f "$srcpath" ] || \
        fail "task '$dir' is intent-seeded but its 0_intent.md source '$src' does not exist"
      ival="$(frontmatter_field "$srcpath" status || true)"
      [ "$ival" = "approved" ] || \
        fail "task '$dir' is intent-seeded (0_intent.md → $src) but that intent is not approved (status: '${ival:-<none>}')"
      echo "task-state: chain valid — spec + plan present, intent approved ($src) — $dir"
    else
      echo "task-state: chain valid — spec + plan present, ad-hoc (no intent required) — $dir"
    fi
    ;;
  merge-intent-pr)
    [ -f "$path" ] || fail "intent file '$path' missing"
    if [ -z "$pr_ref" ]; then
      pr_status=0
      pr_ref="$(pr_ref_from_intent "$path")" || pr_status=$?
      case "$pr_status" in
        0) : ;;
        2) fail "the intent's 'pr:' field is '$(frontmatter_field "$path" pr || true)' which is neither a PR number, an 'owner/name#number' nor a PR URL — fix the field or pass --pr <pr-ref>" ;;
        *) fail "no PR to merge — pass --pr <pr-ref> or give the intent a 'pr:' field with the PR URL or #number" ;;
      esac
    fi
    # The caller is not trusted to have checked the approval: this merge lands in a shared
    # repository, and an unapproved intent's PR is never merged, whatever flags arrive. The same
    # reader the gate uses decides, so the two cannot disagree about the same PR.
    if ! command -v gh >/dev/null 2>&1; then
      echo "task-state: $cmd — 'gh' not found; nothing merged (ask the developer to merge PR $pr_ref by hand, or install gh)" >&2
      exit 3
    fi
    if ! gh auth status >/dev/null 2>&1; then
      echo "task-state: $cmd — 'gh' is not authenticated; nothing merged (ask the developer to merge PR $pr_ref by hand)" >&2
      exit 3
    fi
    # State first, approval second. An already-merged PR is a no-op whatever its reviews say, so
    # reading the board before the gate is what makes this idempotent instead of a second refusal
    # the caller has to interpret. The approval still gates the only write below, and that write is
    # reachable only from OPEN.
    pr_json="$(gh pr view "$pr_ref" --json state,mergeable,mergeStateStatus,title 2>&1)" || \
      fail "gh could not read PR '$pr_ref' ($(printf '%s' "$pr_json" | head -1)); nothing merged"
    pr_state="$(printf '%s' "$pr_json" | awk -F'"state": *"' 'NF>1 { split($2, a, /[",]/); print a[1] }')"
    pr_mergeable="$(printf '%s' "$pr_json" | awk -F'"mergeable": *"' 'NF>1 { split($2, a, /[",]/); print a[1] }')"
    pr_status="$(printf '%s' "$pr_json" | awk -F'"mergeStateStatus": *"' 'NF>1 { split($2, a, /[",]/); print a[1] }')"
    pr_title="$(printf '%s' "$pr_json" | awk -F'"title": *"' 'NF>1 { split($2, a, /[",]/); print a[1] }')"
    if [ "$pr_state" = "MERGED" ]; then
      echo "task-state: $cmd — PR $pr_ref is already merged; nothing to do — $path"
      exit 0
    fi
    [ "$pr_state" = "OPEN" ] || fail "PR '$pr_ref' is ${pr_state:-<unknown>}, not open; nothing merged"
    [ "$pr_mergeable" = "CONFLICTING" ] && \
      fail "PR '$pr_ref' has conflicts (${pr_status:-unknown}); nothing merged — resolve them first, this command never forces a merge"
    if ! approval="$(approval_from_pr "$pr_ref")"; then
      fail "refusing to merge PR '$pr_ref' — it carries no approving review. Merging an intent nobody approved is the one mistake this command exists to prevent"
    fi
    if [ "$merge_now" -eq 0 ]; then
      printf 'task-state: %s — would merge PR %s (%s) with a merge commit; approved by %s on %s; state %s/%s\n' \
        "$cmd" "$pr_ref" "${pr_title:-<untitled>}" "$(printf '%s' "$approval" | cut -f1)" \
        "$(printf '%s' "$approval" | cut -f2)" "$pr_state" "${pr_status:-unknown}"
      echo "task-state: $cmd — nothing merged. Re-run with --yes only after the developer answers yes in this turn"
      exit 0
    fi
    # --merge only. No --admin (bypassing branch protection is the developer's decision), no
    # --delete-branch (never asked for), no --squash/--rebase/--auto (history and method are the
    # repository's business). If the repo's protection refuses, the failure is reported and the PR
    # stays open for a human.
    if ! out="$(gh pr merge "$pr_ref" --merge 2>&1)"; then
      printf 'task-state: %s — gh pr merge failed, PR %s is still open:\n%s\n' \
        "$cmd" "$pr_ref" "$(printf '%s' "$out" | head -3)" >&2
      exit 1
    fi
    merged_at="$(gh pr view "$pr_ref" --json state,mergeCommit \
      -q '"state=" + .state + " mergeCommit=" + (.mergeCommit.oid // "none")' 2>/dev/null || echo 'state=unknown')"
    echo "task-state: $cmd — merged PR $pr_ref (${pr_title:-<untitled>}), approved by $(printf '%s' "$approval" | cut -f1) — $merged_at — $path"
    ;;
  check-kb)
    dir="$path"
    [ -d "$dir" ] || fail "task dir '$dir' does not exist"
    # Research-only / N/A tasks have no 3_memory.md — nothing to gate.
    [ -f "$dir/3_memory.md" ] || {
      echo "task-state: check-kb — no 3_memory.md (research-only / N/A task), nothing to gate — $dir"
      exit 0
    }
    # --path was parsed into kb_path by the shared option loop above; default <toplevel>/knowledge
    if [ -n "$kb_path" ]; then
      kb="$kb_path"
    else
      top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      kb="$top/knowledge"
    fi
    # The KB must be seeded and structurally sound before coverage is claimed.
    [ -f "$kb/index.md" ] || fail "knowledge-base '$kb/index.md' missing — seed it first (core/scripts/scaffold-knowledge.sh)"
    [ -f "$kb/schema.md" ] || fail "knowledge-base '$kb/schema.md' missing — seed it first (core/scripts/scaffold-knowledge.sh)"
    slug="$(basename "$dir")"
    gaps=""
    # Sources synopsis must be cataloged.
    if ! grep -qF "sources/$slug.md" "$kb/index.md"; then
      gaps="$gaps sources/$slug.md not in knowledge/index.md"
    fi
    # One decision-record row per raw adr/NNNN-*.md.
    if [ -d "$dir/adr" ]; then
      for adr in "$dir"/adr/*.md; do
        [ -f "$adr" ] || continue
        base="$(basename "$adr")"
        if ! grep -qF "$base" "$kb/index.md"; then
          gaps="$gaps decision-records/$base not in knowledge/index.md"
        fi
      done
    fi
    # Verified-facts page when 4_verify.md exists.
    if [ -f "$dir/4_verify.md" ]; then
      if ! grep -qF "verified-facts/$slug.md" "$kb/index.md"; then
        gaps="$gaps verified-facts/$slug.md not in knowledge/index.md"
      fi
      if [ ! -f "$kb/verified-facts/$slug.md" ]; then
        gaps="$gaps verified-facts/$slug.md missing"
      fi
    fi
    if [ -n "$gaps" ]; then
      fail "knowledge-base coverage incomplete for '$dir':$gaps — run core/scripts/kb-ingest.sh $dir after the agent adds the pages"
    fi
    echo "task-state: check-kb — knowledge-base coverage complete — $dir → $kb"
    ;;
  check-adr)
    [ -f "$path" ] || fail "spec file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "spec" ] || fail "'$path' is not a spec (phase: '${value:-<none>}')"
    dir="$(dirname "$path")"
    section="$(awk '
      /^## Architectural decisions[[:space:]]*$/ { f=1; next }
      f && /^## / { exit }
      f { print }
    ' "$path")"
    [ -n "$section" ] || {
      echo "task-state: check-adr — no '## Architectural decisions' section (pre-existing spec, none expected) — $path"
      exit 0
    }
    refs="$(printf '%s\n' "$section" | grep -oE 'adr/[0-9]{4}-[A-Za-z0-9._-]+\.md' | sort -u || true)"
    if [ -n "$refs" ]; then
      for r in $refs; do
        [ -f "$dir/$r" ] || fail "spec '$path' references '$r' but the file is missing in task dir '$dir'"
        av="$(frontmatter_field "$dir/$r" phase || true)"
        [ "$av" = "adr" ] || fail "adr file '$r' has no 'phase: adr' frontmatter (phase: '${av:-<none>}')"
      done
      echo "task-state: check-adr — $(printf '%s\n' "$refs" | wc -l | tr -d ' ') referenced ADR(s) valid — $path"
      exit 0
    fi
    # No adr/ links: valid only when the section declares N/A (word-boundary match, so incidental
    # "N/A" inside prose is not enough once the section references real files — but here there are none).
    if printf '%s\n' "$section" | grep -qE '(^|[^A-Za-z0-9])N/A([^A-Za-z0-9]|$)'; then
      echo "task-state: check-adr — spec declares no ADRs (N/A), nothing to validate — $path"
      exit 0
    fi
    fail "spec '$path' has '## Architectural decisions' but references no adr/ files — write the ADR(s) or state N/A"
    ;;
  *)
    echo "task-state: unknown subcommand '$cmd'" >&2
    echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain|check-adr|check-kb|merge-intent-pr> <path> [--pr <pr-ref>] [--yes] [--path <kb>]" >&2
    exit 2
    ;;
esac
