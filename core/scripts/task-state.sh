#!/usr/bin/env bash
# task-state — validation of the per-SDLC-stage artifact chain, and the one write the build stage
# needs. Agent-agnostic.
#
# The stage commands (/monorepo-harness-spec, -plan, -build) call this before acting so a stage can
# never be run against a stale or unwarranted input. It mirrors the frontmatter-parsing style of
# memory-gate.sh (plain grep/sed, no dependencies).
#
# `stage` (a read) and `mark-build` (the only write) are the two halves of one question — "has this
# task reached the build stage?" — and they live here so there is exactly one answer to it.
#
# Subcommands (each prints a reason on stdout and exits 1 on failure, 0 on success):
#   check-intent-approved <intent.md> [--pr <pr-ref>]
#                                        — file exists AND, when a PR is named, that PR carries an
#                                          approving review. The PR is the human decision and is
#                                          read through forge.sh, so the forge may be GitHub,
#                                          GitLab, Bitbucket or Gitea and the read may come from
#                                          that platform's CLI or from REST. The intent file is
#                                          consulted ONLY when there is no PR to read; an approval
#                                          that cannot be read is UNKNOWN and is refused, never
#                                          replaced by the file's own `status: approved`. On success
#                                          the source is named, with the reviewer and date from the
#                                          PR review so the caller can record them without
#                                          inventing them.
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
#   stage <task_dir>                     — prints the task's stage and exits 0, always:
#                                          none   — no spec in the dir (nothing to enforce)
#                                          spec   — spec, no plan (the spec stage is waiting)
#                                          plan   — plan, no `build_started` on it (research-only
#                                                   or plan stage; the build has not started)
#                                          build  — the plan carries `build_started`, so the
#                                                   task is being implemented and memory/verify
#                                                   are owed. A dir that does not exist is `none`;
#                                          this subcommand never fails the caller.
#   mark-build <plan.md>                 — the one write: record `build_started: <ISO-8601>` in the
#                                          plan's frontmatter. Refuses anything that is not
#                                          `phase: plan`, and is write-once — a re-run leaves the
#                                          first timestamp, so the record of when the build
#                                          started cannot be rewritten by a later one.
#   merge-intent-pr <intent.md> [--pr <ref>] [--yes]
#                                        — merge the intent's own PR, but only on an explicit answer
#                                          and only when the PR itself carries an approving review.
#                                          Reads `pr:` from the intent when --pr is absent; every
#                                          spelling of a ref, on every supported forge, is read by
#                                          forge.sh so the two commands cannot disagree. Without
#                                          --yes it prints what it would do and exits 0 (a dry run
#                                          the caller shows before asking). With --yes it runs the
#                                          forge's merge: a MERGE COMMIT and nothing else, never
#                                          --admin (bypassing branch protection is a human's call),
#                                          never --delete-branch, never
#                                          --squash/--rebase/--auto. An already-merged PR is
#                                          reported and exits 0, so a re-run is harmless; a closed or
#                                          conflicting PR fails. Exit 3 means NOT DONE - the harness
#                                          could not read the PR, so it could not verify anything and
#                                          merged nothing.
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
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh stage \
#        apps/api/.agents/artifacts/task_2026_08_27_add_auth
#   bash .agents/monorepo-agents-harness/core/scripts/task-state.sh mark-build \
#        apps/api/.agents/artifacts/task_2026_08_27_add_auth/2_plan.md

set -euo pipefail

