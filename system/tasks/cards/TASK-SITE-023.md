## TASK-SITE-023: Previous/next week navigation in time section

Goal:                 The time section only shows the current week. Add
                     back/forward week navigation so users can review past
                     time data without leaving the UI.

Scope summary:
  1. Week navigation row above week bars: "‹ prev" / date range / "next ›"
     next button disabled when on current week
  2. weekOffset state variable (0 = current, -1 = last week, etc.)
  3. loadTime() accepts optional weekOffset param, passes to /data/time
     (or computes client-side from full intervals list if server returns
     enough history)
  4. If computing client-side: /data/time should return intervals for the
     past 8 weeks by default (currently returns recent intervals)
  5. Week total updates to reflect selected week
  6. Intervals list filtered to selected week

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html (nav row)
                      services/browser/server.py (/data/time: extend range)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
