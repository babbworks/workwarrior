#!/usr/bin/env bash
# services/browser/browser.sh — Workwarrior browser service entry point
#
# Usage: browser.sh [start] [--port N] [--no-open]
#        browser.sh stop
#        browser.sh status
#        browser.sh --help
#
# Called by cmd_browser() in bin/ww. May also be invoked directly.

set -euo pipefail

# ============================================================================
# DEFAULTS
# ============================================================================

BROWSER_DEFAULT_PORT="${WW_BROWSER_PORT:-7777}"
BROWSER_SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_BASE="${WW_BASE:-$HOME/ww}"
STATE_DIR="${WW_BASE}/.state"

# ============================================================================
# HELP
# ============================================================================

_browser_usage() {
  cat << 'EOF'
Usage:
  ww browser [start] [--port N] [--no-open]
  ww browser stop
  ww browser status
  ww browser export [--path FILE]  Generate a self-contained offline HTML snapshot
  ww browser --help

Actions:
  start (default)  Start the browser HTTP server
  stop             Stop a running browser server
  status           Show whether the server is running
  export           Generate a self-contained offline HTML snapshot

Flags:
  --port N         Listen on port N instead of 7777
  --no-open        Do not open browser tab on start
  --path FILE      Output path for export (default: ./ww-export-<profile>-<date>.html)

Examples:
  ww browser                        Start on default port 7777
  ww browser --port 8080            Start on port 8080
  ww browser --no-open              Start without opening a browser tab
  ww browser stop                   Stop the running server
  ww browser status                 Check server status
EOF
}

# ============================================================================
# STATUS HELPERS
# ============================================================================

_browser_pid_file() {
  echo "${STATE_DIR}/browser.pid"
}

_browser_port_file() {
  echo "${STATE_DIR}/browser.port"
}

_browser_read_pid() {
  local pid_file
  pid_file="$(_browser_pid_file)"
  if [[ -f "$pid_file" ]]; then
    cat "$pid_file"
  else
    echo ""
  fi
}

_browser_read_port() {
  local port_file
  port_file="$(_browser_port_file)"
  if [[ -f "$port_file" ]]; then
    cat "$port_file"
  else
    echo ""
  fi
}

_browser_is_running() {
  local pid
  pid="$(_browser_read_pid)"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  # Stale PID files — clean them up
  rm -f "$(_browser_pid_file)" "$(_browser_port_file)"
  return 1
}

_browser_export() {
  local out_path="${1:-}"
  local port
  port="$(_browser_read_port)"

  if ! _browser_is_running; then
    echo "error: browser server is not running — start it first with 'ww browser'" >&2
    exit 1
  fi

  # Fetch all data from the running server
  local data
  data=$(curl -sf "http://localhost:${port}/data/all") || {
    echo "error: could not fetch data from browser server" >&2
    exit 1
  }

  # Determine output path
  local profile date_str
  profile=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('profile','unknown'))" 2>/dev/null || echo "unknown")
  date_str=$(date +%Y%m%d)
  if [[ -z "$out_path" ]]; then
    out_path="./ww-export-${profile}-${date_str}.html"
  fi

  # Read static assets
  local js css
  js=$(cat "${BROWSER_SERVICE_DIR}/static/app.js")
  css=$(cat "${BROWSER_SERVICE_DIR}/static/style.css")

  python3 - "$out_path" "$data" "$js" "$css" << 'PYEOF'
import sys, json, html as _html
from datetime import datetime

out_path = sys.argv[1]
data = json.loads(sys.argv[2])
js = sys.argv[3]
css = sys.argv[4]

profile = data.get("profile", "")
exported_at = data.get("exported_at", "")
tasks = data.get("tasks", [])
journal = data.get("journal", [])
balances = data.get("balances", [])

def esc(s): return _html.escape(str(s or ""))

def fmt_epoch(v):
    if not v: return ""
    try: return datetime.utcfromtimestamp(int(v)).strftime("%Y-%m-%d")
    except: return str(v)

# Fields that are part of the standard Taskwarrior schema (not UDAs)
STANDARD_FIELDS = {
    "id","uuid","description","status","project","tags","priority",
    "due","entry","modified","start","end","scheduled","wait","until",
    "recur","mask","imask","parent","urgency","depends","annotations",
    "exported_at","type","profile",
}

def render_task_compact(t):
    return (
        f'<tr><td>{esc(t.get("id",""))}</td>'
        f'<td>{esc(t.get("description",""))}</td>'
        f'<td>{esc(t.get("project",""))}</td>'
        f'<td>{esc(t.get("status",""))}</td>'
        f'<td>{esc(",".join(t.get("tags") or []))}</td></tr>'
    )

