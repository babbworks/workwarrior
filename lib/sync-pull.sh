#!/usr/bin/env bash
# Pull Operations
# Sync from GitHub to TaskWarrior

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/github-api.sh"
source "${SCRIPT_DIR}/taskwarrior-api.sh"
source "${SCRIPT_DIR}/github-sync-state.sh"
source "${SCRIPT_DIR}/field-mapper.sh"
source "${SCRIPT_DIR}/sync-detector.sh"
source "${SCRIPT_DIR}/annotation-sync.sh"
source "${SCRIPT_DIR}/logging.sh"

# Pull single issue from GitHub to TaskWarrior
# Input: task_uuid, issue_number, repo
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_pull_issue() {
    local task_uuid="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_uuid}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task_uuid, issue_number, and repo required" >&2
        return 1
    fi
    
    # Fetch current issue from GitHub
    local github_data
    github_data=$(github_get_issue "${repo}" "${issue_number}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch issue #${issue_number}: ${github_data}" >&2
        return 1
    fi
    
    # Get current task state
    local task_data
    task_data=$(tw_get_task "${task_uuid}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch task ${task_uuid}: ${task_data}" >&2
        return 1
    fi
    
    # Get last known state
    local last_state
    last_state=$(get_sync_state "${task_uuid}" 2>/dev/null)
    
    # Detect changes (if we have last state)
    if [[ -n "${last_state}" ]]; then
        local last_github_state
        last_github_state=$(echo "${last_state}" | jq -c '.last_github_state')
        
        local changes
        if ! changes=$(detect_github_changes "${issue_number}" "${github_data}" "${last_github_state}"); then
            echo "No changes detected for issue #${issue_number}" >&2
            return 0
        fi
    fi
    
    # Map GitHub fields to TaskWarrior format
    local title state state_reason labels priority tags
    title=$(echo "${github_data}" | jq -r '.title // ""')
    state=$(echo "${github_data}" | jq -r '.state // ""')
    state_reason=$(echo "${github_data}" | jq -r '.stateReason // ""')
    labels=$(echo "${github_data}" | jq -c '[.labels[]?.name] // []')
    
    # Map state to status
    local tw_status
    tw_status=$(map_github_to_status "${state}" "${state_reason}")
    
    # Map labels to priority
    priority=$(map_labels_to_priority "${labels}")
    
    # Map labels to tags
    tags=$(map_labels_to_tags "${labels}")
    
    # Update task fields
    echo "Pulling issue #${issue_number} → task ${task_uuid:0:8}..." >&2
    
    # Update description
    if ! tw_update_task "${task_uuid}" "description" "${title}"; then
        echo "Warning: Failed to update description" >&2
    fi
    
    # Update status
    if ! tw_update_task "${task_uuid}" "status" "${tw_status}"; then
        echo "Warning: Failed to update status" >&2
    fi
    
    # Update priority
    if ! tw_update_task "${task_uuid}" "priority" "${priority}"; then
        echo "Warning: Failed to update priority" >&2
    fi
    
    # Update tags (remove all non-system tags, then add new ones)
    # This is complex - for now, we'll skip tag sync in pull
    # TODO: Implement proper tag sync
    
    # Populate metadata UDAs
    local issue_num url author created_at closed_at
    issue_num=$(echo "${github_data}" | jq -r '.number // ""')
    url=$(echo "${github_data}" | jq -r '.url // ""')
    author=$(echo "${github_data}" | jq -r '.author.login // ""')
    created_at=$(echo "${github_data}" | jq -r '.createdAt // ""')
    closed_at=$(echo "${github_data}" | jq -r '.closedAt // ""')
    
    tw_update_task "${task_uuid}" "githubissue" "${issue_num}" 2>/dev/null
    tw_update_task "${task_uuid}" "githuburl" "${url}" 2>/dev/null
    tw_update_task "${task_uuid}" "githubrepo" "${repo}" 2>/dev/null
    tw_update_task "${task_uuid}" "githubauthor" "${author}" 2>/dev/null
    
    # Set entry date on first sync (if not already set)
    local current_entry
    current_entry=$(tw_get_field "${task_uuid}" "entry")
    if [[ -z "${current_entry}" && -n "${created_at}" ]]; then
        # Convert ISO 8601 to TaskWarrior format
        local tw_entry
        tw_entry=$(echo "${created_at}" | sed 's/[-:]//g' | sed 's/\.[0-9]*Z/Z/')
        tw_update_task "${task_uuid}" "entry" "${tw_entry}" 2>/dev/null
    fi
    
    # Set end date if issue is closed
    if [[ "${tw_status}" == "completed" && -n "${closed_at}" ]]; then
        local tw_end
        tw_end=$(echo "${closed_at}" | sed 's/[-:]//g' | sed 's/\.[0-9]*Z/Z/')
        tw_update_task "${task_uuid}" "end" "${tw_end}" 2>/dev/null
    fi
    
    # Sync comments to annotations
    sync_comments_to_annotations "${task_uuid}" "${issue_number}" "${repo}"
    
    # Update sync state
    task_data=$(tw_get_task "${task_uuid}")
    save_sync_state "${task_uuid}" "${task_data}" "${github_data}"
    
    echo "✓ Pulled issue #${issue_number}" >&2
    return 0
}

# Pull all synced issues from GitHub
# Input: None
# Output: Summary of pull operations
# Returns: 0 on success
sync_pull_all() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Pull All: GitHub → TaskWarrior" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    # Get all synced tasks
    local synced_tasks
    synced_tasks=$(get_all_synced_tasks)
    
    if [[ -z "${synced_tasks}" ]]; then
        echo "No synced tasks found" >&2
        return 0
    fi
    
    local total=0
    local success=0
    local failed=0
    
    while IFS= read -r task_uuid; do
        if [[ -z "${task_uuid}" ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        # Get sync state to find issue number and repo
        local state
        state=$(get_sync_state "${task_uuid}")
        
        if [[ -z "${state}" ]]; then
            echo "⊘ Skipping ${task_uuid:0:8}: No sync state" >&2
            failed=$((failed + 1))
            continue
        fi
        
        local issue_number repo
        issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
        repo=$(echo "${state}" | jq -r '.github_repo // ""')
        
        if [[ -z "${issue_number}" || -z "${repo}" ]]; then
            echo "⊘ Skipping ${task_uuid:0:8}: Missing issue number or repo" >&2
            failed=$((failed + 1))
            continue
        fi
        
        # Pull the issue
        if sync_pull_issue "${task_uuid}" "${issue_number}" "${repo}"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        
    done <<< "${synced_tasks}"
    
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Pull Summary" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Total: ${total}" >&2
    echo "Success: ${success}" >&2
    echo "Failed: ${failed}" >&2
    echo "" >&2
    
    return 0
}
