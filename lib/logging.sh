#!/usr/bin/env bash
# Logging Module for GitHub Sync
# Provides operation and error logging functionality

# Initialize logging
# Creates log directories and files if they don't exist
# Should be called once at the start of sync operations
#
# Usage: init_logging
# Returns: 0 on success, 1 on failure
init_logging() {
  if [[ -z "${WORKWARRIOR_BASE}" ]]; then
    echo "Error: WORKWARRIOR_BASE not set" >&2
    return 1
  fi

  local log_dir="${WORKWARRIOR_BASE}/.task/github-sync"
  
  # Create log directory if it doesn't exist
  if [[ ! -d "${log_dir}" ]]; then
    mkdir -p "${log_dir}" || {
      echo "Error: Failed to create log directory: ${log_dir}" >&2
      return 1
    }
  fi

  # Initialize log files if they don't exist
  local sync_log="${log_dir}/sync.log"
  local error_log="${log_dir}/errors.log"
  
  [[ ! -f "${sync_log}" ]] && touch "${sync_log}"
  [[ ! -f "${error_log}" ]] && touch "${error_log}"

  return 0
}

# Get log file paths
get_sync_log_path() {
  echo "${WORKWARRIOR_BASE}/.task/github-sync/sync.log"
}

get_error_log_path() {
  echo "${WORKWARRIOR_BASE}/.task/github-sync/errors.log"
}

# Log a sync operation
# Logs operation details to sync.log
# Format: timestamp | task_uuid | operation | status | duration | details
#
# Usage: log_sync_operation task_uuid operation status duration [details]
# Example: log_sync_operation "abc123" "push" "success" "2.5" "Updated 3 fields"
# Returns: 0 on success
log_sync_operation() {
  local task_uuid="$1"
  local operation="$2"
  local status="$3"
  local duration="$4"
  local details="${5:-}"
  
  if [[ -z "${task_uuid}" || -z "${operation}" || -z "${status}" ]]; then
    echo "Error: task_uuid, operation, and status required" >&2
    return 1
  fi

  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  
  local log_file
  log_file=$(get_sync_log_path)
  
  # Log format: timestamp | task_uuid | operation | status | duration | details
  local log_entry="${timestamp} | ${task_uuid:0:8} | ${operation} | ${status} | ${duration:-0}s | ${details}"
  
  echo "${log_entry}" >> "${log_file}"
  
  # Also log to stderr if debug mode is enabled
  if [[ "${GITHUB_DEBUG:-false}" == "true" ]]; then
    echo "[SYNC] ${log_entry}" >&2
  fi
  
  return 0
}

# Log an error
# Logs error details to errors.log in JSON format
# Includes timestamp, task_uuid, error_category, field, message, and response
#
# Usage: log_error task_uuid error_category field message [github_response]
# Example: log_error "abc123" "validation" "title" "Title too long" '{"error":"..."}'
# Returns: 0 on success
log_error() {
  local task_uuid="$1"
  local error_category="$2"
  local field="$3"
  local message="$4"
  local github_response="${5:-}"
  
  if [[ -z "${task_uuid}" || -z "${error_category}" || -z "${message}" ]]; then
    echo "Error: task_uuid, error_category, and message required" >&2
    return 1
  fi

  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  
  local log_file
  log_file=$(get_error_log_path)
  
  # Create JSON log entry
  local json_entry
  json_entry=$(jq -n \
    --arg ts "${timestamp}" \
    --arg uuid "${task_uuid}" \
    --arg cat "${error_category}" \
    --arg fld "${field}" \
    --arg msg "${message}" \
    --arg resp "${github_response}" \
    '{
      timestamp: $ts,
      task_uuid: $uuid,
      error_category: $cat,
      field: $fld,
      message: $msg,
      github_response: $resp
    }')
  
  echo "${json_entry}" >> "${log_file}"
  
  # Also log to stderr
  echo "[ERROR] ${error_category}: ${message} (task: ${task_uuid:0:8}, field: ${field})" >&2
  
  return 0
}

