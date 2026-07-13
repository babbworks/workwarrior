## TASK-SITE-040: Journal cross-journal entry link — fix non-functional link

Goal:                 When adding a journal entry to a non-default sub-journal from the browser UI, the response currently renders as a bare link that does nothing. The entry is added server-side but the UI feedback is broken.

Background:           The `journal_add` action in server.py handles `target_journal` parameter. The client-side `wireJournalAddForm` constructs the payload. When the active journal is not "default", the response or the post-submit handler may be returning a link string instead of triggering `loadJournal()` correctly.

Acceptance criteria:  - [ ] Adding an entry to any sub-journal (e.g. dotTel, agentic-dev) from the browser add form reloads the correct journal content
                      - [ ] No broken link or raw URL appears in the UI after submission
                      - [ ] Works whether the target journal is the currently active journal or selected via the add-form journal picker
                      - [ ] SSE broadcast fires on successful add so other connected sessions refresh

Write scope:          - `services/browser/static/app.js` — wireJournalAddForm submit handler
                      - `services/browser/server.py` — journal_add action response (if needed)

Rollback:             Revert app.js submit handler. Server-side change is additive only.

Fragility:            See Risk notes.

Risk notes:           Low — isolated to the add-form submission path.

Notes:                priority: M · area: browser · created: 2026-04-27

Status:               pending

Taskwarrior:          wwdev task (52986c8d) status:pending
