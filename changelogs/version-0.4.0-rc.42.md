---
version: 0.4.0-rc.42
from: 0.4.0-rc.41
date: 2026-11-27
---

# Version 0.4.0-rc.42 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.41 to 0.4.0-rc.42, which fixes skill
frontmatter that Codex could not read (issue #87).

## What changed

**Codex now loads every harness skill.**
- Codex reads the frontmatter of each `SKILL.md` as strict YAML. When the YAML is not valid, it logs
  `failed to load skill` and leaves the skill out, with no message in the chat.
- Two harness skills had invalid frontmatter, so on Codex `adr-workflow` never loaded (ADR capture
  never started) and `/monorepo-harness-intent-dispatch` was not available.
- `intent-workflow` had the same defect. No adapter loads it as a skill today, but it ships.
- Only the frontmatter changed. The wording of each description and the skill bodies are the same.

## Commands to run

- None. The update flow's `install-harness.sh --sync-only` step replaces `adr-workflow` and
  `intent-workflow`. The `install-adapter.sh codex --refresh` step replaces the
  `/monorepo-harness-intent-dispatch` entry point.

## Manual follow-ups for the user

- Codex: start a new Codex session after the update. Codex reads skills when a session starts, so a
  session that is already open still lacks `adr-workflow` and `/monorepo-harness-intent-dispatch`.
  In the new session, its startup log has no `failed to load skill` line for these skills.
- Optional, Codex: check your project's own skills. Codex skips any `SKILL.md` whose frontmatter is
  not valid YAML. The usual causes are a `: ` inside an unquoted `description:`, a wrapped line that
  starts in column 1, and a key that appears twice. To fix the first two, put the description in
  double quotes, or write `description: >-` and indent every line of the text under it. The
  harness's own frontmatter test is repo-local and does not ship.

## Release summary

- Fixed the frontmatter of `core/skills/adr-workflow/SKILL.md`, `core/skills/intent-workflow/SKILL.md`
  and the codex `monorepo-harness-intent-dispatch` entry point (issue #87).
- Added the repo-local test `tests/frontmatter-yaml.test.sh`, which checks the frontmatter of every
  shipped markdown file.
- No change to `core/root-AGENTS.md`, the manifests, adapter settings files or
  `core/gitignore-fragment.txt`.
