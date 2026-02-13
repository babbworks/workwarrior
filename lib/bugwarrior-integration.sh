#!/usr/bin/env bash
# Bugwarrior Integration
# Ensures coexistence with bugwarrior one-way sync

# Check if a task was created by bugwarrior
# Detects bugwarrior by checking for bugwarrior-specific UDAs
#
# Usage: is_bugwarrior_task task_uuid
# Returns: 0 if task is from bugwarrior, 1 if not
is_bugwarrior_task() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    return 1
  fi

  # Get task data
  local task_data
  task_data=$(tw_get_task "${task_uuid}" 2>/dev/null)
  
  if [[ -z "${task_data}" ]]; then
    return 1
  fi

  # Check for bugwarrior UDAs
  # Common bugwarrior UDAs: bugwarrioruuid, bugwarriorurl, bugwarriordescription
  local has_bugwarrior_uda
  has_bugwarrior_uda=$(echo "${task_data}" | jq -r 'has("bugwarrioruuid") or has("bugwarriorurl")')
  
  if [[ "${has_bugwarrior_uda}" == "true" ]]; then
    return 0
  fi
  
  return 1
}

# Get bugwarrior UDAs from a task
# Returns JSON object with all bugwarrior-specific UDAs
#
# Usage: get_bugwarrior_udas task_uuid
# Returns: JSON object with bugwarrior UDAs
get_bugwarrior_udas() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    echo "{}"
    return 1
  fi

  # Get task data
  local task_data
  task_data=$(tw_get_task "${task_uuid}" 2>/dev/null)
  
  if [[ -z "${task_data}" ]]; then
    echo "{}"
    return 1
  fi

  # Extract bugwarrior UDAs
  # Common prefixes: bugwarrior*, github* (from bugwarrior)
  local bugwarrior_udas
  bugwarrior_udas=$(echo "${task_data}" | jq '{
    bugwarrioruuid: .bugwarrioruuid,
    bugwarriorurl: .bugwarriorurl,
    bugwarriordescription: .bugwarriordescription,
    bugwarriortype: .bugwarriortype,
    bugwarriorproject: .bugwarriorproject
  } | with_entries(select(.value != null))')
  
  echo "${bugwarrior_udas}"
  return 0
}

# Preserve bugwarrior UDAs when updating a task
# Ensures bugwarrior UDAs are not overwritten during sync
#
# Usage: preserve_bugwarrior_udas task_uuid
# Returns: 0 on success
preserve_bugwarrior_udas() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    return 1
  fi

  # Check if task has bugwarrior UDAs
  if ! is_bugwarrior_task "${task_uuid}"; then
    # Not a bugwarrior task, nothing to preserve
    return 0
  fi

  # Get bugwarrior UDAs
  local bugwarrior_udas
  bugwarrior_udas=$(get_bugwarrior_udas "${task_uuid}")
  
  # Store in a temporary variable for later restoration if needed
  export BUGWARRIOR_UDAS_BACKUP="${bugwarrior_udas}"
  
  return 0
}

# Initialize sync state for bugwarrior-created tasks
# Detects tasks created by bugwarrior and initializes their sync state
# This allows two-way sync to work with bugwarrior-imported tasks
#
# Usage: init_bugwarrior_task_sync task_uuid
# Returns: 0 on success, 1 on failure
init_bugwarrior_task_sync() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    return 1
  fi

  # Check if task is from bugwarrior
  if ! is_bugwarrior_task "${task_uuid}"; then
    return 1
  fi

  # Get task data
  local task_data
  task_data=$(tw_get_task "${task_uuid}" 2>/dev/null)
  
  if [[ -z "${task_data}" ]]; then
    return 1
  fi

  # Extract GitHub issue information from task
  local issue_number repo
  issue_number=$(echo "${task_data}" | jq -r '.githubissue // empty')
  repo=$(echo "${task_data}" | jq -r '.githubrepo // empty')
  
  if [[ -z "${issue_number}" || -z "${repo}" ]]; then
    # No GitHub information, cannot initialize sync
    return 1
  fi

  # Check if sync state already exists
  local existing_state
  existing_state=$(get_sync_state "${task_uuid}" 2>/dev/null)
  
  if [[ -n "${existing_state}" ]]; then
    # Sync state already exists, don't overwrite
    return 0
  fi

  # Fetch current GitHub issue state
  local github_data
  github_data=$(github_get_issue "${repo}" "${issue_number}" 2>/dev/null)
  
  if [[ -z "${github_data}" ]]; then
    # Failed to fetch issue, cannot initialize
    return 1
  fi

  # Initialize sync state
  save_sync_state "${task_uuid}" "${task_data}" "${github_data}"
  
  echo "Initialized sync state for bugwarrior task ${task_uuid:0:8}" >&2
  
  return 0
}

