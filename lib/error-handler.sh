#!/usr/bin/env bash
# Error Handler
# Handles sync errors with interactive correction

# Parse GitHub error response
# Input: error_response (string)
# Output: Structured error object (JSON) to stdout
# Returns: 0 on success
parse_github_error() {
    local error_response="$1"
    
    # Try to extract error information from gh CLI output
    local error_category="unknown"
    local error_field=""
    local error_message="${error_response}"
    
    # Categorize error based on message content
    if echo "${error_response}" | grep -qi "validation\|invalid\|too long\|required"; then
        error_category="validation"
    elif echo "${error_response}" | grep -qi "permission\|forbidden\|unauthorized"; then
        error_category="permission"
    elif echo "${error_response}" | grep -qi "rate limit\|too many requests"; then
        error_category="rate_limit"
    elif echo "${error_response}" | grep -qi "not found\|does not exist"; then
        error_category="not_found"
    elif echo "${error_response}" | grep -qi "timeout\|connection\|network"; then
        error_category="network"
    fi
    
    # Try to extract field name
    if echo "${error_response}" | grep -qi "title"; then
        error_field="title"
    elif echo "${error_response}" | grep -qi "state"; then
        error_field="state"
    elif echo "${error_response}" | grep -qi "label"; then
        error_field="labels"
    fi
    
    # Build error object
    jq -n \
        --arg category "${error_category}" \
        --arg field "${error_field}" \
        --arg message "${error_message}" \
        '{
            category: $category,
            field: $field,
            message: $message
        }'
    
    return 0
}

# Handle title validation error
# Input: task_uuid, current_value, error_message
# Output: Interactive prompt for correction
# Returns: 0 if corrected, 1 if skipped
handle_title_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Title Validation Error" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Task: ${task_uuid}" >&2
    echo "Current value: ${current_value}" >&2
    echo "Error: ${error_message}" >&2
    echo "" >&2
    echo "Requirements:" >&2
    echo "  - Title must not be empty" >&2
    echo "  - Maximum 256 characters" >&2
    echo "  - No special formatting required" >&2
    echo "" >&2
    
    # Check if title is too long
    if [[ ${#current_value} -gt 256 ]]; then
        echo "Suggestion: Title is ${#current_value} characters (max 256)" >&2
        echo "  Truncated: ${current_value:0:253}..." >&2
        echo "" >&2
    fi
    
    echo "Options:" >&2
    echo "  1) Auto-truncate to 256 characters" >&2
    echo "  2) Enter a new title manually" >&2
    echo "  3) Skip this task" >&2
    echo "" >&2
    read -p "Choose an option (1-3): " choice >&2
    
    case "${choice}" in
        1)
            # Auto-truncate
            local truncated="${current_value:0:253}..."
            # Source taskwarrior API
            source "$(dirname "${BASH_SOURCE[0]}")/taskwarrior-api.sh"
            if tw_update_task "${task_uuid}" "description" "${truncated}"; then
                echo "✓ Title truncated and updated" >&2
                return 0
            else
                echo "✗ Failed to update title" >&2
                return 1
            fi
            ;;
        2)
            # Manual entry
            echo "" >&2
            read -p "Enter new title: " new_title >&2
            if [[ -z "${new_title}" ]]; then
                echo "✗ Title cannot be empty" >&2
                return 1
            fi
            source "$(dirname "${BASH_SOURCE[0]}")/taskwarrior-api.sh"
            if tw_update_task "${task_uuid}" "description" "${new_title}"; then
                echo "✓ Title updated" >&2
                return 0
            else
                echo "✗ Failed to update title" >&2
                return 1
            fi
            ;;
        3|*)
            # Skip
            echo "⊘ Skipping task" >&2
            return 1
            ;;
    esac
}

# Handle state validation error
# Input: task_uuid, current_value, error_message
# Output: Interactive prompt for correction
# Returns: 0 if corrected, 1 if skipped
handle_state_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "State Validation Error" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Task: ${task_uuid}" >&2
    echo "Current value: ${current_value}" >&2
    echo "Error: ${error_message}" >&2
    echo "" >&2
    echo "Valid states:" >&2
    echo "  - pending (maps to OPEN)" >&2
    echo "  - started (maps to OPEN)" >&2
    echo "  - completed (maps to CLOSED)" >&2
    echo "  - deleted (maps to CLOSED)" >&2
    echo "" >&2
    
    echo "Options:" >&2
    echo "  1) Set to pending" >&2
    echo "  2) Set to completed" >&2
    echo "  3) Skip this task" >&2
    echo "" >&2
    read -p "Choose an option (1-3): " choice >&2
    
    case "${choice}" in
        1)
            source "$(dirname "${BASH_SOURCE[0]}")/taskwarrior-api.sh"
            if tw_update_task "${task_uuid}" "status" "pending"; then
                echo "✓ Status set to pending" >&2
                return 0
            else
                echo "✗ Failed to update status" >&2
                return 1
            fi
            ;;
        2)
            source "$(dirname "${BASH_SOURCE[0]}")/taskwarrior-api.sh"
            if tw_update_task "${task_uuid}" "status" "completed"; then
                echo "✓ Status set to completed" >&2
                return 0
            else
                echo "✗ Failed to update status" >&2
                return 1
            fi
            ;;
        3|*)
            echo "⊘ Skipping task" >&2
            return 1
            ;;
    esac
}

