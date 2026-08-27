# Todo — Remove per-adapter update commands; add a README update prompt

## Task: task_2026_08_27_remove_update_command

- [x] Decide design (user: keep shared skill; add paste-in README prompt after install prompt)
- [x] Delete 3 adapter update files (+ empty claude subdir)
- [x] Remove update copy rows from 3 manifests
- [x] core/skills/harness-update/SKILL.md: description + intro (drop slash-command names)
- [x] Adapter READMEs (bullet + section → pointer note) + INSTALL.md Update-check rows
- [x] PORTABILITY.md (matrix row / codex note / ship guidance)
- [x] Root README.md (feature bullet, Scenario 5, self-update line, adapter table, "Or update from the repo" prompt) + INSTALL.md §7
- [x] VERSION 0.1.0-rc.4 + CHANGELOG (Removed/Changed/Upgrade Notes; no changelogs prompt)
- [x] Verify: bash -n, grep stale refs, scratch fresh + refresh install + audit 0, no update files, INSTALL.md ≤ 100
- [x] Memory + verify artifacts + commit
