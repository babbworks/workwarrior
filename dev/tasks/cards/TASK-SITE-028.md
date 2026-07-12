## TASK-SITE-028: Questions panel — run template from UI

Goal:                 The Questions panel can list and create templates but
                     cannot run one. Running a template from the CLI is
                     interactive (prompts for each question). The UI needs
                     a non-interactive equivalent: show all questions as a
                     form, collect answers, submit as a structured journal
                     entry.

Scope summary:
  1. New /data/questions endpoint: returns list of templates with their
     questions [{name, service, description, questions:[{text}]}]
     (parses `ww q list` and per-template info)
  2. Template list rendered as cards with "run" button
  3. "Run" expands an inline form with one text input per question
  4. On submit: assembles a journal entry:
       "[q:template-name] YYYY-MM-DD
        Q: <question 1>
        A: <answer 1>
        ..."
     and calls journal_add action
  5. Success: collapse form, show toast

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/questions endpoint)

Fragility:            LOW

Dependencies:         TASK-SITE-012 (toasts) recommended

Status:               complete — 2026-04-13