def render_task_detail(t):
    tid = esc(t.get("id",""))
    desc = esc(t.get("description",""))
    status = t.get("status","")
    status_cls = {"pending":"s-pending","completed":"s-done","deleted":"s-deleted"}.get(status,"")

    # Core fields
    core_pairs = [
        ("project", esc(t.get("project",""))),
        ("status",  f'<span class="task-status {status_cls}">{esc(status)}</span>'),
        ("priority",esc(t.get("priority",""))),
        ("tags",    esc(", ".join(t.get("tags") or []))),
        ("due",     esc(fmt_epoch(t.get("due","")))),
        ("scheduled",esc(fmt_epoch(t.get("scheduled","")))),
        ("wait",    esc(fmt_epoch(t.get("wait","")))),
        ("entry",   esc(fmt_epoch(t.get("entry","")))),
        ("modified",esc(fmt_epoch(t.get("modified","")))),
        ("urgency", esc(str(round(t.get("urgency",0),2)) if t.get("urgency") else "")),
        ("uuid",    f'<span class="uuid">{esc(t.get("uuid",""))}</span>'),
    ]
    core_html = "".join(
        f'<div class="tf"><span class="tk">{k}</span><span class="tv">{v}</span></div>'
        for k, v in core_pairs if v and v != '<span class="task-status "></span>'
    )

    # UDA fields
    uda_fields = {k: v for k, v in t.items()
                  if k not in STANDARD_FIELDS and not k.startswith("tag_") and v not in ("", None)}
    uda_html = ""
    if uda_fields:
        rows = "".join(
            f'<div class="tf uda-field"><span class="tk">{esc(k)}</span>'
            f'<span class="tv">{esc(str(v))}</span></div>'
            for k, v in sorted(uda_fields.items())
        )
        uda_html = f'<div class="uda-section">{rows}</div>'

    # Annotations
    ann_items = {k: v for k, v in t.items() if k.startswith("annotation_")}
    ann_html = ""
    if ann_items:
        sorted_anns = sorted(ann_items.items(), key=lambda x: x[0])
        rows = "".join(
            f'<div class="ann-row"><span class="ann-ts">{esc(fmt_epoch(k.replace("annotation_","")))}</span>'
            f'<span class="ann-body">{esc(str(v))}</span></div>'
            for k, v in sorted_anns
        )
        ann_html = f'<div class="ann-section" data-annotations>{rows}</div>'

    return (
        f'<div class="task-card" data-status="{esc(status)}">'
        f'<div class="task-card-header">'
        f'<span class="task-id">#{tid}</span>'
        f'<span class="task-desc">{desc}</span>'
        f'</div>'
        f'<div class="task-fields">{core_html}{uda_html}</div>'
        f'{ann_html}'
        f'</div>'
    )

task_rows_compact = "".join(render_task_compact(t) for t in tasks)
task_cards_detail = "".join(render_task_detail(t) for t in tasks)

journal_rows = "".join(
    f'<div class="je"><div class="jd">{esc(e.get("date",""))}</div>'
    f'<div class="jb">{esc(e.get("body",""))}</div></div>'
    for e in journal
)
balance_rows = "".join(
    f'<tr><td>{esc(b.get("account",""))}</td><td>{esc(b.get("amount",""))}</td></tr>'
    for b in balances
)

