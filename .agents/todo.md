# Todo — Install root REVIEW.md during install

## Task: task_2026_08_27_install_root_review

- [x] Decide behavior (user: auto-install like AGENTS.md; leave existing REVIEW.md untouched)
- [x] install-harness.sh: step 3 REVIEW.md generation (marker, resolve PROJECT_NAME, note policy; leave-existing)
- [x] core/root-REVIEW.md: header comment describes auto-install
- [x] audit-install.sh: check_review_md() provenance (missing + stale marker)
- [x] Docs: INSTALL.md §2/§4/§6, README.md index row, PORTABILITY.md
- [x] VERSION 0.1.0-rc.2 + CHANGELOG.md section + Upgrade Note (no prompt file needed — no command/manual follow-up)
- [x] Verify: bash -n, smoke install fresh + pre-existing, audit missing/match/stale
- [ ] Memory + verify artifacts + commit
