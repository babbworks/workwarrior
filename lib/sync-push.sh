#!/usr/bin/env bash
# Push Operations
# Sync from TaskWarrior to GitHub

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/github-api.sh"
source "${SCRIPT_DIR}/taskwarrior-api.sh"
source "${SCRIPT_DIR}/github-sync-state.sh"
source "${SCRIPT_DIR}/field-mapper.sh"
source "${SCRIPT_DIR}/sync-detector.sh"
source "${SCRIPT_DIR}/annotation-sync.sh"
source "${SCRIPT_DIR}/logging.sh"

# Push single task to GitHub
# Input: task_uuid, issue_number, repo
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_push_task() {
    local task_uuid="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_uuid}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task_uuid, issue_number, and repo required" >&2
        return 1
    fi
    
    # Get current task state
    local task_data
    task_data=$(tw_get_task "${task_uuid}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch task ${task_uuid}: ${task_data}" >&2
        return 1
    fi
    
    # Get current GitHub issue state
    local github_data
    github_data=$(github_get_issue "${repo}" "${issue_number}" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch issue #${issue_number}: ${github_data}" >&2
        return 1
    fi
    
    # Get last known state
    local last_state
    last_state=$(get_sync_state "${task_uuid}" 2>/dev/null)
    
    # Detect changes (if we have last state)
    if [[ -n "${last_state}" ]]; then
        local last_task_state
        last_task_state=$(echo "${last_state}" | jq -c '.last_task_state')
        
        local changes
        if ! changes=$(detect_task_changes "${task_uuid}" "${task_data}" "${last_task_state}"); then
            echo "No changes detected for task ${task_uuid:0:8}" >&2
            return 0
        fi
    fi
    
    # Map TaskWarrior fields to GitHub format
    local description status priority tags
    description=$(echo "${task_data}" | jq -r '.description // ""')
    status=$(echo "${task_data}" | jq -r '.status // ""')
    priority=$(echo "${task_data}" | jq -r '.priority // ""')
    tags=$(echo "${task_data}" | jq -c '.tags // []')
    
    # Map status to state
    local gh_state
    gh_state=$(map_status_to_github "${status}")
    
    # Truncate title if needed
    local gh_title
    gh_title=$(truncate_title "${description}" 256)
    
    # Map priority to label
    local priority_label
    priority_label=$(map_priority_to_label "${priority}")
    
    # Map tags to labels
    local gh_labels
    gh_labels=$(map_tags_to_labels "${tags}")
    
    # Update issue on GitHub
    echo "Pushing task ${task_uuid:0:8} → issue #${issue_number}..." >&2
    
    # Update title and state
    if ! github_update_issue "${repo}" "${issue_number}" "${gh_title}" "${gh_state}"; then
        echo "Error: Failed to update issue title/state" >&2
        return 1
    fi
    
    # Get current labels to determine what to add/remove
    local current_labels
    current_labels=$(echo "${github_data}" | jq -c '[.labels[]?.name] // []')
    
    # Get current priority labels
    local current_priority_labels
    current_priority_labels=$(get_priority_labels "${current_labels}")
    
    # Build labels to add/remove
    local labels_to_add="${gh_labels}"
    local labels_to_remove=""
    
    # Add priority label if set
    if [[ -n "${priority_label}" ]]; then
        # Ensure priority label exists (failure is a warning, not fatal — label may already exist)
        if ! github_ensure_label "${repo}" "${priority_label}"; then
            echo "Warning: Failed to ensure priority label '${priority_label}' exists in ${repo}" >&2
        fi

        if [[ -n "${labels_to_add}" ]]; then
            labels_to_add="${labels_to_add},${priority_label}"
        else
            labels_to_add="${priority_label}"
        fi

        # Remove old priority labels if different
        if [[ -n "${current_priority_labels}" && "${current_priority_labels}" != "${priority_label}" ]]; then
            labels_to_remove="${current_priority_labels}"
        fi
    else
        # No priority set - remove any priority labels
        if [[ -n "${current_priority_labels}" ]]; then
            labels_to_remove="${current_priority_labels}"
        fi
    fi

    # Ensure all labels exist before adding
    if [[ -n "${gh_labels}" ]]; then
        IFS=',' read -ra label_array <<< "${gh_labels}"
        for label in "${label_array[@]}"; do
            if ! github_ensure_label "${repo}" "${label}"; then
                echo "Warning: Failed to ensure label '${label}' exists in ${repo}" >&2
            fi
        done
    fi
    
    # Update labels
    if [[ -n "${labels_to_add}" || -n "${labels_to_remove}" ]]; then
        if ! github_update_labels "${repo}" "${issue_number}" "${labels_to_add}" "${labels_to_remove}"; then
            echo "Warning: Failed to update labels" >&2
        fi
    fi
    
    # Sync annotations to comments
    sync_annotations_to_comments "${task_uuid}" "${issue_number}" "${repo}"
    
    # Update sync state
    github_data=$(github_get_issue "${repo}" "${issue_number}")
    save_sync_state "${task_uuid}" "${task_data}" "${github_data}"
    
    echo "✓ Pushed task ${task_uuid:0:8}" >&2
    return 0
}

# Push all synced tasks to GitHub
# Input: None
# Output: Summary of push operations
# Returns: 0 on success
sync_push_all() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Push All: TaskWarrior → GitHub" >&2
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
        
        # Push the task
        if sync_push_task "${task_uuid}" "${issue_number}" "${repo}"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        
    done <<< "${synced_tasks}"
    
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Push Summary" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Total: ${total}" >&2
    echo "Success: ${success}" >&2
    echo "Failed: ${failed}" >&2
    echo "" >&2

    if [[ "${failed}" -gt 0 ]]; then
        return 1
    fi
    return 0
}
