---
name: agents-md-merge
description: Reconcile a project's root AGENTS.md with the harness template core/root-AGENTS.md — a three-way merge when the file carries the harness provenance marker, an additive adoption merge when it does not — then present a clean unified diff and require explicit user approval before writing anything. Use during harness install (INSTALL.md §4 step 4), during every harness upgrade (core/skills/harness-update/SKILL.md step 9), or when the user asks to sync/merge AGENTS.md against the harness template.
---

# AGENTS.md Reconciliation

Shared instructions for reconciling a project's root `AGENTS.md` with the harness template
`core/root-AGENTS.md`, used from both `INSTALL.md` (initial install) and
`core/skills/harness-update/SKILL.md` (every upgrade).

`AGENTS.md` is **jointly owned**: the harness owns the workflow-policy sections (Core Principles,
Agent Lifecycle, the Before You Start checklist, most of Workspace Routing & Execution, most of
Additional Context Locations); the project owns its name, its gotchas, and every row of the
Reference Map. The harness therefore never overwrites this file and never writes it without
explicit approval — but it also no longer leaves the user to diff it by hand. This skill produces a
fully resolved proposal, shows the diff, and asks.

There is no script behind this workflow — every step below is a plain `git`/coreutils one-liner or
a judgment call for you (the active agent) to make directly, the same "engine does mechanical work,
agent does everything else" split used by `harness-update`.

## Vocabulary

| Term | Meaning |
|---|---|
| `OURS` | the project's current root `AGENTS.md`, with the provenance marker line removed |
| `BASE` | `core/root-AGENTS.md` as shipped in the version recorded by `OURS`'s provenance marker |
| `THEIRS` | `core/root-AGENTS.md` from the bundle being installed/upgraded to (`$NEW`) |

The **provenance marker** is the first line the harness writes into every `AGENTS.md` it creates or
merges:

```
<!-- monorepo-agents-harness: root-AGENTS.md vX.Y.Z -->
```

followed by a blank line. It is invisible in rendered Markdown. `X.Y.Z` is the harness version whose
`core/root-AGENTS.md` this file was last reconciled against — it only advances when a merge is
actually **applied** (a decline leaves it at its old value, never blocking, so the next upgrade
re-offers the merge from the correct base instead of silently skipping intervening changes).

## Workflow

### Step 0 — Resolve inputs and pick a mode

Run from the repo root. `$NEW` is the bundle to reconcile against: the newly downloaded bundle
directory during an upgrade (`.agents/.harness-update-v<latest>`), or the freshly copied
`.agents/monorepo-agents-harness` during a fresh install.

```bash
MERGE=.agents/.harness-agents-md-merge
TARGET_VER="$(tr -d '[:space:]' < "$NEW/core/VERSION")"
mkdir -p "$MERGE"

BASE_VER="$(sed -n 's|^<!-- monorepo-agents-harness: root-AGENTS\.md v\([0-9][0-9.]*\) -->.*|\1|p' \
  AGENTS.md 2>/dev/null | head -n1)"
```

Pick the mode:

| Condition | Mode |
|---|---|
| no root `AGENTS.md` | **A — verbatim install** |
| `AGENTS.md` exists, `BASE_VER` is empty (no marker — every pre-0.5.0 install, including hand-authored files) | **B — adoption merge**. Never guess a base version for an unmarked file. |
| `AGENTS.md` exists, `BASE_VER` set, `v$BASE_VER` fetchable from upstream | **C — three-way merge** |
| `AGENTS.md` exists, `BASE_VER` set, but `v$BASE_VER` cannot be fetched (offline, tag missing) | fall back to **Mode B**, and say so in the plan |
| after normalization (Step 2), `OURS` is already identical to `THEIRS` | **D — stamp only** (propose a one-line marker refresh, still ask) |

### Step 1 — Mode A (verbatim install)

```bash
{ printf '<!-- monorepo-agents-harness: root-AGENTS.md v%s -->\n\n' "$TARGET_VER"
  cat "$NEW/core/root-AGENTS.md"; } > AGENTS.md
```

During a fresh install this needs no separate consent (there is nothing to lose). During an upgrade
this case is surprising — a root `AGENTS.md` appearing where none existed — so report it and ask
first.

### Step 2 — Prepare merge inputs (Modes B, C, D)

```bash
# OURS — strip the marker so it never participates in the merge itself
sed '/^<!-- monorepo-agents-harness: root-AGENTS\.md v/d' AGENTS.md > "$MERGE/ours.md"

# project vocabulary, for placeholder substitution below
NAME="$(sed -n 's|^# \(.*\) — Agent Guidelines[[:space:]]*$|\1|p' "$MERGE/ours.md" | head -n1)"
FW="$(bash .agents/monorepo-agents-harness/core/scripts/detect-monorepo-framework.sh --framework)"

# THEIRS — placeholder-normalized so an upstream edit near a placeholder can't inject a raw
# {{...}} token into a live project file
sed -e "s|{{PROJECT_NAME}}|${NAME}|g" -e "s|{{MONOREPO_FRAMEWORK}}|${FW}|g" \
  "$NEW/core/root-AGENTS.md" > "$MERGE/theirs.md"
```

