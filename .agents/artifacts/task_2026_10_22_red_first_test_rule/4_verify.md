---
phase: verify
date: 2026-10-22
slug: red_first_test_rule
---

# Verify: Tiered red-first test rule

## Verification run

All commands below were run from the repo root on branch `feat/red-first-test-rule-46`.

New suite, after implementation:

```text
$ bash tests/red-first-rule.test.sh
...
88 passed, 0 failed
exit=0
```

All repo suites:

```text
$ for t in tests/*.test.sh; do bash "$t"; done
audit-import.test.sh         12 passed, 0 failed  exit=0
build-review-tier.test.sh    16 passed, 0 failed  exit=0
checklist-reminder.test.sh   24 passed, 0 failed  exit=0
kb-index.test.sh             38 passed, 0 failed  exit=0
memory-gate.test.sh          59 passed, 0 failed  exit=0
merge-intent-reject.test.sh  28 passed, 0 failed  exit=0
prior-art.test.sh            19 passed, 0 failed  exit=0
red-first-rule.test.sh       88 passed, 0 failed  exit=0
task-commits.test.sh         37 passed, 0 failed  exit=0
```

Syntax, whitespace, and install checks:

```text
$ bash -n core/scripts/task-state.sh && git diff --check
bash -n: OK
diff --check: OK

$ bash core/scripts/install-harness.sh --from <repo> --no-git-hook   # scratch git repo
install-harness: synced 17 manifest row(s) — harness v0.4.0-rc.24
$ bash core/scripts/audit-install.sh --against <repo>
audit-install: clean — installed state matches <repo>
install+audit exit=0
installed task-state: check-red-evidence present
installed template: tier present
installed README: red-first present

$ install-adapter.sh {claude-code,opencode,codex}   # same scratch repo
claude-code exit=0; opencode exit=0; codex exit=0
claude stub OK; opencode stub OK; codex stub OK
```

Mutation checks (fresh copy of the repo per mutation, then the new suite):

```text
empty evidence exits non-zero                suite_exit=1  83 passed, 5 failed
    FAIL red-first without Red evidence section: exit 0
    FAIL red-first with whitespace-only evidence: exit 0
    FAIL red-first with N/A evidence: exit 0
tier read outside its section                suite_exit=1  86 passed, 2 failed
    FAIL tier in another section: must not fire
    FAIL tier after the test section: must not fire
evidence read outside its section            suite_exit=1  87 passed, 1 failed
    FAIL red text in Deviations only: still advisory
legacy treated as red-first                  suite_exit=1  83 passed, 5 failed
    FAIL legacy spec, no verify: silent
    FAIL legacy spec, verify without red evidence: silent
    FAIL empty tier value: treated as legacy, silent
```

Self-check on this task dir:

```text
$ bash core/scripts/task-state.sh check-red-evidence \
    .agents/artifacts/task_2026_10_22_red_first_test_rule
task-state: check-red-evidence — red-first evidence present — .agents/artifacts/task_2026_10_22_red_first_test_rule
exit=0
```

Commit: `0d13da4` — `feat(workflow): add tiered red-first test rule (closes #46)`.

## Red evidence

Captured with the suite written first, before any implementation change, on 2026-10-22:

```text
$ bash tests/red-first-rule.test.sh
  FAIL legacy spec, no verify: exit 0
  FAIL legacy spec, no verify: silent
     expected no output, got: task-state: unknown subcommand 'check-red-evidence'
  FAIL legacy spec, verify without red evidence: exit 0
  FAIL legacy spec, verify without red evidence: silent
     expected no output, got: task-state: unknown subcommand 'check-red-evidence'
  FAIL empty tier value: exit 0
  FAIL empty tier value: treated as legacy, silent
     expected no output, got: task-state: unknown subcommand 'check-red-evidence'
  FAIL evidence-only, no verify: exit 0
  FAIL evidence-only, no verify: silent
     expected no output, got: task-state: unknown subcommand 'check-red-evidence'
...
  FAIL build stub describes the fallback: /adapters/claude-code/.claude/commands/monorepo-harness-build.md
     missing 'fallback'
  FAIL build stub runs the advisory check: /adapters/claude-code/.claude/commands/monorepo-harness-build.md
     missing 'check-red-evidence'
  FAIL red-first step precedes implementation: /adapters/claude-code/.claude/commands/monorepo-harness-build.md
     red line '', implementation line '2'
...
12 passed, 76 failed
exit=1
```

The failure was the missing contract, not an import or setup error: `check-red-evidence` did not
exist (`unknown subcommand`), and the templates, skill, root `AGENTS.md` and build stubs carried no
tier, `## Red evidence` or fallback text. No implementation file had been touched at this point.

## Acceptance criteria results

- [x] Spec, plan and verify templates carry the tier, ordered test-first steps and `## Red evidence`.
  — `templates/{1_spec,2_plan,4_verify}.md`; structural assertions in the suite plus manual diff.
- [x] `agent-workflow/SKILL.md` and the build command in every adapter describe red-first and the
  fallback. — suite checks all three stubs for `red-first`, `Red evidence`, `fallback`,
  `check-red-evidence`, and that the red step precedes implementation; bodies are byte-identical.
- [x] `task-state.sh check-red-evidence` prints an advisory for an empty `## Red evidence` on a
  red-first task, and never fails because of it. — suite asserts exit 0 on missing dir, legacy,
  evidence-only, red-first missing/empty/N/A/filled and unknown tier; mutation 1 proves a non-zero
  exit is caught.
- [x] Existing task dirs without a tier keep passing every gate and produce no red-first advisory.
  — suite covers legacy `1_spec.md`, legacy `2_spec.md` layout, empty tier value, and tier text
  outside the section; mutation 4 proves treating them as red-first is caught.
- [x] The new test suite covers behavior, parser scoping, false positives, CRLF, legacy layout,
  unknown tiers and file immutability; mutation checks prove the suite fails when the parser or exit
  contract is broken. — 88 cases plus the four mutation runs above.
- [x] Release `0.4.0-rc.24` updates `VERSION`, `CHANGELOG.md` and the upgrade prompt. —
  `VERSION` = `0.4.0-rc.24`; `CHANGELOG.md` section; `changelogs/version-0.4.0-rc.24.md`.

## Deviations

None. `changelogs/version-0.4.0-rc.24.md` is included at the maintainer's request even though the
remote release rules would omit a prompt for an instruction/script-only change with no commands.
