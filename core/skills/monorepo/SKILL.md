---
name: monorepo
description: |
  Generic monorepo guidance plus framework-specific advice for Turborepo, Nx, Lerna,
  and npm/yarn/pnpm workspaces. Triggers on: monorepo structure, workspace configuration,
  task orchestration, caching, package boundaries, dependency management, and CI optimization.

  Use when the user: sets up a monorepo, creates packages, configures tasks/pipelines,
  runs changed/affected packages, debugs cache, shares code between apps, or works with
  apps/packages/libs directories.
metadata:
  version: 0.1.0-rc.0
---

# Monorepo Skill

Guidance for JavaScript/TypeScript monorepos. The harness supports Turborepo, Nx, Lerna,
and plain npm/yarn/pnpm workspaces. The active framework is detected at install time and
recorded in the project's root `AGENTS.md`.

## Which framework is in use?

The harness detects the framework from repo markers:

| Marker | Framework |
|---|---|
| `turbo.json` | **Turborepo** |
| `nx.json` | **Nx** |
| `lerna.json` | **Lerna** |
| `pnpm-workspace.yaml` | **pnpm workspaces** |
| `package.json` `workspaces` array | **npm workspaces** or **yarn workspaces** (resolved by lockfile/`packageManager`) |

When in doubt, prefer the most specific marker. If multiple markers exist, the order above
is used (`turbo.json` wins over `nx.json`, etc.).

## Generic Monorepo Principles

### 1. Package Tasks, Not Root Tasks

**DO NOT create root tasks. ALWAYS create package tasks.**

When creating tasks/scripts/pipelines, you MUST:

1. Add the script to each relevant package's `package.json`.
2. Register/orchestrate the task in the framework's config (`turbo.json`, `nx.json`, `lerna.json`,
   or root `package.json` for plain workspaces).
3. Root `package.json` only delegates to the framework runner (`turbo run <task>`, `nx run-many`,
   `lerna run`, `npm run --workspaces`, etc.).

**DO NOT** put task logic in root `package.json`. This defeats parallelization and caching.

```json
// DO THIS: scripts live in packages
// apps/web/package.json
{ "scripts": { "build": "next build", "lint": "eslint .", "test": "vitest" } }

// packages/ui/package.json
{ "scripts": { "build": "tsc", "lint": "eslint .", "test": "vitest" } }
```

```json
// Root package.json - ONLY delegates
{
  "scripts": {
    "build": "turbo run build",
    "lint": "turbo run lint",
    "test": "turbo run test"
  }
}
```

### 2. Declare Workspace Dependencies

Internal packages must be declared as workspace dependencies. Do not reach into another
package's source tree.

```json
// CORRECT
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/utils": "workspace:*"
  }
}
```

```typescript
// WRONG: reaching into internals
import { Button } from "../../packages/ui/src/button";

// CORRECT: install and import the public export
import { Button } from "@repo/ui/button";
```

### 3. Keep Apps Free of Shared Code

```
// WRONG
apps/web/shared/utils.ts

// CORRECT
packages/utils/src/utils.ts
```

### 4. Root Dependencies Are Only Repo Tools

```json
// WRONG
{ "dependencies": { "react": "^18", "next": "^14" } }

// CORRECT
{ "devDependencies": { "turbo": "latest" } }
```

### 5. Environment Variables Belong in Packages

A root `.env` creates implicit coupling. Put `.env` files in the packages that need them and
register shared variables in your framework's env config.

---

## Turborepo

Build system for JavaScript/TypeScript monorepos. Turborepo caches task outputs and runs
tasks in parallel based on the dependency graph.

### Turbo-specific rules

- **Always use `turbo run` in code:** package.json scripts, CI, and any persisted command
  must use `turbo run <task>`. The shorthand `turbo <task>` is only for interactive terminals.
- **Root `package.json` only delegates.** Never put task logic there.
- **Use `dependsOn: ["^build"]`** to build dependencies first. Use `dependsOn: ["build"]` for
  intra-package ordering.
