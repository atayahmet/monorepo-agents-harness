/**
 * Agent-harness adapter for opencode — mirrors the claude-code adapter's memory-gate
 * (adapters/claude-code/.claude/settings.json) on top of the shared core.
 *
 *  - memory-gate reminder  ← core/scripts/memory-gate.sh (soft here — see note below)
 *
 * Install: copy this file to `.opencode/plugins/agent-harness.ts` in the target repo. opencode
 * auto-loads it at startup. See https://opencode.ai/docs/plugins/
 *
 * IMPORTANT — semantic differences vs. claude-code (see PORTABILITY.md):
 *  - `session.idle` fires after the turn is already idle, so it can only REMIND, not hard-block.
 *    For a real memory-gate on opencode, ALSO install `core/scripts/memory-gate.sh` as a git
 *    pre-commit / CI step (the universal hard gate).
 *
 * No path knobs: task artifacts follow the fixed convention <workspace>/.agents/artifacts/.
 */
import type { Plugin } from "@opencode-ai/plugin"

export const AgentHarness: Plugin = async ({ $, directory }) => {
  const root =
    (await $`git rev-parse --show-toplevel`.quiet().nothrow().text()).trim() || directory

  return {
    // Remind (soft) that today's task dir still needs 3_memory.md before the session ends.
    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      const today = new Date().toISOString().slice(0, 10).replace(/-/g, "_")
      const latest = (
        await $`ls -td ${root}/apps/*/.agents/artifacts/task_${today}_* ${root}/packages/*/.agents/artifacts/task_${today}_* 2>/dev/null | head -1`
          .quiet()
          .nothrow()
          .text()
      ).trim()
      if (!latest) return
      const hasMemory =
        (await $`test -f ${latest}/3_memory.md`.quiet().nothrow()).exitCode === 0
      if (hasMemory) return
      console.warn(
        `agent-workflow: ${latest.replace(`${root}/`, "")}/3_memory.md is missing — ` +
          `write it before ending (see core/skills/agent-workflow/SKILL.md in the harness bundle). ` +
          `Hard enforcement: core/scripts/memory-gate.sh at commit/CI.`,
      )
    },
  }
}
