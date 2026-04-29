## TASK-SITE-035: Lists service stabilization — save reliability + multi-list UX

Goal:                 Stabilize the browser Lists experience so add/edit actions reliably
                      return user-visible results and multi-list workflows are obvious inline.

Acceptance criteria:  1. Lists add flow handles fetch/JSON failures with visible toast errors
                         instead of silent failures.
                      2. Lists edit-save flow supports Enter submit and shows explicit errors
                         on backend failure.
                      3. Lists rows expose inline action buttons consistent with app style
                         (done/edit/remove).
                      4. Lists section shows inline controls for multi-list usage
                         (new list + refresh) alongside add-item flow.
                      5. Manual smoke check: create/switch list, add item, edit item, remove item.

Write scope:          /Users/mp/ww/services/browser/static/index.html
                      /Users/mp/ww/services/browser/static/app.js
                      /Users/mp/ww/system/tasks/cards/TASK-SITE-035.md

Tests required:       node --check services/browser/static/app.js
                      python3 -m py_compile services/browser/server.py
                      Manual: ww browser → Lists section create/switch/add/edit/remove

Rollback:             git checkout services/browser/static/index.html
                      git checkout services/browser/static/app.js
                      git rm system/tasks/cards/TASK-SITE-035.md

Fragility:            Low — browser static UI only, no core task/lib routing changes

Risk notes:           - Existing behavior affected: Lists section UI interactions only.
                      - Tests currently covering write scope: no direct UI test coverage for
                        list add/edit/remove button wiring in browser JS.
                      - Rollback verification: file-level checkout fully reverts this patch.

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 27 (3232ad57-182a-4296-82d3-0b74d8f70e1f) status:completed
