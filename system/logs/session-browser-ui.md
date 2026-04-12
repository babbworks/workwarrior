# Session Log — Browser UI Development (April 2026)

Phase: Phase 2 — TASK-SITE-004/005 continuation
Scope: services/browser/ (server.py, static/app.js, static/index.html, static/style.css)

---

## Changes Delivered

### 1. Resource Creation Backend (POST /resource/create)
- New endpoint creates journals, ledgers, tasklists, and timew instances
- Creates backing files/dirs on disk, registers in profile YAML configs
- Tasklists get their own .taskrc + .task directory under tasklists/<name>/
- Timew instances get a directory under timew/<name>/
- Auto-creates tasklists.yaml and timew.yaml on first use, seeding with default entry

### 2. Resource Selector Dropdowns
- All four sections (tasks, times, journals, ledgers) show a dropdown + "+" create button
- get_profile_resources() now reads tasklists.yaml and timew.yaml when present
- Inline create form: type a name, click create, auto-switches to new resource

### 3. Profile Dropdown Fix
- Replaced fragile `ww profile list` CLI parsing with GET /data/profiles endpoint
- Reads profiles directory directly — reliably shows all profiles

### 4. Tab Renames
- Time → Times, Journal → Journals, Ledger → Ledgers in sidebar nav
- Section title header maps correctly for each tab

### 5. Task Form Enhancements
- Default due date: 2 days from today
- "save" button (Enter also submits)
- "start" button: creates task and immediately starts it

### 6. Task Detail Panel
- Click any task row to expand a detail panel below the list
- Shows: description, project, tags, due, priority, urgency, status, created, UUID, annotations
- "annotate" input: adds annotation to the task via TaskWarrior
- "→ journal" input: writes a note to the profile journal prefixed with [task:ID]
- Both inputs submit on Enter
- Panel closes with × or when task list refreshes

### 7. Journal Entry Fix
- Enter now submits the journal textarea (Shift+Enter for newlines)
- Forms no longer hide themselves after successful submission

### 8. Ledger Enhancements
- Date defaults to today
- Account input has autocomplete via datalist populated from GET /data/accounts
- New endpoint uses `hledger accounts` for known account names
- Autocomplete refreshes after each transaction and on profile switch
- Fixed TSV column mapping: amount was off by one (skipped code column)

### 9. Time Tab
- New inline form: tags, duration, task association dropdown
- ▶ start: begins live timew tracking with tags
- ■ stop: stops current tracking
- + track: records a past interval with specified duration
- Task dropdown populated from pending tasks
- Click any interval in Recent list to start tracking those tags
- Server: timew_start, timew_stop, timew_track actions added to POST /action

### 10. Next Tab Fix
- Replaced unreliable `task next export` with `task status:pending export` sorted by urgency
- Added "skip" button alongside start/done
- Context bar shows recommended task info
- Removed dead ww next CLI call that caused delays

### 11. Context Bar Per-Section
- Each section now updates the header context bar with relevant info
- Next: task description + urgency
- Schedule: label
- Gun: attribution
- No more stale info from previous tab

### 12. Sidebar Fix
- Added padding-bottom: 48px to sidebar to prevent density control and collapse toggle from being clipped by the terminal bar

### 13. Form Alignment
- Changed align-items to center, gave all inputs/selects/buttons consistent height: 28px
- Save and start buttons now sit flush with input fields

### 14. Weapons Bar
- New weapons-bar div below profile pill, above nav
- 🔫 Gun button: opens the Gun section
- ⚔️ Sword button: rendered but disabled (future service)

### 15. Gun Section (Browser UI for ww gun)
- Full form: project, parts, unit, offset, interval, skip
- Submits via POST /cmd with `gun create ...` command
- Shows output/errors inline
- `gun` and `next` added to ALLOWED_SUBCOMMANDS
- Context bar shows "bulk task series generator · taskgun"

---

## Task Cards

| Card | Status | Notes |
|---|---|---|
| TASK-SITE-004 | complete | Wave 3 live data — all endpoints and mutations |
| TASK-SITE-005 | in-progress | Wave 4 — time/journal/ledger polish, resource creation |
| TASK-EXT-SWORD-001 | pending | Sword weapon — design TBD |

---

## Files Modified

- services/browser/server.py — resource creation, accounts endpoint, profiles endpoint, timew actions, next fix, TSV fix, gun/next in allowed subcommands
- services/browser/static/app.js — all UI logic: forms, detail panel, dropdowns, gun section, weapons bar, context bar, tab names, interval click, profile loading
- services/browser/static/index.html — tab names, task detail div, time form, ledger datalist, gun section, weapons bar
- services/browser/static/style.css — alignment, sidebar padding, task detail, clickable intervals/rows, weapons bar, gun panel, inline buttons

## Files Created

