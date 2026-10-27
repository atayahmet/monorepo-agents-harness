# Team Registry — Rules

`.agents/team.yml` is the single source of truth for people, roles, IDs and workspace assignee routing. It is **consumer-owned** (installer never creates it). The harness provides the format, lookup script and integration points.

## Location
- Path: `<repo-root>/.agents/team.yml` (one file, spans workspaces)
- Template: `.agents/monorepo-agents-harness/core/team/team.example.yml` (shipped, never copied as `team.yml`)

## Schema (v1)
```yaml
version: 1
members:
  - key: alice
    name: Alice Example
    role: developer
    title: Staff Engineer
    ids:
      git: [alice@example.com, alice@users.noreply.github.com]
      github: alice-example
      jira: "557058:0000"
      slack: U0000000
contacts:
  - key: bob
    name: Bob Example
    role: product_owner
    title: Product Owner
    ids:
      slack: U1111111
assignee_by_workspace:
  .: [alice]
  apps/api: [alice, carol]
  libs/payments/*: [carol]
  apps/web: []
```

Notes:
- `ids.git` may be a list or a string (parser accepts both for compatibility). Lists are preferred.
- `assignee_by_workspace` values are lists of **members** keys. `[]` means vacant → `ask`. Missing key also means `ask`.
- `role` is free text. Harness does not enforce approver flags in v1.
- Keys must be unique across members+contacts.
- Every entry must have a `name`.

## Workspace matching
- Keys are paths from repo root. `.` is repo root.
- Normalize: `./apps/api/` → `apps/api`
- Match order: **exact match first, else longest matching glob**
- Globs: `*` matches a single path segment, `**` matches zero or more segments
- Lint warns (not fails) when a workspace key matches no directory found by filesystem scan

## Lookup rules
- `team.sh whoami` matches `git config user.email` against `ids.git` (case-insensitive). If no match → exit 3.
- `team.sh assignee <workspace>` prints member keys one per line, or `ask` if vacant/missing.
- `team.sh match <platform> <id>` does reverse lookup.
- Never guess. If unknown → ask.

## Exit codes (team.sh)
| Code | Meaning | Caller action |
|------|---------|---------------|
| 0 | success | proceed |
| 1 | lint error | fix and retry |
| 2 | usage error | fix arguments |
| 3 | not found / undetermined | ask user, do not guess |
| 4 | registry missing (`.agents/team.yml` not found) | fall back to current behavior |
| 5 | registry broken (parse/structure error) | report and ask, do not silently fall back |

## PII & safety
- Store only public/platform IDs your tools use. No tokens/credentials/phone numbers.
- Installer never creates `team.yml`. Setup command only writes with explicit yes.
- Forward-only departure: delete the entry, fix only future-facing files (skills/commands/rules/docs/CI), never rewrite intents/task artifacts/fixtures/git history.

## Parser constraints (YAML subset)
- First `---` block only
- `key: value`, inline lists `[]`, block lists `- item`
- Comments `#`, quoted strings supported
- Unsupported syntax → error with file:line
