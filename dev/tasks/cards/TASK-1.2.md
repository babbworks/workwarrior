## TASK-1.2: Deploy services/CLAUDE.md

Goal:                 Copy devsystem services-CLAUDE.md so Builder agents can write correct
                      services without referencing existing service scripts.
Acceptance criteria:  1. ~/ww/services/CLAUDE.md exists
                      2. A Builder can write a correct Tier 1 service using only this file
                         as reference (no existing service needed)
                      3. bin/wwctl verify-phase1 passes the "services/CLAUDE.md deployed" check
Write scope:          ~/ww/services/CLAUDE.md
Tests required:       Manual cold-read validation by Orchestrator
                      bin/wwctl verify-phase1 (partial)
Rollback:             rm ~/ww/services/CLAUDE.md
Fragility:            None
Risk notes:           Source: dev/services-CLAUDE.md (copy, do not edit in place)
Status:               closed

Closure note:         Design correction — dev/services-CLAUDE.md is authoritative and is
                      read directly by agents. Deploying a copy to services/ creates a maintenance
                      split. See dev/logs/decisions.md.
