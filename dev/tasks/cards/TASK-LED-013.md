## TASK-LED-013: hledger version floor — upgrade, pin, and guard at runtime

Goal:                 The host runs hledger 1.25 — 27 releases behind. EVERY computational
                      result this program depends on (valuation, -X unit conversion, the
                      attention queue, roi, the fuller check suite) was verified on 1.52.1 and
                      is weak or ABSENT on 1.25. This card is the gate on Phases 3-4.

Depends on:           —  (independent; do early)

Evidence:             dev/reports/ledger-hledger/hledger-1.52-verification.md (16 capabilities)
                      dev/reports/ledger-hledger/tests/run-valuation-tests.sh (12/12 on 1.52.1)

Acceptance criteria:  1. Declare a MINIMUM REQUIRED VERSION: hledger >= 1.52. Recorded in
                         docs/INSTALL.md and lib/dependency-installer.sh.
                      2. lib/dependency-installer.sh installs/upgrades hledger to >= the floor.
                         Mechanism decision (Builder to brief before implementing):
                         (a) bundled static binary — 47MB, zero external dependency, we own the
                             version; or (b) package-manager bump with a version assertion —
                             lighter, but distro repos lag (that is HOW we got to 1.25).
                         Recommend (b) with a hard assertion + a clear failure message
                         pointing at the official release URL, and (a) only if (b) cannot
                         reach the floor on a supported platform.
                      3. RUNTIME GUARD: a version check that fails LOUDLY and EARLY with an
                         actionable message when hledger < floor. It MUST NOT silently degrade.
                         Home: lib/ledger-dispatch.sh (the single passthrough owner, landed by
                         TASK-LED-012).
                      4. The guard fires ONCE per session, not per invocation (no per-command
                         `hledger --version` fork).
                      5. `run-valuation-tests.sh` and `run-advanced-tests.sh` pass against the
                         INSTALLED hledger (not a scratch download) — proving the floor is real.
                      6. Version floor documented in dev/schemas/ if any contract depends on it.

Write scope:          lib/dependency-installer.sh
                      lib/ledger-dispatch.sh          (runtime guard — needs LED-012 landed)
                      docs/INSTALL.md
                      dev/tests/test-hledger-floor.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-hledger-floor.bats
                      bats dev/tests/            (full suite)
                      Manual: HLEDGER=<installed> bash dev/reports/ledger-hledger/tests/run-valuation-tests.sh
                              -> 12/12 (criterion 5)

Rollback:             git revert. The installed hledger binary stays — an upgrade is not harmful
                      to revert around.

Fragility:            MEDIUM. dependency-installer touches the install path. A guard that is too
                      aggressive breaks existing users on 1.25 — which is the POINT, but the
                      failure message must tell them exactly what to do.

Risk notes:           (Orchestrator) This is the highest-leverage, lowest-risk single change
                      available (research README §4 item 1). Everything computational is
                      downstream. Do it BEFORE Phase 3/4, not after — building the attention
                      queue against 1.25 means building against a tool that cannot do it.
                      (Builder) Brief the (a)/(b) mechanism choice before writing code.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
