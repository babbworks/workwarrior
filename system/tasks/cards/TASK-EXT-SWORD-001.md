## TASK-EXT-SWORD-001: Design and implement "Sword" weapon service for ww browser UI

Goal:                 Define and build the Sword weapon — a second sidebar weapon
                      alongside Gun in the browser UI. Service purpose, upstream tool
                      (if any), and command surface TBD. This card tracks the design
                      decision and initial implementation.

Design questions:     1. What capability does Sword represent? (e.g. task splitting,
                         batch editing, dependency graph, recurring task templates)
                      2. Is there an upstream tool to adopt, or is this a ww-native service?
                      3. What is the CLI surface? (ww sword <subcommand>)
                      4. What does the browser UI panel look like?

Proposed wiring:      - Sidebar weapon button: ⚔️ (currently rendered but disabled)
                      - Section: section-sword in browser UI
                      - CLI: ww sword <subcommand> in bin/ww
                      - Server: /cmd passthrough or dedicated endpoints

Acceptance criteria:  1. Design document written (what Sword does, why)
                      2. CLI surface defined in bin/ww cmd_sword()
                      3. Browser UI section wired with form and output
                      4. Weapon button activates and shows the section
                      5. docs/taskwarrior-extensions/ or docs/ entry written

Write scope:          bin/ww (cmd_sword)
                      services/browser/server.py (ALLOWED_SUBCOMMANDS)
                      services/browser/static/index.html (section-sword)
                      services/browser/static/app.js (switchSection, loadSection)
                      services/browser/static/style.css (sword panel styles)
                      system/config/command-syntax.yaml (sword domain)

Fragility:            SERIALIZED: bin/ww
                      LOW: browser static files

Depends on:           Design decision on what Sword does

Status:               complete — 2026-04-27 (cmd_sword in bin/ww; ALLOWED_SUBCOMMANDS includes sword; browser section-sword with task search, form, submit handler via /cmd; weapon button wired; "coming soon" label removed)
Taskwarrior:          wwdev task 20 (5568435d-ee09-4d17-8d21-745ddcbb772c) status:completed