html = f"""<!DOCTYPE html>
<html lang=\"en\">
<head><meta charset=\"UTF-8\">
<title>ww export — {esc(profile)} — {esc(exported_at)}</title>
<style>
{css}
.export-header{{padding:16px;border-bottom:1px solid var(--border);background:var(--surface);display:flex;align-items:center;gap:8px;}}
.export-header-right{{margin-left:auto;color:var(--muted);font-size:11px;}}
.export-section{{padding:16px;margin-bottom:24px;}}
.section-header{{display:flex;align-items:center;gap:8px;margin-bottom:12px;border-bottom:1px solid var(--border);padding-bottom:6px;}}
.section-header h2{{font-size:13px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;margin:0;flex:1;}}
.toggle-btn{{font-size:11px;padding:2px 8px;border:1px solid var(--border);background:var(--surface);color:var(--muted);cursor:pointer;border-radius:3px;}}
.toggle-btn.active{{background:var(--accent,#4a9eff);color:#fff;border-color:var(--accent,#4a9eff);}}
table{{width:100%;border-collapse:collapse;font-size:12px;}}
th{{text-align:left;color:var(--muted);padding:4px 8px;border-bottom:1px solid var(--border);}}
td{{padding:4px 8px;border-bottom:1px solid var(--border);}}
.je{{padding:12px 0;border-bottom:1px solid var(--border);}}
.jd{{font-size:11px;color:var(--muted);margin-bottom:4px;}}
.jb{{font-size:13px;white-space:pre-wrap;}}
/* task cards */
.task-card{{border:1px solid var(--border);border-radius:4px;margin-bottom:8px;overflow:hidden;}}
.task-card-header{{padding:8px 12px;background:var(--surface);display:flex;align-items:baseline;gap:8px;}}
.task-id{{font-size:11px;color:var(--muted);min-width:28px;}}
.task-desc{{font-size:13px;font-weight:500;flex:1;}}
.task-fields{{padding:6px 12px 8px;display:flex;flex-wrap:wrap;gap:4px 16px;}}
.tf{{display:flex;align-items:baseline;gap:4px;font-size:11px;}}
.tk{{color:var(--muted);}}
.tv{{color:var(--fg,inherit);}}
.uuid{{font-family:monospace;font-size:10px;opacity:.6;}}
.uda-section{{padding:4px 12px 6px;border-top:1px solid var(--border);display:flex;flex-wrap:wrap;gap:4px 16px;}}
.uda-field .tk{{color:var(--accent,#4a9eff);opacity:.8;}}
.ann-section{{padding:6px 12px 8px;border-top:1px solid var(--border);}}
.ann-row{{display:flex;gap:8px;font-size:11px;padding:2px 0;}}
.ann-ts{{color:var(--muted);min-width:80px;flex-shrink:0;}}
.ann-body{{white-space:pre-wrap;}}
.task-status{{font-size:10px;padding:1px 5px;border-radius:2px;}}
.s-pending{{background:rgba(74,158,255,.15);color:#4a9eff;}}
.s-done{{background:rgba(80,200,120,.15);color:#50c878;}}
.s-deleted{{background:rgba(200,80,80,.15);color:#c85050;}}
[data-annotations]{{display:none;}}
.show-annotations [data-annotations]{{display:block;}}
</style>
</head>
<body>
<div id=\"app\">
<div class=\"export-header\">
  <span class=\"wordmark-ww\">ww</span>
  <span class=\"wordmark-full\">workwarrior export</span>
  <span class=\"export-header-right\">{esc(profile)} &middot; {esc(exported_at)}</span>
</div>
<div id=\"main\">
<div class=\"export-section\">
  <div class=\"section-header\">
    <h2>Tasks ({len(tasks)})</h2>
    <button class=\"toggle-btn\" id=\"btn-detail\" onclick=\"toggleDetail()\">full detail</button>
    <button class=\"toggle-btn\" id=\"btn-annotations\" onclick=\"toggleAnnotations()\" style=\"display:none\">annotations</button>
  </div>
  <div id=\"tasks-compact\">
    <table><thead><tr><th>#</th><th>Description</th><th>Project</th><th>Status</th><th>Tags</th></tr></thead>
    <tbody>{task_rows_compact}</tbody></table>
  </div>
  <div id=\"tasks-detail\" style=\"display:none\">{task_cards_detail}</div>
</div>
<div class=\"export-section\">
<h2>Journal ({len(journal)} recent entries)</h2>
{journal_rows}
</div>
<div class=\"export-section\">
<h2>Balances</h2>
<table><thead><tr><th>Account</th><th>Amount</th></tr></thead>
<tbody>{balance_rows}</tbody></table>
</div>
</div></div>
<script>
const WW_DATA = {json.dumps(data)};
let detailOn = false, annotationsOn = false;
function toggleDetail() {{
  detailOn = !detailOn;
  document.getElementById('tasks-compact').style.display = detailOn ? 'none' : '';
  document.getElementById('tasks-detail').style.display = detailOn ? '' : 'none';
  document.getElementById('btn-detail').classList.toggle('active', detailOn);
  document.getElementById('btn-annotations').style.display = detailOn ? '' : 'none';
  if (!detailOn) {{ annotationsOn = false; applyAnnotations(); document.getElementById('btn-annotations').classList.remove('active'); }}
}}
function toggleAnnotations() {{
  annotationsOn = !annotationsOn;
  document.getElementById('btn-annotations').classList.toggle('active', annotationsOn);
  applyAnnotations();
}}
function applyAnnotations() {{
  document.getElementById('tasks-detail').classList.toggle('show-annotations', annotationsOn);
}}
</script>
</body></html>"""

