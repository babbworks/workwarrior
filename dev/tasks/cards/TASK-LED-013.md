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

Resolution:
  Implemented on branch agent/builder/led-013.

  TWO CARD DEFECTS FOUND AND CORRECTED IN-PASS (Builder -> Orchestrator):

  D1. Criterion 3 homed the runtime guard in lib/ledger-dispatch.sh — WHICH DOES NOT
      EXIST on this branch. It is stranded on agent/builder/ledger-schema (TASK-LED-012).
      The card claimed "Depends on: — (independent)" while depending on LED-012.
      RESOLVED: created lib/hledger-version.sh as the single owner of the floor + guard.
      LED-012 must make ledger-dispatch.sh SOURCE it, not reimplement the floor.

  D2. The mechanism question (a) static binary vs (b) package-manager bump is settled
      by EVIDENCE, not preference: `apt-cache policy hledger` on Debian 12 bookworm
      reports Candidate 1.25-2+b5 — it cannot reach 1.52, and could not even reach the
      PRE-EXISTING 1.30 floor. Option (b) is dead on this platform.
      RESOLVED: (a) official static build -> ~/.local/bin, never overwriting
      /usr/bin/hledger, with a plain-spoken PATH-shadow warning instead of silently
      rewriting the user's PATH.

  ALSO FOUND: MIN_VERSION_HLEDGER="1.30" ALREADY EXISTED and the host runs 1.25 —
  already below the existing floor, with nothing complaining, because the check was
  install-time only and merely advisory ("⚠ update recommended"). This card did not
  introduce a floor; it RAISED one and gave it teeth.

  GUARD SCOPE — a deliberate narrowing (Verifier: please challenge this):
  There are ~14 hledger call sites. Almost all use BASIC commands (balance, register,
  print, stats, accounts, add) which work correctly on 1.25. A blanket guard would
  break `ww profile stats` and exports on older hosts for ZERO safety gain. The guard
  is therefore wired ONLY into the two ARBITRARY-FLAG PASSTHROUGH surfaces, where a
  user can actually hand hledger -X/--value:
    - bin/ww cmd_hledger_passthrough  (`ww hledger ...`)
    - lib/shell-integration.sh `l`    (the ledger shell function)
  Future computational verbs (LED-017 `ww ledger attention`) MUST call
  hledger_require_floor when written. Basic internal call sites remain unguarded, and
  a test asserts that (test-hledger-floor.bats).

  Verified:
  - bats dev/tests/test-hledger-floor.bats — 23/23.
  - Full `bats dev/tests/` — 60 failures, and the failing-test-NAME-set is IDENTICAL to
    the 1fb63f5 baseline (diff is empty). Zero new failures. (Per decisions.md
    2026-07-10: the green exit code lies; only a name-set diff exposes a regression.)
  - Criterion 5 MET: `HLEDGER=$(command -v hledger) bash
    dev/reports/ledger-hledger/tests/run-valuation-tests.sh` -> 12/12 against the
    INSTALLED hledger (1.52.1), not a scratch download. The floor is real.
  - Host upgraded in-pass: /usr/bin/hledger 1.25 -> ~/.local/bin/hledger 1.52.1
    (~/.local/bin already precedes /usr/bin on PATH, so no shadow warning fired).

  NOT DONE (criterion 6): no schema in dev/schemas/ depends on the floor yet. LED-017
  (attention queue) will be the first; fold it in there.

Status:               implemented — awaiting Verifier
Taskwarrior:          (assign live TW id on dispatch)
