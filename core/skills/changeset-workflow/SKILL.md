---
name: changeset-workflow
description: Draft a changesets-compatible release entry (.changeset/*.md) for a finished harness task, derived from its plan/spec/memory artifacts, without adding @changesets/cli as a dependency. Use when the user types /monorepo-harness-changeset <2_plan.md>, or asks to create a changeset / a release entry for a task. Bump levels are always user-confirmed policy — the skill proposes, never decides.
---

# Changeset Workflow — Draft release entries from task artifacts

Turns a finished task's artifacts into a standard **changesets** entry the project's own
`@changesets/cli` consumes unchanged. Engine: `core/scripts/draft-changeset.sh` (deterministic output,
duplicate guard). This skill supplies the reading, the proposal, the consent gate, and the "never do"
floor. No `changeset` dependency — compatibility is by file format only.

**Write in simple English.** Every file and developer message this skill produces follows
`../../governance/rules/simple-english.md` — short sentences, common words, active voice.

## Concepts

1. **A changeset carries bump types, never a version.** `---` frontmatter maps package names to
   `major|minor|patch`; the summary follows the closing `---`. `v1.0.0-alpha.0 → v1.0.0-alpha.1` is
   produced by the consumer's `changeset pre enter alpha` + repeated `changeset version`, not here.
2. **One plan → many changesets.** A long-lived plan landing over several merges emits one changeset
   per revision (`--revision 1`, then `2`, …); `changeset version` consumes the pending entries, so
   `r1` feeds `alpha.0`, `r2` feeds `alpha.1`. The plan's `revisions:` log is the next-number source.
3. **Deterministic filenames.** `draft-changeset.sh` writes
   `monorepo-harness-<YYYYMMDD>-<slug>-r<N>.md` from the plan `date:`/`slug:` frontmatter — the stable
   identity behind the duplicate guard. `changeset` accepts any `.md` with valid frontmatter.

## Workflow

1. **Resolve the plan** — `/monorepo-harness-changeset <2_plan.md>`; if absent, ask which task's plan
   (search `<workspace>/.agents/artifacts/task_*/2_plan.md`).
2. **Gate** —
   `bash .agents/monorepo-agents-harness/core/scripts/task-state.sh check-plan <2_plan.md>`. Non-zero
   → report and stop; never draft against an invalid plan.
3. **Preflight** — confirm `.changeset/` exists at the repo root. Absent → report the project does
   not appear to use changesets, suggest `changeset init`; never create it yourself (script guards
   the same way).
4. **Read the artifacts** — `2_plan.md` `## Affected files / modules` → candidate packages (map
   `packages/<name>`, `apps/<name>` paths to their `package.json` `name`) + `revisions:` log;
   `1_spec.md` `## Acceptance criteria` + `## Architectural decisions` (breaking clues);
   `3_memory.md` `## What was done` (best summary source).
5. **Propose packages + bumps** per the table below, then **ask the user to confirm the package list,
   every bump, and the summary** — release policy is theirs, never the agent's call. Flag every
   `major` ("breaking?").
6. **Show the draft** —
   `bash …/core/scripts/draft-changeset.sh <2_plan.md> --package <n> --bump <l> … [--revision N]`
   without `--write`. If the auto summary drifted, offer `--summary "<text>"`.
7. **Write on explicit consent** — re-run with `--write` and report the created path.

### Bump heuristic (proposal only — always confirmed)

| Signal in the artifacts | Suggested bump |
|-------------------------|----------------|
| Bug fix; no contract change | `patch` |
| New backwards-compatible behaviour/API; new package | `minor` |
| Cross-workspace API/event or data-model change; deprecation/removal; any ADR in the spec | `major` |
| Unsure | ask — never guess |

## Multi-changeset flow (same plan, later merges)

- Pass `--revision <N>` (start 1, or where the last generated changeset left off); the duplicate
  guard refuses a same-revision re-run and prints the next number — do not work around it.
- An older revision still pending in `.changeset/` is expected during a pre-release train (that's the
  `alpha.0`/`alpha.1` accumulation), not a conflict.

## Never do

- Never run `changeset` / `changeset pre` / `version` / `publish`, create `.changeset/config.json`, or
  modify `.changeset/README.md`.
- Never write a changeset without user-confirmed packages, bumps, and summary.
- Never try to make the changeset "agree with" a version — it has no version to agree with.

## Edge cases

- **No `.changeset/`** → stop at step 3; treat the script's guard message as the authoritative refusal.
- **Research-only task** (no memory / acceptance criteria) → summary falls back to `## Scope`, then
  `## Problem`; a `patch` entry is still legitimate if the user wants one.
- **`changeset` `linked`/`ignore` config** → bumping a linked package forces its group, and ignored
  packages won't version — surface it, apply what the user confirms.
- **Summary derivation empty** → normally impossible; if the script refuses, pass `--summary "<text>"`
  or ask.
- **Harness not installed** → inactive until `INSTALL.md` Phase 1 completes.