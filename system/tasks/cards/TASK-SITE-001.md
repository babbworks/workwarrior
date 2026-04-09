## TASK-SITE-001: Design and implement `ww browser` — locally-served Workwarrior web UI

Goal:                 Deliver a locally-served, terminal-aesthetic web interface for Workwarrior
                      accessible via `ww browser`, providing live task/time/journal/ledger data,
                      real command execution via an in-page terminal line, profile switching,
                      and a collapsing sidebar — with a static export path for sharing.

---

## Architecture Decision: Static vs Live

Both approaches have merit. This task adopts a hybrid model:

PRIMARY: Live server
  - `ww browser` launches a Python3 HTTP server (stdlib only, zero external deps)
  - Server-Sent Events (SSE) stream live data updates to the browser
  - Thin POST endpoint executes `ww` commands and returns structured output
  - Profile switching in-browser updates server-side active profile, reflects immediately
  - Actions (complete task, log time, add journal entry) execute against real profile data

SECONDARY: Static export
  - `ww browser export [path]` generates a static HTML snapshot of current profile state
  - Snapshot is self-contained: single HTML file or flat directory, no server required
  - Suitable for sharing, publishing, or archiving a point-in-time view

Rationale: Live is required for real actions and real-time data; static is required for
portability and publish capability. Python3 stdlib covers both with no added dependencies.

---

## Service Namespace

Service name:  `browser`   (ww browser)
Reserved name: `sites`     — reserved for profile documentation site generation (future)

Command surface:
  ww browser              — launch live server, open in default browser
  ww browser --port N     — use custom port (default: 7777)
  ww browser --no-open    — start server without launching browser
  ww browser export       — generate static snapshot to ./ww-browser-export/
  ww browser export PATH  — generate static snapshot to PATH
  ww browser stop         — stop running server
  ww browser status       — show whether server is running and on which port

---

## UI Design Principles

