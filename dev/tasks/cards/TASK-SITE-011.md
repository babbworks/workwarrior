## TASK-SITE-011: Remove native alert()/prompt() from browser UI

Goal:                 Replace all uses of browser-native alert() and prompt()
                      with inline UI components that match the terminal aesthetic.
                      Currently: groups "show" uses alert(), bookbuilder "search"
                      uses prompt(). Both break the dark terminal UI contract.

Scope summary:
  1. Groups panel: replace alert(d.output) with inline output div that expands
     below the group card on click (toggle show/hide)
  2. BookBuilder panel: replace prompt("Search knowledge base:") with an inline
     search input row that appears on "search" button click

Approach:             Direct edit — low-fragility browser static files.

Write scope:          services/browser/static/app.js
                      services/browser/static/index.html (if new HTML needed)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
