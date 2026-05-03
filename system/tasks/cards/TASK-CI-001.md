---
id: TASK-CI-001
title: Re-enable GitHub Actions CI — smoke + targeted BATS after baseline hardening
status: pending
priority: L
area: ci
created: 2026-04-27
tw_uuid: c6c97477
depends: TASK-TEST-003
---

## Goal

GitHub Actions CI is currently disabled (noted in ONBOARDING.md). After browser tests are hardened (TASK-TEST-003) and baseline failures resolved, re-enable the smoke and targeted BATS jobs.

## Context

CI was disabled to prevent false-positive failures from test suites with known structural issues (port coupling, temp dir exhaustion). The path to re-enabling: fix test isolation (TASK-TEST-003), verify the full suite passes locally, then re-enable the workflow files.

## Acceptance Criteria

- [ ] `.github/workflows/` CI workflow file exists and is not commented out / skipped
- [ ] Smoke job: `bats tests/test-smoke.bats` passes on every push to master
- [ ] BATS job: targeted suites pass (foundation, service-discovery, browser, journal, community)
- [ ] CI does NOT run GitHub sync integration tests (requires live credentials — mark as manual only)
- [ ] Badge in README reflects current CI status
- [ ] First green run documented in `system/logs/decisions.md`

## Write Scope

- `.github/workflows/ci.yml` (re-enable / create)
- `tests/` — no new tests required; relies on TASK-TEST-003
- `README.md` — CI badge

## Risk

Low once test baseline is clean. Risk: exposing latent test failures. Run full suite locally before enabling.

## Rollback

Disable workflow file (add `if: false` condition). Does not affect production code.