# Handle label validation error
# Input: task_uuid, current_value, error_message
# Output: Interactive prompt for correction
# Returns: 0 if corrected, 1 if skipped
handle_label_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Label Validation Error" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Task: ${task_uuid}" >&2
    echo "Current value: ${current_value}" >&2
    echo "Error: ${error_message}" >&2
    echo "" >&2
    echo "Label requirements:" >&2
    echo "  - Alphanumeric, hyphens, underscores only" >&2
    echo "  - No spaces (use hyphens instead)" >&2
    echo "  - Maximum 50 characters" >&2
    echo "" >&2
    
    # Try to sanitize
    source "$(dirname "${BASH_SOURCE[0]}")/field-mapper.sh"
    local sanitized
    sanitized=$(sanitize_label_name "${current_value}")
    
    if [[ "${sanitized}" != "${current_value}" ]]; then
        echo "Suggestion: ${sanitized}" >&2
        echo "" >&2
    fi
    
    echo "Options:" >&2
    echo "  1) Use sanitized version: ${sanitized}" >&2
    echo "  2) Remove this tag" >&2
    echo "  3) Skip this task" >&2
    echo "" >&2
    read -p "Choose an option (1-3): " choice >&2
    
    case "${choice}" in
        1)
            # Use sanitized version - caller will retry with sanitized tags
            echo "✓ Using sanitized label" >&2
            return 0
            ;;
        2)
            # Remove tag
            source "$(dirname "${BASH_SOURCE[0]}")/taskwarrior-api.sh"
            # This is complex - just skip for now
            echo "⊘ Tag removal not implemented - skipping task" >&2
            return 1
            ;;
        3|*)
            echo "⊘ Skipping task" >&2
            return 1
            ;;
    esac
}

# Handle permission error
# Input: task_uuid, operation, error_message
# Output: Display error and suggestions
# Returns: 1 (cannot auto-correct)
handle_permission_error() {
    local task_uuid="$1"
    local operation="$2"
    local error_message="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Permission Error" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Task: ${task_uuid}" >&2
    echo "Operation: ${operation}" >&2
    echo "Error: ${error_message}" >&2
    echo "" >&2
    echo "Possible causes:" >&2
    echo "  - No write access to the repository" >&2
    echo "  - GitHub token lacks required scopes" >&2
    echo "  - Repository is archived or read-only" >&2
    echo "" >&2
    echo "Solutions:" >&2
    echo "  1. Check repository permissions on GitHub" >&2
    echo "  2. Refresh GitHub token with correct scopes:" >&2
    echo "     gh auth refresh -s repo" >&2
    echo "  3. Verify you have write access to the repository" >&2
    echo "" >&2
    echo "⊘ Skipping this task" >&2
    
    return 1
}

# Handle rate limit error
# Input: error_response
# Output: Interactive prompt to wait or skip
# Returns: 0 if waiting, 1 if skipped
handle_rate_limit_error() {
    local error_response="$1"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Rate Limit Error" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "GitHub API rate limit exceeded" >&2
    echo "" >&2
    echo "GitHub allows 5000 requests per hour for authenticated users." >&2
    echo "The rate limit resets at the top of each hour." >&2
    echo "" >&2
    
    # Try to get rate limit info
    if command -v gh &>/dev/null; then
        echo "Current rate limit status:" >&2
        gh api rate_limit 2>/dev/null | jq -r '.rate | "  Limit: \(.limit)\n  Used: \(.used)\n  Remaining: \(.remaining)\n  Resets at: \(.reset | strftime("%Y-%m-%d %H:%M:%S"))"' >&2 || true
        echo "" >&2
    fi
    
    echo "Options:" >&2
    echo "  1) Wait 60 seconds and retry" >&2
    echo "  2) Skip remaining tasks" >&2
    echo "" >&2
    read -p "Choose an option (1-2): " choice >&2
    
    case "${choice}" in
        1)
            echo "⏳ Waiting 60 seconds..." >&2
            sleep 60
            echo "✓ Retrying" >&2
            return 0
            ;;
        2|*)
            echo "⊘ Skipping remaining tasks" >&2
            return 1
            ;;
    esac
}

# Retry sync with error handling
# Input: task_uuid, operation (push|pull), max_retries (default 3)
# Output: Success/error message
# Returns: 0 on success, 1 on failure
sync_with_error_handling() {
    local task_uuid="$1"
    local operation="$2"
    local max_retries="${3:-3}"
    
    local retry_count=0
    
    while [[ ${retry_count} -lt ${max_retries} ]]; do
        # This is a placeholder - actual sync operations will be implemented
        # in sync-push.sh, sync-pull.sh, etc.
        echo "Retry ${retry_count}/${max_retries} for task ${task_uuid}" >&2
        
        # Simulate operation (will be replaced with actual sync call)
        # For now, just return success
        return 0
        
        retry_count=$((retry_count + 1))
    done
    
    echo "✗ Max retries (${max_retries}) exceeded for task ${task_uuid}" >&2
    return 1
}
