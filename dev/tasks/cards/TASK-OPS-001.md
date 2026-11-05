## TASK-OPS-001: Scoped transactional operations and inventor lenses

Goal:                 Provide the optional company backend with reliable event identity,
                      explicit context, concurrent participation and truthful returns.
Depends on:           Existing stream/actor analysis; owner authorization 2026-11-05.
Contract:             dev/schemas/operations-v1.md
Acceptance criteria:  1. Reads never initialize; every data call binds organization/instance/profile.
                      2. Same-key retries return one effect; changed input conflicts; interrupted writes roll back.
                      3. Two actors can share one assignment; starts, heartbeats, ends and returns stay distinct.
                      4. Source event identity is producer/source-ID, not timestamp coincidence.
                      5. Derived events do not feed density/signal calculations by default.
                      6. JSON is typed lens output; interval views bind a clock and reconstruct before clipping.
                      7. Returned execution is unreviewed and cannot confer external or MAKE authority.
                      8. Source tests, service help, docs and command syntax match; old runtime stays untouched.
Write scope:          services/operations/; bin/ww routing/help; services/README.md;
                      dev/tests/test_operations.py, test_lens_mathematics.py and test-operations.bats;
                      dev/schemas/operations-v1.md and lens-mathematics-v1.md; this card and generated index;
                      dev/TASKS.md, dev/logs/decisions.md, dev/config/command-syntax.yaml.
Tests required:       Python isolated operations suite; BATS operations wrapper;
                      smoke and service discovery; full BATS suite before any merge.
Rollback:             Revert selected source files; retain the separate operational store for audit.
Fragility:            bin/ww is serialized. No sync libraries or production profiles are changed.
Risk notes:           Inline roles/gates; local qualification only. No independent sign-off or release claimed.
                      Browser/ABC bindings require their own adapter verification; process status is not evidence acceptance.
Status:               in-review (focused contracts pass; legacy full-suite gate remains unresolved; no independent sign-off)
