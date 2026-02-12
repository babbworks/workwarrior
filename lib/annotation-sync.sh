#!/usr/bin/env bash
# Annotation/Comment Sync
# Syncs annotations between TaskWarrior and GitHub comments

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/github-api.sh"
source "${SCRIPT_DIR}/taskwarrior-api.sh"
source "${SCRIPT_DIR}/github-sync-state.sh"
source "${SCRIPT_DIR}/field-mapper.sh"
source "${SCRIPT_DIR}/sync-detector.sh"

# Sync annotations to GitHub comments
# Input: task_uuid, issue_number, repo
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_annotations_to_comments() {
    local task_uuid="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_uuid}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task_uuid, issue_number, and repo required" >&2
        return 1
    fi
    
    # Get sync state to find last annotation count
    local state
    state=$(get_sync_state "${task_uuid}")
    
    local last_annotation_count=0
    if [[ -n "${state}" ]]; then
        last_annotation_count=$(echo "${state}" | jq -r '.last_task_state.annotation_count // 0')
    fi
    
    # Detect new annotations
    local new_annotations
    new_annotations=$(detect_new_annotations "${task_uuid}" "${last_annotation_count}")
    
    local new_count
    new_count=$(echo "${new_annotations}" | jq 'length')
    
    if [[ ${new_count} -eq 0 ]]; then
        return 0
    fi
    
    echo "Syncing ${new_count} new annotation(s) to GitHub..." >&2
    
    # Add each new annotation as a comment
    local synced=0
    while IFS= read -r annotation; do
        if [[ -z "${annotation}" || "${annotation}" == "null" ]]; then
            continue
        fi
        
        local annotation_text
        annotation_text=$(echo "${annotation}" | jq -r '.description // ""')
        
        if [[ -z "${annotation_text}" ]]; then
            continue
        fi
        
        # Add TaskWarrior prefix
        local comment_text
        comment_text=$(add_taskwarrior_prefix "${annotation_text}")
        
        # Create comment on GitHub
        if github_add_comment "${repo}" "${issue_number}" "${comment_text}"; then
            synced=$((synced + 1))
        else
            echo "Warning: Failed to sync annotation to GitHub" >&2
        fi
        
    done < <(echo "${new_annotations}" | jq -c '.[]')
    
    echo "✓ Synced ${synced} annotation(s) to GitHub" >&2
    return 0
}

# Sync GitHub comments to TaskWarrior annotations
# Input: task_uuid, issue_number, repo
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_comments_to_annotations() {
    local task_uuid="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_uuid}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task_uuid, issue_number, and repo required" >&2
        return 1
    fi
    
    # Get sync state to find last comment count
    local state
    state=$(get_sync_state "${task_uuid}")
    
    local last_comment_count=0
    if [[ -n "${state}" ]]; then
        last_comment_count=$(echo "${state}" | jq -r '.last_github_state.comment_count // 0')
    fi
    
    # Detect new comments
    local new_comments
    new_comments=$(detect_new_comments "${repo}" "${issue_number}" "${last_comment_count}")
    
    local new_count
    new_count=$(echo "${new_comments}" | jq 'length')
    
    if [[ ${new_count} -eq 0 ]]; then
        return 0
    fi
    
    echo "Syncing ${new_count} new comment(s) to TaskWarrior..." >&2
    
    # Add each new comment as an annotation
    local synced=0
    while IFS= read -r comment; do
        if [[ -z "${comment}" || "${comment}" == "null" ]]; then
            continue
        fi
        
        local comment_body author
        comment_body=$(echo "${comment}" | jq -r '.body // ""')
        author=$(echo "${comment}" | jq -r '.author.login // "unknown"')
        
        if [[ -z "${comment_body}" ]]; then
            continue
        fi
        
        # Skip comments that came from TaskWarrior (have [TaskWarrior] prefix)
        if echo "${comment_body}" | grep -q "^\[TaskWarrior\]"; then
            continue
        fi
        
        # Add GitHub prefix
        local annotation_text
        annotation_text=$(add_github_prefix "${comment_body}" "${author}")
        
        # Create annotation on TaskWarrior
        if tw_add_annotation "${task_uuid}" "${annotation_text}"; then
            synced=$((synced + 1))
        else
            echo "Warning: Failed to sync comment to TaskWarrior" >&2
        fi
        
    done < <(echo "${new_comments}" | jq -c '.[]')
    
    echo "✓ Synced ${synced} comment(s) to TaskWarrior" >&2
    return 0
}

# Sync annotations and comments bidirectionally
# Input: task_uuid, issue_number, repo
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_annotations_bidirectional() {
    local task_uuid="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_uuid}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task_uuid, issue_number, and repo required" >&2
        return 1
    fi
    
    # Sync annotations to comments
    sync_annotations_to_comments "${task_uuid}" "${issue_number}" "${repo}"
    
    # Sync comments to annotations
    sync_comments_to_annotations "${task_uuid}" "${issue_number}" "${repo}"
    
    return 0
}
