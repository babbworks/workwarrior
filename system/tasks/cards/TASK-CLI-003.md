## TASK-CLI-003: Standardize help output contract

Goal:                 Make help text uniform in structure, examples, and flag documentation across commands.

Acceptance criteria:  1. All core domains provide consistent help sections.
                      2. Preferred aliases are clearly marked where both forms exist.
                      3. Help examples match actual command behavior.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/README.md
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       /Users/mp/ww/bin/ww help
                      /Users/mp/ww/bin/ww help profile
                      /Users/mp/ww/bin/ww help custom
                      rg -n "Usage:" /Users/mp/ww/bin/ww /Users/mp/ww/services

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/services/README.md /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/bin/ww

Risk notes:           Existing behavior affected: user-facing discoverability and guidance.
                      Tests currently covering write scope: help command manual checks + integration smoke.
                      Rollback verification: help text restores cleanly via revert.
                      Implementation evidence (2026-04-04): centralized help contract blocks in bin/ww for
                      profile/service/group/model/journal/ledger; singular-preferred + plural-alias markers
                      added for dual-form domains; top-level command descriptions updated to mark preferred
                      namespaces and aliases; services/README help topic guidance aligned to singular-first;
                      docs/usage-examples help section expanded.
                      Verification (2026-04-04): /Users/mp/ww/bin/ww help (pass),
                      /Users/mp/ww/bin/ww help profile (pass),
                      /Users/mp/ww/bin/ww help custom (pass),
                      rg -n "Usage:" /Users/mp/ww/bin/ww /Users/mp/ww/services (pass).

Status:               complete
