# dev/tests/CLAUDE.md — Workwarrior Test Suite

Read this before writing, modifying, or running tests. It covers the test structure, how to run by change type, baseline failures, and conventions.

---

## Gate Zero: Smoke Test (Always Run First)

Before any targeted or full run, start here:

```bash
bats dev/tests/test-smoke.bats   # ~5 seconds
```

This catches environmental and sourcing failures that produce misleading cascade failures in deeper tests:
- Lib files source cleanly (`core-utils.sh`, `sync-permissions.sh`)
- `log_error` accepts a single string — confirms correct lib is sourced (not `logging.sh` which has a 4-arg structured signature)
- `grep` no-match does not abort a `set -euo pipefail` script — must use `|| true`
- `task config` with `rc.confirmation=no` suppresses interactive prompts in non-TTY contexts
- `task config` value is readable back via `grep` from `.taskrc` (format sanity)
- `sync-permissions` write→read round-trip
- `bin/ww profile help` exits 0 and includes `uda`
- `bin/ww issues uda` exposes ww-native subcommands (`list/install/group/help`)

**If any smoke test fails, stop. Fix the environment before running anything else.**

---

## Test Runner

All BATS tests are run from the project root:

```bash
bats dev/tests/               # full suite (~450 tests across 26 files)
bats dev/tests/<file>.bats    # single file
```

Shell integration tests (non-BATS):

```bash
bash dev/tests/test-foundation.sh
bash dev/tests/test-scripts-integration.sh
bash dev/tests/test-service-discovery.sh
bash dev/tests/test-questions-service.sh
bash dev/tests/test-hook-integration.sh
```

GitHub sync integration (requires `gh` CLI authenticated to test account):

```bash
bash dev/tests/run-integration-tests.sh
```

**Never run integration tests against a real work profile.** Use a dedicated test profile.

---

## Run by Change Type

The recommended sequence for every change: **smoke → targeted → full**.

| Step | Command | When |
|---|---|---|
| 0 — always | `bats dev/tests/test-smoke.bats` | Before anything else |
| 1 — targeted | See table below | After smoke passes |
| 2 — full | `bats dev/tests/` | Before merge |

### Targeted suites by change type

| Change type | Required targeted tests |
|---|---|
| Any `lib/` change | `bats dev/tests/test-smoke.bats` + `bats dev/tests/` |
| `lib/sync-permissions.sh` | `bats dev/tests/test-smoke.bats` + `bats dev/tests/test-profile-uda.bats` |
| `services/profile/subservices/profile-uda.sh` | `bats dev/tests/test-smoke.bats` + `bats dev/tests/test-profile-uda.bats` |
| Any other `services/` change | `bats dev/tests/test-service-discovery.bats` + `bash dev/tests/test-service-discovery.sh` + `bats dev/tests/` |
| Profile behavior | `bats dev/tests/test-directory-structure.bats` + `bats dev/tests/test-backup-portability.bats` + `bash dev/tests/test-scripts-integration.sh` + `bats dev/tests/` |
| `lib/shell-integration.sh` | `bats dev/tests/test-shell-functions.bats` + `bats dev/tests/test-alias-creation.bats` + `bats dev/tests/` |
| `bin/ww` | `bats dev/tests/test-smoke.bats` + `bats dev/tests/` + manual: `ww help`, `ww profile list` |
| GitHub sync files | `bash dev/tests/run-integration-tests.sh` + `bats dev/tests/test-github-sync.bats` + `bats dev/tests/test-sync-state.bats` + `bats dev/tests/` |

The select-tests helper encodes this matrix:

```bash
bash dev/scripts/select-tests.sh <change-type> --run
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`

---

## The Regression Gate (TASK-TEST-004)

**Do not count failures. Diff their NAMES against the committed baseline.**

```bash
bash dev/scripts/check-regression.sh     # exit 1 on any NEW failing test name
```

- **`dev/tests/known-failures.txt`** is the baseline — **60 known failures**, committed as data,
  verified byte-identical across three consecutive full runs.
- The gate reports tests that have started **passing**, too, so the baseline cannot quietly rot.
- **Never add a name to `known-failures.txt` to make the gate pass.** Fix the test, or fix the code.

### Why the old numbers here were dangerous