- system/tasks/cards/TASK-EXT-SWORD-001.md — sword weapon task card
- system/logs/session-browser-ui.md — this log

---

## Continued: Editing and Annotation Across All Sections

### 16. Task Editor with UDA Support
- Click a task row to open a full editing panel
- Editable grid: description, project, priority, due, tags (with add/remove diff)
- Read-only fields: status, urgency, created, uuid
- UDA section: all non-standard fields rendered as editable inputs
- "save changes" sends task_modify with only changed fields
- New server actions: task_modify (modify any field including UDAs), task_get (export single task)

### 17. Journal Entry Actions
- Each journal entry shows annotate and journal buttons on hover
- "+ annotate" adds a follow-up entry referencing the original by date
- "→ journal" adds a new freeform entry

### 18. Ledger Transaction Actions
- Each recent transaction shows annotate and journal buttons on hover
- "+ annotate" adds a ledger comment entry
- "→ journal" writes a journal note referencing the transaction

### 19. Time Interval Actions
- Each interval shows annotate and journal buttons on hover
- Click the tags text to start tracking (moved from whole-row click)
- "+ annotate" writes a journal entry tagged with [time:tags] and duration
- "→ journal" writes a freeform journal note

### 20. CMD Service — Unified Command Interface
- New sidebar tab "CMD" below Schedule
- Single input for any ww subcommand, routed through POST /cmd
- Output display with error highlighting
- All commands logged to services/cmd/cmd.log in JSONL format
- Log entries: command, output (500 char), ok, timestamp, profile
- GET /data/cmd-log returns most recent 100 entries
- Scrollable history list with click-to-expand results
- New service directory: services/cmd/ with README.md
- cmd_log action added to POST /action handler

### 21. Major UI Overhaul (TASK-SITE-007)

Sidebar restructure:
- CMD and CTRL as square buttons below profile pill
- Weapons row: ⚔ sword, 🔫 gun, 🏏 bat, 🔥 fire, 🏹 slingshot
- Function tabs with colored unicode icon badges: ˜ tasks (green), │ times (blue), ╱ journals (orange), ═ ledgers (white)
- Service tabs: Sync, Groups, Models, Network, Export, Questions, BookBuilder
- Warrior stats pinned at sidebar bottom (red ✱)
- Collapsed sidebar shows icon-only thin bar (42px), weapons hidden
- Profile info button (P) next to profile pill, also accessible when collapsed

New panels:
- CTRL: deps check, shortcuts, version buttons
- Sync: github-sync status dashboard
- Groups: group cards from config/groups.yaml (GET /data/groups endpoint)
- Models: model list from ww model list
- Network: connectivity checks for internet, github, ollama (GET /data/network endpoint)
- Export: JSON export + ww export button
- Questions: template list from q list
- BookBuilder: status and run info
- Profile: profile info screen

Color system:
- CSS variables: --clr-tasks (green), --clr-time (blue), --clr-journal (orange), --clr-ledger (white), --clr-warrior (red)
- Nav icons use colored rectangular badges
- Terminal bar shows profile name badge and pinned command icon with function color

Server changes:
- GET /data/groups — reads config/groups.yaml
- GET /data/network — checks internet, github, ollama connectivity
- ALLOWED_SUBCOMMANDS: added sync, q, questions

---

## Continued: Option 1 Time Model, Reverts, Service Wiring

### 22. Divergences Documented
- Created system/audits/divergences.md logging all behavioral differences from upstream tools
- Confirmed: zero source code modifications to TaskWarrior or TimeWarrior
- Documented: timew tag merge (reverted), description-via-journal convention, UDA display grouping

### 23. Concurrent Tracking Reverted
- Restored standard timew_start (replaces active interval, no merge)
- Restored standard timew_stop (stops all tracking, no per-tag removal)
- Per-tag stop buttons and jump-to-task buttons removed from interval rows
- Interval rows retain: click-to-start, annotate (※), journal note (╱)

### 24. Time Form Redesigned (Option 1)
- Tags field: structured @tags for timew categorization
- New description field: free text logged to journal with [time:tags] prefix
- timew receives only the tags; description goes to journal separately
- Track button: records past interval (duration + tags), description to journal

### 25. Groups Panel Wired
- Create form: name + profiles (comma-separated)
- Group cards with show and delete buttons
- Creates via ww group create, deletes via ww group delete
- Refreshes after each operation

### 26. Models Panel Wired
- Buttons: list, providers, env, check
- Each runs the corresponding ww model subcommand
- Output displayed in panel

### 27. Questions Panel Wired
- Buttons: list templates, new journal template, new task template
- Each runs the corresponding ww q subcommand
- Output displayed in panel

### 28. BookBuilder/Saves Panel Expanded
- Add URL form: saves URL to journal as [saved] entry
- Status button: searches for bookbuilder content
- Search button: prompts for term, searches via ww find
- Inbox button: shows bookbuilder inbox instructions
- Run button: shows pipeline stage instructions
- Attribution: bookbuilder

