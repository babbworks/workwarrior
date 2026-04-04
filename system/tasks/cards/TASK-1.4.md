## TASK-1.4: Build canonical TASKS.md at project root

Goal:                 Synthesize Explorer A + B outputs into a fully populated project
                      TASKS.md with evidence-backed status and 8-field cards for all open work.
Acceptance criteria:  1. /Users/mp/ww/TASKS.md exists and is not the seeded template
                      2. Every open task has an 8-field card
                      3. Every confirmed-complete task has evidence citation
                      4. Fragility register lists all HIGH FRAGILITY and SERIALIZED files
                      5. Every TODO in HIGH FRAGILITY files from Explorer B has a task card
                         (Gate E satisfied for all known deferred items)
                      6. pending/ has no new files
Write scope:          /Users/mp/ww/TASKS.md
                      Root CLAUDE.md testing section (amendment only — add Explorer B baseline)
Tests required:       Orchestrator review against Explorer A + B outputs
                      bin/wwctl verify-phase1 (partial — checks TASKS.md exists)
Rollback:             Restore from system/TASKS.md (seeded version)
Fragility:            None
Risk notes:           Depends on TASK-1.3a and TASK-1.3b both complete.
                      Orchestrator synthesizes both Explorer reports.
                      Test baseline from Explorer B goes into CLAUDE.md testing section.
Status:               pending
