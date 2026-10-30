---
name: team-registry
description: The team registry (.agents/team.yml) - one source for people, roles, platform IDs and workspace assignee routing, read through team.sh; and the /monorepo-harness-team setup flow (init, add, remove, lint, migrate) that detects, shows, asks, then writes only on an explicit yes. Use when the user types /monorepo-harness-team, asks who is on the team, who should be assigned, how to add or remove a person, or when a person leaves.
---

# Team Registry

The harness owns the format, the lookup script and the integration points. **The project owns the
data.** `.agents/team.yml` is consumer-owned and holds personal data, so the installer never creates
it: this skill does, on request, with consent.

Format, matching rules and exit codes: `core/team/AGENTS.md`. Template: `core/team/team.example.yml`.
**Write in simple English** (`../../governance/rules/simple-english.md`).

## Reading (any skill or command)

`bash .agents/monorepo-agents-harness/core/scripts/team.sh <cmd>` — read-only.

| Need | Command | Not found |
|------|---------|-----------|
| Who am I (the developer running this) | `whoami` | exit 3 → ask |
| A person's field | `get <key> [name\|role\|title\|ids.<platform>]` | exit 3 |
| The manager / product owner | `find --role <role>` | exit 3 → ask |
| Forge login, chat ID or name → key | `resolve <platform\|key\|name> <id>` | exit 3 |
| Who may take work in a workspace | `assignee <workspace>` | prints `ask` |
| Where is this person still named | `refs <key>` | `refs: none` |
| Is the file sound | `lint` | exit 1 (errors) |

No registry is exit 4: carry on as before and, at most once, say "run `/monorepo-harness-team` to set
up a team registry". **Never start the setup from inside another flow.**

## Workflow — `/monorepo-harness-team [init|add|remove <key>|lint|migrate]`

Same shape as `/monorepo-harness-ci` and the `.agents/tracker.md` cache: **detect, show, ask, then
write.** Nothing is written without an explicit yes in the current turn. The default action is `init`
when there is no `team.yml`, and `lint` when there is one.

### init

1. **Infer, read-only.** `bash .agents/monorepo-agents-harness/core/scripts/team-infer.sh [--since <when>]`
   prints the workspaces, the people who committed (default window: 6 months), and the `CODEOWNERS`
   owners per path when that file exists. Everything it prints is a **suggestion**: it flags bots,
   merges one email seen under two names, and marks people whose last commit is old — a person who
   left recently still shows up, and people who never commit (a manager, a product owner) never do.
2. **Show the draft** and let the developer mark each person `member`, `contact` or `drop`. Never
   pre-select "member" for someone flagged stale or bot.
3. **Ask for contacts by role** (manager, product owner, support). They do not show up in git.
4. **Fill platform IDs only through the developer's own tooling** — `gh api users/<login>`, a tracker or
   chat MCP user lookup, or the developer typing them. Leave an ID out when it cannot be found. Never
   ask for a token or a password; the registry holds public IDs only. Keep only the IDs your tools use.
5. **Build `assignee_by_workspace`** from the `CODEOWNERS` seeds and the developer's answers: keys are
   workspace paths from the repo root (`.` is the root), globs allowed, values are member keys,
   `[]` means "ask the developer".
6. **Show the whole file and ask "Write `.agents/team.yml`?"** On yes, write it, then run
   `team.sh lint` and report the result. On no, write nothing.

### add

Ask for the person's key, name, role, kind (member or contact) and IDs (same rules as init step 4),
show the new entry, and write it only on a yes. Then `team.sh lint`.

### remove `<key>`

The departure procedure (forward-only): the past stays as it was.

1. Run `team.sh refs <key>` **before** deleting anything, and keep the list.
2. Show the entry and the hits. Ask "Remove `<key>` from `.agents/team.yml`?" — on yes, delete the
   entry **and** the key from every `assignee_by_workspace` list (that slot becomes vacant, or stays a
   shorter list), then run `team.sh lint`.
3. Print the hits for the developer to fix: project skills, commands, rules, living docs, CI. **List
   them; do not edit them** unless the developer asks for a specific one.
4. **Never edit** intents, task artifacts, session logs, fixtures, the changelog or git history. They
   were true on their date. `refs` already skips them.

### lint

`team.sh lint`. Report errors (exit 1) and warnings (stderr; a workspace key that matches no
directory, or no workspace the framework detector finds, is a warning because detection does not
cover every layout yet). Offer to fix an error; write only on a yes.

### migrate

`team.sh` exits 5 on a `team.yml` in another shape (for example `jira_account_id`, `slack_id`,
`jira_assignee_by_work_type`, no `version: 1`). **Never overwrite or rewrite it.**

1. Read the old file and propose the v1 shape as `.agents/team.yml.proposed`, mapping old fields to
   `ids.<platform>`. Show a diff against the old file. Unmapped fields are listed, not dropped.
2. List the project skills and commands that read the old fields (`grep` the old field names under
   `.agents/skills/`, `.agents/rules/`, and the adapter command folders) so the developer updates
   them in the same change.
3. The developer swaps the files. The harness never does it for them.

## Integration points

Each is optional and falls back to today's behavior with no registry (exit 4):

- **Intent capture / review / reject / approve** — `author:` and `Reviewer:` use the registry name
  (`whoami`, `resolve github <login>`). See `core/skills/intent-workflow/SKILL.md`.
- **Intent dispatch** — reports self-approval (approver and author resolve to the same key) and
  proposes assignees from `assignee <workspace>`; the chosen person's tracker ID goes to
  `tracker-issue.sh --assignee`. One key: propose. Several: the developer picks. `ask`: the developer
  answers. Never assign on a guess.
- **Self-improvement** — hardcoded names and IDs in project-owned skills are candidates to move here.

## Hard nevers

No write without a yes this turn · no credential asked for or stored · no guess of an ID or an
assignee · no edit of intents, task artifacts, fixtures or history · no overwrite of an existing
`team.yml` of another shape · no setup started inside another flow.