- **Declare `outputs`** for file-producing tasks so they can be cached.
- **Use `--affected`** to run changed packages + dependents.
- **Avoid root tasks (`//#taskname`)** unless the task truly cannot exist in a package.

### Standard pipeline

```json
{
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**", ".next/**", "!.next/cache/**"] },
    "lint": {},
    "test": { "dependsOn": ["build"] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

### Common anti-patterns

- `turbo build` instead of `turbo run build` in `package.json` or CI.
- Chaining tasks with `&&` instead of letting `dependsOn` orchestrate.
- `prebuild` scripts that manually build dependencies.
- Missing `outputs` for tasks that write files.
- Overly broad `globalDependencies` — prefer task-level `inputs`.
- Root `.env` files.

---

## Nx

Nx uses a project graph and task runners. Workspaces are declared in `nx.json` and discovered
from `project.json` files or inferred from `package.json`.

### Nx-specific rules

- **Projects first.** Every runnable unit is an Nx project (`apps/web/project.json` or a
  `package.json` with an `nx` key).
- **Targets in projects.** Build/test/lint scripts live in each project's configuration, not
  in the root.
- **Use `nx affected`** (or `nx affected --target=build`) to run only changed projects and
  their dependents.
- **Cache via `nx.json` `tasksRunnerOptions`**. Remote caching is configured in `nx.json`.
- **Use `inputs` and `namedInputs`** to control cache invalidation.

### Standard commands

```bash
nx run-many -t build        # build all projects
nx affected -t build        # build changed + dependents
nx run web:build            # build a single project
nx graph                    # inspect project graph
```

### Workspace layout

```
my-monorepo/
├── apps/
│   └── web/
├── libs/
│   └── ui/
├── nx.json
└── package.json
```

---

## Lerna

Lerna manages versioning, publishing, and task running for npm/yarn/pnpm workspaces.

### Lerna-specific rules

- **Packages are declared in `lerna.json`** (`packages` array) or inferred from workspaces config.
- **Use `lerna run <script>`** to run a script across packages.
- **Use `lerna exec`** for arbitrary commands.
- **Versioning:** `lerna version` bumps versions and creates tags; `lerna publish` publishes.
- **Lerna does not cache.** Combine Lerna with Turborepo or Nx if you need task caching.

### Standard commands

```bash
lerna run build             # run "build" in all packages
lerna run build --since     # run in changed packages only
lerna version               # bump versions
lerna publish               # publish to registry
```

---

## npm / yarn / pnpm Workspaces

Plain workspaces use the `workspaces` field in root `package.json` (npm/yarn) or
`pnpm-workspace.yaml` (pnpm).

### Plain-workspace rules

- **Install once at root.** Root `node_modules` hoists shared deps; package-specific deps live
  in each workspace's `node_modules`.
- **Use workspace protocol:** `workspace:*` (yarn/pnpm) or `"@repo/ui": "*"` (npm).
- **Run tasks via the package manager:**
  - npm: `npm run build --workspaces` (npm 7+)
  - yarn: `yarn workspaces run build`
  - pnpm: `pnpm --filter ./packages/* run build`
- **No built-in caching.** Add Turborepo or Nx if the monorepo grows.

### pnpm-specific

- `pnpm-workspace.yaml` defines globs:
  ```yaml
  packages:
    - 'apps/*'
    - 'packages/*'
  ```
- Use `--filter` to target packages:
  ```bash
  pnpm --filter web run build
  pnpm --filter ./apps/* run build
  ```

---

## CI / Task Running Decision Tree

```
Run only what changed?
├─ Turborepo → turbo run build --affected
├─ Nx        → nx affected -t build
├─ Lerna     → lerna run build --since
├─ pnpm      → pnpm --filter [origin/main] run build
└─ npm/yarn  → use changesets or third-party tools; consider adding Turborepo/Nx
```

---

## Package Boundaries

Regardless of framework:

1. **No imports across package internals.** Use public exports only.
2. **Declare internal dependencies.** `^build` (Turborepo) and project graphs (Nx) only work
   when dependencies are declared.
3. **Keep shared code in `packages/` (or `libs/` for Nx).**
4. **Respect the framework's filter/affected semantics** when running tasks.
