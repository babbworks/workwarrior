---
id: TASK-TEST-003
title: Harden test-browser.bats and test-browser-warlock.bats for isolated/CI runs
status: pending
priority: M
area: tests
created: 2026-04-27
tw_uuid: 644ebe39
---

## Goal

`test-browser.bats` (267 lines) and `test-browser-warlock.bats` (366 lines) currently have brittle coupling to port 7777 and assume a running server. Harden both suites to spin up and tear down their own server instances on ephemeral ports so they run cleanly in CI and in parallel.

## Context

CI is disabled (see TASK-CI-001). The browser tests are cited in tests/CLAUDE.md as having ~10 structural failures in isolated runs. The warlock test suite was added recently and has not been validated in CI. Both suites need:
- Ephemeral port selection (not hardcoded 7777)
- `setup_file` / `teardown_file` that start/stop the Python server
- Health-check loop before asserting on responses
- ww-base pointed at a temp directory with minimal fixture profiles

## Acceptance Criteria

- [ ] `test-browser.bats`: all tests pass with `bats tests/test-browser.bats` in a clean environment (no pre-running server, no port 7777)
- [ ] `test-browser-warlock.bats`: same isolation guarantee
- [ ] No hardcoded port 7777 remaining in either file
- [ ] Server startup/teardown in BATS `setup_file`/`teardown_file` hooks
- [ ] Total runtime under 60 seconds for each suite
- [ ] CI smoke pass confirmed (manually or via TASK-CI-001)

## Write Scope

- `tests/test-browser.bats`
- `tests/test-browser-warlock.bats`
- `tests/test_helper/` — shared browser fixture helpers if extracted

## Risk

Medium. Changing test scaffolding can mask real failures if teardown is too aggressive. Verifier must run both suites in a clean shell.

## Rollback

Revert test file changes. No production code touched.
