# Lessons — monorepo-agents-harness (repo root)

- The artifact filenames are a **contract**: `memory-gate.sh`, the index format, adapter build
  hooks, the review skill and the docs all reference `1_plan.md` / `2_spec.md` by name. Any rename
  must touch every consumer of that name in the same commit.
- Backcompat is cheaper than migration for a shared template: keep the gate/consumers accepting the
  old `2_spec.md` as a spec when `1_spec.md` is absent, so installed projects with in-flight tasks
  are not broken by an upgrade.
- The `1_`/`2_` numeric prefix means "phase order", not just a cosmetic index — reordering the files
  means reordering *when the agent writes them* (spec before plan), which also flips what the
  pre-implementation prior-art search gates on.
- Every root-facing template shipped under `core/` must mirror the `AGENTS.md` install path: if
  `core/root-*.md` is meant to land at the target root, `install-harness.sh` step 3 must write it
  (with provenance marker), not just ship it in the bundle. The `--sync-only` update path never
  writes root files — document that so users know when a fresh root file will or won't appear.
- Parallel checks in `audit-install.sh` (one per root file) are the safety net that turns "silently
  never installed" into a named gap. Removing/clarifying a doc's "optional copy it yourself" prose
  must come in the same commit as the automation, or the two drift.
