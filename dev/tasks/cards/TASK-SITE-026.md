## TASK-SITE-026: Sync panel dashboard

Goal:                 The Sync panel currently loads `issues help` text as
                     its body — effectively a raw help dump. Replace with a
                     real status dashboard showing sync state, last sync
                     timestamp, and pending change indicators.

Scope summary:
  1. New /data/sync endpoint in server.py: runs `ww issues status --json`
     (or parses text output), returns {configured, last_pull, last_push,
     pending_push, pending_pull, profile, error}
  2. Dashboard layout:
     - Status badge: enabled/disabled/not-configured
     - Last pull: relative timestamp (e.g. "3h ago")
     - Last push: relative timestamp
     - Pending: N tasks awaiting push / M updates to pull
     - Profile + repo info
  3. Buttons (existing) remain: status, pull, push, install
  4. Output div shows button results (existing behavior)
  5. Auto-refreshes when panel is opened

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/sync endpoint)

Fragility:            LOW (browser + minor server.py endpoint)

Dependencies:         none

Status:               complete — 2026-04-13
