## TASK-1.2: Deploy services/CLAUDE.md

Goal:                 Copy devsystem services-CLAUDE.md so Builder agents can write correct
                      services without referencing existing service scripts.
Acceptance criteria:  1. /Users/mp/ww/services/CLAUDE.md exists
                      2. A Builder can write a correct Tier 1 service using only this file
                         as reference (no existing service needed)
                      3. bin/wwctl verify-phase1 passes the "services/CLAUDE.md deployed" check
Write scope:          /Users/mp/ww/services/CLAUDE.md
Tests required:       Manual cold-read validation by Orchestrator
                      bin/wwctl verify-phase1 (partial)
Rollback:             rm /Users/mp/ww/services/CLAUDE.md
Fragility:            None
Risk notes:           Source: system/services-CLAUDE.md (copy, do not edit in place)
Status:               pending
