## TASK-SITE-032: Groups panel inline view

Goal:                 The Groups panel "show" button calls alert(d.output)
                     to display group details. Replace with inline expansion
                     below each group card. Also add profile membership
                     editing (add/remove profile from group).

Scope summary:
  1. Group card "show" → toggles an expanded div below the card showing:
     - Member profiles as clickable chips
     - "switch to" link per profile (calls switchProfile)
     - "run cmd on group" input: enter a ww command, runs against all
       profiles in the group (via /cmd with group context)
  2. Add member: inline input + "add" button on expanded card
  3. Remove member: × button on each profile chip
  4. Group rename: click group name to edit inline
  5. No alert() anywhere in groups panel

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         TASK-SITE-011 (alert removal)

Status:               complete — 2026-04-13
