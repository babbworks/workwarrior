# Dev Guide for Popup — Verified Command Map

**Created:** 2026-07-14
**Source:** Exhaustive audit of WORKWARRIOR-STANDARD.md, browser server.py POST/GET handlers,
and live non-interactive testing on this system.
**Purpose:** Every command in this document is PROVEN to work. The popup should use exactly
these invocations — no guessing, no inference.

---

## 1. Environment Setup

Every command below requires these env vars set for the active profile:

```bash
PROFILE_NAME="$(cat ~/.config/ww/last-profile)"
BASE="${PROFILES_DIR}/${PROFILE_NAME}"
TASKRC="${BASE}/.taskrc"
TASKDATA="${BASE}/.task"
TIMEWARRIORDB="${BASE}/.timewarrior"
JRNL_CFG="${BASE}/jrnl.yaml"
```

Ledger file resolution:
```bash
LEDGER_FILE=$(grep "default:" "${BASE}/ledgers.yaml" | sed 's/.*default:\s*//' | tr -d ' ')
[[ "$LEDGER_FILE" != /* ]] && LEDGER_FILE="${BASE}/ledgers/${LEDGER_FILE}"
```

---

## 2. Tasks — PROVEN Commands

### Read: Get all pending tasks (full JSON with all fields)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no status:pending export
```
Returns JSON array. Each task object contains:
- `id` (short numeric), `uuid`, `description`, `status`
- `project`, `priority` (H/M/L), `tags` (array), `due` (ISO8601)
- `urgency` (float), `entry`, `modified`
- `annotations` (array of `{entry: timestamp, description: text}`)
- ALL UDAs defined in the profile (as key:value pairs)

### Read: Get a single task by ID
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> export
```
Returns JSON array with one element.

### Read: Get active (started) tasks
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no status:active export
```

### Read: Get completed tasks (recent)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no status:completed "end.after:today-7d" export
```

### Read: Count ready/overdue
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task +READY count
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task +OVERDUE count
```

### Read: Unique projects (for picker)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task _unique project
```
Returns one per line. Filter empty lines.

### Read: Unique tags (for picker)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task _unique tags
```
Returns comma-separated list. Split on commas.

### Read: UDA names available in this profile
```bash
grep "^uda\." "$TASKRC" | sed 's/^uda\.\([^.]*\)\..*/\1/' | sort -u
```
Returns one UDA name per line. To get type:
```bash
grep "^uda\.<name>\.type=" "$TASKRC" | cut -d= -f2
```
Types: `string`, `numeric`, `date`, `duration`

### Write: Add task (with all metadata)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no add "<description>" \
  project:<project> priority:<H|M|L> due:<date> scheduled:<date> wait:<date> \
  +tag1 +tag2 <uda_name>:<value>
```
All fields after description are optional. Date formats accepted:
`tomorrow`, `friday`, `eom`, `eow`, `2026-07-20`, `+3d`, `1w`

**Verified:** Returns `Created task N.` on success. Parse N for the new ID.

### Write: Modify task (any attribute)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> modify \
  project:<new> priority:<H|M|L> due:<date> +newtag -oldtag \
  description:"<new desc>" <uda_name>:<value>
```
To CLEAR a field: `field:` (empty value after colon)
To ADD a tag: `+tagname`
To REMOVE a tag: `-tagname`

**Verified:** Returns `Modified 1 task.`

### Write: Complete task
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> done
```

### Write: Delete task
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> delete
```

### Write: Start task (mark active)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> start
```

### Write: Stop task (unmark active)
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> stop
```

### Write: Add annotation
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> annotate "<text>"
```

