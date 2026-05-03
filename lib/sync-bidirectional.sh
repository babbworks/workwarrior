#!/usr/bin/env bash
# Bidirectional Sync
# Sync between TaskWarrior and GitHub (both directions)

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/github-api.sh"
source "${SCRIPT_DIR}/taskwarrior-api.sh"
source "${SCRIPT_DIR}/github-sync-state.sh"
source "${SCRIPT_DIR}/sync-detector.sh"
source "${SCRIPT_DIR}/conflict-resolver.sh"
source "${SCRIPT_DIR}/annotation-sync.sh"
source "${SCRIPT_DIR}/sync-pull.sh"
source "${SCRIPT_DIR}/sync-push.sh"
source "${SCRIPT_DIR}/logging.sh"

# Sync single task bidirectionally
# Input: task_uuid
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_task_bidirectional() {
    local task_uuid="$1"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    # Get sync state
    local state
    state=$(get_sync_state "${task_uuid}")
    
    if [[ -z "${state}" ]]; then
        echo "Error: Task ${task_uuid:0:8} is not synced" >&2
        return 1
    fi
    
    local issue_number repo
    issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
    repo=$(echo "${state}" | jq -r '.github_repo // ""')
    
    if [[ -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: Missing issue number or repo for task ${task_uuid:0:8}" >&2
        return 1
    fi
    
    # Fetch current states
    local task_data github_data
    task_data=$(tw_get_task "${task_uuid}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch task ${task_uuid:0:8}: ${task_data}" >&2
        return 1
    fi
    
    github_data=$(github_get_issue "${repo}" "${issue_number}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch issue #${issue_number}: ${github_data}" >&2
        return 1
    fi
    
    # Get last known states
    local last_task_state last_github_state
    last_task_state=$(echo "${state}" | jq -c '.last_task_state')
    last_github_state=$(echo "${state}" | jq -c '.last_github_state')
    
    # Detect changes on both sides
    local task_changed=1
    local github_changed=1
    
    if detect_task_changes "${task_uuid}" "${task_data}" "${last_task_state}" >/dev/null 2>&1; then
        task_changed=0
    fi
    
    if detect_github_changes "${issue_number}" "${github_data}" "${last_github_state}" >/dev/null 2>&1; then
        github_changed=0
    fi
    
    # Determine sync action
    local action
    action=$(determine_sync_action "${task_changed}" "${github_changed}")
    
    echo "Syncing task ${task_uuid:0:8} ↔ issue #${issue_number}: ${action}" >&2
    
    case "${action}" in
        push)
            # Only task changed - push to GitHub
            sync_push_task "${task_uuid}" "${issue_number}" "${repo}"
            ;;
        pull)
            # Only GitHub changed - pull from GitHub
            sync_pull_issue "${task_uuid}" "${issue_number}" "${repo}"
            ;;
        conflict)
            # Both changed - resolve conflict
            echo "⚠ Conflict detected - resolving..." >&2
            
            local resolution
            resolution=$(resolve_conflict_last_write_wins "${task_uuid}" "${task_data}" "${github_data}")
            
            # Log conflict resolution
            local task_modified github_updated
            task_modified=$(echo "${task_data}" | jq -r '.modified // ""')
            github_updated=$(echo "${github_data}" | jq -r '.updatedAt // ""')
            
            log_conflict_resolution "${task_uuid}" "last_write_wins" "${resolution}" "${task_modified}" "${github_updated}"
            
            case "${resolution}" in
                push)
                    echo "  → Task is newer, pushing to GitHub" >&2
                    sync_push_task "${task_uuid}" "${issue_number}" "${repo}"
                    ;;
                pull)
                    echo "  → GitHub is newer, pulling from GitHub" >&2
                    sync_pull_issue "${task_uuid}" "${issue_number}" "${repo}"
                    ;;
                *)
                    echo "Error: Unknown resolution '${resolution}'" >&2
                    return 1
                    ;;
            esac
            ;;
        none)
            # No changes - still sync annotations/comments
            echo "No field changes detected, syncing annotations/comments..." >&2
            sync_annotations_bidirectional "${task_uuid}" "${issue_number}" "${repo}"
            echo "✓ Annotations/comments synced" >&2
            return 0
            ;;
        *)
            echo "Error: Unknown action '${action}'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Sync all tasks bidirectionally
# Input: None
# Output: Summary of sync operations
# Returns: 0 on success
sync_all_tasks() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Bidirectional Sync: TaskWarrior ↔ GitHub" >&2
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
    local conflicts=0
    
    while IFS= read -r task_uuid; do
        if [[ -z "${task_uuid}" ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        # Sync the task
        if sync_task_bidirectional "${task_uuid}"; then
            success=$((success + 1))
            
            # Check if it was a conflict
            if grep -q "Conflict detected" <<< "$(sync_task_bidirectional "${task_uuid}" 2>&1)"; then
                conflicts=$((conflicts + 1))
            fi
        else
            failed=$((failed + 1))
        fi
        
    done <<< "${synced_tasks}"
    
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Sync Summary" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Total: ${total}" >&2
    echo "Success: ${success}" >&2
    echo "Failed: ${failed}" >&2
    echo "Conflicts resolved: ${conflicts}" >&2
    echo "" >&2
    
    return 0
}
