# ww-popup-screens/board.sh — Board screen (Who's In) — stream.log + timew fallback

screen_board() {
  popup_require_profile || return

  local ctx
  ctx="$(popup_context_bar)"

  local stream_log="${WW_BASE}/stream/stream.log"
  local content=""

  if [[ -f "$stream_log" ]]; then
    # Parse stream.log: format is "<unix_ts> <OP> <action> <object> <ctx_json>"
    # Look for B (bundy) start/stop events for today
    local today_ts
    today_ts=$(date -d 'today 00:00' +%s 2>/dev/null || date +%s)
    content=$(python3 -c "
import sys, json, time

today_start = int('${today_ts}')
events = []
try:
    with open('${stream_log}', 'r') as f:
        for line in f:
            parts = line.strip().split(None, 4)
            if len(parts) < 4:
                continue
            ts = int(parts[0])
            if ts < today_start:
                continue
            op = parts[1]
            action = parts[2]
            obj = parts[3]
            ctx = parts[4] if len(parts) > 4 else ''
            events.append({'ts': ts, 'op': op, 'action': action, 'obj': obj, 'ctx': ctx})
except Exception as e:
    pass

if not events:
    print('(no stream activity today)')
else:
    for e in events[-20:]:
        t = time.strftime('%H:%M', time.localtime(e['ts']))
        print(f\"{t}  {e['op']} {e['action']} {e['obj']}\")
" 2>/dev/null)
  fi

  # Fallback to timew summary if no stream data
  if [[ -z "$content" || "$content" == "(no stream activity today)" ]]; then
    local base
    base="$(popup_profile_base)"
    local twdb="${base}/.timewarrior"
    local timew_out
    timew_out=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null) || timew_out=""
    if [[ -n "$timew_out" ]]; then
      content="Today's Time Activity:
${timew_out}"
    else
      content="(no activity data available)"
    fi
  fi

  popup_display "👥 Board" "$ctx" "$content" || true
}
