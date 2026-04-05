## TASK-INSTALL-002: Fix journals() function — YAML grep matches all keys, not just journal names

Goal:                 The `journals` bare command displayed config keys (body, date, tags, title,
                      colors, default) alongside actual journal names. Root cause: grep pattern
                      `^  [a-zA-Z0-9_-]\+:` matched all 2-space-indented YAML keys, not just entries
                      under the `journals:` section.

Acceptance criteria:  1. `journals` bare command lists only journal names defined under `journals:` in jrnl.yaml.
                      2. Config keys (body, date, tags, title, colors, default, editor) never appear in output.
                      3. Fix handles jrnl.yaml files with multiple top-level sections cleanly.

Write scope:          /Users/mp/ww/lib/shell-integration.sh  (journals() function only)

Tests required:       Manual: activate profile → journals (verify only real journal names shown)

Rollback:             git checkout /Users/mp/ww/lib/shell-integration.sh

Fragility:            SERIALIZED: lib/shell-integration.sh

Risk notes:           awk section-scoped reader is correct approach. `sub()` only modifies first match
                      per record; use `match() + substr()` instead. Verified working.

Resolution:           Fixed with awk section-scoped reader:
                        awk '/^journals:/{f=1;next} f && /^[^ ]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{match($0,/[a-zA-Z0-9_-]+/); print "  • " substr($0,RSTART,RLENGTH)}'

Status:               complete
