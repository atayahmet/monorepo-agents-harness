# Session Log — monorepo-agents-harness

Working-session history for **this workspace** (`monorepo-agents-harness` repository root). Append one entry
per session (newest last); bump the version each session. Every entry MUST record the **artifact
directory** of that session — the task dir holding its `1_spec.md` / `2_plan.md` / `3_memory.md` /
`4_verify.md`. **Read this before starting any task that targets this workspace.**

<!-- Entry template:
## v0.0.1 — YYYY-MM-DD
- Scope: <what this session worked on>
- Artifacts: <this-workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/   # session's plan/spec/memory/verify dir
- Outcome: <result / commit SHAs>
-->

## v0.2.0-rc.3 — 2026-09-03
- Scope: Add `.agents/.harness-map.json` tracking for `self-improvement-workflow` components; introduce `core/scripts/update-harness-map.sh` helper; update skill, rule template, root-AGENTS.md, and adapter command files.
- Artifacts: `.agents/artifacts/task_2026_09_03_harness_map/`
- Outcome: Implemented and committed in 533df6e812edf58d1f94ca511d1e966584c68af2. Script syntax-checked, manually exercised in a temp clone, and verified against the installed bundle.

## v0.2.0-rc.5 — 2026-09-21
- Scope: Apply the first three findings of the `agent-workflow/SKILL.md` review — fix the frontmatter
  description and artifact count, replace the hardcoded workspace example list with a derived rule,
  and document the research-only path consistently with the `-plan`/`-build` gates.
- Artifacts: `.agents/artifacts/task_2026_09_21_agent_workflow_skill_fixes/`
- Outcome: VERSION bumped to `0.2.0-rc.5`; CHANGELOG + index updated; skill doc edits verified via
  grep, `audit-install.sh`, and `task-state.sh check-adr`; committed in a single commit.

## v0.2.0-rc.6 — 2026-09-21
- Scope: Add a build-scope confinement rule so `/monorepo-harness-build` implementations on consumer
  projects never create apps/packages absent from the approved spec and plan. Rule shipped at every
  instruction layer: `agent-workflow/SKILL.md` (Build scope section + `-build` row note),
  `core/root-AGENTS.md` (Critical Gotcha 5), and the three adapters' `/monorepo-harness-build` entry
  points (byte-identical step 3).
- Artifacts: `.agents/artifacts/task_2026_09_21_build_scope_confinement/`
- Outcome: VERSION bumped to `0.2.0-rc.6`; CHANGELOG + `changelogs/version-0.2.0-rc.6.md` added;
  verified via diff of the three stubs, greps, `audit-install.sh`, and `task-state.sh check-adr`;
  committed in a single commit.

## v0.3.0-rc.0 — 2026-09-22
- Scope: Ship a `/monorepo-harness-changeset` capability on all three adapters — drafts
  changesets-compatible release entries (`.changeset/monorepo-harness-<YYYYMMDD>-<slug>-r<N>.md`)
  from a finished task's spec/plan/memory, without adding `@changesets/cli`. New
  `core/scripts/draft-changeset.sh` (check-plan gate, `.changeset/` preflight, explicit
  `--package`/`--bump` pairs as user policy, revision-based duplicate guard, summary derived
  memory → spec → plan) + 78-line `core/skills/changeset-workflow/SKILL.md` (user-imposed ≤80 cap).
  Adapter stubs + manifest rows added; opencode template gained the skill's `instructions` entry.
  Docs: `PORTABILITY.md` matrix row + semantic bullet, README/INSTALL/adapter READMEs,
  `adapters/AGENTS.md` Rule 7. No `core/root-AGENTS.md` change. Version → `0.3.0-rc.0` with
  `changelogs/version-0.3.0-rc.0.md` prompt (adapter re-apply + opencode manual instructions merge).
- Artifacts: `.agents/artifacts/task_2026_09_22_changeset_draft_command/`
- Outcome: verified via a 13-case fixture doctest of `draft-changeset.sh`, parity greps across the
  three stubs, line-count checks, and a scratch install: `install-harness.sh --from <repo>` + all
  three `install-adapter.sh` into `/tmp/harness-audit-consumer`, `audit-install.sh --against <repo>`
  clean; `task-state.sh check-chain` + `check-adr` pass. Committed in a single commit.

## v0.2.0-rc.7 — 2026-09-21
- Scope: Slim `core/skills/agent-workflow/SKILL.md` from 371 to 240 lines without losing capability —
  the five inline fill-in templates moved to a new `core/skills/agent-workflow/templates/` dir
  (byte-identical content, one pointer per phase), the two ASCII directory diagrams consolidated into
  one tree, and the duplicated research-only explanation collapsed to the Stage-commands paragraph.
  All normative prose (phase timing, gates, stop-and-wait, Build-scope, edge cases, script/skill
  cross-references) preserved. Required bookkeeping only: VERSION → `0.2.0-rc.7`, CHANGELOG section
  + compare links, `adapters/AGENTS.md` one-sentence wording fix. No script, manifest, adapter, or
  gate change; no `changelogs/version-0.2.0-rc.7.md` prompt (templates auto-install via the `core`
  row; `changelogs/README.md` rule).
- Artifacts: `.agents/artifacts/task_2026_09_21_agent_workflow_skill_trim/`
- Outcome: verified via `wc -l`, greps (no inline template bodies, all 5 templates referenced),
  read-through, and a scratch install: `install-harness.sh` + `install-adapter.sh claude-code` into
  `/tmp/harness-audit-consumer`, `audit-install.sh --against <repo>` clean, `task-state.sh check-adr`
  pass, `memory-gate.sh` pass. Committed in a single commit.

## v0.3.0-rc.1 — 2026-09-22
- Scope: Ship a starter project rule for local `AGENTS.md` upkeep to every consumer's root
  `.agents/rules/`. New `core/project-rules-template/local-agents-md.md` (seed rule; covers the
  workspace root **and nested subdirectories at any depth**) + `core/scripts/scaffold-project-agents.sh`
  (idempotent seeder, never overwrites, re-seeds deleted files, registers created rules in
  `.agents/.harness-map.json` via `update-harness-map.sh`, jq best-effort). Wired into
  `install-harness.sh` step 4b (full install; `--sync-only` skips by design), verified by new
  `audit-install.sh` Check 5b (presence only), shipped as an explicit `core/install-manifest.txt`
  row, and referenced from `core/root-AGENTS.md` Reference Map. `harness-update/SKILL.md` step 9.5
  gained the remediation. Version `0.3.0-rc.0` → `0.3.0-rc.1` with `changelogs/version-0.3.0-rc.1.md`
  prompt (`scaffold-project-agents.sh` command for updates). README/INSTALL/CHANGELOG updated.
  Adapter manifests deliberately untouched (rule is adapter-neutral; `copy`/`link` rows would
  clobber/symlink a user-editable file).
- Artifacts: `.agents/artifacts/task_2026_09_22_project_rules_seed/`
- Outcome: verified via `bash -n` on 3 scripts, three fresh scratch installs
  (`/tmp/harness-rc1{,-b,-c}-consumer`) with `audit-install.sh --against <repo>` clean, idempotency /
  no-overwrite / re-seed-after-delete checks, `.harness-map.json` registration via jq, audit gap path
  (exit 1 + remediation message), and grep of the generated `AGENTS.md` Reference Map row. Committed
  in a single commit.

## v0.3.0-rc.1 — 2026-09-23
- Scope: Plan-mode design session for the Karpathy-style knowledge base. Consolidated prior art
  (Karpathy "LLM Wiki" gist + community implementations like the karpathy-wiki-protocol) with the
  harness's existing artifact machinery (`3_memory.md`/`4_verify.md`/`adr/`, memory-gate, check-adr).
  User confirmed three decisions: KB at consumer repo root as committed `knowledge/`; ingest sources
  restricted to `3_memory.md` + `adr/` + `4_verify.md`; gate owned by `task-state.sh check-kb`. Wrote
  `1_spec.md` (mapping table, contracts, acceptance criteria, verification plan) + ADR 0001
  (compiled root knowledge layer, task-end incremental ingest). No code, manifest, or version change
  yet — spec phase only, stopping for plan approval per agent-workflow Phase 1.