with open(out_path, "w") as f:
    f.write(html)
print(f"Exported: {out_path}")
PYEOF
}

# ============================================================================
# SUBCOMMANDS
# ============================================================================

_browser_status() {
  if _browser_is_running; then
    local pid port
    pid="$(_browser_read_pid)"
    port="$(_browser_read_port)"
    echo "running on http://localhost:${port}  (pid ${pid})"
    return 0
  else
    echo "not running"
    return 0
  fi
}

_browser_stop() {
  if ! _browser_is_running; then
    echo "browser server is not running"
    return 0
  fi
  local pid
  pid="$(_browser_read_pid)"
  echo "Stopping browser server (pid ${pid}) …"
  kill "$pid" 2>/dev/null || true

  # Wait up to 5 seconds for clean shutdown
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 50 ]]; do
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$(_browser_pid_file)" "$(_browser_port_file)"
  echo "browser server stopped"
}

_find_free_port() {
  local port="${1:-$BROWSER_DEFAULT_PORT}"
  while lsof -iTCP:"${port}" -sTCP:LISTEN -t &>/dev/null 2>&1; do
    port=$(( port + 1 ))
  done
  echo "$port"
}

_browser_start() {
  local port="${1:-$BROWSER_DEFAULT_PORT}"
  local no_open="${2:-0}"

  if ! command -v python3 &>/dev/null; then
    echo "error: python3 not found" >&2
    echo "Install Python 3: https://www.python.org/downloads/" >&2
    exit 1
  fi

  if [[ ! -f "${BROWSER_SERVICE_DIR}/server.py" ]]; then
    echo "error: server.py not found at ${BROWSER_SERVICE_DIR}/server.py" >&2
    exit 2
  fi

  # Ensure state dir exists
  mkdir -p "${STATE_DIR}"

  # Start server in background
  python3 "${BROWSER_SERVICE_DIR}/server.py" \
    --port "${port}" \
    --ww-base "${WW_BASE}" \
    &

  local server_pid=$!

  # Wait for /health to respond (up to 10 seconds)
  local waited=0
  local healthy=0
  while [[ $waited -lt 100 ]]; do
    if curl -sf "http://localhost:${port}/health" &>/dev/null; then
      healthy=1
      break
    fi
    # Check if process died
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "error: browser server failed to start (process exited)" >&2
      exit 1
    fi
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  if [[ $healthy -eq 0 ]]; then
    echo "error: browser server did not respond within 10 seconds" >&2
    kill "$server_pid" 2>/dev/null || true
    exit 1
  fi

  echo "Workwarrior browser running at http://localhost:${port} — Ctrl-C or 'ww browser stop' to quit"

  if [[ "$no_open" -eq 0 ]]; then
    if command -v open &>/dev/null; then
      # macOS
      open "http://localhost:${port}" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
      # Linux
      xdg-open "http://localhost:${port}" 2>/dev/null || true
    fi
  fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local subcommand=""
  local port="${BROWSER_DEFAULT_PORT}"
  local port_explicit=0
  local no_open=0
  local export_path=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      start|stop|status|export)
        subcommand="$1"
        shift
        ;;
      --port)
        if [[ -z "${2:-}" ]]; then
          echo "error: --port requires a port number" >&2
          exit 1
        fi
        port="$2"
        port_explicit=1
        shift 2
        ;;
      --port=*)
        port="${1#--port=}"
        port_explicit=1
        shift
        ;;
      --no-open)
        no_open=1
        shift
        ;;
      --path)
        export_path="${2:-}"
        shift 2
        ;;
      --path=*)
        export_path="${1#--path=}"
        shift
        ;;
      --help|-h|help)
        _browser_usage
        exit 0
        ;;
      *)
        echo "error: unknown argument: $1" >&2
        _browser_usage >&2
        exit 1
        ;;
    esac
  done

  # Default subcommand is start
  subcommand="${subcommand:-start}"

  # Auto-assign a free port unless the user explicitly passed --port
  if [[ "$subcommand" == "start" && "$port_explicit" -eq 0 ]]; then
    port="$(_find_free_port "$port")"
  fi

  case "$subcommand" in
    start)
      _browser_start "$port" "$no_open"
      ;;
    stop)
      _browser_stop
      ;;
    status)
      _browser_status
      ;;
    export)
      _browser_export "$export_path"
      ;;
    *)
      echo "error: unknown subcommand: $subcommand" >&2
      _browser_usage >&2
      exit 1
      ;;
  esac
}

main "$@"
