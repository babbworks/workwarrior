## TASK-COMM-003: Browser community section — 4 views

Goal:                 Add a Community section to the browser UI with four internal
                      tab views: Unified (all entries chronological), Journal (journal
                      entries + annotations/rejournals), Tasks (task entries + comments),
                      Comments (comments only with citations). Community accessible from
                      the sidebar with a dedicated nav item.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. Community nav item appears in sidebar with special position
                         (own section, above current services group)
                      2. Clicking Community loads the Unified view by default
                      3. Four tab buttons within the Community section switch views
                      4. Unified view: all entries sorted chronological, inline comments
                         shown below each entry
                      5. Journal view: journal entries only, annotations rendered below
                         body with subtle separator, rejournals show original first-line
                         block
                      6. Tasks view: simplified task display (description, project, tags,
                         status, due only — no timew controls, no urgency manipulation)
                      7. Comments view: comments only, each with citation (first line +
                         timestamp) and link to original entry
                      8. Community selector (dropdown) to switch between communities
                      9. Captured-state and current-state shown side-by-side on task
                         entries where they differ

Write scope:          (pending Gate A)
                      services/browser/static/index.html
                      services/browser/static/app.js
                      services/browser/static/style.css

Tests required:       (pending Gate A)
                      Manual: all 4 views render, tab switching works
                      Manual: community selector switches communities
                      Manual: task simplified view shows no timew/urgency controls

Rollback:             git checkout services/browser/static/

Fragility:            Low — browser static files only

Depends on:           TASK-COMM-004

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 12 (28ef082f-687c-4972-9f21-69db2b4ffa8f) status:completed
