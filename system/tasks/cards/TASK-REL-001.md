## TASK-REL-001: Operationalize release checklist as enforced gate

Goal:                 Make release-readiness claims impossible without checklist completion evidence.

Acceptance criteria:  1. Release checklist includes mandatory sign-off fields and evidence links.
                      2. Release commands/workflow reference checklist gate before tagging.
                      3. Docs explain release gate process clearly.

Write scope:          /Users/mp/ww/system/gates/release-checklist.md
                      /Users/mp/ww/system/gates/all-gates.md
                      /Users/mp/ww/docs/RELEASE-CHECKLIST.md
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       rg -n "Sign-Off|evidence|Gate D" /Users/mp/ww/system/gates/release-checklist.md /Users/mp/ww/system/gates/all-gates.md
                      Manual: walkthrough release workflow and verify checklist gate step exists.

Rollback:             git checkout /Users/mp/ww/system/gates/release-checklist.md /Users/mp/ww/system/gates/all-gates.md /Users/mp/ww/docs/RELEASE-CHECKLIST.md /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: release process rigor and cadence.
                      Tests currently covering write scope: checklist completeness scans.
                      Rollback verification: gate docs revert.

Status:               pending

