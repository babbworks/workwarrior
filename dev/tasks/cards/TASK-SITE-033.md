## TASK-SITE-033: Sword panel task search to find task IDs

Goal:                 The Sword panel requires the user to enter a task ID,
                     but there's no way to find the ID from within the panel.
                     Add an inline task search so users can find the task
                     they want to split without switching to the Tasks section.

Scope summary:
  1. Task search field above the sword form: type to filter cachedTasks
     (no fetch needed if tasks were recently loaded)
  2. Results shown as a compact list (id · description · project · urgency)
  3. Clicking a result: fills the task_id input and hides the search results
  4. If cachedTasks is empty: show a "load tasks first" hint with a button
     that fetches /data/tasks and populates cachedTasks
  5. task_id input: also accepts UUID prefix (auto-resolves to numeric ID)

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
