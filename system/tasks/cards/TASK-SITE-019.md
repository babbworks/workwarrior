## TASK-SITE-019: Scheduled and wait fields in task add form

Goal:                 The inline task add form exposes description, project,
                     tags, priority, and due. It is missing scheduled and wait
                     fields which are essential for deferred task workflows
                     (an AI agent or planner frequently needs to schedule tasks
                     for future activation, not just set due dates).

Scope summary:
  1. Add "scheduled" date input to the add-task-form (after due)
  2. Add "wait" date input to the add-task-form (after scheduled)
  3. Both optional — only included in the action payload if set
  4. Labels in the form: "sched" and "wait" (compact for space)
  5. The task inline editor already has a field grid — add scheduled and
     wait rows there too (currently missing)
  6. renderDue() analog for scheduled: show "sched: in Nd" badge on task
     rows when task has a scheduled date in the future

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html
                      services/browser/server.py (/action add handler)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
