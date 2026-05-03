## TASK-SITE-005: Wave 4 — Time/Journal/Ledger polish + top bar + typeahead + terminal position

Goal:                 Polish the three remaining data sections (Time, Journal, Ledger),
                      enrich the top bar with live stats, improve the terminal typeahead
                      with real command hints, and add a keyboard shortcut to move the
                      terminal bar between top and bottom of the screen.

Dependency:           TASK-SITE-004 complete (Wave 3 live data)

---

## 1. Top Bar Enhancement

Current: section title (left) | profile name + conn dot (right)

New layout — two rows:

  Row 1 (primary): section title (left) | stats cluster (right)
  Row 2 (secondary, muted, smaller): breadcrumb/context line

Stats cluster (right side of row 1) — live, updated on profile switch and section load:
  ● conn dot
  profile: <name>          — profile name, clickable (same as sidebar pill — opens switcher)
  <N> tasks                — count of pending tasks (from last /data/tasks response)
  <Xh Ym> today            — today's tracked time (from last /data/time response)
  <date>                   — current date, e.g. "Thu Apr 10"

Row 2 (secondary bar, always shown):
  In Tasks section:   "project: <active filter or 'all'> · <N pending> · <N active>"
  In Time section:    "week: <Xh Ym tracked> · <active: tracking / idle>"
  In Journal section: "entries: <N> · last: <most recent entry date>"
  In Ledger section:  "balance: assets <$N> · expenses <$N> this month"
  Default:            profile path (muted)

The stats cluster values are cached from the last data fetch — no extra requests.
Update them inside loadTasks(), loadTime(), loadJournal(), loadLedger() after data arrives.

New element IDs needed:
  #stat-tasks-count    — e.g. "8 tasks"
  #stat-time-today     — e.g. "3h 20m today"
  #stat-date           — e.g. "Thu Apr 10"
  #stat-context-bar    — the secondary row text

---

## 2. Time Section Polish

Current state renders basic today card + week bars + recent intervals. Polish:

  Today card:
  - Larger today total (20px), muted "today" label beside it
  - If active interval: green pulsing dot + "tracking <tags>" since HH:MM (local time)
  - If idle: muted "idle" text
  - Sub-breakdown: show top 3 tags/descriptions by duration today as mini rows

  Week bars:
  - Label each day with its date (e.g. "Mon 7") not just day name
  - Current day bar uses accent color, other days use muted
  - Show percentage label at end of bar if >0 ("2h 10m" already shows; keep)
  - Total week hours in a summary row below bars

  Recent intervals:
  - Show date + description + duration
  - Group by day with a day header ("Today", "Yesterday", "Mon Apr 7")
  - Active interval row shows pulsing dot and elapsed time

---

## 3. Journal Section Polish

Current: entries listed with date + body, 3-line truncation.

Polish:
  - Entry date formatted as human-readable: "Thu Apr 9, 11:15" not raw timestamp
  - Tags (words starting with @) highlighted in accent color within body text
  - Search bar above entry list — client-side filter by body text (same pattern as task filter)
  - Entry count in secondary context bar
  - New entry form: auto-focus the textarea when opened; Escape closes it

---

## 4. Ledger Section Polish

Current: balance rows + recent transactions from hledger JSON (which has a complex nested structure).

The hledger JSON balance output is deeply nested and hard to parse generically.
Simplify: use hledger TEXT output instead of JSON, parse it line by line.

New server endpoint adjustment for /data/ledger:
  Run: hledger -f <file> balance --flat --no-total
  Run: hledger -f <file> register --output-format=tsv (tab-separated, simpler to parse)
  Parse balance lines: "  <amount>  <account>" (leading spaces then amount then account)
  Parse register lines: tsv columns — date, description, account, amount, balance
  Return: {"ok":true, "balances":[{"account":"...","amount":"..."}],
           "recent":[{"date":"...","description":"...","account":"...","amount":"..."}]}

UI polish:
  - Balance rows: indent sub-accounts visually (count colons in account name)
  - Asset accounts: accent text for amount
  - Income accounts: success color
  - Expense accounts: warning color (amount)
  - Liability accounts: error color
  - Running balance shown in recent transactions
  - Month/year header above recent list

---

## 5. Terminal Line Typeahead

Current: static hint text only ("type a ww command — tab to filter mode")