- Artifacts: `.agents/artifacts/task_2026_09_23_knowledge_base_ingest/`
- Outcome: `1_spec.md` + `adr/0001-compiled-root-knowledge-layer.md` written; `check-adr` passes;
  artifacts index row added (7 tasks). Not yet committed (spec awaiting approval).

## v0.4.0-rc.0 — 2026-09-23
- Scope: Ship the Karpathy-style root knowledge base from the approved plan
  (`.agents/artifacts/task_2026_09_23_knowledge_base_ingest/2_plan.md`). New `core/knowledge-template/`
  (index/log/overview/schema + sources/concepts/modules/decision-records/verified-facts), new
  `core/skills/knowledge-base/SKILL.md`, new `core/scripts/scaffold-knowledge.sh` + `kb-ingest.sh`
  (task-end incremental ingest, WRITE default, `--dry-run`/`--kb`, research-only no-op), new
  `task-state.sh check-kb` gate wired into `memory-gate.sh`. Adapter `-build` stubs gain byte-identical
  step 5; skill rows added to `core/install-manifest.txt` + `claude-code`/`codex` manifests +
  `opencode.jsonc` instructions. `install-harness.sh` step 4c seeds the KB; `audit-install.sh` Check 5c;
  `harness-update` step 9.5 remediation; root-AGENTS.md KB section (lifecycle 9, checklist, Reference
  Map, context bullet). Docs/version: `0.3.0-rc.1` → `0.4.0-rc.0`, CHANGELOG + prompt
  `changelogs/version-0.4.0-rc.0.md`, README/INSTALL/PORTABILITY mentions.
- Artifacts: `.agents/artifacts/task_2026_09_23_knowledge_base_ingest/`
- Outcome: verified via `bash -n` on 6 scripts, fresh scratch installs (thin `/tmp` consumer; audit
  clean), simulated task end (positive / negative / research-only) exercising kb-ingest +
  check-kb + memory-gate, module+ADR+verify ingest paths, and byte-identical stub deltas. Fixed two
  writer/reader parity bugs found during verify (catalog rows must emit the literal page paths the
  gate greps for). `3_memory.md` + `4_verify.md` written; committed in a single commit.

## v0.4.0-rc.1 — 2026-09-24
- Scope: Ship a shared "simple English" writing standard for all generated content and developer
  messages (issue #1). New `core/governance/rules/simple-english.md` (simple English itself, bad vs
  good examples: spec, developer message, memory line, commit message) + one standard reference line
  in all 11 content-writing skills (`../../governance/rules/simple-english.md`, resolves in both the
  source tree and an installed bundle) + `core/root-AGENTS.md` Critical Gotcha 6 + Reference Map row
  + explicit manifest row. Version → `0.4.0-rc.1` (user-confirmed) with `changelogs/version-0.4.0-rc.1.md`
  (root-AGENTS.md change per Gotcha 3). CHANGELOG + docs version mentions updated.
- Artifacts: `.agents/artifacts/task_2026_09_24_simple_english/`
- Outcome: verified via grep (11 skill references), relative-path resolution from every skill,
  fresh scratch install (`/tmp/harness-rc1-<suffix>-consumer`) + `audit-install.sh --against <repo>`
  clean, rule file present under the installed bundle, `task-state.sh check-plan` + `check-chain` +
  `check-adr` pass, artifacts index (8 tasks) + session-log + todo current. `3_memory.md` +
  `4_verify.md` written; committed in a single commit.

## v0.4.0-rc.2 — 2026-09-25
- Scope: Issue #4 — bring back a per-adapter harness update command, with the README's update prompt embedded in the harness instead of pasted by hand. New `core/prompts/harness-update.md` holds the prompt (moved out of `README.md` unchanged, still versionless, still one copy in the repo) and three thin command files apply it and then defer to `core/skills/harness-update/SKILL.md`: `.claude/commands/monorepo-harness-update.md`, `.opencode/commands/monorepo-harness-update.md`, `.agents/skills/monorepo-harness-update/SKILL.md` (codex). Flat name on all three; the pre-rc.4 namespaced `/monorepo-harness:update` is not resurrected. Manifest: one `copy` row per adapter + an explicit `core` row for the prompt. Docs: `PORTABILITY.md` (3 places), `README.md` (bullet, Scenario 5, update section, adapter table), `INSTALL.md` §7, and all six adapter README/INSTALL files. `harness-update/SKILL.md` intro no longer claims the entry point is gone. Version → `0.4.0-rc.2` (user-confirmed) + `CHANGELOG.md` section + `changelogs/version-0.4.0-rc.2.md` (no-op: nothing to run, no manual follow-up).
- Artifacts:   `.agents/artifacts/task_2026_09_25_update_command_prompt/`
- Outcome: verified on a scratch consumer (all three adapters installed twice each — second run `0 file(s) written/updated`) — `audit-install.sh --against <repo>` exit 0; deleting a command file makes the audit exit 1 naming `entrypoint missing (claude-code|opencode): …monorepo-harness-update.md`, and `install-adapter.sh <agent> --refresh` restores it (config rows still skipped). `harness-update.sh current` → `0.4.0-rc.2`. Three command bodies byte-identical (sha1 `0b179bf73055`); installed copies `diff` clean against sources. Prompt text appears in exactly one file repo-wide; zero hits for the old "no adapter command" / "Update from the repo" claims outside CHANGELOG history. `3_memory.md` + `4_verify.md` written; artifacts index (9 tasks) + todo updated; committed as `b678d81` on branch `4-embed-update-prompt-in-harness-update-command` (the repo gitignores `/.agents/`, so the artifacts stay local working state and the implementation is a single commit).

## v0.4.0-rc.3 — 2026-09-25
- Scope: Issue #5 — close the loop after intent approval. New `/monorepo-harness-intent-dispatch`
  ships on all three adapters: it verifies the approval, confirms the workspace scope, splits the
  intent into 3-5 phases, records the developer's sign-off, then writes one task directory **and** one
  tracker issue per phase — and stops (implementation stays in `/monorepo-harness-build`). Logic goes
  into the existing `core/skills/intent-workflow/SKILL.md` as a third phase, Execute, rather than a new
  core skill, so opencode needs no new `instructions` line (a `merge` row is never re-applied on
  upgrade). New `core/scripts/tracker-issue.sh` is platform-dispatched with GitHub Issues (`gh`) as
  the only implemented platform; the resolved tracker is cached in each phase plan's frontmatter, so
  no config file is installed and no `.gitignore` work is needed. `core/governance/intents/AGENTS.md`
  gains an optional `pr:` frontmatter field for the approved-commit push. Adapters: three thin entry
  points + a claude-code `tracker` subagent (codex has no subagent primitive → inline fallback).
  Manifests: one `copy` per adapter + one `copy` for the subagent; `core/install-manifest.txt`
  unchanged. Version → `0.4.0-rc.3` (user-confirmed) + `CHANGELOG.md` section +
  `changelogs/version-0.4.0-rc.3.md`.