# Log a conflict resolution
# Logs conflict resolution details to errors.log
# Includes task_uuid, strategy, winner, and timestamps
#
# Usage: log_conflict_resolution task_uuid strategy winner task_modified github_updated
# Example: log_conflict_resolution "abc123" "last_write_wins" "github" "2024-01-15T10:00:00Z" "2024-01-15T10:30:00Z"
# Returns: 0 on success
log_conflict_resolution() {
  local task_uuid="$1"
  local strategy="$2"
  local winner="$3"
  local task_modified="$4"
  local github_updated="$5"
  
  if [[ -z "${task_uuid}" || -z "${strategy}" || -z "${winner}" ]]; then
    echo "Error: task_uuid, strategy, and winner required" >&2
    return 1
  fi

  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  
  local log_file
  log_file=$(get_error_log_path)
  
  # Create JSON log entry
  local json_entry
  json_entry=$(jq -n \
    --arg ts "${timestamp}" \
    --arg uuid "${task_uuid}" \
    --arg strat "${strategy}" \
    --arg win "${winner}" \
    --arg tm "${task_modified}" \
    --arg gu "${github_updated}" \
    '{
      timestamp: $ts,
      task_uuid: $uuid,
      event: "conflict_resolution",
      strategy: $strat,
      winner: $win,
      task_modified: $tm,
      github_updated: $gu
    }')
  
  echo "${json_entry}" >> "${log_file}"
  
  # Also log to stderr if debug mode is enabled
  if [[ "${GITHUB_DEBUG:-false}" == "true" ]]; then
    echo "[CONFLICT] Resolved using ${strategy}: ${winner} wins (task: ${task_uuid:0:8})" >&2
  fi
  
  return 0
}

