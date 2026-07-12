## TASK-SITE-021: Active task persistent indicator in header bar

Goal:                 When a task is active (started), show a persistent
                     indicator in the content header (row 2 / context bar)
                     that is visible from any section — not just when the
                     user is looking at the Tasks section.

Scope summary:
  1. Header row 2 (stat-context-bar): when an active task exists, prepend
     a green pulse dot + truncated task description + elapsed time since
     start to the context bar text. Example:
     "● Review PR description (started 14m ago) · pending: 12 · active: 1"
  2. Active task detection: extend /data/tasks response (already has
     status:'active' tasks) — extract from cachedTasks on render
  3. Elapsed time: computed client-side from task.start timestamp, updated
     every 30s via setInterval
  4. Clicking the active task indicator in the header switches to Tasks
     section and opens that task's inline detail
  5. Also: update stat-tasks-count in the top-right header stats to show
     count in active color when a task is running

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
