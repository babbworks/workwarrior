## TASK-SITE-020: Bulk task operations with multi-select

Goal:                 Allow selecting multiple tasks and applying a bulk
                     action (done, delete, modify project/tags, set priority)
                     in one operation. Critical for AI agent use where batch
                     mutations are common.

Scope summary:
  1. Checkbox column: leftmost column on each task row (hidden by default,
     visible on hover or when any checkbox is checked)
  2. Selection toolbar: appears above task list when ≥1 task selected.
     Actions: "done all", "delete all", "set project…", "add tag…",
     "remove tag…", "set priority…"
  3. POST /action with action:"bulk" + ids:[...] + ops:{...}
  4. Server-side: new "bulk" action handler in server.py that loops over
     IDs and applies the operation
  5. Select-all checkbox in the toolbar header row
  6. Keyboard: Space on a focused task row toggles its checkbox

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html
                      services/browser/static/style.css
                      services/browser/server.py (bulk action handler)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
