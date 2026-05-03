## TASK-SITE-007: Browser UI major overhaul — sidebar restructure, service panels, color system, collapsed mode

Goal:                 Transform the browser UI from a basic data viewer into a full
                      workwarrior control surface with all services accessible, a
                      consistent color/icon system, and a collapsed sidebar mode.

Scope summary:
  1. Sidebar restructure: CMD + CTRL buttons, weapons row (sword, gun, bat, fire, slingshot),
     function tabs with unicode icons and colors, service tabs (Sync, Groups, Models,
     Network, Export, Questions, BookBuilder), Warrior stats footer
  2. Color system: green tasks (˜), muted orange journals (╱), light blue time (│),
     black/white ledgers (═), red warrior (✱), colored icon badges in terminal bar
  3. Collapsed sidebar: icon-only thin bar, weapons hidden, P icon for profile
  4. New panels: CTRL (settings), Sync (dashboard), Groups, Models, Network,
     Export, Questions, BookBuilder, Profile screen, Warrior stats
  5. Terminal bar: profile name + pinned command icon with colored badges
  6. UDA display: acme already has 180 UDAs — visible in task editor

Approach:             Direct execution (low-fragility browser files). No orchestrator
                      overhead. Summary task card + session log afterward.

Write scope:          services/browser/static/index.html
                      services/browser/static/app.js
                      services/browser/static/style.css
                      services/browser/server.py (new endpoints, ALLOWED_SUBCOMMANDS)
                      services/cmd/README.md (update)

Fragility:            LOW — browser static files only. No CLI or lib changes.

Closure note:         Closed as superseded by completed SITE wave cards and scoped
                      carry-forward into TASK-SITE-006.
                      Final decisions:
                        - Keep "Saves" naming (do not rename to BookBuilder)
                        - Keep sidebar/service icons, including placeholder weapon icons
                        - Read-only service panels are acceptable for current wave
                      Any remaining implementation work is tracked under TASK-SITE-006.

Status:               complete