cmd="${1:-}"
[ -n "$cmd" ] || { echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain|check-adr|check-kb|stage|mark-build|merge-intent-pr> <path> [--pr <pr-ref>] [--yes] [--path <kb>]" >&2; exit 2; }
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
# Two subcommands answer "is this PR approved?", so the answer is one reader. 0.4.0-rc.5 had this
# inline in check-intent-approved and filtered on state itself after a test showed that trusting
# gh's jq filter let a CHANGES_REQUESTED review through. A second copy of that filter for the merge
# could disagree with the first about the same PR, which is the one bug class a gate cannot have.
#
# 0.4.0-rc.7 moved the read to forge.sh, which is the harness's answer to "where does this project's
# code live and how can a tool reach it". The PR may be on GitHub, GitLab, Bitbucket or Gitea, be
# reached by that platform's CLI or by REST, or be reachable only through a mechanism this shell
# cannot drive (a project MCP server or skill) - and in that last case the answer is that the
# approval is UNKNOWN, not that it is absent. Reading it here would have kept a second, GitHub-only
# copy of that logic, and would have kept inventing an answer on projects this harness cannot see.
FORGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/forge.sh"

# latest_reviews <pr-ref> — print "<login>\t<state>\t<submittedAt>" for each reviewer's LATEST
# review. Return 1 (reason on stderr) when no read path can be probe-verified or the PR is
# unreadable. The caller then reports the approval as unknown, which is not the same as "not
# approved" and is never replaced by the intent file's own claim.
latest_reviews() {
  bash "$FORGE" reviews "$1" 2>&1
}

# approval_from_pr <pr-ref> — 0 and prints "<reviewer>\t<date>" when the PR is approved; 1 when it is
# not (an approval is required AND no reviewer may be asking for changes); 2 when the PR could not be
# read at all. DISMISSED and COMMENTED are neither an approval nor a block.
#
# The 2 is load-bearing: 0.4.0-rc.6 used to fold "unreadable" into 1, and the file fallback turned
# that into consent. An approval nobody can verify is not an approval.
approval_from_pr() {
  local rows
  if ! rows="$(latest_reviews "$1")"; then
    echo "$rows" >&2
    return 2
  fi
  if [ -z "$rows" ]; then return 1; fi
  # forge.sh already reduces each reviewer to their latest review, so the board this gate reads is
  # the same board the merge gate reads.
  blockers="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "CHANGES_REQUESTED" || $2 == "REQUEST_CHANGES" { print $1 }')"
  if [ -n "$blockers" ]; then
    blockers="$(printf '%s\n' "$blockers" | tr '\n' ',' | sed 's/,$//')"
    echo "task-state: PR '$1' is not approved — reviewer(s) ${blockers} requested changes" >&2
    return 1
  fi
  ok="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "APPROVED"' | head -1)"
  [ -n "$ok" ] || return 1
  printf '%s\t%s\n' "$(printf '%s' "$ok" | cut -f1)" "$(printf '%s' "$ok" | cut -f3 | cut -c1-10)"
}

# pr_ref_from_intent <file> — the intent's own `pr:` field, passed through forge.sh's ref reader so
# the value is understood the same way in both places. The template ships the field as a placeholder,
# and a PR URL may name a different repository than the current one. Returns 1 when there is no PR to
# merge (absent or the template placeholder) and 2 when there is a value we cannot parse - the caller
# says which, because "no pr: field" and "a pr: field I cannot read" are different mistakes.
#
# 0.4.0-rc.6 did this normalisation here, with a GitHub-shaped parser: it accepted owner/name#42 and
# /pull/42 and nothing else. A GitLab '!' ref, a Bitbucket /pull-requests/ URL or a self-hosted host
# was a parse failure here even though forge.sh could read it fine - so the harness refused a PR it
# was about to be handed. One reader, one answer.
pr_ref_from_intent() {
  local raw ref
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
  # forge.sh owns the spelling of a ref on every platform. It prints "<n> <ref>" and exits 2 on a
  # ref it cannot read, which is this function's "2".
  ref="$(bash "$FORGE" resolve "$raw" 2>/dev/null | sed -n 's/.* id=\([0-9][0-9]*\) .*/\1/p')" || return 2
  if [ -n "$ref" ]; then printf '%s' "$raw"; return 0; fi
  # No id could be extracted: either the value names no pull request, or forge could not resolve it.
  # Ask forge directly which of the two it is rather than guessing here.
  resolved="$(bash "$FORGE" resolve "$raw" 2>&1)" || return 2
  case "$resolved" in
    *"id=<none>"*) printf '%s' "$raw"; return 0 ;;
    *) return 2 ;;
  esac
}

