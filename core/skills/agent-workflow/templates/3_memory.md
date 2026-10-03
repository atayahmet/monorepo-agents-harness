---
phase: memory
date: <YYYY-MM-DD>
slug: <slug>
commits: [<sha1>, <sha2>]
patch_ids: [<patch-id1>, <patch-id2>]
---

# Memory: <Task title>

## What was done (single paragraph)
<Outcome, 2–4 sentences>

## Surprising findings
<Facts not foreseen during planning — code, system, behavior>

## If I did it again
<What you would do differently, or an approach worth repeating. Knowledge worth preserving.>

## Related decisions
<Decisions made and their reasons — so future readers know why it was done this way>

<!--
`commits:` is one sha per commit, in the order they were made. `patch_ids:` is the same list as
`git patch-id --stable` values, in the same order: the identity of the change rather than of one
branch's history, so it survives a rebase, a squash or a force-push.

A sha goes stale the moment the branch is rewritten. Run

  bash <bundle>/core/scripts/task-state.sh sync-commits <task_dir>/3_memory.md [--ref <branch>] --write

to remap the list after the branch moved; it is a dry run without `--write`, and it rewrites nothing
it cannot map by content. `patch_ids:` is maintained by that command and by nothing else, so if you
write the memory by hand, take the ids from `git show --format= <sha> | git patch-id --stable`.
-->
