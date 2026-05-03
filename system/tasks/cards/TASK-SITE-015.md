## TASK-SITE-015: Keyboard shortcuts for section navigation

Goal:                 Add vim-style g+key bindings to navigate sections without
                      touching the mouse. Essential for agentic and power-user
                      workflows.

Scope summary:
  Bindings (when terminal input not focused):
    g t  → tasks          g j  → journal
    g T  → times          g l  → ledger
    g n  → next           g s  → schedule
    g c  → cmd            g C  → ctrl
    g S  → sync           g G  → groups
    g m  → models         g N  → network
    g e  → export         g q  → questions
    g p  → profile        g w  → warrior
    g u  → gun            g x  → sword
    ?    → keyboard shortcut overlay (shows all bindings)
  Plus: Escape to focus terminal input from anywhere

  Implementation: keydown listener on document, skip when activeElement
  is an input/textarea/select.

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css (shortcut overlay)

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
