## TASK-COMM-007: Journal filter buttons — Annotated, Rejournaled, All Comments

Goal:                 Add three filter buttons to the browser journal view for
                      filtering entries that have annotations, have been cited by
                      a rejournal, or either. Backed by the journal scanner.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. Three filter buttons visible in journal view header:
                         Annotated | Rejournaled | All Comments
                      2. Annotated: shows only entries with one or more --- [timestamp]
                         annotation blocks
                      3. Rejournaled: shows only entries that appear as the target of
                         a rejournal-of: marker in any other entry (scan-based)
                      4. All Comments: union of Annotated and Rejournaled
                      5. Active filter button visually distinguished
                      6. Filters are toggles — re-clicking clears the filter
                      7. Filter state is not persisted across sessions

Write scope:          (pending Gate A)
                      services/browser/server.py (journal endpoint filter params)
                      services/browser/static/app.js (filter button UI)
                      services/browser/static/style.css (filter button styles)

Tests required:       (pending Gate A)
                      Manual: all three filters produce correct entry sets
                      Manual: filter toggle clears correctly

Rollback:             git checkout services/browser/

Fragility:            Low — additive UI and endpoint changes

Depends on:           TASK-COMM-005, TASK-COMM-006

Status:               complete — 2026-04-23
Taskwarrior:          wwdev task 15 (cda7a6c8-3f99-4043-8c5e-5acb63fe56f4) status:completed
