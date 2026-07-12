## TASK-LED-001: Ledger transaction row redesign — 3-line item UI

Goal:                 Redesign the ledger recent-transactions list to follow the
                      tasks/journal interaction pattern: a primary row, an expandable
                      metadata line, and a persistent comment button. Clicking an item
                      expands one line below — never opens a separate panel.

Background:           Current ledger-row is a flat 5-field strip (date · desc · account ·
                      amount · buttons). This is dense and the annotate/journal actions are
                      hard to discover. The pattern used in tasks (click row → detail row
                      appears inline) and journal (entry body + action row) should be extended
                      here.

Acceptance criteria:  1. Each transaction row shows: date · description · amount · status
                         indicator (cleared * / pending ! / unmarked).
                      2. Clicking the row expands an inline metadata line showing: account(s),
                         balance, and any existing inline comment (; ...) from the register.
                      3. A persistent "note" icon/button at far right of each row opens the
                         annotate input one line below without displacing other rows.
                      4. The "→ journal" action is moved into the expanded detail line, not
                         the primary row.
                      5. Annotation action uses ledger_annotate (writes "; [date] desc: note"
                         to ledger file) — already implemented.
                      6. Rows are keyboard-navigable (Enter to expand, Escape to collapse).
                      7. Manual smoke check: view transactions, expand row, annotate, journal.

Write scope:          services/browser/static/index.html
                      services/browser/static/app.js
                      services/browser/static/style.css

Tests required:       node --check services/browser/static/app.js

Status:               complete — 2026-04-27. Primary row: date|desc|amount|⊕ note icon (persistent). Click primary row → expands .ledger-detail showing account + chips + notes + all action buttons (journal/project/tags/priority/task/community/archive). Keyboard: Enter toggles, Escape collapses. Status indicator (cleared/pending) skipped — not in server response.
Priority:             medium