- Artifacts: `.agents/artifacts/task_2026_09_25_intent_execute_command/`
- Outcome: `1_spec.md` + `2_plan.md` + `adr/0001-per_phase_task_dirs_stop_before_build.md` +
  `adr/0002-tracker_in_plan_frontmatter.md` written; `task-state.sh check-adr` passes (2/2); artifacts
  index row added (10 tasks). Implemented and verified: `bash -n` clean; script doctest covers
  dry-run, both tracker-resolution branches, five guard failures, and the `gh`-absent fail-open
  (exit 3 with paste-ready text, nothing claimed); a pending fixture intent is refused by
  `check-intent-approved` and passes once approved. Scratch consumer: all three adapters installed
  twice (second run `0 file(s) written/updated`), `audit-install.sh --against <repo>` exit 0; deleting
  the claude-code subagent + entry point yields 2 named gaps and exit 1, and `--refresh` restores
  them. All seven shipped files `diff` clean against their installed copies; `harness-update.sh
  current` → `0.4.0-rc.3`; opencode needed no `opencode.jsonc` entry. Also condensed `INSTALL.md`
  from 121 to 99 lines — it was already over the mandatory 100-line install-guide cap before this task
  — and fixed its "only three things" list that had four entries. Live `gh issue create` not executed
  (no authenticated `gh`); recorded in `4_verify.md` as the one uncovered line. Post-review pass
  fixed two defects the first pass shipped: the opencode command dispatched a `tracker` subagent
  opencode does not have, and the claude-code command showed a bare `bash` block under a "with the
  `tracker` subagent" sentence — both contradicting `PORTABILITY.md:106-107`, and both invisible to
  the byte-parity check, because three files agreeing on the same mistake is still a mistake. Also
  corrected the upgrade note claiming `intent-workflow` "was already listed" in `opencode.jsonc`.
  Re-verified on the scratch consumer through the real update order (`install-harness.sh --sync-only
  --from <repo>` → `install-adapter.sh <agent> --refresh` → audit): 2 files refreshed, audit clean
  exit 0, second run 0 files. Learned here: `install-adapter.sh:45` reads the bundle's `adapters/`
  snapshot, not the repo, so re-running it after editing adapter sources is a silent no-op — only the
  audit's "entrypoint stale" check catches that. `3_memory.md` + `4_verify.md` written and updated;
  artifacts index (10 tasks) + todo updated; implementation committed. PR review then renamed the command to `/monorepo-harness-intent-dispatch` (staying in the unreleased rc.3): the command never implements anything and every document carrying the old name needed an "it stops there" caveat to stay honest. 45 occurrences / 16 tracked files plus 3 `git mv` renames (the entry-point file paths carry the name), 3 manifest rows, the skill's third phase title and the capability label. Task slug left alone per artifacts governance, rename recorded as a `## Revisions` entry in `2_plan.md`. Re-verified through the real update order: all three installed copies diff clean, audit exit 0, second refresh 0 files, entry-point parity and all gates still pass. Found while verifying: `install-adapter.sh` only adds, so the consumer kept three live old-name commands while the audit reported clean — it has no notion of an unexpected file. Harmless for an unpublished rc, a real gap for any rename in a released version; logged as follow-up.


## v0.4.0-rc.4 — 2026-09-28
- Scope: Fix issue #9 — intent dispatch infers the tracker from the *consumer's* git config, confirms
  it with the developer, caches it in `<repo-root>/.agents/tracker.md`, and refuses the harness repo as
  an issue target. `core/scripts/tracker-issue.sh` gains a read-only `--infer` plus a harness-repo
  guard; `core/skills/intent-workflow/SKILL.md` Dispatch step 6 becomes the confirmation contract;
  the `tracker` subagent and all three dispatch entry points carry the same rules. New ADR 0001
  supersedes the 2026-09-25 task's ADR 0002 (the plan frontmatter is now a per-phase audit record,
  not the cache). No manifest row and no `changelogs/` prompt: nothing new is installed.
- Artifacts: `.agents/artifacts/task_2026_09_28_tracker_infer_confirm_cache/`
- Outcome: `1_spec.md` + `2_plan.md` + `adr/0001-tracker_is_a_confirmed_project_level_cache.md`
  written (the new ADR carries `supersedes:` at the 09-25 task's ADR 0002, which got a
  superseded-by pointer in place); `task-state.sh check-adr` passes on both specs. Implemented:
  `tracker-issue.sh` gained a read-only `--infer` (consumer `origin` host → platform, cache wins,
  always exit 0, unknown for a self-hosted or no remote), a `<repo-root>/.agents/tracker.md`
  project-level cache, a harness-repo refusal on every path including `--dry-run`, and a three-tier
  platform table (`github` creates; `jira`/`linear` → exit 3 with paste-ready text + handoff hint;
  anything else → exit 1 telling the caller to ask the developer). Resolution is now `--tracker` →
  cache → plan frontmatter. Skill step 6 is the four-step confirmation contract, the `tracker`
  subagent and all three dispatch entry points carry the same rules, and PORTABILITY/README/INSTALL +
  3 × adapter README state the flow. Verified: `bash -n` clean; the guard run **in this repo** (whose
  origin is the harness upstream) refuses on `--dry-run` and `--create` and in all four URL spellings
  while `atayahmet/monorepo-agents-harness-fork` and other repos pass; the same script in a real
  installed consumer refuses the harness repo and allows the consumer's own repo, which is the case
  that would have broken a naive bundle-origin lookup. 4 defects found and fixed while testing: a
  bash-4-only `${var,,}` (macOS ships 3.2, and `bash -n` does not catch it), a `remote_host` regex
  that returned the first path segment as the host for scp-style remotes (so `bitbucket.org` inferred
  as `unknown`), a `.git`/case mismatch in the guard, and a Jira project key being reused as a GitHub
  repository when `--tracker` overrode the cached platform. Scratch consumer: all three adapters
  installed twice (second run 0 files), `audit-install.sh` exit 0, and the change also survives the
  real update path (`--sync-only` → audit clean) with no manifest row. Docs: `INSTALL.md` held at 99
  lines under the 100-line cap; `adapters/*/INSTALL.md` needed no edit after all (they name the
  skill + script, both unchanged) — deviation from the plan's step 5, noted in `4_verify.md`.
  `CHANGELOG.md`: cut `## [0.4.0-rc.4]`, which necessarily carried the knowledge-base feature that
  was still sitting in `[Unreleased]` with no VERSION bump of its own — flagged, not silent. No
  `changelogs/version-0.4.0-rc.4.md` prompt: nothing new is installed and no manual follow-up is
  needed. Live `gh issue create` still not executed (only the failure path of a non-existent repo);
  recorded in `4_verify.md` as the one uncovered line. `3_memory.md` + `4_verify.md` written; index
  (11 tasks) + todo updated; implementation committed.
## v0.4.0-rc.5 — 2026-09-28
- Scope: Fix what the first real dispatch run on `0.4.0-rc.4` actually wrote. It created
  `0_intent.md`, `1_spec.md` and `2_plan.md` per phase plus an `index.md` row, because skill step 7
  said so *and* ADR 0001 (2026-09-25) mandated one task directory per phase. ADR 0001 was reversed,
  phase scope moved into the issue body, and the hand-off moved to `/monorepo-harness-spec
  <intent.md>`. The approval gate also started reading the intent's PR before the local file, and
  `tracker-issue.sh --plan` became optional.
