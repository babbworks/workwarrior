## TASK-QUAL-002: Automate docs and help parity checks

Goal:                 Enforce Gate C by detecting mismatch between command behavior, help text, and docs/CSSOT.

Acceptance criteria:  1. A parity-check script compares help output against documented command entries.
                      2. Parity failures are reported with actionable diff references.
                      3. Verifier workflow requires parity pass before completion.

Write scope:          ~/ww/dev/scripts/check-parity.sh
                      ~/ww/dev/config/command-syntax.yaml
                      ~/ww/dev/workflows/feature-delivery.md

Tests required:       bash ~/ww/dev/scripts/check-parity.sh
                      ~/ww/bin/ww help
                      rg -n "journal|ledger|service" ~/ww/docs/usage-examples.md ~/ww/dev/config/command-syntax.yaml

Rollback:             git checkout ~/ww/dev/scripts/check-parity.sh ~/ww/dev/config/command-syntax.yaml ~/ww/dev/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: completion criteria and docs update cadence.
                      Tests currently covering write scope: parity script execution.
                      Rollback verification: parity gate rollback through file revert.

Status:               complete — 2026-04-20

Completion note:      Added `dev/scripts/check-parity.sh` (maps each active CSSOT `syntax`
                      line to help output; handles `i`→`ww issues`, profile/group/model action tables,
                      `ww find` flags, timew summaries, `ww q` questions forms). Wired Gate C step into
                      `dev/workflows/feature-delivery.md`. Aligned `questions` CSSOT syntax with
                      `ww help questions` text. BATS: `dev/tests/test-parity.bats`.