---

## Continued: Fixes, Projects, Hledger, Command Line

### 29. Hledger PATH Fix
- Added /usr/local/bin, /opt/homebrew/bin, ~/.local/bin to PATH in hledger handler
- Fixes "hledger not found" when server started from restricted PATH context

### 30. Hledger Full Integration
- POST /hledger endpoint with whitelisted commands
- Toolbar: balance sheet, income statement, cashflow, register, stats, activity, check, ROI, accounts, print
- Period selector: all time, monthly, weekly, daily, quarterly, yearly
- Account filter and depth controls
- Output in monospace pre-formatted area

### 31. Task Buttons Fixed
- Start/stop/done buttons now show word labels ("start", "stop", "done") with icons
- Responsive: words hide on screens < 768px, icons remain
- Buttons always visible (not hover-only)

### 32. Questions Form-Based Template Creator
- Replaced interactive CLI calls with browser form
- Service selector, name, description fields
- Dynamic question builder (add fields, save)
- q_create_template server action writes JSON template to profile
- Fixed profile resolution to read active_profile state file

### 33. Times Click-to-Start
- Clicking anywhere on an interval row starts tracking those tags
- Action buttons (annotate, journal) excluded from row click via closest() check

### 34. Projects Service
- New sidebar tab with ◆ icon
- config/projects.yaml for project definitions
- GET /data/projects endpoint
- project_create action for creating projects
- Project cards show name, description, and usage hints
- services/projects/README.md documenting the data model

### 35. Process Decision Logged
- Documented orchestrator bypass justification in system/logs/decisions.md
- Documented simultaneous tracking design decision
- Documented projects service design decision

### 36. Command Line Documentation
- Terminal bar: type command + Enter to execute via ww CLI
- ArrowUp/Down: navigate command history
- Tab: toggle execute/filter mode
- Escape: dismiss output or clear input
- Pinned command: visual label of last command, not a mode
- No prefix system — the pinned label is informational only

---

## Continued: Sword, Sync/Schedule panels, UDA autocomplete

### 37. Sword Weapon — Full Implementation (TASK-EXT-SWORD-002)
- cmd_sword() in bin/ww: splits task into N sequential subtasks
- Each subtask: "Part N of: <original>", project inherited, tags inherited
- Due dates offset by --interval (default 1d)
- Dependencies: subtask N depends on subtask N-1
- Browser UI: sword section with form (task ID, parts, interval, prefix)
- Tested: ww sword 3 -p 3 --interval 2d creates 3 subtasks correctly

### 38. Sync Panel Wired
- Buttons: status, pull, push, install
- Routes through ww issues subcommands
- Output displayed in panel

### 39. Schedule Panel Wired
- Buttons: status, enable, disable, run, dry-run, install
- Routes through ww schedule subcommands
- Output displayed in panel

### 40. Task Cards Updated
- TASK-EXT-SWORD-002: complete
- TASK-SITE-008, 009, 010: complete (from previous round)
- TASKS.md updated with new entries

---

## Continued: Project Organization and Spec Work

### 41. Task Card Index Created
- system/tasks/INDEX.md — scannable registry of all 72 cards
- Priority queue: NEXT, HIGH, MEDIUM, LOW, PARKED
- Organized by status: in-progress, pending, complete, parked, deferred
- Subfolders created: complete/, pending/, drafted/, parked/, removed/
- TASKS.md remains the dispatch board; INDEX.md is the lookup table

### 42. Weapons Folder Created
- /weapons/README.md — architecture, design principles, registry
- /weapons/gun/README.md — taskgun extension documentation
- /weapons/sword/README.md — native weapon documentation
- Gun modeled as extension (external binary passthrough)
- Sword modeled as native (cmd_sword in bin/ww)
- LLM integration spec: --ai flag, same provider resolution as CMD AI

### 43. TimeWarrior Extensions Registry
- docs/taskwarrior-extensions/timewarrior-extensions.md
- 59 repos scanned from GitHub topics
- Tier 1: sync, pomodoro, billable, aggregate
- User selected: sync + billable for integration

### 44. Servers Service Created
- services/servers/README.md — TaskChampion sync, timew sync, server management
- Tied to TASK-TC-001 (parked)

### 45. AI Access Control
- config/ai.yaml — mode (off/local-only/local+remote), per-feature toggles
- Managed via CTRL panel

### 46. Cards Archived
- TASK-WEB-001 moved to removed/ (superseded by browser service)
- TASK-EXT-SWORD-001 superseded by SWORD-002 (complete)
- TASK-EXT-GUN-001-EXPLORE done informally (gun-limitations.md)
- TASK-SITE-001 design is the implementation

