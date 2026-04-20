## TASK-SITE-012: Toast notification system for action feedback

Goal:                 Add a non-blocking toast/snackbar system for confirming
                      successful mutations. Currently: task add/done/start give
                      no visual cue beyond re-rendering the list. Users need a
                      "task added", "✓ done", "started tracking" flash that
                      disappears after ~2s.

Scope summary:
  1. Toast container: fixed position (bottom-right, above terminal bar), stacks
     multiple toasts, auto-dismisses after 2000ms with fade-out
  2. Toast types: success (green), error (red), info (muted)
  3. Wire to: task add, start, stop, done, journal add, time start/stop,
     ledger add, resource create, group create, UDA save

Approach:             Pure JS + CSS — no DOM changes needed in index.html
                      (toast container injected by JS on init).

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
