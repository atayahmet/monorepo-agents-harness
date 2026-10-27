---
name: team-registry
description: Team registry (.agents/team.yml) — schema, lookup via team.sh, forward-only departure, and setup (init/add/remove) flow. Phase A provides read-only contract; setup details live here for Phase B.
---

# Team Registry

## Purpose
Single source of truth for people, roles, platform IDs and workspace assignee routing. Consumer-owned data; harness provides contract and script.

## Usage
- Read via `bash .agents/monorepo-agents-harness/core/scripts/team.sh <cmd>`
- Template: `.agents/monorepo-agents-harness/core/team/team.example.yml`
- Rules: `.agents/monorepo-agents-harness/core/team/AGENTS.md`

## Commands (Phase A)
`whoami`, `get`, `find`, `match`, `assignee`, `lint`

## Phase B (planned)
`/monorepo-harness-team init|add|remove <key>|lint|migrate` with explicit consent, forward-only scanning, and no automatic writes without yes.

## Integration points
- Intent capture/review/dispatch use `whoami`/`match` and optional `author_key`
- Tracker assignment uses `assignee` (create-then-assign on GitHub)
- Self-improvement flags hardcoded people in future-facing files
