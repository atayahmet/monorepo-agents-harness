# Worktrees

`/monorepo-harness-worktree` creates, sets up, lists, removes and prunes git worktrees in **one
place that every adapter shares** (Claude Code, OpenCode, Codex). The command only calls
`core/scripts/worktree.sh`; the script owns the location and every safety rule. Issues #85 and #88.

```bash
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh create feat-login
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh create feat-login --setup  # + the project's setup script
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh setup feat-login          # re-run copy + setup
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh list
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh remove feat-login --delete-branch
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh prune          # dry run
```

If you never run the command, nothing changes: the installer writes no `.gitignore` line, setting
or `AGENTS.md` change for it.

## Where worktrees live

```
~/.harness-worktrees/<repo-id>/<slug>
```

- **One location, always outside the repository.** There is no in-repo mode (see
  [Why not inside the repository](#why-not-inside-the-repository)).
- `<repo-id>` is `<name>-<hash8>`. `<name>` is the repository's directory name; `<hash8>` comes from
  the physical path of the shared git directory (`git rev-parse --git-common-dir`). Every worktree of
  a repository gets the same id, and two clones with the same directory name never collide.
- `<slug>`: letters, digits, `.`, `_` and `-`, starting with a letter or digit, at most 64
  characters. The branch defaults to the slug.
- `HARNESS_WORKTREE_ROOT` moves the root **only** where `$HOME` is not writable or not persistent
  (CI, containers). It must be an absolute path outside the repository. A relative value exits 2; a
  root inside the main checkout or any worktree (also through a symlink) exits 3.
- The harness owns only the worktrees under its root. A worktree an agent tool made itself (Claude
  Code `--worktree`, the Codex app) is `external`: `list --all` shows it, and the harness never
  moves, removes or recreates it.
- Git is the only record. The script keeps no registry file; it reads `git worktree list` every time.

## Subcommands

| Subcommand | What it does |
| --- | --- |
| `path <slug>` | Prints the path. Writes nothing. |
| `create <slug> [--base <ref>] [--branch <name>]` | Adds the worktree and prints its path. A new branch starts from `--base`, else the default branch (`origin/HEAD`, then `main`, then `master`), with no upstream. An existing branch is checked out: a local one, or one a remote has (as a local branch tracking it, by its full ref, so a same-name tag never wins); `--base` with it exits 2. A branch that several remotes have exits 2 unless `checkout.defaultRemote` names one of them, as in git. A branch already checked out in a harness worktree prints that path and changes nothing, so a re-run is safe; one checked out in the main checkout or an external worktree exits 1 and says where. Then it copies the files the project lists in `.agents/worktree-copy.txt`; `--setup` also runs the project's `.agents/worktree-setup.sh` (see [After `create`](#after-create)). |
| `setup <slug>` | Runs the copy step and the project's setup script again in an existing harness worktree (for example after a failed install) and prints its path. |
| `list [--all]` | A tab-separated table: `kind slug branch state merged last_commit path`. `--all` adds `external` worktrees. |
| `remove <slug> [--delete-branch] [--force]` | Removes one harness worktree after the safety checks below. |
| `prune [--yes]` | Dry run by default: lists the harness worktrees that are clean, merged, have at least one commit since `create` and hold no ignored files outside the junk list, plus the missing ones. `--yes` re-reads the worktree list, checks each one again and removes it. Never deletes a branch. |

stdout carries only the result (a path or a table); notes, refusals and everything the project's
setup script prints go to stderr. The script never fetches or pushes.

| Exit code | Meaning |
| --- | --- |
| 0 | Done (or nothing to do). |
| 1 | Refused: the script read the state and said no (for example, the branch is checked out in the main checkout). The reason is printed. |
| 2 | Bad call: unknown subcommand or option, invalid slug or branch, `--base` with an existing branch, a branch that several remotes have. |
| 3 | Environment: not inside a git work tree, `HOME` unset, root not writable, root inside the repository. Fix the setup; `--force` never helps here. |
| 4 | The worktree exists, but the copy or setup step failed (`create`, `setup`). stdout still prints the path; stderr says what failed. Fix the cause and run `setup <slug>`. |

`list` columns:
- `state`: `clean`, `dirty` (uncommitted or untracked files) or `missing` (the directory is gone but
  git still has the record).
- `merged`: `merged`, `unmerged` or `unknown` (no base resolves), by the rule below.

## After `create`

Open a new agent session in the printed path (the current session stays where it is).

Git checks out **tracked files only**. Ignored files are not copied by git: `node_modules`, `.env`,
build output and the `.turbo` cache are not in the new worktree. Two optional files let the project
fill that gap (issue #88). Both belong to the project: the harness reads them and never writes them.
Without them, `create` does nothing beyond the checkout.

| File | What it does | When it runs |
| --- | --- | --- |
| `.agents/worktree-copy.txt` | Copies files from the main checkout into the new worktree. Runs no code. | On every `create`, and on `setup <slug>` |
| `.agents/worktree-setup.sh` | An executable the project writes, e.g. `pnpm install`. Runs code. | Only on `create --setup` or `setup <slug>` |

Both are read from the **main checkout** (the first entry of `git worktree list`; in a bare
repository, the checkout you run the script in), whatever branch the new worktree is on. The new
worktree's own copy is never read or run, so a branch nobody reviewed cannot choose the setup
script. The script still runs in that branch's checkout, though: an install there runs the
branch's own lifecycle scripts (`postinstall` and the like). Use `--setup` only on branches you trust.
When the worktree's copy differs, stderr says the main checkout's copy is used. Commit
both files so every clone has them. (The script still reads them only from the main checkout.)

### `.agents/worktree-copy.txt`

```
# .agents/worktree-copy.txt
.env
apps/*/.env.local
```

- One repo-relative path or glob per line; `#` comments and blank lines are skipped. Globs are shell
  globs from the main checkout: `*` does not cross `/` and does not match a leading `.`, and there
  is no `**`.
- An absolute entry, an entry with a `..` component and one that names `.git` (in any letter case:
  `.GIT` is the same folder on a case-insensitive disk) stop `create` with exit 1, before anything
  is created.
- Each match is copied to the same path with `cp -p`, so an `.env` with mode `600` stays `600`.
  Only **ignored regular files** are copied. These are refused and reported:
  - a symlink or a directory;
  - a source that resolves outside the main checkout;
  - a path through a symlinked folder in the worktree (the copy never writes through a symlink);
  - a path git does not ignore in the new worktree (`git check-ignore`), because `git add -A` could
    commit the copy there.
- An existing file in the worktree is never overwritten. An identical one is fine; a different one,
  or one that is not a regular file, is `kept`. A missing source or an empty glob is only a note.

### `.agents/worktree-setup.sh`

```sh
#!/bin/sh
# .agents/worktree-setup.sh
set -e
pnpm install --frozen-lockfile
```

- It runs only on `create --setup` or `setup <slug>`. The script never asks; the flag is the
  consent. `create --setup` exits 1 before anything is created when the main checkout has no
  executable `.agents/worktree-setup.sh`.
- It runs after the copy step, in the new worktree, by its own shebang (any language), with stdin
  from `/dev/null`. Everything it prints goes to stderr, so stdout still carries one path.
- Environment: yours (with `LC_ALL` and `GIT_OPTIONAL_LOCKS` as you had them), plus
  `HARNESS_WORKTREE_MAIN` (the main checkout), `HARNESS_WORKTREE_PATH` (the new worktree) and
  `HARNESS_WORKTREE_BRANCH` (its branch; empty when detached).
- A non-zero exit is reported as `setup: .agents/worktree-setup.sh exited <code>`.

Without a setup script, run the project's own install in the new worktree, e.g. `pnpm install`.
pnpm hard-links packages from its store when the store and `~/.harness-worktrees` are on the same
volume, so this is fast. npm and yarn classic do a full install. Without a copy list, bring over any
`.env` by hand.

### When a step fails

The worktree exists either way. A refused or failed copy, or a failing setup script, makes `create`
and `setup` exit **4**: stdout still prints the path, and stderr names what failed. Fix the cause
and run `setup <slug>`, which runs both steps again in the existing worktree. A re-run of `create`
prints the path and changes nothing; it never runs either step.

### In an agent session

`/monorepo-harness-worktree` passes `--setup`, or runs `setup <slug>`, only when you typed it in
that turn; otherwise it shows you the command. A long install can hit the agent's command timeout or
its sandbox (Codex blocks writes outside the workspace by default), so a terminal is the better
place: `bash .agents/monorepo-agents-harness/core/scripts/worktree.sh setup <slug>`.

### Secrets

Copied files (an `.env`, a key) live under `~/.harness-worktrees/<repo-id>/<slug>`: outside the
repository, under your user, with the source's mode. `remove` deletes an unchanged copy with the
worktree; the main checkout keeps the original (see [Removal safety](#removal-safety)).

The junk list, `.agents/worktree-junk.txt` (see [Junk list](#junk-list)), is read from the main
checkout too.

## Merged rule

The base is `branch.<branch>.harnessBase` (recorded by `create`; git deletes it with the branch),
else the default branch. `create` records the branch the base names: `--base HEAD` records the
branch HEAD is on, `--base origin/main` records `refs/remotes/origin/main`, and a tag or a commit
records nothing. A branch name means the branch (`refs/heads/<name>`, then `origin/<name>`), never a
same-name tag, which git itself would pick first. A recorded base that no longer exists (a stacked
branch whose base was merged and deleted) falls back to the default branch. A branch is never
measured against itself: a worktree on the default branch is its own base and reads `unknown`. A
branch is **merged** when its tip is an ancestor of `<base>` or
`origin/<base>`, or when `git cherry` finds every commit there by patch-id. That covers merge
commits, rebase-merges and one-commit squashes. A squash of several commits reads `unmerged`. A branch
with a merge commit of its own is merged only when its tip is an ancestor: `git cherry` skips merge
commits, so a change made inside a merge (a conflict resolution) would otherwise be missed. When the
script is unsure, the answer is "not merged".

The check uses local refs only. A branch merged on the host still reads `unmerged` until you run
`git fetch`.

## Removal safety

`remove` never skips these:
- The slug must name a worktree under this repository's root directory. An `external` worktree is
  never touched.
- The current directory must not be inside the worktree.
- The worktree must not be locked (`git worktree unlock` is your call).

`--force` skips these, after it prints what is lost:
- Uncommitted or untracked files.
- Ignored files outside the junk list (an `.env`, a key file). An ignored regular file that is
  **byte-identical** to the main checkout's file at the same path does not count: the main checkout
  still has it (a copied `.env`, also one copied by hand). An edited copy, a symlink, a directory
  and a copy whose main-checkout file is gone still count. `prune` uses the same rule.
- Commits not merged into the base. The branch keeps them; only a detached worktree loses them.

`--delete-branch` deletes the branch only when it is merged by the rule above. An unmerged branch is
never deleted, with or without `--force`: stderr says `kept branch <name> (unmerged)`. The script
never deletes the default branch, merged or not.

A rebase, merge, cherry-pick, revert or bisect in progress stops `remove` (`--force` skips it) and
keeps the worktree out of `prune`. A rebase stopped at `break` and a bisect leave the tree clean, and
the rebase leaves it detached, so the script reads git's state files to see them.

The checks read untracked and ignored files even when `status.showUntrackedFiles=no` is set, and a
`git status` that fails stops `remove` instead of reading as "nothing there".

`prune` also keeps a worktree whose branch has no commit since `create` (its tip is still
`branch.<branch>.harnessStart`, recorded by `create`): another agent session may still be working
there. `remove <slug>` removes it when you mean it.

A missing worktree (directory deleted by hand) is removed by its own path. `prune` never runs a global
`git worktree prune`, because that would also drop the records of `external` worktrees. The script
reads an `external` worktree only for `list --all`, and runs every `git status` with
`GIT_OPTIONAL_LOCKS=0`, so it never takes another session's `index.lock`.

### Junk list

Ignored files that can be rebuilt, so `remove` may lose them:

`node_modules dist build out .turbo .next .nuxt .svelte-kit .output .vercel .cache .parcel-cache
coverage .nyc_output target __pycache__ .pytest_cache .mypy_cache .ruff_cache .venv .gradle
.eslintcache .DS_Store *.tsbuildinfo *.pyc *.log .index.sqlite*`

An entry matches the name of the ignored file or folder itself; `*`, `?` and `[` work as globs. A
folder above it never counts: an ignored `build/signing.p12` inside a tracked `build/` folder stops
`remove`. When `.gitignore` ignores only the files inside a folder (`dist/*`), git reports each file,
so ignore the folder itself (`dist/`) to make it junk. `.index.sqlite*` is the harness's own
knowledge-base cache. A project adds entries in `.agents/worktree-junk.txt` (one name or glob per
line, `#` comments). The file can only add entries, and the harness never writes it.

```
# .agents/worktree-junk.txt
.terraform
*.pem.cache
```

`remove` and `prune` read it from the main checkout, like the copy list and the setup script. A
worktree's own copy is never used, so a branch nobody reviewed cannot add `.env` to the list and
have `remove` delete an `.env` without `--force`. When you run the script from a worktree whose own
copy differs, stderr says the main checkout's list is used. To change the list, edit the main
checkout's file.

A bare repository has no main checkout, so the current checkout stands in, except in a harness
worktree, where only the default list applies: that is where `create --branch` puts a branch you
may not have reviewed. stderr says so. Run `remove` and `prune` from your own checkout to use the
project's list.

## Per-adapter notes

Checked on Claude Code 2.1.332, Codex 0.149.0 and OpenCode 2.1.4 (2026-11-26). Later versions may
change these rules.

- **A new session started in the worktree needs no setup** on any adapter. Claude Code and Codex
  store trust under the main repository, so after you trust it once, no worktree asks again.
- **Claude Code**: the trust prompt defaults to "No, exit" when the folder declares hooks; choose
  "Yes". To edit a worktree from a session in the main checkout, give the session the root:
  `claude --add-dir ~/.harness-worktrees`, `/add-dir`, or `permissions.additionalDirectories` in your
  own `.claude/settings.local.json`.
- **Codex**: the default sandbox blocks writes to `.git` in every checkout, the main one too, so
  `git commit` needs `--add-dir "$(git rev-parse --git-common-dir)"` or an approved escalation. The
  harness hooks need one review ("Trust all") in the main checkout; after that they run in every
  worktree. To edit a worktree from a session in the main checkout, add `--add-dir
  ~/.harness-worktrees` or `sandbox_workspace_write.writable_roots`.
- **OpenCode**: no trust step. The default agent may edit outside the project unless your project
  sets `permission.external_directory`.
- Git hooks live in the shared git directory, so a commit in any worktree runs the main checkout's
  bundle copy of the pre-commit hook.
- The bundle reaches a worktree only through git. When `.agents/monorepo-agents-harness/` is not
  tracked, `create` warns: hooks and `/monorepo-harness-*` commands cannot run in that worktree until
  the bundle is committed or installed there.
- Cross-adapter use works: a worktree committed to with one adapter opens and commits with another.

The harness never changes these settings for you.

## Why not inside the repository

A root such as `<repo>/.worktrees` was tested and rejected:

- OpenCode reads `AGENTS.md` from every parent directory, so a session in the worktree would also
  load the **main checkout's** `AGENTS.md`, possibly from another branch.
- Upward lookups by other tools reach the main checkout. Node, for example, would resolve a missing
  package from `<repo>/node_modules`, so a worktree without its own install could run against the
  main checkout's dependencies.
- It needs a `.gitignore` line in every project. Without it, `git add -A` records the worktree as an
  embedded repository.
- Tools that do not read `.gitignore` (some linters, Docker build contexts, IDE indexers, watchers)
  would see one more copy of the repository per worktree.
- The worktrees would be deleted with the clone, and by `git clean -ffdx`.

That is why the script exits 3 for any root inside the repository.
