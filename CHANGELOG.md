# Changelog

All notable changes to the agent harness are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/), prereleases included (`0.1.0-rc.0` precedes `0.1.0`).

Every release MUST include an **Upgrade Notes** section describing anything an installed copy needs
to do beyond the normal sync (behavior changes, artifact-layout changes, manual merges).

Release procedure (harness maintainers):

1. Update `VERSION` at the repo root (SemVer: MAJOR = workflow/artifact-layout breakers, MINOR = new
   capabilities, PATCH = fixes/docs; `-rc.N` while stabilizing a release).
2. Add a `CHANGELOG.md` section with Upgrade Notes.
3. Add `changelogs/version-X.Y.Z.md` if the release needs anything the manifests cannot express —
   commands to run or manual follow-ups. Files added to the bundle or an adapter need **no** prompt:
   add the manifest row instead (`changelogs/README.md`).
4. Commit and tag the upstream repo as `vX.Y.Z` (`git tag -a vX.Y.Z -m … && git push origin vX.Y.Z`).

## [0.4.0-rc.13] - 2026-10-07

### Added

- **Ranked search over the knowledge base** (issue #25) — new `core/scripts/kb-index.sh` builds a
  gitignored SQLite FTS5 cache (`knowledge/.index.sqlite`) over `knowledge/**/*.md` and answers from
  it: `rebuild` (deterministic `find | sort`, temp file + `mv`, so an interrupted run can never
  leave an empty or half-written index), `query "<terms>"` (BM25-ordered paths with `snippet()` hits,
  `--kind` / `--workspace` / `--limit`), and `links --missing` / `links --orphans` (one SQL pass each
  over the `[[wiki-link]]` and markdown link edges). Query and lint **self-heal staleness first** — a
  page `kb-ingest.sh` just wrote is found with no manual rebuild — while `kb-ingest.sh` itself stays
  untouched, so task-end cost is still zero. `kind`, `workspace`, `task_slug` and `date` are derived
  from the page shapes in `knowledge/schema.md`; indexing raw `.agents/artifacts/` trees is
  deliberately left to phase 2 (the schema already carries those columns, so no migration then).
- **`/monorepo-harness-kb-index` in all three adapters** — a thin command over `kb-index.sh` that
  follows `core/skills/knowledge-base/SKILL.md` (three new `copy` manifest rows, and the Hard Rule 7
  enumeration in `adapters/AGENTS.md`).
- **`knowledge/.index.sqlite*` never reaches git** — new bundle row `core/gitignore-fragment.txt`,
  whose lines `install-harness.sh` merges into the consumer's root `.gitignore` idempotently (absent
  lines only) and `audit-install.sh` verifies verbatim in Check 5c, alongside an explicit
  `kb-index.sh`-in-bundle check.
- **`tests/kb-index.test.sh`** (34 cases): a double rebuild yields identical rows and query output, a
  failed and a `SIGKILL`ed rebuild leave the previous index answering, staleness self-heals on both
  add and delete, a `PATH` without `sqlite3` exits 1 with exactly one warning while the grep fallback
  still answers, and both link lints report what they should (README seeds and the root `index.md`
  are never orphans).

### Upgrade Notes

- The new script ships inside `core/`, so the normal update is enough
  (`/monorepo-harness-update`, or `install-harness.sh --sync-only`); refresh each adapter as usual —
  the three `/monorepo-harness-kb-index` files arrive from `copy` rows via
  `install-adapter.sh --refresh`. Upgrade prompt: `changelogs/version-0.4.0-rc.13.md` (no command
  to run by hand — the manifest-driven update covers everything; it records the `.gitignore` check
  and the `sqlite3`/FTS5 ranking note).
- **Your root `.gitignore` gains two lines** (`# Derived harness caches …` and
  `knowledge/.index.sqlite*`) on the next `install-harness.sh` run, sync-only included. They are
  appended only when absent, and `audit-install.sh` names any line you delete.
- **No schema migration and no manual indexing step.** The index does not exist yet on an installed
  copy; the first `query` builds it (sub-second at KB scale). Deleting `knowledge/.index.sqlite` at
  any time is safe — it is a cache, and the next query rebuilds it. A machine without `sqlite3`, or
  with a build lacking FTS5, gets one warning and a non-zero exit from `kb-index.sh`, and the skill
  falls back to `index.md` + grep exactly as before — same results, only the ranking is lost.
- Docs changed in the same release: `core/skills/knowledge-base/SKILL.md` (principle, query and lint
  workflows, never-do), a new index-layer section in `knowledge/schema.md`, `PORTABILITY.md`
  (matrix row + a new semantic-difference note), `README.md`, `INSTALL.md`, the three adapter
  READMEs and INSTALL.md tables, and `adapters/AGENTS.md` Hard Rule 7.

## [0.4.0-rc.12] - 2026-10-07

### Fixed

