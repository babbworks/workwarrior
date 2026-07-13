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

Verifier round 1 (dev/reports/verifier-TASK-LED-013.md): FAIL, 5 findings.
  F1 HIGH  — installer 404s on Linux ARM (fabricated URL for an asset upstream does not
             build) and serves x86 to every Apple Silicon Mac (Darwin:* swallowed arm64).
  F2 MED-HI— no checksum on a downloaded executable.
  F3 MED   — criterion 4 unmet: WW_HLEDGER_FLOOR_OK cannot cross sibling processes, so
             every `ww hledger` forked `hledger --version`.
  F4 LOW   — curl assumed, never checked.
  F5 LOW   — dead `run` line in a test; a fallback floor literal = second source of truth.

Round 2 — ALL FIVE CLOSED, structurally rather than by patching:

  The root cause of F1 and F2 was that the platform/asset matrix lived as STRING LITERALS
  BURIED IN SHELL. A 23/23 suite missed both, because the tests verified the logic the
  author was thinking about and not the URLs he was not. So the fix is to make those facts
  DATA:

  NEW config/dependencies.yaml  — the toolchain manifest. Floors, pins, per-platform assets,
      SHA-256s, enforcement (hard|advisory), and which package managers are `unsupported`
      for a tool. F1 and F2 are now UNREPRESENTABLE, not merely fixed: an unsupported
      platform CANNOT produce a URL (asserted), and every asset MUST carry a 64-hex digest
      (asserted).
  NEW lib/deps-manifest.sh      — the SINGLE owner of that file (the ledgers.yaml
      five-parser rule). Real asset names verified against the upstream release API.
  NEW lib/deps-state.sh         — the toolchain stamp. THE `apt update` MODEL: `ww deps
      check` probes the binaries once and writes the stamp; the runtime guard READS the
      stamp and forks NOTHING. Closes F3 properly instead of amending the criterion away.
      Self-heals with exactly one probe if the stamp is absent, and is invalidated when the
      manifest changes (a raised floor must never be stamped `ok` against the old one).
  lib/hledger-version.sh        — reduced to a thin shim over the above, so the two already-
      wired call sites keep a stable name.
  lib/dependency-installer.sh   — floor now DERIVED from the manifest; a missing manifest is
      FATAL, not a guessed default (F5). Install routing is manifest-driven, not an
      hledger special-case.

  Found and fixed IN-PASS (not in the original findings): deps_state_refresh aborted under
  `set -e` when ANY tool was absent — `command -v` returns 1, and a failing command
  substitution inside an assignment fails the assignment. Recording that a tool is absent
  IS the job; it must never be the thing that breaks the job. Regression-tested.

  Tests (43/43, deterministic):
    test-deps-manifest.bats 18/18 — F1 platform matrix (mac-arm64 != mac-x64; linux-arm64
      yields NO url), F2 (64-hex digests; install REFUSES on mismatch and leaves nothing
      behind), F4, F5, malformed-manifest-is-fatal.
    test-deps-state.bats     9/9  — F3 TRIPWIRE: the fake binary records its own
      invocations; ten guard calls after a fresh stamp leave ZERO traces. This PROVES the
      fork is gone rather than asserting it should be.
    test-hledger-floor.bats 16/16 — guard wiring, scope, 1.9 < 1.52.

  End-to-end: checksum-verified install of the real 1.52.1 artifact -> stamp written ->
  run-valuation-tests.sh 12/12 against the INSTALLED binary. Host is on 1.52.1.

  REGRESSION GATE COULD NOT BE RUN — see TASK-TEST-004. The suite is NONDETERMINISTIC:
  identical code, consecutive runs, base = 60 then 64 failures; led-013 = 76 then 67. The
  baseline differs from ITSELF, so the mandated name-set diff reports phantom regressions.
  What IS certified: 43/43 deterministic on this change's surface; zero failures anywhere
  touching deps/hledger/floor/install; and the two mechanisms by which this change could
  reach the flapping profile/hook suites were ruled out by execution (profile-manager never
  sources dependency-installer; the fatal-manifest path does not trigger). Those suites are
  stable in ISOLATION and identical on base and on this branch (18 passed / 1 failed).

Status:               implemented — Verifier round 2 pending; blocked on TASK-TEST-004 for a
                      trustworthy regression gate
Taskwarrior:          (assign live TW id on dispatch)
