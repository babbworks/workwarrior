## TASK-SITE-017: Task grouping by project + overdue float

Goal:                 In the Tasks section, group tasks by project with
                      collapsible project headers. Overdue tasks float to a
                      pinned "Overdue" group at the top regardless of project.

Scope summary:
  1. Group rendering: tasks sorted urgency-first within each project group.
     Project header row shows project name + task count + total urgency.
     Groups collapsible (state in localStorage per project name).
  2. Overdue group: tasks where due date is past today. Pinned above all
     project groups. Distinct visual (red left border on header).
  3. No-project tasks: rendered in a final "inbox" group.
  4. Toggle: "group by project" / "flat list" button in section toolbar.
     Flat list = current behavior (urgency sort, no groups).
  5. Group collapse state persisted in localStorage.

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
