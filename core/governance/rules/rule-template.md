# <Topic>

Replace `<Topic>` with a concrete, greppable name derived from the detected pattern.

## **<Rule title in bold>**

<Clear description of what to do, when it applies, and why it matters.>

## **<Another rule title>**

<Description.>

---

Learned from:
- `<workspace>/.agents/lessons.md` — <short title>
- `<workspace>/.agents/artifacts/task_YYYY_MM_DD_slug/3_memory.md`

Add this file to root `AGENTS.md` `## Reference Map` so agents discover it.

Register this rule in `.agents/.harness-map.json` via
`.agents/monorepo-agents-harness/core/scripts/update-harness-map.sh` so the self-improvement
workflow can detect and update it later instead of creating a duplicate.
