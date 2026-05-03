#!/usr/bin/env bash
# lib/warrior-profile-registry.sh — cross-profile read helpers for Warrior service
# Source this file; do not execute directly. Requires WW_BASE.

_warrior_require_ww_base() {
  if [[ -z "${WW_BASE:-}" ]]; then
    echo "warrior: WW_BASE not set" >&2; return 1
  fi
}

# warrior_list_profiles — print all profile names
warrior_list_profiles() {
  _warrior_require_ww_base || return 1
  local profiles_dir="$WW_BASE/profiles"
  [[ -d "$profiles_dir" ]] || { echo "warrior: no profiles directory" >&2; return 1; }
  for pdir in "$profiles_dir"/*/; do
    [[ -d "$pdir" ]] || continue
    local pname taskrc taskdata jrnl_cfg
    pname=$(basename "$pdir")
    taskrc="$pdir.taskrc"
    taskdata="$pdir.task"
    jrnl_cfg="$pdir.config/jrnl.yaml"
    printf "%-20s  taskrc:%s  taskdata:%s  jrnl:%s\n" \
      "$pname" \
      "$([[ -f "$taskrc" ]] && echo "✓" || echo "✗")" \
      "$([[ -d "$taskdata" ]] && echo "✓" || echo "✗")" \
      "$([[ -f "$jrnl_cfg" ]] && echo "✓" || echo "✗")"
  done
}

# warrior_taskrc <profile> — print TASKRC path for a named profile
warrior_taskrc() {
  local pname="$1"
  _warrior_require_ww_base || return 1
  local taskrc="$WW_BASE/profiles/$pname/.taskrc"
  [[ -f "$taskrc" ]] || { echo "warrior: profile '$pname' not found or has no .taskrc" >&2; return 1; }
  echo "$taskrc"
}

# warrior_taskdata <profile> — print TASKDATA path for a named profile
warrior_taskdata() {
  local pname="$1"
  _warrior_require_ww_base || return 1
  local taskdata="$WW_BASE/profiles/$pname/.task"
  [[ -d "$taskdata" ]] || { echo "warrior: profile '$pname' has no .task directory" >&2; return 1; }
  echo "$taskdata"
}

# warrior_read_task <profile> <uuid|id> — export task JSON from a named profile
warrior_read_task() {
  local pname="$1" uuid="$2"
  [[ -n "$pname" && -n "$uuid" ]] || { echo "warrior: profile and task-id required" >&2; return 1; }
  local taskrc taskdata
  taskrc=$(warrior_taskrc "$pname") || return 1
  taskdata=$(warrior_taskdata "$pname") || return 1
  TASKRC="$taskrc" TASKDATA="$taskdata" task rc.confirmation=no "$uuid" export 2>/dev/null
}

# warrior_journal_file <profile> — print default journal file path
warrior_journal_file() {
  local pname="$1"
  _warrior_require_ww_base || return 1
  local jrnl_cfg="$WW_BASE/profiles/$pname/.config/jrnl.yaml"
  if [[ -f "$jrnl_cfg" ]]; then
    grep -E '^\s+default:' "$jrnl_cfg" 2>/dev/null | awk '{print $2}' | head -1
  else
    # Fallback conventional path
    local f="$WW_BASE/profiles/$pname/journals/${pname}.txt"
    [[ -f "$f" ]] && echo "$f"
  fi
}

# warrior_read_journal <profile> <date-slug> — print journal entry for a date slug
warrior_read_journal() {
  local pname="$1" slug="$2"
  [[ -n "$pname" && -n "$slug" ]] || { echo "warrior: profile and date-slug required" >&2; return 1; }
  local jf
  jf=$(warrior_journal_file "$pname") || return 1
  [[ -f "$jf" ]] || { echo "warrior: journal file not found for profile '$pname'" >&2; return 1; }
  # slug format: YYYY-MM-DD_HH-MM → header [YYYY-MM-DD HH:MM]
  local date_part time_part hdr
  date_part="${slug%%_*}"
  time_part="${slug#*_}"; time_part="${time_part//-/:}"
  hdr="[$date_part $time_part]"
  python3 - "$jf" "$hdr" <<'PYEOF'
import sys, re
jf, hdr = sys.argv[1], sys.argv[2]
content = open(jf, encoding='utf-8').read()
escaped = re.escape(hdr)
m = re.search(rf'{escaped}(.*?)(?=\[\d{{4}}-\d{{2}}-\d{{2}} \d{{2}}:\d{{2}}\]|\Z)', content, re.DOTALL)
if m:
    print(hdr)
    print(m.group(1).strip())
else:
    print(f"No entry found for {hdr}", file=sys.stderr)
    sys.exit(1)
PYEOF
}
