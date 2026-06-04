#!/usr/bin/env bash
# Export Utilities Library
# Functions to export data from TaskWarrior, TimeWarrior, JRNL, and Hledger

# ============================================================================
# CONFIGURATION
# ============================================================================

[[ -z "${WW_BASE:-}" ]] && WW_BASE="$HOME/ww"
EXPORT_DIR="${WW_BASE}/exports"

_TASK_BIN="${_TASK_BIN:-$(command -v task 2>/dev/null || true)}"
# Prefer real binary over any shell function wrapper
if [[ "$(type -t task 2>/dev/null)" == "function" ]]; then
  _TASK_BIN=$(PATH="/usr/local/bin:/opt/local/bin:/usr/bin:$PATH" which task 2>/dev/null || true)
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

get_profile_dir() {
  local profile_name="${1:-$WARRIOR_PROFILE}"
  if [[ -z "$profile_name" ]]; then
    return 1
  fi
  echo "$WW_BASE/profiles/$profile_name"
}

get_export_path() {
  local profile_name="$1"
  local type="$2"
  local format="$3"
  local custom_output="$4"

  if [[ -n "$custom_output" ]]; then
    echo "$custom_output"
    return
  fi

  local export_dir="$EXPORT_DIR/$profile_name"
  mkdir -p "$export_dir"

  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H%M%S")
  echo "$export_dir/${timestamp}_${type}.${format}"
}

csv_escape() {
  local field="$1"
  if [[ "$field" == *","* || "$field" == *$'\n'* || "$field" == *'"'* ]]; then
    field="${field//\"/\"\"}"
    echo "\"$field\""
  else
    echo "$field"
  fi
}

json_wrapper() {
  local profile="$1"
  local type="$2"
  local data="$3"

  cat << EOF
{
  "profile": "$profile",
  "exported": "$(date -Iseconds)",
  "type": "$type",
  "data": $data
}
EOF
}

# ============================================================================
# TASKWARRIOR EXPORT
# ============================================================================

export_tasks_json() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if [[ ! -d "$taskdata" || -z "$_TASK_BIN" ]]; then
    [[ -n "$output_file" ]] && echo "[]" > "$output_file" && echo "$output_file" || echo "[]"
    return 0
  fi

  local data
  data=$(TASKRC="$taskrc" TASKDATA="$taskdata" "$_TASK_BIN" $filter export 2>/dev/null || echo "[]")

  local profile_name
  profile_name=$(basename "$profile_dir")
  local wrapped
  wrapped=$(json_wrapper "$profile_name" "tasks" "$data")

  if [[ -n "$output_file" ]]; then
    echo "$wrapped" > "$output_file"
    echo "$output_file"
  else
    echo "$wrapped"
  fi
}

export_tasks_csv() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if [[ ! -d "$taskdata" || -z "$_TASK_BIN" ]]; then
    return 1
  fi

  local json_data
  json_data=$(TASKRC="$taskrc" TASKDATA="$taskdata" "$_TASK_BIN" $filter export 2>/dev/null || echo "[]")

  local csv_output
  csv_output=$(python3 - "$json_data" << 'PY'
import json, sys, csv, io

data = json.loads(sys.argv[1])
out = io.StringIO()
w = csv.writer(out)
w.writerow(["id","uuid","description","status","project","tags","priority","due","entry","modified"])
for t in data:
    w.writerow([
        t.get("id",""), t.get("uuid",""), t.get("description",""),
        t.get("status",""), t.get("project",""),
        ",".join(t.get("tags") or []),
        t.get("priority",""), t.get("due",""),
        t.get("entry",""), t.get("modified",""),
    ])
print(out.getvalue(), end="")
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo "$csv_output"
  fi
}

export_tasks_markdown() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$taskdata" || -z "$_TASK_BIN" ]]; then
    return 1
  fi

  local pending_json completed_json
  pending_json=$(TASKRC="$taskrc" TASKDATA="$taskdata" "$_TASK_BIN" $filter status:pending export 2>/dev/null || echo "[]")
  completed_json=$(TASKRC="$taskrc" TASKDATA="$taskdata" "$_TASK_BIN" $filter status:completed export 2>/dev/null || echo "[]")

  local md_output
  md_output=$(python3 - "$profile_name" "$pending_json" "$completed_json" << 'PY'
import json, sys
profile, pending_raw, completed_raw = sys.argv[1], sys.argv[2], sys.argv[3]
pending = json.loads(pending_raw)
completed = json.loads(completed_raw)
from datetime import datetime

def fmt_date(s):
    if not s: return ""
    try: return datetime.strptime(s, "%Y%m%dT%H%M%SZ").strftime("%Y-%m-%d")
    except: return s[:10]

lines = [f"# Tasks Export - {profile}",
         f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
         "",
         f"## Pending Tasks ({len(pending)})", "",
         "| ID | Description | Project | Priority | Due |",
         "|----|-------------|---------|----------|-----|"]
for t in pending:
    lines.append(f"| {t.get('id','')} | {t.get('description','')[:50]} | {t.get('project','')} | {t.get('priority','')} | {fmt_date(t.get('due',''))} |")
lines += ["", f"## Completed Tasks ({len(completed)})", ""]
for t in completed[:20]:
    lines.append(f"- {t.get('description','')} *(completed {fmt_date(t.get('end',''))})*")
print("\n".join(lines))
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo "$md_output"
  fi
}

# ============================================================================
# TIMEWARRIOR EXPORT
# ============================================================================

export_time_json() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local timedb="$profile_dir/.timewarrior"

  if [[ ! -d "$timedb" ]] || ! command -v timew &>/dev/null; then
    [[ -n "$output_file" ]] && echo "[]" > "$output_file" && echo "$output_file" || echo "[]"
    return 0
  fi

  local data
  data=$(TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null || echo "[]")

  local profile_name
  profile_name=$(basename "$profile_dir")
  local wrapped
  wrapped=$(json_wrapper "$profile_name" "time" "$data")

  if [[ -n "$output_file" ]]; then
    echo "$wrapped" > "$output_file"
    echo "$output_file"
  else
    echo "$wrapped"
  fi
}

export_time_csv() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local timedb="$profile_dir/.timewarrior"

  if [[ ! -d "$timedb" ]] || ! command -v timew &>/dev/null; then
    return 1
  fi

  local json_data
  json_data=$(TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null || echo "[]")

  local csv_output
  csv_output=$(python3 - "$json_data" << 'PY'
import json, sys, csv, io

data = json.loads(sys.argv[1])
out = io.StringIO()
w = csv.writer(out)
w.writerow(["id","start","end","tags","annotation"])
for t in data:
    w.writerow([
        t.get("id",""), t.get("start",""), t.get("end",""),
        ",".join(t.get("tags") or []),
        t.get("annotation",""),
    ])
print(out.getvalue(), end="")
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo "$csv_output"
  fi
}

export_time_markdown() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local timedb="$profile_dir/.timewarrior"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$timedb" ]] || ! command -v timew &>/dev/null; then
    return 1
  fi

  local summary_text json_data
  summary_text=$(TIMEWARRIORDB="$timedb" timew summary $filter 2>/dev/null || echo "(no data)")
  json_data=$(TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null || echo "[]")

  local md_output
  md_output=$(python3 - "$profile_name" "$summary_text" "$json_data" << 'PY'
import json, sys
from datetime import datetime

profile, summary, raw = sys.argv[1], sys.argv[2], sys.argv[3]
entries = json.loads(raw)

def fmt(s):
    if not s: return ""
    try: return datetime.strptime(s, "%Y%m%dT%H%M%SZ").strftime("%Y-%m-%d")
    except: return s[:10]

lines = [f"# Time Export - {profile}",
         f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
         "", "## Summary", "", "```", summary, "```", "",
         "## Recent Entries", "",
         "| Date | Tags |",
         "|------|------|"]
for e in entries[-20:]:
    lines.append(f"| {fmt(e.get('start',''))} | {', '.join(e.get('tags') or [])} |")
print("\n".join(lines))
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo "$md_output"
  fi
}

# ============================================================================
# JRNL EXPORT
# ============================================================================

