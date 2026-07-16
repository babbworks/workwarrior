## TASK-CLI-003: Standardize help output contract

Goal:                 Make help text uniform in structure, examples, and flag documentation across commands.

Acceptance criteria:  1. All core domains provide consistent help sections.
                      2. Preferred aliases are clearly marked where both forms exist.
                      3. Help examples match actual command behavior.

Write scope:          ~/ww/bin/ww
                      ~/ww/services/README.md
                      ~/ww/docs/usage-examples.md
                      ~/ww/dev/config/command-syntax.yaml

Tests required:       ~/ww/bin/ww help
                      ~/ww/bin/ww help profile
                      ~/ww/bin/ww help custom
                      rg -n "Usage:" ~/ww/bin/ww ~/ww/services

Rollback:             git checkout ~/ww/bin/ww ~/ww/services/README.md ~/ww/docs/usage-examples.md ~/ww/dev/config/command-syntax.yaml

Fragility:            SERIALIZED: ~/ww/bin/ww

Risk notes:           Existing behavior affected: user-facing discoverability and guidance.
                      Tests currently covering write scope: help command manual checks + integration smoke.
                      Rollback verification: help text restores cleanly via revert.
                      Implementation evidence (2026-04-04): centralized help contract blocks in bin/ww for
                      profile/service/group/model/journal/ledger; singular-preferred + plural-alias markers
                      added for dual-form domains; top-level command descriptions updated to mark preferred
                      namespaces and aliases; services/README help topic guidance aligned to singular-first;
                      docs/usage-examples help section expanded.
                      Verification (2026-04-04): ~/ww/bin/ww help (pass),
                      ~/ww/bin/ww help profile (pass),
                      ~/ww/bin/ww help custom (pass),
                      rg -n "Usage:" ~/ww/bin/ww ~/ww/services (pass).

Status:               complete
