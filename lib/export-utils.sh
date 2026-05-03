#!/usr/bin/env bash
# Export Utilities Library
# Functions to export data from TaskWarrior, TimeWarrior, JRNL, and Hledger

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_BASE="${WW_BASE:-$HOME/ww}"
EXPORT_DIR="${WW_BASE}/exports"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Get profile directory
get_profile_dir() {
  local profile_name="${1:-$WARRIOR_PROFILE}"
  if [[ -z "$profile_name" ]]; then
    return 1
  fi
  echo "$WW_BASE/profiles/$profile_name"
}

# Create export directory and return output path
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

# Escape CSV field
csv_escape() {
  local field="$1"
  # If field contains comma, newline, or quote, wrap in quotes and escape quotes
  if [[ "$field" == *","* || "$field" == *$'\n'* || "$field" == *'"'* ]]; then
    field="${field//\"/\"\"}"
    echo "\"$field\""
  else
    echo "$field"
  fi
}

# JSON wrapper for export data
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

  if [[ ! -d "$taskdata" ]]; then
    echo "[]"
    return 1
  fi

  if ! command -v task &>/dev/null; then
    echo "[]"
    return 1
  fi

  local data
  data=$(TASKRC="$taskrc" TASKDATA="$taskdata" task $filter export 2>/dev/null || echo "[]")

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

  if [[ ! -d "$taskdata" ]]; then
    return 1
  fi

  if ! command -v task &>/dev/null; then
    return 1
  fi

  # Get JSON and convert to CSV
  local json_data
  json_data=$(TASKRC="$taskrc" TASKDATA="$taskdata" task $filter export 2>/dev/null)

  # CSV header
  local csv_output="id,uuid,description,status,project,tags,priority,due,entry,modified"

  # Parse JSON to CSV (simple parsing for common fields)
  while IFS= read -r line; do
    if [[ "$line" == "{"* ]]; then
      local id uuid desc status project tags priority due entry modified
      id=$(echo "$line" | grep -o '"id":[0-9]*' | cut -d: -f2)
      uuid=$(echo "$line" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
      desc=$(echo "$line" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
      status=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
      project=$(echo "$line" | grep -o '"project":"[^"]*"' | cut -d'"' -f4)
      tags=$(echo "$line" | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]//;s/"//g')
      priority=$(echo "$line" | grep -o '"priority":"[^"]*"' | cut -d'"' -f4)
      due=$(echo "$line" | grep -o '"due":"[^"]*"' | cut -d'"' -f4)
      entry=$(echo "$line" | grep -o '"entry":"[^"]*"' | cut -d'"' -f4)
      modified=$(echo "$line" | grep -o '"modified":"[^"]*"' | cut -d'"' -f4)

      csv_output+="\n$(csv_escape "$id"),$(csv_escape "$uuid"),$(csv_escape "$desc"),$(csv_escape "$status"),$(csv_escape "$project"),$(csv_escape "$tags"),$(csv_escape "$priority"),$(csv_escape "$due"),$(csv_escape "$entry"),$(csv_escape "$modified")"
    fi
  done <<< "$json_data"

  if [[ -n "$output_file" ]]; then
    echo -e "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$csv_output"
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

  if [[ ! -d "$taskdata" ]]; then
    return 1
  fi

  if ! command -v task &>/dev/null; then
    return 1
  fi

  local md_output="# Tasks Export - $profile_name\n"
  md_output+="Exported: $(date +"%Y-%m-%d %H:%M")\n\n"

  # Pending tasks
  local pending_count
  pending_count=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:pending count 2>/dev/null || echo "0")
  md_output+="## Pending Tasks ($pending_count)\n\n"
  md_output+="| ID | Description | Project | Priority | Due |\n"
  md_output+="|-----|-------------|---------|----------|-----|\n"

  TASKRC="$taskrc" TASKDATA="$taskdata" task status:pending export 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == "{"* ]]; then
      local id desc project priority due
      id=$(echo "$line" | grep -o '"id":[0-9]*' | cut -d: -f2)
      desc=$(echo "$line" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 | cut -c1-40)
      project=$(echo "$line" | grep -o '"project":"[^"]*"' | cut -d'"' -f4)
      priority=$(echo "$line" | grep -o '"priority":"[^"]*"' | cut -d'"' -f4)
      due=$(echo "$line" | grep -o '"due":"[^"]*"' | cut -d'"' -f4 | cut -c1-10)
      echo "| $id | $desc | $project | $priority | $due |"
    fi
  done >> /tmp/ww_export_tasks_md.tmp

  if [[ -f /tmp/ww_export_tasks_md.tmp ]]; then
    md_output+=$(cat /tmp/ww_export_tasks_md.tmp)
    rm -f /tmp/ww_export_tasks_md.tmp
  fi

  md_output+="\n\n"

  # Completed tasks
  local completed_count
  completed_count=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:completed count 2>/dev/null || echo "0")
  md_output+="## Completed Tasks ($completed_count)\n\n"

  if [[ -n "$output_file" ]]; then
    echo -e "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$md_output"
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

  if [[ ! -d "$timedb" ]]; then
    echo "[]"
    return 1
  fi

  if ! command -v timew &>/dev/null; then
    echo "[]"
    return 1
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

  if [[ ! -d "$timedb" ]]; then
    return 1
  fi

  if ! command -v timew &>/dev/null; then
    return 1
  fi

  local csv_output="id,start,end,tags,annotation"

  TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == "{"* ]]; then
      local id start end tags annotation
      id=$(echo "$line" | grep -o '"id":[0-9]*' | cut -d: -f2)
      start=$(echo "$line" | grep -o '"start":"[^"]*"' | cut -d'"' -f4)
      end=$(echo "$line" | grep -o '"end":"[^"]*"' | cut -d'"' -f4)
      tags=$(echo "$line" | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]//;s/"//g')
      annotation=$(echo "$line" | grep -o '"annotation":"[^"]*"' | cut -d'"' -f4)
      echo "$id,$(csv_escape "$start"),$(csv_escape "$end"),$(csv_escape "$tags"),$(csv_escape "$annotation")"
    fi
  done >> /tmp/ww_export_time_csv.tmp

  if [[ -f /tmp/ww_export_time_csv.tmp ]]; then
    csv_output+="\n$(cat /tmp/ww_export_time_csv.tmp)"
    rm -f /tmp/ww_export_time_csv.tmp
  fi

  if [[ -n "$output_file" ]]; then
    echo -e "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$csv_output"
  fi
}

