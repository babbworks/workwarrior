## TASK-SITE-030: Profile screen structured stats and create-new

Goal:                 The Profile screen shows raw `ww profile info <name>`
                     text. Replace with structured stat cards and add a
                     create-new-profile form.

Scope summary:
  1. New /data/profile-detail endpoint: returns {name, task_count,
     journal_count, ledger_count, timew_hours, uda_count, created,
     last_active} — parsed from ww profile info + direct data counts
  2. Profile detail card:
     - Stat grid: tasks, journals, ledger entries, hours tracked
     - UDA count + "manage UDAs" link (switches to ww profile uda view)
     - Creation date
  3. Profile selector (existing dropdown) retained
  4. "Create profile" section at bottom:
     - Name input + submit → calls `ww profile create <name>` via /cmd
     - On success: adds to profile list, switches to new profile
  5. "Delete profile" button with inline confirmation (no native confirm())

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/profile-detail)

Fragility:            LOW

Dependencies:         TASK-SITE-012 (toasts)

Status:               complete — 2026-04-13
