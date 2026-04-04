# Release Checklist — Gate D

Complete this checklist before marking any phase complete or tagging a release. Orchestrator signs off. No exceptions.

Release/Phase: _______________
Date: _______________
Orchestrator: _______________

---

## Section 1: Task Completion

- [ ] All TASKS.md items in this release scope are marked `complete`
- [ ] No tasks marked `in-progress` in the release scope
- [ ] No tasks marked `blocked` in the release scope
- [ ] Every deferred item has a TASKS.md card (Gate E satisfied for all tasks)

## Section 2: Documentation and Help (Gate C)

- [ ] Every new or modified service has a working `--help` / `-h` response
- [ ] Help strings match actual behavior (not intended behavior)
- [ ] `services/README.md` reflects current service set
- [ ] Root `CLAUDE.md` is current (fragility markers, env vars, testing section)
- [ ] `services/CLAUDE.md` is current (contract, tiers, conventions)
- [ ] `lib/CLAUDE.md` is current (if lib work was done in this phase)
- [ ] `tests/CLAUDE.md` is current (if test suite changed)
- [ ] `docs/usage-examples.md` is current for any changed user-facing commands

## Section 3: Test Coverage (Gate B)

- [ ] `bats tests/` passes cleanly
- [ ] All integration tests pass (if applicable to scope)
- [ ] Every new behavior added in this phase has a corresponding BATS test
- [ ] No regressions: tests that passed before phase still pass

## Section 4: GitHub Sync (if applicable)

- [ ] `./tests/run-integration-tests.sh` passes on test profile
- [ ] Sync tests 24.1–24.5 all pass
- [ ] No new TODOs in `lib/github-*.sh` or `lib/sync-*.sh`
- [ ] Verifier produced explicit sync behavior sign-off

## Section 5: Repository Hygiene

- [ ] `git status` is clean (no unexpected modified or untracked files)
- [ ] No `.DS_Store`, `.sqlite3`, sync logs, or generated artifacts in diff
- [ ] `.gitignore` covers all generated artifact patterns
- [ ] `pending/` has no new files (archive-only policy enforced)

## Section 6: Phase Exit Criteria (Phase 1 specific)

- [ ] Root `CLAUDE.md` deployed to project root and passes cold-read test
- [ ] `services/CLAUDE.md` deployed and passes cold-read test
- [ ] TASKS.md rebuilt with verified task status (not seeded estimates)
- [ ] Explorer A report complete at `system/outputs/explorer-a-report.md`
- [ ] Explorer B report complete at `system/outputs/explorer-b-report.md`
- [ ] Test baseline per change type defined and in root `CLAUDE.md`
- [ ] Fragility register current and cross-referenced in root `CLAUDE.md`

---

## Sign-Off

All items above checked: **YES / NO**

If NO: list blocking items below, assign task cards, do not proceed.

Blocking items:
1.
2.
3.

Orchestrator sign-off: _______________ Date: _______________
