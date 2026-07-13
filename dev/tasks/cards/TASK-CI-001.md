## TASK-CI-001: Re-enable GitHub Actions CI — smoke + targeted BATS after baseline hardening

Goal:                 GitHub Actions CI is currently disabled (noted in ONBOARDING.md). After browser tests are hardened (TASK-TEST-003) and baseline failures resolved, re-enable the smoke and targeted BATS jobs.

Background:           CI was disabled to prevent false-positive failures from test suites with known structural issues (port coupling, temp dir exhaustion). The path to re-enabling: fix test isolation (TASK-TEST-003), verify the full suite passes locally, then re-enable the workflow files.

Depends on:           TASK-TEST-003

Acceptance criteria:  - [ ] `.github/workflows/` CI workflow file exists and is not commented out / skipped
                      - [ ] Smoke job: `bats dev/tests/test-smoke.bats` passes on every push to master
                      - [ ] BATS job: targeted suites pass (foundation, service-discovery, browser, journal, community)
                      - [ ] CI does NOT run GitHub sync integration tests (requires live credentials — mark as manual only)
                      - [ ] Badge in README reflects current CI status
                      - [ ] First green run documented in `dev/logs/decisions.md`

Write scope:          - `.github/workflows/ci.yml` (re-enable / create)
                      - `dev/tests/` — no new tests required; relies on TASK-TEST-003
                      - `README.md` — CI badge

Rollback:             Disable workflow file (add `if: false` condition). Does not affect production code.

Fragility:            See Risk notes.

Risk notes:           Low once test baseline is clean. Risk: exposing latent test failures. Run full suite locally before enabling.

Notes:                priority: L · area: ci · created: 2026-04-27

Status:               pending

Taskwarrior:          wwdev task (c6c97477) status:pending