export_time_markdown() {
  local profile_dir="$1"
  local output_file="$2"
  local filter="${3:-}"

  local timedb="$profile_dir/.timewarrior"
  local profile_name
  profile_name=$(basename "$profile_dir")

  if [[ ! -d "$timedb" ]]; then
    return 1
  fi

  if ! command -v timew &>/dev/null; then
    return 1
  fi

  local md_output="# Time Export - $profile_name\n"
  md_output+="Exported: $(date +"%Y-%m-%d %H:%M")\n\n"

  # Summary
  md_output+="## Summary\n\n"
  md_output+="\`\`\`\n"
  md_output+=$(TIMEWARRIORDB="$timedb" timew summary $filter 2>/dev/null)
  md_output+="\n\`\`\`\n\n"

  # Recent entries
  md_output+="## Recent Entries\n\n"
  md_output+="| Date | Duration | Tags |\n"
  md_output+="|------|----------|------|\n"

  TIMEWARRIORDB="$timedb" timew export $filter 2>/dev/null | tail -20 | while IFS= read -r line; do
    if [[ "$line" == "{"* ]]; then
      local start tags
      start=$(echo "$line" | grep -o '"start":"[^"]*"' | cut -d'"' -f4 | cut -c1-10)
      tags=$(echo "$line" | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]//;s/"//g')
      echo "| $start | - | $tags |"
    fi
  done >> /tmp/ww_export_time_md.tmp

  if [[ -f /tmp/ww_export_time_md.tmp ]]; then
    md_output+=$(cat /tmp/ww_export_time_md.tmp)
    rm -f /tmp/ww_export_time_md.tmp
  fi

  if [[ -n "$output_file" ]]; then
    echo -e "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$md_output"
  fi
}

