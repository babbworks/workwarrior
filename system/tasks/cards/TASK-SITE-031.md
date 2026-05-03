## TASK-SITE-031: Warrior panel aggregate urgency and cross-profile view

Goal:                 The Warrior panel loads per-profile task counts via
                     `profile stats` commands. Enhance to show aggregate
                     urgency scores, active tasks, and allow viewing any
                     profile's task list directly from the Warrior panel
                     without switching the active profile.

Scope summary:
  1. New /data/warrior endpoint: for each profile, returns {name,
     task_count, active_count, high_urgency_count, top_task_desc}
     using profile-scoped task reads
  2. Warrior cards enhanced:
     - Urgency bar: colored segments (red=high, orange=med, muted=low)
     - Active badge: green pulse dot if active task
     - Top task preview: truncated description of highest urgency task
  3. "View tasks" button: loads that profile's tasks in a read-only overlay
     panel (without switching active profile)
  4. Warrior sidebar footer count: changes from "X profiles" to
     "X tasks · Y active" (aggregate across all profiles)
  5. Aggregate stats row at top: total tasks, total active, total hours today

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/warrior endpoint)
                      services/browser/static/style.css

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
