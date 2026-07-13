## TASK-LED-003: Modular journal files and ledger include strategy

Goal:                 Document and implement the pattern for splitting a profile's journal
                      and ledger into multiple named files (e.g. by year, topic, or project)
                      with hledger include directives and jrnl config pointing to each.

Background:           Both jrnl and hledger support modular file organisation:
                      - hledger: top-level journal can "include" sub-journals
                        (include 2025.journal, include projects/ww.journal, etc.)
                      - jrnl: config can point to multiple named journals, each a separate file

                      ww already supports multiple named resources per profile via ledgers.yaml
                      and journals section in profile config. This task formalises the
                      recommended split pattern and wires it into resource creation.

Acceptance criteria:  1. dev/docs/modular-journals.md documents the include strategy for
                         both hledger and jrnl, with example config snippets.
                      2. ww resource create ledger <name> provisions a sub-journal file and
                         updates the top-level include list in the profile's main journal.
                      3. ww resource create journal <name> creates a named jrnl config entry.
                      4. Profile meta template (profile-meta-template.yaml) reflects the
                         recommended multi-file layout.

Write scope:          dev/docs/modular-journals.md  (new)
                      resources/profile-meta-template.yaml
                      services/browser/server.py  (resource/create handler updates)

Tests required:       bats dev/tests/test-resource-create.bats  (new or extend existing)

Closure note:         Closed as SUBSUMED. The modular-journal include strategy is documented at
                      dev/docs/modular-journals.md (verified present 2026-07-13), and TASK-LED-015
                      (`ww ledger sync-stream`, regenerate-never-append) owns the implementation.
                      TASKS.md already declared the subsumption; only the card status lagged.

Status:               closed — 2026-07-13 (subsumed by TASK-LED-015)
Priority:             low
