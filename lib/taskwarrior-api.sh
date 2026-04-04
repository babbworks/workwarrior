#!/usr/bin/env bash
# TaskWarrior API Wrapper
# Provides shell functions for TaskWarrior operations

# Get task details
# Input: task_uuid (string)
# Output: JSON object with task data (to stdout)
# Returns: 0 on success, 1 on failure
tw_get_task() {
    local task_uuid="$1"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    # Export task as JSON - TaskWarrior syntax is: task <uuid> export
    local task_data
    task_data=$(task "${task_uuid}" export 2>/dev/null)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 || -z "${task_data}" || "${task_data}" == "[]" ]]; then
        echo "Error: Task ${task_uuid} not found" >&2
        return 1
    fi
    
    # task export returns an array, extract first element
    local task_json
    task_json=$(echo "${task_data}" | jq '.[0]' 2>/dev/null)
    
    if [[ -z "${task_json}" || "${task_json}" == "null" ]]; then
        echo "Error: Failed to parse task data" >&2
        return 1
    fi
    
    echo "${task_json}"
    return 0
}

# Update task fields
# Input: task_uuid, field_name, field_value
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
tw_update_task() {
    local task_uuid="$1"
    local field_name="$2"
    local field_value="$3"
    
    if [[ -z "${task_uuid}" || -z "${field_name}" ]]; then
        echo "Error: task_uuid and field_name required" >&2
        return 1
    fi
    
    # Build modify command - TaskWarrior syntax is: task <uuid> modify <field>:<value>
    local result
    if [[ -z "${field_value}" ]]; then
        # Remove field (empty value)
        result=$(task "${task_uuid}" modify "${field_name}:" 2>&1)
    else
        # Set field value
        result=$(task "${task_uuid}" modify "${field_name}:${field_value}" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to update task: ${result}" >&2
        return 1
    fi
    
    return 0
}

# Update multiple task fields at once
# Input: task_uuid, field1:value1, field2:value2, ...
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
tw_update_task_fields() {
    local task_uuid="$1"
    shift
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    if [[ $# -eq 0 ]]; then
        echo "Error: At least one field update required" >&2
        return 1
    fi
    
    # Build modify command with all fields - TaskWarrior syntax is: task <uuid> modify <fields>
    local result
    result=$(task "${task_uuid}" modify "$@" 2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to update task: ${result}" >&2
        return 1
    fi
    
    return 0
}

# Add annotation
# Input: task_uuid, text (string)
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
tw_add_annotation() {
    local task_uuid="$1"
    local text="$2"
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: task_uuid required" >&2
        return 1
    fi
    
    if [[ -z "${text}" ]]; then
        echo "Error: annotation text required" >&2
        return 1
    fi
    
    # Escape special characters in annotation text
    local escaped_text
    escaped_text=$(echo "${text}" | sed 's/"/\\"/g')
    
    # TaskWarrior syntax is: task <uuid> annotate <text>
    local result
    result=$(task "${task_uuid}" annotate "${escaped_text}" 2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to add annotation: ${result}" >&2
        return 1
    fi
    
    return 0
}

# Get task by GitHub issue number
# Input: issue_number (integer)
# Output: Task UUID (to stdout)
# Returns: 0 on success, 1 if not found
tw_get_task_by_issue() {
    local issue_number="$1"
    
    if [[ -z "${issue_number}" ]]; then
        echo "Error: issue_number required" >&2
        return 1
    fi
    
    # Search for task with githubissue UDA - TaskWarrior syntax is: task <filter> export
    local task_data
    task_data=$(task githubissue:"${issue_number}" export 2>/dev/null)
    
    if [[ -z "${task_data}" || "${task_data}" == "[]" ]]; then
        return 1
    fi
    
    # Extract UUID from most recently modified matching task.
    # This makes behavior deterministic when multiple tasks share an issue number.
    local task_uuid
    task_uuid=$(echo "${task_data}" | jq -r '
        sort_by(.modified // .entry // "")
        | reverse
        | .[0].uuid // empty
    ' 2>/dev/null)
    
    if [[ -z "${task_uuid}" ]]; then
        return 1
    fi
    
    echo "${task_uuid}"
    return 0
}

# Check if task exists
# Input: task_uuid (string)
# Output: None
# Returns: 0 if exists, 1 if not
tw_task_exists() {
    local task_uuid="$1"
    
    if [[ -z "${task_uuid}" ]]; then
        return 1
    fi
    
    tw_get_task "${task_uuid}" >/dev/null 2>&1
    return $?
}

# Get task field value
# Input: task_uuid, field_name
# Output: Field value (to stdout)
# Returns: 0 on success, 1 on failure
tw_get_field() {
    local task_uuid="$1"
    local field_name="$2"
    
    if [[ -z "${task_uuid}" || -z "${field_name}" ]]; then
        echo "Error: task_uuid and field_name required" >&2
        return 1
    fi
    
    local task_data
    task_data=$(tw_get_task "${task_uuid}") || return 1
    
    local field_value
    field_value=$(echo "${task_data}" | jq -r ".${field_name} // empty" 2>/dev/null)
    
    echo "${field_value}"
    return 0
}

# Get all tasks with githubsync enabled
# Input: None
# Output: Array of task UUIDs (one per line)
# Returns: 0 on success
tw_get_synced_tasks() {
    local task_data
    task_data=$(task githubsync:enabled export 2>/dev/null)
    
    if [[ -z "${task_data}" || "${task_data}" == "[]" ]]; then
        return 0
    fi
    
    echo "${task_data}" | jq -r '.[].uuid' 2>/dev/null
    return 0
}