Terminal aesthetic:
  - Monospace font throughout (system-ui fallback chain: ui-monospace → Menlo → Consolas)
  - Dark background, high-contrast text — not pure black; near-black (#0d1117 or similar)
  - Subtle scanline or grid texture optional but not cliche (no green-on-black Matrix theme)
  - Color used sparingly: accent for active state, muted tones for secondary content
  - Animations fast and functional, not decorative

Layout:
  - Collapsing sidebar (left): compact but complete — profile switcher, nav sections, filters
  - Main content area: full width when sidebar collapsed, comfortable split when open
  - Sidebar collapse persists in localStorage
  - No floating panels; no modal-heavy flows; actions happen inline

Terminal line:
  - Persistent input bar, keyboard-first (always focused unless user clicks elsewhere)
  - Dual mode:
      EXECUTE: typed command runs against active profile via POST → output rendered inline
      FILTER:  as-you-type filtering of visible data with hints and context surfaced live
  - Mode toggle: explicit (keyboard shortcut or prefix character) or auto-detected by input
  - Typeahead / command hints drawn from ww --help output and recent command history
  - Output rendered as structured result (not raw terminal dump) where possible;
    fallback to preformatted text for unstructured output

Sidebar contents (compact):
  - Profile switcher (active profile highlighted, one-click switch)
  - Navigation: Tasks | Time | Journal | Ledger
  - Quick filters (context-sensitive per section): project, tag, date range, status
  - System status: server uptime, active profile, last sync timestamp

---

## Data Scope

All four tools surfaced:

  Tasks    — active tasks with urgency, project, tags, due date; filterable; actionable
             Actions: start, stop, done, annotate, delete, add
  Time     — today's tracked intervals; weekly summary; tag/project breakdown
             Actions: start tracking, stop tracking, add manual interval
  Journal  — recent entries with search; full-text filter; date navigation
             Actions: new entry, append to today's entry
  Ledger   — account balances; recent transactions; monthly summary
             Actions: add transaction (opens structured form)

---

## Profile Switching

  - Sidebar profile switcher lists all profiles from profiles/ directory
  - Switching profile updates server-side env vars (TASKRC, TASKDATA, TIMEWARRIORDB, etc.)
  - All open data views refresh via SSE immediately after switch
  - Terminal line context updates to reflect new profile
  - Active profile name visible in sidebar header and browser tab title

---

## Export / Publish

  - `ww browser export` generates a flat static snapshot
  - Snapshot includes rendered HTML for each section (tasks, time, journal, ledger)
  - No server-side logic in export — all data baked in at export time
  - Suitable for: sharing a weekly review, publishing a project status page,
    archiving a profile state before migration

---

## Implementation Waves

This task is large. Implementation is broken into sequential waves:

Wave 1 — Server scaffolding (TASK-SITE-002)
  - services/browser/ directory and entry script
  - Python3 HTTP server with SSE endpoint
  - POST /cmd endpoint executing ww commands
  - Profile switching endpoint
  - `ww browser` and `ww browser stop/status` commands wired into bin/ww

Wave 2 — Shell and layout (TASK-SITE-003)
  - Base HTML/CSS: dark theme, monospace, sidebar, main area
  - Sidebar: profile switcher, nav, collapse/expand
  - Terminal line: input bar, execute mode, filter mode, typeahead skeleton

Wave 3 — Tasks section (TASK-SITE-004)
  - Task list with urgency, project, tags, due date
  - Inline actions: start, stop, done, annotate
  - Live SSE updates when task state changes

Wave 4 — Time, Journal, Ledger sections (TASK-SITE-005)
  - Time: today's intervals, weekly summary
  - Journal: recent entries, full-text filter, new entry action
  - Ledger: balances, recent transactions, add transaction form

Wave 5 — Export and polish (TASK-SITE-006)
  - `ww browser export` static snapshot command
  - Terminal line: full typeahead, command history, structured output rendering
  - Keyboard shortcuts documented and functional
  - Final aesthetic pass

---

Acceptance criteria:

  1. `ww browser` launches a local HTTP server and opens the UI in the default browser
  2. UI loads within 2 seconds on localhost with a full profile active
  3. Terminal line executes `ww` commands and renders output within the page
  4. Terminal line filters visible section data as-you-type with no page reload
  5. All four data sections (tasks, time, journal, ledger) render live data from active profile
  6. Sidebar collapses and expands; state persists across page reload
  7. Profile switcher changes active profile; all sections refresh within 1 second
  8. At least one action per section works end-to-end (e.g. `ww done <id>` marks task complete)
  9. `ww browser export` produces a self-contained static snapshot with no server dependency
  10. `ww browser stop` halts the server cleanly; `ww browser status` reports correctly
  11. No external npm/pip dependencies — Python3 stdlib + vanilla JS only
  12. bats tests/test-browser.sh passes for server lifecycle (start, stop, status, port)

Write scope:          services/browser/                  (new directory — all files within)
                      bin/ww                             (add browser command routing)
                      tests/test-browser.sh              (new BATS suite)
                      system/config/command-syntax.yaml  (add browser command surface)

Tests required:       bats tests/test-browser.sh
                      bats tests/
                      Manual: ww browser (verify UI loads, terminal line, profile switch)
                      Manual: ww browser export (verify snapshot opens without server)

Rollback:             git rm -r services/browser/
                      git checkout bin/ww
                      git checkout system/config/command-syntax.yaml

Fragility:            SERIALIZED: bin/ww — confirm no parallel active task touches this file
                      None other — services/browser/ is new, no existing behavior affected

Risk notes:           (Orchestrator) No existing service named `browser` or `sites` — clean
                      namespace. bin/ww serialization is the only coordination risk.
                      Python3 stdlib HTTP server is single-threaded; SSE + POST must be
                      handled carefully to avoid blocking. Builder should evaluate
                      threading.Thread for SSE vs. a forked watcher process.
                      Port conflict on 7777: Builder must implement port-in-use detection
                      and clear error message before attempting bind.
                      (Builder pre-flight) TBD

Status:               pending
