#!/usr/bin/env bash
# Change Detector
# Detects what changed since last sync

# Source field mapper for comparisons
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/field-mapper.sh"

# Detect task changes
# Input: task_uuid, current_state (JSON), last_state (JSON)
# Output: JSON object with changed fields to stdout
# Returns: 0 if changes detected, 1 if no changes
detect_task_changes() {
    local task_uuid="$1"
    local current_state="$2"
    local last_state="$3"
    
    if [[ -z "${current_state}" || -z "${last_state}" ]]; then
        echo "Error: current_state and last_state required" >&2
        return 1
    fi

    # Validate inputs are parseable JSON — prevents silent jq failures and empty changes
    if ! echo "${current_state}" | jq empty >/dev/null 2>&1; then
        echo "Error: current_state is not valid JSON" >&2
        return 2
    fi
    if ! echo "${last_state}" | jq empty >/dev/null 2>&1; then
        echo "Error: last_state is not valid JSON" >&2
        return 2
    fi

    local changes="{}"
    local has_changes=false

    # Extract current values
    local curr_desc curr_status curr_priority curr_tags curr_ann_count
    curr_desc=$(echo "${current_state}" | jq -r '.description // ""')
    curr_status=$(echo "${current_state}" | jq -r '.status // ""')
    curr_priority=$(echo "${current_state}" | jq -r '.priority // ""')
    curr_tags=$(echo "${current_state}" | jq -c '.tags // []')
    curr_ann_count=$(echo "${current_state}" | jq '.annotations | length // 0')
    
    # Extract last known values
    local last_desc last_status last_priority last_tags last_ann_count
    last_desc=$(echo "${last_state}" | jq -r '.description // ""')
    last_status=$(echo "${last_state}" | jq -r '.status // ""')
    last_priority=$(echo "${last_state}" | jq -r '.priority // ""')
    last_tags=$(echo "${last_state}" | jq -c '.tags // []')
    last_ann_count=$(echo "${last_state}" | jq -r '.annotation_count // 0')
    
    # Compare description
    if [[ "${curr_desc}" != "${last_desc}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "description" --arg old "${last_desc}" --arg new "${curr_desc}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare status
    if [[ "${curr_status}" != "${last_status}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "status" --arg old "${last_status}" --arg new "${curr_status}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare priority
    if [[ "${curr_priority}" != "${last_priority}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "priority" --arg old "${last_priority}" --arg new "${curr_priority}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare tags (as sorted arrays)
    local curr_tags_sorted last_tags_sorted
    curr_tags_sorted=$(echo "${curr_tags}" | jq -c 'sort')
    last_tags_sorted=$(echo "${last_tags}" | jq -c 'sort')
    
    if [[ "${curr_tags_sorted}" != "${last_tags_sorted}" ]]; then
        changes=$(echo "${changes}" | jq --argjson old "${last_tags}" --argjson new "${curr_tags}" \
            '. + {tags: {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare annotation count
    if [[ "${curr_ann_count}" != "${last_ann_count}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "annotation_count" --argjson old "${last_ann_count}" --argjson new "${curr_ann_count}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    echo "${changes}"
    
    if [[ "${has_changes}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Detect GitHub changes
# Input: issue_number, current_state (JSON), last_state (JSON)
# Output: JSON object with changed fields to stdout
# Returns: 0 if changes detected, 1 if no changes
detect_github_changes() {
    local issue_number="$1"
    local current_state="$2"
    local last_state="$3"
    
    if [[ -z "${current_state}" || -z "${last_state}" ]]; then
        echo "Error: current_state and last_state required" >&2
        return 1
    fi

    # Validate inputs are parseable JSON — prevents silent jq failures and empty changes
    if ! echo "${current_state}" | jq empty >/dev/null 2>&1; then
        echo "Error: current_state is not valid JSON" >&2
        return 2
    fi
    if ! echo "${last_state}" | jq empty >/dev/null 2>&1; then
        echo "Error: last_state is not valid JSON" >&2
        return 2
    fi

    local changes="{}"
    local has_changes=false

    # Extract current values
    local curr_title curr_state curr_labels curr_comment_count
    curr_title=$(echo "${current_state}" | jq -r '.title // ""')
    curr_state=$(echo "${current_state}" | jq -r '.state // ""')
    curr_labels=$(echo "${current_state}" | jq -c '[.labels[]?.name] // []')
    curr_comment_count=$(echo "${current_state}" | jq '.comments | length // 0')
    
    # Extract last known values
    local last_title last_state_val last_labels last_comment_count
    last_title=$(echo "${last_state}" | jq -r '.title // ""')
    last_state_val=$(echo "${last_state}" | jq -r '.state // ""')
    last_labels=$(echo "${last_state}" | jq -c '.labels // []')
    last_comment_count=$(echo "${last_state}" | jq -r '.comment_count // 0')
    
    # Compare title
    if [[ "${curr_title}" != "${last_title}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "title" --arg old "${last_title}" --arg new "${curr_title}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare state
    if [[ "${curr_state}" != "${last_state_val}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "state" --arg old "${last_state_val}" --arg new "${curr_state}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare labels (as sorted arrays)
    local curr_labels_sorted last_labels_sorted
    curr_labels_sorted=$(echo "${curr_labels}" | jq -c 'sort')
    last_labels_sorted=$(echo "${last_labels}" | jq -c 'sort')
    
    if [[ "${curr_labels_sorted}" != "${last_labels_sorted}" ]]; then
        changes=$(echo "${changes}" | jq --argjson old "${last_labels}" --argjson new "${curr_labels}" \
            '. + {labels: {old: $old, new: $new}}')
        has_changes=true
    fi
    
    # Compare comment count
    if [[ "${curr_comment_count}" != "${last_comment_count}" ]]; then
        changes=$(echo "${changes}" | jq --arg field "comment_count" --argjson old "${last_comment_count}" --argjson new "${curr_comment_count}" \
            '. + {($field): {old: $old, new: $new}}')
        has_changes=true
    fi
    
    echo "${changes}"
    
    if [[ "${has_changes}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Determine sync action
# Input: task_changed (boolean 0/1), github_changed (boolean 0/1)
# Output: action (push|pull|conflict|none) to stdout
# Returns: 0 on success
determine_sync_action() {
    local task_changed="$1"
    local github_changed="$2"
    
    if [[ "${task_changed}" == "0" && "${github_changed}" == "0" ]]; then
        # Both changed - conflict
        echo "conflict"
    elif [[ "${task_changed}" == "0" && "${github_changed}" != "0" ]]; then
        # Only task changed - push
        echo "push"
    elif [[ "${task_changed}" != "0" && "${github_changed}" == "0" ]]; then
        # Only GitHub changed - pull
        echo "pull"
    else
        # Neither changed - no action
        echo "none"
    fi
    
    return 0
}

# Detect new annotations
# Input: task_uuid, last_annotation_count (integer)
# Output: JSON array of new annotation texts to stdout
# Returns: 0 on success
detect_new_annotations() {
    local task_uuid="$1"
    local last_annotation_count="$2"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    # Get current task
    local task_data
    task_data=$(task "${task_uuid}" export 2>/dev/null | jq '.[0]')
    
    if [[ -z "${task_data}" || "${task_data}" == "null" ]]; then
        echo "[]"
        return 0
    fi
    
    # Get all annotations
    local annotations
    annotations=$(echo "${task_data}" | jq -c '.annotations // []')
    
    local current_count
    current_count=$(echo "${annotations}" | jq 'length')
    
    # If no new annotations, return empty array
    if [[ ${current_count} -le ${last_annotation_count} ]]; then
        echo "[]"
        return 0
    fi
    
    # Get new annotations (skip first last_annotation_count)
    local new_annotations
    new_annotations=$(echo "${annotations}" | jq -c ".[${last_annotation_count}:]")
    
    echo "${new_annotations}"
    return 0
}

# Detect new comments
# Input: repo, issue_number, last_comment_count (integer)
# Output: JSON array of new comment objects to stdout
# Returns: 0 on success
detect_new_comments() {
    local repo="$1"
    local issue_number="$2"
    local last_comment_count="$3"
    
    if [[ -z "${repo}" || -z "${issue_number}" ]]; then
        echo "Error: repo and issue_number required" >&2
        return 1
    fi
    
    # Source GitHub API if not already loaded
    if ! declare -f github_get_issue >/dev/null 2>&1; then
        source "${SCRIPT_DIR}/github-api.sh"
    fi
    
    # Get current issue
    local issue_data
    issue_data=$(github_get_issue "${repo}" "${issue_number}" 2>/dev/null)
    
    if [[ -z "${issue_data}" || "${issue_data}" == "null" ]]; then
        echo "[]"
        return 0
    fi
    
    # Get all comments
    local comments
    comments=$(echo "${issue_data}" | jq -c '.comments // []')
    
    local current_count
    current_count=$(echo "${comments}" | jq 'length')
    
    # If no new comments, return empty array
    if [[ ${current_count} -le ${last_comment_count} ]]; then
        echo "[]"
        return 0
    fi
    
    # Get new comments (skip first last_comment_count)
    local new_comments
    new_comments=$(echo "${comments}" | jq -c ".[${last_comment_count}:]")
    
    echo "${new_comments}"
    return 0
}

# Check if there are conflicts
# Input: task_changed (boolean 0/1), github_changed (boolean 0/1)
# Output: None
# Returns: 0 if conflict, 1 if no conflict
has_conflicts() {
    local task_changed="$1"
    local github_changed="$2"
    
    if [[ "${task_changed}" == "0" && "${github_changed}" == "0" ]]; then
        return 0  # Conflict
    else
        return 1  # No conflict
    fi
}