- Artifacts: `.agents/artifacts/task_2026_09_28_dispatch_issues_only/`
- Outcome: developer's report from the first `0.4.0-rc.4` run — dispatch created intent, spec and
  plan files. Two independent causes, not one: the skill's step 7 said "write the artifacts and open
  the issue", **and** the 2026-09-25 ADR 0001 mandated one task directory per phase. Fixing only the
  prose would have left a documented decision demanding the files. ADR 0001
  (`0001-dispatch_creates_issues_not_plan_artifacts.md`) reverses that premise, the old ADR carries a
  superseded pointer, and `check-adr` passes on both specs. Decision: a task is the tracker issue;
  dispatch writes exactly two files — the existing intent's `status:`/`## Review`, and rc.4's tracker
  cache. Phase scope moved into the issue body. Nothing was orphaned: `0_intent.md`'s only legitimate
  writer was always `write-intent-ref.sh` via `/monorepo-harness-spec`, and the chain now starts there
  instead of at `/monorepo-harness-build <2_plan.md>`. The approval gate reads the intent's **PR**
  first (`task-state.sh check-intent-approved --pr <ref>`) and the file second, so an intent approved
  on GitHub is no longer refused while its local file still says `pending`; the reviewer and date come
  from the review. A gate defect surfaced while testing: filtering on state only inside `gh`'s jq
  expression meant a `CHANGES_REQUESTED` review passed as an approval (scenario 6) — the script now
  verifies the state itself and falls through to the file on anything unrecognised. `--plan` became
  optional in `tracker-issue.sh` rather than removed. The `tracker` subagent was the most dangerous
  leftover: it read a `2_plan.md` that no longer exists and passed `--plan`. Verified: 17 approval
  scenarios (the real `gh` query, parsing and error path against this repo's own PR #10; the APPROVED
  row with a stub, since GitHub forbids approving your own PR — stated as a limit in `4_verify.md`),
  `--plan`-less dry run, scratch consumer where the two file-touching steps leave `find apps -type f`
  and `git status` byte-identical, an `rg` sweep that caught "the task directories still stand" in
  README/PORTABILITY/3 adapter READMEs, three adapters installed twice (0 files) + `audit-install.sh`
  clean, `--sync-only` + audit clean with no manifest row, entry-point parity, both install guides
  under 100 lines, `git diff --check`. `INSTALL.md` hit 101 on the first pass and was reflowed. Cut
  `0.4.0-rc.4` → **`0.4.0-rc.5`** (version chosen by the developer, not by me) with
  `changelogs/version-0.4.0-rc.5.md`, since rc.4 consumers who already ran dispatch need told to keep
  those task directories. `3_memory.md` + `4_verify.md` written, index + todo updated.

## v0.4.0-rc.6 — 2026-09-28
- Scope: two new consent questions in `/monorepo-harness-intent-dispatch` — check the project's own
  tracker for already-open work before filing anything, then ask whether to merge the intent's PR
  once every issue exists. `tracker-issue.sh --list-open` (read-only, repeatable `--search`, union
  deduped by issue number) and `task-state.sh merge-intent-pr [--pr] [--yes]` (re-checks the
  approval itself, `gh pr merge --merge` only) are both new script surfaces; the shared skill went
  8 → 10 steps and all three adapter entry points followed.
- Artifacts: `monorepo-agents-harness/.agents/artifacts/task_2026_09_28_dispatch_dedup_and_pr_merge/`
  (`1_spec.md`, `2_plan.md`, `3_memory.md`, `4_verify.md`, `adr/0002-dispatch_gates_open_work_and_consents_pr_merge.md`)
- Outcome: **96/96** stub checks pass. Scratch consumer `/tmp/ti/c3` installed all three adapters
  twice (second round 0 changes), `--sync-only` + `audit-install.sh` clean, and both new steps left
  the workspace byte-identical (shasum `7eafee95d2f4d0e7` before and after) — the two new steps
  write nothing, which is the rc.5 contract preserved. Review semantics were tightened to
  latest-per-reviewer, so an `APPROVED` later retracted no longer passes the gate. Four bugs found
  on the way: a quoted `pr:` (`pr: "42"`) was refused, an unexpanded `{{PR_URL}}` read as a broken ref
  instead of "no PR", approval was read before the PR's state so a merged PR was refused instead of
  being a no-op, and `--list-open` without `--search` exited 1 (read as "stop") rather than 2
  (usage). The 15 pre-existing `check-kb`/ADR failures in this repo are unchanged: identical
  60/15 on pristine `0.4.0-rc.5`. `INSTALL.md` hit 103 and was reflowed back to the 100-line cap.
  Cut `0.4.0-rc.5` → **`0.4.0-rc.6`** (version chosen by the developer, not by me) with
  `changelogs/version-0.4.0-rc.6.md`; no manifest row is owed because no new file reaches a consumer.

## v0.4.0-rc.7 — 2026-09-28
- Scope: the intent's pull request no longer has to be on GitHub. New `core/scripts/forge.sh` owns
  every read of a PR and the merge itself — `resolve` / `probe` / `state` / `reviews` / `issues` /
  `merge` / `paste` — across GitHub, GitLab (nested groups included), Bitbucket, Gitea and
  self-hosted hosts. Forge precedence is the ref's own host, then `forge:` in `.agents/tracker.md`,
  then `origin`; a bare `#42` with no `origin` is refused rather than assumed GitHub. The mechanism
  ladder is platform CLI → REST with a token the project already exports → project MCP server or
  project skill, each rung probe-verified with a real read; the last rung is an agent handoff,
  because a shell script cannot call an MCP tool, and a project skill outranks a generic command.
  `task-state.sh` and `tracker-issue.sh --list-open` now delegate their reads to it. Issue **creation**
  stays GitHub-only (ADR `0003`).
- Artifacts: `monorepo-agents-harness/.agents/artifacts/task_2026_09_28_platform_dispatched_pr_merge/`
  (`1_spec.md`, `2_plan.md`, `3_memory.md`, `4_verify.md`, `adr/0003-forge_axis_is_separate_from_the_tracker_axis.md`)
- Outcome: **134/134** forge checks and **100/100** regression checks pass. The rc.6 suite was
  updated for five intentional policy changes rather than left green by accident. Everything was
  then re-driven through a **scratch consumer's installed bundle** (`/tmp/hv-rc7/scratch2`), not the
  source tree: the four platforms resolve from their own URLs, a bare ref with no `origin` is
  refused, `origin=acme/web` is used instead of the harness repo, the skill and MCP rungs each report
  `agent-only` with the config path, and cross-repo `otherorg/otherrepo#5` keeps its own project
  (`gh pr merge otherorg/otherrepo#5 --merge`, never a bare `5`). The approved path logged exactly
  `gh pr merge 10 --merge`.
- **The one deliberate reversal, and why.** rc.6 fell back to the intent file's own
  `status: approved` when the PR could not be read. On every project whose PR the harness cannot
  reach — exactly the MCP-only and self-hosted setup this release exists to support — that fallback
  is the *normal* path, so an agent-written field was standing in for a human decision on every
  dispatch, with a success message attached. rc.7 removes it: an unreadable approval is UNKNOWN,
  exit 1 for the check and exit 3 for the merge, and the file stays authoritative only when there is
  no `pr:` field at all. Confirmed from the installed bundle with a file that says `approved`: exit 1
  and no `source: file`. Exit 1 (read it, refused) and exit 3 (could not read it) are now documented
  as different answers everywhere — skill, three entry points, tracker subagent, intents governance
  doc, PORTABILITY, README, INSTALL, three adapter READMEs.
- Bugs fixed on the way: REST merges were malformed before reaching the endpoint (JSON appended to
  the URL, which the CLI path masked) and Gitea needed `{"Do":"merge"}`; `forge.sh` was created
  **non-executable**, so a direct run failed with exit 126 while `bash forge.sh` worked; GitLab
  nested groups and a `/files` URL suffix mis-parsed; review casing differed per platform
  (`REQUEST_CHANGES`, lowercase `open`) so one uppercase vocabulary was needed.
- **A gap found while verifying, deliberately not fixed here.** `memory-gate.sh` falls back to
  `$ROOT/apps` and `$ROOT/packages`, which do not exist in this template repo, so it scans nothing
  and exits 0 — it cannot see this task's own `3_memory.md`/`4_verify.md`, which were verified by
  hand instead. The gate and the harness's own Workspace Routing disagree about the repo root being
  a valid workspace. Patching a hard gate for every consumer inside a forge release was the wrong
  trade; it is recorded in `3_memory.md` for its own task.