case "$cmd" in
  check-intent-approved)
    [ -f "$path" ] || fail "intent file '$path' missing"
    # An approving review on the intent's PR *is* the human decision; the file is the record of it.
    # So when a PR exists it is read first, and the file is only consulted when there is no PR to
    # read - which is the direction that cannot invent consent.
    #
    # 0.4.0-rc.7 removed the other half of that rule. rc.6 fell back to the file when the PR could
    # not be READ, and on a non-GitHub project the PR was never readable, so a `status: approved`
    # line in a file the same agent had just written stood in for a human decision that never
    # happened. An unreadable PR is now a refusal: the approval is UNKNOWN, not absent, and UNKNOWN
    # is not a yes. The file is still authoritative for the one case where no PR exists.
    pr_checked="no"
    if [ -n "$pr_ref" ]; then
      pr_checked="yes"
      pr_status=0
      approval="$(approval_from_pr "$pr_ref")" || pr_status=$?
      case "$pr_status" in
        0)
          printf 'task-state: intent approved (source: PR %s, reviewer %s, %s) — %s\n' \
            "$pr_ref" "$(printf '%s' "$approval" | cut -f1)" "$(printf '%s' "$approval" | cut -f2)" "$path"
          exit 0 ;;
        2) fail "the approval on PR '$pr_ref' could not be read, so it is UNKNOWN — not approved and not refused. Answer in this turn, or merge it on the forge yourself; this gate will not read an intent file in place of a human decision" ;;
        *) : ;;
      esac
    fi
    value="$(frontmatter_field "$path" status || true)"
    if [ "$value" != "approved" ]; then
      if [ "$pr_checked" = "yes" ]; then
        fail "intent '$path' is not approved (status: '${value:-<none>}') and PR '$pr_ref' carries no approving review — both sources were checked"
      fi
      fail "intent '$path' is not approved (status: '${value:-<none>}')"
    fi
    if [ "$pr_checked" = "yes" ]; then
      fail "PR '$pr_ref' carries no approving review, and the intent file is not consulted in its place: an intent is merged on a human decision, not on a line in a file the agent wrote"
    fi
    echo "task-state: intent approved (source: file, no PR to read) — $path"
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
    # State first, approval second. An already-merged PR is a no-op whatever its reviews say, so
    # reading the board before the gate is what makes this idempotent instead of a second refusal
    # the caller has to interpret. The approval still gates the only write below.
    #
    # forge.sh answers the same question for the merge itself, but the caller needs the answer
    # BEFORE it decides whether to gate at all: refusing an already-merged PR for "no approving
    # review" is a false alarm about work that is already done.
    forge_status=0
    state_line="$(bash "$FORGE" state "$pr_ref" 2>&1)" || forge_status=$?
    case "$forge_status" in
      0) : ;;
      3) forge_problem="the harness could not read PR $pr_ref at all" ;;
      *) forge_problem="$(printf '%s' "$state_line" | tail -1)" ;;
    esac
    if [ "$forge_status" -ne 0 ]; then
      printf '%s\n' "$state_line" >&2
      if [ "$forge_status" -eq 3 ]; then
        echo "task-state: $cmd — nothing merged. Ask the developer to merge PR $pr_ref by hand, or install a CLI/token for the forge it lives on" >&2
        exit 3
      fi
      fail "$forge_problem"
    fi
    case "$state_line" in
      *"state=MERGED"*)
        echo "task-state: $cmd — PR $pr_ref is already merged; nothing to do — $path"
        exit 0 ;;
    esac
    if [ "$merge_now" -eq 0 ]; then
      forge_out="$(bash "$FORGE" merge "$pr_ref" --explain 2>&1)" || {
        printf '%s\n' "$forge_out" >&2
        printf 'task-state: %s — nothing merged on PR %s. The reason is above; nothing was changed on the forge\n' \
          "$cmd" "$pr_ref" >&2
        exit 3
      }
      printf 'forge: %s\n' "$forge_out"
      # The approval the developer is being shown has to be read from the same board, not asserted.
      if ! approval="$(approval_from_pr "$pr_ref")"; then
        fail "refusing to plan a merge of PR '$pr_ref' — it carries no approving review. Merging an intent nobody approved is the one mistake this command exists to prevent"
      fi
      printf 'task-state: %s — approved by %s on %s\n' "$cmd" \
        "$(printf '%s' "$approval" | cut -f1)" "$(printf '%s' "$approval" | cut -f2)"
      echo "task-state: $cmd — nothing merged. Re-run with --yes only after the developer answers yes in this turn"
      exit 0
    fi
    # --yes given: the approval is still re-read here, so a caller cannot pass --yes to skip the gate.
    # forge.sh re-reads the state, refuses a closed or conflicting PR, and reports a REST merge only
    # when the response itself confirms it.
    if ! approval="$(approval_from_pr "$pr_ref")"; then
      fail "refusing to merge PR '$pr_ref' — it carries no approving review. Merging an intent nobody approved is the one mistake this command exists to prevent"
    fi
    merge_status=0
    merge_out="$(bash "$FORGE" merge "$pr_ref" 2>&1)" || merge_status=$?
    printf 'forge: %s\n' "$merge_out"
    if [ "$merge_status" -ne 0 ]; then
      printf 'task-state: %s — nothing merged on PR %s. The reason is above; nothing was changed on the forge\n' \
        "$cmd" "$pr_ref" >&2
      [ "$merge_status" -eq 3 ] && exit 3
      exit 1
    fi
    echo "task-state: $cmd — merged PR $pr_ref, approved by $(printf '%s' "$approval" | cut -f1) — $path"
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
  stage)
    # The one answer to "which stage is this task in". Exits 0 whatever it finds — a caller asks this
    # to decide what to enforce, and a dir with no spec is a legitimate answer, not an error.
    dir="$path"
    if [ ! -d "$dir" ]; then
      printf 'none\n'
      exit 0
    fi
    # Legacy layout backcompat, same as the gate: a pre-rename task dir exposes its spec as
    # 2_spec.md and its plan as 1_plan.md.
    spec="$dir/1_spec.md"; [ -f "$spec" ] || spec="$dir/2_spec.md"
    plan="$dir/2_plan.md"; [ -f "$plan" ] || plan="$dir/1_plan.md"
    # The marker is asked first, and it is the only signal that counts on its own. A build whose
    # spec was deleted afterwards is still a build — and the gate must be able to say so, rather
    # than read the dir as "nothing started".
    if [ -f "$plan" ] && [ -n "$(frontmatter_field "$plan" build_started || true)" ]; then
      printf 'build\n'
    elif [ -f "$spec" ]; then
      if [ -f "$plan" ]; then printf 'plan\n'; else printf 'spec\n'; fi
    else
      printf 'none\n'
    fi
    ;;
  mark-build)
    [ -f "$path" ] || fail "plan file '$path' missing"
    value="$(frontmatter_field "$path" phase || true)"
    [ "$value" = "plan" ] || fail "'$path' is not a plan (phase: '${value:-<none>}')"
    # Write-once. The field records when the build started; a second call is a re-run of the same
    # build, and letting it move the timestamp would make the record a function of how often the
    # command was repeated.
    existing="$(frontmatter_field "$path" build_started || true)"
    if [ -n "$existing" ]; then
      echo "task-state: build already started — $path (build_started: $existing)"
      exit 0
    fi
    stamped="$(date +%Y-%m-%dT%H:%M:%S%z)"
    # Inserted as a new frontmatter line right after `phase: plan`, so the rest of the file — and any
    # line numbers a tool cached — is untouched. awk rewrites in place through a temp file; a failure
    # leaves the original plan exactly as it was.
    tmp="$path.task-state.$$"
    if ! awk -v ts="$stamped" '
      NR==1 && $0 !~ /^---[[:space:]]*$/ { print; next }
      { print }
      !done && $0 ~ /^[[:space:]]*phase[[:space:]]*:[[:space:]]*plan[[:space:]]*$/ { print "build_started: " ts; done=1 }
    ' "$path" >"$tmp" 2>/dev/null; then
      rm -f "$tmp"
      fail "could not write 'build_started' into '$path'"
    fi
    if ! mv "$tmp" "$path"; then
      rm -f "$tmp"
      fail "could not replace '$path' with the marked plan"
    fi
    echo "task-state: build started — $path (build_started: $stamped)"
    ;;
  *)
    echo "task-state: unknown subcommand '$cmd'" >&2
    echo "usage: task-state.sh <check-intent-approved|check-spec|check-plan|check-chain|check-adr|check-kb|stage|mark-build|merge-intent-pr> <path> [--pr <pr-ref>] [--yes] [--path <kb>]" >&2
    exit 2
    ;;
esac