Do **not** substitute `{{PROJECT_GOTCHAS}}` — it marks a project-owned region, not a value to fill.
If `NAME` comes back empty (the project retitled its H1 away from the expected pattern), leave
`{{PROJECT_NAME}}` unsubstituted in `theirs.md` and resolve that spot by hand rather than guessing.

### Step 3 — Mode C (three-way merge)

```bash
git clone --depth 1 --branch "v$BASE_VER" \
  "${HARNESS_UPSTREAM:-https://github.com/atayahmet/monorepo-agents-harness}" "$MERGE/base-clone"

sed -e "s|{{PROJECT_NAME}}|${NAME}|g" -e "s|{{MONOREPO_FRAMEWORK}}|${FW}|g" \
  "$MERGE/base-clone/core/root-AGENTS.md" > "$MERGE/base.md"

git merge-file -p --diff3 \
  -L "your AGENTS.md" -L "harness template v$BASE_VER" -L "harness template v$TARGET_VER" \
  "$MERGE/ours.md" "$MERGE/base.md" "$MERGE/theirs.md" > "$MERGE/merged.md"
echo "conflicts=$?"
```

- Always pull `BASE` and `THEIRS` from a pristine tag clone or the freshly downloaded bundle —
  **never** from `.agents/monorepo-agents-harness/core/root-AGENTS.md`. That installed copy has
  already had its placeholders substituted at install time (`INSTALL.md` §6) and is not a valid
  merge input.
- `git merge-file` requires no repo/tracking on its inputs — it operates on three arbitrary files.
  Its exit status is the conflict count, not a pass/fail signal; capture it, don't treat non-zero as
  failure.
- `conflicts=0` still requires the Step 6 review below — a clean textual merge can still be
  semantically wrong (duplicated rules, broken list numbering).
- If the clone fails, fall back to Mode B (Step 4) and disclose the downgrade when presenting the
  plan.

### Step 4 — Mode B (adoption merge)

Strictly additive: never delete, reorder, or reword anything already in `ours.md`. Build
`proposed.md` from it:

1. **Inventory** the atomic units of `theirs.md`: each `##` heading; inside them, each policy item
   keyed by its **bold lead-in** (e.g. `**Commits are mandatory…**`, `**Simplicity First**`); each
   "Before You Start" checklist line; the "Working state is per-workspace" blockquote; each
   `.agents/monorepo-agents-harness/**` bullet under "Additional Context Locations".
2. **Classify** each unit against `ours.md`:
   - **PRESENT** — the project already states the rule (even in different words) → leave the
     project's wording untouched.
   - **MISSING** → insert it.
   - **CONFLICTING** — the heading exists in `ours.md` with materially different content (e.g. the
     project already has its own `## Core Principles`) → do **not** overwrite it. Append the missing
     harness items after the project's own content, and record this as a resolved conflict for the
     approval summary.
3. **Placement**: heading already present → append missing items at the end of that section.
   Heading absent → insert the whole section in the template's relative order (right after the
   nearest preceding template section that does exist in `ours.md`; otherwise immediately before
   `## Reference Map`; otherwise at the end).
4. **Match the project's own conventions** for heading depth, list style, and prose voice — don't
   impose the template's formatting where the project already established its own.
5. **Placeholders**: fill `{{PROJECT_NAME}}`/`{{MONOREPO_FRAMEWORK}}` from Step 2. If the project
   already has its own Critical Gotchas, drop the `{{PROJECT_GOTCHAS}}` example item entirely rather
   than importing it.
6. Prepend the marker for `$TARGET_VER` as line 1 of `proposed.md`.

### Step 5 — Ownership map and conflict-resolution rules (shared by Modes B and C)

**Harness-owned** (prefer upstream on a genuine conflict; keep any project-added items alongside
rather than removing them): `## Core Principles`, `## Agent Lifecycle`,
`## Before You Start — Mandatory Checklist`, `## Workspace Routing & Execution` (except
framework-specific example commands), any Critical Gotchas item whose bold lead-in matches a
harness rule, the "Working state is per-workspace" blockquote, and the
`.agents/monorepo-agents-harness/**` bullets under `## Additional Context Locations`.

**Project-owned** (never overwrite; upstream changes to these are offered, never applied
unilaterally): the H1 and intro line, the `{{PROJECT_GOTCHAS}}` region, every row of
`## Reference Map`, and any section/bullet/item with no upstream counterpart at all.

**Resolving conflicts, whichever mode:**

1. Resolve at the level of the smallest **complete** semantic unit — a whole list item, table row,
   or paragraph, never a raw line. The template's prose is hard-wrapped; a `git merge-file` conflict
   region that lands mid-sentence must be widened to the enclosing item before you touch it.
2. Ignore pure list-renumbering differences. Match items by their bold lead-in identity, not by
   position, and renumber the final list sequentially from 1.