export_journal_json() {
  local profile_dir="$1"
  local output_file="$2"

  local journals_dir="$profile_dir/journals"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$journals_dir" ]]; then
    [[ -n "$output_file" ]] && echo "[]" > "$output_file" && echo "$output_file" || echo "[]"
    return 0
  fi

  local wrapped
  wrapped=$(python3 - "$journals_dir" "$profile_name" << 'PY'
import os, re, json, sys
from datetime import datetime

journals_dir, profile = sys.argv[1], sys.argv[2]
entries = []
pat = re.compile(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] (.*)')

for fname in sorted(os.listdir(journals_dir)):
    if not fname.endswith(".txt"):
        continue
    jname = fname[:-4]
    path = os.path.join(journals_dir, fname)
    current = None
    body_lines = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = pat.match(line)
            if m:
                if current:
                    current["body"] = "\n".join(body_lines).strip()
                    entries.append(current)
                current = {"journal": jname, "timestamp": m.group(1), "title": m.group(2)}
                body_lines = []
            elif current:
                body_lines.append(line)
        if current:
            current["body"] = "\n".join(body_lines).strip()
            entries.append(current)

now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
print(json.dumps({"profile": profile, "exported": now, "type": "journal", "data": entries}, indent=2))
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$wrapped" > "$output_file"
    echo "$output_file"
  else
    echo "$wrapped"
  fi
}

export_journal_csv() {
  local profile_dir="$1"
  local output_file="$2"

  local journals_dir="$profile_dir/journals"

  if [[ ! -d "$journals_dir" ]]; then
    return 1
  fi

  local csv_output
  csv_output=$(python3 - "$journals_dir" << 'PY'
import os, re, sys, csv, io

journals_dir = sys.argv[1]
pat = re.compile(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] (.*)')
out = io.StringIO()
w = csv.writer(out)
w.writerow(["journal","timestamp","title","body"])

for fname in sorted(os.listdir(journals_dir)):
    if not fname.endswith(".txt"):
        continue
    jname = fname[:-4]
    current = None
    body_lines = []
    with open(os.path.join(journals_dir, fname), encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = pat.match(line)
            if m:
                if current:
                    w.writerow([jname, current[0], current[1], "\n".join(body_lines).strip()])
                current = (m.group(1), m.group(2))
                body_lines = []
            elif current:
                body_lines.append(line)
        if current:
            w.writerow([jname, current[0], current[1], "\n".join(body_lines).strip()])

print(out.getvalue(), end="")
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo "$csv_output"
  fi
}

export_journal_markdown() {
  local profile_dir="$1"
  local output_file="$2"

  local journals_dir="$profile_dir/journals"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$journals_dir" ]]; then
    return 1
  fi

  local md_output
  md_output=$(python3 - "$journals_dir" "$profile_name" << 'PY'
import os, re, sys
from datetime import datetime

journals_dir, profile = sys.argv[1], sys.argv[2]
pat = re.compile(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] (.*)')
lines = [f"# Journal Export - {profile}",
         f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}", ""]

for fname in sorted(os.listdir(journals_dir)):
    if not fname.endswith(".txt"):
        continue
    jname = fname[:-4]
    path = os.path.join(journals_dir, fname)
    entries = []
    current = None
    body_lines = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = pat.match(line)
            if m:
                if current:
                    entries.append((current[0], current[1], "\n".join(body_lines).strip()))
                current = (m.group(1), m.group(2))
                body_lines = []
            elif current:
                body_lines.append(line)
        if current:
            entries.append((current[0], current[1], "\n".join(body_lines).strip()))

    lines.append(f"## {jname} ({len(entries)} entries)")
    lines.append("")
    for ts, title, body in entries[-10:]:
        lines.append(f"### {ts} — {title}")
        if body:
            lines.append(body)
        lines.append("")

print("\n".join(lines))
PY
)

  if [[ -n "$output_file" ]]; then
    echo "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo "$md_output"
  fi
}

# ============================================================================
# HLEDGER EXPORT
# ============================================================================

export_ledger_json() {
  local profile_dir="$1"
  local output_file="$2"

  local ledgers_dir="$profile_dir/ledgers"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$ledgers_dir" ]]; then
    [[ -n "$output_file" ]] && echo "[]" > "$output_file" && echo "$output_file" || echo "[]"
    return 0
  fi

  local data="["
  local first=true

  for ledger_file in "$ledgers_dir"/*.journal; do
    [[ -f "$ledger_file" ]] || continue
    local ledger_name
    ledger_name=$(basename "$ledger_file" .journal)

    if command -v hledger &>/dev/null; then
      local ledger_json
      ledger_json=$(hledger -f "$ledger_file" print -O json 2>/dev/null || echo "[]")
      [[ "$first" == "true" ]] && first=false || data+=","
      data+="{\"ledger\":\"$ledger_name\",\"transactions\":$ledger_json}"
    fi
  done
  data+="]"

  local wrapped
  wrapped=$(json_wrapper "$profile_name" "ledger" "$data")

  if [[ -n "$output_file" ]]; then
    echo "$wrapped" > "$output_file"
    echo "$output_file"
  else
    echo "$wrapped"
  fi
}

export_ledger_csv() {
  local profile_dir="$1"
  local output_file="$2"

  local ledgers_dir="$profile_dir/ledgers"

  if [[ ! -d "$ledgers_dir" ]] || ! command -v hledger &>/dev/null; then
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  echo "ledger,txnidx,date,description,account,amount,commodity" > "$tmp"

  for ledger_file in "$ledgers_dir"/*.journal; do
    [[ -f "$ledger_file" ]] || continue
    local ledger_name
    ledger_name=$(basename "$ledger_file" .journal)
    hledger -f "$ledger_file" register -O csv 2>/dev/null | tail -n +2 | \
      python3 -c "
import sys, csv, io
r = csv.reader(sys.stdin)
w = csv.writer(sys.stdout)
for row in r:
    w.writerow(['$ledger_name'] + row)
" >> "$tmp"
  done

  if [[ -n "$output_file" ]]; then
    mv "$tmp" "$output_file"
    echo "$output_file"
  else
    cat "$tmp"
    rm -f "$tmp"
  fi
}

export_ledger_markdown() {
  local profile_dir="$1"
  local output_file="$2"

  local ledgers_dir="$profile_dir/ledgers"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$ledgers_dir" ]]; then
    return 1
  fi

  local md_lines
  md_lines="# Ledger Export - $profile_name"$'\n'
  md_lines+="Exported: $(date +"%Y-%m-%d %H:%M")"$'\n\n'

  for ledger_file in "$ledgers_dir"/*.journal; do
    [[ -f "$ledger_file" ]] || continue
    local ledger_name
    ledger_name=$(basename "$ledger_file" .journal)
    md_lines+="## $ledger_name"$'\n\n'

    if command -v hledger &>/dev/null; then
      md_lines+="### Balance"$'\n\n```\n'
      md_lines+=$(hledger -f "$ledger_file" balance 2>/dev/null)
      md_lines+=$'\n```\n\n### Recent Transactions\n\n```\n'
      md_lines+=$(hledger -f "$ledger_file" register -n 10 2>/dev/null)
      md_lines+=$'\n```\n\n'
    else
      md_lines+="(hledger not installed)"$'\n\n'
    fi
  done

  if [[ -n "$output_file" ]]; then
    echo "$md_lines" > "$output_file"
    echo "$output_file"
  else
    echo "$md_lines"
  fi
}

# ============================================================================
# COMBINED EXPORTS
# ============================================================================

export_all_json() {
  local profile_dir="$1"
  local output_file="$2"

  local profile_name
  profile_name=$(basename "$profile_dir")

  local tmp_tasks tmp_time tmp_journal tmp_ledger
  tmp_tasks=$(mktemp)
  tmp_time=$(mktemp)
  tmp_journal=$(mktemp)
  tmp_ledger=$(mktemp)

  export_tasks_json "$profile_dir" "$tmp_tasks" >/dev/null
  export_time_json "$profile_dir" "$tmp_time" >/dev/null
  export_journal_json "$profile_dir" "$tmp_journal" >/dev/null
  export_ledger_json "$profile_dir" "$tmp_ledger" >/dev/null

  local combined
  combined=$(python3 - "$profile_name" "$tmp_tasks" "$tmp_time" "$tmp_journal" "$tmp_ledger" << 'PY'
import json, sys
from datetime import datetime

profile = sys.argv[1]
files = sys.argv[2:]
parts = []
for f in files:
    try:
        d = json.load(open(f))
        parts.append(d.get("data", []))
    except Exception:
        parts.append([])

keys = ["tasks", "time", "journal", "ledger"]
result = {
    "profile": profile,
    "exported": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
    "type": "all",
    "data": {k: v for k, v in zip(keys, parts)}
}
print(json.dumps(result, indent=2))
PY
)

  rm -f "$tmp_tasks" "$tmp_time" "$tmp_journal" "$tmp_ledger"

  if [[ -n "$output_file" ]]; then
    echo "$combined" > "$output_file"
    echo "$output_file"
  else
    echo "$combined"
  fi
}


# ============================================================================
# HTML EXPORTS
# ============================================================================

_html_common_head() {
  local title="$1"
  cat << HEREDOC
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0d0f14;--surface:#13151c;--surface2:#1a1d26;--border:#252836;
  --border2:#1e2030;--text:#d4d8e8;--muted:#666880;--accent:#5b8dee;
  --accent2:#4a9eff;--green:#4ec994;--red:#e05c6a;--yellow:#e8b84b;
  --mono:'SF Mono',Menlo,monospace;
}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  background:var(--bg);color:var(--text);font-size:13px;line-height:1.6;
  height:100vh;overflow:hidden;display:flex;flex-direction:column}
a{color:var(--accent2)}
/* ── layout ────────────────────────────────────────────────────────────── */
.x-header{padding:12px 20px;border-bottom:1px solid var(--border);
  background:var(--surface);display:flex;align-items:center;gap:10px;
  position:sticky;top:0;z-index:100}
.x-ww{font-weight:700;font-size:14px;letter-spacing:-.5px;color:var(--accent2)}
.x-full{color:var(--muted);font-size:11px;letter-spacing:.02em}
.x-meta{margin-left:auto;color:var(--muted);font-size:11px;display:flex;align-items:center;gap:12px}
.x-body{display:flex;flex:1;min-height:0;overflow:hidden}
.x-main{flex:1;min-width:0;overflow-y:auto;padding:20px 24px}
.x-notes{width:300px;flex-shrink:0;border-left:1px solid var(--border);
  display:flex;flex-direction:column;background:var(--surface);
  min-height:0;overflow:hidden}
/* ── section ───────────────────────────────────────────────────────────── */
.sec{margin-bottom:28px}
.sec-hdr{display:flex;align-items:center;gap:6px;margin-bottom:10px;
  padding-bottom:6px;border-bottom:1px solid var(--border)}
.sec-hdr h2{font-size:10px;color:var(--muted);text-transform:uppercase;
  letter-spacing:.1em;font-weight:600;flex:1}
/* ── toggle buttons ────────────────────────────────────────────────────── */
.tbtn{font-size:11px;padding:2px 9px;border:1px solid var(--border);
  background:transparent;color:var(--muted);cursor:pointer;border-radius:3px;
  transition:all .12s;user-select:none}
.tbtn:hover{border-color:var(--accent2);color:var(--accent2)}
.tbtn.on{background:var(--accent);color:#fff;border-color:var(--accent)}
/* ── table ─────────────────────────────────────────────────────────────── */
.tbl{width:100%;border-collapse:collapse;font-size:12px}
.tbl th{text-align:left;color:var(--muted);padding:5px 10px;
  border-bottom:1px solid var(--border);font-weight:500;font-size:11px;
  text-transform:uppercase;letter-spacing:.04em}
.tbl td{padding:6px 10px;border-bottom:1px solid var(--border2)}
.tbl tbody tr{cursor:pointer;transition:background .1s}
.tbl tbody tr:hover td{background:var(--surface2)}
.tbl tbody tr.expanded td{background:var(--surface2)}
/* ── task detail inline ────────────────────────────────────────────────── */
.task-detail-row td{padding:0;background:var(--surface2)!important;cursor:default}
.task-detail-row.hidden{display:none}
.td-inner{padding:10px 14px 12px;display:flex;flex-wrap:wrap;gap:6px 0;border-bottom:1px solid var(--border)}
.td-fields{display:flex;flex-wrap:wrap;gap:4px 20px;width:100%;margin-bottom:4px}
.tf{display:flex;align-items:baseline;gap:4px;font-size:11px}
.tk{color:var(--muted)}
.tv{color:var(--text)}
.uuid-val{font-family:var(--mono);font-size:10px;opacity:.45}
.uda-block{width:100%;display:flex;flex-wrap:wrap;gap:4px 20px;
  padding:6px 0 0;border-top:1px solid var(--border2);margin-top:4px}
.uda-tf .tk{color:var(--accent);opacity:.7}
.ann-block{width:100%;padding:6px 0 0;border-top:1px solid var(--border2);margin-top:4px}
.ann-block.hidden{display:none}
.ann-row{display:flex;gap:8px;font-size:11px;padding:2px 0}
.ann-ts{color:var(--muted);min-width:82px;flex-shrink:0;font-family:var(--mono);font-size:10px}
.ann-body{color:var(--text);white-space:pre-wrap}
/* status badges */
.sb{font-size:10px;padding:1px 6px;border-radius:2px;font-weight:500}
.sb-pending{background:rgba(91,141,238,.15);color:#5b8dee}
.sb-completed{background:rgba(78,201,148,.15);color:var(--green)}
.sb-deleted{background:rgba(224,92,106,.15);color:var(--red)}
/* priority */
.pri-H{color:var(--red);font-weight:600}
.pri-M{color:var(--yellow)}
.pri-L{color:var(--muted)}
/* ── journal ───────────────────────────────────────────────────────────── */
.je{padding:12px 0;border-bottom:1px solid var(--border2)}
.je-meta{display:flex;align-items:baseline;gap:8px;margin-bottom:4px}
.je-journal{font-size:10px;color:var(--accent);text-transform:uppercase;
  letter-spacing:.06em;font-weight:600}
.je-ts{font-size:11px;color:var(--muted);font-family:var(--mono)}
.je-title{font-size:13px;font-weight:500;margin-bottom:4px;color:var(--text)}
.je-body{font-size:12px;color:#b0b4c8;line-height:1.65}
.je-body h1,.je-body h2,.je-body h3{margin:.5em 0 .25em;color:var(--text)}
.je-body h1{font-size:14px}.je-body h2{font-size:13px}.je-body h3{font-size:12px}
.je-body strong{color:var(--text);font-weight:600}
.je-body em{font-style:italic;color:#c0c4d8}
.je-body code{font-family:var(--mono);font-size:11px;background:var(--surface2);
  padding:1px 4px;border-radius:2px;color:var(--accent2)}
.je-body pre{background:var(--surface2);border:1px solid var(--border);
  border-radius:3px;padding:8px 12px;font-size:11px;overflow-x:auto;
  font-family:var(--mono);margin:.5em 0}
.je-body ul,.je-body ol{padding-left:1.5em;margin:.25em 0}
.je-body li{margin:.1em 0}
.je-body p{margin:.35em 0}
.je-body blockquote{border-left:3px solid var(--border);padding-left:10px;
  color:var(--muted);margin:.5em 0}
/* ── time ──────────────────────────────────────────────────────────────── */
pre.summary{background:var(--surface2);border:1px solid var(--border);
  border-radius:3px;padding:10px 14px;font-size:11px;font-family:var(--mono);
  color:#b0b4c8;overflow-x:auto;margin-bottom:12px}
/* ── ledger ────────────────────────────────────────────────────────────── */
.ledger-blk{margin-bottom:20px}
.ledger-name{font-size:10px;color:var(--muted);text-transform:uppercase;
  letter-spacing:.08em;margin-bottom:6px;font-weight:600}
.ledger-lbl{font-size:11px;color:var(--muted);margin:8px 0 4px}
pre.ledger{background:var(--surface2);border:1px solid var(--border);
  border-radius:3px;padding:8px 12px;font-size:11px;font-family:var(--mono);
  color:#b0b4c8;overflow-x:auto}
/* ── panel tabs ─────────────────────────────────────────────────────────── */
.panel-tabs{display:flex;border-bottom:1px solid var(--border);flex-shrink:0}
.panel-tab{flex:1;padding:9px 4px;font-size:10px;text-transform:uppercase;
  letter-spacing:.08em;color:var(--muted);background:none;border:none;
  cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;
  transition:all .12s;font-weight:500}
.panel-tab.on{color:var(--accent2);border-bottom-color:var(--accent2)}
.panel-pane{display:flex;flex-direction:column;flex:1;min-height:0;overflow:hidden}
/* ── notes panel ───────────────────────────────────────────────────────── */
.notes-input-wrap{padding:10px 12px;border-bottom:1px solid var(--border);flex-shrink:0}
#note-input{width:100%;min-height:80px;background:var(--surface2);
  border:1px solid var(--border);border-radius:3px;color:var(--text);
  font-size:12px;padding:8px;resize:vertical;font-family:inherit;line-height:1.5}
#note-input:focus{outline:none;border-color:var(--accent)}
.notes-actions{display:flex;gap:6px;margin-top:6px}
.note-add-btn{flex:1;padding:5px 0;background:var(--accent);color:#fff;
  border:none;border-radius:3px;cursor:pointer;font-size:12px;font-weight:500;
  transition:opacity .12s}
.note-add-btn:hover{opacity:.85}
.notes-footer{display:flex;gap:5px;padding:8px 12px;border-top:1px solid var(--border);
  flex-shrink:0}
.notes-tool-btn{flex:1;padding:5px 4px;background:transparent;
  border:1px solid var(--border);color:var(--muted);border-radius:3px;
  cursor:pointer;font-size:10px;transition:all .12s;white-space:nowrap}
.notes-tool-btn:hover{border-color:var(--accent2);color:var(--accent2)}
.notes-tool-btn.copied{border-color:var(--accent);color:var(--accent)}
.notes-list{flex:1;overflow-y:auto;padding:8px 0;min-height:0}
.note-item{padding:8px 12px;border-bottom:1px solid var(--border2)}
.note-item-ts{font-size:10px;color:var(--muted);font-family:var(--mono);margin-bottom:3px}
.note-item-body{font-size:12px;color:var(--text);white-space:pre-wrap;line-height:1.5}
.note-item-del{float:right;font-size:10px;color:var(--muted);cursor:pointer;
  border:none;background:none;padding:0;opacity:.5}
.note-item-del:hover{opacity:1;color:var(--red)}
.notes-empty{padding:16px 12px;color:var(--muted);font-size:11px;text-align:center}
/* ── new task form ──────────────────────────────────────────────────────── */
.nt-form{padding:10px 12px;border-bottom:1px solid var(--border);
  display:flex;flex-direction:column;gap:6px;overflow-y:auto;
  max-height:55vh;flex-shrink:0}
.nt-input{width:100%;background:var(--surface2);border:1px solid var(--border);
  border-radius:3px;color:var(--text);font-size:12px;padding:5px 8px;
  font-family:inherit;transition:border-color .12s}
.nt-input:focus{outline:none;border-color:var(--accent)}
.nt-label{font-size:10px;color:var(--muted);margin-bottom:2px;font-weight:500}
.nt-row{display:flex;gap:6px}
.nt-col{display:flex;flex-direction:column;flex:1;min-width:0}
/* priority buttons */
.pri-btns{display:flex;gap:3px}
.pri-btn{flex:1;padding:4px 0;font-size:11px;font-weight:600;
  border:1px solid var(--border);background:transparent;color:var(--muted);
  border-radius:3px;cursor:pointer;transition:all .12s}
.pri-btn:hover{color:var(--text)}
.pri-btn.on.H{background:#e05c6a22;color:#e05c6a;border-color:#e05c6a}
.pri-btn.on.M{background:#e8b84b22;color:#e8b84b;border-color:#e8b84b}
.pri-btn.on.L{background:#4ec99422;color:#4ec994;border-color:#4ec994}
/* tag chips */
.tag-chips{display:flex;flex-wrap:wrap;gap:3px;min-height:20px}
.tag-chip{font-size:10px;padding:2px 7px;background:var(--accent)22;
  color:var(--accent2);border:1px solid var(--accent)44;border-radius:10px;
  display:flex;align-items:center;gap:3px}
.tag-chip-del{cursor:pointer;opacity:.6;font-size:9px;border:none;
  background:none;color:inherit;padding:0;line-height:1}
.tag-chip-del:hover{opacity:1}
.tag-sugg-wrap{position:relative}
.tag-sugg{position:absolute;top:100%;left:0;right:0;background:var(--surface);
  border:1px solid var(--border);border-radius:3px;z-index:200;
  max-height:110px;overflow-y:auto;display:none;margin-top:2px}
.tag-sugg-item{padding:5px 8px;font-size:11px;cursor:pointer;color:var(--text)}
.tag-sugg-item:hover{background:var(--surface2)}
/* uda collapsible */
.nt-more-btn{font-size:10px;color:var(--muted);cursor:pointer;background:none;
  border:none;padding:2px 0;text-align:left;width:100%;transition:color .12s}
.nt-more-btn:hover{color:var(--accent2)}
.nt-udas{display:none;flex-direction:column;gap:5px}
.nt-udas.open{display:flex}
/* edit indicator bar */
.nt-edit-bar{display:none;align-items:center;gap:6px;padding:5px 12px;
  background:var(--accent)18;border-bottom:2px solid var(--accent);
  font-size:10px;color:var(--accent2);flex-shrink:0}
.nt-edit-bar.visible{display:flex}
.nt-edit-bar span{flex:1}
.nt-cancel-btn{font-size:10px;color:var(--muted);cursor:pointer;background:none;
  border:none;padding:0;text-decoration:underline;text-underline-offset:2px}
.nt-cancel-btn:hover{color:var(--red)}
/* add/update button */
.nt-add-btn{padding:7px 0;background:var(--accent);color:#fff;border:none;
  border-radius:3px;cursor:pointer;font-size:12px;font-weight:500;
  transition:all .12s;flex-shrink:0}
.nt-add-btn:hover{opacity:.85}
.nt-add-btn.updating{background:var(--accent2)}
/* pending task list */
.nt-list{flex:1;overflow-y:auto;padding:4px 0;min-height:0}
.nt-item{padding:8px 12px;border-bottom:1px solid var(--border2);position:relative}
.nt-item.editing{background:var(--accent)0d;border-left:2px solid var(--accent)}
.nt-item-actions{position:absolute;top:7px;right:7px;display:flex;gap:4px;align-items:center}
.nt-item-edit{font-size:10px;color:var(--accent2);cursor:pointer;
  border:1px solid var(--accent2)44;background:none;padding:2px 7px;
  border-radius:3px;opacity:.7;transition:all .12s;line-height:1.4}
.nt-item-edit:hover{opacity:1;background:var(--accent2)18;border-color:var(--accent2)}
.nt-item-del{font-size:11px;color:var(--red);cursor:pointer;font-weight:700;
  border:1px solid var(--red)55;background:none;padding:2px 6px;
  border-radius:3px;opacity:.65;transition:all .12s;line-height:1.4}
.nt-item-del:hover{opacity:1;background:var(--red)18;border-color:var(--red)}
.nt-item-desc{font-size:12px;color:var(--text);margin-bottom:4px;
  padding-right:80px;line-height:1.4;font-weight:500}
.nt-item-meta{font-size:10px;color:var(--muted);display:flex;flex-wrap:wrap;
  gap:3px;align-items:center}
.nt-item-tag{background:var(--surface2);border:1px solid var(--border);
  padding:1px 5px;border-radius:8px;color:var(--muted)}
.nt-item-proj{color:var(--accent2)}
.nt-item-pri-H{color:#e05c6a;font-weight:700}
.nt-item-pri-M{color:#e8b84b;font-weight:700}
.nt-item-pri-L{color:#4ec994;font-weight:700}
.nt-item-due{color:var(--yellow)}
.nt-empty{padding:24px 12px;color:var(--muted);font-size:11px;text-align:center;
  line-height:1.8}
</style>
</head>
HEREDOC
}

_html_scripts() {
  cat << 'JSEOF'
<script>
// ── markdown renderer ──────────────────────────────────────────────────────
function md(s){
  if(!s) return '';
  const lines=s.split('\n');
  let out=[],inPre=false,inUl=false,inOl=false;
  const flush=()=>{if(inUl){out.push('</ul>');inUl=false;}if(inOl){out.push('</ol>');inOl=false;}};
  const inline=t=>t
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>')
    .replace(/__(.+?)__/g,'<strong>$1</strong>')
    .replace(/\*(.+?)\*/g,'<em>$1</em>')
    .replace(/_(.+?)_/g,'<em>$1</em>')
    .replace(/`([^`]+)`/g,'<code>$1</code>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g,'<a href="$2">$1</a>');
  for(let i=0;i<lines.length;i++){
    let l=lines[i];
    if(l.startsWith('```')){
      if(inPre){out.push('</code></pre>');inPre=false;}
      else{flush();out.push('<pre><code>');inPre=true;}
      continue;
    }
    if(inPre){out.push(l.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')+'\n');continue;}
    if(/^#{3} /.test(l)){flush();out.push('<h3>'+inline(l.slice(4))+'</h3>');continue;}
    if(/^#{2} /.test(l)){flush();out.push('<h2>'+inline(l.slice(3))+'</h2>');continue;}
    if(/^# /.test(l)){flush();out.push('<h1>'+inline(l.slice(2))+'</h1>');continue;}
    if(/^> /.test(l)){flush();out.push('<blockquote>'+inline(l.slice(2))+'</blockquote>');continue;}
    if(/^- /.test(l)||/^\* /.test(l)){if(!inUl){if(inOl){out.push('</ol>');inOl=false;}out.push('<ul>');inUl=true;}out.push('<li>'+inline(l.slice(2))+'</li>');continue;}
    if(/^\d+\. /.test(l)){if(!inOl){if(inUl){out.push('</ul>');inUl=false;}out.push('<ol>');inOl=true;}out.push('<li>'+inline(l.replace(/^\d+\. /,''))+'</li>');continue;}
    flush();
    if(l.trim()===''){out.push('<p style="margin:.3em 0"></p>');}
    else{out.push('<p>'+inline(l)+'</p>');}
  }
  flush();
  return out.join('');
}

// ── task detail toggle ─────────────────────────────────────────────────────
let allExpanded=false,annVisible=false;
function toggleTaskRow(uuid){
  const dr=document.getElementById('td-'+uuid);
  const hr=document.getElementById('tr-'+uuid);
  if(!dr||!hr) return;
  const open=dr.classList.toggle('hidden');
  hr.classList.toggle('expanded',!open);
}
function toggleAll(){
  allExpanded=!allExpanded;
  document.getElementById('btn-detail').classList.toggle('on',allExpanded);
  document.getElementById('btn-ann').style.display=allExpanded?'':'none';
  document.querySelectorAll('.task-detail-row').forEach(r=>{
    r.classList.toggle('hidden',!allExpanded);
  });
  document.querySelectorAll('.tbl tbody tr.task-row').forEach(r=>{
    r.classList.toggle('expanded',allExpanded);
  });
  if(!allExpanded){annVisible=false;applyAnn();document.getElementById('btn-ann')?.classList.remove('on');}
}
function toggleAnn(){
  annVisible=!annVisible;
  document.getElementById('btn-ann').classList.toggle('on',annVisible);
  applyAnn();
}
function applyAnn(){
  document.querySelectorAll('.ann-block').forEach(b=>{
    b.classList.toggle('hidden',!annVisible);
  });
}

// ── notes ──────────────────────────────────────────────────────────────────
const PROFILE=document.querySelector('meta[name=ww-profile]')?.content||'export';
const NOTES_KEY='ww-notes-'+PROFILE;
let notes=[];
try{const raw=document.getElementById('ww-notes-data')?.textContent;
  notes=raw?JSON.parse(raw):[];}catch(e){}
try{const ls=JSON.parse(localStorage.getItem(NOTES_KEY)||'null');
  if(ls&&ls.length>=notes.length) notes=ls;}catch(e){}

function renderNotes(){
  const el=document.getElementById('notes-list');
  if(!el) return;
  if(!notes.length){el.innerHTML='<div class="notes-empty">No notes yet.</div>';return;}
  el.innerHTML=notes.slice().reverse().map((n,ri)=>{
    const i=notes.length-1-ri;
    const d=new Date(n.ts);
    const ts=d.toLocaleDateString()+' '+d.toLocaleTimeString(undefined,{hour:'2-digit',minute:'2-digit'});
    return `<div class="note-item"><button class="note-item-del" onclick="deleteNote(${i})" title="delete">✕</button><div class="note-item-ts">${ts}</div><div class="note-item-body">${n.text.replace(/&/g,'&amp;').replace(/</g,'&lt;')}</div></div>`;
  }).join('');
}
function saveNote(){
  const inp=document.getElementById('note-input');
  const text=inp.value.trim();
  if(!text) return;
  notes.push({ts:new Date().toISOString(),text});
  localStorage.setItem(NOTES_KEY,JSON.stringify(notes));
  renderNotes();
  inp.value='';
}
function deleteNote(i){
  notes.splice(i,1);
  localStorage.setItem(NOTES_KEY,JSON.stringify(notes));
  renderNotes();
}
function downloadWithNotes(){
  const nd=document.getElementById('ww-notes-data');
  if(nd) nd.textContent=JSON.stringify(notes);
  const ntd=document.getElementById('ww-new-tasks-data');
  if(ntd) ntd.textContent=JSON.stringify(newTasks);
  const html='<!DOCTYPE html>'+document.documentElement.outerHTML;
  const blob=new Blob([html],{type:'text/html'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url;a.download=document.title.replace(/[^a-z0-9-]/gi,'_')+'.html';
  document.body.appendChild(a);a.click();
  document.body.removeChild(a);URL.revokeObjectURL(url);
}
function saveNotesOnly(){
  if(!notes.length){alert('No notes to save.');return;}
  const lines=notes.slice().reverse().map(n=>{
    const d=new Date(n.ts);
    const ts=d.toLocaleDateString()+' '+d.toLocaleTimeString(undefined,{hour:'2-digit',minute:'2-digit'});
    return ts+'\n'+n.text;
  }).join('\n\n---\n\n');
  const blob=new Blob([lines],{type:'text/plain'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url;a.download=(document.title.replace(/[^a-z0-9-]/gi,'_')||'notes')+'_notes.txt';
  document.body.appendChild(a);a.click();
  document.body.removeChild(a);URL.revokeObjectURL(url);
}
function copyAllNotes(){
  if(!notes.length){alert('No notes to copy.');return;}
  const lines=notes.slice().reverse().map(n=>{
    const d=new Date(n.ts);
    const ts=d.toLocaleDateString()+' '+d.toLocaleTimeString(undefined,{hour:'2-digit',minute:'2-digit'});
    return ts+'\n'+n.text;
  }).join('\n\n---\n\n');
  navigator.clipboard.writeText(lines).then(()=>{
    const btn=document.getElementById('btn-copy-notes');
    if(btn){btn.textContent='copied!';btn.classList.add('copied');
      setTimeout(()=>{btn.textContent='copy all';btn.classList.remove('copied');},1800);}
  });
}

// ── tab switching ──────────────────────────────────────────────────────────
function switchTab(name){
  document.querySelectorAll('.panel-tab').forEach(b=>b.classList.toggle('on',b.dataset.tab===name));
  document.querySelectorAll('.panel-pane').forEach(p=>{p.style.display=p.id==='pane-'+name?'flex':'none';});
}

// ── new tasks ──────────────────────────────────────────────────────────────
const NT_KEY='ww-new-tasks-'+PROFILE;
let newTasks=[];
try{const raw=document.getElementById('ww-new-tasks-data')?.textContent;
  newTasks=raw?JSON.parse(raw):[];}catch(e){}
try{const ls=JSON.parse(localStorage.getItem(NT_KEY)||'null');
  if(ls&&ls.length>=newTasks.length) newTasks=ls;}catch(e){}

let _ntMeta={projects:[],tags:[],udas:[]};
try{_ntMeta=JSON.parse(document.getElementById('ww-task-meta')?.textContent||'{}');}catch(e){}

let _ntTags=[];
let _ntPri='';
let _ntEditIdx=-1;

function escH(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}

function switchPri(v){
  _ntPri=_ntPri===v?'':v;
  document.querySelectorAll('.pri-btn').forEach(b=>b.classList.toggle('on',b.dataset.pri===_ntPri));
}

function ntTagAdd(v){
  v=v.trim().replace(/^\+/,'');
  if(!v||_ntTags.includes(v)) return;
  _ntTags.push(v);
  renderChips();
  const inp=document.getElementById('nt-tag-input');
  if(inp) inp.value='';
  ntSuggest('');
}
function ntTagRemove(v){
  _ntTags=_ntTags.filter(t=>t!==v);
  renderChips();
}
function renderChips(){
  const el=document.getElementById('nt-chips');
  if(!el) return;
  el.innerHTML=_ntTags.map(t=>
    `<span class="tag-chip">${escH(t)}<button class="tag-chip-del" type="button" onclick="ntTagRemove('${escH(t)}')">✕</button></span>`
  ).join('');
}
function ntTagKey(e){
  if(e.key==='Enter'||e.key===','||e.key===' '){e.preventDefault();ntTagAdd(e.target.value);}
  else if(e.key==='Backspace'&&!e.target.value&&_ntTags.length){ntTagRemove(_ntTags[_ntTags.length-1]);}
  else ntSuggest(e.target.value);
}
function ntSuggest(q){
  const el=document.getElementById('nt-tag-sugg');
  if(!el) return;
  const all=(_ntMeta.tags||[]).filter(t=>!_ntTags.includes(t)&&(!q||t.toLowerCase().includes(q.toLowerCase()))).slice(0,10);
  if(!all.length){el.style.display='none';return;}
  el.style.display='block';
  el.innerHTML=all.map(t=>`<div class="tag-sugg-item" onmousedown="ntTagAdd('${escH(t)}')">${escH(t)}</div>`).join('');
}
function ntToggleMore(){
  const el=document.getElementById('nt-udas');
  const btn=document.getElementById('nt-more-btn');
  if(!el) return;
  el.classList.toggle('open');
  if(btn) btn.textContent=el.classList.contains('open')?'▾ fewer fields':'▸ more fields';
}

function _ntResetForm(){
  document.getElementById('nt-desc').value='';
  document.getElementById('nt-project').value='';
  document.getElementById('nt-due').value='';
  const noteEl=document.getElementById('nt-note');if(noteEl) noteEl.value='';
  document.querySelectorAll('.nt-uda-input').forEach(inp=>inp.value='');
  _ntTags=[];_ntPri='';_ntEditIdx=-1;
  renderChips();
  document.querySelectorAll('.pri-btn').forEach(b=>b.classList.remove('on'));
  ntSuggest('');
  const btn=document.getElementById('nt-add-btn');
  if(btn){btn.textContent='Add Task';btn.classList.remove('updating');}
  const bar=document.getElementById('nt-edit-bar');
  if(bar) bar.classList.remove('visible');
}
function cancelEdit(){_ntResetForm();renderNewTasks();}
function editNewTask(i){
  const t=newTasks[i];
  if(!t) return;
  _ntEditIdx=i;
  document.getElementById('nt-desc').value=t.description||'';
  document.getElementById('nt-project').value=t.project||'';
  document.getElementById('nt-due').value=t.due&&t.due.includes('-')?t.due:(t.due?t.due.slice(0,4)+'-'+t.due.slice(4,6)+'-'+t.due.slice(6,8):'');
  const noteEl=document.getElementById('nt-note');
  if(noteEl) noteEl.value=t.annotations?.[0]?.description||'';
  _ntTags=[...(t.tags||[])];
  _ntPri=t.priority||'';
  renderChips();
  document.querySelectorAll('.pri-btn').forEach(b=>b.classList.toggle('on',b.dataset.pri===_ntPri));
  document.querySelectorAll('.nt-uda-input').forEach(inp=>{inp.value=t[inp.dataset.uda]||'';});
  const btn=document.getElementById('nt-add-btn');
  if(btn){btn.textContent='Update Task';btn.classList.add('updating');}
  const bar=document.getElementById('nt-edit-bar');
  if(bar) bar.classList.add('visible');
  document.getElementById('nt-form')?.scrollIntoView({behavior:'smooth',block:'start'});
  document.getElementById('nt-desc')?.focus();
  renderNewTasks();
}
function addNewTask(){
  const desc=document.getElementById('nt-desc')?.value.trim();
  if(!desc){document.getElementById('nt-desc')?.focus();return;}
  const proj=document.getElementById('nt-project')?.value.trim()||'';
  const due=document.getElementById('nt-due')?.value||'';
  const note=document.getElementById('nt-note')?.value.trim()||'';
  const ts=new Date().toISOString();
  const udaVals={};
  document.querySelectorAll('.nt-uda-input').forEach(inp=>{if(inp.value.trim()) udaVals[inp.dataset.uda]=inp.value.trim();});
  const base=_ntEditIdx>=0?{...newTasks[_ntEditIdx]}:{uuid:'pending',status:'pending',entry:ts};
  const task={...base,description:desc,
    ...(proj?{project:proj}:{project:undefined}),
    ...(_ntTags.length?{tags:[..._ntTags]}:{tags:undefined}),
    ...(_ntPri?{priority:_ntPri}:{priority:undefined}),
    ...(due?{due:due}:{due:undefined}),
    ...(note?{annotations:[{entry:base.entry||ts,description:note}]}:{annotations:undefined}),
    ...udaVals};
  // remove undefined keys
  Object.keys(task).forEach(k=>task[k]===undefined&&delete task[k]);
  if(_ntEditIdx>=0) newTasks[_ntEditIdx]=task;
  else newTasks.push(task);
  localStorage.setItem(NT_KEY,JSON.stringify(newTasks));
  _ntResetForm();
  renderNewTasks();
}
function deleteNewTask(i){
  const t=newTasks[i];
  if(!confirm('Delete this task?\n\n"'+t.description+'"')) return;
  if(_ntEditIdx===i) _ntResetForm();
  else if(_ntEditIdx>i) _ntEditIdx--;
  newTasks.splice(i,1);
  localStorage.setItem(NT_KEY,JSON.stringify(newTasks));
  renderNewTasks();
}
function renderNewTasks(){
  const el=document.getElementById('nt-list');
  const cnt=document.getElementById('nt-count');
  if(!el) return;
  if(cnt) cnt.textContent=newTasks.length?String(newTasks.length):'';
  if(!newTasks.length){
    el.innerHTML='<div class="nt-empty">No pending tasks yet.<br>Use the form above to add tasks<br>and export them as JSON.</div>';
    return;
  }
  el.innerHTML=newTasks.slice().reverse().map((t,ri)=>{
    const i=newTasks.length-1-ri;
    const isEditing=_ntEditIdx===i;
    const tags=(t.tags||[]).map(tg=>`<span class="nt-item-tag">+${escH(tg)}</span>`).join('');
    const pri=t.priority?`<span class="nt-item-pri-${t.priority}">${t.priority}</span>`:'';
    const proj=t.project?`<span class="nt-item-proj">${escH(t.project)}</span>`:'';
    const due=t.due?`<span class="nt-item-due">due ${escH(t.due)}</span>`:'';
    const ann=t.annotations?.length?`<span style="color:var(--muted)">↩ note</span>`:'';
    return `<div class="nt-item${isEditing?' editing':''}">
      <div class="nt-item-actions">
        <button class="nt-item-edit" onclick="editNewTask(${i})">edit</button>
        <button class="nt-item-del" onclick="deleteNewTask(${i})">✕</button>
      </div>
      <div class="nt-item-desc">${escH(t.description)}</div>
      <div class="nt-item-meta">${pri}${proj}${tags}${due}${ann}</div>
    </div>`;
  }).join('');
}

function toTwDate(s){
  // "2026-06-04" → "20260604T000000Z"
  return s.replace(/-/g,'')+'T000000Z';
}
function buildTwJSON(){
  return newTasks.map((t,i)=>{
    const out={...t,uuid:`pending-${i+1}`,
      entry:new Date(t.entry).toISOString().replace(/[-:.]/g,'').slice(0,15)+'Z'};
    if(out.due&&out.due.includes('-')) out.due=toTwDate(out.due);
    return out;
  });
}
function exportNewTasksJSON(){
  if(!newTasks.length){alert('No pending tasks to export.');return;}
  const blob=new Blob([JSON.stringify(buildTwJSON(),null,2)],{type:'application/json'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url;a.download=(document.title.replace(/[^a-z0-9-]/gi,'_')||'tasks')+'_pending.json';
  document.body.appendChild(a);a.click();
  document.body.removeChild(a);URL.revokeObjectURL(url);
}
function copyNewTasksJSON(){
  if(!newTasks.length){alert('No pending tasks to copy.');return;}
  navigator.clipboard.writeText(JSON.stringify(buildTwJSON(),null,2)).then(()=>{
    const btn=document.getElementById('btn-copy-tasks');
    if(btn){btn.textContent='copied!';btn.classList.add('copied');
      setTimeout(()=>{btn.textContent='copy JSON';btn.classList.remove('copied');},1800);}
  });
}

document.addEventListener('DOMContentLoaded',()=>{
  renderNotes();
  renderNewTasks();
  document.querySelectorAll('.je-body').forEach(el=>{el.innerHTML=md(el.dataset.raw||'');});
  document.getElementById('note-input')?.addEventListener('keydown',e=>{
    if(e.key==='Enter'&&(e.metaKey||e.ctrlKey)) saveNote();
  });
  // populate project datalist from meta
  const dl=document.getElementById('nt-project-list');
  if(dl)(_ntMeta.projects||[]).forEach(p=>{const o=document.createElement('option');o.value=p;dl.appendChild(o);});
  // build UDA fields from meta
  const udaWrap=document.getElementById('nt-udas');
  const moreBtn=document.getElementById('nt-more-btn');
  if(udaWrap&&(_ntMeta.udas||[]).length){
    udaWrap.innerHTML=(_ntMeta.udas||[]).map(k=>
      `<div><div class="nt-label">${escH(k)}</div><input class="nt-input nt-uda-input" data-uda="${escH(k)}" placeholder="${escH(k)}" /></div>`
    ).join('');
    if(moreBtn) moreBtn.style.display='';
  } else {
    if(moreBtn) moreBtn.style.display='none';
  }
  // tag input events
  const tagInp=document.getElementById('nt-tag-input');
  tagInp?.addEventListener('focus',()=>ntSuggest(tagInp.value));
  tagInp?.addEventListener('blur',()=>setTimeout(()=>{const s=document.getElementById('nt-tag-sugg');if(s)s.style.display='none';},150));
  // desc enter submits
  document.getElementById('nt-desc')?.addEventListener('keydown',e=>{if(e.key==='Enter'&&(e.metaKey||e.ctrlKey)) addNewTask();});
});
</script>
JSEOF
}

_html_notes_panel() {
  cat << 'PANEL'
<aside class="x-notes">
  <div class="panel-tabs">
    <button class="panel-tab on" data-tab="notes" onclick="switchTab('notes')">Notes</button>
    <button class="panel-tab" data-tab="tasks" onclick="switchTab('tasks')">New Tasks<span id="nt-count" style="margin-left:4px;opacity:.55;font-size:9px"></span></button>
  </div>

  <!-- notes pane -->
  <div id="pane-notes" class="panel-pane">
    <div class="notes-input-wrap">
      <textarea id="note-input" placeholder="Add a note… (⌘↵ to save)"></textarea>
      <div class="notes-actions">
        <button class="note-add-btn" onclick="saveNote()">Add note</button>
      </div>
    </div>
    <div class="notes-list" id="notes-list"></div>
    <div class="notes-footer">
      <button class="notes-tool-btn" onclick="saveNotesOnly()" title="Download notes as plain text">save notes</button>
      <button class="notes-tool-btn" id="btn-copy-notes" onclick="copyAllNotes()" title="Copy all notes to clipboard">copy all</button>
      <button class="notes-tool-btn" onclick="downloadWithNotes()" title="Save this page with notes and tasks embedded">save page</button>
    </div>
  </div>

  <!-- new tasks pane -->
  <div id="pane-tasks" class="panel-pane" style="display:none">
    <div id="nt-edit-bar" class="nt-edit-bar">
      <span>Editing task</span>
      <button class="nt-cancel-btn" type="button" onclick="cancelEdit()">cancel</button>
    </div>
    <div id="nt-form" class="nt-form">
      <div>
        <div class="nt-label">Description *</div>
        <input class="nt-input" id="nt-desc" type="text" placeholder="What needs doing?" autocomplete="off" />
      </div>
      <div>
        <div class="nt-label">Project</div>
        <input class="nt-input" id="nt-project" type="text" list="nt-project-list" placeholder="project name" autocomplete="off" />
        <datalist id="nt-project-list"></datalist>
      </div>
      <div>
        <div class="nt-label">Tags</div>
        <div id="nt-chips" class="tag-chips" style="margin-bottom:4px"></div>
        <div class="tag-sugg-wrap">
          <input class="nt-input" id="nt-tag-input" type="text" placeholder="type a tag, press Enter or Space…" autocomplete="off"
            onkeydown="ntTagKey(event)" oninput="ntSuggest(this.value)" />
          <div class="tag-sugg" id="nt-tag-sugg"></div>
        </div>
      </div>
      <div class="nt-row">
        <div class="nt-col">
          <div class="nt-label">Priority</div>
          <div class="pri-btns">
            <button class="pri-btn H" data-pri="H" type="button" onclick="switchPri('H')">H</button>
            <button class="pri-btn M" data-pri="M" type="button" onclick="switchPri('M')">M</button>
            <button class="pri-btn L" data-pri="L" type="button" onclick="switchPri('L')">L</button>
          </div>
        </div>
        <div class="nt-col">
          <div class="nt-label">Due date</div>
          <input class="nt-input" type="date" id="nt-due" />
        </div>
      </div>
      <div>
        <div class="nt-label">Note / first annotation</div>
        <input class="nt-input" id="nt-note" type="text" placeholder="Optional annotation…" />
      </div>
      <button id="nt-more-btn" class="nt-more-btn" type="button" onclick="ntToggleMore()" style="display:none">▸ more fields</button>
      <div id="nt-udas" class="nt-udas"></div>
      <button id="nt-add-btn" class="nt-add-btn" type="button" onclick="addNewTask()">Add Task</button>
    </div>
    <div id="nt-list" class="nt-list"></div>
    <div class="notes-footer">
      <button class="notes-tool-btn" onclick="exportNewTasksJSON()" title="Download pending tasks as JSON">export JSON</button>
      <button class="notes-tool-btn" id="btn-copy-tasks" onclick="copyNewTasksJSON()" title="Copy pending tasks JSON to clipboard">copy JSON</button>
    </div>
  </div>
</aside>
<script type="application/json" id="ww-notes-data">[]</script>
<script type="application/json" id="ww-new-tasks-data">[]</script>
PANEL
}

export_tasks_html() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$taskdata" || -z "$_TASK_BIN" ]]; then return 1; fi

  local task_json
  task_json=$(TASKRC="$taskrc" TASKDATA="$taskdata" "$_TASK_BIN" $filter export 2>/dev/null || echo "[]")

  local task_html count
  task_html=$(python3 - "$task_json" << 'PY'
import json, sys, html as _h
from datetime import datetime

STANDARD = {"id","uuid","description","status","project","tags","priority",
            "due","entry","modified","start","end","scheduled","wait","until",
            "recur","mask","imask","parent","urgency","depends","annotations",
            "exported_at","type","profile"}

def esc(s): return _h.escape(str(s or ""))
def fmte(v):
    if not v: return ""
    try: return datetime.utcfromtimestamp(int(v)).strftime("%Y-%m-%d")
    except: return str(v)[:10]

tasks = json.loads(sys.argv[1])
rows = []
for t in tasks:
    status = t.get("status","")
    scls = {"pending":"sb-pending","completed":"sb-completed","deleted":"sb-deleted"}.get(status,"")
    pri = t.get("priority","")
    pcls = {"H":"pri-H","M":"pri-M","L":"pri-L"}.get(pri,"")
    uuid = t.get("uuid","")
    tags = ", ".join(t.get("tags") or [])

    # compact row
    rows.append(
        f'<tr class="task-row" id="tr-{esc(uuid)}" onclick="toggleTaskRow(\'{esc(uuid)}\')">'
        f'<td>{esc(str(t.get("id","")))}</td>'
        f'<td>{esc(t.get("description",""))}</td>'
        f'<td>{esc(t.get("project",""))}</td>'
        f'<td><span class="sb {scls}">{esc(status)}</span></td>'
        f'<td class="{pcls}">{esc(pri)}</td>'
        f'<td>{esc(tags)}</td></tr>'
    )

    # core detail fields
    core = [
        ("due", fmte(t.get("due",""))), ("scheduled", fmte(t.get("scheduled",""))),
        ("wait", fmte(t.get("wait",""))), ("entry", fmte(t.get("entry",""))),
        ("modified", fmte(t.get("modified",""))),
        ("urgency", f'{round(t.get("urgency",0),2)}' if t.get("urgency") else ""),
    ]
    core_html = "".join(
        f'<div class="tf"><span class="tk">{k}</span><span class="tv">{esc(v)}</span></div>'
        for k,v in core if v)
    core_html += f'<div class="tf"><span class="tk">uuid</span><span class="tv uuid-val">{esc(uuid)}</span></div>'

    # UDA fields
    udas = {k:v for k,v in t.items()
            if k not in STANDARD and not k.startswith("tag_") and v not in ("",None,[])}
    uda_html = ""
    if udas:
        inner = "".join(
            f'<div class="tf uda-tf"><span class="tk">{esc(k)}</span><span class="tv">{esc(str(v))}</span></div>'
            for k,v in sorted(udas.items()))
        uda_html = f'<div class="uda-block">{inner}</div>'

    # Annotations — taskwarrior JSON uses annotations:[{entry,description}]
    ann_list = t.get("annotations") or []
    ann_html = ""
    if ann_list:
        inner = "".join(
            f'<div class="ann-row">'
            f'<span class="ann-ts">{esc(fmte(a.get("entry","")) )}</span>'
            f'<span class="ann-body">{esc(a.get("description",""))}</span>'
            f'</div>'
            for a in sorted(ann_list, key=lambda x: x.get("entry",""))
        )
        ann_html = f'<div class="ann-block hidden">{inner}</div>'

    rows.append(
        f'<tr class="task-detail-row hidden" id="td-{esc(uuid)}">'
        f'<td colspan="6"><div class="td-inner">'
        f'<div class="td-fields">{core_html}</div>'
        f'{uda_html}{ann_html}'
        f'</div></td></tr>'
    )

print('\n'.join(rows))
print(f'<!-- count:{len(tasks)} -->')
PY
)
  count=$(echo "$task_html" | grep -o 'count:[0-9]*' | cut -d: -f2)

  # collect meta (projects, tags, UDA keys) for the new-task form
  local task_meta
  task_meta=$(python3 - "$task_json" << 'METAPY'
import json, sys
STANDARD = {"id","uuid","description","status","project","tags","priority",
            "due","entry","modified","start","end","scheduled","wait","until",
            "recur","mask","imask","parent","urgency","depends","annotations",
            "exported_at","type","profile"}
tasks = json.loads(sys.argv[1])
projects = sorted(set(t.get("project","") for t in tasks if t.get("project")))
tags = sorted(set(tag for t in tasks for tag in (t.get("tags") or [])))
udas = sorted(set(k for t in tasks for k in t
               if k not in STANDARD and not k.startswith("tag_") and t[k] not in ("",None,[])))
print(json.dumps({"projects":projects,"tags":tags,"udas":udas}))
METAPY
)

  local head scripts notes_panel
  head=$(_html_common_head "ww tasks — ${profile_name}")
  scripts=$(_html_scripts)
  notes_panel=$(_html_notes_panel)

  local html
  html="${head}
<body>
<meta name='ww-profile' content='${profile_name}'>
<script type='application/json' id='ww-task-meta'>${task_meta}</script>
<div class='x-header'>
  <span class='x-ww'>ww</span>
  <span class='x-full'>workwarrior · tasks</span>
  <div class='x-meta'>
    <span>${profile_name}</span>
    <span>$(date +"%Y-%m-%d %H:%M")</span>
  </div>
</div>
<div class='x-body'>
<div class='x-main'>
<div class='sec'>
  <div class='sec-hdr'>
    <h2>Tasks (${count:-0})</h2>
    <button class='tbtn' id='btn-detail' onclick='toggleAll()'>expand all</button>
    <button class='tbtn' id='btn-ann' onclick='toggleAnn()' style='display:none'>annotations</button>
  </div>
  <table class='tbl'>
    <thead><tr><th>#</th><th>Description</th><th>Project</th><th>Status</th><th>Pri</th><th>Tags</th></tr></thead>
    <tbody>${task_html}</tbody>
  </table>
</div>
</div>
${notes_panel}
</div>
${scripts}
</body></html>"

  if [[ -n "$output_file" ]]; then
    echo "$html" > "$output_file"
    echo "$output_file"
  else
    echo "$html"
  fi
}

export_time_html() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local timedb="$profile_dir/.timewarrior"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$timedb" ]] || ! command -v timew &>/dev/null; then return 1; fi

  local summary_text time_json
  summary_text=$(TIMEWARRIORDB="$timedb" timew summary $filter 2>/dev/null || echo "(no data)")
  time_json=$(TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null || echo "[]")

  local table_rows count
  table_rows=$(python3 - "$time_json" << 'PY'
import json, sys, html as _h
from datetime import datetime
def fmt(s):
    if not s: return ""
    try: return datetime.strptime(s,"%Y%m%dT%H%M%SZ").strftime("%Y-%m-%d %H:%M")
    except: return s[:16]
data = json.loads(sys.argv[1])
for e in data:
    tags = ", ".join(e.get("tags") or [])
    print(f'<tr><td>{_h.escape(str(e.get("id","")))}</td>'
          f'<td>{_h.escape(fmt(e.get("start","")))}</td>'
          f'<td>{_h.escape(fmt(e.get("end","")))}</td>'
          f'<td>{_h.escape(tags)}</td></tr>')
print(f'<!-- count:{len(data)} -->')
PY
)
  count=$(echo "$table_rows" | grep -o 'count:[0-9]*' | cut -d: -f2)

  local head scripts notes_panel
  head=$(_html_common_head "ww time — ${profile_name}")
  scripts=$(_html_scripts)
  notes_panel=$(_html_notes_panel)

  local sum_esc
  sum_esc=$(echo "$summary_text" | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")

  local html
  html="${head}
<body>
<meta name='ww-profile' content='${profile_name}'>
<div class='x-header'>
  <span class='x-ww'>ww</span><span class='x-full'>workwarrior · time</span>
  <div class='x-meta'><span>${profile_name}</span><span>$(date +"%Y-%m-%d %H:%M")</span></div>
</div>
<div class='x-body'>
<div class='x-main'>
<div class='sec'>
  <div class='sec-hdr'><h2>Summary</h2></div>
  <pre class='summary'>${sum_esc}</pre>
</div>
<div class='sec'>
  <div class='sec-hdr'><h2>Intervals (${count:-0})</h2></div>
  <table class='tbl'>
    <thead><tr><th>#</th><th>Start</th><th>End</th><th>Tags</th></tr></thead>
    <tbody>${table_rows}</tbody>
  </table>
</div>
</div>
${notes_panel}
</div>
${scripts}
</body></html>"

  if [[ -n "$output_file" ]]; then echo "$html" > "$output_file" && echo "$output_file"
  else echo "$html"; fi
}

export_journal_html() {
  local profile_dir="$1"
  local output_file="$2"

  local journals_dir="$profile_dir/journals"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$journals_dir" ]]; then return 1; fi

  local entries_html
  entries_html=$(python3 - "$journals_dir" << 'PY'
import os, re, sys, html as _h
journals_dir = sys.argv[1]
pat = re.compile(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] (.*)')
for fname in sorted(os.listdir(journals_dir)):
    if not fname.endswith(".txt"): continue
    jname = fname[:-4]
    entries, current, body_lines = [], None, []
    with open(os.path.join(journals_dir, fname), encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = pat.match(line)
            if m:
                if current: entries.append((current[0], current[1], "\n".join(body_lines).strip()))
                current = (m.group(1), m.group(2)); body_lines = []
            elif current: body_lines.append(line)
        if current: entries.append((current[0], current[1], "\n".join(body_lines).strip()))
    for ts, title, body in entries:
        body_attr = f' data-raw="{_h.escape(body)}"' if body else ""
        body_div = f'<div class="je-body"{body_attr}></div>' if body else ""
        print(f'<div class="je">'
              f'<div class="je-meta">'
              f'<span class="je-journal">{_h.escape(jname)}</span>'
              f'<span class="je-ts">{_h.escape(ts)}</span>'
              f'</div>'
              f'<div class="je-title">{_h.escape(title)}</div>'
              f'{body_div}</div>')
PY
)

  local head scripts notes_panel
  head=$(_html_common_head "ww journal — ${profile_name}")
  scripts=$(_html_scripts)
  notes_panel=$(_html_notes_panel)

  local html
  html="${head}
<body>
<meta name='ww-profile' content='${profile_name}'>
<div class='x-header'>
  <span class='x-ww'>ww</span><span class='x-full'>workwarrior · journal</span>
  <div class='x-meta'><span>${profile_name}</span><span>$(date +"%Y-%m-%d %H:%M")</span></div>
</div>
<div class='x-body'>
<div class='x-main'>
<div class='sec'>
  <div class='sec-hdr'><h2>Journal</h2></div>
  ${entries_html}
</div>
</div>
${notes_panel}
</div>
${scripts}
</body></html>"

  if [[ -n "$output_file" ]]; then echo "$html" > "$output_file" && echo "$output_file"
  else echo "$html"; fi
}

export_ledger_html() {
  local profile_dir="$1"
  local output_file="$2"

  local ledgers_dir="$profile_dir/ledgers"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$ledgers_dir" ]]; then return 1; fi

  local ledger_blocks=""
  for ledger_file in "$ledgers_dir"/*.journal; do
    [[ -f "$ledger_file" ]] || continue
    local lname
    lname=$(basename "$ledger_file" .journal)
    if command -v hledger &>/dev/null; then
      local bal reg
      bal=$(hledger -f "$ledger_file" balance 2>/dev/null | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")
      reg=$(hledger -f "$ledger_file" register -n 20 2>/dev/null | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")
      ledger_blocks+="<div class='ledger-blk'><div class='ledger-name'>${lname}</div>"
      ledger_blocks+="<p class='ledger-lbl'>Balance</p><pre class='ledger'>${bal}</pre>"
      ledger_blocks+="<p class='ledger-lbl'>Recent (20)</p><pre class='ledger'>${reg}</pre></div>"
    fi
  done

  local head scripts notes_panel
  head=$(_html_common_head "ww ledger — ${profile_name}")
  scripts=$(_html_scripts)
  notes_panel=$(_html_notes_panel)

  local html
  html="${head}
<body>
<meta name='ww-profile' content='${profile_name}'>
<div class='x-header'>
  <span class='x-ww'>ww</span><span class='x-full'>workwarrior · ledger</span>
  <div class='x-meta'><span>${profile_name}</span><span>$(date +"%Y-%m-%d %H:%M")</span></div>
</div>
<div class='x-body'>
<div class='x-main'>
<div class='sec'>
  <div class='sec-hdr'><h2>Ledger</h2></div>
  ${ledger_blocks}
</div>
</div>
${notes_panel}
</div>
${scripts}
</body></html>"

  if [[ -n "$output_file" ]]; then echo "$html" > "$output_file" && echo "$output_file"
  else echo "$html"; fi
}

export_all_html() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local profile_name
  profile_name=$(basename "$profile_dir")

  # ── tasks ──────────────────────────────────────────────────────────────────
  local task_html task_count=0 task_meta="{}"
  if [[ -d "$profile_dir/.task" && -n "$_TASK_BIN" ]]; then
    local task_json
    task_json=$(TASKRC="$profile_dir/.taskrc" TASKDATA="$profile_dir/.task" "$_TASK_BIN" $filter export 2>/dev/null || echo "[]")
    task_html=$(python3 - "$task_json" << 'PY'
import json, sys, html as _h
from datetime import datetime

STANDARD = {"id","uuid","description","status","project","tags","priority",
            "due","entry","modified","start","end","scheduled","wait","until",
            "recur","mask","imask","parent","urgency","depends","annotations",
            "exported_at","type","profile"}

def esc(s): return _h.escape(str(s or ""))
def fmte(v):
    if not v: return ""
    try: return datetime.utcfromtimestamp(int(v)).strftime("%Y-%m-%d")
    except: return str(v)[:10]

tasks = json.loads(sys.argv[1])
rows = []
for t in tasks:
    status = t.get("status","")
    scls = {"pending":"sb-pending","completed":"sb-completed","deleted":"sb-deleted"}.get(status,"")
    pri = t.get("priority","")
    pcls = {"H":"pri-H","M":"pri-M","L":"pri-L"}.get(pri,"")
    uuid = t.get("uuid","")
    tags = ", ".join(t.get("tags") or [])
    rows.append(
        f'<tr class="task-row" id="tr-{esc(uuid)}" onclick="toggleTaskRow(\'{esc(uuid)}\')">'
        f'<td>{esc(str(t.get("id","")))}</td>'
        f'<td>{esc(t.get("description",""))}</td>'
        f'<td>{esc(t.get("project",""))}</td>'
        f'<td><span class="sb {scls}">{esc(status)}</span></td>'
        f'<td class="{pcls}">{esc(pri)}</td>'
        f'<td>{esc(tags)}</td></tr>'
    )
    core = [
        ("due", fmte(t.get("due",""))), ("scheduled", fmte(t.get("scheduled",""))),
        ("wait", fmte(t.get("wait",""))), ("entry", fmte(t.get("entry",""))),
        ("modified", fmte(t.get("modified",""))),
        ("urgency", f'{round(t.get("urgency",0),2)}' if t.get("urgency") else ""),
    ]
    core_html = "".join(
        f'<div class="tf"><span class="tk">{k}</span><span class="tv">{esc(v)}</span></div>'
        for k,v in core if v)
    core_html += f'<div class="tf"><span class="tk">uuid</span><span class="tv uuid-val">{esc(uuid)}</span></div>'
    udas = {k:v for k,v in t.items()
            if k not in STANDARD and not k.startswith("tag_") and v not in ("",None,[])}
    uda_html = ""
    if udas:
        inner = "".join(
            f'<div class="tf uda-tf"><span class="tk">{esc(k)}</span><span class="tv">{esc(str(v))}</span></div>'
            for k,v in sorted(udas.items()))
        uda_html = f'<div class="uda-block">{inner}</div>'
    ann_list = t.get("annotations") or []
    ann_html = ""
    if ann_list:
        inner = "".join(
            f'<div class="ann-row">'
            f'<span class="ann-ts">{esc(fmte(a.get("entry","")))}</span>'
            f'<span class="ann-body">{esc(a.get("description",""))}</span>'
            f'</div>'
            for a in sorted(ann_list, key=lambda x: x.get("entry",""))
        )
        ann_html = f'<div class="ann-block hidden">{inner}</div>'
    rows.append(
        f'<tr class="task-detail-row hidden" id="td-{esc(uuid)}">'
        f'<td colspan="6"><div class="td-inner">'
        f'<div class="td-fields">{core_html}</div>'
        f'{uda_html}{ann_html}'
        f'</div></td></tr>'
    )
print('\n'.join(rows))
print(f'<!-- count:{len(tasks)} -->')
PY
)
    task_count=$(echo "$task_html" | grep -o 'count:[0-9]*' | cut -d: -f2 || echo 0)
    task_meta=$(python3 - "$task_json" << 'METAPY'
import json, sys
STANDARD = {"id","uuid","description","status","project","tags","priority",
            "due","entry","modified","start","end","scheduled","wait","until",
            "recur","mask","imask","parent","urgency","depends","annotations",
            "exported_at","type","profile"}
tasks = json.loads(sys.argv[1])
projects = sorted(set(t.get("project","") for t in tasks if t.get("project")))
tags = sorted(set(tag for t in tasks for tag in (t.get("tags") or [])))
udas = sorted(set(k for t in tasks for k in t
               if k not in STANDARD and not k.startswith("tag_") and t[k] not in ("",None,[])))
print(json.dumps({"projects":projects,"tags":tags,"udas":udas}))
METAPY
)
  fi

  # ── time ───────────────────────────────────────────────────────────────────
  local time_summary="" time_rows="" time_count=0
  if [[ -d "$profile_dir/.timewarrior" ]] && command -v timew &>/dev/null; then
    local time_json
    time_summary=$(TIMEWARRIORDB="$profile_dir/.timewarrior" timew summary $filter 2>/dev/null || echo "(no data)")
    time_json=$(TIMEWARRIORDB="$profile_dir/.timewarrior" timew export $filter 2>/dev/null || echo "[]")
    time_count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$time_json" 2>/dev/null || echo 0)
    time_rows=$(python3 - "$time_json" << 'PY'
import json, sys, html as _h
from datetime import datetime
def fmt(s):
    if not s: return ""
    try: return datetime.strptime(s,"%Y%m%dT%H%M%SZ").strftime("%Y-%m-%d %H:%M")
    except: return s[:16]
for e in json.loads(sys.argv[1]):
    tags = ", ".join(e.get("tags") or [])
    print(f'<tr><td>{_h.escape(str(e.get("id","")))}</td>'
          f'<td>{_h.escape(fmt(e.get("start","")))}</td>'
          f'<td>{_h.escape(fmt(e.get("end","")))}</td>'
          f'<td>{_h.escape(tags)}</td></tr>')
PY
)
    time_summary=$(echo "$time_summary" | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")
  fi

  # ── journal ────────────────────────────────────────────────────────────────
  local journal_html=""
  if [[ -d "$profile_dir/journals" ]]; then
    journal_html=$(python3 - "$profile_dir/journals" << 'PY'
import os, re, sys, html as _h
journals_dir = sys.argv[1]
pat = re.compile(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] (.*)')
for fname in sorted(os.listdir(journals_dir)):
    if not fname.endswith(".txt"): continue
    jname = fname[:-4]
    entries, current, body_lines = [], None, []
    with open(os.path.join(journals_dir, fname), encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = pat.match(line)
            if m:
                if current: entries.append((current[0], current[1], "\n".join(body_lines).strip()))
                current = (m.group(1), m.group(2)); body_lines = []
            elif current: body_lines.append(line)
        if current: entries.append((current[0], current[1], "\n".join(body_lines).strip()))
    for ts, title, body in entries:
        body_attr = f' data-raw="{_h.escape(body)}"' if body else ""
        body_div = f'<div class="je-body"{body_attr}></div>' if body else ""
        print(f'<div class="je">'
              f'<div class="je-meta">'
              f'<span class="je-journal">{_h.escape(jname)}</span>'
              f'<span class="je-ts">{_h.escape(ts)}</span>'
              f'</div>'
              f'<div class="je-title">{_h.escape(title)}</div>'
              f'{body_div}</div>')
PY
)
  fi

  # ── ledger ─────────────────────────────────────────────────────────────────
  local ledger_html=""
  if [[ -d "$profile_dir/ledgers" ]] && command -v hledger &>/dev/null; then
    for ledger_file in "$profile_dir/ledgers"/*.journal; do
      [[ -f "$ledger_file" ]] || continue
      local lname
      lname=$(basename "$ledger_file" .journal)
      local bal reg
      bal=$(hledger -f "$ledger_file" balance 2>/dev/null | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")
      reg=$(hledger -f "$ledger_file" register -n 20 2>/dev/null | python3 -c "import sys,html; print(html.escape(sys.stdin.read()))")
      ledger_html+="<div class='ledger-blk'><div class='ledger-name'>${lname}</div>"
      ledger_html+="<p class='ledger-lbl'>Balance</p><pre class='ledger'>${bal}</pre>"
      ledger_html+="<p class='ledger-lbl'>Recent (20)</p><pre class='ledger'>${reg}</pre></div>"
    done
  fi

  local head scripts notes_panel
  head=$(_html_common_head "ww export — ${profile_name}")
  scripts=$(_html_scripts)
  notes_panel=$(_html_notes_panel)

  local html
  html="${head}
<body>
<meta name='ww-profile' content='${profile_name}'>
<script type='application/json' id='ww-task-meta'>${task_meta}</script>
<div class='x-header'>
  <span class='x-ww'>ww</span>
  <span class='x-full'>workwarrior export</span>
  <div class='x-meta'>
    <span>${profile_name}</span>
    <span>$(date +"%Y-%m-%d %H:%M")</span>
  </div>
</div>
<div class='x-body'>
<div class='x-main'>

<div class='sec'>
  <div class='sec-hdr'>
    <h2>Tasks (${task_count:-0})</h2>
    <button class='tbtn' id='btn-detail' onclick='toggleAll()'>expand all</button>
    <button class='tbtn' id='btn-ann' onclick='toggleAnn()' style='display:none'>annotations</button>
  </div>
  <table class='tbl'>
    <thead><tr><th>#</th><th>Description</th><th>Project</th><th>Status</th><th>Pri</th><th>Tags</th></tr></thead>
    <tbody>${task_html}</tbody>
  </table>
</div>

<div class='sec'>
  <div class='sec-hdr'><h2>Time — Summary</h2></div>
  <pre class='summary'>${time_summary}</pre>
  <div class='sec-hdr' style='margin-top:12px'><h2>Intervals (${time_count:-0})</h2></div>
  <table class='tbl'>
    <thead><tr><th>#</th><th>Start</th><th>End</th><th>Tags</th></tr></thead>
    <tbody>${time_rows}</tbody>
  </table>
</div>

<div class='sec'>
  <div class='sec-hdr'><h2>Journal</h2></div>
  ${journal_html}
</div>

<div class='sec'>
  <div class='sec-hdr'><h2>Ledger</h2></div>
  ${ledger_html}
</div>

</div>
${notes_panel}
</div>
${scripts}
</body></html>"

  if [[ -n "$output_file" ]]; then
    echo "$html" > "$output_file"
    echo "$output_file"
  else
    echo "$html"
  fi
}

export_profile_backup() {
  local profile_dir="$1"
  local output_file="$2"

  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ -z "$output_file" ]]; then
    local export_dir="$EXPORT_DIR/$profile_name"
    mkdir -p "$export_dir"
    output_file="$export_dir/$(date +"%Y-%m-%d_%H%M%S")_backup.tar.gz"
  fi

  tar -czf "$output_file" -C "$WW_BASE/profiles" "$profile_name" 2>/dev/null
  echo "$output_file"
}

# ============================================================================
# MAIN (for testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Export Utils Library — functions: export_tasks_{json,csv,markdown} export_time_{json,csv,markdown} export_journal_{json,csv,markdown} export_ledger_{json,csv,markdown} export_all_json export_profile_backup"
fi
