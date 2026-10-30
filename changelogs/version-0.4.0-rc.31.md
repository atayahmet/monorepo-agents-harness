---
version: 0.4.0-rc.31
from: 0.4.0-rc.30
date: 2026-10-30
---

# Version 0.4.0-rc.31 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.30 to 0.4.0-rc.31, which lets an intent
capture open its own pull request.

## What changed

**`/monorepo-harness-intent --pr [--draft] <description>` carries a capture through to an open PR.**
The flag is your consent to branch, commit, push and open the PR. The harness creates `intent/<slug>`
from the default branch, commits only the intent file, pushes it with `git push -u`, opens the PR on
your forge, and records the PR link in `pr:` with a second commit. After that, `--approve`, `--reject`
and dispatch find the PR without asking. The workspace question is still asked. `--pr` is never a
review decision: it does not approve or merge anything.

**`forge.sh create` opens the pull request.** It reaches your forge the same way `approve` and `merge`
do: the platform CLI (`gh` / `glab` / `tea`), then REST with a token your project already exports, then
a handoff to your agent when the only route is a project MCP server or skill. It never asks for or stores
a credential. `--draft` works on GitHub, GitLab and Gitea. Bitbucket has no draft state, so the harness
asks before it opens a normal PR.

## Commands to run

- None. `core/install-manifest.txt` already copies the whole `core/` directory, and the three
  `monorepo-harness-intent` entry points are existing adapter manifest rows. The update flow's
  `install-adapter.sh <agent> --refresh` step installs the new text.

## Manual follow-ups for the user

- If you edited your project's copy of the intent command (`.claude/commands/monorepo-harness-intent.md`,
  `.opencode/commands/monorepo-harness-intent.md` or `.agents/skills/monorepo-harness-intent/SKILL.md`),
  the refresh replaces it with the shipped text. Re-apply your edits on top of the new `--pr` bullet.
- `--pr` needs a pushable `origin` remote. Without a CLI or token the harness cannot call, it prints
  the pull request details for you to paste. The branch stays pushed and the intent stays valid.

## Release summary

- Added `/monorepo-harness-intent --pr [--draft]` and `forge.sh create` (issue #60).
- Added `forge.sh default-branch`, so the agent and the script agree on the PR base.
- No change to `core/root-AGENTS.md`.
