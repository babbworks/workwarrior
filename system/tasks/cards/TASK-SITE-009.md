## TASK-SITE-009: Fix Times screen — clicking recent interval starts tracking

Goal:                 Clicking an item in the Times recent intervals list should
                      start time tracking with those tags. This has been requested
                      multiple times but the click handler is not working reliably.

Acceptance criteria:  1. Clicking any interval row in the Recent list starts timew
                         tracking with the tags from that interval
                      2. The time display updates to show active tracking
                      3. The action buttons (annotate, journal) still work independently
                      4. Manual test: click an interval, verify with `timew` CLI

Write scope:          services/browser/static/app.js

Tests required:       Manual: open Times tab, click a recent interval, verify tracking starts

Rollback:             git checkout services/browser/static/app.js

Fragility:            LOW

Risk notes:           (Orchestrator) Previous attempts added click handlers but they
                      may not be attaching correctly due to dynamic HTML rendering.
                      The interval rows are rebuilt on each loadTime() call.

Status:               complete

Completion note:      Click handler moved from .int-tags to entire .interval-row
                      with e.target.closest('.int-actions') guard for action buttons.
                      Also removed duplicate .int-tags handler that was conflicting.
