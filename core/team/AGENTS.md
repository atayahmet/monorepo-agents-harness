# Team Registry — Rules

`.agents/team.yml` is the single source of truth for people, roles, platform IDs and workspace
assignee routing. It is **consumer-owned**: the installer never creates it (it holds personal data),
`/monorepo-harness-team` does, with consent. The harness provides the format, `core/scripts/team.sh`
(read-only) and the integration points. Skill and setup flow: `core/skills/team-registry/SKILL.md`.

## Location
- Path: `<repo-root>/.agents/team.yml` — one file at the repo root, because people span workspaces.
- Template: `.agents/monorepo-agents-harness/core/team/team.example.yml` (shipped, never copied as `team.yml`).
- Whether the file is committed is the project's decision. It holds public platform IDs and work
  emails only; keep only the IDs your tools use.

## Schema (v1)
```yaml
version: 1
members:                      # developers; only these can be assignees
  - key: alice
    name: Alice Example       # written into intents and reviews (never the key)
    role: developer           # free text; the harness gives no role a meaning
    title: Staff Engineer
    ids:                      # keyed by platform, so the harness stays platform-neutral
      git: [alice@example.com, alice@users.noreply.github.com]   # matched by `whoami`
      github: alice-example
      jira: "557058:0000"
      slack: U0000000
contacts:                     # not developers; reached by role (find --role manager)
  - key: bob
    name: Bob Example
    role: product_owner
    ids: { slack: U1111111 }
assignee_by_workspace:        # key: workspace dir from the repo root; value: member keys
  .: [alice]                  # `.` is the repo root
  apps/api: [alice, carol]
  "libs/payments/*": [carol]  # globs allowed (quote keys that start with `*`)
  apps/web: []                # vacant: ask the developer
```

Rules:
- Keys are unique across `members` and `contacts`. Every entry has a `name`.
- `ids.git` may be a list, a block list, or one string. An ID may appear on one entry only.
- `assignee_by_workspace` values are `members` keys. A contact is never an assignee. A key that is no
  longer a member is skipped at lookup (and reported by `lint`), so a departed person is never proposed.
- Members vs contacts matters: sprint capacity and assignment count members only.

## Workspace matching
- Keys are workspace directory paths from the repo root — the one thing every framework has, and what
  the harness already uses for `<workspace>/.agents/`. Package names and Nx project names are not keys.
- Keys and lookups are normalized alike (`./apps/api/` is `apps/api`). A lookup matches the **exact
  path first**, then the **most specific matching glob**: most literal characters, then fewer `**`,
  then fewer `*`. `*` matches inside one path segment, `**` matches zero or more segments.
- Not found, or an empty list → `ask`. The harness never picks for the developer (no round-robin).

## Commands (`team.sh`)
`whoami` · `get <key> [field]` · `find --role <r> [--kind members|contacts]` · `resolve <platform|key|name> <id>`
(`match` is an alias) · `assignee <workspace>` · `lint` · `refs <key>`. `whoami` matches
`git config user.email` against `ids.git`, case-insensitively; `--email` overrides.

`lint` errors (exit 1): duplicate keys, a missing `name`, a duplicated ID, an assignee that is not a
member (or is a contact). Warnings (stderr, exit 0): an `assignee_by_workspace` key that matches no
directory, or no workspace `detect-monorepo-framework.sh` finds — only a warning, because discovery
does not cover every layout yet.

## Exit codes
| Code | Meaning | Caller action |
|------|---------|---------------|
| 0 | success | proceed |
| 1 | lint error | fix and retry |
| 2 | usage error | fix arguments |
| 3 | not found / undetermined | ask the developer; **never guess** |
| 4 | no `.agents/team.yml` | behave exactly as before; hint once: run `/monorepo-harness-team` |
| 5 | registry unreadable (wrong shape, unsupported syntax, version) | report it and ask; never silently fall back |

## Integration contract
Optional everywhere; with no registry the harness behaves exactly as before.
- Intent `author:` / `Reviewer:` ← registry **name** (`whoami`, `resolve github <login>`).
- Dispatch reports self-approval when approver and author resolve to the same key. Approval itself
  stays a forge decision; the registry carries no approver flag.
- Dispatch + `tracker-issue.sh --assignee`: one key → propose, several → the developer picks, `ask` →
  the developer answers; the chosen person's ID *for that tracker* (`ids.github`, `ids.jira`, …).
- Skills and commands never hardcode people or IDs (root rule 8).

## Forward-only departure
Remove the entry (`/monorepo-harness-team remove <key>`), then fix only the files that drive future
work (project skills, commands, rules, living docs, CI). Never rewrite intents, task artifacts, session
logs, fixtures or git history: they were true on their date.

## Parser constraints (YAML subset)
`key: value`, quoted strings, `# comments`, `- key:` entries, `ids:` as a block map or a one-line
`{ a: b }` map, lists as `[a, b]` or `- item`. Assignee values are `[a, b]`, `[]`, one key, or a block
list. Anything else in a known section is exit 5 with the line number, never a guess. An unknown
top-level key (with any children) is ignored and `lint` warns about it. No anchors,
multi-line scalars, or nested maps. In a one-line `{ }` map, give one git email (use the block form
for several).
