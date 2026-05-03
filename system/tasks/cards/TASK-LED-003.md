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

Acceptance criteria:  1. system/docs/modular-journals.md documents the include strategy for
                         both hledger and jrnl, with example config snippets.
                      2. ww resource create ledger <name> provisions a sub-journal file and
                         updates the top-level include list in the profile's main journal.
                      3. ww resource create journal <name> creates a named jrnl config entry.
                      4. Profile meta template (profile-meta-template.yaml) reflects the
                         recommended multi-file layout.

Write scope:          system/docs/modular-journals.md  (new)
                      resources/profile-meta-template.yaml
                      services/browser/server.py  (resource/create handler updates)

Tests required:       bats tests/test-resource-create.bats  (new or extend existing)

Status:               open
Priority:             low
