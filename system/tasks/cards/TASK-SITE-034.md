## TASK-SITE-034: Live data refresh via SSE push and polling

Goal:                 Currently SSE only pushes profile change events.
                     Mutations made from other sessions (terminal, another
                     browser tab) are not reflected in the UI until the user
                     manually switches sections. Add lightweight polling or
                     SSE data-push for tasks and time.

Scope summary:
  1. SSE push (preferred): server emits a "data" event when a mutation
     occurs (after any POST /action or /cmd that modifies task/time data).
     Client: on "data" event, re-fetch active section if it's tasks or time.
  2. Fallback polling: if SSE push is too complex, add 30s polling for
     the active section (tasks, time, journal) via setInterval.
  3. Polling is paused when the browser tab is hidden (document.visibilityState)
  4. On SSE reconnect: reload active section (handles server restart)
  5. Warrior sidebar count should auto-update on task mutations

Write scope:          services/browser/static/app.js
                      services/browser/server.py (SSE broadcast on mutation)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
