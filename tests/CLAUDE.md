# tests/CLAUDE.md — Workwarrior Test Suite

Read this before writing, modifying, or running tests. It covers the test structure, how to run by change type, baseline failures, and conventions.

---

## Test Runner

All BATS tests are run from the project root:

```bash
bats tests/               # full suite (~370 tests across 25 files)
bats tests/<file>.bats    # single file
```

Shell integration tests (non-BATS):

```bash
bash tests/test-foundation.sh
bash tests/test-scripts-integration.sh
bash tests/test-service-discovery.sh
bash tests/test-questions-service.sh
bash tests/test-hook-integration.sh
```

GitHub sync integration (requires `gh` CLI authenticated to test account):

```bash
bash tests/run-integration-tests.sh
```

**Never run integration tests against a real work profile.** Use a dedicated test profile.

---

## Run by Change Type

| Change type | Required tests |
|---|---|
| Any `lib/` change | `bats tests/` |
| Any `services/` change | `bats tests/test-service-discovery.bats` + `bash tests/test-service-discovery.sh` + `bats tests/` |
| Profile behavior | `bats tests/test-directory-structure.bats` + `bats tests/test-backup-portability.bats` + `bats tests/` |
| `lib/shell-integration.sh` | `bats tests/test-shell-functions.bats` + `bats tests/test-alias-creation.bats` + `bats tests/` |
| `bin/ww` | `bats tests/` + manual: `ww help`, `ww profile list` |
| GitHub sync files | `bash tests/run-integration-tests.sh` + `bats tests/test-github-sync.bats` + `bats tests/test-sync-state.bats` + `bats tests/` |

The select-tests helper encodes this matrix:

```bash
bash system/scripts/select-tests.sh <change-type> --run
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`

---

## Known Baseline Failures (~67)

These are **pre-existing, not regressions**. Do not chase them.

| Test file | Failing tests | Reason |
|---|---|---|
| `test-timewarrior-hook-installation.bats` | 13 | Hook install edge cases not covered |
| `test-timewarrior-hook-environment.bats` | 10 | Hook environment edge cases not covered |
| `test-taskrc-properties.bats` | 11 | taskrc property assertions not yet enforced |
| `test-taskrc-copy.bats` | 8 | taskrc copy edge cases |
| `test-profile-management-properties.bats` | 7 | Profile property edge cases not enforced |
| `test-default-configuration.bats` | 4 | Default config property assertions |
| `test-taskrc-copy-path-update.bats` | 4 | Path rewrite on taskrc copy not implemented |
| `test-taskrc-creation.bats` | 2 | taskrc creation edge cases |
| `test-profile-name-validation.bats` | 2 | Strict name validation not yet enforced |
| `test-journal-multiple-support.bats` | 2 | Multiple journal edge cases |
| `test-data-isolation.bats` | 1 | Data isolation edge case |
| `test-directory-structure.bats` | 1 | Directory structure edge case |
| `test-journal-addition.bats` | 1 | Journal addition edge case |
| `test-taskrc-path-configuration.bats` | 1 | Path config edge case |

When running the suite, a clean run will show these ~67 failures. Any new failures on top of this baseline are regressions and must be fixed before merge.

---

## Test File Index

### GitHub Sync (HIGH FRAGILITY — 42 tests total)

| File | What it covers | Count |
|---|---|---|
| `test-github-sync.bats` | `check_gh_cli`, `github_get_issue`, `detect_task_changes`, `detect_github_changes` | 21 |
| `test-sync-state.bats` | `init_state_database`, `save_sync_state`, `get_sync_state`, `remove_sync_state` | 21 |

### TaskWarrior / Profile (core)

| File | Count |
|---|---|
| `test-taskrc-copy.bats` | 23 |
| `test-taskrc-creation.bats` | 17 |
| `test-taskrc-path-configuration.bats` | 17 |
| `test-taskrc-copy-path-update.bats` | 17 |
| `test-taskrc-properties.bats` | 15 |
| `test-directory-structure.bats` | 13 |
| `test-profile-management-properties.bats` | 7 |
| `test-profile-name-validation.bats` | 14 |
| `test-installation.bats` | 17 |
| `test-data-isolation.bats` | 1 |
| `test-backup-portability.bats` | 1 |
| `test-env-atomic-update.bats` | 1 |
| `test-config-path-updates.bats` | 3 |
| `test-default-configuration.bats` | 4 |

### Shell / Alias / Service

| File | Count |
|---|---|
| `test-shell-functions.bats` | 19 |
| `test-alias-creation.bats` | 15 |
| `test-service-discovery.bats` | 19 |

### Journal / Ledger

| File | Count |
|---|---|
| `test-journal-initialization.bats` | 20 |
| `test-journal-addition.bats` | 20 |
| `test-journal-multiple-support.bats` | 15 |
| `test-ledger-initialization.bats` | 14 |
| `test-ledger-naming-convention.bats` | 13 |

### TimeWarrior Hook

| File | Count |
|---|---|
| `test-timewarrior-hook-installation.bats` | 19 |
| `test-timewarrior-hook-environment.bats` | 16 |

---

## Test Helper

All BATS tests load from `test_helper/`:

```bash
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
```

Standard test setup pattern:

```bash
setup() {
    export TEST_MODE=1
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    # mock gh CLI via PATH prepend to _WW_MOCK_BIN
}

teardown() {
    rm -rf "${WORKWARRIOR_BASE}"
    rm -rf "${_WW_MOCK_BIN}"
}
```

For sync tests, `gh` is mocked by writing a stub to `_WW_MOCK_BIN` and prepending it to `PATH`. Never call real GitHub in unit tests.

---

## Rules

- Every behavior change requires a new or updated BATS test — this is Gate B.
- New tests go in the most specific existing file, or a new `test-<topic>.bats` if none fits.
- Test files follow `test-<component>.bats` naming.
- Sync integration tests that touch real GitHub must use a dedicated test profile and never the `work` or `personal` profiles.
- Run the baseline *before* your change to establish expected failure count, then again after to confirm no new failures.
