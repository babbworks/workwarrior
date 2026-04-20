## TASK-SITE-006: ww browser Wave 5 — export, terminal UX, spacing, search, services sidebar

Goal:                 Complete the browser service with static export, a redesigned terminal
                      UX that handles command+subcommand flows naturally, inline add forms,
                      density control, transaction search, and initial services sidebar.

Acceptance criteria:

  1. Timer bug fixed
       TIMEWARRIORDB passed to run_task env in server.py so task start/stop
       correctly writes to the active profile's .timewarrior directory.

  2. ww browser export [path]
       Generates a single self-contained .html file with all profile data embedded
       as JSON in <script> tags. CSS and JS inlined. Zero external dependencies.
       Opens offline in any browser. Default output: ./ww-export-<profile>-<date>.html
       ww browser export --path ~/Desktop/snapshot.html for custom path.

  3. Terminal UX — command+subcommand context mode
       When user types a known command+subcommand combo (e.g. "journal add",
       "j add", "task add", "ledger add") and presses Enter:
         - The combo appears as a context label above the terminal input line
           (e.g. "journal add ›") replacing the hints bar
         - The terminal prompt changes to a continuation indicator (e.g. "  ")
         - The input is now free-form for arguments (description, entry text, etc.)
         - Pressing Enter submits the full command+args to /action or /cmd
         - Pressing Escape clears context and returns to normal execute mode
       Single-token commands (e.g. "journal", "tasks", "time") switch the active
       section without entering context mode.
       All existing execute/filter/history behaviour preserved.

  4. Inline add forms — remove floating "+ Add" buttons
       Add forms are always visible at the top of each section, not hidden behind
       a button. Compact single-row layout: inputs inline, submit on Enter.
       Journal: single textarea row, submit on Ctrl+Enter (multiline) or Enter (single line).
       Ledger: date + description + account + amount inline, submit on Enter.
       Tasks: description + optional project/tags/priority/due inline, submit on Enter.

  5. Density control
       Horizontal slider at the bottom of the sidebar with three stops:
       compact / normal / relaxed. Controls --row-gap CSS variable (4px / 8px / 14px)
       and --font-size (12px / 13px / 14px). Persisted in localStorage.
       Label: "density" with three dot indicators showing current stop.

  6. Transaction search
       Search input below the ledger recent transactions list (same style as
       journal search). Filters visible transaction rows client-side as-you-type.

  7. Services sidebar — low-hanging fruit
       Add a "Services" section to the sidebar nav below the four data sections.
       Initial services exposed (read-only first):
         - next        → calls ww next, renders recommended task in a card
         - schedule    → shows ww schedule status (enabled/disabled, last run)
         - density     → shows ww profile density config
       Each service renders in the main content area as a new section.
       Services that require install show an install prompt instead of data.

  8. SITE-007 carry-forward decisions
       Preserve "Saves" naming in browser UI labels/routes.
       Preserve existing icon system, including placeholder weapon icons.
       Treat read-only service panels as acceptable for this wave.

Write scope:          /Users/mp/ww/services/browser/server.py
                      /Users/mp/ww/services/browser/static/index.html
                      /Users/mp/ww/services/browser/static/app.js
                      /Users/mp/ww/services/browser/static/style.css
                      /Users/mp/ww/services/browser/browser.sh  (export subcommand)

Tests required:       bats tests/test-browser.bats
                      Manual: task start → verify timew tracking in profile .timewarrior
                      Manual: ww browser export → verify single HTML file opens offline
                      Manual: terminal context mode with "journal add", "task add"
                      Manual: density slider persists across reload
                      Manual: transaction search filters rows

Rollback:             git checkout services/browser/

Fragility:            Low — services/browser/ only, no lib or bin/ww changes

Status:               pending
