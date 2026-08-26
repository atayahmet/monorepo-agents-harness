# Todo — monorepo-agents-harness (root)

Working plan for the current task. Overwrite per task.

## Feedback Loop + verifier subagent (Phase 1, v0.7.0) — 2026-08-26

- [x] Write `1_plan.md` / `2_spec.md`
- [ ] Extend `core/skills/agent-workflow/SKILL.md` with Phase 4 (`4_verify.md`)
- [ ] Extend `core/scripts/memory-gate.sh` (default + `--json` modes, N/A escape hatch)
- [ ] Add `adapters/claude-code/.claude/agents/verifier.md`
- [ ] Update `PORTABILITY.md` (verifier matrix row) and `adapters/AGENTS.md` (subagent scope rule)
- [ ] Update `core/governance/artifacts/AGENTS.md` directory layout
- [ ] Propagate the artifact-triad → quad change through docs that document it verbatim
      (`README.md`, `INSTALL.md`, adapter `INSTALL.md`/`README.md` x3, `core/root-AGENTS.md`,
      top-level `AGENTS.md`, `core/workspace-agents-template/session-log.md`)
- [ ] Bump `core/VERSION` to 0.7.0, fix stale `CHANGELOG.md` bookkeeping, write
      `changelogs/version-0.7.0.md` (folding in the pending `changelogs/draft.md` content), remove
      `changelogs/draft.md`
- [ ] Write `4_verify.md` + `3_memory.md`, update `.agents/artifacts/index.md`, commit
