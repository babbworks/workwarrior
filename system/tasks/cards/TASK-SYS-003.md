## TASK-SYS-003: Create command syntax source of truth (CSSOT)

Goal:                 Establish one canonical specification for commands, subcommands, flags, and examples across all services.

Acceptance criteria:  1. A machine-readable command spec exists and is linked from system docs.
                      2. Every active service has an entry with syntax, flags, scope rules, and examples.
                      3. CLI/help/doc updates require updating CSSOT in the same task.

Write scope:          /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/system/README.md
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       rg -n "^  - domain:" /Users/mp/ww/system/config/command-syntax.yaml
                      rg -n "command-syntax.yaml" /Users/mp/ww/system

Rollback:             git checkout /Users/mp/ww/system/config/command-syntax.yaml /Users/mp/ww/system/README.md /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: governance and command-design workflow.
                      Tests currently covering write scope: static validation and reference scan.
                      Rollback verification: file-level revert.
                      Dispatch readiness: ready-now (unblocks CLI command-design dialogue loop).
                      Dependencies: none.
                      Completion evidence (2026-04-04): command-syntax.yaml created and linked
                      from system docs/workflows; CSSOT update is now an explicit pre-flight requirement.
                      Note: `yq` unavailable in environment, so regex-based structure checks used.

Status:               complete