### Write: Remove annotation
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> denotate "<exact text>"
```

### Write: Add dependency
```bash
TASKRC="$TASKRC" TASKDATA="$TASKDATA" task rc.confirmation=no <id> modify depends:<other_uuid>
```

---

## 3. Time (TimeWarrior) — PROVEN Commands

### Read: Current tracking state
```bash
timew
```
First line is either `Tracking "<tags>"` or `There is no active time tracking.`
Parse: if starts with "Tracking" → extract tags and duration.

### Read: Today's summary
```bash
timew summary :day
```
Text table output. Use as-is for display.

### Read: This week's summary
```bash
timew summary :week
```

### Read: Export intervals as JSON
```bash
timew export :day
```
Returns JSON array of `{start, end, tags:[]}`. Useful for programmatic access.

### Write: Start tracking
```bash
timew start <tag1> <tag2> ...
```
Tags are space-separated (NOT quoted as one string). Each word becomes a tag.
**Gotcha:** If you pass `"my activity"` (quoted), it becomes the tag `"my activity"` with quotes.
For multi-word activities, pass without quotes: `timew start my activity`

### Write: Stop tracking
```bash
timew stop
```

### Write: Track past interval
```bash
timew track <duration> <tag1> <tag2>
```
Duration: `30min`, `1h`, `2h30min`

---

## 4. Journal (jrnl) — PROVEN Commands

### Read: Recent entries (short form)
```bash
jrnl --config-file "$JRNL_CFG" --short -n 10
```
**CRITICAL:** Output contains ANSI escape codes that MUST be stripped:
```bash
jrnl --config-file "$JRNL_CFG" --short -n 10 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
```
Output format after stripping: `YYYY-MM-DD HH:MM Title text`

### Read: Entries containing text
```bash
jrnl --config-file "$JRNL_CFG" --short -contains "<query>" | sed 's/\x1b\[[0-9;]*m//g'
```

### Read: Full entry for a date
```bash
jrnl --config-file "$JRNL_CFG" -on <YYYY-MM-DD> | sed 's/\x1b\[[0-9;]*m//g'
```

### Read: List journal names (from jrnl.yaml)
```bash
awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); gsub(/:.*$/,""); print}' "$JRNL_CFG"
```
Returns one name per line. The first one listed is the default.

### Write: New entry (default journal)
```bash
jrnl --config-file "$JRNL_CFG" "Title. Body text here"
```
The first sentence (ending with `.`) becomes the title. Everything after is body.
**Verified:** Exit code 0 on success, no stdout.

### Write: New entry (named journal)
```bash
jrnl <journal_name> --config-file "$JRNL_CFG" "Title. Body text"
```
Journal name goes BEFORE `--config-file`. This is a jrnl quirk.

### ALTERNATIVE: Browser-style direct file write
The browser does NOT use jrnl CLI for adding. It appends directly:
```bash
printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$entry_text" >> "$journal_file"
```
Where `$journal_file` is resolved from jrnl.yaml mapping.
This avoids jrnl's interactive behaviors entirely. Both approaches produce valid entries.

---

## 5. Ledger (hledger) — PROVEN Commands

### Read: Account balances
```bash
hledger -f "$LEDGER_FILE" balance --flat --no-total
```
Output: `  <amount>  <account>` per line, whitespace-padded.

### Read: Balance sheet
```bash
hledger -f "$LEDGER_FILE" balancesheet
```

### Read: Income statement
```bash
hledger -f "$LEDGER_FILE" incomestatement
```

### Read: Recent transactions (register)
```bash
hledger -f "$LEDGER_FILE" register -n 10
```
Shows last 10 postings.

### Read: Monthly expenses
```bash
hledger -f "$LEDGER_FILE" balance expenses -p 'this month'
```

### Read: Search transactions by description
```bash
hledger -f "$LEDGER_FILE" register "desc:<query>"
```

### Read: List all accounts
```bash
hledger -f "$LEDGER_FILE" accounts
```
Returns one account per line. Useful for pickers.

### Write: Add transaction (valid double-entry)
```bash
printf '\n%s %s\n    %s  %s\n    %s\n' \
  "$date" "$description" "$expense_account" "$amount" "$source_account" \
  >> "$LEDGER_FILE"