- Cut `0.4.0-rc.6` → **`0.4.0-rc.7`** (version chosen by the developer, not by me) with
  `changelogs/version-0.4.0-rc.7.md`. No manifest row is owed: `core` is a directory row, so the new
  `core/scripts/forge.sh` ships with the normal sync. `INSTALL.md` hit 103 and then 101 lines while
  documenting the ladder and was reflowed back to the 100-line cap. Test suites deliberately left in
  `/tmp/ti/` — `core/` is copied whole into every consumer bundle, so a test tree under it would ship
  to users (confirmed with the developer).

## v0.4.0-rc.9 — 2026-09-29
- Scope: Issue #17 — the memory-gate enforced `3_memory.md` / `4_verify.md` on **every** task dir
  created that day, so a legitimate spec-only or plan-only turn (both of which stop at a stage
  boundary by design) was blocked, and on claude-code the `Stop` hook block could repeat because it
  only ever saw "this task is missing its artifacts". The gate now enforces only on a task that
  reached the **build** stage, and never blocks the same stop twice.
- Artifacts: `.agents/artifacts/task_2026_09_29_memory_gate_stage_scope/`
- Outcome: Implemented and committed. The marker is a write-once `build_started` field in
  `2_plan.md` frontmatter — no new file, no index row, nothing to migrate — written by the new
  `task-state.sh mark-build <2_plan.md>` and read by the new `task-state.sh stage <task_dir>`
  (`none|spec|plan|build`), which is the single stage reader shared by the gate, the hook and the
  docs; the marker wins over file presence, so a build whose spec was later deleted is still a build.
  `memory-gate.sh` now scans every task dir of the day and keeps the build-stage ones newest-first
  (the old `ls -t | head -1` let a fresh spec mask an in-flight build), scopes **both** `--json` and
  the default mode, honours `stop_hook_active` (true → silent; absent/false/malformed → still
  enforce), and falls back to the old newest-dir behaviour when the stage reader is missing rather
  than passing everything.
- **Design correction made after the plan was approved:** plan-mode exit cannot write the marker —
  `ExitPlanMode` / `update_plan` fire *before* `2_plan.md` exists. Arming moved to a file-write hook,
  `core/scripts/hook-arm-build.sh`, which watches the first write **outside** `.agents/` and delegates
  to `mark-build`; it always exits 0. Wired as `PreToolUse[Write|Edit|MultiEdit|NotebookEdit]` for
  claude-code. **Codex keeps the prose path** — no file-write hook matcher there could be verified, so
  its `update_plan` reminder names `mark-build` instead. Capability is identical on all three
  adapters; only the trigger differs, and `PORTABILITY.md` says so in the matrix and the semantic list.
- New: `core/scripts/hook-arm-build.sh` and `tests/memory-gate.test.sh` (**40 cases, all passing**,
  each on a throwaway installed-layout git fixture). The test file is deliberately repo-local and
  **not** in `core/install-manifest.txt`, because `core/` is copied whole into every consumer bundle.
- Bugs the tests caught that manual checking had missed: a `jq` that is present but broken made
  `--json` mode exit **127** (a hook error, not a block) — now fails open; and the first two fixture
  versions passed/failed for reasons unrelated to the code because the bundle was not at
  `.agents/monorepo-agents-harness/`, so the gate silently took its fallback path. A real
  `install-harness.sh` + `install-adapter.sh claude-code` into `/tmp/harness-consumer` with
  `audit-install.sh` clean twice also **falsified a claim I had just written** into `INSTALL.md` §5:
  at build stage the knowledge-base coverage check still applies, so the guide can no longer promise
  exit 0 after memory + verify alone. Reworded to stop at the artifacts it can prove.
- Release `0.4.0-rc.8` → **`0.4.0-rc.9`** (version chosen by the developer) with
  `changelogs/version-0.4.0-rc.9.md`. No manifest row is owed (no new file reached a consumer). Both
  adapter settings files are `merge` rows and both gained content, so the prompt carries the one
  manual step: accept the `.harness-proposed` `PreToolUse` hook (claude-code) and the reworded
  `update_plan` reminder (codex). `core/root-AGENTS.md` gotcha 5 changed, as required for any
  installable-template edit. `INSTALL.md` hit 102 and 103 lines and was rewrapped back to the
  100-line cap. `check-kb` cannot be satisfied in this repo (no `knowledge/` layer — same as every
  prior release task); the gate itself exits 0 here because there is no `apps/`/`packages/` workspace.

## v0.4.0-rc.8 — 2026-09-29
- Scope: Issues #7 and #8 shipped as **one atomic release** — a multi-phase intent can get one parent
  **epic** issue (`tracker-issue.sh --parent` → `gh issue create --parent`), asked for at `N >= 2`
  inside the existing step 5 sign-off table with `no epic` as a first-class answer, and dispatch
  appends an append-only `## Dispatch` block to the intent recording the epic and every phase key the
  creates actually returned. Single-phase dispatch is untouched.
- Artifacts: `.agents/artifacts/task_2026_09_29_dispatch_epic_and_task_keys/`
- Outcome: Implemented and committed. `tracker-issue.sh` gained `--parent`, a `gh issue create --help`
  capability preflight (absent flag → paste-ready + exit 3, the same floor as "`gh` not found") and a
  `tracker-issue: created number=<n>` line printed **before** the URL, which stays last so the existing
  "the last stdout line is the URL" contract in installed `tracker` subagents keeps working. The
  `## Dispatch` block is a section of the existing intent file, so **the two-file write count is
  unchanged**. "Created but unlinked" was **deleted from the design**: GitHub's `parent_issue_id` is
  atomic, so a refused link is an ordinary exit-1 create failure recorded as `no issue yet (<reason>)`.
  Verified 63 new stub checks, 100 + 134 regression checks unchanged, byte-identical workspace across
  every read and dry-run path, exact `gh` argv asserted for both the epic (no `--parent`, no preflight)
  and a child (`--parent 412`), and the capability confirmed present in a scratch consumer's
  **installed** bundle and all four agent surfaces. `audit-install.sh` clean, exit 0. `INSTALL.md` hit
  103 and then 102 lines and was rewrapped programmatically back to the 100-line cap. No manifest row
  is owed (no new file reached a consumer). ADR files were renamed to the kebab-case the
  `adr-workflow` skill requires, and every reference corrected. The one failing `check-adr` in the
  repo (`task_2026_09_25_update_command_prompt`) fails identically on stashed `HEAD` — pre-existing,
  not from this change.

## v0.4.0-rc.12 — 2026-10-07
- Scope: Issue #22 — make a repo-root `.agents/artifacts/task_*` dir a first-class candidate for
  `memory-gate.sh` and `hook-arm-build.sh`, with the tests the issue's acceptance asks for.
- Artifacts: `.agents/artifacts/task_2026_10_07_repo_root_task_scan/`
- Outcome: Implemented and committed in `ed6fada` (`closes #22`). The scan-set half had already
  landed in `c211a9a`, so the task was 12 new cases in `tests/memory-gate.test.sh` — gate enforces a
  repo-root build (default + `--json`) in a fixture with `apps/` and in a `root-only` fixture with
  neither, hook arms it, artifact writes and workspace plans stay untouched — plus the defect those
  cases exposed: the hook resolved a written path only through an existing `dirname`, so a
  brand-new file in a brand-new directory could not be placed when its spelling differed from git's
  physical root (doubled `TMPDIR` slash, symlinked checkout) and the plan never armed. It now walks
  to the deepest existing directory, `pwd -P`s that and re-appends the tail. Verified 59/59 (was 47)
  + 37/37, `bash -n`, `git diff --check`, and three fault injections — scan lines out → 5 failures,
  hook root line out → 3, placement walk out → 2, each restored to green. `VERSION` → `0.4.0-rc.12`
  (version chosen by the developer) with `CHANGELOG.md` + `changelogs/version-0.4.0-rc.12.md`; no
  manifest row owed (`tests/` ships nowhere, `core/` ships whole). The gate now reports this
  repository's own task dir — the gap `lessons.md` recorded on 2026-09-28 is closed: it exited 1
  naming the missing `3_memory.md`, then `4_verify.md`, and exits 0 now that both exist.