# ============================================================================
# JRNL EXPORT
# ============================================================================

export_journal_json() {
  local profile_dir="$1"
  local output_file="$2"

  local journals_dir="$profile_dir/journals"

  if [[ ! -d "$journals_dir" ]]; then
    echo "[]"
    return 1
  fi

  local profile_name
  profile_name=$(basename "$profile_dir")

  local entries="["
  local first=true

  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      local journal_name
      journal_name=$(basename "$journal_file" .txt)

      while IFS= read -r line; do
        if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2})\]\ (.*) ]]; then
          local timestamp="${BASH_REMATCH[1]}"
          local content="${BASH_REMATCH[2]}"
          # Escape quotes in content
          content="${content//\"/\\\"}"

          if [[ "$first" == "true" ]]; then
            first=false
          else
            entries+=","
          fi
          entries+="{\"journal\":\"$journal_name\",\"timestamp\":\"$timestamp\",\"content\":\"$content\"}"
        fi
      done < "$journal_file"
    fi
  done

  entries+="]"

  local wrapped
  wrapped=$(json_wrapper "$profile_name" "journal" "$entries")

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

  local csv_output="journal,timestamp,content"

  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      local journal_name
      journal_name=$(basename "$journal_file" .txt)

      while IFS= read -r line; do
        if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2})\]\ (.*) ]]; then
          local timestamp="${BASH_REMATCH[1]}"
          local content="${BASH_REMATCH[2]}"
          csv_output+="\n$(csv_escape "$journal_name"),$(csv_escape "$timestamp"),$(csv_escape "$content")"
        fi
      done < "$journal_file"
    fi
  done

  if [[ -n "$output_file" ]]; then
    echo -e "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$csv_output"
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

  local md_output="# Journal Export - $profile_name\n"
  md_output+="Exported: $(date +"%Y-%m-%d %H:%M")\n\n"

  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      local journal_name
      journal_name=$(basename "$journal_file" .txt)
      local entry_count
      entry_count=$(grep -c '^\[' "$journal_file" 2>/dev/null || echo "0")

      md_output+="## $journal_name ($entry_count entries)\n\n"

      # Last 10 entries
      tail -20 "$journal_file" | while IFS= read -r line; do
        if [[ "$line" =~ ^\[ ]]; then
          echo "- $line"
        fi
      done >> /tmp/ww_export_journal_md.tmp

      if [[ -f /tmp/ww_export_journal_md.tmp ]]; then
        md_output+=$(cat /tmp/ww_export_journal_md.tmp)
        rm -f /tmp/ww_export_journal_md.tmp
      fi
      md_output+="\n\n"
    fi
  done

  if [[ -n "$output_file" ]]; then
    echo -e "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$md_output"
  fi
}

# ============================================================================
# HLEDGER EXPORT
# ============================================================================