- **A repo-root task dir is now read by the gate and armed by the hook** (issue #22).
  `memory-gate.sh` and `hook-arm-build.sh` discovered task directories only under workspace parents
  (`apps/*`, `packages/*`, whatever `detect-monorepo-framework.sh` reports), so the directory the
  root `AGENTS.md` allows at the repository root — `<repo>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/`,
  the workspace of a repo with no `apps/` and no `packages/` — was invisible: the `-build` command
  wrote `build_started` and nothing ever enforced it. Both scripts now add
  `$ROOT/.agents/artifacts/task_*` to the same scan set, so arming and enforcing cannot disagree
  about it again.
- **A write into a directory that does not exist yet arms its plan** (`hook-arm-build.sh`). The
  written path was resolved by `dirname` and only when that parent already existed — while the first
  write of a build is normally a brand-new file in a brand-new directory. With a spelling the repo
  root does not share (a doubled slash from `TMPDIR`, a symlinked checkout) such a path matched
  neither the physical root nor `PWD`, the workspace rule failed closed and the plan stayed unarmed.
  The hook now walks up to the deepest directory that exists, resolves that one physically, and
  re-appends the part below it.

### Added

- **Regression tests for both halves** (`tests/memory-gate.test.sh`, 12 new cases): a repo-root
  build-stage dir is enforced by default mode and blocked by `--json`, in a fixture with `apps/` and
  in one with neither `apps/` nor `packages/`; a repo-root plan is armed by an ordinary write, never
  by an artifact write, and not by a write that belongs to a workspace plan; new-file writes arm in
  both layouts. Reverting either fix fails the cases that cover it.

### Upgrade Notes

- No new bundle or adapter file, so no manifest row and no copy step: `core/` ships whole. Run the
  normal update (`/monorepo-harness-update`, or `core/scripts/install-harness.sh --sync-only`) and
  refresh the adapter as usual.
- **The gate can now reach a repo-root task.** If a build-stage task lives in
  `<repo>/.agents/artifacts/`, commits and the Stop hook will start demanding its `3_memory.md`
  (and `4_verify.md` when the spec asks for one) — the enforcement that was always meant for it.
  Nothing to do when that directory does not exist or its tasks are already finished.

## [0.4.0-rc.10] - 2026-10-03

### Fixed

- **The arming hook now arms only what the gate would enforce** (issues #19, #20). `rc.9` gave the
  memory gate a build-stage marker, but the hook that writes it was left unscoped: it marked the
  newest task dir of **any** date, in **any** workspace, ordered by file modification time. Three
  consequences, all fixed by making the hook's candidate list identical to the gate's:
  - **A finished task was marked again by an unrelated write.** A task that already has
    `3_memory.md` is skipped, so a later edit anywhere in the repo can no longer stamp
    `build_started` into a committed, finished task dir and dirty it.
  - **A write in one workspace armed another workspace's plan.** A plan is now armed only when the
    written path is inside that plan's own workspace — the path in front of the task's own
    `.agents/artifacts/`, so the rule needs no lookup table and cannot disagree with where the dir
    lives. A path that cannot be placed arms nothing.
  - **An old task dir with a fresh mtime won.** "Newest" is now the **date in the directory name**
    (`task_<YYYY_MM_DD>_<slug>`), with mtime only as a tie-break inside one date, and only among
    dirs created today — the gate reads no other date. A `git checkout`, rebase or stash pop rewrites
    mtime, so mtime is not the task's age.
  - The stage question is no longer re-implemented in the hook: it calls `task-state.sh stage`, the
    same reader the gate uses, legacy plan filenames included.
  - `harness_task_dirs_newest_first` in `core/scripts/harness-common.sh` is the single order both
    scripts use, so the hook and the gate cannot drift apart. Each script falls back to its previous
    order when that library is absent — a shared library must never be able to switch a gate off.

### Added

- **`task-state.sh sync-commits <3_memory.md>` — keeps a memory's `commits:` list true after a
  rewritten history** (issue #21). A sha is a name a commit has on one branch: a rebase, squash or
  force-push leaves it pointing at nothing while the change itself survives, so a finished task's
  memory silently became a list of dead references.
  - **Identity by content.** A sha still reachable from the ref is kept as is; one that is not is
    matched by `git patch-id --stable` — the identity of the change rather than of one branch's
    history — and rewritten to the sha carrying the same content.
  - **Refused to guess.** `--ref` defaults to `origin/HEAD`, then `main`, then `master`, and the ref
    used is always printed. A sha with no unique match is left exactly as written, named in the
    report, and the command exits 1; a history that is not reachable at all exits 3 with nothing
    compared. Dry run by default, `--write` applies.
  - **`patch_ids:` in the memory frontmatter**, the durable join key for tools, written by
    `sync-commits` next to the shas it verified. The memory-gate does not require it, so a memory
    written before this version stays valid.

### Changed

- `core/root-AGENTS.md` (installed as the consumer's `AGENTS.md`): the memory bullet now names
  `patch_ids:` and points at `sync-commits` for a rewritten history. Follow-up: a few files the
  `-build` command writes are not covered by the file-write hook (`4_verify.md`, `index.md`).
- `hook-arm-build.sh` is now documented as workspace-scoped and today-scoped in `PORTABILITY.md`,
  `adapters/AGENTS.md` and the claude-code README, so an adapter author reads the real contract.
- The `agent-workflow` skill says plainly that `ls -t` orders by mtime, not by task age, and keeps
  it only as a same-day tie-break.

### Upgrade Notes

- No new bundle or adapter file, so no manifest row and no copy step: `core/` ships whole and
  `sync-commits` is a new subcommand of a script that already ships. Run the normal update
  (`/monorepo-harness-update`, or `core/scripts/install-harness.sh --sync-only`) and refresh the
  adapter.
- Behaviour change with no action needed: a `PreToolUse` hook in an installed claude-code copy will
  now arm **less** often — only for today's plans, in the workspace being written to, without a
  `3_memory.md`. If arming seems too quiet, check that the workspace really has a task dir created
  today: `ls -d apps/*/.agents/artifacts/task_$(date +%Y_%m_%d)_*`.
- To repair memories whose commits were already rewritten:
  `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh sync-commits <task_dir>/3_memory.md --write`
  (dry run without `--write`).

## [0.4.0-rc.9] - 2026-09-29

### Fixed

- **The memory gate no longer blocks a task that never started building** (issue #17). `/monorepo-
  harness-spec` and `/monorepo-harness-plan` are supposed to end at a stage boundary, but the gate
  asked every task dir created that day for `3_memory.md` — so a legitimate spec-only turn was
  blocked, and on claude-code the block could repeat, because the Stop hook only ever saw "this task
  is missing its artifacts". The gate now asks **one question, read from one place**: has this task
  reached the build stage?
  - **The marker is one field, written once.** `build_started: <ISO-8601>` in `2_plan.md` frontmatter,
    written by the new `task-state.sh mark-build <2_plan.md>`. No new file, nothing in the artifact
    index, and a re-run never restamps it.
  - **`task-state.sh stage <task_dir>` is the single stage reader**, answering `none`, `spec`, `plan`
    or `build`. `memory-gate.sh`, `hook-arm-build.sh` and every doc read the same answer; the marker
    wins over file presence, so a build whose spec was later deleted is still a build.
  - **The newest task dir no longer masks an in-flight build.** The gate scans every task dir created
    today and keeps the ones at build stage, newest first, instead of enforcing whichever dir `ls -t`
    happened to return. Opening a fresh spec while yesterday's build is still open no longer hides it.
  - **Both modes are stage-scoped.** `--json` (Claude Stop hook) and the default mode (git
    pre-commit / CI) answer the same question, so CI cannot reject a commit a local hook allowed.
  - **The block still cannot repeat.** The gate reads its own hook input and stands down silently when
    `stop_hook_active` is true. Anything unreadable — absent, `false`, or malformed — still enforces:
    a fix for a blocking loop must never double as a switch to turn the gate off. A `jq` that is
    present but broken now also fails open instead of crashing the hook.
  - **Enforcement at build stage is unchanged**, including `4_verify.md` when the spec's verification
    plan is not `N/A` and the knowledge-base coverage check. If the stage reader cannot be found, the
    gate falls back to its old "newest task dir" behaviour rather than silently passing.

### Added

- **`core/scripts/hook-arm-build.sh` — the gate arms itself when implementation starts.** A `PreToolUse`
  hook for `Write`/`Edit`/`MultiEdit`/`NotebookEdit` watches the first write that is **not** a task
  artifact and calls `mark-build` on the newest plan. This covers the one path the marker cannot:
  an agent that leaves plan mode, writes `1_spec.md` + `2_plan.md` and edits code without ever
  running `/monorepo-harness-build`. It edits nothing itself, depends only on coreutils (jq when
  present, a unique-match fallback when not), and always exits 0 — a hook that cannot answer must
  never stand between an agent and its edit.
  - **Wired for claude-code** in `.claude/settings.json` (`Write|Edit|MultiEdit|NotebookEdit`).
  - **Codex keeps the prose path**, by design: Codex has no equivalent file-write hook whose matcher
    could be verified, so its `update_plan` reminder names `task-state.sh mark-build` explicitly. The
    gate itself is identical on every agent — only the arming differs (`PORTABILITY.md`).
- **`tests/memory-gate.test.sh` — 40 cases, repo-local.** Spec-only and plan-only pass; a build without
  memory or verify is blocked; `stop_hook_active` true is silent and false/malformed/absent still
  blocks; `N/A` verification plans need memory alone; kb coverage is unchanged; a newer spec-only dir
  does not mask a build; `stage` and `mark-build` are write-once; the hook arms on a code write, never
  on a `.agents/` write, and arms nothing when it cannot tell which file was edited. Each case runs
  against a throwaway installed-layout git fixture. The file is deliberately **not** in
  `core/install-manifest.txt` — `core/` ships whole, and a test tree must not reach a consumer.

### Changed

- **`core/root-AGENTS.md` (the installable root guidelines) — gotcha 5 now describes the real
  contract**: the memory gate scans every workspace and blocks a task from ending only once it has
  `build_started` and is missing `3_memory.md` (and `4_verify.md` when required) — a spec-only or
  plan-only task is never blocked, and a spec-only task is never gated at all.
- `core/skills/agent-workflow/SKILL.md`, `PORTABILITY.md`, `README.md`, `adapters/AGENTS.md`, the
  three adapter READMEs, all three adapter INSTALL guides, the root `INSTALL.md` smoke test, and
  `core/skills/ci-integration/SKILL.md` describe the same staged contract. The build command's
  new step 3 is `task-state.sh mark-build`; the three adapters keep identical step numbers.

### Upgrade Notes

- **One manual step for claude-code and codex installs.** Both adapter settings files are `merge` rows
  and both gained content, so an already-installed copy needs the new `PreToolUse` hook
  (claude-code) or the reworded `update_plan` reminder (codex). Run the normal adapter refresh, then
  accept the `.harness-proposed` changes in `.claude/settings.json` and `.codex/hooks.json`.
- **No commands to run and no manifest rows owed.** `core/install-manifest.txt` already copies the
  whole `core/` directory, so `core/scripts/hook-arm-build.sh` ships with the normal sync; no adapter
  gained or lost a file.
- **Nothing to migrate, and a task already in flight is not retro-blocked.** Plans written before this
  version have no `build_started`, so they read as `plan` and the gate stays quiet until the first
  write outside `.agents/` or the first `/monorepo-harness-build` marks them. That is intentional: a
  finished 0.4.0-rc.8 build keeps its own memory and verify files and needs no marker.
- **CI and pre-commit now allow spec-only and plan-only commits** — the intended effect, not a
  regression. Re-run your gate (`bash .agents/monorepo-agents-harness/core/scripts/memory-gate.sh`) if
  you expected a build-stage task to be blocked and it is not.
- See `changelogs/version-0.4.0-rc.9.md`.

## [0.4.0-rc.8] - 2026-09-29

### Added

- **A multi-phase intent can get one parent issue.** `tracker-issue.sh --create` takes `--parent
  <number-or-url>`, which maps to `gh issue create --parent` — a real parent/child relation on the
  tracker, not a label. Dispatch asks *"Start these N phases under an epic?"* inside the existing
  step 5 sign-off table, so the epic is consented to in the same turn as the phase list; on a "yes"
  it creates the epic (an ordinary issue, no new script) and files every phase as its sub-issue.
  - **At `N >= 2` only.** A single-phase intent gets no epic, no row and no extra question, and a
    second phase is never invented to justify one.
  - **`no epic` is an explicit answer**; it files the phases flat, exactly as before.
  - **A re-run never files a second epic.** The epic named in the intent's newest `## Dispatch` block
    is reused, and an open-work candidate becomes the epic only when the developer nominates it in the
    current turn — the automatic-dedupe prohibition of ADR
    `0002-dispatch_gates_open_work_and_consents_pr_merge.md` is unchanged.
  - **GitHub's create is atomic in its parent field**, so a child and its parent either both exist or
    neither does. There is no "created but unlinked" state to report, and a refused link is an
    ordinary exit-1 create failure recorded as `no issue yet (<reason>)` like any other.
- **`## Dispatch` — the intent records what it produced** (`core/governance/intents/AGENTS.md`).
  One append-only block per dispatch run (newest last) holding the tracker, the `Epic:` line (omitted
  entirely when there is no epic) and one `Phases:` line per phase slug with the key and URL the
  create actually returned, or `no issue yet (<reason>)`. It is the second thing dispatch records on
  the intent file and closes the traceability gap left once the PR is merged — **the number of files
  dispatch writes stays at two** (intent file + tracker cache); `## Dispatch` is a section of the
  existing intent, not a new file. No key is ever inferred from a title or carried over from an
  earlier turn, and a partial run records the partial truth.

### Changed

- **`tracker-issue.sh --create` now prints `tracker-issue: created number=<n>` before the URL.** The
  number is what a parent link and a `## Dispatch` row need, and deriving it from the URL meant every
  caller re-parsed a string it was never meant to parse. The URL is still the last line, so
  `tail -1` keeps working.
- **A `gh` too old for `--parent` degrades to flat, it does not fail.** The script probes
  `gh issue create --help` for the flag when `--parent` is used; without it (present in `gh` 2.100.0)
  it prints paste-ready title and body and exits 3 — the same floor as "`gh` not found". The phases
  are filed without a parent, the report says the epic is unlinked, and no dispatch is blocked. No
  version check exists anywhere else and no floor is pinned.

### Documentation

- `PORTABILITY.md` records the epic decision and the parent link as agent-neutral: same sign-off
  question, same `--parent` flag, same reuse rule on claude-code, opencode and codex, with the
  `tracker` subagent and the two inline agents changed together.
- The three adapter READMEs and the shared workflow paragraph in `README.md` describe the epic
  question, the sub-issue link and the `## Dispatch` record. `INSTALL.md` needed no change — no file
  was added to either manifest, so installation is unchanged.

### Upgrade Notes

- No commands, no manifest rows, no artifact-layout change, and nothing to migrate: intents dispatched
  under earlier versions simply have no `## Dispatch` block, and the first dispatch that follows writes
  one with no earlier epic to reuse.
- Optional: if you want the epic link, `gh` must be **2.100.0 or newer** (`gh --version`). On an older
  `gh` every phase still gets an issue, just without the parent link — there is no harness setting to
  change.
- See `changelogs/version-0.4.0-rc.8.md`.

## [0.4.0-rc.7] - 2026-09-28

### Added

- **`core/scripts/forge.sh` — the intent PR's forge is resolved, never assumed.** A new agent-neutral
  script owns every read of a pull request and the merge itself, so `task-state.sh` and
  `tracker-issue.sh` no longer hard-code GitHub. Subcommands: `resolve`, `probe`, `state`, `reviews`,
  `issues`, `merge`, `paste`.
  - **Platforms:** GitHub, GitLab (including nested groups), Bitbucket, Gitea and self-hosted hosts.
  - **Forge precedence:** the host in the `pr:` value itself, then a `forge:` line in
    `<repo-root>/.agents/tracker.md`, then this repo's `origin` remote. A bare `#42` with no
    `origin` is refused rather than assumed to be GitHub.
  - **Mechanism ladder, each rung probe-verified with a real read before any write is considered:**
    the platform's own CLI (`gh` / `glab` / `bb` / `tea`), then that platform's REST API using a token
    the project **already exports** (`GITHUB_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN`,
    `GITEA_TOKEN`), then a project MCP server or a project skill. The harness installs, prompts for
    and stores no credential.
  - **Agent-only handoff:** a shell script cannot call an MCP tool, so when only the last rung exists
    the script names the config file and the server, states plainly that it cannot verify an approval
    and will not merge, and the agent makes the call with its own tools under the same rule. A project
    skill outranks a generic command, because the project's own procedure wins.
  - **Exit codes:** `0` done (resolved / probed / read / listed / merged / already merged), `1`
    refused or usage error, `3` not done — no mechanism could read it, which is a different answer
    from "the harness looked and said no".
- **`task-state.sh check-intent-approved` and `merge-intent-pr` work on any forge.** Both delegate
  every PR read to `forge.sh`. A cross-repository ref keeps its `owner/name` or full URL so it can
  never resolve against the current project, and `merge --explain` prints the exact command it would
  run (`gh pr merge 10 --merge`) so the write is inspectable before `--yes`.
- **`tracker-issue.sh --list-open` reads the board through `forge.sh`**, so the already-open
  duplicate check works on self-hosted and non-GitHub forges. Multi-word search terms and results
  matched across terms are de-duplicated. Issue **creation** remains GitHub-only in this release —
  reading a board and writing to it are separate axes (ADR
  `0003-forge_axis_is_separate_from_the_tracker_axis.md`).

### Changed

- **An approval the harness cannot read is no longer replaced by the intent file's own
  `status: approved`.** This is the one deliberate reversal in this release. In rc.6, if the PR could
  not be read, dispatch fell back to the file — so on **any** project whose PR the harness could not
  reach (which is every MCP-only or self-hosted setup, i.e. the setup this release exists to support)
  the file stood in for a human's decision, every single time. That was a standing permission slip
  with a success message attached. An unreadable approval is now `UNKNOWN`: `check-intent-approved`
  exits 1 and names the fact, `merge-intent-pr` exits 3 and hands off. The file is still
  authoritative in the one case it is meant to be — an intent with **no** `pr:` field at all — and
  the script reports which source it used.
- **A read that cannot happen is never a board state.** `--list-open` and `forge.sh` reads exit 3 on
  an unreadable board, and the skill says "unknown is never nothing is open" so an agent cannot
  answer the duplicate question from memory either.
- **A project skill outranks a generic command when both are available**, and a conflict is reported
  rather than silently resolved.
- **`merge-intent-pr` separates "refused" from "could not look".** Exit 1 means the harness read the
  PR and said no (still open); exit 3 means it could not read it at all, so the approval is unknown
  and nothing was merged. The three adapter entry points, the shared skill, the intents governance
  doc, `PORTABILITY.md`, `README.md`, `INSTALL.md` and the three adapter READMEs now describe the
  merge this way.

### Fixed

- **PR refs are normalized once, and the host in the ref wins.** A trailing `/files` or `/commits`
  suffix on a GitHub or Gitea PR URL, a scp-style URL (`git@host:owner/name/pull/42`), an `owner/name`
  pair containing dashes or digits, and GitLab nested groups all resolve to the same ref instead of
  being refused or misread.
- **Review state is a single uppercase vocabulary.** `CHANGES_REQUESTED` and `REQUEST_CHANGES` are
  both recognized as a request for changes; `OPEN` / `open` and `MERGED` / `merged` normalize, so a
  platform's own casing cannot silently satisfy the gate.
- **GitLab and Gitea REST merges no longer fail on the request itself.** The JSON body was being
  appended to the URL, so the request was malformed before the endpoint was ever reached; Gitea's
  merge field is now `{"Do":"merge"}` rather than GitHub's `{"merge_method":"merge"}`. A REST merge
  also confirms the response state before reporting success, instead of reporting on a 2xx alone.
- **A quoted or multi-word `pr:` survives end to end.** A `pr:` value wrapped in quotes reaches
  `forge.sh` unquoted, and a multi-word `--search` term on the duplicate check is one term rather
  than several.
- **`forge.sh` is executable in the installed bundle.** It was created non-executable, so a direct
  invocation failed with exit 126 while `bash forge.sh` worked — an inconsistency every other script
  in `core/scripts/` does not have.

### Upgrade Notes

- **`core/install-manifest.txt` already copies the whole `core/` directory**, so the new
  `core/scripts/forge.sh` needs **no** manifest row. Run the normal `/monorepo-harness-update` sync
  and the adapter refresh; see `changelogs/version-0.4.0-rc.7.md` for the `forge:` line you may want
  to add to `.agents/tracker.md`, and for the one manual follow-up that matters: if you relied on the
  rc.6 file fallback, an intent whose `pr:` the harness could not read is now refused rather than
  approved.

## [0.4.0-rc.6] - 2026-09-28

### Added

- **`/monorepo-harness-intent-dispatch` checks whether the work is already open before filing it.**
  Two asks, both asked on every agent, in this order, after the existing approval / push / scope /
  phase / sign-off steps:
  1. **"This work may already be open — create these phases anyway?"** — the command reads the
     project's own tracker (`tracker-issue.sh --list-open --search <keyword>...`, read-only) and
     shows every open match before creating anything. New read-only mode on `tracker-issue.sh`:
     repeatable `--search` terms, results unioned and de-duplicated by issue number, `count=0` is
     success, and the same tracker resolution and harness-repo refusal as `--create` so the check can
     never read the wrong board. It **writes nothing** — no comment, label, assignment or close —
     and nothing is created without an explicit yes in the current turn.
  2. **"Merge the intent PR (#N) now?"** — asked **last**, once every issue URL has been reported, so
     an unapproved PR never hides behind a successful dispatch. New `task-state.sh merge-intent-pr
     <intent.md> [--pr <ref>] [--yes]`: dry-run by default (prints title, state, approval source and
     the exact `gh pr merge` it would run), re-checks the approval itself, is idempotent on an
     already-merged PR, and merges with `gh pr merge <ref> --merge` only. It never passes
     `--admin`, never deletes the branch, and never squash/rebase/auto-merges.

### Changed

- **An approving review is read per reviewer, newest review wins.** `check-intent-approved` and
  `merge-intent-pr` share one reader: each reviewer's **latest** review decides, at least one must be
  `APPROVED`, and no reviewer may have `CHANGES_REQUESTED` as their latest. `DISMISSED` and
  `COMMENTED` are neutral, and a review superseded by a later one is ignored. Previously any single
  historical `APPROVED` satisfied the gate, so a review that was later retracted still let dispatch
  and a merge through. Exit codes are unchanged: 0 approved, 1 not approved, 3 `gh` missing or
  unauthenticated (the file's own `status:` is the fallback).
- **The two new steps write nothing.** Dispatch still writes exactly two files, and only when
  justified: the existing intent file's `status: approved` + `## Review`, and the
  `<repo-root>/.agents/tracker.md` cache. No task directory, no `0_intent.md`, no `1_spec.md`, no
  `2_plan.md`, no `index.md` row — a task is the tracker issue, and neither the found issues nor the
  merge outcome is recorded anywhere.
- **The advisory open-work check never blocks a dispatch the developer wants.** `gh` missing or
  unauthenticated, or a platform the harness recognizes but does not implement, exits **3**: the
  command says "I could not check whether this is already open", names the reason, records the skip
  in its report, and continues — the same fail-open contract issue creation has always had. A guard
  failure (exit 1) still stops, and a usage error (exit 2, e.g. a missing `--search`) is a call bug
  that must be fixed and retried rather than read as a board state.

### Fixed

- **A quoted `pr:` value is no longer refused.** `pr: "42"`, `pr: '42'` and a quoted PR URL are
  valid hand-written YAML and are what most people write; the value reached `gh` with its quotes
  attached, so `merge-intent-pr` failed on a ref that was perfectly good. One layer of surrounding
  quotes is now stripped before the ref is normalized.
- **An unexpanded `{{PR_URL}}`-style placeholder reads as "no PR", not as a broken ref.** The
  template ships `pr: <optional PR URL or #number>`, and a field filled in by hand is just as easily
  left as `{{PR_URL}}`. Both now take the same path as an absent field — "no PR to merge, pass
  `--pr <ref>`" — instead of "fix the field".
- **`merge-intent-pr` reads the PR's state before its reviews.** An already-merged PR is a no-op
  (exit 0) whatever its reviews say, so re-running the command on a merged PR no longer fails with
  "carries no approving review". The approval still gates the only write, and that write is reachable
  only from an `OPEN` PR.
- **`--list-open` without `--search` is a usage error (exit 2), not a guard failure.** It is a
  mistake in the call, not a fact about the board, and the skill now says so instead of treating it
  as a stop condition.

### Upgrade Notes

- No new file is added to the bundle or to any adapter, so there is **no manifest row to add** — the
  normal `/monorepo-harness-update` sync installs the changed scripts, skill, governance doc and the
  three dispatch entry points, and `--refresh` places the `tracker` subagent note. See
  `changelogs/version-0.4.0-rc.6.md` for the new commands to try and one manual follow-up: an intent
  whose approval was later retracted now fails the gate, by design.

## [0.4.0-rc.5] - 2026-09-28

### Fixed

- **`/monorepo-harness-intent-dispatch` no longer writes intent, spec or plan files.** Found on the
  first real run of `0.4.0-rc.4`: the command created `0_intent.md`, `1_spec.md` and `2_plan.md` per
  phase, plus an `index.md` row. Those files belong to `/monorepo-harness-spec` and
  `/monorepo-harness-plan`, which scope one task at a time — dispatch was running N stage chains in a
  single turn, on N tasks, behind one "Start these N phases?" gate. A task is now the tracker issue.
  - **Dispatch writes exactly two files, and only when justified:** the **existing** intent file's
    `status: approved` + `## Review` section, and the `<repo-root>/.agents/tracker.md` cache added in
    rc.4. It never creates an intent file, a task directory, `0_intent.md`, `1_spec.md`, `2_plan.md`
    or an `index.md` row.
  - Each phase's scope, workspace, verification command and intent link live in its **issue body**,
    which is where a phase is tracked from now on. The hand-off is
    `/monorepo-harness-spec <intent.md>` — the unchanged start of the chain — instead of
    `/monorepo-harness-build <2_plan.md>`, a file dispatch no longer creates.
  - `0_intent.md` keeps **exactly one writer**: `write-intent-ref.sh`, called by
    `/monorepo-harness-spec`. Two writers could let the stub disagree with itself about `source:`, and
    an `index.md` row for a directory nobody scoped indexes work that does not exist.
  - `tracker-issue.sh --plan` is now **optional** (its `tracker:` stays a resolution source when a
    caller has a plan). The `tracker` subagent no longer reads a plan or records a URL in one.
  - ADR `0001-dispatch_creates_issues_not_plan_artifacts.md` supersedes the 2026-09-25 task's ADR 0001
    — "one task directory per phase" is reversed, so the hand-off carries the reversal rather than
    quietly contradicting it.
  - `core/governance/intents/AGENTS.md` names the stub's single writer instead of describing the stub
    as if several commands might write it.

### Added

- **The approval gate now reads the intent's PR before the intent file.** `task-state.sh
  check-intent-approved <intent.md> [--pr <pr-ref>]`. An intent approved on its PR while the local
  file still said `pending` — the ordinary state right after a reviewer clicks "Approve" — was
  refused, and the developer was told the intent was not approved while the approval sat on the PR.
  The PR is the decision; the file is the record of it, and the command writes the record from the
  PR's reviewer and date rather than asking twice.
  - The state is verified in the script, not only in `gh`'s jq filter: a `CHANGES_REQUESTED` or
    comment-only PR is not an approval. Unrecognised output falls through to the file, the safe
    direction.
  - Missing or unauthenticated `gh`, or a non-GitHub `pr:`, warns and falls through to the file — a
    warning, not a failure, since the file is a complete source on its own.
  - A failure now names **both** sources it checked. The old message named only the file, and that is
    the message that misled the first run.
  - `--pr` is accepted only by this subcommand, and an unrecognized option exits 2 rather than being
    ignored — a typo in a gate argument must never read as "no PR, check the file only" and pass.

### Upgrade Notes

- No new installed file, so no manifest row and no command beyond the normal update sync.
- **Behavior change, no action required:** if you ran `/monorepo-harness-intent-dispatch` on
  `0.4.0-rc.4`, the task directories it wrote are still valid tasks and still work with
  `/monorepo-harness-plan` and `/monorepo-harness-build`. Leave them. Re-running dispatch now opens
  issues instead of rewriting those files, so a re-run cannot overwrite a spec or plan you revised.
- A phase's scope is re-derived from its issue plus the intent when you scope it with
  `/monorepo-harness-spec`, so read the issue body first — the phase's written spec now lives there
  rather than on disk.

## [0.4.0-rc.4] - 2026-09-28

### Added

- **Ship a repo-root knowledge base (Karpathy "LLM Wiki" pattern) compiled incrementally at task
  end.** Agents answer questions against a compiled, interlinked markdown layer (`knowledge/` at the
  consumer repo root) instead of re-deriving from per-workspace artifact trees on every query. Built
  on the existing artifact machinery rather than new tooling — markdown + grep only, no vector DB.
  - `core/knowledge-template/` — the seeded skeleton: `index.md` (master catalog), `log.md`
    (append-only ingest history), `overview.md`, `schema.md` (the KB constitution: page types,
    naming, link/citation rules), and `sources/`, `concepts/`, `modules/`, `decision-records/`,
    `verified-facts/` subdirectories. Raw task artifacts stay immutable; `knowledge/` is
    regenerable compiled output.
  - `core/skills/knowledge-base/SKILL.md` — the Karpathy "schema" as a skill: the task-end ingest
    workflow, the query fast-path (read `knowledge/index.md` + linked pages first), the periodic lint
    workflow (contradiction / stale / orphan detection, two-position documents on conflict), and the
    never-do floor.
  - `core/scripts/kb-ingest.sh` — the mechanical task-end ingest (structure, catalog rows, log entry,
    ADR copies, page skeletons); the agent authors the page prose per the skill and `knowledge/schema.md`.
    `core/scripts/scaffold-knowledge.sh` seeds `knowledge/` idempotently, never overwriting consumer
    content; `install-harness.sh` runs it in step 4c.
  - `core/scripts/task-state.sh check-kb <task_dir>` — read-only coverage gate (source synopsis,
    one decision-record per raw ADR, verified-facts when `4_verify.md` exists) plus a
    `core/scripts/memory-gate.sh` scope extension so a task that wrote `3_memory.md` but left
    `knowledge/` untouched fails the same universal gate as memory/verify.
  - Adapter `-build` stubs gain step 5 (run `kb-ingest.sh` + verify `check-kb` in the same commit);
    `core/root-AGENTS.md` gains Agent Lifecycle 9 (Query Knowledge First), a pre-plan checklist hit,
    a Reference Map row, and an Additional Context bullet.
  - New manifest rows (`core/knowledge-template`, `core/skills/knowledge-base/SKILL.md`), a
    `.claude/skills/` + `.agents/skills/` symlink and `opencode.jsonc` `instructions` entry per
    adapter, `audit-install.sh` Check 5c, `harness-update/SKILL.md` step 9.5 remediation, and
    `PORTABILITY.md` capability + semantic-difference rows.
- **The tracker a project uses is now inferred, confirmed, and cached (issue #9).**
  `tracker-issue.sh --infer` reads the **consumer project's** own `origin` remote and prints
  `platform= target= source= origin=` — `github.com` → `github`, `bitbucket.org` → `bitbucket`,
  `gitlab.com` → `gitlab`, anything else → `unknown`. Read-only, always exit 0, so an inference is a
  suggestion with a visible source rather than a silent decision. The new confirmed answer is
  remembered in `<repo-root>/.agents/tracker.md` (`tracker:`, `target:`, `confirmed:`) — a
  consumer-owned file, read with the awk frontmatter helper the script already had, so no `jq`, no
  manifest row, and no `.gitignore` work. Resolution order is now `--tracker` → project cache → the
  phase plan's `tracker:` (an audit record, not the cache). `jira` and `linear` became recognized
  platforms that end at exit 3 with paste-ready text and a handoff hint; any other platform is
  refused with a message that tells the caller to ask the developer, never silently redirected to a
  GitHub repository.

### Fixed

- **The harness repo is never an issue target (issue #9).** `/monorepo-harness-intent-dispatch` in a
  consumer project on v0.4.0-rc.3 was asked an open "which GitHub repo?" question, and the agent
  offered `atayahmet/monorepo-agents-harness` **first** — it is the most salient string in the
  harness's own context. Picking it would have filed a consumer app's tasks in the template's
  tracker. `tracker-issue.sh` now refuses a target matching the harness upstream on every path
  (`--repo`, the cached `target:`, the `origin` default) and in `--dry-run` as well as `--create`, so
  the refusal holds on every agent and every future caller rather than relying on an instruction; the
  skill, the `tracker` subagent and the three dispatch entry points all state it. The refusal matches
  the bundle's own `origin` too, so a fork or re-hosted bundle is covered.

### Changed

- `/monorepo-harness-intent-dispatch` asks "is `<inferred>` right, or do you file it somewhere else?"
  before any issue exists, and writes nothing to `.agents/tracker.md` before the developer answers in
  the current turn. A later run reuses the cached answer without asking; `--tracker` still overrides
  it deliberately.
- `PORTABILITY.md` gains a semantic-difference note: tracker resolution has no per-agent variance —
  inference, confirmation, cache and refusal are script- and skill-driven, so only the delivery of
  the script call differs (claude-code subagent, opencode/codex inline).

### Removed

### Upgrade Notes

- **Backwards-compatible, no manifest change, no prompt.** No file was added to the bundle or to any
  adapter, so there is no `core/install-manifest.txt` / `manifest.txt` row and no
  `changelogs/version-0.4.0-rc.4.md` prompt — re-run the normal `install-harness.sh --sync-only` +
  `install-adapter.sh <agent> --refresh` (or a fresh install) and the update flow carries it.
  - An existing phase plan with `tracker: github` still resolves exactly as before: the plan is now
    the last fallback instead of the first, so nothing that used to work stops working.
  - A consumer whose confirmed tracker is `jira` or `linear` now gets paste-ready text and exit 3
    (record "no issue yet", keep the task directories) where the script used to exit 1 and stop. Any
    other platform still exits 1, with a message that says to ask the developer.
  - Knowledge base (this release, from `[Unreleased]`): existing consumers keep their `.agents/`
    working state untouched; a `knowledge/` dir is seeded only on a fresh full install or by running
    `core/scripts/scaffold-knowledge.sh`. Research-only / `N/A` tasks (no `3_memory.md`) are skipped
    by ingest and pass the gate. Tasks that wrote `3_memory.md` after this upgrade must land a
    corresponding `knowledge/` update in the same commit (`check-kb`/memory-gate enforces it); the
    `changelogs/version-0.4.0-rc.0.md` prompt gives the one command for existing installs.

## [0.4.0-rc.3] - 2026-09-25

### Added

- **`/monorepo-harness-intent-dispatch <intent.md>` — an approved intent now becomes real work**
  (issue #5). `/monorepo-harness-intent` captures a problem and `/monorepo-harness-intent review`
  approves it, and then the harness went quiet: choosing the workspaces, splitting the intent into
  reviewable phases and recording the work in the team's tracker were all left to hand. The new
  command does that part — and only that part.
  - `core/skills/intent-workflow/SKILL.md` gains a third phase, `## Workflow — Dispatch`, next to
    Capture and Review. It verifies the approval first (`task-state.sh check-intent-approved`; a
    `pending` intent writes nothing), pushes the approval commit when the intent names a `pr:`
    field, confirms the workspace scope, proposes 3-5 phases (a phase is worth its own review), and
    records an explicit **"Start these N phases?"** sign-off before anything is written.
  - One task directory **and** one tracker issue **per phase**:
    `task_<YYYY_MM_DD>_<phase_slug>/` with `0_intent.md` (reference stub, never a copy), `1_spec.md`
    and `2_plan.md`, plus an index row, and a `## Tracker` section holding the issue URL. Phases stay
    independently buildable and independently closable, so a four-phase intent does not sit behind
    one closing gate.
  - `core/scripts/tracker-issue.sh` — creates the issue through tooling the developer already has
    authenticated. `--dry-run` is the default and creates nothing; `--create` prints the URL. Only
    GitHub Issues (the `gh` CLI) is implemented in this version, and the script is platform-dispatched
    so Linear/Jira is a new branch, not a rewrite. When `gh` is missing or unauthenticated it exits
    **3** with paste-ready issue text — the task directories still stand and the command reports "no
    issue yet", so it never claims an issue that does not exist.
  - `core/governance/intents/AGENTS.md` documents an optional `pr:` frontmatter field. An intent
    without one is complete and valid.
  - Three thin entry points — `.claude/commands/monorepo-harness-intent-dispatch.md` (claude-code),
    `.opencode/commands/monorepo-harness-intent-dispatch.md` (opencode),
    `.agents/skills/monorepo-harness-intent-dispatch/SKILL.md` (codex) — plus a claude-code
    `.claude/agents/tracker.md` subagent that creates the issues and returns the URLs. opencode and
    codex run the same script inline (no subagent primitive), so the capability is identical
    everywhere; see `PORTABILITY.md`.
  - Manifest rows: one `copy` per adapter entry point and one for the subagent. The resolved tracker
    is recorded as `tracker:` in each phase's `2_plan.md`, so **no config file is installed and
    nothing needs a `.gitignore` entry** — the plan is the cache, and `--tracker` overrides it.

### Changed

- `core/skills/intent-workflow/SKILL.md` — title, frontmatter `description`, the
  "Connection to `agent-workflow`" note (Dispatch is the one phase that writes task directories) and
  the edge-case list now cover dispatch. Capture and Review behavior is unchanged.
- Docs updated to match: `PORTABILITY.md` (capability row + two semantic-difference notes),
  `adapters/AGENTS.md` Rule 7 whitelist, `README.md` (feature bullet + all three adapter rows),
  `INSTALL.md` §6, and every adapter `README.md` / `INSTALL.md`.

### Removed

### Upgrade Notes

- **Backwards-compatible, and everything arrives by itself.** All additions are manifest rows, so the
  normal update path delivers them: the bundle sync brings the extended skill, the new script and the
  `pr:` documentation; `install-adapter.sh <agent> --refresh` places the entry point (and the
  `tracker` subagent on claude-code). **No command to run and no manual follow-up** — see
  `changelogs/version-0.4.0-rc.3.md`.
- **opencode needs no `opencode.jsonc` edit.** The command reaches
  `core/skills/intent-workflow/SKILL.md` by path, so the new Dispatch phase needs no new
  `instructions` entry. `audit-install.sh` Check 6 stays clean — a new core skill would have left
  that gap open on every upgrade.
- **Nothing implements a phase.** After `-intent-dispatch` the work still starts with
  `/monorepo-harness-build <2_plan.md>`, one phase at a time. A plan is never approved and executed
  in the same turn.
- **No credential is ever installed, asked for, or stored.** GitHub issues go through the `gh` CLI
  the developer already authenticated; Linear and Jira need an MCP server or API token that the
  **developer** installs. The harness ships neither, and the installer does not require `gh`.

## [0.4.0-rc.2] - 2026-09-25

### Added

- **`/monorepo-harness-update` is back on every adapter, with the README update prompt embedded**
  (issue #4). `0.1.0-rc.4` removed the per-adapter update entry points and left the README
  paste-in prompt as the only way in, so every update meant finding and copying that prompt by
  hand, out of a README copy that may be stale. The workflow never left the bundle — only the
  entry point did. It is now a command again, and the prompt ships with the harness.
  - `core/prompts/harness-update.md` — the paste-in prompt, now the single copy of the procedure
    in this repo. Versionless by design: the version engine is `harness-update.sh`, the file list
    is `core/install-manifest.txt`, the workflow is `harness-update/SKILL.md`.
  - `adapters/claude-code/.claude/commands/monorepo-harness-update.md`,
    `adapters/opencode/.opencode/commands/monorepo-harness-update.md`,
    `adapters/codex/.agents/skills/monorepo-harness-update/SKILL.md` — thin entry points that apply
    that prompt verbatim and then defer to the shared skill. Bodies are byte-identical; only the
    frontmatter differs per agent. The command never restates the workflow, so it cannot drift
    from the skill.
  - Manifest rows: one `copy` row per adapter command, plus an explicit row for the prompt file
    (`audit-install.sh` Check 2 now reports a missing command as a gap).
  - Docs: `PORTABILITY.md` (capability row, Codex note, adapter-authoring note), `README.md`
    (feature bullet, Scenario 5, the update section, the adapter table), `INSTALL.md` §7, and every
    adapter `README.md` / `INSTALL.md`. The README's 25-line update block is replaced by a link to
    `core/prompts/harness-update.md` — one copy of the prompt, still clickable on GitHub and
    resolvable inside an installed bundle.

### Changed

- `core/skills/harness-update/SKILL.md` states that the entry point exists again and where the
  prompt lives. Its workflow is unchanged.

### Removed

### Upgrade Notes

- **Backwards-compatible, and the new command arrives by itself.** All three additions are
  manifest rows, so the normal update path delivers them: step 7 syncs the bundle (including
  `core/prompts/harness-update.md`), step 7.5 runs `install-adapter.sh <agent> --refresh` and places
  the command. **No command to run and no manual follow-up** — see `changelogs/version-0.4.0-rc.2.md`.
- A project that still carries the pre-`0.1.0-rc.4` `/monorepo-harness:update` file in
  `.claude/commands/monorepo-harness/` keeps it: `--refresh` never deletes. It is harmless (it
  still points at the same skill) and `audit-install.sh` will report it as an extra file, exactly
  as `0.1.0-rc.4` documented. Remove it whenever you like; nothing depends on it.
- claude-code gets the flat `/monorepo-harness-update` name, matching its eight sibling commands
  and the same name on opencode and codex. The namespaced pre-rc.4 name is not resurrected.

## [0.4.0-rc.1] - 2026-09-24

### Added

- **A shared "simple English" writing standard applies to every generated file and every developer
  message.** The harness writes specs, plans, memory files, verify files, intents, ADRs,
  changesets, knowledge-base pages, review reports, and commit messages, and it talks to the
  developer during each step — all of that text must now be simple English (issue #1).
  - `core/governance/rules/simple-english.md` — the shared rule: short sentences, one idea per
    sentence, common words, active voice, lists over long paragraphs; technical terms (file names,
    commands, paths) stay exact. Written in simple English itself, with bad vs good examples —
    a spec paragraph and a developer question.
  - All 11 content-writing skills (agent-workflow, adr-workflow, intent-workflow,
    changeset-workflow, knowledge-base, pr-review, self-improvement-workflow, agents-md-merge,
    harness-update, ci-integration, monorepo) carry one standard reference line that resolves to the
    rule via the bundle-relative path `../../governance/rules/simple-english.md` — correct both in
    this source tree and in an installed `.agents/monorepo-agents-harness/core/` copy.
  - `core/root-AGENTS.md` gains Critical Gotcha 6 and a Reference Map row, so every consumer's
    generated `AGENTS.md` tells its agents to follow the rule.
  - Explicit `core/install-manifest.txt` row (the rule also ships via the `core` directory row).

### Changed

- No script, gate, adapter, or manifest-verb behavior changed; the rule is a writing standard that
  agents apply when generating content and messages.

### Removed

### Upgrade Notes

- **Backwards-compatible.** The rule auto-installs with the regular bundle sync (the `core` row);
  no command needs to run. Each consumer's `AGENTS.md` picks up Gotcha 6 and the Reference Map row
  through the normal step-9 reconciliation (`core/skills/agents-md-merge/SKILL.md`).

## [0.3.0-rc.1] - 2026-09-22

### Added

- **A starter project rule for local `AGENTS.md` upkeep ships with the harness.** The installer now
  seeds `.agents/rules/local-agents-md.md` into every consumer project: when an agent works in any
  directory inside a workspace — the workspace root (`apps/<name>/`, `packages/<name>/`) **or a
  nested subdirectory at any depth** (`apps/<name>/src/components/**`, `packages/<name>/lib/**`) —
  whose current state needs agent instructions, it MUST create an `AGENTS.md` there or update the
  existing one.
  - `core/project-rules-template/local-agents-md.md` — the seed rule (new `core/project-rules-template/`
    directory), shipped to the bundle as an **explicit `core/install-manifest.txt` row** (not just
    inside the `core` directory row) so the consumer-facing seed artifact is a first-class, audited
    install row.
  - `core/scripts/scaffold-project-agents.sh` — seeds `.agents/rules/` from the template, never
    overwrites existing files, and registers each newly created rule in `.agents/.harness-map.json`
    (via `update-harness-map.sh`, best-effort when `jq` is available) so `/monorepo-self-improve`
    inventories it instead of proposing a duplicate.
  - `core/scripts/install-harness.sh` runs the seed as step 4b of a full install; `--sync-only`
    (updates) skips it by design — the update path reaches it through the release prompt below.
  - `core/scripts/audit-install.sh` gains Check 5b: a project-rules seed missing from
    `.agents/rules/` is reported as a gap (presence only — a rule file the project edited is never
    compared).

### Changed

- **`core/root-AGENTS.md` Reference Map now ships one rule.** The "template ships none" wording is
  replaced by the seed explanation, and a `.agents/rules/local-agents-md.md` row is added so agents
  discover the rule; the `.agents/rules/*.md` "Additional Context Locations" bullet now notes the
  seeded starter.

### Removed

### Upgrade Notes

- **Backwards-compatible.** Existing consumers keep all their `.agents/rules/`; the seed step only
  creates files that do not exist yet. The reference-map row lands via the normal `AGENTS.md`
  reconciliation (step 9), which runs after the seed, so it never points at a missing file.
- **Commands to run (updates):** seed the new starter rule with
  `bash .agents/monorepo-agents-harness/core/scripts/scaffold-project-agents.sh` (see
  `changelogs/version-0.3.0-rc.1.md`). Fresh installs do this automatically.

## [0.3.0-rc.0] - 2026-09-22

### Added

- **`/monorepo-harness-changeset <2_plan.md>`** — drafts a changesets-compatible release entry
  (`.changeset/monorepo-harness-<YYYYMMDD>-<slug>-r<N>.md`) for a finished task, derived from its
  artifacts, without adding `@changesets/cli` as a dependency:
  - `core/scripts/draft-changeset.sh` — deterministic generator + guards: `task-state.sh check-plan`
    gate, `.changeset/` preflight (absent → refuse, point at `changeset init`), explicit
    `--package`/`--bump` pairs (packages and bump levels are user-confirmed policy, never
    machine-decided), a duplicate guard keyed on the deterministic filename, and a summary
    auto-derived from `3_memory.md` → `1_spec.md` → `2_plan.md` with `--summary` override.
  - `core/skills/changeset-workflow/SKILL.md` (78 lines) — the proposal + consent workflow, the bump
    heuristic table, the multi-changeset/revision flow, and the hard never-do list (never run
    `changeset`, never create `config.json`, never pick bumps unilaterally). A changeset carries bump
    types only — the `v1.0.0-alpha.0 → v1.0.0-alpha.1` sequence stays the job of the consumer's own
    `changeset pre` + `changeset version`.
  - Adapter entry points on all three adapters (`adapters/{claude-code,opencode,codex}`) gated on
    `check-plan` and user confirmation; skill symlinked for claude-code/codex, `instructions` entry
    added to the opencode template.
- **One plan → many changesets.** Each merged revision of a long-lived plan gets its own changeset via
  `--revision N`, so a pre-release train (`alpha.0`, `alpha.1`, …) accumulates pending entries the
  way stock changesets does.

### Changed

- `adapters/AGENTS.md` Rule 7 whitelist now includes the changeset-draft trigger; `PORTABILITY.md`
  gains a capability-matrix row and a semantic-difference bullet (bumps are user policy identically
  on every agent; file production is script-driven and agent-neutral).

### Removed

### Upgrade Notes

- **Changeset feature auto-installs with the normal sync** — the script and skill ship under the
  existing `core` manifest row; the three adapter stubs are new `copy`/`link` rows that reach the
  project when the installed adapters are refreshed.
- **Commands to run:** re-apply every installed adapter so the new `/monorepo-harness-changeset`
  entry points reach the project. From upgrade runs this is the usual
  `bash .agents/monorepo-agents-harness/core/scripts/install-adapter.sh <agent> --refresh` (see
  `changelogs/version-0.3.0-rc.0.md`).
- **Manual follow-up (opencode only):** the new shared `changeset-workflow` skill reaches opencode
  only through your root `opencode.jsonc` `instructions` array (a `merge` row that is never
  rewritten). Add `.agents/monorepo-agents-harness/core/skills/changeset-workflow/SKILL.md` to it, or
  follow the `opencode.jsonc.harness-proposed` the installer leaves; `audit-install.sh` reports the
  missing entry until you do.

## [0.2.0-rc.7] - 2026-09-21

### Added

- **`core/skills/agent-workflow/templates/`** — the five fill-in artifact templates (`0_intent_ref.md`,
  `1_spec.md`, `2_plan.md`, `3_memory.md`, `4_verify.md`) now live as separate files next to the
  skill, byte-identical to the blocks they replace. Agents read the phase's template file, then
  create the artifact in the task directory; the skill points to each template inline.

### Changed

- **`core/skills/agent-workflow/SKILL.md` reduced from 371 to 240 lines with no capability loss.** The
  inline template blocks were extracted to `templates/` (one pointer line each), the two ASCII
  directory diagrams were consolidated into one tree plus a packages note, and the duplicated
  research-only explanation was collapsed to the Stage-commands paragraph with the edge case pointing
  back. All normative prose is preserved: phase timing, stage-command gates, stop-and-wait,
  Build-scope confinement, edge cases, slug/naming rules, and every script/skill cross-reference.
- `adapters/AGENTS.md` wording corrected: "Templates come from the agent-workflow skill"
  (`SKILL.md` + `templates/`), not "from the SKILL.md" alone (repo-internal guidance, not installed).

### Removed

### Upgrade Notes

- **No manual follow-up required.** The `core` manifest row already installs the whole skill
  directory, and adapter skills are linked wholesale, so `templates/` reaches every consumer with
  the normal harness-update sync — no commands, no re-install, no artifact/gate change. The
  extracted templates are byte-identical to the previous inline blocks, so plan/spec/memory/verify
  artifacts produced before and after this release are interchangeable.

## [0.2.0-rc.6] - 2026-09-21

### Added

### Changed

- **`-build` implementation is now strictly confined to the approved spec/plan scope.** In consumer
  monorepos the implementation started by `/monorepo-harness-build <2_plan.md>` has sometimes built
  applications that are not named in the task's `1_spec.md` and `2_plan.md` (unplanned workspaces/
  apps scaffolded on the agent's own initiative). The guardrail "change only what the task requires"
  was too vague. The harness now enforces a hard boundary at every instruction layer:
  - **`core/skills/agent-workflow/SKILL.md`** gains a **Build scope** rule before Phase 3: the
    implementation touches only what `1_spec.md`'s `## Scope` / `## Acceptance criteria` and
    `2_plan.md`'s `## Affected files / modules` declare; creating any file, app, package, or workspace
    the plan does not name is forbidden; and when scope must genuinely grow the agent must **stop
    implementing**, report, and extend spec+plan (append a `revisions:` log entry) on approval before
    resuming. The stage-command table's `/monorepo-harness-build` row now names the confinement.
  - **`core/root-AGENTS.md`** gains Critical Gotcha 5 — the same boundary, installed into every
    consumer project's root `AGENTS.md`.
  - **All three `/monorepo-harness-build` entry points** (claude-code command, opencode command,
    codex skill) tighten step 3 with byte-identical text pointing at the two artifact sections and
    forbidding unlisted apps/packages/files.

### Removed

### Upgrade Notes

- **Reconcile your root `AGENTS.md`.** This release adds Critical Gotcha 5 to `core/root-AGENTS.md`.
  The normal harness-update flow proposes the merge via `agents-md-merge`; accept it so consumer
  agents enforce build-scope confinement.
- **Re-install installed adapters.** The updated `/monorepo-harness-build` entry point files must
  reach your project. The harness-update workflow does this in step 7.5; otherwise run
  `install-adapter.sh <agent> --refresh` once per installed adapter (`claude-code`, `opencode`,
  `codex`).
- **No artifact or gate migration.** This is an instruction change only — task directories, the
  artifact format, and the `task-state.sh` gates are unchanged.

## [0.2.0-rc.5] - 2026-09-21

### Added

### Changed

- **`core/skills/agent-workflow/SKILL.md`** docs tightened: the frontmatter `description` now counts
  the actual four artifacts (spec, plan, memory, verify), names all driving triggers (stage commands
  plus the plan-mode approval signal), and drops the project-specific example workspace names; the
  `<workspace>` definition now derives from the project's `apps/*` / `packages/*` directories instead
  of a hardcoded list; and the research-only path (hand-written plan, no spec/memory/verify) is
  documented consistently with the `-plan`/`-build` gates.

### Removed

### Upgrade Notes

- **No manual follow-up required.** Docs-only change to an installed skill; it ships with the normal
  harness-update sync and does not change any artifact format or gate behavior.

## [0.2.0-rc.4] - 2026-09-11

### Added

### Changed

- **`core/skills/intent-workflow/SKILL.md`** now authorizes the agent to add an optional `## Visual summary` section with a mermaid diagram to generated intent files when it would clarify the content; diagrams must not be added if they feel forced.
- **`core/governance/intents/AGENTS.md`** intent template now includes the optional `## Visual summary` section for mermaid diagrams.

### Removed

### Upgrade Notes

- **No manual follow-up required.** The intent template and skill instruction change ships with the normal harness-update path; intent files created before this release are unaffected.

## [0.2.0-rc.3] - 2026-09-03

### Added

- **`.agents/.harness-map.json` component map.** The self-improvement workflow (`/monorepo-self-improve`)
  now records every project-owned rule, skill, agent, and command it creates in a machine-readable
  JSON inventory at the consuming project's root.
- **`core/scripts/update-harness-map.sh`.** A deterministic helper that adds or updates map entries,
  prevents duplicates via the `name` + `type` unique key, preserves `createdAt`, and refreshes
  `updatedAt` / `lastUpdated`.

### Changed

- **`core/skills/self-improvement-workflow/SKILL.md`** now reads `.agents/.harness-map.json` before
  proposing components, marks each proposal as `new` or `update`, and invokes
  `update-harness-map.sh` after writing files.
- **`core/governance/rules/rule-template.md`** reminds agents to register each rule in the map.
- **`core/root-AGENTS.md`** documents `.agents/.harness-map.json` in the Reference Map and Additional
  Context.
- **Adapter `/monorepo-self-improve` entry points** (claude-code, codex, opencode) instruct the agent
  to read the map first and update it on apply.

### Removed

### Upgrade Notes

- **Reconcile your root `AGENTS.md`.** This release adds a Reference Map row for
  `.agents/.harness-map.json`. The normal harness-update flow will propose the merge via
  `agents-md-merge`; accept it so future agents know about the component map.
- **Re-install installed adapters.** The updated `/monorepo-self-improve` command files must reach
  your project. The harness-update workflow does this in step 7.5; otherwise run
  `install-adapter.sh <agent> --refresh` once per installed adapter (`claude-code`, `opencode`,
  `codex`).
- **No manual migration of existing components.** Components created before this release are not
  backfilled; only newly created components are recorded.

## [0.2.0-rc.2] - 2026-09-03

Closes the two loose ends left by the `/monorepo-self-improve` release: an output directory that was
referenced but never defined, and an opencode wiring step that existed only as prose in a release
prompt.

### Added

- **`.agents/self-improve-proposals/<YYYY_MM_DD>-<slug>.md` is now a defined output.**
  `core/skills/self-improvement-workflow/SKILL.md` previously mentioned this path once, in the "no"
  branch of its approval gate, with no naming convention, no stated contents, and no entry in root
  `AGENTS.md` — so an agent that saved a report there produced a file nothing else in the harness
  knew how to find. It is now Outputs §4: one file per run, the exact proposal report plus a
  `Status:` line (`declined` / `deferred` / `partially applied — <what landed>`), never overwritten,
  offered rather than written unasked. It is listed in `core/root-AGENTS.md` under Additional
  Context Locations with an instruction to read it *before* re-running the workflow, so a pattern
  the user already declined is cited instead of re-proposed.
- **`audit-install.sh` Check 6 — opencode `instructions` coverage.** opencode installs no skill
  symlinks: shared `SKILL.md` files reach the agent only through the `instructions` array of the
  project's own root `opencode.jsonc`, which is a `merge` manifest row — written once, never
  overwritten. A release that adds a shared skill therefore *cannot* wire it in, and Check 2 could
  not see the gap because merge rows are existence-checked only. The audit now compares the
  project's `opencode.jsonc` (or `opencode.json`) against the adapter's and reports each missing
  `core/skills/*/SKILL.md` entry by exact path. Matching is on the `core/skills/<name>/SKILL.md`
  suffix, so a bundle vendored under a non-default prefix is not a false positive.

### Changed

- **`core/skills/self-improvement-workflow/SKILL.md`** — Scope gains a `Record` step; the approval
  gate's `no` branch and the declined-`AGENTS.md`-merge edge case both point at the now-defined
  report convention (the latter with `Status: partially applied` and the `AGENTS.md.harness-proposed`
  path as the named follow-up); the "no writes without approval" constraint explicitly covers the
  report itself.
- **All three `/monorepo-self-improve` entry points** (claude-code command, codex skill, opencode
  command) gain an identical step 7 for the declined/deferred report, preserving byte-for-byte
  parity below the frontmatter.
- **`core/skills/harness-update/SKILL.md`** — step 7.5 now names the opencode `instructions` case as
  something `--refresh` structurally cannot cover and defers to the audit rather than to guesswork;
  step 9.5 gains an "opencode `instructions` gap" resolution branch (show the line, ask, add only on
  approval, carry to step 11 follow-ups if declined).
- **`adapters/opencode/manifest.txt`, `INSTALL.md`, `README.md`** — the "no skill symlinks" note now
  states the consequence (new shared skills are a manual merge on every upgrade) and names Check 6
  as what keeps it honest, instead of leaving it to a per-release prompt.
- **Docs** — `README.md`, `INSTALL.md`, `PORTABILITY.md` and the three adapter READMEs describe where
  declined proposals land; `PORTABILITY.md`'s opencode column records the `instructions` merge-row
  constraint.
- **`.gitignore`** (this repo's own, dogfooding) ignores `/.agents/self-improve-proposals/`, next to
  `/.agents/artifacts/`. The harness itself still ships no `.gitignore` — whether to track these
  reports stays the consuming monorepo's decision, and the skill says so.

### Upgrade Notes

- **No changelog prompt ships for this release, by design.** The one manual follow-up it touches —
  the opencode `instructions` entry — is exactly what Check 6 now audits and what
  `harness-update` step 9.5 now resolves. Shipping it as prose again would undo the fix
  (`changelogs/README.md`: prompts never carry what the workflow already does).
- **opencode projects may see a new gap on the next audit.** If you upgraded to `0.2.0-rc.0`/`-rc.1`
  and never merged `opencode.jsonc.harness-proposed`, `audit-install.sh` will now report the missing
  `core/skills/self-improvement-workflow/SKILL.md` entry. That is the previously-silent gap becoming
  visible, not a regression: add the line to your `instructions` array. The slash command worked
  without it; the skill was never auto-loaded.
- **Root `AGENTS.md` gains one Additional Context Locations bullet.** The normal step 9
  `agents-md-merge` reconciliation proposes it — no manual diffing.

## [0.2.0-rc.1] - 2026-09-03

### Added

- **`core/scripts/write-intent-ref.sh`** — a helper script that mechanically creates the
  `0_intent.md` reference stub for intent-seeded tasks. It validates that the referenced intent is
  `status: approved`, computes the relative `source:` path from the task directory, and writes the
  stub with `phase: intent-ref`. This removes the agent's discretion at the exact step where the
  intent file was sometimes copied in full.

### Changed

- **`task-state.sh check-chain` now rejects non-stub `0_intent.md` files.** When a task directory
  contains `0_intent.md`, its frontmatter `phase:` must be `intent-ref`; otherwise the chain check
  fails with a clear error. The existing `source:` resolution and original-intent approval checks
  remain in place.
- **All three `/monorepo-harness-spec` adapter commands** now instruct the agent to call
  `write-intent-ref.sh` instead of asking it to hand-write the reference stub.
- **`core/skills/agent-workflow/SKILL.md`** documents the helper script in the reference-stub
  section.

### Removed

### Upgrade Notes

- **Refresh installed adapters.** The updated `/monorepo-harness-spec` command files must reach your
  project. The harness-update workflow does this in step 7.5; otherwise run
  `install-adapter.sh <agent> --refresh` once per installed adapter (`claude-code`, `opencode`,
  `codex`).
- **Copied `0_intent.md` files need conversion.** Any existing task directory that contains a full
  copy of an intent instead of the `phase: intent-ref` stub will now fail `check-chain`. Convert
  such files with
  `write-intent-ref.sh <task_dir> <workspace>/.agents/intents/intent_<YYYY_MM_DD>_<slug>.md`.

## [0.1.0-rc.10] - 2026-09-02

### Added

### Changed

- **`0_intent.md` is now a reference stub, not a copy.** Task directories seeded by an approved
  intent no longer duplicate the intent's content into `0_intent.md`; instead it's a small stub with
  a `source:` frontmatter link pointing back to the real intent file under
  `<workspace>/.agents/intents/`, which stays the single source of truth. `core/scripts/task-state.sh`
  `check-chain` now resolves that `source:` link and checks approval on the **original** intent file
  rather than on the local copy — so an intent rejected after a task was seeded is now caught too.
  Updated in `core/skills/agent-workflow/SKILL.md`, `core/governance/intents/AGENTS.md`,
  `core/scripts/task-state.sh`, the three adapters' `/monorepo-harness-spec` stubs, their READMEs,
  `adapters/AGENTS.md`, `core/governance/artifacts/AGENTS.md`, and the root `README.md`.

### Removed

### Upgrade Notes

- **No manual follow-up required.** Prompt/script change only — no manifest rows, no artifact
  migration (no existing task directory contains a `0_intent.md` yet). Installed projects pick it up
  on the normal harness-update path.

## [0.1.0-rc.9] - 2026-09-02

### Added

### Changed

- **Spec and plan artifacts now explicitly reference the seeding intent.** Intent-seeded tasks must
  include `intent: 0_intent.md` in `1_spec.md` frontmatter and cite the intent in `2_plan.md`'s
  `## Problem` section (e.g. `problem originally captured and approved in [0_intent.md](0_intent.md)`).
  Ad-hoc tasks with no `0_intent.md` omit the frontmatter line and the trailing clause. Updated in
  `core/skills/agent-workflow/SKILL.md` and `core/governance/intents/AGENTS.md`.
- **No manual follow-up required yet.**

## [0.2.0-rc.0] - 2026-09-02

### Added

- **Self-improvement workflow (`/monorepo-self-improve`).** A new harness capability lets consumer
  projects harvest recurring patterns from their own agent working state — `<workspace>/.agents/lessons.md`,
  `<workspace>/.agents/artifacts/index.md`, and recent `3_memory.md` files — and turn them into
  durable, project-owned artifacts:
  - `.agents/rules/<topic>.md` for simple guidelines and constraints.
  - `.agents/skills/<new-skill>/SKILL.md` for multi-step, project-specific workflows.
  - Root `AGENTS.md` Reference Map updates so agents discover the new rules and skills.
- **`core/skills/self-improvement-workflow/SKILL.md`** — shared instructions for pattern detection,
  proposal reporting, and (only after explicit approval) writing consumer-owned files. It explicitly
  forbids modifying `.agents/monorepo-agents-harness/` at runtime.
- **`adapters/opencode/.opencode/commands/monorepo-self-improve.md`** — thin slash command that
  delegates to the shared skill.
- **`core/governance/rules/rule-template.md`** — template for generated `.agents/rules/*.md` files.
- **Reference Map guidance in `core/root-AGENTS.md`** — documents `.agents/rules/*.md` and
  `.agents/skills/*/SKILL.md` as project-owned instruction locations.

### Changed

### Removed

### Upgrade Notes

- **Reconcile your root `AGENTS.md`.** This release adds Reference Map rows for `.agents/rules/*.md`
  and `.agents/skills/*/SKILL.md`. The normal harness-update flow will propose the merge via
  `agents-md-merge`; accept it so future agents know where project-owned rules and skills live.
- **opencode users: merge `opencode.jsonc`.** The self-improvement skill is added to the adapter's
  `instructions` list. The update flow writes `opencode.jsonc.harness-proposed`; merge it to enable
  auto-loading. The `/monorepo-self-improve` command works regardless.
- **Re-install installed adapters.** Run `install-adapter.sh <agent> --refresh` for each agent you
  use so the new `/monorepo-self-improve` entry point and skill symlink land.
- **No gate or artifact-layout migration.** Existing task directories and the memory-gate are
  unchanged.

## [0.1.0-rc.8] - 2026-08-28

### Changed

- **Intent capture now asks before creating (and committing to) a dedicated `intent/<slug>` branch.**
  On capture the workflow already asked which workspace the intent goes under; it now also present a
  slug-derived branch name it **recommends** (e.g. `intent/add_login_form`) and asks the author to
  confirm or decline creating it via `git switch -c` / `git checkout -b`. If a branch is created, it
  then asks **separately** whether to commit the `status: pending` intent file to that branch. Both
  are explicit in-turn consent questions — a branch is never created, and a pending intent is never
  committed, without the author's answer. Whether the intent file is actually tracked by git is left
  to the host project, whose `.gitignore` decides it — the harness does not mandate or force it
  (`install-manifest.txt` deliberately ships no `.gitignore`). This is a single-source-of-truth change
  to `core/skills/intent-workflow/SKILL.md` plus the matching rule in
  `core/governance/intents/AGENTS.md`; the three adapters' `/monorepo-harness-intent` stage files were
  updated to reflect the new workspace → branch → commit consent flow, and `PORTABILITY.md` notes that
  the flow now uses native `git` branch/commit alongside the existing consent questions.

### Upgrade Notes

- **No manual follow-up required.** Prompt/rule change only — no manifest rows, no gate changes, no
  migration. Branch/commit only happen when the author consents during capture; whether a project's
  `.gitignore` excludes `<workspace>/.agents/intents/` is that project's own decision, and the harness
  never force-adds an intent against it. Installed projects pick the behavior up on the normal
  harness-update path (the intent skill + rules + stage files ship in the bundle).

## [0.1.0-rc.7] - 2026-08-28

### Changed

- **Intent capture now always confirms the target workspace with the author.** The intent workflow no
  longer files an intent under the workspace most likely to drive the work by default — on capture it
  always asks which workspace the intent goes under and presents its own recommendation as the prompt
  (e.g. "File this intent under `apps/api`? (my recommendation)"). The intent file is written only
  after the author confirms the workspace in the current turn, so the intent lands in the right review
  inbox and correctly routes the later plan-mode task that consumes an approved intent. This is a
  single-source-of-truth change to `core/skills/intent-workflow/SKILL.md` plus the matching rule in
  `core/governance/intents/AGENTS.md`; all three adapters' `/monorepo-harness-intent` stage files
  already defer to the shared skill, so they inherit the behavior unchanged.

### Upgrade Notes

- **No manual follow-up required.** Prompt/rule change only — no manifest rows, no gate changes, no
  migration. Installed projects pick it up on the normal harness-update path (the intent skill and
  rules ship in the core bundle).

## [0.1.0-rc.6] - 2026-08-28

### Changed

- **Implementation is now gated on an approved plan.** Fixed the gap where a helpful agent, right
  after writing the spec (`1_spec.md`), would jump straight into implementation without an approved
  `2_plan.md`. Every `/monorepo-harness-spec` command now ends by telling the agent to **stop and
  wait** for `/monorepo-harness-plan`, and every `/monorepo-harness-plan` command ends by telling it
  to **stop and wait** for `/monorepo-harness-build` — so implementation never begins before a
  user-approved plan exists, preserving the `intent → spec → plan → memory → verify` SDLC order.
- **Shared skill hardened.** `core/skills/agent-workflow/SKILL.md` Phase 1 and Phase 2 each end with
  an explicit wait/stop step, and its description no longer implies automatic plan-mode-exit
  triggering exists on every agent (it is manual on opencode and codex).
- **Parity across adapters.** The identical STOP text was applied to all three adapters' `-spec`
  and `-plan` stage files (opencode commands, claude-code commands, codex skills) and all three
  READMEs' typical-workflow sections were updated to name the stop/wait points.

### Upgrade Notes

- **No manual follow-up required.** This is a prompt/instruction change only — no manifest rows,
  no gate changes, no migration. Existing installed projects pick it up on the normal harness-update
  path (the `-spec`/`-plan` stage files ship inside the adapter bundle and update on `refresh`).
  Agents that previously skipped the plan will now stop and ask for `/monorepo-harness-plan` first.

## [0.1.0-rc.5] - 2026-08-28

### Added

- **ADR (Architecture Decision Record) workflow, automatically triggered.** A new
  `core/skills/adr-workflow/SKILL.md` fires while the spec (`1_spec.md`) or plan (`2_plan.md`) is
  being written whenever a task makes an architecture-affecting decision — new external dependency
  or service integration, persistent data-model change with cross-workspace ripple, cross-workspace
  API/event contract change, delivery-guarantee change (idempotency/retry/ordering),
  auth/security model change, or any choice between alternatives with material, hard-to-reverse
  consequences. Decisions land as `adr/NNNN-<title>.md` files **inside the task directory**
  (`## Context` / `## Decision` / `## Alternatives considered` / `## Consequences` /
  `## Related prior ADRs`), each referenced from the spec's new `## Architectural decisions` section.
  Tasks with no architecture-affecting decision write `N/A` and are done — the record stays
  conditional, never gated.
- **`core/scripts/task-state.sh check-adr <spec.md>`** — read-only validator (fail-open backcompat:
  a pre-existing spec without the section passes) used by the `agent-workflow` Phase 1 and the PR
  review pass.
- **ADR-compliance pass in review.** `core/skills/pr-review/SKILL.md` and the root `REVIEW.md`
  template (`core/root-REVIEW.md`) now check that every ADR a task's spec references exists with
  `phase: adr` (failing = Important); an architecture-affecting diff with no ADR declared is at most
  a Nit.
- **Spec template integration.** `core/skills/agent-workflow/SKILL.md` gains the
  `## Architectural decisions` section in the `1_spec.md` template, an `adr/` row in its layout
  trees, and Phase 1/2 trigger steps for the new skill.
- **Adapter registration.** The skill ships for all three agents: new `link` rows in
  `adapters/claude-code/manifest.txt` and `adapters/codex/manifest.txt` (auto-registered skill), and
  a new `instructions` entry in `adapters/opencode/opencode.jsonc`. No slash command — triggering is
  automatic (codex auto-registers it in the slash list anyway, same as the other shared skills).
- Docs updated: `PORTABILITY.md` capability matrix + semantic note, `README.md` (feature bullet,
  artifact tree, Scenario 1 ADR example, docs map), the three adapter READMEs, and the installable
  templates (`core/root-AGENTS.md`, `core/governance/artifacts/AGENTS.md`).

### Upgrade Notes

- **New files reach installed projects via the normal update path.** The `adr-workflow` skill
  (bundle, inside `core/`) and the new claude-code/codex `link` rows are applied automatically by
  the harness-update workflow (`install-harness.sh --sync-only` + `install-adapter.sh --refresh`).
- **opencode needs one manual merge.** The new skill reference lives inside `opencode.jsonc`, which
  installs as a `merge` row — the update flow proposes `opencode.jsonc.harness-proposed` but never
  touches your existing file. Add
  `.agents/monorepo-agents-harness/core/skills/adr-workflow/SKILL.md` to the `instructions` array
  (or accept the proposed version); until then opencode just won't auto-load the ADR skill — a soft
  loss, no hard gate (see `changelogs/version-0.1.0-rc.5.md`).
- **Task directories may optionally contain `adr/`.** No migration, nothing renamed: existing tasks
  without the `## Architectural decisions` section are treated as "no ADRs declared" by `check-adr`.

## [0.1.0-rc.4] - 2026-08-27

### Removed

- **Per-adapter harness update commands.** The `/monorepo-harness:update` (claude-code) and
  `/monorepo-harness-update` (opencode, codex) entry points are removed. Updating is now driven by a
  paste-in **"Or update from the repo"** prompt in the project README that points the active agent at
  the (now-versionless) `core/skills/harness-update/SKILL.md` workflow — the same check, consent
  gates, installer re-run, self-healing adapter `--refresh`, AGENTS.md reconciliation, and audit as
  before, just no longer via a registered slash command. The shared skill and
  `core/scripts/harness-update.sh` remain in the bundle.

### Changed

- Adapter install manifests drop the removed update-command rows; the capability matrix
  (`PORTABILITY.md`), the README feature bullets, Scenario 5, the adapter tables, and each adapter's
  README/INSTALL now describe the README-prompt-driven update instead.

### Upgrade Notes

- **No manual follow-up is required.** The removal is manifest-only: an existing installed adapter
  keeps a stale `/monorepo-harness:update` command/skill until you re-run
  `install-adapter.sh <agent> --refresh` (or run the README update prompt, which does this
  automatically). Re-running it is optional — the stale entry point is harmless and still points at
  the valid shared skill — but re-running it matches the new layout. Any consumer using
  `audit-install.sh` against this release will flag a stale update command file as an extra file to
  remove (or re-install), which is expected.

## [0.1.0-rc.3] - 2026-08-27

### Added

- **Per-SDLC-stage slash commands.** The single `/monorepo-harness-build` that wrote spec+plan in
  one step is split into three gated stages, plus a new read-only validator
  `core/scripts/task-state.sh`:
  - `/monorepo-harness-spec <intent.md?>` — writes `1_spec.md`; when an intent path is given it
    refuses (via `check-intent-approved`) unless that intent is `approved`, and copies it as
    `0_intent.md`. Without a path it makes a normal ad-hoc spec.
  - `/monorepo-harness-plan <spec.md>` — writes `2_plan.md`; validates the spec (`check-spec`) and
    asks about plan mode first (proceeding without it if the user declines).
  - `/monorepo-harness-build <2_plan.md>` — runs the implementation gated on the whole chain
    (`check-chain`: spec+plan present; intent approved if the task is intent-seeded), then
    **automatically** writes `3_memory.md` + `4_verify.md` (unless the spec's Test/verification plan
    is `N/A`) and updates the index.
- `task-state.sh` ships inside the bundle automatically (part of the existing `core/` row).
- All three adapters gain the new `-spec`/`-plan` commands and a rewritten `-build` (manifest rows
  added); docs (`PORTABILITY.md`, each adapter `README.md`/`INSTALL.md`, root `README.md`) updated.

### Upgrade Notes

- `/monorepo-harness-build` **no longer writes `1_spec.md`/`2_plan.md`.** If your workflow relied on
  it to create plan/spec artifacts, use `/monorepo-harness-spec` then `/monorepo-harness-plan`
  instead. `-build` now starts implementation (gated) and writes memory/verify on completion.
- The intent-approval requirement is **conditional, not universal**: it is enforced only when a task
  is seeded by an intent (a `0_intent.md` exists). Ad-hoc tasks (no intent) are unaffected — they
  skip the intent gate entirely, preserving the existing lightweight path.
- An existing installed adapter does not get the new commands until you re-run its installer
  (`install-adapter.sh <agent> --refresh`) or upgrade the harness — see
  `changelogs/version-0.1.0-rc.3.md`.

## [0.1.0-rc.2] - 2026-08-27

### Added

- **Root `REVIEW.md` is now installed automatically.** `core/scripts/install-harness.sh` writes the
  review-policy file at the project root from `core/root-REVIEW.md` (provenance marker on line 1,
  `{{PROJECT_NAME}}` resolved), exactly like the existing `AGENTS.md` step. It is no longer a manual
  "copy it yourself" step. `core/scripts/audit-install.sh` now reports a missing or stale
  `REVIEW.md` alongside the existing `AGENTS.md` check.

### Upgrade Notes

- Existing projects that never created a root `REVIEW.md` will get one on their next **full**
  install (a re-run of `install-harness.sh` without `--sync-only`), exactly like `AGENTS.md` — the
  `--sync-only` update path deliberately does not touch root files. A `REVIEW.md` that already exists
  is **never overwritten** — it is left untouched, like `AGENTS.md`. The `{{PROJECT_REVIEW_POLICY}}`
  region is yours to fill in or delete; leaving the defaults in place preserves the current review
  behavior (the skill's built-in defaults match the generated file).

## [0.1.0-rc.1] - 2026-08-27

### Changed

- **Artifact order now matches the AI-native SDLC playbook** (`intent → spec → plan → memory →
  verify`): the per-task files are renamed so the spec is written first. What was `1_plan.md` is now
  `2_plan.md` (the "how") and what was `2_spec.md` is now `1_spec.md` (the "what"). Plan-mode
  approval now produces `1_spec.md` then `2_plan.md` before implementation, matching Design-before-
  Build (`claude.com/blog/the-ai-native-sdlc-playbook`).
- **Propagated the rename everywhere it is read by name:** the `agent-workflow` skill (Phase 1 =
  spec, Phase 2 = plan), `core/scripts/memory-gate.sh`, the task-index format (link target now
  `1_spec.md`; ◆ = `2_plan.md` + `3_memory.md`), the governance rules (`artifacts`, `intents`), the
  root templates (`root-AGENTS.md`, `root-REVIEW.md`, workspace seed), the PR-review skill, and all
  three adapters' build/review commands, the claude-code `verifier` subagent, and the hook messages.
- **Backcompat for legacy task dirs.** `memory-gate.sh` and the review skill accept a pre-rename
  task dir whose spec is still `2_spec.md` when no `1_spec.md` exists, so installed projects with
  in-flight tasks keep passing the gate on upgrade. No forced migration, nothing renamed on disk.

### Upgrade Notes

- New task directories use `1_spec.md` / `2_plan.md`. Existing task dirs are left untouched and keep
  passing the gate via backcompat — you may rename them at leisure; there is no release prompt that
  forces a migration.
- If you grep installed projects for the old `2_spec.md`/`1_plan.md` names you will still match
  legacy dirs — that is expected until they are closed out.

## [0.1.0-rc.0] - 2026-08-27

First release candidate. Versioning starts here.

### Added

- **Plan → spec → memory → verify artifact workflow.** Every non-trivial task produces
  `<workspace>/.agents/artifacts/task_<YYYY_MM_DD>_<slug>/` containing `1_plan.md`, `2_spec.md`,
  `3_memory.md` and `4_verify.md` (the last required unless the spec's verification plan is `N/A`),
  indexed in that workspace's searchable `.agents/artifacts/index.md`.
- **A hard memory-gate.** `core/scripts/memory-gate.sh` scans every workspace and blocks until
  today's task directory is complete — as an agent stop-hook where the agent can block its own stop,
  and as a git `pre-commit` hook / CI step everywhere else. Fail-open on missing dependencies.
- **Manifest-driven install.** What lands in a consumer project is data, not prose:
  `core/install-manifest.txt` (the bundle whitelist) and `adapters/<agent>/manifest.txt` (one row
  per installed file; verbs `copy`, `link`, `merge`, `tmpl`). Executed by
  `core/scripts/install-harness.sh` (Phase 1) and `core/scripts/install-adapter.sh` (Phase 2),
  verified against those same manifests by `core/scripts/audit-install.sh`.
- **Never-destructive install/update.** Nothing is deleted: replaced content is moved to
  `.agents/.harness-trash/<timestamp>_<pid>/`, and purging it is the user's own explicit call via
  `core/scripts/cleanup-harness-trash.sh`. An existing config file is never modified — the adapter's
  version arrives as `<file>.harness-proposed` for a deliberate merge.
- **Root `AGENTS.md` reconciliation.** `core/root-AGENTS.md` is installed as the project's
  `AGENTS.md` with a provenance marker recording the template version, so
  `core/skills/agents-md-merge/SKILL.md` can three-way merge on later upgrades — presented as a
  diff and written only after explicit approval.
- **Consent-gated upgrades.** `core/scripts/harness-update.sh` resolves installed vs. upstream
  version (SemVer precedence, prereleases included); `core/skills/harness-update/SKILL.md` reports
  the diff, asks once, then re-runs the installers and audits the result before claiming success.
- **Adapters for claude-code, opencode and Codex CLI**, under a mandatory-parity rule
  (`PORTABILITY.md`): every harness capability has a live counterpart per agent, or an explicit
  agent-agnostic fallback. Each ships the harness-plumbing commands `/monorepo-harness-build`,
  `-update`, `-ci`, `-review`, `-intent`, plus a `verifier` subagent where the agent supports one.
- **Supporting skills:** `agent-workflow` (artifact templates), `monorepo` (framework-agnostic
  guidance), `ci-integration` (detects the CI provider and wires the gate in), `pr-review` (reviews a
  diff against `REVIEW.md` and the task's own artifacts), `intent-workflow` (stakeholder intent
  capture with an approve/reject gate).
- **Workspace scaffolding.** `core/scripts/scaffold-workspace-agents.sh` seeds every app and package
  with `.agents/{session-log,lessons,todo}.md`, the artifact tree and the intent inbox; it never
  overwrites an existing file and is safe to re-run after adding a workspace.

### Upgrade Notes

- Nothing to upgrade from — this is the first tagged release. Install with `INSTALL.md`.
- While on `-rc.*`, treat the artifact layout and the manifest format as still settling: a breaking
  change may land in a later `rc` without a MAJOR bump.

[Unreleased]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.3.0-rc.0...HEAD
[0.3.0-rc.0]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.2.0-rc.7...v0.3.0-rc.0
[0.2.0-rc.7]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.2.0-rc.6...v0.2.0-rc.7
[0.2.0-rc.6]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.2.0-rc.5...v0.2.0-rc.6
[0.2.0-rc.5]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.2.0-rc.4...v0.2.0-rc.5
[0.2.0-rc.4]: https://github.com/atayahmet/monorepo-agents-harness/compare/v0.2.0-rc.3...v0.2.0-rc.4
[0.2.0-rc.3]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0-rc.3
[0.2.0-rc.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0-rc.2
[0.2.0-rc.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0-rc.1
[0.2.0-rc.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.2.0-rc.0
[0.1.0-rc.8]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.8
[0.1.0-rc.7]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.7
[0.1.0-rc.6]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.6
[0.1.0-rc.5]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.5
[0.1.0-rc.4]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.4
[0.1.0-rc.3]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.3
[0.1.0-rc.2]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.2
[0.1.0-rc.1]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.1
[0.1.0-rc.0]: https://github.com/atayahmet/monorepo-agents-harness/releases/tag/v0.1.0-rc.0

## 0.4.0-rc.11 (2026-10-03)

- memory-gate.sh and hook-arm-build.sh now enforce/arm build-stage tasks across all dates (not just today), while still excluding finished tasks (closes #23).
- No adapter or manifest changes. Tests cover cross-midnight cases.
