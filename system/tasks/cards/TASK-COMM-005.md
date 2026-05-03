## TASK-COMM-005: Journal annotation append — timestamped separator format + scanner

Goal:                 Enable appending annotations to existing jrnl entries. Annotations
                      are appended as timestamped blocks using a standard separator.
                      A service scanner parses these blocks for display and filtering.
                      Also enables the compact annotation panel at journal entry creation.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. Annotation format appended to entry text:
                           ---
                           [YYYY-MM-DD HH:MM] annotation text
                      2. Multiple annotations produce multiple --- [timestamp] blocks
                      3. ww journal annotate <entry-ref> "<text>" appends block to entry
                      4. lib/journal-scanner.sh parses entries and returns structured
                         output separating body text from annotation blocks
                      5. Browser journal entry detail shows annotations below body with
                         subtle visual separator (not a new timeline entry)
                      6. At creation, compact annotation panel allows pre-attaching
                         annotations; each auto-stamped at click time
                      7. jrnl plain text file is modified only by append (no re-write
                         of existing lines)

Write scope:          (pending Gate A)
                      lib/journal-scanner.sh (new)
                      services/browser/server.py (journal entry detail endpoint update)
                      services/browser/static/app.js (annotation panel in journal view)

Tests required:       (pending Gate A)
                      bats tests/test-journal-annotation.bats (new)
                      Manual: annotate existing entry, verify separator format in file

Rollback:             git checkout lib/ services/browser/

Fragility:            Medium — modifies jrnl plain text files; scanner must be
                      robust to varied jrnl entry formats

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 13 (74190028-270c-4dfc-8fff-830ec5078cdd) status:completed
