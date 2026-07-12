## TASK-SITE-016: Global search across tasks and journals

Goal:                 Add a global search mode reachable from the terminal bar
                      (/ key or Ctrl+/) that searches across tasks AND journal
                      entries simultaneously, showing results in a unified panel.

Scope summary:
  1. New section "search" added to DOM and section routing
  2. Terminal bar: pressing / when in execute mode opens global search (sets
     termMode to 'search'), prompt changes to '🔍 '
  3. Search executes against /data/tasks and /data/journal client-side (no new
     endpoint needed for basic version)
  4. Results panel: two groups (Tasks, Journal entries) with matched text
     highlighted. Clicking a task result opens that task's inline detail.
     Clicking a journal result switches to journal section and scrolls to entry.
  5. Escape clears results and returns to execute mode

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         TASK-SITE-012 (toasts) recommended but not required

Status:               complete — 2026-04-13
