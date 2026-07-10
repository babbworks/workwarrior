## TASK-STRUCT-1A: Decouple runtime config from system/config/ into config/

Goal:                 Move the 5 runtime YAML files out of the dev control plane
                      (system/config/) into the runtime config/ dir and repoint their
                      readers, so system/ becomes pure-dev and can be renamed (1B)
                      without any runtime coupling.

Acceptance criteria:  1. These 5 files are relocated via `git mv` (history preserved),
                         present under config/ and absent from system/config/:
                         label-uda-map.yaml, body-uda-map.yaml,
                         service-uda-registry.yaml, uda-indicator-map.yaml,
                         uda-color-map.yaml.
                      2. lib/field-mapper.sh lines 10-11 read from `../config/` (not
                         `../system/config/`); no `system/config` string remains in the file.
                      3. services/profile/subservices/profile-uda.sh lines 26-28 read from
                         `${_WW_BASE}/config/` (not `${_WW_BASE}/system/config/`).
                      4. The 5 dev-only files stay put (command-syntax.yaml, gates.yaml,
                         roles.yaml, serialization-paths.txt, test-baseline.yaml).
                      5. `git grep -n 'system/config' bin/ lib/ services/` returns nothing
                         for the 5 moved files.
                      6. Tests pass (see Tests required); full suite at/above the known
                         ~29-failure baseline — no NEW failures.

Write scope:          config/label-uda-map.yaml            (git mv from system/config/)
                      config/body-uda-map.yaml             (git mv)
                      config/service-uda-registry.yaml     (git mv)
                      config/uda-indicator-map.yaml        (git mv)
                      config/uda-color-map.yaml            (git mv)
                      lib/field-mapper.sh
                      services/profile/subservices/profile-uda.sh

Tests required:       bats tests/test-github-sync.bats
                      bash tests/run-integration-tests.sh
                      bats tests/
                      Manual: `ww profile uda list` (exercises profile-uda.sh indicator/
                        color maps) renders without error
                      Manual: a github-sync dry-run exercising field-mapper.sh label mapping

Rollback:             git mv the 5 files back to system/config/ and
                      `git checkout lib/field-mapper.sh services/profile/subservices/profile-uda.sh`
                      (all changes are path-string edits + moves; fully reversible)

Fragility:            HIGH FRAGILITY: lib/field-mapper.sh — sync correctness layer.
                      Orchestrator approval: GRANTED as part of this card (restructure spec
                      2026-07-09, "Decouple properly" decision). Extended risk brief +
                      integration tests required (Tests required above). Independent Verifier
                      per Agent Execution Model (feature-delivery.md).

Risk notes:           (Orchestrator) field-mapper.sh reads via `${_FM_DIR}/../system/config/`
                      (relative to lib/); new path is `${_FM_DIR}/../config/`. profile-uda.sh
                      reads via `${_WW_BASE}/system/config/`; new path `${_WW_BASE}/config/`.
                      config/ is ALREADY copied by install.sh:321, so relocation makes these
                      files ship correctly and pre-satisfies the shipping need that 1B removes.
                      Verify path resolution in BOTH repo layout and an installed layout.
                      (Builder) fill pre-flight brief before touching field-mapper.sh.

Resolution:
  Implemented on branch agent/builder/struct-1a (commit 9154879). git mv (R100) the 5
  runtime YAMLs system/config/ -> config/; repointed lib/field-mapper.sh (2 lines) and
  services/profile/subservices/profile-uda.sh (3 lines).
  Verified: full bats suite 605/60 IDENTICAL to master (byte-identical failing-test set,
  zero new failures); field-mapper + profile-uda unit coverage passes via new path; write
  scope clean; Gate E clean. Sign-off: system/reports/verifier-TASK-STRUCT-1A.md.
  PRE-MERGE CONDITIONS (do not merge to master until cleared):
    N1 — run-integration-tests.sh in an installed env (active profile + gh auth).
    N2 — 8 doc-prose system/config/ references (docs/) reconciled by Part 4.

Status:               verified — impl + local verify complete; N1/N2 pending before merge
Taskwarrior:          (assign live TW id on dispatch) status:in-review
