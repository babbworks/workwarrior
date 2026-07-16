# WW Floor Popup v2 — Design Spec

**Status:** draft — awaiting operator review before build
**Location:** `scripts/ww-floor-popup.sh` + `scripts/ww-popup-screens/`

---

## 1. Concept

A full-function rofi popup that exposes all workwarrior capability via paginated menus
with concurrent typing support. Designed for non-developers (factory floor, office) but
equally fast for power users via prefix shortcuts.

**Navigation model:**
- Home opens on Page 1
- Arrow right/left moves between pages
- Each page has selectable menu items
- Selecting an item opens a screen
- Typing from any page routes via prefix or bare-add
- Esc exits from any depth

---

## 2. Page structure

### Page 1 — Daily actions (default landing)

Context bar: `<profile> / <list> · ▶ <timer> (<dur>) · N tasks`

| Item | Action |
|---|---|
| 🕐 Clock In / Out | → clock screen |
| 📋 My Tasks | → tasks screen |
| 📝 My Lists | → lists screen |
| 🔍 Search | → search screen |
| → Page 2 | indicator: arrow right to continue |

### Page 2 — Data & browse

Context bar: same

| Item | Action |
|---|---|
| 📓 Journal | → journal screen |
| 💰 Ledger | → ledger screen |
| 👥 Board (Who's In) | → board screen |
| 📊 Reports | → reports screen |
| 🤝 Community | → community screen |
| ← Page 1 · Page 3 → | navigation indicators |

### Page 3 — System & config

Context bar: same

| Item | Action |
|---|---|
| 🔄 Switch Profile | → profile screen |
| 🔗 GitHub Sync | → sync screen |
| ⚙️  Groups / Models | → system screen |
| 📡 Dependencies | → deps check/install |
| ← Page 2 | navigation indicator |

---

## 3. Input routing (active on all pages)

Typing takes priority over menu navigation. Input is parsed on Enter:

| Input | Route |
|---|---|
| `.text` | task add `text` |
| `>text` | timew start `text` |
| `>>` | timew stop |
| `@text` | jrnl entry `text` |
| `$amount account` | ledger transaction |
| `?query` | cross-tool search |
| `!name` | switch profile (bare `!` = picker) |
| `#tag` | filter current list by tag |
| `/command` | pass through as `ww command` (full CLI access) |
| bare text | add to current list |

The `/` prefix gives full CLI access without leaving the popup — any `ww` subcommand
can be typed (e.g., `/profile list`, `/journal add work "meeting notes"`).

---

## 4. Screens — capability map

Each screen maps to what the tools ACTUALLY support in non-interactive mode.

### 🕐 Clock screen

**Reads:** `timew` (current tracking state, summary)
**Writes:** `timew start <tags>`, `timew stop`

| View | Source |
|---|---|
| Current activity + duration | `timew` first line: "Tracking X" |
| Today's intervals | `timew summary :day` |
| Recent activities (ours) | `~/.config/ww/popup-recents` |

| Action | Command |
|---|---|
| Clock Out | `timew stop` |
| Clock In (new) | `timew start <activity>` |
| Switch activity | `timew stop && timew start <new>` |
| Select recent | `timew start <recent>` |

### 📋 Tasks screen

**Reads:** `task` (with TASKRC/TASKDATA set)
**Writes:** `task add`, `task <id> done`, `task <id> modify`, `task <id> annotate`

| View | Source |
|---|---|
| Pending tasks sorted by urgency | `task rc.verbose=nothing limit:20 next` (columns: id, description) |
| Ready/overdue counts | `task +READY count` / `task +OVERDUE count` |
| Filter by project | `task _unique project` → `task project:<p> next` |

| Action | Command |
|---|---|
| Add task | `task add "<description>"` |
| Complete | `task rc.confirmation=no <id> done` |
| Start timer | `timew start "<task description>"` |
| Annotate | `task rc.confirmation=no <id> annotate "<note>"` |
| Set due date | `task rc.confirmation=no <id> modify due:<date>` |
| Defer | `task rc.confirmation=no <id> modify wait:+1d` |

**Critical note:** Always use `rc.confirmation=no` for mutations. Always set
TASKRC/TASKDATA inline (never export). Task IDs from `next` report are the short
numeric IDs shown in column 1.

### 📝 Lists screen

**Reads:** `tools/list/list.py` with `-t <dir> -l <name>`
**Writes:** same tool for add/finish/edit/remove

| View | Source |
|---|---|
| All lists with item counts | scan `<profile>/list/` for non-hidden files |
| Items in a list | `list.py -t <dir> -l <name>` (output: `prefix - text`) |
| Notes | Parse ` // ` in item text |
| Tags | Parse `#word` in item text |

| Action | Command |
|---|---|
| Add item | `list.py -t <dir> -l <name> -q "text"` |
| Finish | `list.py -t <dir> -l <name> -f <prefix>` |
| Edit | `list.py -t <dir> -l <name> -e <prefix> "new text"` |
| Add note | Edit with `"original text // note"` appended |
| Remove | `list.py -t <dir> -l <name> -r <prefix>` |
| New list | `list.py -t <dir> -l <name> --profile-name <p> new <newname>` |
| Switch list | `list.py -t <dir> -l <name> --profile-name <p> switch <target>` |
| Filter by tag | `list.py -t <dir> -l <name> -g "#tag"` |

**Item output format:** `<prefix> - <text>` where prefix is the short hash ID.
Parse prefix as first token before ` - `.

### 📓 Journal screen

**Reads:** `jrnl --config-file <cfg>` with various flags
**Writes:** `jrnl --config-file <cfg> "entry text"`

| View | Source |
|---|---|
| Recent entries | `jrnl --config-file <cfg> --short -n 10` |
| Journal names | Parse `journals:` keys from `<profile>/jrnl.yaml` |
| Full entry | `jrnl --config-file <cfg> -on <date> --format text` |
| Search results | `jrnl --config-file <cfg> --short -contains "<query>"` |

| Action | Command |
|---|---|
| New entry | `jrnl --config-file <cfg> "Title. Body text"` |
| New entry to named journal | `jrnl <name> --config-file <cfg> "text"` |
| Search | `jrnl --config-file <cfg> --short -contains "<q>"` |

**Critical note:** jrnl entry format is `Title. Body text here` — the first sentence
(ending with `.`) becomes the title. Multi-journal: the journal name goes BEFORE
`--config-file` in the argument list.

### 💰 Ledger screen

**Reads:** `hledger -f <file>` with various subcommands
**Writes:** Append text to the journal file directly (hledger doesn't have an `add`
that works non-interactively without stdin prompts)

| View | Source |
|---|---|
| Account balances | `hledger -f <file> balance --flat --no-total` |
| Recent transactions | `hledger -f <file> register -n 10` |
| Monthly spending | `hledger -f <file> balance expenses -p 'this month'` |

| Action | Command |
|---|---|
| Log transaction | Append formatted entry to file: `\n<date> <desc>\n    <account>  <amount>\n    <source>\n` |

**Ledger file location:** Parse `default:` from `<profile>/ledgers.yaml`. If relative
path, prefix with `<profile>/ledgers/`. File must exist.

### 👥 Board screen (display-only for now)

**Reads:** Stream log at `$WW_BASE/stream/stream.log` OR `timew summary :day`

| View | Source |
|---|---|
| Active punches (if stream.log exists) | Parse B start/stop events |
| Today's time activity (fallback) | `timew summary :day` |

No write actions from the board — it's an awareness view.

### 📊 Reports screen (display-only)

| Report | Command |
|---|---|
| Time today | `timew summary :day` |
| Time this week | `timew summary :week` |
| Tasks completed this week | `task status:completed end.after:today-7d` |
| Spending this month | `hledger -f <file> balance expenses -p 'this month'` |

### 🔍 Search screen

**Reads:** Multiple tools in sequence

| Source | Command |
|---|---|
| Tasks | `task rc.verbose=nothing status:pending description.contains:<q> limit:5 next` |
| Lists | `list.py -t <dir> -l <name> -q -g "<query>"` per list |
| Journal | `jrnl --config-file <cfg> --short -contains "<q>"` |
| Ledger | `hledger -f <file> register desc:<q>` |

Results prefixed with source emoji. Display-only (select shows detail).

### 🔄 Profile screen

**Reads:** Scan `$PROFILES_DIR/` for directories
**Writes:** `~/.config/ww/last-profile` (state file)

Shows all profiles with active marker. On select: writes to state file + notifies.
Does NOT activate in terminal (that requires `p-<name>` in a shell session).

### 🔗 Sync screen

**Reads:** `ww issues status` or equivalent
**Writes:** `ww issues sync`, `ww issues push`, `ww issues pull`

| View | Source |
|---|---|
| Sync status | `ww issues status` (parsed output) |
| Linked tasks | Tasks with github UDAs set |

| Action | Command |
|---|---|
| Sync (bidirectional) | `ww issues sync` |
| Push only | `ww issues push` |
| Pull only | `ww issues pull` |

### 🤝 Community screen

**Reads:** Community collections from `$WW_BASE/.community/community.db` (SQLite)
**Writes:** Via `ww community add`

| View | Source |
|---|---|
| Collection names | `ww community list` |
| Items in collection | `ww community show <name>` |

| Action | Command |
|---|---|
| Push item to collection | `ww community add <collection> "<content>"` |

### ⚙️ System screen

| Sub-item | Action |
|---|---|
| Groups | `ww group list` → select → show members |
| Models | `ww model list` → show providers |
| Dependencies | `ww deps check` → show status |
| Service info | `ww service list` → select → `ww service info <name>` |

---

## 5. Implementation notes

### Pagination via rofi
Rofi doesn't have native "pages." We simulate with:
- The last item on each page is a navigation indicator (`→ Page 2`, `← Page 1`)
- Selecting it redraws with the next page's items
- Arrow right/left keybinds (if rofi supports `-kb-custom-*`) for faster nav

Alternatively: use rofi tabs (`-modi`) if available in the installed version.

### State between invocations
- Profile: read from `~/.config/ww/last-profile`
- Current page: does NOT persist (always opens on page 1)
- Recent activities: `~/.config/ww/popup-recents` (one per line, max 10)

### Error handling
- If a tool isn't installed, show "(tool not available)" instead of crashing
- If no profile active, show page with only "Switch Profile" option
- All external commands wrapped in `|| true` or checked return codes

---

## 6. Out of scope (for now)

- Weapons (Gun, Sword, Next, Schedule) — complex multi-step, defer to terminal
- Export — defer to terminal (`ww export`)
- Heuristic natural language routing — needs regeneration (TASK-HEUR-001)
- AI chat — browser-only for now
- Overlay mode (telemetry background) — separate v3 design

---

## 7. Build plan

Phase 1: Shared helpers + pagination + home pages + input routing
Phase 2: Clock, Tasks, Lists screens (the daily trio)
Phase 3: Journal, Ledger, Board, Reports, Search
Phase 4: Profile, Sync, Community, System
