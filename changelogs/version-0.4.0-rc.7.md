---
version: 0.4.0-rc.7
from: 0.4.0-rc.6
date: 2026-09-28
---

# Version 0.4.0-rc.7 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.6 to 0.4.0-rc.7, which makes the intent
PR's **forge** something the harness resolves instead of assumes.

## What changed

**The intent's pull request no longer has to be on GitHub.** `pr:` may now be a GitLab, Bitbucket or
Gitea pull/merge request URL, and dispatch reads and merges it there. The forge is decided in this
order: the host in the `pr:` value itself, then a `forge:` line in your `.agents/tracker.md`, then
this repo's `origin` remote. The harness never assumes GitHub because `gh` is the tool it knows.

**The harness looks for a way in before it touches anything.** It tries that platform's own CLI
(`gh` / `glab` / `bb` / `tea`) first, then its REST API using a token your project already exports
(`GITHUB_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN`, `GITEA_TOKEN`), and each one is probe-verified
with a real read before any write is considered. If the only route in is a project MCP server or a
project skill, the harness says so by name and hands the call to your agent — it never guesses, never
prompts for a credential, and never stores one.

**One behavior change to be aware of: an approval the harness cannot read is no longer replaced by
the intent file's own `status: approved`.** In rc.6, if the PR could not be read, dispatch fell back
to the file — so on any project whose PR the harness could not reach (any MCP-only or self-hosted
setup) the file stood in for a human decision, every time. That was a standing permission slip. Now
an unreadable approval is `UNKNOWN` and dispatch stops, and the command explains whether to read the
PR yourself through the named MCP server or skill. The file is still authoritative when the intent has
no `pr:` field at all.

**Also new:** `tracker-issue.sh --list-open` reads the board through the same mechanism, so the
duplicate check works on self-hosted and non-GitHub forges. A read that cannot happen reports exit 3
and is never treated as "nothing is open". Issue **creation** is still GitHub-only in this release.

## Commands to run

- None. `core/install-manifest.txt` already copies the whole `core/` directory, so the new
  `core/scripts/forge.sh` needs no manifest row. Run the normal update sync
  (`/monorepo-harness-update`, or `core/scripts/install-harness.sh --sync-only`) and the adapter
  refresh.

## Manual follow-ups

- **If you want dispatch to know your forge without inferring it, add a `forge:` line** to
  `<repo-root>/.agents/tracker.md`:

  ```yaml
  forge: gitlab   # github | gitlab | bitbucket | gitea
  ```

  Without it, a bare `#42` resolves through your `origin` remote as before. Only cross-repository
  refs (`owner/name#42` and full URLs) need this — they already name their own host.
- **If you previously relied on the file fallback, check the approval yourself.** Any intent whose
  `pr:` the harness could not read is now refused rather than approved. Re-run dispatch from a machine
  with a working `gh` / `glab` / `bb` / `tea`, or export the platform token, or read the PR with your
  own MCP server or skill and merge it there. Do not re-run with the `pr:` field removed to get a
  "yes" out of the file.
- **On GitLab, Bitbucket or Gitea, issue creation still does not happen.** Dispatch will report
  paste-ready title and body for each phase and continue with the rest. This is unchanged from
  rc.6 and is a separate axis from reading the PR — see ADR
  `0003-forge_axis_is_separate_from_the_tracker_axis.md`.

## Verify

```bash
# 1. which forge, and can the harness reach it?
bash .agents/monorepo-agents-harness/core/scripts/forge.sh probe <pr-ref>

# 2. the merge decision is still a dry run unless you pass --yes
bash .agents/monorepo-agents-harness/core/scripts/task-state.sh merge-intent-pr \
  <your-intent.md>
```

Expect `probe result=usable mechanism=<cli|rest>`, or `probe result=agent-only mechanism=<mcp|skill>`
with the config path and server name when only your agent can read the PR. A bare `result=none` means
no mechanism at all: install or authenticate the platform CLI, export its token, or accept that
dispatch cannot read that PR. Nothing is merged in any of those cases without your explicit yes.
