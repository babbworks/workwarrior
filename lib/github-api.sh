#!/usr/bin/env bash
# GitHub API Wrapper
# Provides shell functions for GitHub operations using gh CLI

# Check if gh CLI is installed and authenticated
# Input: None
# Output: Error message if not available (to stderr)
# Returns: 0 if available, 1 if not
check_gh_cli() {
    # Check if gh is installed
    if ! command -v gh &>/dev/null; then
        echo "Error: gh CLI not found. Please install it:" >&2
        echo "  brew install gh" >&2
        echo "  or visit: https://cli.github.com/" >&2
        return 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &>/dev/null; then
        echo "Error: gh CLI not authenticated. Please run:" >&2
        echo "  gh auth login" >&2
        return 1
    fi
    
    return 0
}

# Get issue details
# Input: repo (string "owner/repo"), issue_number (integer)
# Output: JSON object with issue data (to stdout)
# Returns: 0 on success, 1 on failure
github_get_issue() {
    local repo="$1"
    local issue_number="$2"
    
    if [[ -z "${repo}" ]]; then
        echo "Error: repo required (format: owner/repo)" >&2
        return 1
    fi
    
    if [[ -z "${issue_number}" ]]; then
        echo "Error: issue_number required" >&2
        return 1
    fi
    
    check_gh_cli || return 1
    
    local issue_data
    issue_data=$(gh issue view "${issue_number}" \
        --repo "${repo}" \
        --json number,title,state,stateReason,labels,comments,createdAt,updatedAt,closedAt,url,author \
        2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        if echo "${issue_data}" | grep -q "Could not resolve to an Issue"; then
            echo "Error: Issue #${issue_number} not found in ${repo}" >&2
        elif echo "${issue_data}" | grep -q "permission"; then
            echo "Error: Permission denied accessing ${repo}" >&2
        else
            echo "Error: Failed to fetch issue: ${issue_data}" >&2
        fi
        return 1
    fi
    
    echo "${issue_data}"
    return 0
}

# Update issue title and state
# Input: repo, issue_number, title (string), state (OPEN|CLOSED)
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
github_update_issue() {
    local repo="$1"
    local issue_number="$2"
    local title="$3"
    local state="$4"
    
    if [[ -z "${repo}" || -z "${issue_number}" ]]; then
        echo "Error: repo and issue_number required" >&2
        return 1
    fi
    
    check_gh_cli || return 1
    
    local args=()
    
    # Add title if provided
    if [[ -n "${title}" ]]; then
        args+=(--title "${title}")
    fi
    
    # Add state if provided
    if [[ -n "${state}" ]]; then
        case "${state}" in
            OPEN|open)
                args+=(--state open)
                ;;
            CLOSED|closed)
                args+=(--state closed)
                ;;
            *)
                echo "Error: Invalid state '${state}'. Must be OPEN or CLOSED" >&2
                return 1
                ;;
        esac
    fi
    
    if [[ ${#args[@]} -eq 0 ]]; then
        echo "Error: No updates specified (title or state required)" >&2
        return 1
    fi
    
    local result
    result=$(gh issue edit "${issue_number}" \
        --repo "${repo}" \
        "${args[@]}" \
        2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to update issue: ${result}" >&2
        return 1
    fi
    
    return 0
}

# Add or remove labels
# Input: repo, issue_number, add_labels (comma-separated), remove_labels (comma-separated)
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
github_update_labels() {
    local repo="$1"
    local issue_number="$2"
    local add_labels="$3"
    local remove_labels="$4"
    
    if [[ -z "${repo}" || -z "${issue_number}" ]]; then
        echo "Error: repo and issue_number required" >&2
        return 1
    fi
    
    check_gh_cli || return 1
    
    local args=()
    
    # Add labels
    if [[ -n "${add_labels}" ]]; then
        args+=(--add-label "${add_labels}")
    fi
    
    # Remove labels
    if [[ -n "${remove_labels}" ]]; then
        args+=(--remove-label "${remove_labels}")
    fi
    
    if [[ ${#args[@]} -eq 0 ]]; then
        # Nothing to do
        return 0
    fi
    
    local result
    result=$(gh issue edit "${issue_number}" \
        --repo "${repo}" \
        "${args[@]}" \
        2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to update labels: ${result}" >&2
        return 1
    fi
    
    return 0
}

# Add comment
# Input: repo, issue_number, body (string)
# Output: Comment ID (to stdout)
# Returns: 0 on success, 1 on failure
github_add_comment() {
    local repo="$1"
    local issue_number="$2"
    local body="$3"
    
    if [[ -z "${repo}" || -z "${issue_number}" ]]; then
        echo "Error: repo and issue_number required" >&2
        return 1
    fi
    
    if [[ -z "${body}" ]]; then
        echo "Error: comment body required" >&2
        return 1
    fi
    
    check_gh_cli || return 1
    
    local result
    result=$(gh issue comment "${issue_number}" \
        --repo "${repo}" \
        --body "${body}" \
        2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Failed to add comment: ${result}" >&2
        return 1
    fi
    
    # Extract comment URL and get ID from it
    # gh returns URL like: https://github.com/owner/repo/issues/123#issuecomment-456
    local comment_url
    comment_url=$(echo "${result}" | grep -o 'https://github.com/[^#]*#issuecomment-[0-9]*')
    
    if [[ -n "${comment_url}" ]]; then
        local comment_id
        comment_id=$(echo "${comment_url}" | grep -o 'issuecomment-[0-9]*' | cut -d'-' -f2)
        echo "${comment_id}"
    fi
    
    return 0
}

# Create label if doesn't exist
# Input: repo, label_name (string)
# Output: Success/error message (to stderr)
# Returns: 0 on success, 1 on failure
github_ensure_label() {
    local repo="$1"
    local label_name="$2"
    
    if [[ -z "${repo}" || -z "${label_name}" ]]; then
        echo "Error: repo and label_name required" >&2
        return 1
    fi
    
    check_gh_cli || return 1
    
    # Check if label exists
    local label_exists
    label_exists=$(gh label list --repo "${repo}" --json name --jq ".[] | select(.name == \"${label_name}\") | .name" 2>/dev/null)
    
    if [[ -n "${label_exists}" ]]; then
        # Label already exists
        return 0
    fi
    
    # Create label with default color
    local result
    result=$(gh label create "${label_name}" \
        --repo "${repo}" \
        --color "0366d6" \
        2>&1)
    
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        # Check if error is because label already exists (race condition)
        if echo "${result}" | grep -q "already exists"; then
            return 0
        fi
        echo "Error: Failed to create label: ${result}" >&2
        return 1
    fi
    
    return 0
}
