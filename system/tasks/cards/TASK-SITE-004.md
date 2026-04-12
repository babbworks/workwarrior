## TASK-SITE-004: Live data sections for `ww browser` — Wave 3 of TASK-SITE-001

Goal:                 Replace skeleton placeholders in all four sections (Tasks, Time,
                      Journal, Ledger) with live data fetched from the active profile.
                      Add GET /data/* endpoints to server.py for structured JSON responses.
                      Add POST /action endpoint for task mutations (start, stop, done, add).

Dependency:           TASK-SITE-003 complete (Wave 2 UI shell)

---

## New Server Endpoints

Add to server.py (do_GET and do_POST routing + handler methods):

  GET /data/tasks
    Returns all pending tasks for the active profile as JSON.
    Runs: task export status:pending
    Env: TASKRC and TASKDATA set to profile paths
    Response: {"ok": true, "tasks": [...task objects...]}
    Each task object: id, uuid, description, project, tags, urgency, due, status,
                      priority, annotations (array of {entry, description}), entry, modified

  GET /data/time
    Returns this week's time intervals plus today's summary.
    Runs: timew export :week  (JSON export, one object per interval)
    Env: TIMEWARRIORDB set to profile path
    Response: {"ok": true, "intervals": [...], "today_total_seconds": N,
               "week_total_seconds": N, "active": bool, "active_since": "ISO8601 or null"}
    Parse intervals to compute today/week totals in Python.

  GET /data/journal
    Returns the most recent 20 journal entries from the profile's default journal file.
    Read the txt file directly (no jrnl CLI — too slow, needs config). Parse entries by
    the "[YYYY-MM-DD HH:MM]" header line format.
    Response: {"ok": true, "entries": [{"date": "...", "body": "..."}]}

  GET /data/ledger
    Returns account balances and 10 most recent transactions.
    Runs: hledger -f <ledger-file> balance --output-format=json
          hledger -f <ledger-file> register --output-format=json  (most recent 10)
    If hledger not found, return {"ok": false, "error": "hledger not installed"}
    Response: {"ok": true, "balances": [...], "recent": [...]}

  POST /action
    Executes a task mutation and returns updated task data.
    Body: {"action": "start"|"stop"|"done"|"add"|"annotate", "id": N, "args": {...}}
    For "add": {"action":"add","args":{"description":"...","project":"...","tags":[...],"priority":"H|M|L","due":"YYYY-MM-DD"}}
    For "annotate": {"action":"annotate","id":N,"args":{"note":"..."}}
    Runs task subcommand with TASKRC/TASKDATA env, returns {"ok":bool,"output":"..."}
    After mutation, returns updated task list inline: {"ok":true,"output":"...","tasks":[...]}

## Profile Path Resolution

server.py needs a helper to get profile tool paths:

  def get_profile_paths(self) -> dict:
      profile = self.get_active_profile()
      if not profile:
          return {}
      base = os.path.join(self.ww_base, "profiles", profile)
      return {
          "taskrc":       os.path.join(base, ".taskrc"),
          "taskdata":     os.path.join(base, ".task"),
          "timewarriordb":os.path.join(base, ".timewarrior"),
          "journal_file": os.path.join(base, "journals", f"{profile}.txt"),
          "ledger_file":  os.path.join(base, "ledgers", f"{profile}.journal"),
          "ledgers_yaml": os.path.join(base, "ledgers.yaml"),
      }

  Note: journal and ledger default file names follow the "<profile-name>.*" convention.
  If ledgers.yaml exists, parse it to find the actual default ledger path (key: ledgers.default).
  Same for jrnl.yaml → journals.default for the journal path.

---

## UI Changes (app.js + index.html)

### Tasks section (#section-tasks)

Replace skeleton with:
- Section toolbar: "+ Add task" button (right-aligned), filter input (inline, small)
- Task list: one row per task
  Each row:
    [ urgency score ] [ project ] description [ tags ] [ due ] [ priority dot ] [ actions … ]
  - Urgency: right-aligned muted number (1 decimal), colored by range:
      < 5: muted   5–10: text  10–15: warning  > 15: error
  - Project: accent-colored badge, small
  - Tags: muted, comma-separated, small
  - Due: shows relative time ("in 2 days", "overdue") — overdue in error color
  - Priority dot: H=error, M=warning, L=muted
  - Actions: ▶ start / ■ stop / ✓ done — shown on row hover; always visible on active task
  - Active task (status:active): left border in success color, subtle background tint
- Clicking a row expands it to show annotations inline
- "+ Add task" opens an inline form at the top of the list (not a modal)
  Fields: description (required), project, tags (comma-sep), priority (H/M/L), due (date)
  Submit → POST /action {"action":"add",...} → refresh list

### Time section (#section-time)

Replace skeleton with:
- Today card: "Today — X h Y m" with a breakdown by tag/description
  If active interval: show "● Tracking: <description> (since HH:MM)" in success color
- This week: bar-like rows for each day Mon-today showing total hours
  Simple text representation: "Mon  3h 20m  ████░░░░" (CSS width bars, no canvas)
- Recent intervals table: date | description | duration — last 10

### Journal section (#section-journal)

Replace skeleton with:
- Entry list: most recent first
  Each entry: date header (muted) + body text
  Body truncated at 3 lines with "show more" toggle
- "+ New entry" button → inline textarea at top, submit appends to journal file via POST /action
  Action: {"action":"journal_add","args":{"entry":"..."}}  (server appends to journal txt file)

### Ledger section (#section-ledger)

Replace skeleton with:
- Balance summary: one row per account with balance, indented by account depth
  Asset accounts highlighted, income accounts in success, expense accounts in warning
- Recent transactions: date | description | amount | account (last 10)
- "+ Add transaction" button → inline form: date, description, account, amount
  Action: {"action":"ledger_add","args":{...}}  (server appends to journal file)

### Filter mode wiring

app.js already dispatches a 'filter' CustomEvent. In Wave 3, each section
registers a listener and filters its visible rows client-side (no server round-trip):
  document.addEventListener('filter', (e) => {
    if (e.detail.section !== activeSection) return;
    // filter rows by matching e.detail.query against description/project/tags
  });

---

## Dummy Profile

A "demo" profile has been pre-seeded with the following data for development/demo use:
  Tasks: 10 pending (projects: infra, api, docs, maintenance, observability, comms)
         2 completed, 1 active (CORS fix), annotations on 2 tasks
  Time:  ~5 days of intervals this week; 1 active interval (Postgres migration)
  Journal: 5 entries Apr 3–9 covering infra, API, database, and team sync topics
  Ledger:  8 transactions, balanced across expenses/income/assets

To view: ww browser --no-open  then POST /profile {"profile":"demo"}

---

Acceptance criteria:

  1. GET /data/tasks returns {"ok":true,"tasks":[...]} with all pending tasks
     including urgency, project, tags, due, annotations, priority fields
  2. GET /data/time returns {"ok":true,"intervals":[...],"today_total_seconds":N,
     "week_total_seconds":N,"active":bool}
  3. GET /data/journal returns {"ok":true,"entries":[...]} with at most 20 entries,
     most recent first
  4. GET /data/ledger returns {"ok":true,"balances":[...],"recent":[...]}
     or {"ok":false,"error":"hledger not installed"} if hledger absent
  5. POST /action with action=done marks a task complete and returns updated task list
  6. POST /action with action=add creates a new task and returns updated list
  7. Tasks section renders real task rows with urgency, project, tags, due, priority
  8. Active task (status:active) has visually distinct styling
  9. Row hover reveals action buttons; clicking done marks task complete and refreshes
  10. "+ Add task" form creates a task and the new task appears in the list
  11. Time section shows today's total and a per-day breakdown for the week
  12. Journal section shows recent entries, truncated at 3 lines with expand toggle
  13. Ledger section shows account balances with appropriate color coding
  14. Filter mode (terminal line) filters visible task rows by query string client-side
  15. Switching profiles via sidebar re-fetches all section data for the new profile
  16. All sections gracefully handle an empty or missing data store (show "no data" state)
  17. bats tests/test-browser.bats passes (no regressions — 16 tests)
  18. New: bats tests/test-browser-data.bats passes (covers /data/* and /action endpoints)

---

Write scope:          $WW_BASE/services/browser/server.py        (add /data/* + /action endpoints)
                      $WW_BASE/services/browser/static/app.js    (replace skeleton sections with live data)
                      $WW_BASE/services/browser/static/index.html (update section markup)
                      $WW_BASE/services/browser/static/style.css  (add task row, time bar, ledger styles)
                      $WW_BASE/tests/test-browser-data.bats       (new BATS suite for data endpoints)

Tests required:       bats tests/test-browser.bats     (regression check — must still pass 16)
                      bats tests/test-browser-data.bats (new)
                      Manual: ww browser — switch to demo profile, verify all 4 sections show data
                      Manual: complete a task in the browser, verify it disappears from pending list

Rollback:             git checkout services/browser/server.py
                      git checkout services/browser/static/
                      git rm tests/test-browser-data.bats

Fragility:            None — changes are isolated to services/browser/
                      No bin/ww changes in this wave

Risk notes:           (Orchestrator) Journal parsing: read txt file directly — do not invoke
                      jrnl CLI (slow, requires config). Entry header format is "[YYYY-MM-DD HH:MM]".
                      Ledger path: read ledgers.yaml to find the actual file path rather than
                      assuming "<profile>.journal" — use yaml.safe_load if available, else
                      parse with regex (stdlib only, no PyYAML assumption).
                      TimeWarrior active interval: the last entry in the .data file has no end
                      time (format: "inc YYYYMMDDTHHMMSSZ # ..."). Detect this for active=true.
                      hledger JSON output: use --output-format=json flag (hledger >= 1.20).
                      If it fails, fall back to text output and return as a raw string.
                      task export: runs fast and returns clean JSON — preferred over parsing
                      task report output.
                      (Builder pre-flight) TBD

Status:               complete
