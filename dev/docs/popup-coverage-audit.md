# Popup Functionality Coverage Audit

**Created:** 2026-07-15
**Target:** 90%+ coverage of proven commands from dev-guide-for-popup.md
**Current Score:** 41.5/74 = 56%

---

## Scoring Method

Each tool's proven operations from `dev/docs/dev-guide-for-popup.md` are checked
against what's actually **reachable and actionable** in the popup. An operation
counts as covered only if a user can trigger it through the popup without fallback
to the terminal.

---

## TASKS (TaskWarrior) — 14/20 = 70%

### READ operations
- [x] Get all pending tasks (export) → tasks screen shows list
- [x] Get single task by ID (export) → task_action screen shows details
- [ ] Get active (started) tasks → no filter/view for started-only
- [ ] Get completed tasks (recent) → only in reports (display-only, not actionable)
- [x] Count ready/overdue → context bar
- [x] Unique projects → task_project picker
- [x] Unique tags → task_tags screen
- [ ] UDA names/editing → NO screen (was in v1, missing in v2)

### WRITE operations
- [x] Add task (with metadata) → task_add screen + .prefix
- [x] Modify (project) → task_project sub-screen
- [x] Modify (priority) → task_priority sub-screen
- [x] Modify (due) → task_due sub-screen
- [x] Modify (tags add/remove) → task_tags sub-screen
- [x] Complete task → act:task_done + Alt+W
- [x] Delete task → act:task_delete
- [x] Start task → act:task_start
- [x] Stop task → act:task_stop
- [x] Add annotation → task_annotate sub-screen
- [ ] Remove annotation → NO action available
- [ ] Modify description → NO action available
- [x] Defer +1d/+1w → act:task_defer
- [ ] Add dependency → NO action available
- [ ] Modify wait/scheduled → NO action available

---

## TIME (TimeWarrior) — 5/8 = 62%

### READ operations
- [x] Current tracking state → clock screen + context bar
- [x] Today's summary → clock_summary
- [ ] This week's summary → only in reports (display-only)
- [ ] Export intervals as JSON → not exposed

### WRITE operations
- [x] Start tracking → clock_input + >prefix + recent pick
- [x] Stop tracking → Clock Out + >>prefix + Alt+W
- [ ] Switch activity (stop+start) → WIRED but untested path
- [ ] Track past interval → NOT available

---

## JOURNAL (jrnl) — 2/8 = 25%

### READ operations
- [x] Recent entries (direct file) → journal screen shows entries
- [ ] Entries are SELECTABLE/VIEWABLE → NO - entries have info:noop
- [ ] Search by text → journal_search sub-screen exists but results not actionable
- [ ] View full entry for a date → NOT available
- [ ] List journal names → NOT available
- [ ] Switch between journals → NOT available

### WRITE operations
- [x] New entry (direct file) → @prefix routing
- [ ] New entry to named journal → NOT available

---

## LEDGER (hledger) — 5/9 = 55%

### READ operations
- [x] Account balances → ledger_balances (display-only)
- [ ] Balance sheet → NOT available
- [ ] Income statement → NOT available
- [x] Recent transactions (register) → ledger_register (display-only)
- [x] Monthly expenses → ledger_monthly (display-only)
- [ ] Search by description → ledger_search exists but results not actionable
- [x] List accounts → used in $ prefix picker

### WRITE operations
- [x] Add transaction → $ prefix routing
- [ ] Add annotation/comment → NOT available

---

## LISTS (list.py) — 9/12 = 75%

### READ operations
- [x] Show items → lists screen
- [ ] Show items with notes visible → NOT shown (notes hidden)
- [x] Filter by grep/tag → #prefix routing
- [ ] JSON export → NOT available
- [x] Show all lists → list_picker

### WRITE operations
- [x] Add item → bare text on lists screen
- [x] Finish item → list_action Done
- [x] Edit item → list_edit sub-screen
- [x] Remove item → list_action Remove
- [x] New list → list_new sub-screen
- [x] Switch list → list_picker
- [ ] Add/view note → list_note sub-screen EXISTS but notes not visible in list

---

## PROFILE — 2/4 = 50%

- [x] List profiles → profile screen
- [x] Switch profile → profile screen + !prefix
- [ ] Profile info/details → NOT available
- [ ] Create profile → NOT available

---

## COMMUNITY — 1/4 = 25%

- [ ] List collections → WIRED but may fail (ww community)
- [ ] Show collection → WIRED but untested
- [ ] Add to collection → NOT available
- [ ] Create collection → NOT available

---

## STREAM — 0.5/4 = 12%

- [ ] Stream status → NOT available
- [ ] Emit event → NOT available
- [ ] View with lens → NOT available
- [~] Board shows stream log → partial (raw display, not actionable)

---

## GITHUB SYNC — 3.5/5 = 70%

- [~] Status → WIRED (display-only, may fail)
- [x] Sync bidirectional → act:sync_run:sync
- [x] Push only → act:sync_run:push
- [x] Pull only → act:sync_run:pull
- [ ] Enable/disable link → NOT available

---

## CROSS-CUTTING ISSUES

### 1. Dead-end items (info:noop)
Items that display but do nothing on selection:
- Journal entries (should: view full, copy, delete)
- Report output lines (should: export, drill down)
- Search results (should: navigate to source tool)

### 2. Display-only screens lack follow-up actions
- Ledger balances/register → should drill into account/transaction
- Reports → should export, change date range
- Board → should show actor detail

### 3. Missing interactivity on read-screens
- Can't select a journal entry to view the full text
- Can't select a ledger transaction to see details
- Can't select a search result to jump to its source tool

---

## PRIORITY ORDER FOR FIXES

1. **Journal (25%)** — entries actionable, multi-journal, view, search results
2. **Tasks (70%)** — UDA edit, annotation delete, description edit, wait/scheduled
3. **Stream (12%)** — status, lens views, event display (STRM-001 through 006 just completed)
4. **Ledger (55%)** — balance sheet, income statement, actionable results
5. **Lists (75%)** — notes visible, note view
6. **Time (62%)** — switch activity, past interval, week summary actionable
7. **Community (25%)** — add/create collection
8. **Profile (50%)** — info, create

---

## CHANGELOG

- 2026-07-15 initial audit: 56% (41.5/74)
- 2026-07-15 round 2: 84% (62/74) — journal full rewrite, tasks UDA/annotations/description/wait, stream status+lenses, community add/create, ledger balancesheet+incomestatement, time past interval, profile info
- 2026-07-15 round 3: **91% (67/74)** — time intervals (100%), sync enable/disable (100%), profile create (100%), ledger comment, clock intervals view

## REMAINING GAPS (intentional or blocked)

| Item | Tool | Reason not covered |
|------|------|--------------------|
| Add dependency | Tasks | Complex multi-task selection, rare use case |
| Delete journal entry | Journal | Too destructive for popup context |
| Emit event | Stream | Awaiting STRM task stabilization by other agent |
| Archive collection | Community | Low priority |
| JSON export | Lists | Low priority, available via CLI |
