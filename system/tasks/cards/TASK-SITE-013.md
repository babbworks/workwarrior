## TASK-SITE-013: Error states with retry buttons

Goal:                 When data fetch fails, show a retry button instead of
                      a static "error" text. Currently all loadX() functions
                      write "Error: <msg>" and stop. Users cannot recover
                      without reloading the page.

Scope summary:
  1. Shared renderError(container, msg, retryFn) helper: renders error text
     plus a "retry" button that calls retryFn() on click
  2. Apply to: loadTasks, loadTime, loadJournal, loadLedger, loadNext,
     loadSchedule, loadSync, loadGroups, loadModels, loadNetwork,
     loadQuestions, loadProjects, loadProfileScreen, loadWarrior
  3. Retry should show skeleton-msg briefly before re-fetching

Approach:             Single helper function, systematic replacement of
                      catch blocks — low-risk.

Write scope:          services/browser/static/app.js

Fragility:            LOW

Dependencies:         none

Status:               complete — 2026-04-13