3. Favor the project's phrasing wherever it doesn't contradict harness policy; favor upstream only
   where the two genuinely disagree on policy, and name that disagreement in the approval summary.
4. Never drop a project-owned unit to resolve a conflict.
5. Never leave a conflict unresolved for the user to see — the file presented for approval must
   already be final and clean.

### Step 6 — Self-check before showing anything to the user

```bash
# 1. No conflict markers may survive. (A bare '=======' line is legal Markdown — a setext H1
#    underline — so only match the markers that are unambiguous.)
grep -n '^<<<<<<< \|^>>>>>>> \|^||||||| ' "$MERGE/proposed.md" && echo "STOP — unresolved conflicts" \
  || echo "clean"

# 2. Structural safety: no heading present in the current file may have disappeared.
diff <(grep '^#\{1,6\} ' "$MERGE/ours.md") <(grep '^#\{1,6\} ' "$MERGE/proposed.md")

# 3. No template placeholder leaked into the project file.
grep -n '{{PROJECT_NAME}}\|{{MONOREPO_FRAMEWORK}}\|{{PROJECT_GOTCHAS}}' "$MERGE/proposed.md"
```

Check 2 must come back empty, or additions-only. Any deletion means the merge has a bug — fix it
before proceeding; if a release genuinely removes a section, call that out explicitly at approval
time instead of letting it happen silently.

### Step 7 — Ask for approval

```bash
git diff --no-index --stat -- AGENTS.md "$MERGE/proposed.md"
git diff --no-index --      AGENTS.md "$MERGE/proposed.md"
```

(`git diff --no-index` exits 1 when the files differ — that's normal, not an error; it works on
untracked files too.)

Present, in this order:

1. One line of context: mode, base version, target version — e.g. "Three-way merge of your
   AGENTS.md against the harness template, base v0.4.5 → v0.5.0."
2. A grouped semantic change list, not a raw diff dump: `Added: N harness rules` (named),
   `Updated: M harness rules` (named, with what changed), `Preserved: all project content — K
   project-only sections untouched`, `Resolved: C conflicts`.
3. One line per resolved conflict: section/rule name, what the project had, what upstream changed,
   what was chosen, and why.
4. The unified diff (stat first, then the full diff; if it's very long, show the stat plus the
   harness-owned hunks and point at the proposal file for the rest).
5. The question, verbatim: **"Apply this merge to AGENTS.md?"**

Rules: never show raw conflict markers to the user; never write `AGENTS.md` without an explicit
affirmative in the current turn; this consent is separate from any broader "Upgrade now?" consent —
approving an upgrade does not by itself authorize writing `AGENTS.md`.

### Step 8 — Apply, or record the decline

On **yes**:

```bash
git ls-files --error-unmatch AGENTS.md >/dev/null 2>&1 || cp AGENTS.md AGENTS.md.harness-backup
cp "$MERGE/proposed.md" AGENTS.md      # proposed.md already carries the marker as line 1
```

Re-run the Step 6 checks against the file you just wrote, then report
`AGENTS.md reconciled with the harness template v$TARGET_VER`.

On **edit**: take the user's instructions, regenerate `proposed.md`, and return to Step 6.

On **no**: write nothing. Preserve the proposal outside the temp dir so cleanup (Step 9) stays
unconditional:

```bash
cp "$MERGE/proposed.md" AGENTS.md.harness-proposed
```

Report the path, the review command (`git diff --no-index AGENTS.md AGENTS.md.harness-proposed`),
and that the provenance marker was deliberately **not** advanced — the next install/upgrade will
re-offer the same merge from the same base. A decline never blocks or fails the install/upgrade.

### Step 9 — Clean up (always)

```bash
rm -rf .agents/.harness-agents-md-merge
```

Unconditional, regardless of which mode ran or whether the user approved — the same lesson as the
0.4.5 changelogs-cleanup fix: one command, not a fire-and-forget step that can be half-run.

## Edge cases

- **Base tag unreachable** (offline, tag not published) → fall back to Mode B and state the
  downgrade in the plan; never guess a different base version to compensate.
- **No provenance marker** → always Mode B, unconditionally. Do not attempt to infer which harness
  version the file might have come from.
- **Merge declined** → not an install/upgrade failure. Proceed with the rest of the install/upgrade;
  carry the proposal path forward as a manual follow-up.
- **`AGENTS.md` uses CRLF line endings** → every line will differ from the LF template, conflicting
  the whole file. Detect with `grep -c $'\r' AGENTS.md`; if non-zero, strip CR from all three inputs
  before merging and restore CRLF only in the final `proposed.md`.
- **`AGENTS.md` is a symlink** (e.g. some projects point it at `CLAUDE.md`) → do not overwrite the
  link target blindly; report it and ask how to proceed.
- **The H1 doesn't match `# <name> — Agent Guidelines`** → leave `{{PROJECT_NAME}}` unresolved in
  the proposal and flag it for manual resolution rather than guessing a name.
- **No root `AGENTS.md` during an upgrade** (Mode A mid-upgrade) → still ask before writing; a file
  appearing where none existed is worth a beat of confirmation.