## v0.4.0-rc.13 — 2026-10-07
- Scope: Issue #25 — ranked search over `knowledge/`: a SQLite FTS5 index behind
  `core/scripts/kb-index.sh` (`rebuild` / `query` / `links`), a gitignored derived cache wired into
  install + audit, `/monorepo-harness-kb-index` on all three adapters, query/lint workflows in the
  knowledge-base skill and schema, docs, and a repo-local test suite.
- Artifacts: `.agents/artifacts/task_2026_10_07_kb_fts5_index/`
- Outcome: Implemented and committed in `9f3f063` (`closes #25`) on `feat/kb-index-fts5`. Decisions
  the developer answered up front: lazy rebuild (query/lints self-heal staleness, `kb-ingest.sh`
  untouched), `knowledge/` only for v1 (schema columns reserved for phase 2), the ignore lines merged
  into the consumer root `.gitignore` by `install-harness.sh` and checked by `audit-install.sh`
  Check 5c, and the new command on all three adapters (3 command files, 3 `copy` rows, Hard Rule 7).
  The script builds a temp SQL file and a temp database and renames the latter over
  `knowledge/.index.sqlite`, derives `kind`/`workspace`/`task_slug`/`date` from the page shapes,
  orders hits by `bm25()` ascending with `snippet()` highlights, and exits 1 with exactly one
  warning (grep fallback) when `sqlite3` or FTS5 is absent. `tests/kb-index.test.sh` — 38 cases —
  earned its keep twice: the first draft's kill test left an in-flight `sqlite3` child alive and
  passed with `mv` removed, so it now kills the process tree and drives the publish window with an
  `mv` shim; fault injections: no self-heal → 2 failures, no temp+rename → 4 failures, both restored
  to 38/38. Verified 38/38 + 59/59 + 37/37, `bash -n`, `git diff --check`, `INSTALL.md` exactly at
  its 100-line cap (adapter INSTALLs 79/84/85), and an installed-consumer fixture (fresh `git init`,
  harness + all three adapters) where `audit-install.sh` is clean, a second install does not grow
  `.gitignore`, and both negative controls (script removed, ignore line removed) fail it by name.
  `VERSION` → `0.4.0-rc.13` (developer's answer) with CHANGELOG Added + Upgrade Notes, plus
  `changelogs/version-0.4.0-rc.13.md` (developer asked for the upgrade prompt: no hand-run command —
  the manifest-driven update covers it — so it carries the `.gitignore` check, the "no indexing step"
  note and the `sqlite3`/FTS5 ranking note).
  Note for later: `.agents/artifacts/index.md` is missing rows for two pre-2026-09-03 task dirs
  (`task_2026_09_02_self_improvement_workflow`, `task_2026_09_03_fix_intent_ref_copy`) — untouched,
  unrelated to #25.

## v0.4.0-rc.14 — 2026-10-11
- Scope: Issue #30 — point the root KB-first rule at the ranked index. `core/root-AGENTS.md`'s Before
  You Start checklist item and Agent Lifecycle 9 now run
  `bash .agents/monorepo-agents-harness/core/scripts/kb-index.sh query "<keywords>"` (BM25-ranked,
  grep fallback without `sqlite3`/FTS5) and read the top pages, keeping `knowledge/index.md` as the
  catalog browse path. `core/skills/knowledge-base/SKILL.md`'s `description` gained "at the start of
  a spec or a plan (query prior art first)" so the skill loads when the rule is due.
- Artifacts: `.agents/artifacts/task_2026_10_11_kb_query_first/`
- Outcome: Implemented and committed in `7329194` (`closes #30`) on `fix/kb-query-first-root-agents`.
  Text-only change: no script, manifest, or adapter touched. `VERSION` → `0.4.0-rc.14` (developer's
  answer) with `CHANGELOG.md` Changed + Upgrade Notes, plus `changelogs/version-0.4.0-rc.14.md` (the
  developer asked for the prompt even though no command is owed — the root `AGENTS.md` merge is
  automatic and consent-gated, so the prompt carries no hand-run step). Verified:
  `grep -c 'kb-index.sh query' core/root-AGENTS.md` = 2, the skill `description` names it and the new
  trigger, `git diff --check` clean, suites 38/59/37 green, and a scratch-consumer fixture whose
  installed `AGENTS.md` carries both new lines with placeholders resolved and whose `audit-install.sh`
  is clean. No repo-local test added: the natural home for a checklist drift guard is #29.

## v0.4.0-rc.15 — 2026-10-11
- Scope: Issue #27 — the spec stage now reaches the knowledge base.
  `core/skills/agent-workflow/SKILL.md` Phase 1 runs four checks: (1) query the repo-root knowledge
  base first (`kb-index.sh query`, BM25-ranked, grep fallback) and read the top pages; (2) grep the
  task indexes for what the KB does not cover, with the new-workspace fallback (grep every workspace
  index), the cross-cutting sibling-index grep, and the no-`apps/`/`packages/` repo-root index case.
  `templates/2_plan.md`'s `## Related prior work` now asks for a `[[page]]` (`knowledge/…`) line then
  a task-dir line, and keeps `- none found`. Synced `core/governance/artifacts/AGENTS.md` search-rule
  6 and `README.md`.
- Artifacts: `.agents/artifacts/task_2026_10_11_spec_kb_prior_art/`
- Outcome: Implemented and committed in `8979e54` (`closes #27`) on `docs/spec-stage-kb-first`.
  Text-only release `0.4.0-rc.15` (developer's answer): no script, manifest, adapter, or gate change,
  and no changelog prompt (nothing to run). Verified: Phase 1 check 1 names `kb-index.sh query` before
  the index grep, the plan template asks for a `knowledge/` citation, the governance rule and README
  name the query, `git diff --check` clean, suites 38/59/37 green, and a scratch-consumer fixture whose
  installed SKILL/template carry the new text with `audit-install.sh` clean. `memory-gate.sh` exits 0 by
  omission here (it scans `apps/*`/`packages/*`, absent in this repo) — noted in `4_verify.md`; the
  gate is not evidence about this task.

## v0.4.0-rc.16 — 2026-10-11
- Scope: Issue #28 — the `-spec` and `-plan` stubs now name the knowledge-base query. Each of the six
  adapter stubs got a step **before** writing its artifact: `-spec` runs
  `kb-index.sh query "<1–3 keywords>"`, reads the top hits, and keeps them for the plan; `-plan` runs
  the same query (or reuses the hits) and cites the `knowledge/…` pages under `## Related prior work`.
  Both point at `core/skills/agent-workflow/SKILL.md` Phase 1 check 1 (added in v0.4.0-rc.15, #27).
  Synced `PORTABILITY.md` (Knowledge-base row + semantic-difference note) and the `INSTALL.md` §6 KB
  bullet so neither claims the KB is build-only.
- Artifacts: `.agents/artifacts/task_2026_10_11_stage_stub_kb_query/`
- Outcome: Implemented and committed in `5b86993` (`closes #28`) on `docs/stage-stub-kb-query`.
  Instruction-only release `0.4.0-rc.16`: no script, manifest, adapter row, hook, or gate change, and
  no changelog prompt. Verified: all six stubs name `kb-index.sh query` before the write step,
  PORTABILITY/INSTALL name the read path, `INSTALL.md` stays at the ≤100-line cap, `git diff --check`
  clean, suites 38/59/37 green, and a scratch-consumer fixture that installed the bundle + all three
  adapters with the new step in each installed stub and `audit-install.sh` clean. `memory-gate.sh`
  exits 0 by omission here (it scans `apps/*`/`packages/*`, absent in this repo) — noted in
  `4_verify.md`; the gate is not evidence about this task.

## v0.4.0-rc.17 — 2026-10-11
- Scope: Issue #29 — the "Before You Start" checklist reminder is now read live from the root
  `AGENTS.md` instead of being hand-copied. New agent-neutral `core/scripts/checklist-reminder.sh`
  extracts the `## Before You Start — Mandatory Checklist` section at run time and emits it (Claude
  hook JSON by default, plain markdown with `--text`; fail-open). The claude-code
  `PostToolUse[ExitPlanMode]` reminder hook calls it (replacing the drifted 7-item inline list), and
  all three `-spec` stubs (claude-code, opencode, codex) run it before writing `1_spec.md`, so the
  checklist is seen on both the plan-mode and command-driven paths. Repo-local
  `tests/checklist-reminder.test.sh` locks the emitted items to `core/root-AGENTS.md` and fails on a
  reintroduced hand-copied list. Docs synced (claude INSTALL/README, adapters/AGENTS.md, PORTABILITY,
  README).
- Artifacts: `.agents/artifacts/task_2026_10_11_checklist_reminder_single_source/`
- Outcome: Implemented and committed in `65054e0` (`closes #29`). Release `0.4.0-rc.17` ships a
  `changelogs/version-0.4.0-rc.17.md` prompt because `.claude/settings.json` is a `merge` row (existing
  installs merge the proposed hook command); the `-spec` stubs are `copy` rows and sync automatically.
  Verified: `bash -n` clean, both JSON configs valid, all four test files green (24/38/59/37),
  scratch fixture installed the bundle + all three adapters with the script reachable from the installed
  hook and each `-spec` stub and `audit-install.sh` clean, `git diff --check` clean.
- Caveat: the memory-gate's green here is partial — `.agents/monorepo-agents-harness/` is not installed
  in this template repo, so the gate has no `TASK_STATE`, skips `check-kb`, and falls back to enforcing
  the newest task dir. `check-kb` exits 1 only because there is no `knowledge/` tree (N/A here). Both
  recorded in `4_verify.md`.

## v0.4.0-rc.18 — 2026-10-11
- Scope: Issue #32 — a plan now records that the knowledge base was queried, and the gate surfaces a
  missing record. `2_plan.md`'s `## Related prior work` section carries a required `- KB:` line
  (`- KB: [[<page>]] (knowledge/…)` for hits, or `- KB: no relevant pages` for none). New
  `prior_art_warning` helper in `core/scripts/task-state.sh`, called by `check-plan` and `check-chain`
  (run by `-build`), prints an advisory when it is missing and still exits 0 — the same fail-open
  contract as `check-adr`. The `pr-review` skill adds a Prior-art pass that raises a Nit. All in
  `core/` (script, template, skills), so no adapter or manifest row changed.
- Artifacts: `.agents/artifacts/task_2026_10_11_prior_art_trace/`
- Outcome: Implemented and committed in `84917f5` (`closes #32`). Release `0.4.0-rc.18` needs no
  `changelogs/version-*.md` prompt — no merge/manifest row changed; the script/template/skill are
  `copy` rows on the existing `core/` install row. Verified: `bash -n` clean, suites 16/24/38/59/37
  green, `git diff --check` clean, scratch fixture (bundle + 3 adapters) shows the installed
  `check-plan` printing the advisory while exiting 0, and `audit-install.sh` clean.
- Caveat: the memory-gate's green here is partial (no `.agents/monorepo-agents-harness/` install, so
  no `TASK_STATE`; it skips `check-kb` and enforces the newest dir by fallback). `check-kb` exits 1
  only because there is no `knowledge/` tree (N/A here). Both recorded in `4_verify.md`.

## v0.4.0-rc.19 — 2026-10-11
- Scope: Issue #31 — detect a pointer file that stopped importing the root `AGENTS.md`. The claude-code
  adapter reads the single source of truth through the thin root `CLAUDE.md` (`@AGENTS.md`), but that
  file is a `tmpl` manifest row — never overwritten — so a repo that already had its own `CLAUDE.md`
  without the import silently lost the whole root `AGENTS.md` (checklist, gotchas, KB-first rule).
  New template-driven `check_pointer_imports` (Check 7) in `core/scripts/audit-install.sh`: for every
  adapter `tmpl`/`merge` row it reads the first `@<path>` token the **shipped template** carries and
  reports the project file when it is missing. `core/scripts/install-adapter.sh` adds an import-aware
  `Needs you:` line; both stay read-only on the consumer file. `harness-update` skill step 9.5,
  `adapters/claude-code/INSTALL.md` and `PORTABILITY.md` state the rule. No manifest row changed.
- Artifacts: `.agents/artifacts/task_2026_10_11_claude_md_import_guard/`
- Outcome: Implemented and committed in `657da8d` (`closes #31`). Release `0.4.0-rc.19` (developer's
  answer) with `CHANGELOG.md` section + `changelogs/version-0.4.0-rc.19.md` (one manual follow-up: add
  `@AGENTS.md` if you keep your own `CLAUDE.md`). New repo-local `tests/audit-import.test.sh` (12
  cases); suites 12/16/24/37/38/59 green, `bash -n` clean, `git diff --check` clean. Natural
  end-to-end in a scratch consumer (real `install-harness.sh` + `install-adapter.sh claude-code`): a
  pre-existing `CLAUDE.md` without the import gets the `Needs you:` note + a `.harness-proposed`
  (original byte-identical), `audit-install.sh` reports the gap, and after adding the one line the
  audit is clean. Two text guards initially grepped prose that wrapped across lines + backticks and
  failed on the real files — retargeted to stable tokens (`import gap`, `@AGENTS.md`).
- Caveat: the memory-gate's green here is partial (no `.agents/monorepo-agents-harness/` install, so
  no `TASK_STATE`; it skips `check-kb` and enforces the newest dir by fallback). `check-kb` is N/A
  (no `knowledge/` tree here). Both recorded in `4_verify.md`.

## v0.4.0-rc.20 — 2026-10-12
- Scope: Make the intent stage reach the knowledge base (issue #39). `/monorepo-harness-intent`
  Capture now runs `core/scripts/kb-index.sh query` (ranked SQLite FTS5 over `knowledge/`, grep
  fallback) **before** writing the intent and records the result in a new `## Prior art` section
  (`- KB: [[<page>]] (knowledge/…)`, or `- KB: no relevant pages`); Review queries per pending intent,
  shows the hits and fills in `## Prior art` when missing. Mirrors the plan's `- KB:` trace (#32) one
  stage earlier, like #27/#28 did for the spec stage. Instruction/text-only: skill +
  `core/governance/intents/AGENTS.md` intent format + three intent stubs (claude/opencode/codex) +
  docs (`README.md` Scenario 1, `PORTABILITY.md`, `INSTALL.md`) + `tests/prior-art.test.sh` guards.
- Artifacts: `.agents/artifacts/task_2026_10_12_intent_kb_prior_art/`
- Outcome: Release `0.4.0-rc.20` (developer's answer) with `CHANGELOG.md` Changed + Upgrade Notes and
  no `changelogs/version-*.md` prompt (nothing to run). Verified via greps (`kb-index.sh query` and
  `## Prior art` in the skill + three stubs), `tests/prior-art.test.sh` green with the new guards,
  `git diff --check` clean, and a scratch-consumer fixture + `audit-install.sh --against` clean.
  No script, manifest or gate change.
- Caveat: `kb-index.sh query` exits 1 here (`knowledge/` does not exist in this template repo), so the
  recorded trace is the `- KB: no relevant pages` path. `check-kb` is N/A (no `knowledge/` tree). Both
  noted in `4_verify.md`.

## v0.4.0-rc.21 — 2026-10-13
- Scope: Issue #41 — a finished `/monorepo-harness-build` now suggests `/monorepo-harness-review`,
  decided deterministically. New `core/scripts/build-review-tier.sh <task_dir>` prints `simple` or
  `comprehensive` from the changed-file count (`3_memory.md` `commits:`, fallback plan affected files)
  and the spec's architectural signals (an `adr/` file, or a non-`N/A` `## Architectural decisions` /
  `## API / contracts` / `## Data model`). `agent-workflow` skill gains an "After the build" subsection
  and a `-build` row note; the three build stubs gain a final step (`simple` → one informational line;
  `comprehensive` → ask, then run the `pr-review` skill inline); `pr-review` skill gains an
  end-of-build note; `README.md`/`PORTABILITY.md` sync; `tests/build-review-tier.test.sh` (16 cases).
- Artifacts: `.agents/artifacts/task_2026_10_13_build_review_suggestion/`
- Outcome: Release `0.4.0-rc.21` (developer's answer) with `CHANGELOG.md` Added + Upgrade Notes and
  `changelogs/version-0.4.0-rc.21.md` (maintainer-requested; strictly the release needs no prompt —
  no command, no manual follow-up — the helper ships on the `core/` directory row). Verified: new
  suite 16/16 and all suites green (12/16/24/38/59/19/37), `bash -n`
  clean, the three stub bodies byte-identical, greps name the helper in the skill + all three stubs,
  `git diff --check` clean, and a scratch consumer where the installed helper is present/executable
  and `audit-install.sh --against <repo>` is clean. Committed `62478c6` (`closes #41`) on
  `feat/build-review-suggestion`.
- **Deviation recorded:** #41 asked for an automatic, blocking review before the unit-test phase. The
  harness has no separate unit-test phase (tests are part of the implementation; `4_verify.md` records
  their run), so the review is a conditional, non-blocking suggestion at the end of the build. The
  issue text/title should be updated to match.
- Caveat: `memory-gate.sh` exits 0 here; `check-kb` exits 1 only because this repo keeps no committed
  `knowledge/` tree (N/A). Both recorded in `4_verify.md`.

## v0.4.0-rc.22 — 2026-10-13
- Scope: Issue #42 — add an objectivity rule so the agent never flatters or blindly agrees with the
  developer. New shared rule `core/governance/rules/objectivity.md` (judge the input not the person;
  say "no" with evidence; hold a correct position under pushback; no flattery openers; report
  outcomes as they are; do not over-correct), surfaced the same way as `simple-english`: a numbered
  Critical Gotcha in `core/root-AGENTS.md` (gotcha 7, so it stays in context every turn), a
  Reference Map row, and an explicit audited `core/install-manifest.txt` row. No script, no gate, no
  adapter change, no `agents-md-merge` change.
- Artifacts: `.agents/artifacts/task_2026_10_13_objectivity_rule/`
- Outcome: Release `0.4.0-rc.22` (developer's answer) with `CHANGELOG.md` Added + Upgrade Notes and
  **no** prompt (a bundle file needs a manifest row, not a prompt, and the root `AGENTS.md` merge is
  handled by `agents-md-merge` step 9). Verified: all suites green, gotcha numbering sequential
  (1–7), greps name the rule file in the gotcha, the Reference Map and the manifest, `git diff
  --check` clean. Committed `cbb596b` (`closes #42`) on `feat/objectivity-rule-42`.
- **Deferred:** the issue's optional review-side pass (flag agent-written artifacts that state
  agreement or success without evidence) is left as a separate follow-up, by the developer's choice.
- Caveat: `kb-index.sh query` is unavailable here (`.agents/monorepo-agents-harness/` is not
  installed in the template repo and there is no committed `knowledge/` tree) — recorded as the
  "no relevant pages" path. The `agents-md-merge` propagation claim rests on reading Steps 4–5; no
  test exercises that path. Both noted in `4_verify.md`.

## v0.4.0-rc.22 — 2026-10-18
- Scope: Plan-mode session for issue #45 — `/monorepo-harness-intent --reject <PR-url>...`.
  Research corrected the issue itself twice: governance and the workflow already use the
  canonical `status: rejected` (an earlier "fix" to `declined` was reverted), and the claimed
  `intent-naming` skill with a `reject` verb does not exist (step 6 rewritten around the
  governance `pr:` push precedent). Verified the merge-intent-pr approval gate is real
  (`task-state.sh` re-reads `approval_from_pr` even with `--yes`), so the issue's open question 1
  stands: the reject path needs its own route. Spec answers all five open questions (own
  `--reject` merge mode gated on the file's `status: rejected` + in-turn `--yes`; no forge
  review-state write; continue-on-partial; already-rejected no-op; two consent questions).
- Artifacts: `.agents/artifacts/task_2026_10_18_intent_reject_flag/`
- Outcome: `1_spec.md` + `2_plan.md` written; artifacts index row added (30 tasks); todo
  overwritten. No code, manifest, or version change — plan phase only, stopping for plan approval
  per agent-workflow Phase 1. VERSION stays `0.4.0-rc.22` until implementation, when the
  developer gives the release number.

## v0.4.0-rc.23 — 2026-10-18
- Scope: Implementation of issue #45 — `/monorepo-harness-intent --reject <PR-url>...`, approved
  plan executed step by step. `task-state.sh merge-intent-pr --reject` swaps the approving-review
  gate for the intent file's own `status: rejected` + the in-turn `--yes` (reviews never read in
  this mode); the skill gains `## Workflow — Reject` (6 steps: resolve PR head, three guards, batch
  consent + reason, status+`## Review`+commit+push on the PR branch, separate batch merge question,
  partial-truth report); the three adapter entry points gain one byte-identical bullet;
  `core/governance/intents/AGENTS.md` gains the reject-path paragraph; README/PORTABILITY/INSTALL
  synced (INSTALL at exactly the 100-line cap). Repo-local suite `tests/merge-intent-reject.test.sh`
  (28 cases: gate swap both directions, missing status, state-first no-op, exit 3, `--reject`
  refused elsewhere = exit 2, dry-run, merge failures 1/3, approve-route regressions, and a stub
  that fails the test if `reviews` is ever called in reject mode).
- Artifacts: `.agents/artifacts/task_2026_10_18_intent_reject_flag/` (incl. `adr/0001-reject-merge-
  gate-is-the-decision-not-a-review.md` — plan said `0004`, per-task numbering restarts, fixed
  pre-commit; `check-adr` exit 0)
- Outcome: Release `0.4.0-rc.23` (developer's answer) — `CHANGELOG.md` Added + Upgrade Notes and
  `changelogs/version-0.4.0-rc.23.md` (maintainer-requested; the release strictly needs no prompt —
  instruction/script-only, `changelogs/README.md` says to omit). Verified: new
  suite 28/28, all 8 suites green, `bash -n` + `git diff --check` clean, stub bodies byte-identical
  (`8a02ce05…`), scratch consumer install ×2 (consumer-facing writes 0 on the re-run; bundle rows
  re-synced by design into `.harness-trash/`) + three adapters + `audit-install.sh --against <repo>`
  clean twice, installed skill/stubs carry the workflow, live `gh` state read against merged PR #44
  (exit 0 no-op before the gate). Committed `dfae632` (`closes #45`) on `feat/intent-reject-flag-45`,
  pushed, PR opened: https://github.com/atayahmet/monorepo-agents-harness/pull/48 — merged
  (`818149b`, 2026-10-18) and tagged `v0.4.0-rc.23` (annotated, pushed to origin).
- **Note:** the spec's "second run writes 0 files" wording was wrong about the installer's
  mechanism — corrected in `4_verify.md` and `3_memory.md` (what is 0 is consumer-facing writes).
- Caveat: `memory-gate.sh` exits 0 here (no bundle install → its `check-kb` step is skipped);
  `check-kb` exits 1 only because this repo keeps no committed `knowledge/` tree (N/A, same as
  rc.21/rc.22). No open PR existed at verification time, so the live run covers the merged-PR read
  only; a real reject merge is left to the developer (recorded in `4_verify.md`).
