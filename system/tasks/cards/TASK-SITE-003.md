## TASK-SITE-003: Build `ww browser` UI shell — Wave 2 of TASK-SITE-001

Goal:                 Replace the Wave 1 placeholder HTML with a real UI shell: dark
                      terminal-aesthetic layout, collapsing sidebar with profile switcher
                      and nav, a live SSE connection, and a dual-mode terminal input line.
                      No real data in this wave — sections show skeleton placeholders.

Dependency:           TASK-SITE-002 complete (Wave 1 server infrastructure)

---

## Design Specification

### Color palette
  Background (page):  #0d1117
  Surface (cards):    #161b22
  Border:             #21262d
  Text primary:       #e6edf3
  Text muted:         #7d8590
  Accent:             #58a6ff
  Success:            #3fb950
  Warning:            #d29922
  Error:              #f85149
  Terminal green:     #39d353   (used only for the terminal line cursor/prompt)

### Typography
  font-family: ui-monospace, Menlo, Consolas, "Liberation Mono", monospace
  base size: 13px
  line-height: 1.5

### Layout (three-zone)
  ┌──────────────┬───────────────────────────────────────┐
  │   SIDEBAR    │           MAIN CONTENT                │
  │   240px      │           flex-1                      │
  │              │                                       │
  │              │  ┌─────────────────────────────────┐  │
  │              │  │  section header                 │  │
  │              │  ├─────────────────────────────────┤  │
  │              │  │                                 │  │
  │              │  │  content area (scrollable)      │  │
  │              │  │                                 │  │
  │              │  └─────────────────────────────────┘  │
  │              │                                       │
  └──────────────┴───────────────────────────────────────┘
  ┌──────────────────────────────────────────────────────┐
  │  TERMINAL LINE  (fixed bottom, full width)           │
  └──────────────────────────────────────────────────────┘

  When sidebar is collapsed: sidebar width → 0, main content takes full width.
  Transition: sidebar width CSS transition 150ms ease.

### Sidebar (expanded: 240px)
  Sections from top to bottom:
  1. Wordmark: "ww" in accent color + "workwarrior" muted — compact, not huge
  2. Active profile pill: shows current profile name from /health; clickable → opens switcher
  3. Profile switcher (inline dropdown, not a modal):
     - Lists profiles fetched from GET /cmd {"cmd":"profile list"}
     - Clicking a profile POSTs to /profile and updates the pill
     - Hidden by default; shown when profile pill is clicked
  4. Nav links: Tasks | Time | Journal | Ledger
     - Each is a button; active state uses accent color left-border
     - Clicking sets the active section in the main content area
  5. Collapse toggle button at the very bottom of sidebar:
     - Icon: ‹ when expanded, › when collapsed
     - Persists state in localStorage key "ww-sidebar-collapsed"

  Sidebar has no scroll. All content fits in compact form.

### Main content area
  Header bar (fixed top of content area):
  - Left: section name ("Tasks", "Time", "Journal", "Ledger")
  - Right: active profile name + connection status dot (green=connected, red=disconnected)

  Content: each section shows a skeleton placeholder in Wave 2:
  - A muted message: "Tasks — loading in Wave 3"
  - Three skeleton rows (grey bars) to suggest list content is coming
  - Sections are hidden/shown based on sidebar nav selection; Tasks is default

### Terminal line (fixed bottom)
  Full-width bar, 1px top border in border color.
  Two modes — toggled by pressing Tab or typing the mode prefix:

  EXECUTE mode (default):
    Prompt: "❯ " in terminal-green
    Input: free text — on Enter, POST /cmd {"cmd": "<input>"}, render output above line
    Hint text: "type a ww command — tab to filter mode"

  FILTER mode:
    Prompt: "/ " in accent color
    Input: as-you-type filter — dispatches a "filter" CustomEvent on the document
           (Wave 3 sections will listen for this event to filter their content)
    Hint text: "filtering <section> — tab to execute mode"

  Output area (above the input, expands upward):
  - Shows last command output as preformatted text in a box
  - Max height: 40vh, scrollable
  - Dismisses on Escape or when a new command is run
  - Success/error tinted by exit code

  Typeahead skeleton (Wave 2):
  - A hints bar below the prompt showing static placeholder text
  - The real typeahead (fetching ww help output) is Wave 5

  Keyboard shortcuts:
  - Tab: toggle execute/filter mode
  - Escape: clear output / clear input
  - Arrow-up / Arrow-down: command history (localStorage, max 100 entries)
  - The terminal line is focused on page load and re-focused when Escape is pressed