### 47. User Decisions Captured
- TIMEW-001: sync + billable extensions (not all four)
- CRON-001: TW built-in recurrence + extend to journals/ledgers (LOW priority)
- CAL-001: parked (not a priority)
- Recurring: CTRL panel UI for managing TW recurrence + journal/ledger schedules

---

## Continued: AI Integration (TASK-AI-001) via Orchestrator

### 48. Root Cause Analysis
- "subcommand 'create' is not allowed" — LLM generated `create task` instead of `task add`
- Small models (gemma3:1b, llama3.2:3b) don't follow complex instruction protocols
- The ACTION prefix format was too complex for small LLMs

### 49. System Prompt Simplified
- Replaced complex ACTION protocol with simple few-shot examples
- Each example shows: user request → exact command
- No special prefixes or protocols — just plain commands

### 50. Heuristic Command Parser
- Detects intent from first token: task, timew, journal, ledger, profile, etc.
- Handles any format: "task add X", "task X", "create task X", "X" (→ task add)
- Falls back to task add for unrecognized commands (most common intent)
- Strips leading "ww" or "ACTION" if present

### 51. AI Access Controls
- CTRL panel: AI mode selector (off / local-only / local+remote)
- Stored in localStorage, checked before CMD AI calls
- Ollama status shown in CTRL panel (checks /data/network)
- config/ai.yaml created for server-side config (future use)

### 52. Orchestrator Process Used
- Task card TASK-AI-001 created with full 8 fields
- Explorer investigation identified root cause
- Builder implemented fix with verification
- Card marked complete with completion notes

---

## Continued: Ollama Integration (TASK-AI-002)

### 53. Ollama Sensing at Shell Init
- ww-init.sh: background curl probe to localhost:11434/api/tags (1s timeout)
- Sets WW_OLLAMA_AVAILABLE=1 if reachable
- Non-blocking: runs in background subshell

### 54. AI Convenience Commands
- ww ctrl ai-on: sets mode=local-only, cmd_ai=true, probes ollama
- ww ctrl ai-off: sets mode=off, cmd_ai=false
- ww ctrl ai-status: shows mode, cmd_ai, preferred provider, profile override, ollama probe

### 55. Per-Profile AI Config
- profiles/<name>/ai.yaml overrides global config/ai.yaml
- Server reads profile-level after global, overriding mode and preferred_provider
- ww ctrl ai-status shows profile override if present

### 56. Codex Handover Integration
- Codex delivered: models.sh, ctrl.sh, models tests, deprecation cleanup
- This session extended: ai-on/off/status, ollama probe, per-profile override
- All changes additive to Codex's work

---

## Continued: Route Indicator and Heuristic Evolution Plan

### 57. Route Indicator in UI
- Server response includes `route: "ai"` or `route: "heuristic"`
- UI shows ⚡ for AI route, ⚙ for heuristic route
- CMD log records route field for historical analysis
- Both primary and fallback paths show the route

### 58. Heuristic Evolution Plan
- system/plans/heuristic-evolution.md — 5-phase roadmap
- Phase 1 (done): logging with route field
- Phase 2 (next): pattern extraction from CMD log
- Phase 3: enhanced heuristic engine reads config/cmd-heuristics.yaml
- Phase 4: user-editable rules via CTRL panel
- Phase 5: continuous learning with automatic digest

### 59. Initial Heuristic Rules
- config/cmd-heuristics.yaml with 12 builtin patterns
- Covers: task creation, time tracking, journal entries, profiles, passthrough
- Confidence threshold: 0.8 for auto-execution
- Rules have provenance tracking (builtin/ai-digest/manual)

### 60. Models Registered
- llama3 (ollama/llama3.2:latest) set as default
- gemma3 (ollama/gemma3:1b) registered
- "detect ollama models" button added to Models panel

---

## Heuristic Compilation — First Run

### 61. Compiler Built and Executed
- scripts/compile-heuristics.py: 600+ lines, Python 3 stdlib only
- Source Scanner: extracted 259 commands from command-syntax.yaml and bin/ww
- Pattern Generator: produced 902 rules (6 variations per command)
- Synthetic Corpus: 120 entries across all domains and 5 phrasing styles
- Validator: 902/902 passed, 0 failed
- Merger: 554 rules after deduplication with existing 10 rules
- Output: config/cmd-heuristics.yaml (2780 lines), config/cmd-heuristics-corpus.yaml (485 lines)
- CLI: ww compile-heuristics [--verbose] [--digest]

### 62. Domain Coverage
- profile: 76 rules, group: 47, model: 64, ctrl: 35
- task: 22 (+ domain-specific patterns), time: 3 (+ specific), journal: 34
- schedule: 43, gun: 20, next: 14, mcp: 24, tui: 14
- shortcut: 392 (one per shortcut entry × 6 variations)
- Total: 554 merged rules covering 19 domains
