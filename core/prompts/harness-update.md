# Harness update prompt

The paste-in prompt below is the single source of the harness update procedure in this bundle. It
is used by the `/monorepo-harness-update` command on every adapter, and the project README links to
this file instead of quoting it.

The prompt is **versionless on purpose**: it names no release and no file list. The version engine
is `core/scripts/harness-update.sh`, the file list is `core/install-manifest.txt`, and the workflow
is `core/skills/harness-update/SKILL.md`. If you change the procedure, change it there.

Prefer the command when you have an adapter installed (`claude-code`, `opencode`, `codex`):

```
/monorepo-harness-update
```

Otherwise, paste this into any agent (Claude Code, opencode, Codex CLI, …) from your monorepo root
whenever a new harness release is announced, or you suspect your install is out of date:

```text
Update the monorepo-agents-harness in this repository.

1. Check the installed version against upstream:

     bash .agents/monorepo-agents-harness/core/scripts/harness-update.sh check --json

   - If it reports "current", say so and stop.
   - If it reports "outdated", continue. If "unknown", show me the script's stderr and the
     `git ls-remote --tags <upstream>` suggestion instead.

2. Upgrading must follow the installed workflow exactly —
   `.agents/monorepo-agents-harness/core/skills/harness-update/SKILL.md`. Read it and do what it
   says end to end: clone the new release, apply its `changelogs/version-X.Y.Z.md` prompts in
   order, run the new release's own `install-harness.sh --sync-only`, `--refresh` every adapter
   whose manifest rows exist here, reconcile the root AGENTS.md via
   `core/skills/agents-md-merge/SKILL.md` (its own consent gate), audit, and clean up. Do NOT
   copy files by hand and do NOT shorten the workflow.

Rules while you do this:
- Ask me "Upgrade now?" before the bundle sync, and again before writing AGENTS.md — these are
  two separate approvals.
- Never overwrite a config file I already have; a `.harness-proposed` file means leave the
  original and show me the diff.
- If any script exits non-zero, stop and show me its output verbatim. Do not improvise a fix.
- Report the manual follow-ups the prompts list, and the audit result, before anything else.
  Do not commit without asking me.
```
