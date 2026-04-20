## TASK-SITE-024: Time entry tag format clarity and validation

Goal:                 The time entry form's tags field shows placeholder
                     "+project +meeting" suggesting + prefix, but TimeWarrior
                     tags are space-separated without + (unless user
                     intentionally uses them). This causes confusion and
                     incorrect tag storage. Also: no visual feedback on what
                     tags are currently tracked.

Scope summary:
  1. Update tag field placeholder to reflect actual timew tag format:
     "tags (e.g. dev review meeting)"
  2. Add tag parsing preview below the field: as user types, show the
     parsed tags as individual badges so they can verify before starting
  3. The datalist already provides autocomplete — keep it
  4. When tracking is active, the start button changes to "restart (new
     tags)" and shows current tags as badges
  5. Tag normalization: trim whitespace, collapse multiple spaces, lowercase

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
