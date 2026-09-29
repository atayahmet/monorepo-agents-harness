---
version: 0.4.0-rc.8
from: 0.4.0-rc.7
date: 2026-09-29
---

# Version 0.4.0-rc.8 Upgrade Instructions

You are upgrading the monorepo-agents-harness from 0.4.0-rc.7 to 0.4.0-rc.8, which gives a
multi-phase intent a **parent issue** on the board and records every key it filed back on the intent.

## What changed

**Two or more phases can now hang under one epic issue.** Dispatch asks *"Start these N phases under
an epic?"* in the same sign-off table where it asks *"Start these N phases?"* — the same turn, the
same consent. On a "yes" it creates one parent issue and files every phase as its **sub-issue**, so
the board itself shows the grouping rather than a flat list of siblings. `no epic` files them flat, as
before. **A single-phase intent is unchanged**: no epic, no extra question, no extra issue.

The parent link is a real hierarchy, not a label or a line of prose — `gh issue create --parent`,
which GitHub renders as a parent/child relation. Re-running dispatch reuses the epic the intent
already records rather than filing a second one, and an issue from the duplicate check can serve as
the epic only if you nominate it yourself. Nothing is auto-matched.

**Your intent now records what it produced.** After a dispatch, the intent file gains a `## Dispatch`
block listing the tracker, the epic, and every phase key the creates actually returned — so once the
PR is merged and the conversation is gone, the approved decision still points at the work it
authorised. It is append-only (one block per run, newest last), and a phase that could not be filed
reads `no issue yet (<reason>)` rather than being quietly dropped. This is the **only** file dispatch
adds; it still writes no spec, no plan and no task directory.

**`gh` version floor — it degrades, it does not pin.** `--parent` needs `gh` 2.100.0 or newer. On an
older `gh` the script says so, prints paste-ready issue text and exits 3 rather than failing the
dispatch: the phases are filed **flat**, the report states that the epic exists but is unlinked, and
every phase still gets its issue. Grouping is never worth blocking work for.

## Commands to run

- None. `core/install-manifest.txt` already copies the whole `core/` directory, and no adapter gained
  or lost a file, so neither manifest changed. Run the normal update sync (`/monorepo-harness-update`,
  or `core/scripts/install-harness.sh --sync-only`) and the adapter refresh.

## Manual follow-ups

- **Check your `gh` version if you want the epic link.** `gh --version` — below `2.100.0` dispatch
  still works and still files every phase, just without the parent link. Upgrading `gh` is the only
  step; there is no harness setting for this.
- **Nothing to migrate.** Intents that were dispatched under rc.7 or earlier have no `## Dispatch`
  block, and that is fine — the block is written from the next dispatch onward, and the first one that
  follows simply has no earlier epic to reuse.
- **`jira` / `linear` are still not created by the harness.** An epic there is a phase you file
  yourself; the harness hands you the text.
