# Rofi Popup Optimization Reference

**Created:** 2026-07-14
**For:** ww-floor-popup.sh and ww-popup-screens/
**Target:** <200ms keypress-to-visible, <100ms screen transitions

---

## 1. Measured Baselines (this system, rofi 1.7.3)

| Component | Time | Notes |
|-----------|------|-------|
| Rofi startup (no-config, no-plugins, dmenu) | ~75ms | From timing trace |
| Rofi startup (with config + theme parsing) | ~120-200ms | Depends on theme complexity |
| Bash source shared.sh | 6ms | Negligible |
| Bash source all screen files | 7ms | Negligible |
| Context bar assembly | 34ms | Profile + timew + task count |
| task (single query) | 6ms | Extremely fast (C binary) |
| timew (status check) | 3ms | Extremely fast (C++ binary) |
| python3 (bare startup) | 30ms | Interpreter init overhead |
| hledger (bare startup) | 48ms | Haskell runtime init |
| jrnl (bare startup) | **227ms** | ⚠️ SLOW — Python + pkg loading |

**Critical insight:** Rofi itself is the bottleneck at 75ms minimum. Everything else
(except jrnl) is fast enough. The optimization strategy is:
1. Minimize rofi invocations (don't re-launch per screen if possible)
2. Never call jrnl in the hot path — use direct file reads
3. Parallelize context bar assembly
4. Pre-compute rofi input strings

---

## 2. Two Architecture Options

### Option A: dmenu mode (current)

Each screen = new rofi process. Script builds item list, pipes to rofi, reads selection.

```
[keypress] → bash script → pipe items → rofi process → user selects → stdout → script processes → repeat
```

**Per-transition cost:** 75-120ms (rofi startup) + data assembly time
**Advantage:** Simple, stateless, easy to debug
**Disadvantage:** Every screen change re-launches rofi (perceptible flicker)

### Option B: rofi-script mode (recommended for v3)

Single rofi process stays alive. Script is called repeatedly by rofi with selection context.

```
[keypress] → rofi starts ONCE → calls script (ROFI_RETV=0) → script outputs items
             user selects → rofi calls script again (ROFI_RETV=1, $1=selection)
             script outputs new items → rofi redraws IN-PLACE → no flicker
```

**Per-transition cost:** ~5-15ms (just script execution, no rofi restart)
**Advantage:** Instant screen changes, no flicker, state preserved
**Disadvantage:** Script must be stateless between calls (use ROFI_DATA for state),
                  more complex control flow

---

## 3. Rofi-Script Mode Protocol (the key to speed)

### Environment variables set by rofi:

| Variable | Meaning |
|----------|---------|
| `ROFI_RETV` | 0=initial, 1=selected entry, 2=custom text typed, 10-28=kb-custom-N |
| `ROFI_INFO` | Value from `\0info\x1f<data>` of the selected row |
| `ROFI_DATA` | Value from previous `\0data\x1f<state>` header (persistent state!) |

### Header options (output by script, one per `\0` line):

```bash
# Set at start of output, before item lines:
echo -en "\0prompt\x1fww\n"                    # Change prompt text
echo -en "\0message\x1f${context_bar}\n"       # Set mesg area (context bar!)
echo -en "\0markup-rows\x1ftrue\n"             # Enable pango markup in rows
echo -en "\0no-custom\x1ffalse\n"              # Allow custom text (our prefix routing)
echo -en "\0use-hot-keys\x1ftrue\n"            # Enable kb-custom-N (return codes 10-28)
echo -en "\0keep-selection\x1ftrue\n"          # Don't reset cursor position on redraw
echo -en "\0new-selection\x1f3\n"              # Override: move cursor to row 3
echo -en "\0data\x1f${STATE_JSON}\n"           # Pass state to next invocation
echo -en "\0theme\x1fwindow{border-color:red;}\n"  # Runtime theme tweak
```

### Row options (per-item metadata):

```bash
# Append after each item line:
echo -en "🕐  Clock In / Out\0icon\x1fclock\x1finfo\x1fscreen:clock\n"
echo -en "📋  My Tasks\0icon\x1ftask\x1finfo\x1fscreen:tasks\n"
echo -en "───────────────────\0nonselectable\x1ftrue\n"
echo -en "📓  Journal\0info\x1fscreen:journal\x1fmeta\x1fjournal notes diary\n"
```

| Row option | Purpose |
|------------|---------|
| `info` | Passed back as ROFI_INFO on selection (our routing key!) |
| `icon` | Icon name or path |
| `meta` | Invisible search terms for filtering |
| `nonselectable` | Can't be selected (perfect for separators!) |
| `permanent` | Always shown regardless of filter |
| `display` | Override display text (original still used for filtering) |
| `urgent` | Highlight as urgent (true/false) |
| `active` | Highlight as active (true/false) |

### Custom keybindings (return codes 10-28):

```bash
# Enable in header:
echo -en "\0use-hot-keys\x1ftrue\n"

# Then in rofi invocation or script, bind keys:
# -kb-custom-1 "ctrl+d"    → ROFI_RETV=10 (delete action)
# -kb-custom-2 "ctrl+e"    → ROFI_RETV=11 (edit action)
# -kb-custom-3 "ctrl+s"    → ROFI_RETV=12 (start timer)
# -kb-custom-4 "ctrl+n"    → ROFI_RETV=13 (new item)

# In script, check:
case "$ROFI_RETV" in
  0)  ;; # initial call — output items
  1)  ;; # selected entry — $1 is the text, ROFI_INFO is the info field
  2)  ;; # custom text typed — $1 is what they typed (our prefix routing!)
  10) ;; # kb-custom-1 pressed on $1
  11) ;; # kb-custom-2 pressed on $1
esac
```

---

## 4. Optimized Invocation Flags

### For dmenu mode (current approach, optimized):

```bash
rofi -dmenu -i \
  -no-config \
  -no-plugins \
  -async-pre-read 0 \
  -p "ww" \
  -mesg "$context_bar" \
  -theme-str '
    window { width: 50%; location: center; }
    listview { lines: 15; fixed-height: true; scrollbar: false; }
    element { padding: 2px 8px; }
  ' \
  -kb-custom-1 "ctrl+d" \
  -kb-custom-2 "ctrl+e" \
  -kb-custom-3 "ctrl+s"
```

Key flags:
| Flag | Why |
|------|-----|
| `-no-config` | Skip parsing ~/.config/rofi/config.rasi (~5-10ms saved) |
| `-no-plugins` | Skip loading .so plugins (~2-5ms saved) |
| `-async-pre-read 0` | Start displaying immediately, don't buffer stdin |
| `-i` | Case-insensitive matching |
| `fixed-height: true` | No layout reflow as items change — faster rendering |
| `scrollbar: false` | One less widget to render |

### For script mode (recommended upgrade):

```bash
rofi -show ww \
  -no-config \
  -no-plugins \
  -modi "ww:${SCRIPT_DIR}/ww-popup-script.sh" \
  -theme-str '
    window { width: 50%; location: center; anchor: center; }
    listview { lines: 15; fixed-height: true; scrollbar: false; }
    element { padding: 2px 8px; }
    element-icon { size: 1.2em; }
  ' \
  -kb-custom-1 "ctrl+d" \
  -kb-custom-2 "ctrl+e" \
  -kb-custom-3 "ctrl+s" \
  -kb-custom-4 "ctrl+n" \
  -kb-custom-5 "ctrl+r"
```

---

## 5. Script Mode Architecture for ww

### Single entry-point script: `ww-popup-script.sh`

```bash
#!/usr/bin/env bash
# Called by rofi repeatedly. Must output items fast.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ww-popup-screens/shared.sh"

# State from previous invocation
STATE="${ROFI_DATA:-home}"
SELECTION="$1"
INFO="${ROFI_INFO:-}"

case "$ROFI_RETV" in
  0) # Initial call — show home screen
    render_home
    ;;
  1) # User selected an entry — route based on info field
    route_selection "$INFO" "$SELECTION"
    ;;
  2) # User typed custom text — prefix routing
    route_typed_input "$SELECTION"
    ;;
  10) # kb-custom-1: delete/done action on current selection
    action_done "$INFO" "$SELECTION"
    ;;
  11) # kb-custom-2: edit action
    action_edit "$INFO" "$SELECTION"
    ;;
  12) # kb-custom-3: start timer for selection
    action_start_timer "$INFO" "$SELECTION"
    ;;
esac
```

### Routing via ROFI_INFO:

Instead of pattern-matching menu text (fragile), each row carries structured
info that tells the script exactly what to do:

```bash
render_home() {
  local ctx=$(popup_context_bar)
  echo -en "\0prompt\x1fww\n"
  echo -en "\0message\x1f${ctx}\n"
  echo -en "\0markup-rows\x1ftrue\n"
  echo -en "\0no-custom\x1ffalse\n"
  echo -en "\0use-hot-keys\x1ftrue\n"
  echo -en "\0data\x1fhome\n"

  echo -en "🕐  Clock In / Out\0info\x1fnav:clock\n"
  echo -en "📋  My Tasks\0info\x1fnav:tasks\n"
  echo -en "📝  My Lists\0info\x1fnav:lists\n"
  echo -en "🔍  Search\0info\x1fnav:search\n"
  echo -en "───────────────────\0nonselectable\x1ftrue\n"
  echo -en "📓  Journal\0info\x1fnav:journal\n"
  echo -en "💰  Ledger\0info\x1fnav:ledger\n"
  echo -en "👥  Board (Who's In)\0info\x1fnav:board\n"
  echo -en "📊  Reports\0info\x1fnav:reports\n"
  echo -en "🤝  Community\0info\x1fnav:community\n"
  echo -en "───────────────────\0nonselectable\x1ftrue\n"
  echo -en "🔄  Switch Profile\0info\x1fnav:profile\n"
  echo -en "🔗  GitHub Sync\0info\x1fnav:sync\n"
  echo -en "⚙️  System\0info\x1fnav:system\n"
}

route_selection() {
  local info="$1" selection="$2"
  case "$info" in
    nav:clock)   render_clock ;;
    nav:tasks)   render_tasks ;;
    nav:lists)   render_lists ;;
    # ... etc
    task:done:*) do_task_done "${info#task:done:}"; render_tasks ;;
    task:start:*) do_task_start "${info#task:start:}"; render_tasks ;;
  esac
}
```

### Why this is fast:

1. **Rofi starts ONCE** (75ms) then stays alive for the entire session
2. **Screen transitions** = rofi calls script → script outputs new items → rofi redraws
   - Script execution: ~10-40ms depending on data queries
   - Rofi redraw: ~5-10ms (just list widget update, no window creation)
   - **Total transition: 15-50ms** (imperceptible)
3. **Separators** use `nonselectable` — no more pattern matching or re-display hacks
4. **State** via ROFI_DATA — no temp files, no env pollution
5. **Custom actions** via kb-custom — Ctrl+D to complete a task without leaving the list

---

## 6. Context Bar Optimization

Current: 34ms (sequential). Target: <15ms.

### Strategy: parallel subshells

```bash
popup_context_bar_fast() {
  local profile
  profile="$(popup_active_profile)"
  [[ -z "$profile" ]] && { echo "No profile · Switch Profile to begin"; return; }

  local base="${PROFILES_DIR}/${profile}"
  local list_name timer_part task_part

  # Read list name (pure file read, ~1ms)
  list_name=$(grep -m1 'default:' "${base}/lists.yaml" 2>/dev/null | sed 's/.*default:\s*//' | tr -d '[:space:]')
  list_name="${list_name:-tasks}"

  # Parallel: timer + task count
  local timer_file task_file
  timer_file=$(mktemp)
  task_file=$(mktemp)

  (
    if [[ -d "${base}/.timewarrior" ]]; then
      local line
      line=$(TIMEWARRIORDB="${base}/.timewarrior" timew 2>/dev/null | head -1)
      if [[ "$line" == "Tracking"* ]]; then
        echo "▶ $(echo "$line" | sed 's/^Tracking //' | sed 's/"//g')"
      else
        echo "⏸ idle"
      fi
    else
      echo "⏸ idle"
    fi
  ) > "$timer_file" &

  (
    TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task +READY count 2>/dev/null || echo "0"
  ) > "$task_file" &

  wait

  timer_part=$(<"$timer_file")
  task_part=$(<"$task_file")
  rm -f "$timer_file" "$task_file"

  local result="${profile} / ${list_name} · ${timer_part}"
  [[ "$task_part" != "0" ]] && result+=" · ${task_part} tasks"
  echo "$result"
}
```

### Even faster: cache file with TTL

```bash
CACHE_DIR="${HOME}/.cache/ww/popup"
mkdir -p "$CACHE_DIR" 2>/dev/null

popup_context_bar_cached() {
  local cache="${CACHE_DIR}/context-bar"
  # Cache valid for 5 seconds
  if [[ -f "$cache" ]] && (( $(date +%s) - $(stat -c %Y "$cache") < 5 )); then
    cat "$cache"
    return
  fi
  local result
  result=$(popup_context_bar_fast)
  echo "$result" > "$cache"
  echo "$result"
}
```

Invalidation: after any write action (task add, timew start/stop), delete the cache:
```bash
rm -f "${CACHE_DIR}/context-bar"
```

---

## 7. Tool-Specific Optimization

### TaskWarrior (6ms — already fast)
- **Export JSON for bulk reads:** `task export` returns everything; parse with
  `python3 -c` for complex filtering (one python3 call vs multiple task calls)
- **Pre-format task list for rofi:** Cache the formatted string ready to pipe

```bash
# Generate task list ready for rofi (with info fields for routing)
popup_task_list_rofi() {
  local rc="${base}/.taskrc" data="${base}/.task"
  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing \
    status:pending export 2>/dev/null | python3 -c '
import json,sys
tasks=sorted(json.load(sys.stdin),key=lambda t:-t.get("urgency",0))
for t in tasks[:20]:
    tid=t["id"]; desc=t.get("description","")
    proj=t.get("project","")
    p=f" [{proj}]" if proj else ""
    # Row with info field for routing
    sys.stdout.write(f"{tid:3d}  {desc}{p}\0info\x1ftask:id:{tid}\n")
'
}
```

### TimeWarrior (3ms — already fast)
- Direct reads possible: `~/.timewarrior/data/YYYY-MM.data` is plain text
- Format: `inc YYYYMMDDTHHMMSSZ - YYYYMMDDTHHMMSSZ # "tag1" "tag2"`
- For status-only, `timew` binary is fine at 3ms

### jrnl (227ms — AVOID in hot path)
- **NEVER call jrnl binary** for reads in the popup
- **Direct file read** for recent entries:

```bash
popup_journal_recent_fast() {
  local journal_file
  journal_file=$(popup_journal_file)
  [[ -f "$journal_file" ]] || return
  # Read last 10 entries (format: [YYYY-MM-DD HH:MM] Title text)
  grep -E '^\[20[0-9]{2}-' "$journal_file" | tail -10 | tac
}
```

- For writes, already using direct file append (proven in dev-guide)

### hledger (48ms — acceptable for non-hot paths)
- For balance views, 48ms is fine (user navigated to ledger screen)
- For context bar, don't include ledger data
- Cache account list (rarely changes):

```bash
popup_accounts_cached() {
  local cache="${CACHE_DIR}/accounts"
  if [[ -f "$cache" ]] && (( $(date +%s) - $(stat -c %Y "$cache") < 300 )); then
    cat "$cache"; return
  fi
  local ledger_file=$(popup_ledger_file)
  [[ -n "$ledger_file" && -f "$ledger_file" ]] || return
  hledger -f "$ledger_file" accounts 2>/dev/null | tee "$cache"
}
```

### python3 / list.py (30ms startup)
- For simple reads, consider direct file parsing:

```bash
# list.py data format is just: "text | id:hash" per line
# For display, we just need the text before " | id:"
popup_list_items_fast() {
  local list_file="${list_dir}/${list_name}"
  [[ -f "$list_file" ]] || return
  while IFS= read -r line; do
    local text="${line%% | id:*}"
    local prefix="${line##* | id:}"
    prefix="${prefix:0:6}"
    echo -en "${prefix} - ${text}\0info\x1flist:item:${prefix}\n"
  done < "$list_file"
}
```

- For writes, still use list.py (it manages the ID generation and file format)

---

## 8. Bash Speed Patterns

### Use mapfile for bulk reads:
```bash
mapfile -t lines < <(some_command)  # faster than while-read loop
```

### Avoid subshells where possible:
```bash
# Slow (subshell per assignment):
profile=$(cat "$STATE_DIR/last-profile")

# Fast (built-in):
read -r profile < "$STATE_DIR/last-profile"
```

### LC_ALL=C for string operations:
```bash
# Faster grep/sed/awk when you don't need UTF-8 awareness:
LC_ALL=C grep -c "pattern" file
```

### printf over echo for \0 sequences:
```bash
# echo -en is bash-specific and sometimes buggy with \0
# printf is more portable and reliable:
printf '%s\0info\x1fnav:tasks\n' "📋  My Tasks"
```

### Here-strings over echo|pipe:
```bash
# Slow (spawns subshell + pipe):
echo "$items" | rofi -dmenu

# Faster (here-string, no subshell):
rofi -dmenu <<< "$items"

# Fastest for multi-line (here-doc or -input flag):
rofi -dmenu -input <(printf '%s\n' "${items[@]}")
```

---

## 9. Theme for Speed

Minimal theme that avoids all rendering overhead:

```rasi
/* ww-popup-speed.rasi — minimal theme for maximum performance */
* {
    background-color: #1e1e2e;
    text-color: #cdd6f4;
    font: "monospace 12";
}

window {
    width: 50%;
    location: center;
    anchor: center;
    border: 2px solid;
    border-color: #89b4fa;
    border-radius: 0px;           /* no rounded corners = no alpha compositing */
    transparency: "disabled";      /* critical: no compositor interaction */
}

mainbox {
    padding: 8px;
    spacing: 4px;
}

inputbar {
    padding: 4px 8px;
    children: [prompt, textbox-prompt-colon, entry];
}

prompt { text-color: #89b4fa; }
textbox-prompt-colon { str: ": "; }

message {
    padding: 4px 8px;
    border: 1px solid;
    border-color: #313244;
}

listview {
    lines: 15;
    fixed-height: true;          /* no reflow on filter */
    scrollbar: false;            /* one less widget */
    spacing: 0px;
    padding: 4px 0;
}

element {
    padding: 4px 8px;
    spacing: 8px;
}

element selected {
    background-color: #313244;
    text-color: #cdd6f4;
}

element-text {
    highlight: bold #89b4fa;     /* matching chars highlighted */
}
```

**Key speed decisions:**
- `transparency: "disabled"` — prevents compositor roundtrip
- `border-radius: 0px` — no anti-aliased corners (saves GPU compositing)
- `fixed-height: true` — list doesn't reflow when filtering
- `scrollbar: false` — one less widget to measure/render
- No icons (`element-icon` omitted) — skip icon theme lookup entirely
- Monospace font — simpler glyph metrics, faster text layout

---

## 10. Architectural Recommendations

### Phase 1 (now): Optimize dmenu mode

1. Add `-no-config -no-plugins` to all rofi invocations
2. Use inline theme-str with the speed optimizations above
3. Parallelize context bar (saves ~15ms)
4. Cache task list and accounts (avoid redundant reads)
5. Replace jrnl CLI reads with direct file parsing
6. Use `nonselectable` row option for separators (already works in dmenu mode!)

**Expected result:** Home screen in ~90ms (75ms rofi + 15ms data), screen transitions ~100ms

### Phase 2 (next): Switch to rofi-script mode

1. Create `ww-popup-script.sh` as the single entry point
2. Use ROFI_INFO for routing (no more text pattern matching)
3. Use ROFI_DATA for state persistence between calls
4. Use kb-custom-N for multi-action (Ctrl+D=done, Ctrl+E=edit, Ctrl+S=start timer)
5. Use `\0nonselectable` for separators, `\0active` for current timer, `\0urgent` for overdue

**Expected result:** Home screen in ~90ms (first launch), transitions in ~15-40ms (instant feel)

### Phase 3 (future): Background cache daemon

If needed (probably overkill given current measurements):
- Tiny background script that runs every 5s, writes cache files
- Cache: formatted rofi item strings, pre-computed context bar, task list
- Popup reads cache → pipes directly to rofi → zero data assembly time

---

## 11. Quick Reference: Return Codes

| Code | Meaning | Use case |
|------|---------|----------|
| 0 | Entry selected | Normal selection routing |
| 1 | Cancelled (Esc) | Exit popup |
| 10 | kb-custom-1 | Task done / Clock out |
| 11 | kb-custom-2 | Edit / Modify |
| 12 | kb-custom-3 | Start timer |
| 13 | kb-custom-4 | Add new item |
| 14 | kb-custom-5 | Refresh / Back |
| 15-28 | kb-custom-6-19 | Available for more |

---

## 12. Comparison: dmenu vs script mode for our use case

| Factor | dmenu mode | script mode |
|--------|-----------|-------------|
| First launch | 75-120ms | 75-120ms (same) |
| Screen transition | 75-120ms (new process) | **15-40ms** (script re-exec) |
| Typed input routing | Read from stdout, parse | ROFI_RETV=2, already parsed |
| State management | External files/env | ROFI_DATA (built-in) |
| Separator handling | Pattern match "─" | `nonselectable` flag (proper) |
| Multi-action per row | Can't (one return) | kb-custom-N (19 actions!) |
| Flicker on transition | Yes (window destroy/create) | **No** (in-place redraw) |
| Code complexity | Simple pipes | More structured, but cleaner routing |
| fzf/dmenu fallback | Easy (same pipe model) | Need separate code path |

**Verdict:** Script mode is the clear winner for the "blazingly fast" goal.
The only trade-off is losing trivial fzf/dmenu fallback — but those can
remain as a separate `popup_select` path for environments without rofi.