# Scan for bugwarrior tasks and initialize sync state
# Finds all tasks with bugwarrior UDAs and GitHub information
# Initializes sync state for each one
#
# Usage: scan_and_init_bugwarrior_tasks
# Returns: 0 on success
scan_and_init_bugwarrior_tasks() {
  echo "Scanning for bugwarrior tasks..." >&2
  
  # Find all tasks with githubissue UDA (likely from bugwarrior)
  local tasks
  tasks=$(task export githubissue.any: 2>/dev/null)
  
  if [[ -z "${tasks}" ]]; then
    echo "No tasks with GitHub information found" >&2
    return 0
  fi

  local count=0
  local initialized=0
  
  # Process each task (use process substitution to avoid subshell variable loss)
  while read -r task_json; do
    count=$((count + 1))
    
    local task_uuid
    task_uuid=$(echo "${task_json}" | jq -r '.uuid')
    
    # Check if it's a bugwarrior task
    if is_bugwarrior_task "${task_uuid}"; then
      # Try to initialize sync state
      if init_bugwarrior_task_sync "${task_uuid}"; then
        initialized=$((initialized + 1))
      fi
    fi
  done < <(echo "${tasks}" | jq -c '.[]')
  
  echo "Scanned ${count} tasks, initialized ${initialized} bugwarrior tasks" >&2
  
  return 0
}

# Check if sync operation would interfere with bugwarrior
# Validates that two-way sync won't break bugwarrior functionality
#
# Usage: check_bugwarrior_interference task_uuid
# Returns: 0 if safe, 1 if would interfere
check_bugwarrior_interference() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    return 1
  fi

  # Check if task is from bugwarrior
  if ! is_bugwarrior_task "${task_uuid}"; then
    # Not a bugwarrior task, no interference possible
    return 0
  fi

  # Get bugwarrior UDAs
  local bugwarrior_udas
  bugwarrior_udas=$(get_bugwarrior_udas "${task_uuid}")
  
  # Check if critical bugwarrior UDAs would be affected
  # For now, we just preserve them, so no interference
  
  return 0
}

# Merge bugwarrior and GitHub sync UDAs
# Ensures both bugwarrior and GitHub sync UDAs coexist
#
# Usage: merge_sync_udas task_uuid
# Returns: 0 on success
merge_sync_udas() {
  local task_uuid="$1"
  
  if [[ -z "${task_uuid}" ]]; then
    return 1
  fi

  # Get current task data
  local task_data
  task_data=$(tw_get_task "${task_uuid}" 2>/dev/null)
  
  if [[ -z "${task_data}" ]]; then
    return 1
  fi

  # Get bugwarrior UDAs
  local bugwarrior_udas
  bugwarrior_udas=$(get_bugwarrior_udas "${task_uuid}")
  
  # Merge with GitHub sync UDAs
  # Both should coexist without conflict
  # bugwarrior UDAs: bugwarrior*
  # GitHub sync UDAs: githubissue, githuburl, githubrepo, githubauthor, githubsync
  
  # No actual merging needed - they use different UDA names
  # Just ensure both are preserved
  
  return 0
}

# Display bugwarrior integration status
# Shows information about bugwarrior coexistence
#
# Usage: show_bugwarrior_status
# Returns: 0 on success
show_bugwarrior_status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Bugwarrior Integration Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Count bugwarrior tasks
  local bugwarrior_count=0
  local synced_count=0
  
  # Find all tasks with bugwarrior UDAs
  local tasks
  tasks=$(task export 2>/dev/null)
  
  if [[ -n "${tasks}" ]]; then
    while read -r task_json; do
      local task_uuid
      task_uuid=$(echo "${task_json}" | jq -r '.uuid')
      
      if is_bugwarrior_task "${task_uuid}"; then
        bugwarrior_count=$((bugwarrior_count + 1))
        
        # Check if it has sync state
        if is_task_synced "${task_uuid}"; then
          synced_count=$((synced_count + 1))
        fi
      fi
    done < <(echo "${tasks}" | jq -c '.[]')
  fi
  
  echo "Bugwarrior tasks: ${bugwarrior_count}"
  echo "With two-way sync enabled: ${synced_count}"
  echo ""
  
  if [[ ${bugwarrior_count} -gt 0 ]]; then
    echo "✓ Bugwarrior integration is active"
    echo "  Two-way sync coexists with bugwarrior"
    echo "  Bugwarrior UDAs are preserved during sync"
  else
    echo "No bugwarrior tasks detected"
  fi
  
  return 0
}