export_ledger_json() {
  local profile_dir="$1"
  local output_file="$2"

  local ledgers_dir="$profile_dir/ledgers"

  if [[ ! -d "$ledgers_dir" ]]; then
    echo "[]"
    return 1
  fi

  local profile_name
  profile_name=$(basename "$profile_dir")

  local data="["
  local first=true

  for ledger_file in "$ledgers_dir"/*.journal; do
    if [[ -f "$ledger_file" ]]; then
      local ledger_name
      ledger_name=$(basename "$ledger_file" .journal)

      if command -v hledger &>/dev/null; then
        local ledger_json
        ledger_json=$(hledger -f "$ledger_file" print -O json 2>/dev/null || echo "[]")

        if [[ "$first" == "true" ]]; then
          first=false
        else
          data+=","
        fi
        data+="{\"ledger\":\"$ledger_name\",\"transactions\":$ledger_json}"
      fi
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

  if [[ ! -d "$ledgers_dir" ]]; then
    return 1
  fi

  local csv_output="ledger,date,description,account,amount"

  for ledger_file in "$ledgers_dir"/*.journal; do
    if [[ -f "$ledger_file" ]]; then
      local ledger_name
      ledger_name=$(basename "$ledger_file" .journal)

      if command -v hledger &>/dev/null; then
        hledger -f "$ledger_file" register -O csv 2>/dev/null | tail -n +2 | while IFS= read -r line; do
          csv_output+="\n$(csv_escape "$ledger_name"),$line"
        done
      fi
    fi
  done

  if [[ -n "$output_file" ]]; then
    echo -e "$csv_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$csv_output"
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

  local md_output="# Ledger Export - $profile_name\n"
  md_output+="Exported: $(date +"%Y-%m-%d %H:%M")\n\n"

  for ledger_file in "$ledgers_dir"/*.journal; do
    if [[ -f "$ledger_file" ]]; then
      local ledger_name
      ledger_name=$(basename "$ledger_file" .journal)

      md_output+="## $ledger_name\n\n"

      if command -v hledger &>/dev/null; then
        md_output+="### Balance\n\n"
        md_output+="\`\`\`\n"
        md_output+=$(hledger -f "$ledger_file" balance 2>/dev/null)
        md_output+="\n\`\`\`\n\n"

        md_output+="### Recent Transactions\n\n"
        md_output+="\`\`\`\n"
        md_output+=$(hledger -f "$ledger_file" register -n 10 2>/dev/null)
        md_output+="\n\`\`\`\n\n"
      else
        md_output+="(hledger not installed)\n\n"
      fi
    fi
  done

  if [[ -n "$output_file" ]]; then
    echo -e "$md_output" > "$output_file"
    echo "$output_file"
  else
    echo -e "$md_output"
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

  local tasks time journal ledger

  # Get each data type
  tasks=$(export_tasks_json "$profile_dir" "" | grep -o '"data":.*' | sed 's/"data"://' | sed 's/}$//')
  time=$(export_time_json "$profile_dir" "" | grep -o '"data":.*' | sed 's/"data"://' | sed 's/}$//')
  journal=$(export_journal_json "$profile_dir" "" | grep -o '"data":.*' | sed 's/"data"://' | sed 's/}$//')
  ledger=$(export_ledger_json "$profile_dir" "" | grep -o '"data":.*' | sed 's/"data"://' | sed 's/}$//')

  local combined
  combined=$(cat << EOF
{
  "profile": "$profile_name",
  "exported": "$(date -Iseconds)",
  "type": "all",
  "data": {
    "tasks": ${tasks:-[]},
    "time": ${time:-[]},
    "journal": ${journal:-[]},
    "ledger": ${ledger:-[]}
  }
}
EOF
)

  if [[ -n "$output_file" ]]; then
    echo "$combined" > "$output_file"
    echo "$output_file"
  else
    echo "$combined"
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

  # Create backup tarball
  tar -czf "$output_file" -C "$WW_BASE/profiles" "$profile_name" 2>/dev/null

  echo "$output_file"
}

# ============================================================================
# MAIN (for testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Export Utils Library"
  echo "===================="
  echo ""
  echo "Functions available:"
  echo "  export_tasks_json <profile_dir> [output_file]"
  echo "  export_tasks_csv <profile_dir> [output_file]"
  echo "  export_tasks_markdown <profile_dir> [output_file]"
  echo "  export_time_json <profile_dir> [output_file]"
  echo "  export_time_csv <profile_dir> [output_file]"
  echo "  export_time_markdown <profile_dir> [output_file]"
  echo "  export_journal_json <profile_dir> [output_file]"
  echo "  export_journal_csv <profile_dir> [output_file]"
  echo "  export_journal_markdown <profile_dir> [output_file]"
  echo "  export_ledger_json <profile_dir> [output_file]"
  echo "  export_ledger_csv <profile_dir> [output_file]"
  echo "  export_ledger_markdown <profile_dir> [output_file]"
  echo "  export_all_json <profile_dir> [output_file]"
  echo "  export_profile_backup <profile_dir> [output_file]"
fi