New typeahead behavior:

  On page load (or first keypress):
  - Fetch GET /data/commands → returns list of top-level ww commands
  - Add new endpoint to server: GET /data/commands
    Runs: ww help (captures output, parses command names and one-line descriptions)
    Returns: {"commands": [{"name":"tasks","desc":"..."},{"name":"profile","desc":"..."},...]}
    Cache this in the client — only fetched once per page load

  As user types in execute mode:
  - Match input prefix against command list
  - Show top match in hints bar: "<command> — <description>"
  - If no match: show "type a ww command — tab to filter mode"
  - Example: user types "pr" → hints bar shows "profile — manage profiles · journal — ..."
  - Show up to 3 matches separated by "·"

  As user types in filter mode:
  - Hints bar shows: "filtering <N> items in <section>"
  - Updates count as filter reduces rows

  Command history in hints:
  - If input is empty and history exists: show "↑ <most recent command>" in muted text
  - If navigating history (ArrowUp/Down in execute mode): show "(history <N>/<total>)" in hints

---

## 6. Terminal Position Toggle

Add keyboard shortcut and button to move the terminal bar between bottom (default) and top.

  Shortcut: Ctrl+Shift+T (or a small ⇅ button at the far right of the terminal input row)
  Toggle between: position:fixed bottom:0  ↔  position:fixed top:0
  When at top: #app padding adjusts (top instead of bottom offset)
  State persists in localStorage key "ww-term-position" ("bottom" | "top")
  On init: restore saved position

  Visual indicator: the ⇅ button shows "↑" when at bottom (click moves to top),
                    shows "↓" when at top (click moves to bottom)

---

Acceptance criteria:

  1.  Top bar shows: section title, pending task count, today's tracked time, current date, conn dot, profile name
  2.  Secondary context bar shows section-relevant stats that update on data load
  3.  Profile name in top bar is clickable and opens the profile switcher (same as sidebar pill)
  4.  Time section today card shows active tracking state with pulsing dot if interval is open
  5.  Time week bars label current day distinctly; total row shows week sum
  6.  Time recent intervals grouped by day with human-readable day headers
  7.  Journal entries show human-readable dates
  8.  Journal @ tags highlighted in accent color
  9.  Journal search bar filters entries client-side
  10. Ledger balances parsed from hledger text output, sub-accounts indented
  11. Ledger recent transactions show date, description, account, amount clearly
  12. Typeahead shows matching command names + descriptions as user types
  13. Hints bar shows filter count in filter mode
  14. History hint shows most recent command when input is empty
  15. Ctrl+Shift+T (or ⇅ button) toggles terminal between top and bottom
  16. Terminal position persists in localStorage across reload
  17. #app padding adjusts correctly when terminal moves to top
  18. bats tests/test-browser.bats passes (16 tests — no regressions)
  19. bats tests/test-browser-data.bats passes (9 tests — no regressions)

---

Write scope:          /Users/mp/ww/services/browser/server.py        (update /data/ledger + add GET /data/commands)
                      /Users/mp/ww/services/browser/static/app.js    (top bar stats, section polish, typeahead, terminal position)
                      /Users/mp/ww/services/browser/static/index.html (top bar markup, terminal position button)
                      /Users/mp/ww/services/browser/static/style.css  (top bar styles, pulsing dot, indented ledger, typeahead hints)

Tests required:       bats tests/test-browser.bats
                      bats tests/test-browser-data.bats
                      Manual: verify typeahead shows hints while typing
                      Manual: Ctrl+Shift+T moves terminal to top, persists on reload

Rollback:             git checkout services/browser/

Fragility:            None — all changes isolated to services/browser/

Risk notes:           (Orchestrator) hledger text output is more stable than JSON across
                      versions — use --flat --no-total for balance, TSV for register.
                      /data/commands parses `ww help` stdout — the command list section
                      starts after "Commands:" and each line is "  <name>  <desc>".
                      Terminal position toggle: when moving to top, set
                      #app { padding-top: <terminal-height>px; padding-bottom: 0 }
                      and vice versa. Use getBoundingClientRect() to measure terminal height
                      after DOM settles rather than hardcoding 60px.
                      Pulsing dot: CSS @keyframes pulse on opacity, no JS timer needed.
                      (Builder pre-flight) TBD

Status:               complete
