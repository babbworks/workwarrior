## TASK-SITE-027: Models panel structured list and set-default

Goal:                 The Models panel shows raw `model list` text output.
                     Replace with a structured card list showing provider,
                     model name, active/default indicator, and a set-default
                     button per model.

Scope summary:
  1. New /data/models endpoint in server.py: parses `ww model list` output
     into [{name, provider, model_id, active, description}]
  2. Models rendered as cards: provider badge + model name + active indicator
  3. "set default" button per card → calls `ww model set <name>`
  4. "detect ollama" button (existing) retained
  5. Empty state: "No models configured. Use 'ww model add' or detect ollama."
  6. Provider filter tabs if >3 providers present

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/models endpoint)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
