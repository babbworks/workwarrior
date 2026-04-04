## TASK-UX-002: Build command examples library per service

Goal:                 Provide validated examples for every major command family to reduce adoption friction.

Acceptance criteria:  1. Each service has at least 3 approved examples (basic, scoped override, advanced).
                      2. Examples are reflected in CLI help and docs.
                      3. Example-validation checklist is added to verifier flow.

Write scope:          /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/services/README.md
                      /Users/mp/ww/system/templates/verifier-signoff.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       rg -n "Examples:" /Users/mp/ww/bin/ww /Users/mp/ww/services /Users/mp/ww/docs/usage-examples.md
                      Manual: run each new example command and verify expected output.

Rollback:             git checkout /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/services/README.md /Users/mp/ww/system/templates/verifier-signoff.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: user guidance quality and support burden.
                      Tests currently covering write scope: manual example execution checklist.
                      Rollback verification: docs/template revert.

Status:               pending

