## TASK-COMM-004: Browser /data/community/* server endpoints

Goal:                 Add community data endpoints to services/browser/server.py.
                      These endpoints serve community data to the frontend and are
                      the API layer between the JS UI and community.db.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. GET /data/community/list — returns all communities with entry counts
                      2. GET /data/community/<name> — returns all entries for a community
                         with view filter param: ?view=unified|journal|tasks|comments
                      3. GET /data/community/<name>/entry/<id> — returns single entry
                         with captured_state, live_state (fetched from source), and comments
                      4. POST /action with action=community_add — adds entry to community
                      5. POST /action with action=community_comment — adds comment to entry,
                         returns approve_copy_to_source: true/false UI trigger for task entries
                      6. POST /action with action=community_copy_annotation — executes
                         task annotate on source task (requires user approval in UI)
                      7. "community" added to ALLOWED_SUBCOMMANDS in server.py
                      8. All endpoints return consistent {"ok": bool, ...} shape

Write scope:          (pending Gate A)
                      services/browser/server.py

Tests required:       (pending Gate A)
                      Manual: all endpoints return expected JSON shapes
                      bats tests/test-browser.bats (extend with community endpoint tests)

Rollback:             git checkout services/browser/server.py

Fragility:            Low — additive changes to server.py, no existing endpoints modified

Depends on:           TASK-COMM-001

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 11 (ff0facc3-96d0-4dad-9ff5-242a2d90f68f) status:completed
