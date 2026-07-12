## TASK-SITE-014: Section scroll position memory

Goal:                 When switching between sections and returning, the scroll
                      position within the content area is restored. Currently
                      every section switch resets to top.

Scope summary:
  1. Capture scrollTop of #content-area before hiding a section
  2. Restore scrollTop when showing a section (stored in a JS Map keyed by
     section name)
  3. On data reload (e.g. task done triggers renderTasks), preserve scroll if
     user didn't explicitly switch sections

Approach:             Small state addition in switchSection() — low risk.

Write scope:          services/browser/static/app.js

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
