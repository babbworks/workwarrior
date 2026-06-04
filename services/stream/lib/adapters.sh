#!/usr/bin/env bash

_dedup_events() {
  local log="$1"
  [[ -f "$log" ]] || { cat; return 0; }
  awk 'NR==FNR{seen[$1" "$2" "$3" "$4]=1;next} !seen[$1" "$2" "$3" "$4]' "$log" -
}

_ts_from_tw() {
  # Convert TaskWarrior timestamp (20260503T090000Z) to unix
  python3 -c "
import sys
from datetime import datetime, timezone
s = sys.argv[1].replace('Z','')
try:
    dt = datetime.strptime(s, '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$1" 2>/dev/null || echo 0
}

_hash12() {
  # sha256 first 12 chars of input
  printf '%s' "$1" | python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest()[:12])"
}

adapt_tasks() {
  local taskrc="${TASKRC:-}"
  local taskdata="${TASKDATA:-}"
  local prof="${WARRIOR_PROFILE:-}"

  if ! command -v task &>/dev/null; then
    echo "adapt_tasks: task command not found" >&2
    return 0
  fi

  local export_cmd="task"
  [[ -n "$taskrc" ]]   && export_cmd="TASKRC='$taskrc' $export_cmd"
  [[ -n "$taskdata" ]] && export_cmd="TASKDATA='$taskdata' $export_cmd"

  local json
  json=$(env \
    ${TASKRC:+TASKRC="$TASKRC"} \
    ${TASKDATA:+TASKDATA="$TASKDATA"} \
    task export 2>/dev/null || echo "[]")

  echo "$json" | python3 -c "
import sys, json, hashlib

data = json.load(sys.stdin)
prof = sys.argv[1] if len(sys.argv) > 1 else ''

def tw_ts(s):
    if not s: return 0
    from datetime import datetime, timezone
    try:
        return int(datetime.strptime(s.replace('Z',''), '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc).timestamp())
    except:
        return 0

def h12(s):
    return hashlib.sha256(s.encode()).hexdigest()[:12]

for task in data:
    uuid  = task.get('uuid', '')
    proj  = task.get('project', '')
    tags  = task.get('tags', [])
    desc  = task.get('description', '')[:60].replace('\"', '\\\\\"')
    entry = task.get('entry', '')
    status= task.get('status', 'pending')
    start = task.get('start', '')

    action = {'pending': 'add', 'completed': 'done', 'deleted': 'delete'}.get(status, 'modify')
    ts = tw_ts(entry)
    if ts == 0:
        continue

    c = json.dumps({'src':'task','prof':prof,'proj':proj,'tags':tags,'name':desc}, separators=(',',':'))
    print(f'{ts} T {action} {uuid} {c}')

    if start:
        fts = tw_ts(start)
        if fts > 0:
            print(f'{fts} F start {uuid} {c}')
" "$prof" 2>/dev/null || true
}

adapt_timew() {
  local timedb="${TIMEWARRIORDB:-}"
  local prof="${WARRIOR_PROFILE:-}"

  if ! command -v timew &>/dev/null; then
    echo "adapt_timew: timew command not found" >&2
    return 0
  fi

  local json
  if [[ -n "$timedb" ]]; then
    json=$(TIMEWARRIORDB="$timedb" timew export 2>/dev/null || echo "[]")
  else
    json=$(timew export 2>/dev/null || echo "[]")
  fi

  local _py; _py="$(mktemp /tmp/wwadapt_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json, hashlib, re
from datetime import datetime, timezone

data = json.load(sys.stdin)
prof = sys.argv[1] if len(sys.argv) > 1 else ''

UUID_PAT = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)

def tw_ts(s):
    if not s: return 0
    try:
        return int(datetime.strptime(s.replace('Z',''), '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc).timestamp())
    except:
        return 0

def h12(*parts):
    return hashlib.sha256('|'.join(parts).encode()).hexdigest()[:12]

def first_project(tags):
    for t in tags:
        t = t.strip('"\'')
        if t and not UUID_PAT.match(t):
            return t
    return ''

for interval in data:
    if not isinstance(interval, dict):
        continue
    tags  = interval.get('tags', [])
    start = interval.get('start', '')
    end   = interval.get('end', '')
    if not start or not end:
        continue
    ts_start = tw_ts(start)
    ts_end   = tw_ts(end)
    if ts_start == 0:
        continue
    proj = first_project(tags)
    obj  = h12(start, json.dumps(tags))
    c    = json.dumps({'src':'timew','prof':prof,'proj':proj,'tags':tags}, separators=(',',':'))
    print(f'{ts_start} B start {obj} {c}')
    if ts_end > 0:
        print(f'{ts_end} B stop {obj} {c}')
PYEOF
  echo "$json" | python3 "$_py" "$prof" 2>/dev/null || true
  rm -f "$_py"
}

adapt_jrnl() {
  local prof="${WARRIOR_PROFILE:-}"
  local base="${WORKWARRIOR_BASE:-}"
  local jrnl_config=""
  [[ -n "$base" && -f "$base/jrnl.yaml" ]] && jrnl_config="$base/jrnl.yaml"

  if ! command -v jrnl &>/dev/null; then
    echo "adapt_jrnl: jrnl command not found" >&2
    return 0
  fi

  local json
  if [[ -n "$jrnl_config" ]]; then
    json=$(jrnl --config-file "$jrnl_config" --format json 2>/dev/null || echo '{"entries":[]}')
  else
    json=$(jrnl --format json 2>/dev/null || echo '{"entries":[]}')
  fi

  echo "$json" | python3 -c "
import sys, json, hashlib, re
from datetime import datetime, timezone

data = json.load(sys.stdin)
prof = sys.argv[1] if len(sys.argv) > 1 else ''
entries = data.get('entries', [])

TAG_PAT = re.compile(r'[@#]([\w-]+)')

def h12(*parts):
    return hashlib.sha256('|'.join(parts).encode()).hexdigest()[:12]

def parse_ts(s):
    if not s: return 0
    for fmt in ('%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            dt = datetime.strptime(s[:len(fmt)], fmt).replace(tzinfo=timezone.utc)
            return int(dt.timestamp())
        except:
            continue
    return 0

for entry in entries:
    date  = entry.get('date', '')
    title = entry.get('title', '')
    body  = entry.get('body', '')
    jrnl_tags = entry.get('tags', [])

    ts = parse_ts(date)
    if ts == 0:
        continue

    # Collect all @/# tags from title + body + native tags list
    raw_tags = set()
    for t in jrnl_tags:
        raw_tags.add(re.sub(r'^[@#]', '', t))
    for m in TAG_PAT.finditer(title + ' ' + body):
        raw_tags.add(m.group(1))
    tags = sorted(raw_tags)

    # First @mention = project (jrnl convention)
    proj = ''
    for m in TAG_PAT.finditer('@' + title + ' ' + body):
        if title.startswith('@') or '@' in body:
            proj = m.group(1)
            break

    obj   = h12(date, title)
    name  = title[:60].replace('\"', '\\\\\"')
    c     = json.dumps({'src':'jrnl','prof':prof,'proj':proj,'tags':tags,'name':name}, separators=(',',':'))
    print(f'{ts} A write {obj} {c}')
" "$prof" 2>/dev/null || true
}

adapt_ledger() {
  local prof="${WARRIOR_PROFILE:-}"
  local base="${WORKWARRIOR_BASE:-}"
  local ledgers_dir=""
  [[ -n "$base" && -d "$base/ledgers" ]] && ledgers_dir="$base/ledgers"

  if ! command -v hledger &>/dev/null; then
    echo "adapt_ledger: hledger command not found" >&2
    return 0
  fi

  [[ -z "$ledgers_dir" ]] && return 0

  for ledger_file in "$ledgers_dir"/*.journal; do
    [[ -f "$ledger_file" ]] || continue
    local ledger_name; ledger_name="$(basename "$ledger_file" .journal)"

    local json
    json=$(hledger -f "$ledger_file" print -O json 2>/dev/null || echo "[]")

    echo "$json" | python3 -c "
import sys, json, hashlib, re
from datetime import datetime, timezone

data = json.load(sys.stdin)
prof        = sys.argv[1] if len(sys.argv) > 1 else ''
ledger_name = sys.argv[2] if len(sys.argv) > 2 else ''

COMMENT_TAG = re.compile(r'(\w[\w-]*):\s*([\w][\w-]*)')

def parse_date(s):
    if not s: return 0
    try:
        dt = datetime.strptime(s[:10], '%Y-%m-%d').replace(tzinfo=timezone.utc)
        return int(dt.timestamp())
    except:
        return 0

def h12(*parts):
    return hashlib.sha256('|'.join(str(p) for p in parts).encode()).hexdigest()[:12]

for tx in data:
    if not isinstance(tx, dict): continue
    date_str = tx.get('tdate', tx.get('date', ''))
    desc     = tx.get('tdescription', tx.get('description', ''))[:60].replace('\"', '\\\\\"')
    comment  = tx.get('tcomment', '')
    postings = tx.get('tpostings', [])
    ts       = parse_date(date_str)
    if ts == 0: continue

    # Parse comment tags: ; project:alpha, client:acme
    comment_tags = {}
    for m in COMMENT_TAG.finditer(comment):
        comment_tags[m.group(1)] = m.group(2)
    proj = comment_tags.get('project', '')

    for posting in postings:
        acct = posting.get('paccount', '')
        if not acct: continue
        segs = acct.split(':')
        if not proj and len(segs) >= 2:
            proj = segs[1]
        tag_set = list(segs) + list(comment_tags.keys())
        tags = sorted(set(tag_set))
        obj = h12(date_str, desc, acct)
        c = json.dumps({'src':'ledger','prof':prof,'proj':proj,'tags':tags,
                        'name':desc,'ledger':ledger_name}, separators=(',',':'))
        print(f'{ts} T post {obj} {c}')
" "$prof" "$ledger_name" 2>/dev/null || true
  done
}
