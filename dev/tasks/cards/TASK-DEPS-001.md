## TASK-DEPS-001: The warrior fleet view — which instances are below floor?

Goal:                 A warrior spans instances. The moment a version floor exists, the obvious
                      question is "which of my instances are below it?" — and TODAY NOTHING CAN
                      ANSWER THAT. The registry records workwarrior's OWN version and nothing
                      about the toolchain.

                      This matters because an instance below the floor DOES NOT ERROR — it
                      computes wrong answers. A fleet needs to see that.

Depends on:           TASK-LED-013 (merged — config/dependencies.yaml + the toolchain stamp)

Context:              LED-013 already produced the raw material. `ww deps check` writes a
                      per-instance stamp ($WW_BASE/.state/deps.json) recording every tool's
                      version, floor, status (ok|below_floor|missing) and resolved path. It is
                      per-instance state, which is exactly what a cross-instance view needs.
                      The registry (~/.config/ww/registry/) knows each instance's install_path.
                      Join the two.

Acceptance criteria:  1. `ww deps check --all` iterates the instance registry, reads each
                         instance's stamp, and prints a fleet table:
                           INSTANCE   TOOL      VERSION  FLOOR   STATUS
                           factory-a  hledger   1.25     1.52    ✗ BELOW FLOOR
                           home       hledger   1.52.1   1.52    ok
                      2. An instance with NO stamp reports `unknown`, never `ok`. Absence of
                         evidence is not evidence of compliance.
                      3. A stale stamp (written against an older config/dependencies.yaml) is
                         reported as `stale`, not silently trusted — the manifest fingerprint is
                         already recorded in the stamp for exactly this.
                      4. `--format json` for the browser panel and the Warrior app.
                      5. Exit 1 if ANY instance is below a `hard` floor — so it can gate CI or a
                         fleet-wide preflight.
                      6. Read-only. It must never install or "fix" anything across instances.

Write scope:          services/  or bin/ww          (deps check --all)
                      lib/deps-state.sh             (cross-instance read helper)
                      lib/instance-registry.sh      (expose install_path iteration if not already)
                      dev/tests/test-deps-fleet.bats (new)

Tests required:       bats dev/tests/test-deps-fleet.bats
                      bash dev/scripts/check-regression.sh
                      Manual: two fake instances, one below floor -> table + exit 1.

Rollback:             git revert. Read-only reporting.

Fragility:            LOW. Reads the registry and per-instance stamps; writes nothing.

Risk notes:           (Orchestrator) This is the first concrete piece of the WARRIOR meta-identity
                      (a view across instances) to be backed by real data rather than a concept.
                      Keep it read-only: a fleet command that can mutate N instances at once is a
                      different, much more dangerous card.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
