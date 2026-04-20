## TASK-SITE-025: Journal date grouping and pagination

Goal:                 Journal entries are currently displayed as a flat
                     reverse-chronological list with no visual date grouping
                     and no pagination — all entries load at once. For profiles
                     with hundreds of entries this is both slow and visually
                     difficult to scan.

Scope summary:
  1. Date group headers: entries grouped by local date (Today, Yesterday,
     date string for older). Each group header shows entry count.
  2. Pagination: load 20 entries at a time. "load more" button at bottom
     (or auto-load-on-scroll). Server-side: /data/journal should accept
     ?offset=N&limit=20 params.
  3. Active search disables pagination (searches full list up to 200 entries)
  4. Group headers collapsible (collapsed state in localStorage per date)
  5. Entry count shown in section context bar: "entries: N · page 1 of M"

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/journal: offset/limit)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
