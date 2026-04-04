## TASK-1.1: Deploy root CLAUDE.md

Goal:                 Copy devsystem CLAUDE.md to project root so all agents can cold-start.
Acceptance criteria:  1. /Users/mp/ww/CLAUDE.md exists
                      2. File passes cold-read test: an agent can identify architecture,
                         what it cannot touch, how to run tests, and where TASKS.md is
                         without reading any other file.
                      3. bin/wwctl verify-phase1 passes the "Root CLAUDE.md deployed" check
Write scope:          /Users/mp/ww/CLAUDE.md
Tests required:       Manual cold-read validation by Orchestrator
                      bin/wwctl verify-phase1 (partial — checks this file)
Rollback:             rm /Users/mp/ww/CLAUDE.md
Fragility:            None
Risk notes:           Source: system/CLAUDE.md (copy, do not edit in place)
Status:               pending