# Log operation start
# Records the start of a sync operation
# Returns a start time that can be used to calculate duration
#
# Usage: start_time=$(log_operation_start task_uuid operation)
# Returns: Unix timestamp in seconds
log_operation_start() {
  local task_uuid="$1"
  local operation="$2"
  
  if [[ "${GITHUB_LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
    echo "[START] ${operation} for task ${task_uuid:0:8}" >&2
  fi
  
  date +%s
}

# Log operation end
# Calculates duration and logs the operation
#
# Usage: log_operation_end task_uuid operation status start_time [details]
# Returns: 0 on success
log_operation_end() {
  local task_uuid="$1"
  local operation="$2"
  local status="$3"
  local start_time="$4"
  local details="${5:-}"
  
  local end_time
  end_time=$(date +%s)
  
  local duration=$((end_time - start_time))
  
  log_sync_operation "${task_uuid}" "${operation}" "${status}" "${duration}" "${details}"
}

# Rotate log files if they exceed max size
# Checks log file size and rotates if necessary
# Keeps GITHUB_LOG_ROTATE_COUNT old log files
#
# Usage: rotate_logs
# Returns: 0 on success
rotate_logs() {
  local max_size_mb="${GITHUB_LOG_MAX_SIZE:-10}"
  local max_size_bytes=$((max_size_mb * 1024 * 1024))
  local rotate_count="${GITHUB_LOG_ROTATE_COUNT:-5}"
  
  local sync_log
  sync_log=$(get_sync_log_path)
  local error_log
  error_log=$(get_error_log_path)
  
  # Rotate sync log if needed
  if [[ -f "${sync_log}" ]]; then
    local size
    size=$(stat -f%z "${sync_log}" 2>/dev/null || stat -c%s "${sync_log}" 2>/dev/null || echo 0)
    
    if [[ ${size} -gt ${max_size_bytes} ]]; then
      # Rotate existing logs
      for ((i=rotate_count-1; i>=1; i--)); do
        local old_log="${sync_log}.${i}"
        local new_log="${sync_log}.$((i+1))"
        [[ -f "${old_log}" ]] && mv "${old_log}" "${new_log}"
      done
      
      # Move current log to .1
      mv "${sync_log}" "${sync_log}.1"
      touch "${sync_log}"
      
      echo "Rotated sync log (size: ${size} bytes)" >&2
    fi
  fi
  
  # Rotate error log if needed
  if [[ -f "${error_log}" ]]; then
    local size
    size=$(stat -f%z "${error_log}" 2>/dev/null || stat -c%s "${error_log}" 2>/dev/null || echo 0)
    
    if [[ ${size} -gt ${max_size_bytes} ]]; then
      # Rotate existing logs
      for ((i=rotate_count-1; i>=1; i--)); do
        local old_log="${error_log}.${i}"
        local new_log="${error_log}.$((i+1))"
        [[ -f "${old_log}" ]] && mv "${old_log}" "${new_log}"
      done
      
      # Move current log to .1
      mv "${error_log}" "${error_log}.1"
      touch "${error_log}"
      
      echo "Rotated error log (size: ${size} bytes)" >&2
    fi
  fi
  
  return 0
}

# Get recent sync operations
# Returns the last N lines from sync.log
#
# Usage: get_recent_operations [count]
# Returns: Last N log entries (default: 20)
get_recent_operations() {
  local count="${1:-20}"
  local sync_log
  sync_log=$(get_sync_log_path)
  
  if [[ ! -f "${sync_log}" ]]; then
    echo "No sync operations logged yet"
    return 0
  fi
  
  tail -n "${count}" "${sync_log}"
}

# Get recent errors
# Returns the last N errors from errors.log
#
# Usage: get_recent_errors [count]
# Returns: Last N error entries (default: 10)
get_recent_errors() {
  local count="${1:-10}"
  local error_log
  error_log=$(get_error_log_path)
  
  if [[ ! -f "${error_log}" ]]; then
    echo "No errors logged yet"
    return 0
  fi
  
  tail -n "${count}" "${error_log}"
}

# Display sync statistics
# Shows summary of sync operations from log
#
# Usage: show_sync_stats
# Returns: 0 on success
show_sync_stats() {
  local sync_log
  sync_log=$(get_sync_log_path)
  
  if [[ ! -f "${sync_log}" ]]; then
    echo "No sync operations logged yet"
    return 0
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Sync Statistics"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Total operations
  local total
  total=$(wc -l < "${sync_log}" | tr -d ' ')
  echo "Total operations: ${total}"
  
  # Success count
  local success
  success=$(grep -c "| success |" "${sync_log}" || echo 0)
  echo "Successful: ${success}"
  
  # Failure count
  local failure
  failure=$(grep -c "| failure |" "${sync_log}" || echo 0)
  echo "Failed: ${failure}"
  
  # Operations by type
  echo ""
  echo "By operation type:"
  grep -o "| [a-z_]* |" "${sync_log}" | sort | uniq -c | while read -r count op; do
    op=$(echo "${op}" | tr -d '|' | xargs)
    echo "  ${op}: ${count}"
  done
  
  echo ""
  echo "Recent operations (last 10):"
  tail -n 10 "${sync_log}" | while IFS='|' read -r timestamp uuid operation status duration details; do
    timestamp=$(echo "${timestamp}" | xargs)
    uuid=$(echo "${uuid}" | xargs)
    operation=$(echo "${operation}" | xargs)
    status=$(echo "${status}" | xargs)
    echo "  ${timestamp} | ${uuid} | ${operation} | ${status}"
  done
  
  return 0
}

# Clear old logs
# Removes log entries older than specified days
#
# Usage: clear_old_logs [days]
# Returns: 0 on success
clear_old_logs() {
  local days="${1:-30}"
  local cutoff_date
  cutoff_date=$(date -u -d "${days} days ago" '+%Y-%m-%d' 2>/dev/null || date -u -v-"${days}"d '+%Y-%m-%d' 2>/dev/null)
  
  local sync_log
  sync_log=$(get_sync_log_path)
  local error_log
  error_log=$(get_error_log_path)
  
  # Clear old sync log entries
  if [[ -f "${sync_log}" ]]; then
    local temp_file="${sync_log}.tmp"
    grep -v "^${cutoff_date}" "${sync_log}" > "${temp_file}" || true
    mv "${temp_file}" "${sync_log}"
    echo "Cleared sync log entries older than ${days} days" >&2
  fi
  
  # Clear old error log entries
  if [[ -f "${error_log}" ]]; then
    local temp_file="${error_log}.tmp"
    # For JSON logs, filter by timestamp field
    jq "select(.timestamp >= \"${cutoff_date}\")" "${error_log}" > "${temp_file}" 2>/dev/null || true
    mv "${temp_file}" "${error_log}"
    echo "Cleared error log entries older than ${days} days" >&2
  fi
  
  return 0
}
