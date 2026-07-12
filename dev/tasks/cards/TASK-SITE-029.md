## TASK-SITE-029: BookBuilder panel — real integration and inline search

Goal:                 The BookBuilder panel currently: (a) saves URLs to
                     journal only (not to bookbuilder), (b) uses prompt()
                     for search (removed in TASK-SITE-011), (c) shows static
                     help text for pipeline operations. Replace with actual
                     bookbuilder CLI integration where available, with graceful
                     degradation to journal-backed mode.

Scope summary:
  1. Remove prompt() search (TASK-SITE-011 handles this, but this card
     adds the actual search UI: inline search input row under "search" btn)
  2. bb-add-form: try `bookbuilder add <url>` first via /cmd; fall back to
     journal entry if bookbuilder not installed. Show which mode was used.
  3. bb-status: call `bookbuilder status` if available; else show
     "bookbuilder not installed — using journal mode"
  4. bb-search: inline search input → calls `bookbuilder search <term>` via
     /cmd and renders results as cards
  5. Show install hint with exact brew/pipx command when not installed

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html

Fragility:            LOW

Dependencies:         TASK-SITE-011 (alert/prompt removal)

Status:               complete — 2026-04-13
