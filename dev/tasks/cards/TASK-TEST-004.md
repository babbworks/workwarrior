## TASK-TEST-004: The BATS suite is nondeterministic — the regression gate is inoperable

Goal:                 `dev/logs/decisions.md` (2026-07-10) mandates the regression gate for any
                      non-trivial change: "the green exit code lies; only a failing-test-NAME-set
                      diff against master exposes it."

                      THAT GATE CURRENTLY DOES NOT WORK. The baseline differs from ITSELF.

Depends on:           —

Evidence (measured 2026-07-13, TASK-LED-013 verification):
  Identical code, same machine, consecutive full runs of `bats dev/tests/`:
    - master/base, run 1:  60 failures
    - master/base, run 2:  64 failures     <- differs from itself
    - led-013,     run A:  76 failures (31 Property)
    - led-013,     run B:  67 failures (22 Property)  <- differs from itself

  A name-set diff between any two single runs therefore reports 4-12 phantom
  "regressions" that are pure noise. During LED-013 this cost a full verification cycle
  and nearly produced a false FAIL against a clean change.

Two identified sources (there may be more):
  1. SHARED MUTABLE STATE — several suites write to a single `test-profiles/` directory
     at the REPO ROOT (`dev/tests/../../test-profiles`), not to `$BATS_TEST_TMPDIR`.
     Leftovers from a previous run make `teardown`'s `rm -rf "$TEST_PROFILES_DIR"` fail,
     which cascades into unrelated failures. Suites affected include
     test-timewarrior-hook-installation.bats (Property 15/16/17/18) and the profile-copy
     property suites. In ISOLATION these same suites are stable (18 passed / 1 failed,
     identical on base and on the change).
  2. BROWSER SERVER TESTS — `browser status`, `ww browser stop`, `POST /cmd`, `POST
     /profile` flap between runs. Presumably a port/timing race.

Acceptance criteria:  1. Every suite writes ONLY under `$BATS_TEST_TMPDIR`. No test writes to
                         the repo root. Grep-assert this: no test file may reference
                         `test-profiles` at a path outside BATS_TEST_TMPDIR.
                      2. Browser suites are isolated (ephemeral port, deterministic
                         start/stop barrier) or explicitly quarantined behind a tag.
                      3. **`bats dev/tests/` run three times consecutively on unchanged code
                         produces a BYTE-IDENTICAL failing-test-name-set.** This is the
                         acceptance test. Nothing else matters.
                      4. The ~29 known-baseline failures are captured in a checked-in
                         `dev/tests/known-failures.txt`, so the gate becomes a diff against a
                         COMMITTED list rather than a re-measured run.
                      5. `dev/scripts/` gains a `check-regression.sh` that runs the suite and
                         diffs against that committed list, exiting 1 on any new name.

Write scope:          dev/tests/*.bats            (isolation fixes)
                      dev/tests/known-failures.txt (new)
                      dev/scripts/check-regression.sh (new)
                      dev/tests/CLAUDE.md         (document the gate)

Tests required:       The acceptance test IS criterion 3: three consecutive identical runs.

Rollback:             git revert. Test-only.

Fragility:            LOW to change, HIGH in consequence. Until this lands, NO large change can
                      be honestly verified against regression, and every Verifier is forced to
                      argue from mechanism rather than measurement.

Risk notes:           (Orchestrator) This is not cosmetic and it is not a "nice to have". The
                      repo's stated merge gate (Gate B) depends on a measurement that is
                      currently noise. TASK-LED-013 could only be verified by ruling out
                      mechanisms by hand — that does not scale, and the next change may not be
                      so easy to reason about. Prioritise before Phase 1 lands, since the STRM
                      cards all touch a shared dispatcher and will need exactly this gate.

Resolution:
  Implemented on agent/builder/test-004 (merged 2026-07-13).
  8 suites shared ONE test-profiles/ dir at the REPO ROOT and each teardown rm -rf'd it;
  browser tests raced on hardcoded ports with a teardown that killed without waiting.
  Repointed at $BATS_TEST_TMPDIR; kernel-assigned free port per test; PIDs recorded;
  teardown waits for death.
  ACCEPTANCE MET: three consecutive full runs produce a BYTE-IDENTICAL failing-name-set
  (60 each). Was 60 then 64 on identical code.
  dev/tests/known-failures.txt (the committed baseline) + dev/scripts/check-regression.sh
  (the gate; exits 1 on any NEW failing name, and reports newly-PASSING tests so the
  baseline cannot rot).
  It has already earned its keep: it caught a genuine break during LED-012.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
