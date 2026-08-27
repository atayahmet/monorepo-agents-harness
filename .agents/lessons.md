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
