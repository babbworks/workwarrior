#!/usr/bin/env bash
# GitHub Sync State Manager
# Manages sync state database for change detection and conflict resolution

# Initialize state database
# Creates state.json if missing with proper permissions
# Input: None (uses WORKWARRIOR_BASE environment variable)
# Output: Creates state.json if missing
# Returns: 0 on success, 1 on failure
init_state_database() {
    local state_dir="${WORKWARRIOR_BASE}/.task/github-sync"
    local state_file="${state_dir}/state.json"
    
    # Check if WORKWARRIOR_BASE is set
    if [[ -z "${WORKWARRIOR_BASE}" ]]; then
        echo "Error: WORKWARRIOR_BASE not set. Activate a profile first." >&2
        return 1
    fi
    
    # Create directory if missing
    if [[ ! -d "${state_dir}" ]]; then
        mkdir -p "${state_dir}" || {
            echo "Error: Failed to create state directory: ${state_dir}" >&2
            return 1
        }
    fi
    
    # Create state file if missing
    if [[ ! -f "${state_file}" ]]; then
        echo "{}" > "${state_file}" || {
            echo "Error: Failed to create state file: ${state_file}" >&2
            return 1
        }
        chmod 600 "${state_file}"
    fi
    
    # Verify state file is valid JSON
    if ! jq empty "${state_file}" 2>/dev/null; then
        echo "Warning: State file corrupted, re-initializing..." >&2
        echo "{}" > "${state_file}"
        chmod 600 "${state_file}"
    fi
    
    return 0
}

# Get sync state for a task
# Input: task_uuid (string)
# Output: JSON object with sync state (to stdout)
# Returns: 0 on success, 1 if not found
get_sync_state() {
    local task_uuid="$1"
    local state_file="${WORKWARRIOR_BASE}/.task/github-sync/state.json"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    if [[ ! -f "${state_file}" ]]; then
        init_state_database || return 1
    fi
    
    local state
    state=$(jq -r ".\"${task_uuid}\" // empty" "${state_file}" 2>/dev/null)
    
    if [[ -z "${state}" || "${state}" == "null" ]]; then
        return 1
    fi
    
    echo "${state}"
    return 0
}

# Save sync state for a task
# Input: task_uuid (string), task_data (JSON string), github_data (JSON string)
# Output: Updates state.json
# Returns: 0 on success, 1 on failure
save_sync_state() {
    local task_uuid="$1"
    local task_data="$2"
    local github_data="$3"
    local state_file="${WORKWARRIOR_BASE}/.task/github-sync/state.json"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    if [[ -z "${task_data}" ]]; then
        echo "Error: task_data required" >&2
        return 1
    fi
    
    if [[ -z "${github_data}" ]]; then
        echo "Error: github_data required" >&2
        return 1
    fi
    
    # Ensure state database exists
    init_state_database || return 1
    
    # Extract relevant fields from task data
    local description status priority tags annotation_count modified
    description=$(echo "${task_data}" | jq -r '.description // ""')
    status=$(echo "${task_data}" | jq -r '.status // ""')
    priority=$(echo "${task_data}" | jq -r '.priority // ""')
    tags=$(echo "${task_data}" | jq -c '.tags // []')
    annotation_count=$(echo "${task_data}" | jq '.annotations | length // 0')
    modified=$(echo "${task_data}" | jq -r '.modified // ""')
    
    # Extract relevant fields from GitHub data
    local title state labels comment_count updated_at issue_number repo url
    title=$(echo "${github_data}" | jq -r '.title // ""')
    state=$(echo "${github_data}" | jq -r '.state // ""')
    labels=$(echo "${github_data}" | jq -c '[.labels[]?.name] // []')
    comment_count=$(echo "${github_data}" | jq '.comments | length // 0')
    updated_at=$(echo "${github_data}" | jq -r '.updatedAt // ""')
    issue_number=$(echo "${github_data}" | jq -r '.number // ""')
    repo=$(echo "${github_data}" | jq -r '.repository.nameWithOwner // ""')
    url=$(echo "${github_data}" | jq -r '.url // ""')
    
    # Build state object
    local state_object
    state_object=$(jq -n \
        --arg issue "${issue_number}" \
        --arg repo "${repo}" \
        --arg url "${url}" \
        --arg last_sync "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg desc "${description}" \
        --arg status "${status}" \
        --arg priority "${priority}" \
        --argjson tags "${tags}" \
        --arg annotation_count "${annotation_count}" \
        --arg modified "${modified}" \
        --arg title "${title}" \
        --arg gh_state "${state}" \
        --argjson labels "${labels}" \
        --arg comment_count "${comment_count}" \
        --arg updated_at "${updated_at}" \
        '{
            github_issue: $issue,
            github_repo: $repo,
            github_url: $url,
            sync_enabled: true,
            last_sync: $last_sync,
            last_task_state: {
                description: $desc,
                status: $status,
                priority: $priority,
                tags: $tags,
                annotation_count: ($annotation_count | tonumber),
                modified: $modified
            },
            last_github_state: {
                title: $title,
                state: $gh_state,
                labels: $labels,
                comment_count: ($comment_count | tonumber),
                updated_at: $updated_at
            },
            sync_metadata: {
                synced_annotations: [],
                synced_comments: [],
                last_annotation_count: ($annotation_count | tonumber),
                last_comment_count: ($comment_count | tonumber)
            },
            conflict_strategy: "last_write_wins"
        }')
    
    # Update state file
    local temp_file="${state_file}.tmp"
    jq --arg uuid "${task_uuid}" \
       --argjson state "${state_object}" \
       '.[$uuid] = $state' \
       "${state_file}" > "${temp_file}" || {
        echo "Error: Failed to update state file" >&2
        rm -f "${temp_file}"
        return 1
    }
    
    mv "${temp_file}" "${state_file}"
    chmod 600 "${state_file}"
    return 0
}

# Check if task is synced
# Input: task_uuid (string)
# Output: None
# Returns: 0 if synced, 1 if not
is_task_synced() {
    local task_uuid="$1"
    
    if [[ -z "${task_uuid}" ]]; then
        return 1
    fi
    
    get_sync_state "${task_uuid}" >/dev/null 2>&1
    return $?
}

# Get all synced tasks
# Input: None
# Output: Array of task UUIDs (one per line)
# Returns: 0 on success
get_all_synced_tasks() {
    local state_file="${WORKWARRIOR_BASE}/.task/github-sync/state.json"
    
    if [[ ! -f "${state_file}" ]]; then
        init_state_database || return 1
    fi
    
    jq -r 'keys[]' "${state_file}" 2>/dev/null
    return 0
}

# Remove sync state
# Input: task_uuid (string)
# Output: Removes entry from state.json
# Returns: 0 on success, 1 on failure
remove_sync_state() {
    local task_uuid="$1"
    local state_file="${WORKWARRIOR_BASE}/.task/github-sync/state.json"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    if [[ ! -f "${state_file}" ]]; then
        # Nothing to remove
        return 0
    fi
    
    local temp_file="${state_file}.tmp"
    jq --arg uuid "${task_uuid}" 'del(.[$uuid])' "${state_file}" > "${temp_file}" || {
        echo "Error: Failed to remove state" >&2
        rm -f "${temp_file}"
        return 1
    }
    
    mv "${temp_file}" "${state_file}"
    chmod 600 "${state_file}"
    return 0
}