```
Example output:
```
2026-07-14 Coffee at Blue Bottle
    expenses:coffee  $5.50
    assets:checking
```
**The second posting has NO amount** — hledger auto-balances it. This IS valid double-entry.
The browser uses exactly this format.

### Write: Add annotation (standalone comment)
```bash
printf '; [%s] %s: %s\n' "$date" "$description" "$note" >> "$LEDGER_FILE"
```

### Write: Add tags to a transaction (comment line after description)
Insert `    ; project:<p>  tag:<t>  priority:<H>` as the line AFTER the date line.
The browser does this by reading the file, finding the transaction, inserting the comment line.

---

## 6. Lists (tools/list/list.py) — PROVEN Commands

All invocations:
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" [args]
```

### Read: Show items
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name"
```
Output: `<prefix> - <text>` per line. Prefix is the short hash ID.

### Read: Show items with notes visible
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -n
```

### Read: Filter by grep
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -g "<query>"
```

### Read: JSON export
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --json
```

### Read: Show all lists
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --show-lists --profile-name "$PROFILE_NAME"
```

### Write: Add item
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -q "<text>"
```
`-q` suppresses the prefix echo.

### Write: Finish item
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -f "<prefix>"
```

### Write: Edit item
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -e "<prefix>" "<new text>"
```

### Write: Remove item
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -r "<prefix>"
```

### Write: New list
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$PROFILE_NAME" new "<name>"
```

### Write: Switch default list
```bash
python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$PROFILE_NAME" switch "<name>"
```

### Item format anatomy
```
<text> | id:<sha1>
```
Text may contain: `[YYYY-MM-DD HH:MM] body #tag1 #tag2 // note text`

---

## 7. Stream — Available Commands

```bash
ww stream status          # Shows schema version, event count
ww stream emit <args>     # Write event (programmatic)
ww stream view --lens <name>   # Project through a lens
```

Stream log location: `$WW_BASE/stream/stream.log`
Format: `<unix_ts> <OP> <action> <object> <ctx_json>` (5 space-separated fields)

Lenses: bundy, frick, dey, cooper, hollerith, pacioli, burroughs, felt

---

## 8. Community — PROVEN Commands

```bash
ww community list                    # List collections (may be empty)
ww community create <name>           # Create collection
ww community show <name>             # Show items
ww community add <name> "<content>"  # Add item
```

Browser supports 12 community actions:
`community_add`, `community_create`, `community_archive`, `community_unarchive`,
`community_describe`, `community_rename`, `community_modify_entry`,
`community_refresh_entry`, `community_move_entry`, `community_remove_entry`,
`community_comment_save`, `community_comment_copy_back`

---

## 9. GitHub Sync — Available Commands

```bash
ww issues status                     # Show sync state
ww issues sync                       # Bidirectional sync
ww issues push                       # Push to GitHub only
ww issues pull                       # Pull from GitHub only
ww issues enable <task_id> <issue_num> <org/repo>   # Link
ww issues disable <task_id>          # Unlink
```

---

## 10. Profile — Commands

```bash
# List profiles (just names)
find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort

# Switch (write to state file)
echo "<name>" > "${STATE_DIR}/last-profile"

# Profile info
ww profile info <name>

# Profile create (non-interactive)
ww profile create <name> --non-interactive
```

---

## 11. System/Admin — Commands

```bash
ww group list                        # Profile groups
ww model list                        # LLM models
ww deps check                        # Dependency status
ww service list                      # Available services
ww shortcut list                     # Shortcuts
ww extensions taskwarrior list       # TW extensions
```

---

## 12. Gotchas & Requirements

