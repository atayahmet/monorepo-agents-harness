# Worktrees

`/monorepo-harness-worktree` creates, lists, removes and prunes git worktrees in **one place that
every adapter shares** (Claude Code, OpenCode, Codex). The command only calls
`core/scripts/worktree.sh`; the script owns the location and every safety rule. Issue #85.

```bash
bash .agents/monorepo-agents-harness/core/scripts/worktree.sh create feat-login
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
| `create <slug> [--base <ref>] [--branch <name>]` | Adds the worktree and prints its path. A new branch starts from `--base`, else the default branch (`origin/HEAD`, then `main`, then `master`), with no upstream. An existing branch (local, or one remote has it) is checked out; `--base` with it exits 2. A branch that several remotes have exits 2 unless `checkout.defaultRemote` names one of them, as in git. A branch already checked out somewhere prints that path and changes nothing, so a re-run is safe. |
| `list [--all]` | A tab-separated table: `kind slug branch state merged last_commit path`. `--all` adds `external` worktrees. |
| `remove <slug> [--delete-branch] [--force]` | Removes one harness worktree after the safety checks below. |
| `prune [--yes]` | Dry run by default: lists the harness worktrees that are clean, merged and hold no ignored files outside the junk list, plus the missing ones. `--yes` removes them. Never deletes a branch. |

stdout carries only the result (a path or a table); notes and refusals go to stderr. The script
never fetches or pushes.

| Exit code | Meaning |
| --- | --- |
| 0 | Done (or nothing to do). |
| 1 | Refused: the script read the state and said no. The reason is printed. |
| 2 | Bad call: unknown subcommand or option, invalid slug or branch, `--base` with an existing branch, a branch that several remotes have. |
| 3 | Environment: not inside a git work tree, `HOME` unset, root not writable, root inside the repository. Fix the setup; `--force` never helps here. |

`list` columns:
- `state`: `clean`, `dirty` (uncommitted or untracked files) or `missing` (the directory is gone but
  git still has the record).
- `merged`: `merged`, `unmerged` or `unknown` (no base resolves), by the rule below.

## After `create`

Git checks out **tracked files only**. Ignored files are not copied: `node_modules`, `.env`, build
output and the `.turbo` cache are not in the new worktree.

1. Open a new agent session in the printed path (the current session stays where it is).
2. Run the project's own install there, e.g. `pnpm install`. pnpm hard-links packages from its store
   when the store and `~/.harness-worktrees` are on the same volume, so this is fast. npm and yarn
   classic do a full install.
3. Bring over any `.env` by hand.

The harness never runs an install as part of `create`: it does not know your install command, and
running code on `create` would need its own consent step. When you remove the worktree later,
dependency and build output count as junk and go with it, but an `.env` stops `remove`.

## Merged rule

The base is `branch.<branch>.harnessBase` (recorded by `create`; git deletes it with the branch),
else the default branch. `create` records the branch the base names: `--base HEAD` records the
branch HEAD is on, `--base origin/main` records `refs/remotes/origin/main`, and a tag or a commit
records nothing. A recorded base that no longer exists (a stacked branch whose base was merged and
deleted) falls back to the default branch. A branch is **merged** when its tip is an ancestor of `<base>` or
`origin/<base>`, or when `git cherry` finds every commit there by patch-id. That covers merge
commits, rebase-merges and one-commit squashes. A squash of several commits reads `unmerged`. When the
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
- Ignored files outside the junk list (an `.env`, a key file).
- Commits not merged into the base. The branch keeps them; only a detached worktree loses them.

`--delete-branch` deletes the branch only when it is merged by the rule above. An unmerged branch is
never deleted, with or without `--force`: stderr says `kept branch <name> (unmerged)`.

A missing worktree (directory deleted by hand) is removed by its own path. `prune` never runs a global
`git worktree prune`, because that would also drop the records of `external` worktrees.

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
line, `#` comments, read from the checkout you run the script in). The file can only add entries,
and the harness never writes it.

```
# .agents/worktree-junk.txt
.terraform
*.pem.cache
```

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