This section used to claim `~19`, and `~29` elsewhere, across "26 files". The real suite is
**665 tests across 42 files**. Worse, the counts were *unstable*: the suite was
nondeterministic, and the baseline differed from itself between consecutive runs of identical
code (60, then 64). **A Verifier following the old guidance would have cleared a genuine
regression as "baseline".**

The cause is fixed (TASK-TEST-004): eight suites shared one `test-profiles/` directory at the
repo root and each teardown `rm -rf`'d it; the browser suites raced on hardcoded ports. Tests
now use `$BATS_TEST_TMPDIR` and kernel-assigned ports.

**The lesson generalises, and it is the same one that produced `wwctl index`:**

> Never hand-maintain a mirror of a fact that lives elsewhere. Derive it, or point at it.

---

## Known Pitfalls (Lessons from Session 6)

These patterns produce silent failures that look like logic bugs. Check for them first when a test shows "expected success but got status: 1" with no clear message.

| Pitfall | Symptom | Fix |
|---|---|---|
| Sourcing `lib/logging.sh` in a service script | `log_error` called with one arg → `$2: unbound variable` | Source `lib/core-utils.sh` instead; its `log_error` takes a single message string |
| `task config` without `rc.confirmation=no` | Script hangs or exits non-zero in non-TTY (no stdin) | Always use `task rc.confirmation=no config ...` |
| `grep` no-match in `set -euo pipefail` pipeline | Script exits 1 silently at the grep | Append `\| ... \| grep ... \| ... \|\| true` to the pipeline |
| `task _get rc.uda.<name>.type` needing TASKDATA | Returns empty or errors without a data dir | Read directly from `.taskrc` with `grep -E '^uda\.<name>\.type=' \| cut -d= -f2` |
| `bin/ww` tests with WARRIOR_PROFILE set to a non-existent profile | `ww` rejects non-existent profile at startup | Use `env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE` for help/routing tests |

---

## Test File Index

### Pre-flight

| File | What it covers | Count |
|---|---|---|
| `test-smoke.bats` | Lib sourcing, `log_error` sig, grep/pipefail trap, `task config` confirmation, sync-permissions round-trip, `bin/ww` routing | 12 |

### UDA Management (TASK-UDA-001+) / Urgency (TASK-URG-001)

| File | What it covers | Count |
|---|---|---|
| `test-profile-uda.bats` | `sync-permissions` unit (11), `profile-uda` list/add/remove/group/perm/help (23) | 34 |
| `test-profile-urgency.bats` | `urgency` help/show/set/reset/explain/routing | 30 |

### GitHub Sync (HIGH FRAGILITY)

| File | What it covers | Count |
|---|---|---|
| `test-github-sync.bats` | `check_gh_cli`, `github_get_issue`, `detect_task_changes`, `detect_github_changes`, `map_uda_to_labels`, `map_labels_to_udas`, `serialize_udas_to_body_block`, `parse_body_block_to_udas`, round-trip | 50 |
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

### Interactive prompt testing

For scripts that use `read -rp`, pipe input via `printf` into `bash`:

```bash
# Drive an interactive wizard: name=goals, type=string, label=Goals, values=(empty), group=(skip)
run bash -c "printf 'goals\nstring\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add"
```

Input lines correspond to each `read` prompt in order. Use `\n` for Enter (accept default).
Trailing newlines skip optional prompts. Test the minimal path first, then add value/group variants.

For sync tests, `gh` is mocked by writing a stub to `_WW_MOCK_BIN` and prepending it to `PATH`. Never call real GitHub in unit tests.

### task config in tests

Always suppress the confirmation prompt — task asks "Are you sure? (yes/no)" in non-TTY contexts:

```bash
TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.myfield.type string
```

Read values back with grep, not `task _get` (which requires a valid TASKDATA directory):

```bash
type=$(grep -E '^uda\.myfield\.type=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
```

---

## Rules

- Every behavior change requires a new or updated BATS test — this is Gate B.
- Always run `test-smoke.bats` first. If it fails, fix the environment before proceeding.
- New tests go in the most specific existing file, or a new `test-<topic>.bats` if none fits.
- Test files follow `test-<component>.bats` naming.
- UDA-related tests (indicators, colors, urgency) all go in `test-profile-uda.bats` — keep UDA coverage co-located.
- Sync integration tests that touch real GitHub must use a dedicated test profile and never the `work` or `personal` profiles.
- Run the baseline *before* your change to establish expected failure count, then again after to confirm no new failures.