### SSE connection
  On page load, open EventSource("/events").
  On "connected" event: update profile pill and connection dot.
  On "profile" event: update profile pill, broadcast to sections.
  On "ping" event: reset a 30s timeout; if timeout fires, show disconnected dot.
  On error/close: show disconnected dot, retry with exponential back-off (1s, 2s, 4s, max 30s).

---

Acceptance criteria:

  1. `ww browser` opens a page with the dark terminal aesthetic matching the palette above
  2. Sidebar is visible at 240px by default; clicking the toggle collapses it to 0
  3. Collapsed state persists across page reload (localStorage)
  4. Profile pill shows the active profile name (from /health); placeholder "—" if none
  5. Profile switcher lists available profiles on click; selecting one POSTs to /profile
     and updates the pill and the main content header without a page reload
  6. Nav links (Tasks, Time, Journal, Ledger) switch the visible section
  7. Each section shows a skeleton placeholder (no real data — that is Wave 3)
  8. Terminal line is focused on page load
  9. Pressing Tab switches between execute and filter mode; prompt character changes
  10. Typing a valid ww command in execute mode and pressing Enter shows output above the line
  11. Typing in filter mode dispatches a "filter" CustomEvent (verifiable in browser console)
  12. Arrow-up/down cycles through command history; history persists in localStorage
  13. Escape clears output box; second Escape clears the input
  14. Connection dot is green when SSE is connected, red when disconnected
  15. No external fonts, no CDN links, no npm — everything served from services/browser/static/
  16. Page renders correctly with sidebar collapsed and with sidebar expanded
  17. `bats tests/test-browser.bats` continues to pass (no regressions to Wave 1 tests)

---

Write scope:          /Users/mp/ww/services/browser/static/index.html   (new)
                      /Users/mp/ww/services/browser/static/style.css    (new)
                      /Users/mp/ww/services/browser/static/app.js       (new)
                      /Users/mp/ww/services/browser/server.py           (update _handle_index + add static file serving)
                      /Users/mp/ww/tests/test-browser.bats              (add Wave 2 smoke tests)

---

server.py changes required:
  - Replace _handle_index() to serve static/index.html from disk
  - Add GET routing for /static/* (or bare /app.js, /style.css) to serve static files
    Simpler: serve /app.js and /style.css as named paths; no directory listing needed
  - Correct MIME types: text/html, text/css, application/javascript
  - 404 for any other unknown path

New BATS tests to add to test-browser.bats:
  - GET / returns 200 with Content-Type text/html
  - GET /app.js returns 200 with Content-Type application/javascript
  - GET /style.css returns 200 with Content-Type text/css
  - GET / response body contains "workwarrior" (case-insensitive)
  - GET /nonexistent returns 404

---

Tests required:       bats tests/test-browser.bats
                      Manual: ww browser (open in browser, verify layout, sidebar, terminal line)
                      Manual: Tab key toggles mode; Enter executes command; Arrow-up recalls history

Rollback:             rm -rf /Users/mp/ww/services/browser/static/
                      git checkout /Users/mp/ww/services/browser/server.py
                      git checkout /Users/mp/ww/tests/test-browser.bats

Fragility:            None — new static files + minimal server.py change to _handle_index()
                      No changes to bin/ww in this wave

Risk notes:           (Orchestrator) server.py _handle_index() is a clean, self-contained
                      method. Only that method and the do_GET router need updating.
                      Static file serving should use open(path, 'rb') with a try/except
                      for missing files (return 404). No directory traversal risk since
                      paths are hardcoded (/app.js, /style.css), not user-controlled.
                      (Builder pre-flight) TBD

Status:               complete
