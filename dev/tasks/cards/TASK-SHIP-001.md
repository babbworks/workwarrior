## TASK-SHIP-001: Ship dev/ with workwarrior

Goal:                 Ship the dev control plane — substrate AND project record — so anyone
                      who receives workwarrior receives the means to evolve it, human or agent.
                      Supersedes TASK-STRUCT-1B's "stop shipping dev/" (decisions 2026-07-12).

Depends on:           TASK-STRUCT-1B (must be merged — this modifies the install path it created)

Decision:             dev/logs/decisions.md, 2026-07-12 ("dev/ SHIPS")

Context:              This does NOT reverse STRUCT-1A/1B — it is what they earned. Before 1A,
                      the 5 runtime UDA YAMLs lived inside system/, so it HAD to ship: it was
                      load-bearing. 1A moved them to config/; 1B proved by scratch-install that
                      no runtime path depends on dev/. The achievement was never "dev/ doesn't
                      ship" — it was that dev/ went from LOAD-BEARING to SHIPPABLE-BY-CHOICE.
                      We are now choosing to.

Acceptance criteria:  1. install.sh copies dev/ into the install dir (one `cp -r` alongside the
                         existing lib/, scripts/, bin/, resources/, config/, functions/, tools/
                         allowlist entries — the exclusion was by OMISSION, not by rule).
                      2. The install summary text lists dev/ among what was installed.
                      3. **The load-bearing property is PRESERVED and PROVEN: a scratch install
                         with dev/ subsequently DELETED must still fully work.** Run the
                         STRUCT-1B criterion-8 checks against an install with `rm -rf
                         $WW_INSTALL_DIR/dev`: `ww help`, `ww profile list`, `ww profile uda
                         list`, github-sync dry-run all succeed. dev/ ships, but nothing may
                         come to depend on it.
                      4. `dev/bin/wwctl` resolves in the INSTALLED layout (ww-init.sh already
                         points PATH at dev/bin with a `[[ -d ]]` guard — the guard stays).
                      5. Install size delta is measured and recorded in the resolution notes.
                      6. .gitignore / packaging exclusions (if any) do not strip dev/ from a
                         release tarball.

Write scope:          install.sh
                      dev/CLAUDE.md          (directory-map line — ALREADY updated 2026-07-12)
                      docs/INSTALL.md        (if it enumerates installed dirs)
                      dev/tests/test-install-ships-dev.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-install-ships-dev.bats
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: fresh scratch install -> dev/ present -> `wwctl status` runs.
                      Manual: SAME install, `rm -rf dev/` -> everything still works (criterion 3).

Rollback:             git revert (remove the one cp -r line). Trivially reversible.

Fragility:            LOW-MEDIUM. install.sh is the user's first contact with the product; a
                      broken install is the worst possible regression. But the change is one
                      additive line in an existing allowlist.

Risk notes:           (Orchestrator) Criterion 3 is the one that matters and it is
                      counterintuitive: we ship dev/ AND we prove the product still runs
                      without it. If a runtime path ever starts depending on shipped dev/,
                      we have silently re-created the load-bearing coupling that STRUCT-1A
                      existed to remove. Guard it with a permanent test, not a convention.
                      (Orchestrator) STRUCT-1B's card and verifier report assert "scratch
                      install ships config/ but NOT dev/" as a PASSED criterion. That
                      sign-off is NOT rewritten — records here are append-only. It is
                      superseded, and this card is the supersede.
                      (Builder) Adopters inherit our task board and decisions log. That is
                      intentional (a worked corpus is the best teaching material an agent can
                      get). No "clean board" mechanism is in scope.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
