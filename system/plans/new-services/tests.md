# Service Concept: Tests

## Purpose

A profile-aware test runner service. Manages and executes test suites associated with
a profile or project — not just workwarrior's own BATS tests, but any test suite the
user maintains in their work context (scripts, BATS, shell assertions, custom runners).

The core problem it solves: developers using workwarrior profiles for project work have
no way to tie test suites to a profile, track pass/fail history, or run tests in the
correct environment without manually setting paths and env vars each time.

---

## CLI Shape (rough)

```
ww tests run    [<suite>] [-- <extra args>] [--print]  — run suite(s); extra args passed through to command
ww tests list                                           — list suites with last-run status (PASS/FAIL/never)
ww tests add    <name> <command>                        — register a suite
ww tests remove <name>                                  — deregister a suite
ww tests show   [<suite>]                              — show last result artifact
ww tests history [<suite>]                             — list all result artifacts for suite
```

Extra args: everything after `--` is appended to the suite's registered command verbatim.
`ww tests list` shows last run status with clear PASS/FAIL/NEVER markers — failures visually
distinct (e.g. `[FAIL]` prefix, non-zero exit surfaced inline).

---

## Data Model

Suite registry at `profiles/<name>/tests/suites.yaml`:

```yaml
suites:
  - name: unit
    command: bats tests/unit/
  - name: integration
    command: ./tests/run-integration.sh
  - name: lint
    command: shellcheck lib/*.sh
```

Result artifacts at `profiles/<name>/tests/results/YYYY-MM-DD-HH-MM-<suite>.md`.
Each artifact records: suite name, command run, exit code, stdout/stderr, duration.

`--print`: stdout only, no artifact written.

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Suite registry and result path resolution |

Suite commands run in the profile's environment (TASKRC, TASKDATA, etc. already set).
YAML registry parsed with `yq` or `awk` section reader (same pattern as journals service).

No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Not a replacement for workwarrior's own BATS suite in `tests/` — that is the project's
  internal test harness and runs independently
- This service is for the *user's* test suites within a profile/project context
- Complements `daily` and `reports` — test results could appear in daily review or reports

---

## Deferred to Tier 2

- `ww tests watch <suite>` — continuous re-run on file change; parked pending use case.

---

## Tier Estimate

Tier 1: YAML registry, run + capture to artifact, extra arg passthrough, PASS/FAIL/NEVER
in list, show/history subcommands.
Tier 2: watch mode, cross-suite aggregation in reports, CI hooks.

---

## Status

ratified — ready for task card when pipeline slot opens