| Tool | Gotcha | Solution |
|------|--------|----------|
| TaskWarrior | Prompts for confirmation on modify/delete/done | Always use `rc.confirmation=no` |
| TaskWarrior | Needs TASKRC+TASKDATA as ENV vars, not args | Inline: `TASKRC=x TASKDATA=y task ...` |
| TaskWarrior | `task export` returns ALL fields including UDAs | Parse with `python3 -c "import json..."` |
| jrnl | ALWAYS outputs ANSI color codes | Strip: `\| sed 's/\x1b\[[0-9;]*m//g'` |
| jrnl | Named journal: name goes BEFORE --config-file | `jrnl <name> --config-file <cfg> "text"` |
| jrnl | `--format text` still outputs ANSI | Use sed stripping regardless |
| hledger | Second posting needs no amount (auto-balances) | Leave blank: `    assets:checking` |
| hledger | `-f <file>` is required (no env var) | Always pass `-f "$LEDGER_FILE"` |
| timew | Quoted multi-word → becomes one tag with quotes | Don't quote: `timew start my activity` |
| timew | TIMEWARRIORDB env var IS respected | Set it for profile isolation |
| list.py | `-q` flag suppresses prefix output on add | Use for non-interactive add |
| list.py | Prefix is first token before ` - ` | Parse: `echo "$line" \| awk '{print $1}'` |
| Rofi | Esc returns non-zero exit | Handle with `\|\| return` |
| Rofi | User can type custom text | Check if selection matches a menu item |
| All | Non-TTY context | Never use `read -p`; use popup_input |

---

## 13. Data Paths for Active Profile

```
$BASE/
  .taskrc               → TASKRC (read by task)
  .task/                → TASKDATA (read by task)
  .timewarrior/         → TIMEWARRIORDB (read by timew)
  jrnl.yaml             → journal name:file mapping
  ledgers.yaml          → ledger name:file mapping
  journals/             → journal text files
  ledgers/              → hledger journal files
  list/                 → list.py data files (one per list)
  lists.yaml            → list configuration (default: name)
```

---

## 14. What the Browser Does That the Popup Should Replicate

| Feature | Browser implementation | Popup equivalent |
|---------|----------------------|------------------|
| Task add with metadata | `task add <desc> project:X priority:H due:D +tag uda:val` | Same — all inline |
| Task modify any field | `task <id> modify key:value +tag -tag` | Same |
| Task annotations view | `task <id> export` → parse `annotations` array | Same (python3 json parse) |
| Annotation delete | `task <id> denotate "<exact text>"` | Same |
| Tags add/remove | `+tag` / `-tag` in modify | Same |
| UDA editing | `task <id> modify <uda_name>:<value>` | Same — read UDA list from .taskrc |
| Timew with profile isolation | `TIMEWARRIORDB=<path> timew start <tags>` | Same |
| Journal: direct file write | `printf '\n[timestamp] text\n' >> file` | Preferred (avoids jrnl ANSI) |
| Ledger: double-entry | `printf '\ndate desc\n    acct  amt\n    source\n' >> file` | Same format |
| Ledger: accounts list | `hledger -f file accounts` | For picker |
| Community | `ww community <action>` | Same |
| Profile switch | Write to state file | Same |

---

## 15. Summary: What Was Wrong in Popup v1

| Bug | Root cause | Correct approach |
|-----|-----------|-----------------|
| `task annotations` command | Non-existent subcommand | Use `task <id> export` + parse JSON |
| Lists used .md format | Guessed format | Use `list.py` — it's the owner |
| Board parsed `\|` delimiter | Wrong format | Stream is space-separated: `split(None, 4)` |
| jrnl entries unreadable | ANSI codes not stripped | Always `sed 's/\x1b\[[0-9;]*m//g'` |
| Ledger "single entry" | Missing auto-balance line | Leave second amount blank — hledger does it |
| Popup closed after action | Missing loop-back calls | Always call `screen_*` after action |
| Home didn't return after screens | No `screen_home` after screen_* | Add `; screen_home` to all routes |
| Task ID extraction failed | Used `grep -oP '^\d+'` on padded output | Output already stripped — but verify |
| `_journal_current` wrong | Looked for non-existent `default:` key | Read first key under `journals:` |
