## TASK-1.1: Deploy root CLAUDE.md

Goal:                 Copy devsystem CLAUDE.md to project root so all agents can cold-start.
Acceptance criteria:  1. ~/ww/CLAUDE.md exists
                      2. File passes cold-read test: an agent can identify architecture,
                         what it cannot touch, how to run tests, and where TASKS.md is
                         without reading any other file.
                      3. bin/wwctl verify-phase1 passes the "Root CLAUDE.md deployed" check
Write scope:          ~/ww/CLAUDE.md
Tests required:       Manual cold-read validation by Orchestrator
                      bin/wwctl verify-phase1 (partial — checks this file)
Rollback:             rm ~/ww/CLAUDE.md
Fragility:            None
Risk notes:           Source: dev/CLAUDE.md (copy, do not edit in place)
Status:               closed

Closure note:         Design correction — ~/ww is a hybrid user-data/software directory.
                      Dev/agent files do not belong at the project root. dev/CLAUDE.md is
                      authoritative and is read directly by agents. See dev/logs/decisions.md.
