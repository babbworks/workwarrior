## TASK-CLI-004: Add deprecation and compatibility layer

Goal:                 Preserve legacy command forms while nudging users to preferred syntax.

Acceptance criteria:  1. Legacy commands still execute successfully.
                      2. Deprecation warnings identify preferred replacements.
                      3. Deprecation matrix is documented in CSSOT and docs.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/core-utils.sh
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-scripts-integration.sh
                      /Users/mp/ww/bin/ww journals list
                      /Users/mp/ww/bin/ww journal list

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/lib/core-utils.sh /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/bin/ww

Risk notes:           Existing behavior affected: backward compatibility paths.
                      Tests currently covering write scope: integration scripts and manual alias checks.
                      Rollback verification: compatibility hooks revert with dispatcher rollback.
                      Implementation evidence (2026-04-04): added compatibility nudge helpers in
                      lib/core-utils.sh and bin/ww; plural/legacy aliases continue to route successfully
                      while emitting preferred-syntax warnings; plural help-topic aliases also emit nudges.
                      Added deprecation matrix in system/config/command-syntax.yaml and compatibility section
                      in docs/usage-examples.md.
                      Verification (2026-04-04): bats /Users/mp/ww/tests/test-scripts-integration.sh (pass),
                      /Users/mp/ww/bin/ww journals list (pass with deprecation warning),
                      /Users/mp/ww/bin/ww journal list (pass).

Status:               complete

## Wrap Up Edits

- Decision (2026-04-04): Deprecation warnings are optional and may be removed in a future pass if both singular and plural command forms remain officially supported long-term.
- Follow-up note: If this decision is ratified permanently, remove `nudge_preferred_syntax` call sites in `bin/ww` while retaining alias routing behavior.
