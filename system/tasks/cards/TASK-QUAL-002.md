## TASK-QUAL-002: Automate docs and help parity checks

Goal:                 Enforce Gate C by detecting mismatch between command behavior, help text, and docs/CSSOT.

Acceptance criteria:  1. A parity-check script compares help output against documented command entries.
                      2. Parity failures are reported with actionable diff references.
                      3. Verifier workflow requires parity pass before completion.

Write scope:          /Users/mp/ww/system/scripts/check-parity.sh
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       bash /Users/mp/ww/system/scripts/check-parity.sh
                      /Users/mp/ww/bin/ww help
                      rg -n "journal|ledger|service" /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Rollback:             git checkout /Users/mp/ww/system/scripts/check-parity.sh /Users/mp/ww/system/config/command-syntax.yaml /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: completion criteria and docs update cadence.
                      Tests currently covering write scope: parity script execution.
                      Rollback verification: parity gate rollback through file revert.

Status:               complete — 2026-04-20

Completion note:      Added `system/scripts/check-parity.sh` (maps each active CSSOT `syntax`
                      line to help output; handles `i`→`ww issues`, profile/group/model action tables,
                      `ww find` flags, timew summaries, `ww q` questions forms). Wired Gate C step into
                      `system/workflows/feature-delivery.md`. Aligned `questions` CSSOT syntax with
                      `ww help questions` text. BATS: `tests/test-parity.bats`.

