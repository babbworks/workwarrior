## TASK-COMM-006: Journal metadata markers — @tags/@project/@priority embedded at creation

Goal:                 Enable tags, project, and priority metadata on journal entries,
                      stored as parseable inline markers in the jrnl entry text.
                      Services scan for these markers. No separate metadata store.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. Journal creation form in browser includes tags, project,
                         priority fields
                      2. On submit, metadata appended to entry text as:
                           @tags:foo,bar @project:planning @priority:H
                         on a dedicated final line of the entry
                      3. lib/journal-scanner.sh (COMM-005 dependency) parses and
                         returns these fields as structured data
                      4. Retroactive edit of metadata: user edits fields in browser,
                         a new annotation block is appended:
                           ---
                           [YYYY-MM-DD HH:MM] @tags:new,tags @project:updated
                         (scanner uses most-recent metadata block as authoritative)
                      5. ww journal entries filtered by tag/project in CLI:
                           ww journal list --tag foo
                           ww journal list --project planning

Write scope:          (pending Gate A)
                      lib/journal-scanner.sh (extend from COMM-005)
                      services/browser/server.py (journal data endpoint update)
                      services/browser/static/app.js (creation form + filter UI)

Tests required:       (pending Gate A)
                      bats tests/test-journal-metadata.bats (new)
                      Manual: create entry with tags, verify marker written to file

Rollback:             git checkout lib/ services/browser/

Fragility:            Medium — depends on COMM-005 scanner; marker format must be
                      stable (changing format breaks existing entries)

Depends on:           TASK-COMM-005

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 14 (12036f9e-8ecd-4df5-92d2-82ba123a5f95) status:completed
