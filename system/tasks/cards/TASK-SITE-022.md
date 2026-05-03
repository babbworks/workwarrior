## TASK-SITE-022: Second and millisecond time display granularity

Goal:                 The fmt() function currently shows "Xh Xm" which renders
                     as "0h 0m" for any interval under 60 seconds. For AI
                     agent sessions where individual operations take 1-30
                     seconds, this is useless. Extend to second and
                     millisecond precision.

Scope summary:
  Replace the single fmt(s) function with a scale-aware version:
    < 1 second:    "Nms" (milliseconds — for sub-second intervals)
    1–59 seconds:  "N.Ns" (e.g. "4.2s", "47.0s")
    1–59 minutes:  "Nm Ns" (e.g. "3m 12s")
    ≥ 1 hour:      "Nh Nm Ns" (e.g. "1h 4m 22s")

  Apply to: today card total, week bar day totals, interval row durations,
  week total, and the header stat-time-today.

  The terminal bar time tracking badge should show seconds elapsed live
  (update every second via setInterval when tracking is active).

  Note: TimeWarrior records to second precision. Sub-second ms display
  applies only to JS-computed elapsed time (Date.now() diff), not stored
  intervals.

Write scope:          services/browser/static/app.js

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
