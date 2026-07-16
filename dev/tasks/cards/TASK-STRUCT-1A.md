## TASK-STRUCT-1A: Decouple runtime config from dev/config/ into config/

Goal:                 Move the 5 runtime YAML files out of the dev control plane
                      (dev/config/) into the runtime config/ dir and repoint their
                      readers, so dev/ becomes pure-dev and can be renamed (1B)
                      without any runtime coupling.

Acceptance criteria:  1. These 5 files are relocated via `git mv` (history preserved),
                         present under config/ and absent from dev/config/:
                         label-uda-map.yaml, body-uda-map.yaml,
                         service-uda-registry.yaml, uda-indicator-map.yaml,
                         uda-color-map.yaml.
                      2. lib/field-mapper.sh lines 10-11 read from `../config/` (not
                         `../dev/config/`); no `dev/config` string remains in the file.
                      3. services/profile/subservices/profile-uda.sh lines 26-28 read from
                         `${_WW_BASE}/config/` (not `${_WW_BASE}/dev/config/`).
                      4. The 5 dev-only files stay put (command-syntax.yaml, gates.yaml,
                         roles.yaml, serialization-paths.txt, test-baseline.yaml).
                      5. `git grep -n 'dev/config' bin/ lib/ services/` returns nothing
                         for the 5 moved files.
                      6. Tests pass (see Tests required); full suite at/above the known
                         ~29-failure baseline — no NEW failures.

Write scope:          config/label-uda-map.yaml            (git mv from dev/config/)
                      config/body-uda-map.yaml             (git mv)
                      config/service-uda-registry.yaml     (git mv)
                      config/uda-indicator-map.yaml        (git mv)
                      config/uda-color-map.yaml            (git mv)
                      lib/field-mapper.sh
                      services/profile/subservices/profile-uda.sh

Tests required:       bats dev/tests/test-github-sync.bats
                      bash dev/tests/run-integration-tests.sh
                      bats dev/tests/
                      Manual: `ww profile uda list` (exercises profile-uda.sh indicator/
                        color maps) renders without error
                      Manual: a github-sync dry-run exercising field-mapper.sh label mapping

Rollback:             git mv the 5 files back to dev/config/ and
                      `git checkout lib/field-mapper.sh services/profile/subservices/profile-uda.sh`
                      (all changes are path-string edits + moves; fully reversible)

Fragility:            HIGH FRAGILITY: lib/field-mapper.sh — sync correctness layer.
                      Orchestrator approval: GRANTED as part of this card (restructure spec
                      2026-07-09, "Decouple properly" decision). Extended risk brief +
                      integration tests required (Tests required above). Independent Verifier
                      per Agent Execution Model (feature-delivery.md).

Risk notes:           (Orchestrator) field-mapper.sh reads via `${_FM_DIR}/../dev/config/`
                      (relative to lib/); new path is `${_FM_DIR}/../config/`. profile-uda.sh
                      reads via `${_WW_BASE}/dev/config/`; new path `${_WW_BASE}/config/`.
                      config/ is ALREADY copied by install.sh:321, so relocation makes these
                      files ship correctly and pre-satisfies the shipping need that 1B removes.
                      Verify path resolution in BOTH repo layout and an installed layout.
                      (Builder) fill pre-flight brief before touching field-mapper.sh.

Resolution:
  Implemented on branch agent/builder/struct-1a (commit 9154879). git mv (R100) the 5
  runtime YAMLs dev/config/ -> config/; repointed lib/field-mapper.sh (2 lines) and
  services/profile/subservices/profile-uda.sh (3 lines).
  Verified: full bats suite 605/60 IDENTICAL to master (byte-identical failing-test set,
  zero new failures); field-mapper + profile-uda unit coverage passes via new path; write
  scope clean; Gate E clean. Sign-off: dev/reports/verifier-TASK-STRUCT-1A.md.
  PRE-MERGE CONDITIONS (do not merge to master until cleared):
    N1 — run-integration-tests.sh in an installed env (active profile + gh auth).
    N2 — 8 doc-prose dev/config/ references (docs/) reconciled by Part 4.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch) status:in-review
